-- Gamification: points, score categories, levels, badges, streaks,
-- communities and leaderboards.
--
-- Health and activity data lives on the device, so the app reports a day's
-- metrics through submit_daily_report(). That function clamps implausible
-- values, awards points from point_rules into the point_events ledger and
-- updates player_stats. Clients can read their own rows but never write
-- points, stats or badges directly.
--
-- Points are kept out of `profiles` on purpose: users may update their own
-- profile row, so anything stored there would be editable by the user.

-- ---------------------------------------------------------------------------
-- Profile fields shown on leaderboards (user-editable)
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS country_code TEXT,
  ADD COLUMN IF NOT EXISTS leaderboard_visible BOOLEAN NOT NULL DEFAULT TRUE;

-- Existing avatars live in auth metadata; the app now also writes them here.
UPDATE public.profiles p
SET avatar_url = COALESCE(u.raw_user_meta_data->>'avatar_url', u.raw_user_meta_data->>'picture')
FROM auth.users u
WHERE u.id = p.id AND p.avatar_url IS NULL;

-- Days roll over at midnight India time, like the AI quota.
CREATE OR REPLACE FUNCTION gamification_today()
RETURNS DATE
LANGUAGE sql
STABLE
AS $$
  SELECT (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
$$;

-- ---------------------------------------------------------------------------
-- Catalog tables (public read, edited by admins in the dashboard)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS score_categories (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon_key TEXT,
  sort INTEGER NOT NULL DEFAULT 0
);

-- `points` is per unit (per log, per 1,000 steps, ...); a day's award for a
-- rule is LEAST(units * points, daily_cap). A NULL cap means uncapped.
CREATE TABLE IF NOT EXISTS point_rules (
  source TEXT PRIMARY KEY,
  category TEXT NOT NULL REFERENCES score_categories(code),
  name TEXT NOT NULL,
  points INTEGER NOT NULL,
  unit TEXT NOT NULL DEFAULT 'each',
  daily_cap INTEGER,
  sort INTEGER NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS levels (
  level INTEGER PRIMARY KEY,
  min_points INTEGER NOT NULL UNIQUE,
  title TEXT NOT NULL
);

-- kind decides how `threshold` is checked:
--   streak         current streak (days) >= threshold
--   total_points   lifetime points >= threshold
--   level          level >= threshold
--   steps_day      steps in a single day >= threshold
--   workouts_total lifetime workouts >= threshold
--   source_days    days that earned points from `source` >= threshold
CREATE TABLE IF NOT EXISTS badges (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_key TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN
    ('streak', 'total_points', 'level', 'steps_day', 'workouts_total', 'source_days')),
  source TEXT REFERENCES point_rules(source),
  threshold INTEGER NOT NULL,
  bonus_points INTEGER NOT NULL DEFAULT 0,
  sort INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE score_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Score categories are public" ON score_categories;
CREATE POLICY "Score categories are public" ON score_categories FOR SELECT USING (true);
DROP POLICY IF EXISTS "Point rules are public" ON point_rules;
CREATE POLICY "Point rules are public" ON point_rules FOR SELECT USING (true);
DROP POLICY IF EXISTS "Levels are public" ON levels;
CREATE POLICY "Levels are public" ON levels FOR SELECT USING (true);
DROP POLICY IF EXISTS "Badges are public" ON badges;
CREATE POLICY "Badges are public" ON badges FOR SELECT USING (true);

-- ---------------------------------------------------------------------------
-- Per-user state (owner read, written only by SECURITY DEFINER functions)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS player_stats (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_points INTEGER NOT NULL DEFAULT 0,
  nutrition_points INTEGER NOT NULL DEFAULT 0,
  lifestyle_points INTEGER NOT NULL DEFAULT 0,
  fitness_points INTEGER NOT NULL DEFAULT 0,
  bonus_points INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  last_active_day DATE,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS daily_reports (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  day DATE NOT NULL,
  metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, day)
);

-- One row per (rule, day) — or per (rule, period) for weekly goals, streak
-- runs and badges — so re-reporting the same day can never award twice.
CREATE TABLE IF NOT EXISTS point_events (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  day DATE NOT NULL,
  source TEXT NOT NULL,
  category TEXT NOT NULL REFERENCES score_categories(code),
  ref TEXT NOT NULL,
  points INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, source, ref)
);

CREATE INDEX IF NOT EXISTS idx_point_events_day_user ON point_events(day, user_id, category);
CREATE INDEX IF NOT EXISTS idx_point_events_user_day ON point_events(user_id, day DESC);

CREATE TABLE IF NOT EXISTS user_badges (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  badge_code TEXT REFERENCES badges(code) ON DELETE CASCADE NOT NULL,
  earned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, badge_code)
);

