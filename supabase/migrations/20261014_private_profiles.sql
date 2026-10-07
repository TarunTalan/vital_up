-- Respect leaderboard_visible on friend profiles.
--
-- With "Show me on leaderboards" off, friends opening the profile get only
-- name, avatar and level plus `private: true`; points, streaks and badges
-- are left out. The caller always sees their own full profile.

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
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_user <> v_user AND NOT _are_friends(v_user, p_user) THEN
    RAISE EXCEPTION 'not_friends';
  END IF;

  SELECT p_user <> v_user AND NOT p.leaderboard_visible
  INTO v_private
  FROM profiles p WHERE p.id = p_user;
  IF v_private IS NULL THEN RAISE EXCEPTION 'user_not_found'; END IF;

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
        AND c.day = gamification_today()
    )
  ) || CASE WHEN v_private THEN '{}'::jsonb ELSE jsonb_build_object(
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
    ), '[]'::jsonb)
  ) END
  INTO v_result
  FROM profiles p
  LEFT JOIN player_stats ps ON ps.user_id = p.id
  WHERE p.id = p_user;

  RETURN v_result;
END;
$$;
