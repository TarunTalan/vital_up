-- Per-minute cap for AI features, on top of the daily quota.
--
-- The daily quota bounds what one account can spend, but not how fast: a
-- script could send a Pro user's 150 Vita chats in seconds and hit the
-- shared provider rate limit for everyone. Edge functions call
-- ai_burst_allowed before consume_ai_quota; it counts requests in a fixed
-- window per user and feature, on the same ai_usage_daily row.
--
-- Rows it creates have use_count 0 (only consume_ai_quota spends quota), so
-- get_remaining_scans and the daily caps read them unchanged.

ALTER TABLE public.ai_usage_daily
  ADD COLUMN IF NOT EXISTS window_start TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS window_count INTEGER NOT NULL DEFAULT 0;

-- True when this request is within [p_max] per [p_window_seconds] for the
-- user and feature (and counts it); false when the window is full.
CREATE OR REPLACE FUNCTION public.ai_burst_allowed(
  p_user_id UUID,
  p_feature TEXT,
  p_max INTEGER,
  p_window_seconds INTEGER DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF p_max IS NULL OR p_max <= 0 THEN
    RETURN TRUE;
  END IF;

  INSERT INTO ai_usage_daily (user_id, feature, day, use_count, window_start, window_count)
  VALUES (p_user_id, p_feature, ai_quota_day(), 0, NOW(), 1)
  ON CONFLICT (user_id, feature, day)
  DO UPDATE SET
    window_count = CASE
      WHEN ai_usage_daily.window_start IS NULL
        OR ai_usage_daily.window_start <= NOW() - make_interval(secs => p_window_seconds)
      THEN 1
      ELSE ai_usage_daily.window_count + 1
    END,
    window_start = CASE
      WHEN ai_usage_daily.window_start IS NULL
        OR ai_usage_daily.window_start <= NOW() - make_interval(secs => p_window_seconds)
      THEN NOW()
      ELSE ai_usage_daily.window_start
    END
  RETURNING window_count INTO v_count;

  RETURN v_count <= p_max;
END;
$$;

-- Takes an arbitrary user id: edge functions (service role) only.
REVOKE EXECUTE ON FUNCTION public.ai_burst_allowed(UUID, TEXT, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ai_burst_allowed(UUID, TEXT, INTEGER, INTEGER) TO service_role;
