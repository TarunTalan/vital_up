-- Notifications: one inbox per user for friend requests, achievements
-- (badges, level-ups, streak milestones) and app announcements.
--
-- Rows are created only by the triggers and admin functions below; clients
-- can read, mark read (via mark_notifications_read) and delete their own.

CREATE TABLE IF NOT EXISTS notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN
    ('friend_request', 'friend_accepted', 'badge', 'level_up', 'streak', 'announcement')),
  title TEXT NOT NULL,
  body TEXT,
  -- Who caused it (the friend), when there is one.
  actor_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Type-specific extras: username/avatar_url for friends, code/icon_key for
  -- badges, level, streak, and an optional in-app `route` for announcements.
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  read_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications(user_id) WHERE read_at IS NULL;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
CREATE POLICY "Users can read own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications" ON notifications
  FOR DELETE USING (auth.uid() = user_id);

-- Live updates in the app.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications')
  THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  END IF;
END;
$$;

-- Marks the caller's notifications read: [p_ids], or all when NULL.
CREATE OR REPLACE FUNCTION mark_notifications_read(p_ids BIGINT[] DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  UPDATE notifications SET read_at = NOW()
  WHERE user_id = auth.uid() AND read_at IS NULL
    AND (p_ids IS NULL OR id = ANY(p_ids));
END;
$$;

-- ---------------------------------------------------------------------------
-- Admin: announcements (run from the SQL editor or with the service role)
-- ---------------------------------------------------------------------------

-- Sends one notification to [p_user].
CREATE OR REPLACE FUNCTION notify_user(
  p_user UUID, p_title TEXT, p_body TEXT DEFAULT NULL, p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS BIGINT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (p_user, 'announcement', p_title, p_body, COALESCE(p_data, '{}'::jsonb))
  RETURNING id;
$$;

-- Sends an announcement to every user; returns how many were sent.
CREATE OR REPLACE FUNCTION broadcast_notification(
  p_title TEXT, p_body TEXT DEFAULT NULL, p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  INSERT INTO notifications (user_id, type, title, body, data)
  SELECT p.id, 'announcement', p_title, p_body, COALESCE(p_data, '{}'::jsonb)
  FROM profiles p;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION notify_user(UUID, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION broadcast_notification(TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_notifications_read(BIGINT[]) TO authenticated;
REVOKE EXECUTE ON FUNCTION mark_notifications_read(BIGINT[]) FROM anon;

-- ---------------------------------------------------------------------------
-- Friends
-- ---------------------------------------------------------------------------

-- {username, avatar_url} of [p_user], for showing the friend in the inbox.
CREATE OR REPLACE FUNCTION _notification_actor(p_user UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object('username', COALESCE(p.username, 'VitalUp user'), 'avatar_url', p.avatar_url)
  FROM profiles p WHERE p.id = p_user;
$$;

CREATE OR REPLACE FUNCTION notify_friendship_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor JSONB;
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    v_actor := COALESCE(_notification_actor(NEW.requester_id), '{}'::jsonb);
    INSERT INTO notifications (user_id, type, title, body, actor_id, data)
    VALUES (NEW.addressee_id, 'friend_request', 'New friend request',
            '@' || COALESCE(v_actor->>'username', 'Someone') || ' wants to be your friend',
            NEW.requester_id, v_actor || '{"status": "pending"}'::jsonb);

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    -- The request is answered: keep it in the inbox without its buttons.
    UPDATE notifications
    SET data = data || '{"status": "accepted"}'::jsonb, read_at = COALESCE(read_at, NOW())
    WHERE user_id = NEW.addressee_id AND actor_id = NEW.requester_id AND type = 'friend_request';

    v_actor := COALESCE(_notification_actor(NEW.addressee_id), '{}'::jsonb);
    INSERT INTO notifications (user_id, type, title, body, actor_id, data)
    VALUES (NEW.requester_id, 'friend_accepted', 'Friend request accepted',
            '@' || COALESCE(v_actor->>'username', 'Someone') || ' accepted your friend request',
            NEW.addressee_id, v_actor);

  ELSIF TG_OP = 'DELETE' AND OLD.status = 'pending' THEN
    -- Declined or cancelled: the request no longer exists.
    DELETE FROM notifications
    WHERE user_id = OLD.addressee_id AND actor_id = OLD.requester_id AND type = 'friend_request';
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS friendships_notify ON friendships;
CREATE TRIGGER friendships_notify
  AFTER INSERT OR UPDATE OR DELETE ON friendships
  FOR EACH ROW EXECUTE FUNCTION notify_friendship_change();

-- ---------------------------------------------------------------------------
-- Achievements
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION notify_badge_earned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_badge badges%ROWTYPE;
BEGIN
  SELECT * INTO v_badge FROM badges WHERE code = NEW.badge_code;
  IF FOUND THEN
    INSERT INTO notifications (user_id, type, title, body, data)
    VALUES (NEW.user_id, 'badge', 'Badge unlocked: ' || v_badge.name, v_badge.description,
            jsonb_build_object('code', v_badge.code, 'icon_key', v_badge.icon_key,
                               'bonus_points', v_badge.bonus_points));
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS user_badges_notify ON user_badges;
CREATE TRIGGER user_badges_notify
  AFTER INSERT ON user_badges
  FOR EACH ROW EXECUTE FUNCTION notify_badge_earned();

CREATE OR REPLACE FUNCTION notify_level_up()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_title TEXT;
BEGIN
  SELECT title INTO v_title FROM levels WHERE level = NEW.level;
  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (NEW.user_id, 'level_up', 'You reached level ' || NEW.level,
          CASE WHEN v_title IS NULL THEN 'Keep it up!' ELSE 'You''re now a ' || v_title || '. Keep it up!' END,
          jsonb_build_object('level', NEW.level, 'level_title', v_title));
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS player_stats_level_notify ON player_stats;
CREATE TRIGGER player_stats_level_notify
  AFTER UPDATE OF level ON player_stats
  FOR EACH ROW WHEN (NEW.level > OLD.level)
  EXECUTE FUNCTION notify_level_up();

-- Streak milestone bonuses are ledger rows with source streak_<days>; each
-- is inserted once per streak run.
CREATE OR REPLACE FUNCTION notify_streak_milestone()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_days INTEGER := NULLIF(SUBSTRING(NEW.source FROM '^streak_(\d+)$'), '')::INTEGER;
BEGIN
  IF v_days IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, title, body, data)
    VALUES (NEW.user_id, 'streak', v_days || '-day streak!',
            'You earned ' || NEW.points || ' bonus points for staying active ' || v_days || ' days in a row.',
            jsonb_build_object('streak', v_days, 'points', NEW.points));
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS point_events_streak_notify ON point_events;
CREATE TRIGGER point_events_streak_notify
  AFTER INSERT ON point_events
  FOR EACH ROW WHEN (NEW.source LIKE 'streak\_%')
  EXECUTE FUNCTION notify_streak_milestone();

REVOKE EXECUTE ON FUNCTION _notification_actor(UUID) FROM PUBLIC, anon, authenticated;
