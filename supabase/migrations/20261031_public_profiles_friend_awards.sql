-- Public profiles and friends' awards (Oct 22).
--
-- 1. get_player_profile for any signed-in member, not only friends. A
--    member who shows on leaderboards ("Show me on leaderboards", on by
--    default) already shares username, avatar, level and points there;
--    now their streaks and badges show in the profile preview too. Points
--    by area stay for friends (Compare is a friend feature). A hidden
--    member shares name, avatar and level only, as with friends. Cheers,
--    challenges and Compare stay friends-only (send_cheer and the
--    challenge RPCs check friendship themselves).
-- 2. When someone wins a medal or trophy, each of their friends gets one
--    'friend_award' notification (their best award of that period only:
--    global > city > interest, then place; a member topping several
--    communities sends one, not several). A deferred trigger, so it runs
--    at commit, once the run has inserted every community's awards.
--    Hidden members' wins aren't announced to friends.
-- 3. The winner's own notification points to Achievements (the app's
--    Badges page was renamed; same route).

-- ---------------------------------------------------------------------------
-- 1. Profiles
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
  v_private BOOLEAN;
  v_friend BOOLEAN;
  v_today DATE;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  v_friend := p_user = v_user OR _are_friends(v_user, p_user);
  SELECT p_user <> v_user AND NOT p.leaderboard_visible
  INTO v_private
  FROM profiles p WHERE p.id = p_user;
  IF v_private IS NULL THEN RAISE EXCEPTION 'user_not_found'; END IF;
  -- Cheers are once per day of the sender (send_cheer).
  v_today := user_today((SELECT timezone FROM profiles WHERE id = v_user));

  SELECT jsonb_build_object(
    'user_id', p.id,
    'username', COALESCE(p.username, 'VitalUp user'),
    'display_name', p.display_name,
    'avatar_url', p.avatar_url,
    'level', COALESCE(ps.level, 1),
    'private', v_private,
    'friend', v_friend,
    'cheered_today', v_friend AND p.id <> v_user AND EXISTS (
      SELECT 1 FROM friend_cheers c
      WHERE c.sender_id = v_user AND c.recipient_id = p.id
        AND c.day = v_today
    )
  ) || CASE WHEN v_private THEN '{}'::jsonb ELSE jsonb_build_object(
    'total_points', COALESCE(ps.total_points, 0),
    'current_streak',
      COALESCE(effective_streak(ps.current_streak, ps.last_active_day, p.timezone), 0),
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
  ) END || CASE WHEN v_private OR NOT v_friend THEN '{}'::jsonb ELSE jsonb_build_object(
    'nutrition_points', COALESCE(ps.nutrition_points, 0),
    'lifestyle_points', COALESCE(ps.lifestyle_points, 0),
    'fitness_points', COALESCE(ps.fitness_points, 0),
    'bonus_points', COALESCE(ps.bonus_points, 0)
  ) END
  INTO v_result
  FROM profiles p
  LEFT JOIN player_stats ps ON ps.user_id = p.id
  WHERE p.id = p_user;

  RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_player_profile(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_player_profile(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Friends hear about awards
-- ---------------------------------------------------------------------------

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type IN
  ('friend_request', 'friend_accepted', 'badge', 'level_up', 'streak',
   'announcement', 'challenge', 'cheer', 'award', 'friend_award'));

CREATE OR REPLACE FUNCTION public.notify_friends_of_award()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name TEXT;
  v_type TEXT;
  v_who TEXT;
  v_username TEXT;
  v_avatar TEXT;
  v_prize TEXT;
  v_where TEXT;
  v_place TEXT := CASE NEW.place WHEN 1 THEN '1st' WHEN 2 THEN '2nd' ELSE '3rd' END;
  v_when TEXT;
BEGIN
  -- Hidden members' wins stay with them.
  IF NOT EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = NEW.user_id AND p.leaderboard_visible
  ) THEN
    RETURN NULL;
  END IF;
  -- One per winner and period: only their best award is told.
  IF NEW.id <> (
    SELECT a.id FROM community_awards a
    JOIN communities c ON c.id = a.community_id
    WHERE a.user_id = NEW.user_id AND a.period = NEW.period
      AND a.period_start = NEW.period_start
    ORDER BY CASE c.type WHEN 'global' THEN 0 WHEN 'local' THEN 1 ELSE 2 END,
             a.place, a.id
    LIMIT 1
  ) THEN
    RETURN NULL;
  END IF;
  -- Told already (a rerun, or awards added in two transactions).
  IF EXISTS (
    SELECT 1 FROM notifications n
    WHERE n.type = 'friend_award'
      AND n.actor_id = NEW.user_id
      AND n.data->>'period' = NEW.period
      AND n.data->>'period_start' = NEW.period_start::TEXT
  ) THEN
    RETURN NULL;
  END IF;

  SELECT c.name, c.type INTO v_name, v_type FROM communities c WHERE c.id = NEW.community_id;
  SELECT COALESCE(NULLIF(p.display_name, ''), p.username, 'A friend'),
         p.username, p.avatar_url
  INTO v_who, v_username, v_avatar FROM profiles p WHERE p.id = NEW.user_id;
  v_where := CASE WHEN v_type = 'global' THEN 'all of VitalUp' ELSE v_name END;
  v_when := CASE WHEN NEW.period = 'month'
    THEN 'in ' || to_char(NEW.period_start, 'FMMonth')
    ELSE 'last week' END;
  IF NEW.period = 'month' THEN
    v_prize := CASE NEW.place WHEN 1 THEN 'the monthly trophy' ELSE 'a monthly trophy' END;
  ELSE
    v_prize := CASE NEW.place WHEN 1 THEN 'a gold medal' WHEN 2 THEN 'a silver medal'
                              ELSE 'a bronze medal' END;
  END IF;

  INSERT INTO notifications (user_id, type, title, body, actor_id, data)
  SELECT
    CASE WHEN f.requester_id = NEW.user_id THEN f.addressee_id ELSE f.requester_id END,
    'friend_award',
    v_who || ' won ' || v_prize,
    v_place || ' in ' || v_where || ' ' || v_when || '. Send a cheer?',
    NEW.user_id,
    jsonb_build_object(
      'username', v_username,
      'avatar_url', v_avatar,
      'award_id', NEW.id,
      'community_name', v_name,
      'community_type', v_type,
      'period', NEW.period,
      'period_start', NEW.period_start,
      'place', NEW.place
    )
  FROM friendships f
  WHERE f.status = 'accepted'
    AND (f.requester_id = NEW.user_id OR f.addressee_id = NEW.user_id);
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_friends_of_award() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS community_awards_notify_friends ON public.community_awards;
CREATE CONSTRAINT TRIGGER community_awards_notify_friends
  AFTER INSERT ON public.community_awards
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION public.notify_friends_of_award();

-- ---------------------------------------------------------------------------
-- 3. The winner's own notification: "See it in Achievements."
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
    'You earned ' || v_prize || '. See it in Achievements.',
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
