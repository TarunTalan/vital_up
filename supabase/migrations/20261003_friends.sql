-- Friends: requests by username, accept/decline, and a friends-only
-- leaderboard. All writes go through the functions below; clients can only
-- read friendships they are part of.

CREATE TABLE IF NOT EXISTS friendships (
  requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  addressee_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (requester_id, addressee_id),
  CHECK (requester_id <> addressee_id)
);

-- One row per pair, whichever side asked.
CREATE UNIQUE INDEX IF NOT EXISTS idx_friendships_pair
  ON friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships(addressee_id);

ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own friendships" ON friendships;
CREATE POLICY "Users can read own friendships" ON friendships
  FOR SELECT USING (auth.uid() IN (requester_id, addressee_id));

-- Usernames are matched case-insensitively.
CREATE INDEX IF NOT EXISTS idx_profiles_username_lower ON public.profiles (LOWER(username));

-- Sends a request to [p_username]. If they already asked the caller, this
-- accepts it instead. Returns 'pending' or 'accepted'.
CREATE OR REPLACE FUNCTION send_friend_request(p_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_target UUID;
  v_row friendships%ROWTYPE;
  v_pending INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT id INTO v_target FROM profiles
  WHERE LOWER(username) = LOWER(BTRIM(LTRIM(BTRIM(COALESCE(p_username, '')), '@')));
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;
  IF v_target = v_user THEN
    RAISE EXCEPTION 'cannot_add_self';
  END IF;

  SELECT * INTO v_row FROM friendships
  WHERE (requester_id = v_user AND addressee_id = v_target)
     OR (requester_id = v_target AND addressee_id = v_user);

  IF FOUND THEN
    IF v_row.status = 'accepted' THEN
      RAISE EXCEPTION 'already_friends';
    END IF;
    IF v_row.requester_id = v_user THEN
      RAISE EXCEPTION 'already_requested';
    END IF;
    -- They asked first: accept.
    UPDATE friendships SET status = 'accepted', responded_at = NOW()
    WHERE requester_id = v_target AND addressee_id = v_user;
    RETURN 'accepted';
  END IF;

  -- Stops one account spamming requests.
  SELECT COUNT(*) INTO v_pending FROM friendships
  WHERE requester_id = v_user AND status = 'pending';
  IF v_pending >= 50 THEN
    RAISE EXCEPTION 'too_many_requests';
  END IF;

  INSERT INTO friendships (requester_id, addressee_id) VALUES (v_user, v_target);
  RETURN 'pending';
END;
$$;

-- Accepts or declines a request someone sent the caller.
CREATE OR REPLACE FUNCTION respond_friend_request(p_requester UUID, p_accept BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_accept THEN
    UPDATE friendships SET status = 'accepted', responded_at = NOW()
    WHERE requester_id = p_requester AND addressee_id = auth.uid() AND status = 'pending';
  ELSE
    DELETE FROM friendships
    WHERE requester_id = p_requester AND addressee_id = auth.uid() AND status = 'pending';
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'request_not_found';
  END IF;
END;
$$;

-- Unfriends [p_user], or cancels a request either way.
CREATE OR REPLACE FUNCTION remove_friend(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  DELETE FROM friendships
  WHERE (requester_id = auth.uid() AND addressee_id = p_user)
     OR (requester_id = p_user AND addressee_id = auth.uid());
END;
$$;

-- The caller's friends and pending requests. status is 'accepted',
-- 'incoming' (they asked the caller) or 'outgoing'.
CREATE OR REPLACE FUNCTION get_friends()
RETURNS TABLE (
  user_id UUID, username TEXT, avatar_url TEXT, level INTEGER,
  status TEXT, since TIMESTAMP WITH TIME ZONE
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.username, p.avatar_url, COALESCE(ps.level, 1),
         CASE
           WHEN f.status = 'accepted' THEN 'accepted'
           WHEN f.addressee_id = auth.uid() THEN 'incoming'
           ELSE 'outgoing'
         END,
         COALESCE(f.responded_at, f.created_at)
  FROM friendships f
  JOIN profiles p ON p.id = CASE WHEN f.requester_id = auth.uid() THEN f.addressee_id ELSE f.requester_id END
  LEFT JOIN player_stats ps ON ps.user_id = p.id
  WHERE auth.uid() IN (f.requester_id, f.addressee_id)
  ORDER BY 5, p.username;
$$;

-- The caller and their accepted friends ranked for a period. Friends see
-- each other even with leaderboard_visible off (that hides public boards).
-- Players with no points are listed last without a rank.
CREATE OR REPLACE FUNCTION get_friends_leaderboard(
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

GRANT EXECUTE ON FUNCTION send_friend_request(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION respond_friend_request(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_friend(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_friends() TO authenticated;
GRANT EXECUTE ON FUNCTION get_friends_leaderboard(TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION send_friend_request(TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION respond_friend_request(UUID, BOOLEAN) FROM anon;
REVOKE EXECUTE ON FUNCTION remove_friend(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION get_friends() FROM anon;
REVOKE EXECUTE ON FUNCTION get_friends_leaderboard(TEXT, TEXT) FROM anon;
