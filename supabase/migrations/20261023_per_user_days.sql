-- Days per user, a wider late-report window and capped-report feedback.
--
-- Audit of app vs server days (the server counts days in India time, the
-- app in the phone's local time):
-- 1. submit_daily_report() capped a figure at the logs already uploaded,
--    but the app recorded the day as sent and never resent it after the
--    upload, so the last workout / water / meal of a day could lose its
--    points for good. The wrapper now returns `capped`; the app resends.
-- 2. Reports were accepted back to India today - 2. West of India that is
--    barely one local day: an offline weekend lost its oldest day. Now
--    today - 3; award finalisation moves one day later to match (weeks on
--    Thursday, months on the 4th).
-- 3. Rest days, the streak shown to friends and the once-a-day cheer used
--    the India day. They now use each user's own day (profiles.timezone,
--    India when unset).
-- 4. Live leaderboards had no end date: tomorrow's points from zones ahead
--    of India counted in the period that was ending.
-- 5. Weekly summaries fell back to UTC when no zone was reported; India
--    now, like every other server day.
-- 6. email_send_log kept every recipient address forever; rows past the
--    one-day rate-limit window are deleted daily.
--
-- Scoring days themselves (point_events.day, the report range check) stay
-- India days, so every board and award agrees on one calendar.

-- ---------------------------------------------------------------------------
-- 1. A user's own day
-- ---------------------------------------------------------------------------

-- Today in [p_tz] (an IANA zone, checked when profiles.timezone is written);
-- India when the app never reported one.
CREATE OR REPLACE FUNCTION public.user_today(p_tz TEXT)
RETURNS DATE
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT (now() AT TIME ZONE COALESCE(p_tz, 'Asia/Kolkata'))::DATE;
$$;

-- The streak as the user sees it on their own phone: alive while their
-- yesterday or today was active.
CREATE OR REPLACE FUNCTION public.effective_streak(
  p_streak INTEGER, p_last_active DATE, p_tz TEXT)
RETURNS INTEGER
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE WHEN p_last_active >= user_today(p_tz) - 1 THEN p_streak ELSE 0 END;
$$;

