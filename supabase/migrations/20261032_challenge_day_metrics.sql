-- More to compete on, and one-day challenges.
--
-- New metrics, scored by day from figures the server already checks:
--   points            points earned (nutrition + wellbeing + fitness; no
--                     streak or badge bonuses, so newer players can win)
--   nutrition_points  healthy eating: meals logged, diet plan meals and
--                     days, calorie target, water
--   wellbeing_points  sleep logged, 7 h sleep, mood check-ins, calm days
--   steps             steps from the daily reports (capped at 60,000 a day)
-- Point rules carry their own daily caps, and the daily report wrapper caps
-- logs at what was uploaded, so these can't be won by logging nonsense.
--
-- Day-based challenges run on whole days: today and the next days - 1, in
-- each participant's own time zone (profiles.timezone, India fallback).
-- They end at the creator's midnight after the last day, so the tile shows
-- the real time left. Late syncs of those days still count. Workout
-- metrics keep their rolling window (now to now + days).
--
-- Lengths: 1, 3, 7 or 14 days. Older apps don't know the new metrics and
-- show them as active minutes until they update.

ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS days SMALLINT;

ALTER TABLE public.challenges DROP CONSTRAINT IF EXISTS challenges_metric_check;
ALTER TABLE public.challenges ADD CONSTRAINT challenges_metric_check CHECK (metric IN
  ('active_minutes', 'distance_km', 'workouts',
   'points', 'nutrition_points', 'wellbeing_points', 'steps'));

-- ---------------------------------------------------------------------------
-- A participant's score.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._challenge_score(p_challenge UUID, p_user UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c challenges%ROWTYPE;
  v_tz TEXT;
  v_first DATE;
  v_last DATE;
  v_score NUMERIC;
BEGIN
  SELECT * INTO c FROM challenges WHERE id = p_challenge;
  IF NOT FOUND THEN RETURN 0; END IF;

  IF c.metric IN ('active_minutes', 'distance_km', 'workouts') THEN
    SELECT CASE c.metric
             WHEN 'workouts' THEN COUNT(a.id)::numeric
             WHEN 'active_minutes' THEN
               FLOOR(SUM((a.data->>'totalDurationSeconds')::numeric) / 60)
             ELSE ROUND(SUM((a.data->>'totalDistanceMeters')::numeric) / 1000, 1)
           END
      INTO v_score
    FROM activity_sessions a
    WHERE a.user_id = p_user
      AND a.deleted_at IS NULL
      AND a.end_time IS NOT NULL
      AND a.start_time >= c.starts_at
      AND a.start_time < c.ends_at;
    RETURN COALESCE(v_score, 0);
  END IF;

  -- The participant's own days.
  SELECT timezone INTO v_tz FROM profiles WHERE id = p_user;
  v_first := (c.starts_at AT TIME ZONE COALESCE(v_tz, 'Asia/Kolkata'))::DATE;
  v_last := v_first + GREATEST(COALESCE(c.days, 1), 1) - 1;

  IF c.metric = 'steps' THEN
    SELECT SUM(COALESCE((r.metrics->>'steps')::INT, 0)) INTO v_score
    FROM daily_reports r
    WHERE r.user_id = p_user AND r.day BETWEEN v_first AND v_last;
  ELSE
    SELECT SUM(e.points) INTO v_score
    FROM point_events e
    WHERE e.user_id = p_user
      AND e.day BETWEEN v_first AND v_last
      AND e.category = ANY (CASE c.metric
            WHEN 'nutrition_points' THEN ARRAY['nutrition']
            WHEN 'wellbeing_points' THEN ARRAY['lifestyle']
            ELSE ARRAY['nutrition', 'lifestyle', 'fitness'] END);
  END IF;
  RETURN COALESCE(v_score, 0);
END;
$$;

