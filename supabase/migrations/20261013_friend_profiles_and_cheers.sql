-- Friend profiles and cheers.
--
-- get_player_profile(): level, points per category, streaks and recent
-- badges of the caller or one of their accepted friends. Friends see each
-- other even with leaderboard_visible off (that only hides public boards),
-- same as get_friends_leaderboard().
--
-- send_cheer(): a friend sends encouragement, at most once per friend per
-- day; it lands in the recipient's inbox (and as a push) as type 'cheer'.

-- ---------------------------------------------------------------------------
-- Shared: are two users accepted friends?
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._are_friends(p_a UUID, p_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM friendships f
    WHERE f.status = 'accepted'
      AND ((f.requester_id = p_a AND f.addressee_id = p_b)
        OR (f.requester_id = p_b AND f.addressee_id = p_a))
  );
$$;

-- ---------------------------------------------------------------------------
-- Cheers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.friend_cheers (
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  day DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  PRIMARY KEY (sender_id, recipient_id, day)
);

ALTER TABLE public.friend_cheers ENABLE ROW LEVEL SECURITY;
-- No policies: all access goes through the SECURITY DEFINER functions.
REVOKE ALL ON public.friend_cheers FROM anon, authenticated;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type IN
  ('friend_request', 'friend_accepted', 'badge', 'level_up', 'streak',
   'announcement', 'challenge', 'cheer'));

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
  VALUES (v_user, p_friend, gamification_today())
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

-- ---------------------------------------------------------------------------
-- Player profile
-- ---------------------------------------------------------------------------
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
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_user <> v_user AND NOT _are_friends(v_user, p_user) THEN
    RAISE EXCEPTION 'not_friends';
  END IF;

  SELECT jsonb_build_object(
    'user_id', p.id,
    'username', COALESCE(p.username, 'VitalUp user'),
    'display_name', p.display_name,
    'avatar_url', p.avatar_url,
    'level', COALESCE(ps.level, 1),
    'total_points', COALESCE(ps.total_points, 0),
    'nutrition_points', COALESCE(ps.nutrition_points, 0),
    'lifestyle_points', COALESCE(ps.lifestyle_points, 0),
    'fitness_points', COALESCE(ps.fitness_points, 0),
    'bonus_points', COALESCE(ps.bonus_points, 0),
    'current_streak',
      COALESCE(effective_streak(ps.current_streak, ps.last_active_day), 0),
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
    ), '[]'::jsonb),
    'cheered_today', p.id <> v_user AND EXISTS (
      SELECT 1 FROM friend_cheers c
      WHERE c.sender_id = v_user AND c.recipient_id = p.id
        AND c.day = gamification_today()
    )
  )
  INTO v_result
  FROM profiles p
  LEFT JOIN player_stats ps ON ps.user_id = p.id
  WHERE p.id = p_user;

  IF v_result IS NULL THEN RAISE EXCEPTION 'user_not_found'; END IF;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public._are_friends(UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.send_cheer(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_player_profile(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_cheer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_player_profile(UUID) TO authenticated;
