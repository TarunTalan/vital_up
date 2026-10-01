-- Weekly summary: every Sunday at 18:00 in the user's own time zone they get
-- a notification (and push) recapping their week, linking to the in-app
-- Weekly summary screen (route "weekly-summary").
--
-- Needs pg_cron (Dashboard > Database > Extensions) and the synced log
-- tables from 20261008_synced_logs.sql.

-- ---------------------------------------------------------------------------
-- The user's time zone, reported by the app (set_my_timezone).
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS timezone TEXT;

CREATE OR REPLACE FUNCTION public.set_my_timezone(p_tz TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  -- Rejects names Postgres doesn't know (raises invalid_parameter_value).
  PERFORM now() AT TIME ZONE p_tz;
  UPDATE profiles SET timezone = p_tz
  WHERE id = auth.uid() AND timezone IS DISTINCT FROM p_tz;
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_timezone(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_timezone(TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- One row per user per week sent, so a re-run never sends twice.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.weekly_summaries (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  week_start DATE NOT NULL,
  stats JSONB NOT NULL,
  sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, week_start)
);

ALTER TABLE public.weekly_summaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own weekly summaries" ON public.weekly_summaries;
CREATE POLICY "Users can read own weekly summaries" ON public.weekly_summaries
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

REVOKE ALL ON public.weekly_summaries FROM anon;
GRANT SELECT ON public.weekly_summaries TO authenticated;

-- ---------------------------------------------------------------------------
-- Sends the summaries due this hour. Run hourly by pg_cron.
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
           (now() AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date - 6 AS week_start,
           (now() AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date + 1 AS week_end,
           COALESCE(p.timezone, 'UTC') AS tz
    FROM profiles p
    WHERE EXTRACT(DOW FROM now() AT TIME ZONE COALESCE(p.timezone, 'UTC')) = 0
      AND EXTRACT(HOUR FROM now() AT TIME ZONE COALESCE(p.timezone, 'UTC')) = 18
      AND NOT EXISTS (
        SELECT 1 FROM weekly_summaries w
        WHERE w.user_id = p.id
          AND w.week_start = (now() AT TIME ZONE COALESCE(p.timezone, 'UTC'))::date - 6
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
-- Hourly job (each user is due in exactly one hour of the week).
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  PERFORM cron.unschedule('weekly-summaries');
EXCEPTION WHEN OTHERS THEN
  NULL; -- not scheduled yet
END;
$$;

SELECT cron.schedule(
  'weekly-summaries',
  '5 * * * *',
  $$SELECT public.send_weekly_summaries()$$
);
