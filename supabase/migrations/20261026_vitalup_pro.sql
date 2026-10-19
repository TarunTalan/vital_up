-- VitalUp Pro (RevenueCat subscriptions).
--
-- 1. subscriptions: where the row came from, whether the plan renews, and
--    the time of the newest webhook event applied (events can arrive out of
--    order; without a RevenueCat secret key the webhook trusts the event and
--    must not let an older one undo a newer one). Rows are still written
--    only by edge functions (service role); users read their own.
-- 2. consume_ai_quota takes an optional Pro limit. NULL keeps the old
--    behaviour (Pro is unlimited, -1) for functions deployed before this;
--    a number makes Pro a fair-use cap that is counted like the free one,
--    so one Pro account can't spend the whole provider budget.
-- 3. get_remaining_scans: free photo scans drop from 25 to 5 a day.

ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS source TEXT;
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS will_renew BOOLEAN;
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS last_event_at TIMESTAMP WITH TIME ZONE;

-- Service-written only (20261020 already revoked writes; repeated here so
-- this file holds on its own). Users keep SELECT on their own row through
-- the "Users can read own subscription" policy.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.subscriptions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.subscriptions FROM anon;
GRANT SELECT ON public.subscriptions TO authenticated;
GRANT ALL ON public.subscriptions TO service_role;

DROP POLICY IF EXISTS "Users can read own subscription" ON public.subscriptions;
CREATE POLICY "Users can read own subscription"
  ON public.subscriptions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Edge functions ask it directly to tell a refused user whether Pro would
-- help (the 429 body's `upgradable`).
GRANT EXECUTE ON FUNCTION public.is_premium_user(UUID) TO service_role;

-- Dropped rather than replaced: a 3- and a 4-argument version side by side
-- would make PostgREST calls with three named arguments ambiguous.
DROP FUNCTION IF EXISTS public.consume_ai_quota(UUID, TEXT, INTEGER);

-- Atomically reserves one use of [p_feature] for today.
-- Returns uses remaining after this one, -1 when unlimited (Pro without
-- [p_pro_limit]), or NULL when the day's limit is already reached (nothing
-- is reserved). Pro users are counted against [p_pro_limit] when given.
CREATE OR REPLACE FUNCTION public.consume_ai_quota(
  p_user_id UUID,
  p_feature TEXT,
  p_daily_limit INTEGER,
  p_pro_limit INTEGER DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
  v_limit INTEGER := p_daily_limit;
BEGIN
  IF public.is_premium_user(p_user_id) THEN
    IF p_pro_limit IS NULL THEN
      RETURN -1;
    END IF;
    v_limit := p_pro_limit;
  END IF;

  INSERT INTO ai_usage_daily (user_id, feature, day, use_count)
  SELECT p_user_id, p_feature, ai_quota_day(), 1
  WHERE v_limit > 0
  ON CONFLICT (user_id, feature, day)
  DO UPDATE SET use_count = ai_usage_daily.use_count + 1, updated_at = NOW()
  WHERE ai_usage_daily.use_count < v_limit
  RETURNING use_count INTO v_count;

  IF v_count IS NULL OR v_count > v_limit THEN
    RETURN NULL;
  END IF;
  RETURN v_limit - v_count;
END;
$$;

-- Takes an arbitrary user id: edge functions (service role) only.
REVOKE EXECUTE ON FUNCTION public.consume_ai_quota(UUID, TEXT, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_quota(UUID, TEXT, INTEGER, INTEGER) TO service_role;

-- Today's remaining free photo scans; -1 for Pro (the app hides the
-- counter, Pro's fair-use cap is not shown).
CREATE OR REPLACE FUNCTION public.get_remaining_scans(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_used INTEGER;
  v_limit INTEGER := 5; -- keep in sync with FREE_DAILY_SCANS in scan-food
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.is_premium_user(p_user_id) THEN
    RETURN -1;
  END IF;

  SELECT use_count INTO v_used
  FROM ai_usage_daily
  WHERE user_id = p_user_id AND feature = 'photo_scan' AND day = ai_quota_day();

  RETURN GREATEST(0, v_limit - COALESCE(v_used, 0));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_remaining_scans(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_remaining_scans(UUID) TO authenticated, service_role;
