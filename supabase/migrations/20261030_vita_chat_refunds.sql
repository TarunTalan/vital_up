-- Vita chats only count when the user gets an answer. The edge function
-- still takes a use before calling the model (so parallel requests can't
-- pass the cap) and gives it back when no answer comes, but the 3 refunds a
-- day from 20261020 meant a bad afternoon of provider errors used up a free
-- user's chats. Callers now pass their own refund cap (vita-chat: the daily
-- chat limit); the default stays 3, so photo scans and diet plans, whose
-- failures a user can cause on purpose, are unchanged. A user who keeps
-- causing chat failures still spends at most limit + cap model calls a day.
--
-- Returns whether a use was given back (vita-chat then reports one more
-- left). DROP first: a second overload would make the 2-argument calls
-- ambiguous.

DROP FUNCTION IF EXISTS public.refund_ai_quota(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.refund_ai_quota(
  p_user_id UUID,
  p_feature TEXT,
  p_max_refunds INTEGER DEFAULT 3
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE ai_usage_daily
  SET use_count = GREATEST(0, use_count - 1),
      refund_count = refund_count + 1,
      updated_at = NOW()
  WHERE user_id = p_user_id
    AND feature = p_feature
    AND day = ai_quota_day()
    AND use_count > 0
    AND refund_count < LEAST(GREATEST(COALESCE(p_max_refunds, 3), 0), 200);
  RETURN FOUND;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refund_ai_quota(UUID, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_ai_quota(UUID, TEXT, INTEGER) TO service_role;
