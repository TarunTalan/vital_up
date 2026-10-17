-- Second pass of the pre-release security fixes.
--
-- 1. profiles: users update their own row directly, which let them change
--    server-owned columns (email, username_confirmed) and point avatar_url at
--    any server (every friend's app then loads it, leaking their IPs).
-- 2. Username sign-in: get_email_by_username handed any username's email to
--    anyone signed out, and leaderboards show usernames. login_email() only
--    returns the email together with the right password, with throttling.
-- 3. submit_daily_report trusted the app's water / meal / workout figures,
--    so a script could take every daily point. Those figures are now capped
--    at what the user's synced logs show (sleep, mood and steps can come from
--    Health Connect or stay on the device, so they can't be checked here).

-- ---------------------------------------------------------------------------
-- 1. profiles: columns only the server sets
-- ---------------------------------------------------------------------------
-- Runs as the caller (no SECURITY DEFINER): current_user is 'authenticated'
-- or 'anon' for direct API writes, and the function owner inside SECURITY
-- DEFINER functions (set_username, ensure_profile...), which keep full
-- control.
CREATE OR REPLACE FUNCTION public._protect_profile_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- The signed-in user's own address, from their token.
    NEW.email := auth.jwt() ->> 'email';
    NEW.username_confirmed := TRUE;
  ELSE
    NEW.email := OLD.email;
    NEW.username_confirmed := OLD.username_confirmed;
  END IF;

  -- Our storage (the user's own folder) or the Google account photo.
  IF NEW.avatar_url IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.avatar_url IS DISTINCT FROM OLD.avatar_url)
     AND NOT (
       NEW.avatar_url LIKE 'https://lh3.googleusercontent.com/%'
       OR NEW.avatar_url ~ ('^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/avatars/'
                            || NEW.id::text || '/')
     ) THEN
    RAISE EXCEPTION 'avatar_url not allowed' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public._protect_profile_columns() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS profiles_protect_columns ON public.profiles;
CREATE TRIGGER profiles_protect_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public._protect_profile_columns();

-- ---------------------------------------------------------------------------
-- 2. Username sign-in without leaking emails
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.login_attempts (
  id BIGSERIAL PRIMARY KEY,
  username TEXT NOT NULL,
  attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS login_attempts_username_idx
  ON public.login_attempts (username, attempted_at DESC);
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.login_attempts FROM anon, authenticated;

-- The account's email when [p_password] is right, else NULL (same answer for
-- unknown usernames). 10 failed tries per username per 15 minutes, then NULL
-- until the window passes. The app then signs in with email + password, so
-- GoTrue still does the real authentication.
CREATE OR REPLACE FUNCTION public.login_email(p_username TEXT, p_password TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_name TEXT := lower(trim(COALESCE(p_username, '')));
  v_hash TEXT;
  v_email TEXT;
BEGIN
  IF v_name = '' OR length(v_name) > 30 OR COALESCE(length(p_password), 0) NOT BETWEEN 1 AND 128 THEN
    RETURN NULL;
  END IF;

  IF (SELECT count(*) FROM login_attempts
      WHERE username = v_name AND attempted_at > now() - INTERVAL '15 minutes') >= 10 THEN
    RETURN NULL;
  END IF;

  SELECT u.encrypted_password, u.email INTO v_hash, v_email
  FROM profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE lower(p.username) = v_name
  LIMIT 1;

  IF v_hash IS NOT NULL AND v_hash <> '' AND crypt(p_password, v_hash) = v_hash THEN
    DELETE FROM login_attempts WHERE username = v_name;
    RETURN v_email;
  END IF;

  -- Unknown names cost the same as wrong passwords (no timing hint).
  IF v_hash IS NULL OR v_hash = '' THEN
    PERFORM crypt(p_password, gen_salt('bf', 10));
  END IF;
  INSERT INTO login_attempts (username) VALUES (v_name);
  DELETE FROM login_attempts WHERE attempted_at < now() - INTERVAL '1 day';
  RETURN NULL;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.login_email(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.login_email(TEXT, TEXT) TO anon, authenticated;

-- The old lookup (created in the dashboard, so its signature isn't in the
-- repo) is closed to clients whatever its arguments are.
DO $$
DECLARE
  f REGPROCEDURE;
BEGIN
  FOR f IN
    SELECT p.oid::REGPROCEDURE
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_email_by_username'
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Daily report figures capped by synced logs
-- ---------------------------------------------------------------------------
-- The original becomes an internal step; clients call the wrapper.
ALTER FUNCTION public.submit_daily_report(DATE, JSONB) RENAME TO _submit_daily_report_core;
REVOKE EXECUTE ON FUNCTION public._submit_daily_report_core(DATE, JSONB) FROM PUBLIC, anon, authenticated;

-- Logs anywhere in this window count for [p_day]: wide enough for every time
-- zone (the day is the user's local day; the server only knows UTC).
CREATE OR REPLACE FUNCTION public._report_window(p_day DATE)
RETURNS TSTZRANGE
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT tstzrange((p_day::TIMESTAMP - INTERVAL '14 hours') AT TIME ZONE 'UTC',
                   (p_day::TIMESTAMP + INTERVAL '38 hours') AT TIME ZONE 'UTC');
$$;

CREATE OR REPLACE FUNCTION public.submit_daily_report(p_day DATE, p_metrics JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_window TSTZRANGE;
  v_water INTEGER;
  v_meals INTEGER;
  v_workouts INTEGER;
  m JSONB := COALESCE(p_metrics, '{}'::jsonb);
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_day IS NULL THEN
    RAISE EXCEPTION 'day out of range';
  END IF;
  v_window := _report_window(p_day);

  SELECT count(*) INTO v_water FROM water_logs
  WHERE user_id = v_user AND deleted_at IS NULL AND logged_at <@ v_window;
  SELECT count(*) INTO v_meals FROM meal_logs
  WHERE user_id = v_user AND deleted_at IS NULL AND captured_at <@ v_window;
  SELECT count(*) INTO v_workouts FROM activity_sessions
  WHERE user_id = v_user AND deleted_at IS NULL AND start_time <@ v_window;

  -- Not uploaded yet (offline) counts as nothing for now; the report sent
  -- after the next sync raises the day again (figures never go down).
  m := m
    || jsonb_build_object(
      'water_logs', LEAST(COALESCE((m->>'water_logs')::NUMERIC, 0), v_water),
      'water_goal_met', COALESCE((m->>'water_goal_met')::BOOLEAN, FALSE) AND v_water > 0,
      'food_logs', LEAST(COALESCE((m->>'food_logs')::NUMERIC, 0), v_meals),
      'planned_meals_logged', LEAST(COALESCE((m->>'planned_meals_logged')::NUMERIC, 0), v_meals),
      'calorie_goal_met', COALESCE((m->>'calorie_goal_met')::BOOLEAN, FALSE) AND v_meals > 0,
      'workouts', LEAST(COALESCE((m->>'workouts')::NUMERIC, 0), v_workouts));

  RETURN _submit_daily_report_core(p_day, m);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.submit_daily_report(DATE, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_daily_report(DATE, JSONB) TO authenticated;