ALTER TABLE player_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own stats" ON player_stats;
CREATE POLICY "Users can read own stats" ON player_stats FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can read own reports" ON daily_reports;
CREATE POLICY "Users can read own reports" ON daily_reports FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can read own point events" ON point_events;
CREATE POLICY "Users can read own point events" ON point_events FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can read own badges" ON user_badges;
CREATE POLICY "Users can read own badges" ON user_badges FOR SELECT USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Communities
-- ---------------------------------------------------------------------------

-- `global` has no membership rows (everyone is in it). `local` communities
-- are created by set_my_city(). `score_categories` limits which categories
-- an interest community ranks on; NULL ranks on the total score.
CREATE TABLE IF NOT EXISTS communities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('global', 'local', 'interest')),
  city TEXT,
  country_code TEXT,
  description TEXT,
  icon_key TEXT,
  score_categories TEXT[],
  member_count INTEGER NOT NULL DEFAULT 0,
  sort INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS community_members (
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (community_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_members(user_id);

ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Communities are public" ON communities;
CREATE POLICY "Communities are public" ON communities FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can read own memberships" ON community_members;
CREATE POLICY "Users can read own memberships" ON community_members
  FOR SELECT USING (auth.uid() = user_id);

-- Interest communities are joined directly; local ones only via set_my_city().
DROP POLICY IF EXISTS "Users can join interest communities" ON community_members;
CREATE POLICY "Users can join interest communities" ON community_members
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM communities c WHERE c.id = community_id AND c.type = 'interest')
  );

DROP POLICY IF EXISTS "Users can leave interest communities" ON community_members;
CREATE POLICY "Users can leave interest communities" ON community_members
  FOR DELETE USING (
    auth.uid() = user_id
    AND EXISTS (SELECT 1 FROM communities c WHERE c.id = community_id AND c.type = 'interest')
  );

CREATE OR REPLACE FUNCTION sync_community_member_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE communities SET member_count = member_count + 1 WHERE id = NEW.community_id;
  ELSE
    UPDATE communities SET member_count = GREATEST(0, member_count - 1) WHERE id = OLD.community_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS community_members_count ON community_members;
CREATE TRIGGER community_members_count
  AFTER INSERT OR DELETE ON community_members
  FOR EACH ROW EXECUTE FUNCTION sync_community_member_count();

-- ---------------------------------------------------------------------------
-- Seed data
-- ---------------------------------------------------------------------------