-- ---------------------------------------------------------------------------
-- Create (from 20261024_challenge_request_id.sql): new metrics and 1 day.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_challenge(
  p_metric TEXT,
  p_days INTEGER,
  p_friend_ids UUID[],
  p_request_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_id UUID;
  v_friends UUID[];
  v_actor JSONB;
  v_tz TEXT;
  v_ends TIMESTAMP WITH TIME ZONE;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  -- A retry of a challenge already created: hand it back.
  IF p_request_id IS NOT NULL THEN
    SELECT id INTO v_id FROM challenges
    WHERE creator_id = v_user AND request_id = p_request_id;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  END IF;

  IF p_metric IS NULL OR p_metric NOT IN ('active_minutes', 'distance_km', 'workouts',
      'points', 'nutrition_points', 'wellbeing_points', 'steps') THEN
    RAISE EXCEPTION 'invalid_metric';
  END IF;
  IF p_days IS NULL OR p_days NOT IN (1, 3, 7, 14) THEN
    RAISE EXCEPTION 'invalid_duration';
  END IF;
  -- The app sends 1-9 distinct friends; refuse oversized arrays before
  -- scanning them.
  IF p_friend_ids IS NULL OR cardinality(p_friend_ids) = 0 THEN
    RAISE EXCEPTION 'no_friends_selected';
  END IF;
  IF cardinality(p_friend_ids) > 9 THEN RAISE EXCEPTION 'too_many_friends'; END IF;

  -- Only accepted friends, without duplicates or the caller.
  SELECT ARRAY_AGG(DISTINCT f.friend) INTO v_friends
  FROM (
    SELECT CASE WHEN fr.requester_id = v_user THEN fr.addressee_id ELSE fr.requester_id END AS friend
    FROM friendships fr
    WHERE fr.status = 'accepted' AND v_user IN (fr.requester_id, fr.addressee_id)
  ) f
  WHERE f.friend = ANY (p_friend_ids);

  IF v_friends IS NULL OR array_length(v_friends, 1) = 0 THEN
    RAISE EXCEPTION 'no_friends_selected';
  END IF;
  IF array_length(v_friends, 1) > 9 THEN RAISE EXCEPTION 'too_many_friends'; END IF;
  IF (SELECT COUNT(*) FROM challenges WHERE creator_id = v_user
        AND created_at > now() - INTERVAL '1 day') >= 5 THEN
    RAISE EXCEPTION 'too_many_challenges';
  END IF;

  IF p_metric IN ('active_minutes', 'distance_km', 'workouts') THEN
    v_ends := now() + make_interval(days => p_days);
  ELSE
    -- Midnight after the last day, on the creator's clock.
    SELECT COALESCE(timezone, 'Asia/Kolkata') INTO v_tz FROM profiles WHERE id = v_user;
    v_tz := COALESCE(v_tz, 'Asia/Kolkata');
    v_ends := (user_today(v_tz) + p_days)::TIMESTAMP AT TIME ZONE v_tz;
  END IF;

  BEGIN
    INSERT INTO challenges (creator_id, metric, starts_at, ends_at, request_id, days)
    VALUES (v_user, p_metric, now(), v_ends, p_request_id, p_days)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    -- The same request finished in parallel: return that one.
    SELECT id INTO v_id FROM challenges
    WHERE creator_id = v_user AND request_id = p_request_id;
    IF v_id IS NULL THEN RAISE; END IF;
    RETURN v_id;
  END;

  INSERT INTO challenge_participants (challenge_id, user_id, status, responded_at)
  VALUES (v_id, v_user, 'joined', now());
  INSERT INTO challenge_participants (challenge_id, user_id)
  SELECT v_id, unnest(v_friends);

  v_actor := COALESCE(_notification_actor(v_user), '{}'::jsonb);
  INSERT INTO notifications (user_id, type, title, body, actor_id, data)
  SELECT friend, 'challenge', 'New challenge',
    '@' || COALESCE(v_actor->>'username', 'A friend') || ' challenged you: most '
      || CASE p_metric WHEN 'active_minutes' THEN 'active minutes'
                       WHEN 'distance_km' THEN 'distance'
                       WHEN 'workouts' THEN 'workouts'
                       WHEN 'points' THEN 'points'
                       WHEN 'nutrition_points' THEN 'healthy eating points'
                       WHEN 'wellbeing_points' THEN 'wellbeing points'
                       ELSE 'steps' END
      || ' in ' || p_days || CASE WHEN p_days = 1 THEN ' day' ELSE ' days' END,
    v_user,
    v_actor || jsonb_build_object('challenge_id', v_id, 'route', 'challenges')
  FROM unnest(v_friends) AS friend;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public._challenge_score(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[], UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[], UUID) TO authenticated;