REVOKE EXECUTE ON FUNCTION public.user_today(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.effective_streak(INTEGER, DATE, TEXT) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Rest days are spent after each user's own midnight
-- ---------------------------------------------------------------------------

-- Hourly: covers the user's yesterday with a rest day when their streak
-- would break today (last active the day before yesterday, their time).
CREATE OR REPLACE FUNCTION public.use_streak_freezes()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  WITH due AS (
    SELECT s.user_id, user_today(p.timezone) AS today
    FROM player_stats s
    LEFT JOIN profiles p ON p.id = s.user_id
    WHERE s.streak_freezes > 0 AND s.current_streak > 0
  )
  UPDATE player_stats ps SET
    streak_freezes = ps.streak_freezes - 1,
    last_active_day = due.today - 1,
    frozen_days = ARRAY(
      SELECT d FROM unnest(array_append(ps.frozen_days, due.today - 1)) d
      WHERE d >= due.today - 14 ORDER BY d)
  FROM due
  WHERE ps.user_id = due.user_id
    AND ps.last_active_day = due.today - 2;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.use_streak_freezes() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Scoring: three days back; the streak returned in the user's day.
--    Otherwise the core from 20261015_streak_rest_days.sql, unchanged.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._submit_daily_report_core(p_day DATE, p_metrics JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_today DATE := gamification_today();
  v_old JSONB;
  m JSONB;
  v_stats player_stats%ROWTYPE;
  v_before_total INTEGER;
  v_before_level INTEGER;
  v_before_cat JSONB;
  v_day_points INTEGER;
  v_streak INTEGER;
  v_goal TEXT;
  v_milestone INTEGER;
  v_badge RECORD;
  v_earned BOOLEAN;
  v_value NUMERIC;
  v_new_badges JSONB := '[]'::jsonb;
  v_level INTEGER;
  v_week_start DATE;
  v_freezes INTEGER;
  v_start DATE;
  v_gap INTEGER;
  v_counted BOOLEAN := FALSE;
  v_freezes_used INTEGER := 0;
  v_freeze_earned BOOLEAN := FALSE;
  v_frozen DATE[];
  v_tz TEXT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_day IS NULL OR p_day < v_today - 3 OR p_day > v_today + 1 THEN
    RAISE EXCEPTION 'day out of range';
  END IF;

  INSERT INTO player_stats (user_id) VALUES (v_user) ON CONFLICT (user_id) DO NOTHING;
  -- Serialises concurrent submits for this user.
  SELECT * INTO v_stats FROM player_stats WHERE user_id = v_user FOR UPDATE;
  v_before_total := v_stats.total_points;
  v_before_level := v_stats.level;
  v_before_cat := jsonb_build_object(
    'nutrition', v_stats.nutrition_points,
    'lifestyle', v_stats.lifestyle_points,
    'fitness', v_stats.fitness_points);

  -- Clamp to plausible values, then merge with what was already reported so
  -- the day's numbers never go down.
  SELECT metrics INTO v_old FROM daily_reports WHERE user_id = v_user AND day = p_day;
  v_old := COALESCE(v_old, '{}'::jsonb);

  m := jsonb_build_object(
    'steps', GREATEST(COALESCE((v_old->>'steps')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'steps')::NUMERIC, 0), 0), 60000)::INT),
    'distance_m', GREATEST(COALESCE((v_old->>'distance_m')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'distance_m')::NUMERIC, 0), 0), 80000)::INT),
    'active_minutes', GREATEST(COALESCE((v_old->>'active_minutes')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'active_minutes')::NUMERIC, 0), 0), 600)::INT),
    'calories', GREATEST(COALESCE((v_old->>'calories')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'calories')::NUMERIC, 0), 0), 6000)::INT),
    'workouts', GREATEST(COALESCE((v_old->>'workouts')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'workouts')::NUMERIC, 0), 0), 6)::INT),
    'food_logs', GREATEST(COALESCE((v_old->>'food_logs')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'food_logs')::NUMERIC, 0), 0), 20)::INT),
    'water_logs', GREATEST(COALESCE((v_old->>'water_logs')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'water_logs')::NUMERIC, 0), 0), 30)::INT),
    'planned_meals', GREATEST(COALESCE((v_old->>'planned_meals')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'planned_meals')::NUMERIC, 0), 0), 8)::INT),
    'planned_meals_logged', GREATEST(COALESCE((v_old->>'planned_meals_logged')::INT, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'planned_meals_logged')::NUMERIC, 0), 0), 8)::INT),
    'sleep_hours', GREATEST(COALESCE((v_old->>'sleep_hours')::NUMERIC, 0),
                      LEAST(GREATEST(COALESCE((p_metrics->>'sleep_hours')::NUMERIC, 0), 0), 16)),
    'water_goal_met', COALESCE((v_old->>'water_goal_met')::BOOLEAN, FALSE)
                      OR COALESCE((p_metrics->>'water_goal_met')::BOOLEAN, FALSE),
    'calorie_goal_met', COALESCE((v_old->>'calorie_goal_met')::BOOLEAN, FALSE)
                      OR COALESCE((p_metrics->>'calorie_goal_met')::BOOLEAN, FALSE),
    'sleep_logged', COALESCE((v_old->>'sleep_logged')::BOOLEAN, FALSE)
                      OR COALESCE((p_metrics->>'sleep_logged')::BOOLEAN, FALSE),
    'mood_checkin', COALESCE((v_old->>'mood_checkin')::BOOLEAN, FALSE)
                      OR COALESCE((p_metrics->>'mood_checkin')::BOOLEAN, FALSE),
    -- Lowest (calmest) level reported that day; 0 means none.
    'mood_level', CASE
                    WHEN COALESCE((p_metrics->>'mood_level')::INT, 0) BETWEEN 1 AND 5
                      AND COALESCE((v_old->>'mood_level')::INT, 0) BETWEEN 1 AND 5
                      THEN LEAST((p_metrics->>'mood_level')::INT, (v_old->>'mood_level')::INT)
                    WHEN COALESCE((p_metrics->>'mood_level')::INT, 0) BETWEEN 1 AND 5
                      THEN (p_metrics->>'mood_level')::INT
                    ELSE COALESCE((v_old->>'mood_level')::INT, 0)
                  END,
    'daily_goals', (
      SELECT COALESCE(jsonb_agg(DISTINCT g), '[]'::jsonb) FROM (
        SELECT jsonb_array_elements_text(COALESCE(v_old->'daily_goals', '[]'::jsonb)) AS g
        UNION
        SELECT jsonb_array_elements_text(COALESCE(p_metrics->'daily_goals', '[]'::jsonb))
      ) goals
      WHERE g IN ('steps', 'distance', 'calories', 'activeMinutes', 'workouts')),
    'weekly_goals', (
      SELECT COALESCE(jsonb_agg(DISTINCT g), '[]'::jsonb) FROM (
        SELECT jsonb_array_elements_text(COALESCE(v_old->'weekly_goals', '[]'::jsonb)) AS g
        UNION
        SELECT jsonb_array_elements_text(COALESCE(p_metrics->'weekly_goals', '[]'::jsonb))
      ) goals
      WHERE g IN ('steps', 'distance', 'calories', 'activeMinutes', 'workouts'))
  );

  INSERT INTO daily_reports (user_id, day, metrics)
  VALUES (v_user, p_day, m)
  ON CONFLICT (user_id, day) DO UPDATE SET metrics = EXCLUDED.metrics, updated_at = NOW();

  -- Daily rules: one ledger row per rule per day.
  PERFORM _award_points(v_user, p_day, 'food_log', p_day::TEXT, _rule_points('food_log', (m->>'food_logs')::INT));
  PERFORM _award_points(v_user, p_day, 'water_log', p_day::TEXT, _rule_points('water_log', (m->>'water_logs')::INT));
  PERFORM _award_points(v_user, p_day, 'water_goal', p_day::TEXT,
    _rule_points('water_goal', CASE WHEN (m->>'water_goal_met')::BOOLEAN THEN 1 ELSE 0 END));
  PERFORM _award_points(v_user, p_day, 'planned_meal', p_day::TEXT,
    _rule_points('planned_meal', LEAST((m->>'planned_meals_logged')::INT, (m->>'planned_meals')::INT)));
  PERFORM _award_points(v_user, p_day, 'diet_day', p_day::TEXT,
    _rule_points('diet_day', CASE WHEN (m->>'planned_meals')::INT > 0
      AND (m->>'planned_meals_logged')::INT >= (m->>'planned_meals')::INT THEN 1 ELSE 0 END));
  PERFORM _award_points(v_user, p_day, 'calorie_goal', p_day::TEXT,
    _rule_points('calorie_goal', CASE WHEN (m->>'calorie_goal_met')::BOOLEAN THEN 1 ELSE 0 END));
  PERFORM _award_points(v_user, p_day, 'sleep_logged', p_day::TEXT,
    _rule_points('sleep_logged', CASE WHEN (m->>'sleep_logged')::BOOLEAN THEN 1 ELSE 0 END));
  PERFORM _award_points(v_user, p_day, 'sleep_7h', p_day::TEXT,
    _rule_points('sleep_7h', CASE WHEN (m->>'sleep_hours')::NUMERIC >= 7 THEN 1 ELSE 0 END));
  PERFORM _award_points(v_user, p_day, 'mood_checkin', p_day::TEXT,
    _rule_points('mood_checkin', CASE WHEN (m->>'mood_checkin')::BOOLEAN THEN 1 ELSE 0 END));
  PERFORM _award_points(v_user, p_day, 'low_stress', p_day::TEXT,
    _rule_points('low_stress', CASE WHEN (m->>'mood_level')::INT BETWEEN 1 AND 2 THEN 1 ELSE 0 END));
  PERFORM _award_points(v_user, p_day, 'steps', p_day::TEXT,
    _rule_points('steps', (m->>'steps')::INT / 1000));
  PERFORM _award_points(v_user, p_day, 'daily_goal', p_day::TEXT,
    _rule_points('daily_goal', jsonb_array_length(m->'daily_goals')));
  PERFORM _award_points(v_user, p_day, 'workout', p_day::TEXT,
    _rule_points('workout', (m->>'workouts')::INT));

  -- Weekly goals: once per goal per week.
  v_week_start := date_trunc('week', p_day)::DATE;
  FOR v_goal IN SELECT jsonb_array_elements_text(m->'weekly_goals') LOOP
    PERFORM _award_points(v_user, p_day, 'weekly_goal', v_week_start::TEXT || ':' || v_goal,
      _rule_points('weekly_goal', 1));
  END LOOP;

  -- Streak: a day is active once it earns 20+ non-bonus points. Missed
  -- days can be covered by rest days (streak_freezes): one is earned every
  -- 7 active days in a row, up to 2. use_streak_freezes() spends them each
  -- night; this also spends them if the next active day arrives first.
  SELECT COALESCE(SUM(points), 0) INTO v_day_points FROM point_events
  WHERE user_id = v_user AND day = p_day AND category <> 'bonus';

  SELECT * INTO v_stats FROM player_stats WHERE user_id = v_user;
  v_streak := v_stats.current_streak;
  v_freezes := v_stats.streak_freezes;
  v_start := v_stats.streak_start;
  v_frozen := v_stats.frozen_days;

  IF v_day_points >= 20 THEN
    IF p_day = ANY(v_frozen) THEN
      -- A rest day turned out active after all (late sync): count it and
      -- give the rest day back.
      v_frozen := array_remove(v_frozen, p_day);
      v_freezes := LEAST(v_freezes + 1, 2);
      v_streak := v_streak + 1;
      v_counted := TRUE;
    ELSIF v_stats.last_active_day IS NULL OR p_day > v_stats.last_active_day THEN
      v_gap := p_day - v_stats.last_active_day - 1;
      IF v_gap = 0 THEN
        v_streak := v_streak + 1;
      ELSIF v_gap > 0 AND v_streak > 0 AND v_gap <= v_freezes THEN
        v_freezes := v_freezes - v_gap;
        v_freezes_used := v_gap;
        v_frozen := v_frozen || ARRAY(
          SELECT generate_series(v_stats.last_active_day + 1, p_day - 1, INTERVAL '1 day')::DATE);
        v_streak := v_streak + 1;
      ELSE
        v_streak := 1;
        v_start := p_day;
      END IF;
      v_counted := TRUE;
    END IF;
  END IF;

  IF v_counted THEN
    v_start := COALESCE(v_start, p_day - (v_streak - 1));
    IF v_streak % 7 = 0 AND v_freezes < 2 THEN
      v_freezes := v_freezes + 1;
      v_freeze_earned := TRUE;
    END IF;

    UPDATE player_stats SET
      current_streak = v_streak,
      longest_streak = GREATEST(longest_streak, v_streak),
      last_active_day = GREATEST(COALESCE(last_active_day, p_day), p_day),
      streak_start = v_start,
      streak_freezes = v_freezes,
      frozen_days = ARRAY(SELECT d FROM unnest(v_frozen) d WHERE d >= v_today - 14 ORDER BY d)
    WHERE user_id = v_user;

    -- Milestone bonuses, once per streak run (keyed by the run's first day,
    -- which rest days don't move).
    FOREACH v_milestone IN ARRAY ARRAY[3, 7, 30, 100] LOOP
      IF v_streak >= v_milestone THEN
        PERFORM _award_points(v_user, p_day, 'streak_' || v_milestone,
          v_start::TEXT, _rule_points('streak_' || v_milestone, 1));
      END IF;
    END LOOP;
  END IF;
  -- current_streak is not zeroed when a day is missed, because a late sync
  -- can still make that day active. Readers use effective_streak() instead.

  -- Badges. Bonus points can unlock point/level badges, so check twice.
  FOR i IN 1..2 LOOP
    SELECT * INTO v_stats FROM player_stats WHERE user_id = v_user;
    SELECT COALESCE(MAX(level), 1) INTO v_level FROM levels WHERE min_points <= v_stats.total_points;
    UPDATE player_stats SET level = v_level WHERE user_id = v_user;

    FOR v_badge IN
      SELECT b.* FROM badges b
      WHERE NOT EXISTS (SELECT 1 FROM user_badges ub WHERE ub.user_id = v_user AND ub.badge_code = b.code)
      ORDER BY b.sort
    LOOP
      v_value := CASE v_badge.kind
        WHEN 'streak' THEN v_stats.current_streak
        WHEN 'total_points' THEN v_stats.total_points
        WHEN 'level' THEN v_level
        WHEN 'steps_day' THEN (m->>'steps')::INT
        WHEN 'workouts_total' THEN (
          SELECT COALESCE(SUM((metrics->>'workouts')::INT), 0) FROM daily_reports WHERE user_id = v_user)
        WHEN 'source_days' THEN (
          SELECT COUNT(DISTINCT day) FROM point_events WHERE user_id = v_user AND source = v_badge.source)
        ELSE 0
      END;
      v_earned := v_value >= v_badge.threshold;

      IF v_earned THEN
        INSERT INTO user_badges (user_id, badge_code) VALUES (v_user, v_badge.code)
        ON CONFLICT DO NOTHING;
        PERFORM _award_points(v_user, p_day, 'badge', v_badge.code, v_badge.bonus_points);
        v_new_badges := v_new_badges || jsonb_build_object(
          'code', v_badge.code, 'name', v_badge.name,
          'description', v_badge.description, 'icon_key', v_badge.icon_key);
      END IF;
    END LOOP;
  END LOOP;

  SELECT * INTO v_stats FROM player_stats WHERE user_id = v_user;
  SELECT timezone INTO v_tz FROM profiles WHERE id = v_user;

  RETURN jsonb_build_object(
    'points_awarded', v_stats.total_points - v_before_total,
    'by_category', jsonb_build_object(
      'nutrition', v_stats.nutrition_points - (v_before_cat->>'nutrition')::INT,
      'lifestyle', v_stats.lifestyle_points - (v_before_cat->>'lifestyle')::INT,
      'fitness', v_stats.fitness_points - (v_before_cat->>'fitness')::INT),
    'total_points', v_stats.total_points,
    'level', v_stats.level,
    'level_up', v_stats.level > v_before_level,
    'streak', effective_streak(v_stats.current_streak, v_stats.last_active_day, v_tz),
    'streak_freezes', v_stats.streak_freezes,
    'freezes_used', v_freezes_used,
    'freeze_earned', v_freeze_earned,
    'new_badges', v_new_badges
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public._submit_daily_report_core(DATE, JSONB) FROM PUBLIC, anon, authenticated;

-- The wrapper from 20261021_profile_login_report_hardening.sql, plus
-- `capped` in the result.
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
  v_capped BOOLEAN;
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

  -- Tells the app a figure went past the uploaded logs, so it reports the
  -- day again once its uploads land instead of treating it as sent.
  v_capped :=
       COALESCE((m->>'water_logs')::NUMERIC, 0) > v_water
    OR COALESCE((m->>'food_logs')::NUMERIC, 0) > v_meals
    OR COALESCE((m->>'planned_meals_logged')::NUMERIC, 0) > v_meals
    OR COALESCE((m->>'workouts')::NUMERIC, 0) > v_workouts
    OR (COALESCE((m->>'water_goal_met')::BOOLEAN, FALSE) AND v_water = 0)
    OR (COALESCE((m->>'calorie_goal_met')::BOOLEAN, FALSE) AND v_meals = 0);

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

  RETURN _submit_daily_report_core(p_day, m) || jsonb_build_object('capped', v_capped);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_daily_report(DATE, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_daily_report(DATE, JSONB) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_badge_progress()
RETURNS TABLE (code TEXT, value NUMERIC, threshold NUMERIC)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH s AS (
    SELECT ps.*, p.timezone FROM player_stats ps
    LEFT JOIN profiles p ON p.id = ps.user_id
    WHERE ps.user_id = auth.uid()
  )
  SELECT
    b.code,
    COALESCE(CASE b.kind
      WHEN 'streak' THEN (SELECT effective_streak(current_streak, last_active_day, timezone) FROM s)
      WHEN 'total_points' THEN (SELECT total_points FROM s)
      WHEN 'level' THEN (SELECT level FROM s)
      WHEN 'steps_day' THEN (
        SELECT MAX((metrics->>'steps')::INT) FROM daily_reports WHERE user_id = auth.uid())
      WHEN 'workouts_total' THEN (
        SELECT SUM((metrics->>'workouts')::INT) FROM daily_reports WHERE user_id = auth.uid())
      WHEN 'source_days' THEN (
        SELECT COUNT(DISTINCT day) FROM point_events
        WHERE user_id = auth.uid() AND source = b.source)
    END, 0)::NUMERIC,
    b.threshold::NUMERIC
  FROM badges b
  WHERE auth.uid() IS NOT NULL;
$$;

REVOKE EXECUTE ON FUNCTION public.get_badge_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_badge_progress() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Friends: streaks in the friend's day, cheers once per sender's day
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.send_cheer(p_friend UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_actor JSONB;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_friend = v_user THEN RAISE EXCEPTION 'cannot_cheer_self'; END IF;
  IF NOT _are_friends(v_user, p_friend) THEN RAISE EXCEPTION 'not_friends'; END IF;

  INSERT INTO friend_cheers (sender_id, recipient_id, day)
  VALUES (v_user, p_friend,
          user_today((SELECT timezone FROM profiles WHERE id = v_user)))
  ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RAISE EXCEPTION 'already_cheered'; END IF;

  v_actor := COALESCE(_notification_actor(v_user), '{}'::jsonb);
  INSERT INTO notifications (user_id, type, title, body, actor_id, data)
  VALUES (
    p_friend, 'cheer', 'New cheer',
    '@' || COALESCE(v_actor->>'username', 'A friend') || ' cheered you on',
    v_user,
    v_actor || jsonb_build_object('route', 'friends')
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_cheer(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_cheer(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_player_profile(p_user UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_result JSONB;
  v_private BOOLEAN;
  v_today DATE;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_user <> v_user AND NOT _are_friends(v_user, p_user) THEN
    RAISE EXCEPTION 'not_friends';
  END IF;

  SELECT p_user <> v_user AND NOT p.leaderboard_visible
  INTO v_private
  FROM profiles p WHERE p.id = p_user;
  IF v_private IS NULL THEN RAISE EXCEPTION 'user_not_found'; END IF;
  -- Cheers are once per day of the sender (send_cheer).
  v_today := user_today((SELECT timezone FROM profiles WHERE id = v_user));

  SELECT jsonb_build_object(
    'user_id', p.id,
    'username', COALESCE(p.username, 'VitalUp user'),
    'display_name', p.display_name,
    'avatar_url', p.avatar_url,
    'level', COALESCE(ps.level, 1),
    'private', v_private,
    'cheered_today', p.id <> v_user AND EXISTS (
      SELECT 1 FROM friend_cheers c
      WHERE c.sender_id = v_user AND c.recipient_id = p.id
        AND c.day = v_today
    )
  ) || CASE WHEN v_private THEN '{}'::jsonb ELSE jsonb_build_object(
    'total_points', COALESCE(ps.total_points, 0),
    'nutrition_points', COALESCE(ps.nutrition_points, 0),
    'lifestyle_points', COALESCE(ps.lifestyle_points, 0),
    'fitness_points', COALESCE(ps.fitness_points, 0),
    'bonus_points', COALESCE(ps.bonus_points, 0),
    'current_streak',
      COALESCE(effective_streak(ps.current_streak, ps.last_active_day, p.timezone), 0),
    'longest_streak', COALESCE(ps.longest_streak, 0),
    'badge_count', (SELECT COUNT(*) FROM user_badges ub WHERE ub.user_id = p.id),
    'badges', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.earned_at DESC)
      FROM (
        SELECT b.code, b.name, b.description, b.icon_key, ub.earned_at
        FROM user_badges ub
        JOIN badges b ON b.code = ub.badge_code
        WHERE ub.user_id = p.id
        ORDER BY ub.earned_at DESC
        LIMIT 6
      ) x
    ), '[]'::jsonb)
  ) END
  INTO v_result
  FROM profiles p
  LEFT JOIN player_stats ps ON ps.user_id = p.id
  WHERE p.id = p_user;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_player_profile(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_player_profile(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. Live leaderboards end with their period
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._leaderboard_ranked(p_community UUID, p_period TEXT, p_category TEXT)
RETURNS TABLE (
  rank BIGINT, user_id UUID, username TEXT, display_name TEXT,
  avatar_url TEXT, points BIGINT, level INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_type TEXT;
  v_categories TEXT[];
  v_from DATE;
  v_to DATE;
BEGIN
  SELECT c.type, c.score_categories INTO v_type, v_categories FROM communities c WHERE c.id = p_community;
  IF v_type IS NULL THEN
    RAISE EXCEPTION 'community not found';
  END IF;
  IF p_category IS NOT NULL THEN
    v_categories := ARRAY[p_category];
  END IF;

  v_from := CASE p_period
    WHEN 'week' THEN date_trunc('week', gamification_today())::DATE
    WHEN 'month' THEN date_trunc('month', gamification_today())::DATE
    ELSE NULL
  END;
  -- Upper bound too: zones ahead of India already report tomorrow, which
  -- belongs to the next period (the awards count it there).
  v_to := CASE p_period
    WHEN 'week' THEN v_from + 7
    WHEN 'month' THEN (v_from + INTERVAL '1 month')::DATE
    ELSE NULL
  END;

  RETURN QUERY
  WITH members AS (
    SELECT p.id AS uid FROM profiles p
    WHERE v_type = 'global' AND (p.leaderboard_visible OR p.id = auth.uid())
    UNION
    SELECT cm.user_id FROM community_members cm
    JOIN profiles p ON p.id = cm.user_id
    WHERE v_type <> 'global' AND cm.community_id = p_community
      AND (p.leaderboard_visible OR p.id = auth.uid())
  ),
  scores AS (
    SELECT e.user_id AS uid, SUM(e.points)::BIGINT AS pts
    FROM point_events e
    JOIN members mb ON mb.uid = e.user_id
    WHERE (v_from IS NULL OR e.day >= v_from)
      AND (v_to IS NULL OR e.day < v_to)
      AND (v_categories IS NULL OR e.category = ANY(v_categories))
    GROUP BY e.user_id
    HAVING SUM(e.points) > 0
  )
  SELECT
    RANK() OVER (ORDER BY s.pts DESC) AS rank,
    s.uid, p.username, p.display_name, p.avatar_url, s.pts,
    COALESCE(ps.level, 1)
  FROM scores s
  JOIN profiles p ON p.id = s.uid
  LEFT JOIN player_stats ps ON ps.user_id = s.uid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public._leaderboard_ranked(UUID, TEXT, TEXT) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_friends_leaderboard(
  p_period TEXT DEFAULT 'week',
  p_category TEXT DEFAULT NULL
)
RETURNS TABLE (
  rank BIGINT, user_id UUID, username TEXT, display_name TEXT,
  avatar_url TEXT, points BIGINT, level INTEGER, is_me BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_from DATE := CASE p_period
    WHEN 'week' THEN date_trunc('week', gamification_today())::DATE
    WHEN 'month' THEN date_trunc('month', gamification_today())::DATE
    ELSE NULL
  END;
  v_to DATE := CASE p_period
    WHEN 'week' THEN date_trunc('week', gamification_today())::DATE + 7
    WHEN 'month' THEN (date_trunc('month', gamification_today()) + INTERVAL '1 month')::DATE
    ELSE NULL
  END;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  RETURN QUERY
  WITH members AS (
    SELECT auth.uid() AS uid
    UNION
    SELECT CASE WHEN f.requester_id = auth.uid() THEN f.addressee_id ELSE f.requester_id END
    FROM friendships f
    WHERE f.status = 'accepted' AND auth.uid() IN (f.requester_id, f.addressee_id)
  ),
  scores AS (
    SELECT mb.uid, COALESCE(SUM(e.points), 0)::BIGINT AS pts
    FROM members mb
    LEFT JOIN point_events e ON e.user_id = mb.uid
      AND (v_from IS NULL OR e.day >= v_from)
      AND (v_to IS NULL OR e.day < v_to)
      AND (p_category IS NULL OR e.category = p_category)
    GROUP BY mb.uid
  )
  SELECT
    CASE WHEN s.pts > 0 THEN RANK() OVER (ORDER BY s.pts DESC) END,
    s.uid, p.username, p.display_name, p.avatar_url, s.pts,
    COALESCE(ps.level, 1), s.uid = auth.uid()
  FROM scores s
  JOIN profiles p ON p.id = s.uid
  LEFT JOIN player_stats ps ON ps.user_id = s.uid
  ORDER BY s.pts DESC, p.username;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_friends_leaderboard(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_friends_leaderboard(TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Awards wait for the wider late window (weeks on Thursday, months on
--    the 4th; AwardRules.lateDays in the app)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.finalize_due_community_awards()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff DATE := gamification_today() - 3;
BEGIN
  PERFORM finalize_community_awards(
    'week', (date_trunc('week', v_cutoff) - INTERVAL '7 days')::DATE);
  PERFORM finalize_community_awards(
    'month', (date_trunc('month', v_cutoff) - INTERVAL '1 month')::DATE);
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_due_community_awards() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. Weekly summaries: India when no zone was reported
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.send_weekly_summaries()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sent INTEGER;
BEGIN
  WITH due AS (
    -- Users for whom it's now Sunday 18:xx locally.
    SELECT p.id AS user_id,
           (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - 6 AS week_start,
           (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + 1 AS week_end,
           COALESCE(p.timezone, 'Asia/Kolkata') AS tz
    FROM profiles p
    WHERE EXTRACT(DOW FROM now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata')) = 0
      AND EXTRACT(HOUR FROM now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata')) = 18
      AND NOT EXISTS (
        SELECT 1 FROM weekly_summaries w
        WHERE w.user_id = p.id
          AND w.week_start = (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - 6
      )
  ),
  bounds AS (
    SELECT d.*,
           (d.week_start::timestamp AT TIME ZONE d.tz) AS from_ts,
           (d.week_end::timestamp AT TIME ZONE d.tz) AS to_ts
    FROM due d
  ),
  stats AS (
    SELECT b.user_id, b.week_start,
      (SELECT COUNT(*) FROM activity_sessions a
        WHERE a.user_id = b.user_id AND a.deleted_at IS NULL
          AND a.start_time >= b.from_ts AND a.start_time < b.to_ts) AS workouts,
      (SELECT COALESCE(SUM((a.data->>'totalDurationSeconds')::int), 0) / 60
         FROM activity_sessions a
        WHERE a.user_id = b.user_id AND a.deleted_at IS NULL
          AND a.start_time >= b.from_ts AND a.start_time < b.to_ts) AS active_minutes,
      (SELECT ROUND(AVG(s.duration_minutes)) FROM sleep_logs s
        WHERE s.user_id = b.user_id AND s.deleted_at IS NULL
          AND s.end_time >= b.from_ts AND s.end_time < b.to_ts) AS avg_sleep_minutes,
      (SELECT COALESCE(SUM(w.amount_ml), 0) FROM water_logs w
        WHERE w.user_id = b.user_id AND w.deleted_at IS NULL
          AND w.logged_at >= b.from_ts AND w.logged_at < b.to_ts) AS water_ml,
      (SELECT COUNT(*) FROM meal_logs m
        WHERE m.user_id = b.user_id AND m.deleted_at IS NULL
          AND m.captured_at >= b.from_ts AND m.captured_at < b.to_ts) AS meals,
      (SELECT COALESCE(SUM(e.points), 0) FROM point_events e
        WHERE e.user_id = b.user_id
          AND e.day >= b.week_start AND e.day < b.week_end) AS points
    FROM bounds b
  ),
  msg AS (
    SELECT s.*,
      NULLIF(concat_ws(' · ',
        CASE WHEN s.workouts > 0 THEN
          s.workouts || CASE WHEN s.workouts = 1 THEN ' workout' ELSE ' workouts' END
          || ' (' || s.active_minutes || ' min)' END,
        CASE WHEN s.avg_sleep_minutes IS NOT NULL THEN
          (s.avg_sleep_minutes::int / 60) || 'h ' || (s.avg_sleep_minutes::int % 60)
          || 'm sleep on average' END,
        CASE WHEN s.water_ml > 0 THEN
          ROUND(s.water_ml / 1000.0, 1) || ' L water' END,
        CASE WHEN s.meals > 0 THEN s.meals || ' meals logged' END,
        CASE WHEN s.points > 0 THEN '+' || s.points || ' points' END
      ), '') AS body
    FROM stats s
  ),
  recorded AS (
    INSERT INTO weekly_summaries (user_id, week_start, stats)
    SELECT t.user_id, t.week_start, jsonb_build_object(
      'workouts', t.workouts, 'active_minutes', t.active_minutes,
      'avg_sleep_minutes', t.avg_sleep_minutes, 'water_ml', t.water_ml,
      'meals', t.meals, 'points', t.points)
    FROM msg t
    ON CONFLICT DO NOTHING
    RETURNING user_id, week_start
  )
  INSERT INTO notifications (user_id, type, title, body, data)
  SELECT t.user_id, 'announcement',
    CASE WHEN t.body IS NULL THEN 'A fresh week starts tomorrow'
         ELSE 'Your week in review' END,
    COALESCE(t.body,
      'Nothing logged this week. Small steps count — start with a glass of water tomorrow.'),
    jsonb_build_object('route', 'weekly-summary', 'week_start', t.week_start)
  FROM msg t
  JOIN recorded r USING (user_id, week_start);

  GET DIAGNOSTICS v_sent = ROW_COUNT;
  RETURN v_sent;
END;
$$;

REVOKE ALL ON FUNCTION public.send_weekly_summaries() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. email_send_log: keep only the rate-limit window
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prune_email_send_log()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- send-email counts a recipient's mails over the last day.
  DELETE FROM email_send_log WHERE sent_at < now() - INTERVAL '2 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.prune_email_send_log() FROM PUBLIC, anon, authenticated;

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  PERFORM cron.unschedule('prune-email-send-log');
EXCEPTION WHEN OTHERS THEN
  NULL; -- not scheduled yet
END;
$$;

SELECT cron.schedule(
  'prune-email-send-log',
  '15 3 * * *',
  $$SELECT public.prune_email_send_log()$$
);
