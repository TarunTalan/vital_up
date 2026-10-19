-- Username sign-in throttle per caller, and limits on moving push tokens.
--
-- 1. login_email (20261021) counted failed tries per username only, so
--    anyone could lock a user out of username sign-in with 10 wrong
--    passwords. Tries now count per username AND caller address (10 per
--    15 minutes), with a higher per-username cap (50 per 15 minutes) that
--    still bounds guessing from many addresses. A throttled call raises
--    `too_many_attempts` (unknown usernames are throttled the same way, so
--    it says nothing about whether the account exists); the app then
--    suggests signing in with the email, which this throttle never blocks.
-- 2. register_push_token moved a token from any account to the caller.
--    That's needed when a phone changes accounts and the old sign-out
--    couldn't unregister, but with a leaked token it redirects someone
--    else's notifications. Taking over another account's token is now
--    limited to 3 a day per account (a phone changes hands rarely).

-- ---------------------------------------------------------------------------
-- 1. Username sign-in
-- ---------------------------------------------------------------------------
ALTER TABLE public.login_attempts ADD COLUMN IF NOT EXISTS caller TEXT NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS login_attempts_caller_idx
  ON public.login_attempts (username, caller, attempted_at DESC);

-- The caller's address as the API gateway reports it ('' when unknown).
-- A spoofed header only buys its own bucket: the per-username cap holds.
CREATE OR REPLACE FUNCTION public._request_caller()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_headers JSON;
BEGIN
  BEGIN
    v_headers := NULLIF(current_setting('request.headers', true), '')::JSON;
  EXCEPTION WHEN OTHERS THEN
    RETURN '';
  END;
  RETURN left(COALESCE(
    NULLIF(btrim(v_headers->>'cf-connecting-ip'), ''),
    NULLIF(btrim(v_headers->>'x-real-ip'), ''),
    NULLIF(btrim(split_part(v_headers->>'x-forwarded-for', ',', 1)), ''),
    ''
  ), 64);
END;
$$;
REVOKE EXECUTE ON FUNCTION public._request_caller() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.login_email(p_username TEXT, p_password TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_name TEXT := lower(trim(COALESCE(p_username, '')));
  v_caller TEXT := public._request_caller();
  v_hash TEXT;
  v_email TEXT;
BEGIN
  IF v_name = '' OR length(v_name) > 30 OR COALESCE(length(p_password), 0) NOT BETWEEN 1 AND 128 THEN
    RETURN NULL;
  END IF;

  IF (SELECT count(*) FROM login_attempts
      WHERE username = v_name AND caller = v_caller
        AND attempted_at > now() - INTERVAL '15 minutes') >= 10
     OR (SELECT count(*) FROM login_attempts
         WHERE username = v_name
           AND attempted_at > now() - INTERVAL '15 minutes') >= 50 THEN
    RAISE EXCEPTION 'too_many_attempts' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.encrypted_password, u.email INTO v_hash, v_email
  FROM profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE lower(p.username) = v_name
  LIMIT 1;

  IF v_hash IS NOT NULL AND v_hash <> '' AND crypt(p_password, v_hash) = v_hash THEN
    -- Only this caller's tries: someone else's guesses stay counted.
    DELETE FROM login_attempts WHERE username = v_name AND caller = v_caller;
    RETURN v_email;
  END IF;

  -- Unknown names cost the same as wrong passwords (no timing hint).
  IF v_hash IS NULL OR v_hash = '' THEN
    PERFORM crypt(p_password, gen_salt('bf', 10));
  END IF;
  INSERT INTO login_attempts (username, caller) VALUES (v_name, v_caller);
  DELETE FROM login_attempts WHERE attempted_at < now() - INTERVAL '1 day';
  RETURN NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.login_email(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.login_email(TEXT, TEXT) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Push tokens
-- ---------------------------------------------------------------------------
-- Service only (no client policies), like login_attempts.
CREATE TABLE IF NOT EXISTS public.push_token_takeovers (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  taken_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS push_token_takeovers_user_idx
  ON public.push_token_takeovers (user_id, taken_at DESC);
ALTER TABLE public.push_token_takeovers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_token_takeovers FROM anon, authenticated;

-- From 20261016_input_constraints.sql; adds the takeover limit.
CREATE OR REPLACE FUNCTION public.register_push_token(p_token TEXT, p_platform TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_owner UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_token IS NULL OR LENGTH(p_token) NOT BETWEEN 20 AND 4096 THEN
    RAISE EXCEPTION 'invalid token';
  END IF;
  IF p_token ~ '[[:cntrl:][:space:]]' THEN
    RAISE EXCEPTION 'invalid token' USING ERRCODE = '22023';
  END IF;
  IF p_platform IS NULL OR p_platform NOT IN ('android', 'ios') THEN
    RAISE EXCEPTION 'invalid platform' USING ERRCODE = '22023';
  END IF;

  SELECT user_id INTO v_owner FROM push_tokens WHERE token = p_token FOR UPDATE;
  IF v_owner IS NOT NULL AND v_owner <> v_user THEN
    IF (SELECT count(*) FROM push_token_takeovers
        WHERE user_id = v_user AND taken_at > now() - INTERVAL '1 day') >= 3 THEN
      RAISE EXCEPTION 'too_many_token_changes' USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO push_token_takeovers (user_id) VALUES (v_user);
    DELETE FROM push_token_takeovers WHERE taken_at < now() - INTERVAL '2 days';
  END IF;

  INSERT INTO push_tokens (token, user_id, platform)
  VALUES (p_token, v_user, p_platform)
  ON CONFLICT (token) DO UPDATE
  SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW();

  -- Caps tokens per account (reinstalls leave stale ones behind).
  DELETE FROM push_tokens
  WHERE user_id = v_user AND token IN (
    SELECT token FROM push_tokens WHERE user_id = v_user
    ORDER BY updated_at DESC OFFSET 10);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.register_push_token(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_push_token(TEXT, TEXT) TO authenticated;
