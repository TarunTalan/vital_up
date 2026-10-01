-- Push notifications (FCM): device tokens, and a trigger that hands every
-- new notification to the `send-push` Edge Function.
--
-- One-time setup after deploying the function (SQL editor):
--   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/send-push', 'push_webhook_url');
--   select vault.create_secret('<long random string>', 'push_webhook_secret');
-- and set the same secret on the function:
--   supabase secrets set PUSH_WEBHOOK_SECRET=<long random string>
-- Until both vault secrets exist, notifications stay in-app only.

CREATE TABLE IF NOT EXISTS push_tokens (
  token TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);

-- Read only; tokens are written through the functions below.
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own push tokens" ON push_tokens;
CREATE POLICY "Users can read own push tokens" ON push_tokens
  FOR SELECT USING (auth.uid() = user_id);

-- Saves this device's token for the caller. A device that signs into another
-- account moves its token to that account.
CREATE OR REPLACE FUNCTION register_push_token(p_token TEXT, p_platform TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_token IS NULL OR LENGTH(p_token) NOT BETWEEN 20 AND 4096 THEN
    RAISE EXCEPTION 'invalid token';
  END IF;

  INSERT INTO push_tokens (token, user_id, platform)
  VALUES (p_token, auth.uid(), p_platform)
  ON CONFLICT (token) DO UPDATE
  SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW();

  -- Caps tokens per account (reinstalls leave stale ones behind).
  DELETE FROM push_tokens
  WHERE user_id = auth.uid() AND token IN (
    SELECT token FROM push_tokens WHERE user_id = auth.uid()
    ORDER BY updated_at DESC OFFSET 10);
END;
$$;

CREATE OR REPLACE FUNCTION unregister_push_token(p_token TEXT)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM push_tokens WHERE token = p_token AND user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION register_push_token(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION unregister_push_token(TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION register_push_token(TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION unregister_push_token(TEXT) FROM anon;

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Posts the new row to send-push. pg_net is asynchronous, so this never slows
-- down or fails the insert.
CREATE OR REPLACE FUNCTION dispatch_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url TEXT;
  v_secret TEXT;
BEGIN
  SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name = 'push_webhook_url';
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'push_webhook_secret';
  IF v_url IS NULL OR v_secret IS NULL THEN
    RETURN NULL;
  END IF;
  -- No registered device: nothing to send.
  IF NOT EXISTS (SELECT 1 FROM push_tokens WHERE user_id = NEW.user_id) THEN
    RETURN NULL;
  END IF;

  PERFORM net.http_post(
    url := v_url,
    body := jsonb_build_object('record', to_jsonb(NEW)),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', v_secret)
  );
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  -- Push is best effort; the in-app inbox already has the row.
  RAISE WARNING 'push dispatch failed: %', SQLERRM;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS notifications_dispatch_push ON notifications;
CREATE TRIGGER notifications_dispatch_push
  AFTER INSERT ON notifications
  FOR EACH ROW EXECUTE FUNCTION dispatch_push_notification();
