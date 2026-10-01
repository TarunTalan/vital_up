-- Daily fair-use quota for AI-backed features (photo scans, diet plans).
--
-- All users share one Gemini/Groq free-tier quota, so each user gets a daily
-- allowance per feature to stop one heavy user (or a script) from exhausting
-- it for everyone. Premium users are unlimited. Days roll over at midnight
-- India time, where the user base is.

CREATE TABLE IF NOT EXISTS ai_usage_daily (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  feature TEXT NOT NULL,
  day DATE NOT NULL,
  use_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, feature, day)
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_daily_day ON ai_usage_daily(day);

ALTER TABLE ai_usage_daily ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own AI usage" ON ai_usage_daily;
CREATE POLICY "Users can read own AI usage"
  ON ai_usage_daily FOR SELECT
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION ai_quota_day()
RETURNS DATE
LANGUAGE sql
STABLE
AS $$
  SELECT (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
$$;

-- Atomically reserves one use of [p_feature] for today.
-- Returns uses remaining after this one, -1 when unlimited (premium), or
-- NULL when the daily limit is already reached (nothing is reserved).
CREATE OR REPLACE FUNCTION consume_ai_quota(p_user_id UUID, p_feature TEXT, p_daily_limit INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF is_premium_user(p_user_id) THEN
    RETURN -1;
  END IF;

  INSERT INTO ai_usage_daily (user_id, feature, day, use_count)
  VALUES (p_user_id, p_feature, ai_quota_day(), 1)
  ON CONFLICT (user_id, feature, day)
  DO UPDATE SET use_count = ai_usage_daily.use_count + 1, updated_at = NOW()
  WHERE ai_usage_daily.use_count < p_daily_limit
  RETURNING use_count INTO v_count;

  IF v_count IS NULL OR v_count > p_daily_limit THEN
    RETURN NULL;
  END IF;
  RETURN p_daily_limit - v_count;
END;
$$;

-- Gives back a reserved use when the request failed on our side (provider
-- outage, no food detected), so users aren't charged for errors.
CREATE OR REPLACE FUNCTION refund_ai_quota(p_user_id UUID, p_feature TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE ai_usage_daily
  SET use_count = GREATEST(0, use_count - 1), updated_at = NOW()
  WHERE user_id = p_user_id AND feature = p_feature AND day = ai_quota_day();
END;
$$;

-- These take an arbitrary user id, so only edge functions (service role) may
-- call them; otherwise a user could spend or refund someone else's quota.
REVOKE EXECUTE ON FUNCTION consume_ai_quota(UUID, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION refund_ai_quota(UUID, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION consume_ai_quota(UUID, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION refund_ai_quota(UUID, TEXT) TO service_role;

-- get_remaining_scans previously (a) returned 0 for users with no usage row
-- yet, because SELECT INTO on zero rows yields NULL and GREATEST(0, NULL) = 0,
-- and (b) treated expired subscriptions as premium. It now reports today's
-- remaining photo scans under the fair-use cap.
CREATE OR REPLACE FUNCTION get_remaining_scans(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_used INTEGER;
  v_limit INTEGER := 25; -- keep in sync with FREE_DAILY_SCANS in scan-food
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF is_premium_user(p_user_id) THEN
    RETURN -1; -- Unlimited
  END IF;

  SELECT use_count INTO v_used
  FROM ai_usage_daily
  WHERE user_id = p_user_id AND feature = 'photo_scan' AND day = ai_quota_day();

  RETURN GREATEST(0, v_limit - COALESCE(v_used, 0));
END;
$$;
