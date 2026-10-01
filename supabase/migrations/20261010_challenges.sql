-- Friend challenges: a short contest (3, 7 or 14 days) between friends on
-- active minutes, distance or number of workouts.
--
-- Scores are computed on the server from the synced workouts
-- (activity_sessions, 20261008_synced_logs.sql), never sent by the client,
-- so a challenge can't be won by editing the app.
--
-- Clients read through get_challenges() / get_challenge_leaderboard() and
-- write only through the functions below.

CREATE TABLE IF NOT EXISTS public.challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  metric TEXT NOT NULL CHECK (metric IN ('active_minutes', 'distance_km', 'workouts')),
  starts_at TIMESTAMP WITH TIME ZONE NOT NULL,
  ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS public.challenge_participants (
  challenge_id UUID REFERENCES public.challenges(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'joined', 'declined')),
  responded_at TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (challenge_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_challenge_participants_user
  ON public.challenge_participants (user_id);

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;
-- No policies: all access goes through the SECURITY DEFINER functions.
REVOKE ALL ON public.challenges, public.challenge_participants FROM anon, authenticated;

-- Challenge invites appear in the notification inbox.
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type IN
  ('friend_request', 'friend_accepted', 'badge', 'level_up', 'streak', 'announcement', 'challenge'));

-- ---------------------------------------------------------------------------
-- A participant's score: computed from their synced workouts.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._challenge_score(p_challenge UUID, p_user UUID)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    CASE c.metric
      WHEN 'workouts' THEN COUNT(a.id)::numeric
      WHEN 'active_minutes' THEN
        FLOOR(SUM((a.data->>'totalDurationSeconds')::numeric) / 60)
      WHEN 'distance_km' THEN
        ROUND(SUM((a.data->>'totalDistanceMeters')::numeric) / 1000, 1)
    END, 0)
  FROM challenges c
  LEFT JOIN activity_sessions a
    ON a.user_id = p_user
   AND a.deleted_at IS NULL
   AND a.end_time IS NOT NULL
   AND a.start_time >= c.starts_at
   AND a.start_time < c.ends_at
  WHERE c.id = p_challenge
  GROUP BY c.metric;
$$;

-- ---------------------------------------------------------------------------
-- Create: the caller challenges up to 9 accepted friends, starting now.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_challenge(
  p_metric TEXT,
  p_days INTEGER,
  p_friend_ids UUID[]
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
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_metric NOT IN ('active_minutes', 'distance_km', 'workouts') THEN
    RAISE EXCEPTION 'invalid_metric';
  END IF;
  IF p_days NOT IN (3, 7, 14) THEN RAISE EXCEPTION 'invalid_duration'; END IF;

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

  INSERT INTO challenges (creator_id, metric, starts_at, ends_at)
  VALUES (v_user, p_metric, now(), now() + make_interval(days => p_days))
  RETURNING id INTO v_id;

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
                       ELSE 'workouts' END
      || ' in ' || p_days || ' days',
    v_user,
    v_actor || jsonb_build_object('challenge_id', v_id, 'route', 'challenges')
  FROM unnest(v_friends) AS friend;

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Join or decline an invite.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_challenge(p_challenge UUID, p_accept BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE challenge_participants p
  SET status = CASE WHEN p_accept THEN 'joined' ELSE 'declined' END,
      responded_at = now()
  FROM challenges c
  WHERE p.challenge_id = p_challenge AND p.user_id = auth.uid()
    AND p.status = 'invited' AND c.id = p.challenge_id AND c.ends_at > now();
  IF NOT FOUND THEN RAISE EXCEPTION 'invite_not_found'; END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- The caller's challenges (invited or joined), newest first, with their
-- own score and rank among joined participants.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_challenges()
RETURNS TABLE (
  id UUID, metric TEXT, starts_at TIMESTAMP WITH TIME ZONE,
  ends_at TIMESTAMP WITH TIME ZONE, creator_username TEXT,
  my_status TEXT, participants INTEGER, my_score NUMERIC, my_rank INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH mine AS (
    SELECT c.*, p.status AS my_status
    FROM challenges c
    JOIN challenge_participants p ON p.challenge_id = c.id AND p.user_id = auth.uid()
    WHERE p.status <> 'declined'
  ),
  scores AS (
    SELECT p.challenge_id, p.user_id, _challenge_score(p.challenge_id, p.user_id) AS score
    FROM challenge_participants p
    WHERE p.status = 'joined' AND p.challenge_id IN (SELECT m.id FROM mine m)
  ),
  ranked AS (
    SELECT s.*, RANK() OVER (PARTITION BY s.challenge_id ORDER BY s.score DESC)::int AS rnk
    FROM scores s
  )
  SELECT m.id, m.metric, m.starts_at, m.ends_at,
         COALESCE(pr.username, 'VitalUp user'),
         m.my_status,
         (SELECT COUNT(*)::int FROM scores s WHERE s.challenge_id = m.id),
         r.score, r.rnk
  FROM mine m
  LEFT JOIN profiles pr ON pr.id = m.creator_id
  LEFT JOIN ranked r ON r.challenge_id = m.id AND r.user_id = auth.uid()
  ORDER BY m.ends_at > now() DESC, m.created_at DESC
  LIMIT 50;
$$;

-- ---------------------------------------------------------------------------
-- Live standings of one challenge the caller is part of.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_challenge_leaderboard(p_challenge UUID)
RETURNS TABLE (
  user_id UUID, username TEXT, avatar_url TEXT, status TEXT,
  score NUMERIC, rank INTEGER, is_me BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM challenge_participants
    WHERE challenge_id = p_challenge AND challenge_participants.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'challenge_not_found';
  END IF;

  RETURN QUERY
  WITH s AS (
    SELECT p.user_id, p.status,
           CASE WHEN p.status = 'joined'
                THEN _challenge_score(p_challenge, p.user_id) END AS score
    FROM challenge_participants p
    WHERE p.challenge_id = p_challenge AND p.status <> 'declined'
  )
  SELECT s.user_id, COALESCE(pr.username, 'VitalUp user'), pr.avatar_url, s.status,
         s.score,
         CASE WHEN s.score IS NULL THEN NULL
              ELSE RANK() OVER (ORDER BY s.score DESC NULLS LAST)::int END,
         s.user_id = auth.uid()
  FROM s
  LEFT JOIN profiles pr ON pr.id = s.user_id
  ORDER BY s.score DESC NULLS LAST, pr.username;
END;
$$;

REVOKE ALL ON FUNCTION public._challenge_score(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_to_challenge(UUID, BOOLEAN) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_challenges() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_challenge_leaderboard(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_challenge(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_challenge_leaderboard(UUID) TO authenticated;
