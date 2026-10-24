-- Friend requests nobody answers expire after 30 days. Deleting the row
-- also removes the addressee's notification (friendships_notify trigger),
-- frees a slot of the requester's 50 pending requests and lets either side
-- ask again.

CREATE INDEX IF NOT EXISTS idx_friendships_pending_created
  ON public.friendships (created_at) WHERE status = 'pending';

CREATE OR REPLACE FUNCTION public.expire_friend_requests()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM friendships
  WHERE status = 'pending' AND created_at < now() - INTERVAL '30 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_friend_requests() FROM PUBLIC, anon, authenticated;

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  PERFORM cron.unschedule('expire-friend-requests');
EXCEPTION WHEN OTHERS THEN
  NULL; -- not scheduled yet
END;
$$;

SELECT cron.schedule(
  'expire-friend-requests',
  '25 * * * *',
  $$SELECT public.expire_friend_requests()$$
);
