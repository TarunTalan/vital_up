-- Leaving a running challenge.
--
-- A joined participant can quit before the challenge ends. They move to
-- 'left': off the standings and the participant count, but the challenge
-- stays in their history (get_challenges() returns every status except
-- 'declined').

ALTER TABLE public.challenge_participants
  DROP CONSTRAINT IF EXISTS challenge_participants_status_check;
ALTER TABLE public.challenge_participants
  ADD CONSTRAINT challenge_participants_status_check
  CHECK (status IN ('invited', 'joined', 'declined', 'left'));

CREATE OR REPLACE FUNCTION public.leave_challenge(p_challenge UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE challenge_participants p
  SET status = 'left', responded_at = now()
  FROM challenges c
  WHERE p.challenge_id = p_challenge AND p.user_id = auth.uid()
    AND p.status = 'joined' AND c.id = p.challenge_id AND c.ends_at > now();
  IF NOT FOUND THEN RAISE EXCEPTION 'challenge_not_active'; END IF;
END;
$$;

-- Same as 20261010 but also leaves out people who left.
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
    WHERE p.challenge_id = p_challenge AND p.status IN ('invited', 'joined')
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

REVOKE ALL ON FUNCTION public.leave_challenge(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_challenge(UUID) TO authenticated;
