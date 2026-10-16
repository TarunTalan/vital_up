-- Community awards: weekly medals and monthly trophies for the top 3 of
-- every community.
--
-- Leaderboards are live; this locks in a finished period. A day's points
-- can still arrive two days late (submit_daily_report accepts today - 2),
-- so a period is final once the day after it is two days back: weeks on
-- Wednesday, months on the 3rd (IST, like gamification_today()). The
-- hourly job finalises the latest due week and month once each, so a
-- missed run catches up on the next one.
--
-- Rules:
-- - Ranked like the board with no category filter (the community's own
--   score categories), members as of finalising.
-- - Players hidden from leaderboards can't place.
-- - Ties share a place (RANK()), so a place can have several winners.
-- - A community needs at least 5 players with points that period;
--   otherwise it gets no awards for it.
-- - No bonus points: the award itself is the reward.
--
-- Importance, highest first (the app orders and celebrates by it):
-- month global, month local, month interest, week global, week local,
-- week interest; then 1st, 2nd, 3rd.
--
-- Each award adds an 'award' notification (and a push).

CREATE TABLE IF NOT EXISTS public.community_awards (
  id BIGSERIAL PRIMARY KEY,
  community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  period TEXT NOT NULL CHECK (period IN ('week', 'month')),
  period_start DATE NOT NULL,
  place SMALLINT NOT NULL CHECK (place BETWEEN 1 AND 3),
  points BIGINT NOT NULL CHECK (points > 0),
  -- Players ranked in the community that period.
  players INTEGER NOT NULL CHECK (players > 0),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE (community_id, period, period_start, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_awards_user
  ON public.community_awards(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_awards_board
  ON public.community_awards(community_id, period, period_start DESC);

-- Periods already finalised, including ones where no community had enough
-- players, so they aren't retried.
CREATE TABLE IF NOT EXISTS public.community_award_periods (
  period TEXT NOT NULL CHECK (period IN ('week', 'month')),
  period_start DATE NOT NULL,
  finalized_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (period, period_start)
);

ALTER TABLE public.community_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_award_periods ENABLE ROW LEVEL SECURITY;
-- No policies: reads go through the SECURITY DEFINER functions below.
REVOKE ALL ON public.community_awards FROM anon, authenticated;
REVOKE ALL ON public.community_award_periods FROM anon, authenticated;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type IN
  ('friend_request', 'friend_accepted', 'badge', 'level_up', 'streak',
   'announcement', 'challenge', 'cheer', 'award'));

-- ---------------------------------------------------------------------------
-- Finalising
-- ---------------------------------------------------------------------------

-- Players of [p_community] with points in [p_from, p_to), best first. Same
-- membership and categories as _leaderboard_ranked, without the caller
-- exception (this runs from cron).
CREATE OR REPLACE FUNCTION public._community_period_ranked(
  p_community UUID, p_from DATE, p_to DATE
)
RETURNS TABLE (place BIGINT, user_id UUID, points BIGINT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_type TEXT;
  v_categories TEXT[];
BEGIN
  SELECT c.type, c.score_categories INTO v_type, v_categories
  FROM communities c WHERE c.id = p_community;
  IF v_type IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH members AS (
    SELECT p.id AS uid FROM profiles p
    WHERE v_type = 'global' AND p.leaderboard_visible
    UNION
    SELECT cm.user_id FROM community_members cm
    JOIN profiles p ON p.id = cm.user_id
    WHERE v_type <> 'global' AND cm.community_id = p_community
      AND p.leaderboard_visible
  ),
  scores AS (
    SELECT e.user_id AS uid, SUM(e.points)::BIGINT AS pts
    FROM point_events e
    JOIN members mb ON mb.uid = e.user_id
    WHERE e.day >= p_from AND e.day < p_to
      AND (v_categories IS NULL OR e.category = ANY(v_categories))
    GROUP BY e.user_id
    HAVING SUM(e.points) > 0
  )
  SELECT RANK() OVER (ORDER BY s.pts DESC), s.uid, s.pts
  FROM scores s;
END;
$$;

-- Awards the top 3 of every community for one period. Returns how many
-- awards were added; 0 when the period was already finalised.
CREATE OR REPLACE FUNCTION public.finalize_community_awards(
  p_period TEXT, p_start DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_min_players CONSTANT INTEGER := 5;
  v_end DATE;
  v_added INTEGER := 0;
  v_rows INTEGER;
  v_community UUID;
BEGIN
  IF p_period = 'week' THEN
    IF p_start <> date_trunc('week', p_start)::DATE THEN
      RAISE EXCEPTION 'week must start on a Monday';
    END IF;
    v_end := p_start + 7;
  ELSIF p_period = 'month' THEN
    IF p_start <> date_trunc('month', p_start)::DATE THEN
      RAISE EXCEPTION 'month must start on the 1st';
    END IF;
    v_end := (p_start + INTERVAL '1 month')::DATE;
  ELSE
    RAISE EXCEPTION 'invalid period';
  END IF;

  INSERT INTO community_award_periods (period, period_start)
  VALUES (p_period, p_start)
  ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  FOR v_community IN SELECT id FROM communities LOOP
    WITH ranked AS (
      SELECT * FROM _community_period_ranked(v_community, p_start, v_end)
    ),
    counted AS (
      SELECT r.*, COUNT(*) OVER () AS players FROM ranked r
    )
    INSERT INTO community_awards
      (community_id, user_id, period, period_start, place, points, players)
    SELECT v_community, c.user_id, p_period, p_start, c.place, c.points, c.players
    FROM counted c
    WHERE c.place <= 3 AND c.players >= v_min_players
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_added := v_added + v_rows;
  END LOOP;
  RETURN v_added;
END;
$$;

-- The latest week and month whose late reports are closed. A period is
-- closed once the day after it is two days back (today - 2).
CREATE OR REPLACE FUNCTION public.finalize_due_community_awards()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cutoff DATE := gamification_today() - 2;
BEGIN
  PERFORM finalize_community_awards(
    'week', (date_trunc('week', v_cutoff) - INTERVAL '7 days')::DATE);
  PERFORM finalize_community_awards(
    'month', (date_trunc('month', v_cutoff) - INTERVAL '1 month')::DATE);
END;
$$;

REVOKE ALL ON FUNCTION public._community_period_ranked(UUID, DATE, DATE) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_community_awards(TEXT, DATE) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finalize_due_community_awards() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_community_award()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name TEXT;
  v_type TEXT;
  v_place TEXT := CASE NEW.place WHEN 1 THEN '1st' WHEN 2 THEN '2nd' ELSE '3rd' END;
  v_when TEXT;
  v_prize TEXT;
BEGIN
  SELECT c.name, c.type INTO v_name, v_type FROM communities c WHERE c.id = NEW.community_id;
  IF NEW.period = 'month' THEN
    v_when := to_char(NEW.period_start, 'FMMonth');
    v_prize := 'a trophy';
  ELSE
    v_when := 'the week of ' || to_char(NEW.period_start, 'FMDD Mon');
    v_prize := CASE NEW.place WHEN 1 THEN 'a gold medal' WHEN 2 THEN 'a silver medal'
                              ELSE 'a bronze medal' END;
  END IF;

  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    NEW.user_id, 'award',
    v_place || ' in ' || v_name || ' for ' || v_when,
    'You earned ' || v_prize || '. See it with your badges.',
    jsonb_build_object(
      'award_id', NEW.id,
      'community_id', NEW.community_id,
      'community_name', v_name,
      'community_type', v_type,
      'period', NEW.period,
      'period_start', NEW.period_start,
      'place', NEW.place
    )
  );
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_community_award() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS community_awards_notify ON public.community_awards;
CREATE TRIGGER community_awards_notify
  AFTER INSERT ON public.community_awards
  FOR EACH ROW EXECUTE FUNCTION public.notify_community_award();

-- ---------------------------------------------------------------------------
-- Reads
-- ---------------------------------------------------------------------------

-- Winners of [p_community] for the latest finalised [p_period] (empty when
-- it had too few players). Players who now hide from leaderboards are
-- left out, except the caller.
CREATE OR REPLACE FUNCTION public.get_community_awards(
  p_community UUID,
  p_period TEXT DEFAULT 'week'
)
RETURNS TABLE (
  place INTEGER, user_id UUID, username TEXT, display_name TEXT,
  avatar_url TEXT, points BIGINT, level INTEGER, players INTEGER,
  period_start DATE, is_me BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_user UUID := auth.uid();
  v_start DATE;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_period NOT IN ('week', 'month') THEN
    RAISE EXCEPTION 'invalid period';
  END IF;

  SELECT MAX(ap.period_start) INTO v_start
  FROM community_award_periods ap WHERE ap.period = p_period;

  RETURN QUERY
  SELECT a.place::INTEGER, a.user_id, p.username, p.display_name, p.avatar_url,
         a.points, COALESCE(ps.level, 1), a.players, a.period_start,
         a.user_id = v_user
  FROM community_awards a
  JOIN profiles p ON p.id = a.user_id
  LEFT JOIN player_stats ps ON ps.user_id = a.user_id
  WHERE a.community_id = p_community
    AND a.period = p_period
    AND a.period_start = v_start
    AND (p.leaderboard_visible OR a.user_id = v_user)
  ORDER BY a.place, a.points DESC, p.username;
END;
$$;

-- Every award [p_user] has won, newest first. Other players' awards show
-- only while they appear on leaderboards.
CREATE OR REPLACE FUNCTION public.get_player_awards(p_user UUID DEFAULT NULL)
RETURNS TABLE (
  id BIGINT, community_id UUID, community_name TEXT, community_type TEXT,
  period TEXT, period_start DATE, place INTEGER, points BIGINT,
  players INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_user UUID := auth.uid();
  v_target UUID := COALESCE(p_user, auth.uid());
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF v_target <> v_user AND NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = v_target AND p.leaderboard_visible
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT a.id, a.community_id, c.name, c.type, a.period, a.period_start,
         a.place::INTEGER, a.points, a.players
  FROM community_awards a
  JOIN communities c ON c.id = a.community_id
  WHERE a.user_id = v_target
  ORDER BY a.period_start DESC, a.id DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_community_awards(UUID, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_player_awards(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_community_awards(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_player_awards(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Schedule
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  PERFORM cron.unschedule('finalize-community-awards');
EXCEPTION WHEN OTHERS THEN
  NULL; -- not scheduled yet
END;
$$;

-- Hourly so a missed run is picked up; each period runs once. :35 UTC is
-- :05 India time, so results land at 00:05 IST on the due day (the app's
-- countdown, AwardSchedule, assumes this).
SELECT cron.schedule(
  'finalize-community-awards',
  '35 * * * *',
  $$SELECT public.finalize_due_community_awards()$$
);
