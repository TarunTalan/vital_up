-- Where the caller and their friends stand inside communities.
--
-- get_community_friend_ranks: the caller and every accepted friend ranked
-- in one community board (same ranks as get_leaderboard, so a friend at
-- #340 shows even though the first page stops at 50). Friends who turned
-- "Show me on leaderboards" off are left out, as on the public board. The
-- caller always gets a row (rank NULL without points this period).
--
-- get_my_community_standings: for each community the caller belongs to
-- (global, their city, joined interest ones), their rank, how many players
-- are ranked and how many of their friends are ranked there. Feeds the
-- Arena community tiles.

CREATE OR REPLACE FUNCTION public._my_friend_ids(p_user UUID)
RETURNS TABLE (uid UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE WHEN f.requester_id = p_user THEN f.addressee_id ELSE f.requester_id END
  FROM friendships f
  WHERE f.status = 'accepted' AND p_user IN (f.requester_id, f.addressee_id);
$$;

REVOKE EXECUTE ON FUNCTION public._my_friend_ids(UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_community_friend_ranks(
  p_community UUID,
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
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_period NOT IN ('week', 'month', 'all') THEN
    RAISE EXCEPTION 'invalid period';
  END IF;

  RETURN QUERY
  WITH ranked AS (
    SELECT * FROM _leaderboard_ranked(p_community, p_period, p_category)
  )
  SELECT r.rank, r.user_id, r.username, r.display_name, r.avatar_url,
         r.points, r.level, FALSE
  FROM ranked r
  WHERE r.user_id IN (SELECT uid FROM _my_friend_ids(v_user))
  UNION ALL
  SELECT r.rank, p.id, p.username, p.display_name, p.avatar_url,
         COALESCE(r.points, 0), COALESCE(ps.level, 1), TRUE
  FROM profiles p
  LEFT JOIN ranked r ON r.user_id = p.id
  LEFT JOIN player_stats ps ON ps.user_id = p.id
  WHERE p.id = v_user
  ORDER BY 1 NULLS LAST, 3;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_community_standings(
  p_period TEXT DEFAULT 'week'
)
RETURNS TABLE (
  community_id UUID, rank BIGINT, points BIGINT,
  ranked_count INTEGER, friend_count INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_period NOT IN ('week', 'month', 'all') THEN
    RAISE EXCEPTION 'invalid period';
  END IF;

  RETURN QUERY
  SELECT c.id,
         MAX(r.rank) FILTER (WHERE r.user_id = v_user),
         COALESCE(MAX(r.points) FILTER (WHERE r.user_id = v_user), 0)::BIGINT,
         COUNT(r.user_id)::INTEGER,
         COUNT(r.user_id) FILTER (
           WHERE r.user_id IN (SELECT uid FROM _my_friend_ids(v_user))
         )::INTEGER
  FROM communities c
  LEFT JOIN LATERAL _leaderboard_ranked(c.id, p_period, NULL) r ON TRUE
  WHERE c.type = 'global' OR EXISTS (
    SELECT 1 FROM community_members cm
    WHERE cm.community_id = c.id AND cm.user_id = v_user)
  GROUP BY c.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_community_friend_ranks(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_my_community_standings(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_community_friend_ranks(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_community_standings(TEXT) TO authenticated;
