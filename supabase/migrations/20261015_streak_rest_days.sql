-- Rest days (streak freezes), badge progress and more health milestone
-- badges.
--
-- A missed day used to wipe a streak. Now every 7 active days in a row earn
-- a rest day (up to 2 banked); a missed day spends one instead of breaking
-- the streak. Rest days don't add to the streak count. The hourly job
-- spends them, so every reader of last_active_day / effective_streak() sees
-- the streak as alive without changes; submit_daily_report() refunds one if
-- the "missed" day syncs late and turns out active.

ALTER TABLE player_stats
  ADD COLUMN IF NOT EXISTS streak_freezes INTEGER NOT NULL DEFAULT 0,
  -- First day of the current run; keys streak milestone bonuses.
  ADD COLUMN IF NOT EXISTS streak_start DATE,
  -- Recent days covered by a rest day (last 14 days kept).
  ADD COLUMN IF NOT EXISTS frozen_days DATE[] NOT NULL DEFAULT '{}';

ALTER TABLE player_stats DROP CONSTRAINT IF EXISTS player_stats_streak_freezes_range;
ALTER TABLE player_stats ADD CONSTRAINT player_stats_streak_freezes_range
  CHECK (streak_freezes BETWEEN 0 AND 2);

-- Existing runs: their start day, and the rest days they would have earned.
UPDATE player_stats SET
  streak_start = last_active_day - (current_streak - 1),
  streak_freezes = LEAST(current_streak / 7, 2)
WHERE streak_start IS NULL AND last_active_day IS NOT NULL AND current_streak > 0;

-- ---------------------------------------------------------------------------
-- Spending rest days
-- ---------------------------------------------------------------------------

-- Covers yesterday with a rest day for everyone whose streak would break
-- today (last active the day before yesterday). Runs hourly; only the first
-- run after midnight finds anyone. Two missed days spend two rest days on
-- consecutive nights.
CREATE OR REPLACE FUNCTION use_streak_freezes()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := gamification_today();
  v_count INTEGER;
BEGIN
  UPDATE player_stats SET
    streak_freezes = streak_freezes - 1,
    last_active_day = v_today - 1,
    frozen_days = ARRAY(
      SELECT d FROM unnest(array_append(frozen_days, v_today - 1)) d
      WHERE d >= v_today - 14 ORDER BY d)
  WHERE streak_freezes > 0
    AND current_streak > 0
    AND last_active_day = v_today - 2;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION use_streak_freezes() FROM PUBLIC, anon, authenticated;

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  PERFORM cron.unschedule('use-streak-freezes');
EXCEPTION WHEN OTHERS THEN
  NULL; -- not scheduled yet
END;
$$;

SELECT cron.schedule(
  'use-streak-freezes',
  '1 * * * *',
  $$SELECT public.use_streak_freezes()$$
);

-- ---------------------------------------------------------------------------
-- Scoring: submit_daily_report() with rest days; otherwise unchanged
-- ---------------------------------------------------------------------------

-- Reports one day's metrics and awards points. Safe to call repeatedly: the
-- day's metrics only ever go up and each rule tops up its ledger row.
--
-- p_metrics keys (all optional):
--   fitness:   steps, distance_m, active_minutes, calories, workouts,
--              daily_goals (text[] of metric names), weekly_goals (text[]),
--              week_start (date, Monday)
--   nutrition: food_logs, water_logs, water_goal_met, planned_meals,
--              planned_meals_logged, calorie_goal_met
--   lifestyle: sleep_logged, sleep_hours, mood_checkin, mood_level (1-5)
CREATE OR REPLACE FUNCTION submit_daily_report(p_day DATE, p_metrics JSONB)
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
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_day IS NULL OR p_day < v_today - 2 OR p_day > v_today + 1 THEN
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

  RETURN jsonb_build_object(
    'points_awarded', v_stats.total_points - v_before_total,
    'by_category', jsonb_build_object(
      'nutrition', v_stats.nutrition_points - (v_before_cat->>'nutrition')::INT,
      'lifestyle', v_stats.lifestyle_points - (v_before_cat->>'lifestyle')::INT,
      'fitness', v_stats.fitness_points - (v_before_cat->>'fitness')::INT),
    'total_points', v_stats.total_points,
    'level', v_stats.level,
    'level_up', v_stats.level > v_before_level,
    'streak', effective_streak(v_stats.current_streak, v_stats.last_active_day),
    'streak_freezes', v_stats.streak_freezes,
    'freezes_used', v_freezes_used,
    'freeze_earned', v_freeze_earned,
    'new_badges', v_new_badges
  );
END;
$$;

GRANT EXECUTE ON FUNCTION submit_daily_report(DATE, JSONB) TO authenticated;
REVOKE EXECUTE ON FUNCTION submit_daily_report(DATE, JSONB) FROM anon;

-- ---------------------------------------------------------------------------
-- Badge progress
-- ---------------------------------------------------------------------------

-- Where the caller stands on every badge, measured the way
-- submit_daily_report() awards them ("7 of 10 workouts"). For one-day
-- badges (steps_day) the value is the best day so far.
CREATE OR REPLACE FUNCTION get_badge_progress()
RETURNS TABLE (code TEXT, value NUMERIC, threshold NUMERIC)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH s AS (
    SELECT * FROM player_stats WHERE user_id = auth.uid()
  )
  SELECT
    b.code,
    COALESCE(CASE b.kind
      WHEN 'streak' THEN (SELECT effective_streak(current_streak, last_active_day) FROM s)
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

GRANT EXECUTE ON FUNCTION get_badge_progress() TO authenticated;
REVOKE EXECUTE ON FUNCTION get_badge_progress() FROM anon;

-- ---------------------------------------------------------------------------
-- Health milestone badges (a habit kept for a month)
-- ---------------------------------------------------------------------------

INSERT INTO badges (code, name, description, icon_key, kind, source, threshold, bonus_points, sort) VALUES
  ('goal_days_30',  'Goal Getter',     'Hit an activity goal on 30 days', 'goal_days_30',  'source_days', 'daily_goal',   30, 30, 12),
  ('food_days_30',  'Mindful Eater',   'Log your meals on 30 days',       'food_days_30',  'source_days', 'food_log',     30, 30, 32),
  ('water_days_30', 'Hydration Habit', 'Hit your water goal on 30 days',  'water_days_30', 'source_days', 'water_goal',   30, 30, 33),
  ('sleep_days_30', 'Sleep Tracker',   'Log your sleep on 30 nights',     'sleep_days_30', 'source_days', 'sleep_logged', 30, 25, 42)
ON CONFLICT (code) DO NOTHING;
