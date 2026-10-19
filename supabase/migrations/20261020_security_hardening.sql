-- Security hardening from the pre-release audit.
--
-- 1. Policies written as "service role can ..." had no TO clause, so they
--    applied to anon and authenticated too (the service role bypasses RLS
--    and never needed them). Anyone could make themselves premium, reset
--    their scan counts, write recognition logs for any user and poison the
--    shared USDA cache.
-- 2. email_send_log: per-recipient cap for the send-email function.
-- 3. is_premium_user / increment_scan_count / cleanup_expired_cache were
--    SECURITY DEFINER without a search_path; is_premium_user also answered
--    for any user id.
-- 4. "REVOKE ... FROM anon" did nothing while PUBLIC kept EXECUTE (the
--    default for new functions), so signed-out callers could still scrape
--    leaderboards and friend lists.
-- 5. profiles.timezone is writable by its owner; an invalid zone made the
--    hourly weekly-summary job fail for everyone.
-- 6. Avatars: anyone could list the bucket (folder names are user ids).
-- 7. Challenge scores trust activity_sessions.data; impossible values are
--    refused from now on.

-- ---------------------------------------------------------------------------
-- 1. Service-only tables
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Service role can manage subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Service role can manage scan usage" ON public.scan_usage;
DROP POLICY IF EXISTS "Service role can insert recognition logs" ON public.recognition_logs;
DROP POLICY IF EXISTS "Service role can manage food search cache" ON public.food_search_cache;

-- Read-own policies stay; only the service role (edge functions,
-- revenuecat-webhook) writes these.
REVOKE INSERT, UPDATE, DELETE ON public.subscriptions FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.scan_usage FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.recognition_logs FROM anon, authenticated;
REVOKE ALL ON public.food_search_cache FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. send-email rate limit log (service role only: RLS on, no policies)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.email_send_log (
  id BIGSERIAL PRIMARY KEY,
  recipient TEXT NOT NULL CHECK (length(recipient) BETWEEN 3 AND 254),
  sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS email_send_log_recipient_idx
  ON public.email_send_log (recipient, sent_at DESC);
ALTER TABLE public.email_send_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.email_send_log FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Legacy food-scan functions
-- ---------------------------------------------------------------------------
-- A signed-in caller only learns their own status; the service role (edge
-- functions, consume_ai_quota called from them) may ask about anyone.
CREATE OR REPLACE FUNCTION public.is_premium_user(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
  IF auth.uid() IS NOT NULL AND p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN FALSE;
  END IF;

  SELECT is_premium, expires_at INTO v_is_premium, v_expires_at
  FROM subscriptions
  WHERE user_id = p_user_id;

  IF v_is_premium IS NULL OR v_is_premium = FALSE THEN
    RETURN FALSE;
  END IF;
  IF v_expires_at IS NOT NULL AND v_expires_at < NOW() THEN
    RETURN FALSE;
  END IF;
  RETURN v_is_premium;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.is_premium_user(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_premium_user(UUID) TO authenticated;

-- Nothing in the app or the edge functions calls these any more.
ALTER FUNCTION public.increment_scan_count(UUID, TEXT) SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.increment_scan_count(UUID, TEXT) FROM PUBLIC, anon, authenticated;
ALTER FUNCTION public.cleanup_expired_cache() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.cleanup_expired_cache() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Signed-in-only RPCs: take EXECUTE away from PUBLIC (and so from anon)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  f REGPROCEDURE;
BEGIN
  FOR f IN
    SELECT p.oid::REGPROCEDURE
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = ANY (ARRAY[
        'submit_daily_report', 'get_leaderboard', 'get_my_rank',
        'get_communities', 'set_my_city', 'send_friend_request',
        'respond_friend_request', 'remove_friend', 'get_friends',
        'get_friends_leaderboard', 'mark_notifications_read',
        'register_push_token', 'unregister_push_token',
        'username_available', 'set_username', 'get_badge_progress',
        'get_remaining_scans'
      ])
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. Only real time zones in profiles.timezone
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._check_profile_timezone()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.timezone IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = NEW.timezone) THEN
    RAISE EXCEPTION 'invalid time zone' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public._check_profile_timezone() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS profiles_timezone_check ON public.profiles;
CREATE TRIGGER profiles_timezone_check
  BEFORE INSERT OR UPDATE OF timezone ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public._check_profile_timezone();

-- Rows written before this trigger: fall back to UTC so the job can run.
UPDATE public.profiles
SET timezone = NULL
WHERE timezone IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = profiles.timezone);

-- ---------------------------------------------------------------------------
-- 6. Avatars: files are served by public URL (no policy needed); only the
--    owner may list or read their folder through the API.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Avatar images are publicly readable" ON storage.objects;
DROP POLICY IF EXISTS "Users can read their own avatar folder" ON storage.objects;
CREATE POLICY "Users can read their own avatar folder"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- 7. Workout figures challenges are scored from. NOT VALID: checks new and
--    edited rows only; run the SELECT below, then VALIDATE.
-- ---------------------------------------------------------------------------
ALTER TABLE public.activity_sessions DROP CONSTRAINT IF EXISTS activity_sessions_sane_figures;
-- CASE, not AND: Postgres may evaluate AND in any order, and a cast of a
-- non-number would raise 22P02 instead of a check violation (sync only sets
-- aside rows that fail a check; any other error blocks the table).
CREATE OR REPLACE FUNCTION public._sane_workout(p_data JSONB, p_start TIMESTAMPTZ, p_end TIMESTAMPTZ)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT (p_end IS NULL OR (p_end >= p_start AND p_end - p_start <= INTERVAL '48 hours'))
    AND CASE
          WHEN p_data->'totalDistanceMeters' IS NULL THEN TRUE
          WHEN jsonb_typeof(p_data->'totalDistanceMeters') = 'number'
            THEN (p_data->>'totalDistanceMeters')::NUMERIC BETWEEN 0 AND 500000
          ELSE FALSE
        END
    AND CASE
          WHEN p_data->'totalDurationSeconds' IS NULL THEN TRUE
          WHEN jsonb_typeof(p_data->'totalDurationSeconds') = 'number'
            THEN (p_data->>'totalDurationSeconds')::NUMERIC BETWEEN 0 AND 172800
          ELSE FALSE
        END
$$;

ALTER TABLE public.activity_sessions ADD CONSTRAINT activity_sessions_sane_figures
  CHECK (public._sane_workout(data, start_time, end_time)) NOT VALID;
-- SELECT id FROM public.activity_sessions
-- WHERE NOT public._sane_workout(data, start_time, end_time);
-- ALTER TABLE public.activity_sessions VALIDATE CONSTRAINT activity_sessions_sane_figures;

-- ---------------------------------------------------------------------------
-- 8. AI quota refunds are capped. Edge functions refund on any failure,
--    including ones a user can cause on purpose (non-food photos, "answer in
--    plain text", asking for a listed allergen), which made the daily caps
--    unlimited. A few refunds a day still cover real provider outages.
-- ---------------------------------------------------------------------------
ALTER TABLE public.ai_usage_daily
  ADD COLUMN IF NOT EXISTS refund_count INTEGER NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.refund_ai_quota(p_user_id UUID, p_feature TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE ai_usage_daily
  SET use_count = GREATEST(0, use_count - 1),
      refund_count = refund_count + 1,
      updated_at = NOW()
  WHERE user_id = p_user_id
    AND feature = p_feature
    AND day = ai_quota_day()
    AND refund_count < 3;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.refund_ai_quota(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_quota(UUID, TEXT) TO service_role;
