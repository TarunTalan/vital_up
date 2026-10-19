-- Creating a challenge is safe to retry.
--
-- The app sends a request id per challenge it is creating. If the reply to
-- the first attempt is lost (flaky network) and the user tries again, the
-- same id returns the challenge already made instead of creating a second
-- one, which would also use up one of the 5 allowed a day.

ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS request_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS challenges_creator_request_id_key
  ON public.challenges (creator_id, request_id)
  WHERE request_id IS NOT NULL;

-- Replaced, not overloaded: two create_challenge functions would make a
-- call without p_request_id ambiguous. Older apps still work: the new
-- parameter defaults to NULL.
DROP FUNCTION IF EXISTS public.create_challenge(TEXT, INTEGER, UUID[]);

CREATE OR REPLACE FUNCTION public.create_challenge(
  p_metric TEXT,
  p_days INTEGER,
  p_friend_ids UUID[],
  p_request_id UUID DEFAULT NULL
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

  -- A retry of a challenge already created: hand it back.
  IF p_request_id IS NOT NULL THEN
    SELECT id INTO v_id FROM challenges
    WHERE creator_id = v_user AND request_id = p_request_id;
    IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  END IF;

  IF p_metric NOT IN ('active_minutes', 'distance_km', 'workouts') THEN
    RAISE EXCEPTION 'invalid_metric';
  END IF;
  IF p_days NOT IN (3, 7, 14) THEN RAISE EXCEPTION 'invalid_duration'; END IF;
  -- The app sends 1-9 distinct friends; refuse oversized arrays before
  -- scanning them.
  IF p_friend_ids IS NULL OR cardinality(p_friend_ids) = 0 THEN
    RAISE EXCEPTION 'no_friends_selected';
  END IF;
  IF cardinality(p_friend_ids) > 9 THEN RAISE EXCEPTION 'too_many_friends'; END IF;

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

  BEGIN
    INSERT INTO challenges (creator_id, metric, starts_at, ends_at, request_id)
    VALUES (v_user, p_metric, now(), now() + make_interval(days => p_days), p_request_id)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    -- The same request finished in parallel: return that one.
    SELECT id INTO v_id FROM challenges
    WHERE creator_id = v_user AND request_id = p_request_id;
    IF v_id IS NULL THEN RAISE; END IF;
    RETURN v_id;
  END;

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

REVOKE ALL ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[], UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[], UUID) TO authenticated;