INSERT INTO score_categories (code, name, icon_key, sort) VALUES
  ('nutrition', 'Nutrition', 'nutrition', 1),
  ('lifestyle', 'Lifestyle', 'lifestyle', 2),
  ('fitness', 'Fitness', 'fitness', 3),
  ('bonus', 'Bonus', 'bonus', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO point_rules (source, category, name, points, unit, daily_cap, sort) VALUES
  ('food_log',      'nutrition', 'Log a meal or food',               3, 'each log',     15,  1),
  ('water_log',     'nutrition', 'Log water',                        1, 'each log',      8,  2),
  ('water_goal',    'nutrition', 'Hit your water goal',              5, 'per day',       5,  3),
  ('planned_meal',  'nutrition', 'Log a meal from your diet plan',   2, 'each meal',    10,  4),
  ('diet_day',      'nutrition', 'Log every meal in your diet plan', 15, 'per day',     15,  5),
  ('calorie_goal',  'nutrition', 'Stay within 10% of calorie goal',  10, 'per day',     10,  6),
  ('sleep_logged',  'lifestyle', 'Log your sleep',                   5, 'per day',       5, 10),
  ('sleep_7h',      'lifestyle', 'Sleep 7 hours or more',            5, 'per day',       5, 11),
  ('mood_checkin',  'lifestyle', 'Do your mood check-in',            5, 'per day',       5, 12),
  ('low_stress',    'lifestyle', 'Have a calm day',                  3, 'per day',       3, 13),
  ('steps',         'fitness',   'Walk',                             1, 'per 1,000 steps', 25, 20),
  ('daily_goal',    'fitness',   'Hit a daily activity goal',        10, 'each goal',   50, 21),
  ('weekly_goal',   'fitness',   'Hit a weekly activity goal',       50, 'each goal',  NULL, 22),
  ('workout',       'fitness',   'Complete a workout (10+ min)',     15, 'each workout', 45, 23),
  ('streak_3',      'bonus',     '3-day streak',                     20, 'per streak', NULL, 30),
  ('streak_7',      'bonus',     '7-day streak',                     50, 'per streak', NULL, 31),
  ('streak_30',     'bonus',     '30-day streak',                   200, 'per streak', NULL, 32),
  ('streak_100',    'bonus',     '100-day streak',                 1000, 'per streak', NULL, 33),
  ('badge',         'bonus',     'Earn a badge',                     0, 'per badge',  NULL, 34)
ON CONFLICT (source) DO NOTHING;

INSERT INTO levels (level, min_points, title) VALUES
  (1, 0, 'Starter'),
  (2, 100, 'Mover'),
  (3, 250, 'Go-Getter'),
  (4, 500, 'Achiever'),
  (5, 1000, 'Committed'),
  (6, 1750, 'Consistent'),
  (7, 2750, 'Dedicated'),
  (8, 4000, 'Strong'),
  (9, 6000, 'Driven'),
  (10, 9000, 'Elite'),
  (11, 12500, 'Champion'),
  (12, 16500, 'Hero'),
  (13, 21000, 'Master'),
  (14, 26000, 'Grandmaster'),
  (15, 32000, 'Legend'),
  (16, 39000, 'Titan'),
  (17, 47000, 'Mythic'),
  (18, 56000, 'Immortal'),
  (19, 66000, 'Icon'),
  (20, 77000, 'VitalUp Legend')
ON CONFLICT (level) DO NOTHING;

INSERT INTO badges (code, name, description, icon_key, kind, source, threshold, bonus_points, sort) VALUES
  ('streak_3',        'Warming Up',      'Stay active 3 days in a row',          'streak_3',        'streak',         NULL,           3,  0,  1),
  ('streak_7',        'On Fire',         'Stay active 7 days in a row',          'streak_7',        'streak',         NULL,           7,  0,  2),
  ('streak_30',       'Unstoppable',     'Stay active 30 days in a row',         'streak_30',       'streak',         NULL,          30,  0,  3),
  ('streak_100',      'Centurion',       'Stay active 100 days in a row',        'streak_100',      'streak',         NULL,         100,  0,  4),
  ('steps_10k',       '10K Day',         'Walk 10,000 steps in one day',         'steps_10k',       'steps_day',      NULL,       10000, 10, 10),
  ('steps_20k',       'Marathon Walker', 'Walk 20,000 steps in one day',         'steps_20k',       'steps_day',      NULL,       20000, 25, 11),
  ('workouts_1',      'First Workout',   'Complete your first workout',          'workouts_1',      'workouts_total', NULL,           1,  5, 20),
  ('workouts_25',     'Regular',         'Complete 25 workouts',                 'workouts_25',     'workouts_total', NULL,          25, 25, 21),
  ('workouts_100',    'Athlete',         'Complete 100 workouts',                'workouts_100',    'workouts_total', NULL,         100, 100, 22),
  ('diet_days_7',     'Plan Follower',   'Follow your diet plan for 7 days',     'diet_days_7',     'source_days',    'diet_day',     7, 25, 30),
  ('water_days_7',    'Hydrated',        'Hit your water goal on 7 days',        'water_days_7',    'source_days',    'water_goal',   7, 15, 31),
  ('sleep_days_7',    'Well Rested',     'Sleep 7+ hours on 7 nights',           'sleep_days_7',    'source_days',    'sleep_7h',     7, 15, 40),
  ('checkin_days_14', 'Mindful',         'Do your mood check-in on 14 days',     'checkin_days_14', 'source_days',    'mood_checkin', 14, 20, 41),
  ('points_1000',     'Point Collector', 'Earn 1,000 points',                    'points_1000',     'total_points',   NULL,        1000,  0, 50),
  ('level_5',         'Rising Star',     'Reach level 5',                        'level_5',         'level',          NULL,           5,  0, 51),
  ('level_10',        'Elite',           'Reach level 10',                       'level_10',        'level',          NULL,          10,  0, 52)
ON CONFLICT (code) DO NOTHING;

INSERT INTO communities (slug, name, type, description, icon_key, score_categories, sort) VALUES
  ('global',        'Global',                 'global',   'Everyone on VitalUp',                          'global',        NULL,                     0),
  ('weight-loss',   'Weight Loss',            'interest', 'Eat well, move more and stay consistent',      'weight-loss',   NULL,                     10),
  ('runners',       'Runners',                'interest', 'For everyone who loves to run',                'runners',       ARRAY['fitness'],         11),
  ('joggers',       'Joggers & Walkers',      'interest', 'Daily walks, jogs and step goals',             'joggers',       ARRAY['fitness'],         12),
  ('strength',      'Strength & Fitness',     'interest', 'Workouts, training and active minutes',        'strength',      ARRAY['fitness'],         13),
  ('dieting',       'Dieting & Clean Eating', 'interest', 'Log your meals and follow your plan',          'dieting',       ARRAY['nutrition'],       14),
  ('mindful',       'Mindful Living',         'interest', 'Better sleep, calmer days',                    'mindful',       ARRAY['lifestyle'],       15)
ON CONFLICT (slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Scoring
-- ---------------------------------------------------------------------------

-- Awards (or tops up) one ledger row and returns the points added. Callers
-- must hold the player_stats row lock for the user.
CREATE OR REPLACE FUNCTION _award_points(
  p_user UUID, p_day DATE, p_source TEXT, p_ref TEXT, p_points INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category TEXT;
  v_old INTEGER;
  v_delta INTEGER;
BEGIN
  IF p_points IS NULL OR p_points <= 0 THEN
    RETURN 0;
  END IF;

  SELECT category INTO v_category FROM point_rules WHERE source = p_source;
  IF v_category IS NULL THEN
    RETURN 0;
  END IF;

  SELECT points INTO v_old FROM point_events
  WHERE user_id = p_user AND source = p_source AND ref = p_ref;

  v_delta := p_points - COALESCE(v_old, 0);
  IF v_delta <= 0 THEN
    RETURN 0;
  END IF;

  INSERT INTO point_events (user_id, day, source, category, ref, points)
  VALUES (p_user, p_day, p_source, v_category, p_ref, p_points)
  ON CONFLICT (user_id, source, ref)
  DO UPDATE SET points = EXCLUDED.points, updated_at = NOW();

  UPDATE player_stats SET
    total_points = total_points + v_delta,
    nutrition_points = nutrition_points + CASE WHEN v_category = 'nutrition' THEN v_delta ELSE 0 END,
    lifestyle_points = lifestyle_points + CASE WHEN v_category = 'lifestyle' THEN v_delta ELSE 0 END,
    fitness_points = fitness_points + CASE WHEN v_category = 'fitness' THEN v_delta ELSE 0 END,
    bonus_points = bonus_points + CASE WHEN v_category = 'bonus' THEN v_delta ELSE 0 END,
    updated_at = NOW()
  WHERE user_id = p_user;

  RETURN v_delta;
END;
$$;

-- The streak as users should see it: still alive while yesterday or today
-- was active, otherwise broken.
CREATE OR REPLACE FUNCTION effective_streak(p_streak INTEGER, p_last_active DATE)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT CASE WHEN p_last_active >= gamification_today() - 1 THEN p_streak ELSE 0 END;
$$;

-- Points a daily rule is worth for [p_units] units, after its cap.
CREATE OR REPLACE FUNCTION _rule_points(p_source TEXT, p_units NUMERIC)
RETURNS INTEGER
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN r.daily_cap IS NULL THEN (FLOOR(GREATEST(p_units, 0)) * r.points)::INTEGER
    ELSE LEAST(FLOOR(GREATEST(p_units, 0)) * r.points, r.daily_cap)::INTEGER
  END
  FROM point_rules r
  WHERE r.source = p_source AND r.active;
$$;

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
  v_streak_start DATE;
  v_goal TEXT;
  v_milestone INTEGER;
  v_badge RECORD;
  v_earned BOOLEAN;
  v_value NUMERIC;
  v_new_badges JSONB := '[]'::jsonb;
  v_level INTEGER;
  v_week_start DATE;
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

  -- Streak: a day is active once it earns 20+ non-bonus points.
  SELECT COALESCE(SUM(points), 0) INTO v_day_points FROM point_events
  WHERE user_id = v_user AND day = p_day AND category <> 'bonus';

  SELECT * INTO v_stats FROM player_stats WHERE user_id = v_user;
  v_streak := v_stats.current_streak;

  IF v_day_points >= 20 AND (v_stats.last_active_day IS NULL OR p_day > v_stats.last_active_day) THEN
    IF v_stats.last_active_day = p_day - 1 THEN
      v_streak := v_streak + 1;
    ELSE
      v_streak := 1;
    END IF;

    UPDATE player_stats SET
      current_streak = v_streak,
      longest_streak = GREATEST(longest_streak, v_streak),
      last_active_day = p_day
    WHERE user_id = v_user;

    -- Milestone bonuses, once per streak run (keyed by the run's first day).
    v_streak_start := p_day - (v_streak - 1);
    FOREACH v_milestone IN ARRAY ARRAY[3, 7, 30, 100] LOOP
      IF v_streak >= v_milestone THEN
        PERFORM _award_points(v_user, p_day, 'streak_' || v_milestone,
          v_streak_start::TEXT, _rule_points('streak_' || v_milestone, 1));
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
    'new_badges', v_new_badges
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Leaderboards
-- ---------------------------------------------------------------------------

-- Every ranked player of a community for a period. Global ranks all visible
-- users; other communities rank their members. The caller always sees
-- themselves, even with leaderboard_visible off.
CREATE OR REPLACE FUNCTION _leaderboard_ranked(p_community UUID, p_period TEXT, p_category TEXT)
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

REVOKE EXECUTE ON FUNCTION _leaderboard_ranked(UUID, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION _award_points(UUID, DATE, TEXT, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION get_leaderboard(
  p_community UUID,
  p_period TEXT DEFAULT 'week',
  p_category TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  rank BIGINT, user_id UUID, username TEXT, display_name TEXT,
  avatar_url TEXT, points BIGINT, level INTEGER, is_me BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.rank, r.user_id, r.username, r.display_name, r.avatar_url, r.points, r.level,
         r.user_id = auth.uid()
  FROM _leaderboard_ranked(p_community, p_period, p_category) r
  ORDER BY r.rank, r.username
  LIMIT LEAST(GREATEST(p_limit, 1), 100) OFFSET GREATEST(p_offset, 0);
$$;

-- The caller's own row. rank is NULL when they have no points this period.
CREATE OR REPLACE FUNCTION get_my_rank(
  p_community UUID,
  p_period TEXT DEFAULT 'week',
  p_category TEXT DEFAULT NULL
)
RETURNS TABLE (
  rank BIGINT, user_id UUID, username TEXT, display_name TEXT,
  avatar_url TEXT, points BIGINT, level INTEGER, is_me BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.rank, p.id, p.username, p.display_name, p.avatar_url,
         COALESCE(r.points, 0), COALESCE(ps.level, 1), TRUE
  FROM profiles p
  LEFT JOIN _leaderboard_ranked(p_community, p_period, p_category) r ON r.user_id = p.id
  LEFT JOIN player_stats ps ON ps.user_id = p.id
  WHERE p.id = auth.uid();
$$;

-- Communities with the caller's membership. Global counts every profile.
CREATE OR REPLACE FUNCTION get_communities()
RETURNS TABLE (
  id UUID, slug TEXT, name TEXT, type TEXT, city TEXT, country_code TEXT,
  description TEXT, icon_key TEXT, score_categories TEXT[],
  member_count INTEGER, is_member BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT c.id, c.slug, c.name, c.type, c.city, c.country_code, c.description,
         c.icon_key, c.score_categories,
         CASE WHEN c.type = 'global' THEN (SELECT COUNT(*)::INTEGER FROM profiles) ELSE c.member_count END,
         c.type = 'global' OR EXISTS (
           SELECT 1 FROM community_members cm WHERE cm.community_id = c.id AND cm.user_id = auth.uid())
  FROM communities c
  WHERE c.type <> 'local' OR EXISTS (
    SELECT 1 FROM community_members cm WHERE cm.community_id = c.id AND cm.user_id = auth.uid())
  ORDER BY c.sort, c.name;
$$;

-- Sets the caller's city and moves them into that city's local community,
-- creating it on first use. An empty city leaves local communities.
CREATE OR REPLACE FUNCTION set_my_city(p_city TEXT, p_country_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_city TEXT := NULLIF(INITCAP(BTRIM(REGEXP_REPLACE(COALESCE(p_city, ''), '\s+', ' ', 'g'))), '');
  v_cc TEXT := NULLIF(UPPER(BTRIM(COALESCE(p_country_code, ''))), '');
  v_slug TEXT;
  v_community UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF v_city IS NOT NULL AND LENGTH(v_city) > 60 THEN
    RAISE EXCEPTION 'city too long';
  END IF;

  UPDATE profiles SET city = v_city, country_code = v_cc WHERE id = v_user;

  DELETE FROM community_members cm
  USING communities c
  WHERE cm.community_id = c.id AND c.type = 'local' AND cm.user_id = v_user;

  IF v_city IS NULL THEN
    RETURN NULL;
  END IF;

  v_slug := 'local-' || LOWER(COALESCE(v_cc, 'xx')) || '-'
    || BTRIM(REGEXP_REPLACE(LOWER(v_city), '[^a-z0-9]+', '-', 'g'), '-');

  INSERT INTO communities (slug, name, type, city, country_code, description, icon_key, sort)
  VALUES (v_slug, v_city, 'local', v_city, v_cc, 'People near you in ' || v_city, 'local', 5)
  ON CONFLICT (slug) DO UPDATE SET slug = EXCLUDED.slug
  RETURNING id INTO v_community;

  INSERT INTO community_members (community_id, user_id) VALUES (v_community, v_user)
  ON CONFLICT DO NOTHING;

  RETURN v_community;
END;
$$;

GRANT EXECUTE ON FUNCTION submit_daily_report(DATE, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_leaderboard(UUID, TEXT, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_rank(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_communities() TO authenticated;
GRANT EXECUTE ON FUNCTION set_my_city(TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION submit_daily_report(DATE, JSONB) FROM anon;
REVOKE EXECUTE ON FUNCTION get_leaderboard(UUID, TEXT, TEXT, INTEGER, INTEGER) FROM anon;
REVOKE EXECUTE ON FUNCTION get_my_rank(UUID, TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION get_communities() FROM anon;
REVOKE EXECUTE ON FUNCTION set_my_city(TEXT, TEXT) FROM anon;
