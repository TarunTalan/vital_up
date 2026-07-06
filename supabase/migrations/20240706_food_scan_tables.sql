-- Food Scan Feature Tables
-- This migration adds tables for food recognition, premium gating, and quota tracking

-- Recognition logs table - tracks which vision provider served each request
CREATE TABLE IF NOT EXISTS recognition_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  served_by TEXT NOT NULL CHECK (served_by IN ('gemini', 'groq')),
  latency_ms INTEGER NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for user_id lookups
CREATE INDEX IF NOT EXISTS idx_recognition_logs_user_id ON recognition_logs(user_id);
-- Index for created_at for analytics queries
CREATE INDEX IF NOT EXISTS idx_recognition_logs_created_at ON recognition_logs(created_at);

-- RLS policies for recognition_logs
ALTER TABLE recognition_logs ENABLE ROW LEVEL SECURITY;

-- Users can read their own logs
CREATE POLICY "Users can read own recognition logs"
  ON recognition_logs FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can insert logs (Edge Function uses service role)
CREATE POLICY "Service role can insert recognition logs"
  ON recognition_logs FOR INSERT
  WITH CHECK (true);

-- Food search cache table - caches USDA search results
CREATE TABLE IF NOT EXISTS food_search_cache (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  query_normalized TEXT NOT NULL UNIQUE,
  search_results JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Index for query lookups
CREATE INDEX IF NOT EXISTS idx_food_search_cache_query ON food_search_cache(query_normalized);
-- Index for expiration cleanup
CREATE INDEX IF NOT EXISTS idx_food_search_cache_expires_at ON food_search_cache(expires_at);

-- RLS policies for food_search_cache
ALTER TABLE food_search_cache ENABLE ROW LEVEL SECURITY;

-- Service role can manage cache (Edge Function uses service role)
CREATE POLICY "Service role can manage food search cache"
  ON food_search_cache FOR ALL
  USING (true);

-- Subscriptions table - tracks premium entitlement
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  product_id TEXT,
  expires_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for user_id lookups
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
-- Index for expiration tracking
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at);

-- RLS policies for subscriptions
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own subscription status
CREATE POLICY "Users can read own subscription"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Only service role can insert/update subscriptions (webhook uses service role)
CREATE POLICY "Service role can manage subscriptions"
  ON subscriptions FOR ALL
  WITH CHECK (true);

-- Scan usage table - tracks monthly scan quota
CREATE TABLE IF NOT EXISTS scan_usage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  month TEXT NOT NULL, -- Format: 'YYYY-MM'
  scan_count INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, month)
);

-- Index for user_id lookups
CREATE INDEX IF NOT EXISTS idx_scan_usage_user_id ON scan_usage(user_id);
-- Index for month lookups
CREATE INDEX IF NOT EXISTS idx_scan_usage_month ON scan_usage(month);
-- Composite index for quota checks
CREATE INDEX IF NOT EXISTS idx_scan_usage_user_month ON scan_usage(user_id, month);

-- RLS policies for scan_usage
ALTER TABLE scan_usage ENABLE ROW LEVEL SECURITY;

-- Users can read their own usage
CREATE POLICY "Users can read own scan usage"
  ON scan_usage FOR SELECT
  USING (auth.uid() = user_id);

-- Only service role can insert/update scan_usage (Edge Function uses service role)
CREATE POLICY "Service role can manage scan usage"
  ON scan_usage FOR ALL
  WITH CHECK (true);

-- Function to increment scan count (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION increment_scan_count(p_user_id UUID, p_month TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  INSERT INTO scan_usage (user_id, month, scan_count)
  VALUES (p_user_id, p_month, 1)
  ON CONFLICT (user_id, month)
  DO UPDATE SET
    scan_count = scan_usage.scan_count + 1,
    updated_at = NOW()
  RETURNING scan_count INTO v_count;
  
 _RETURN v_count;
END;
$$;

-- Function to check remaining scans
CREATE OR REPLACE FUNCTION get_remaining_scans(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_current_count INTEGER;
  v_month TEXT;
  v_free_tier_limit INTEGER := 10;
BEGIN
  -- Check if user is premium
  SELECT is_premium INTO v_is_premium
  FROM subscriptions
  WHERE user_id = p_user_id;
  
  IF v_is_premium = TRUE THEN
    RETURN -1; -- Unlimited
  END IF;
  
  -- Get current month
  v_month := TO_CHAR(NOW(), 'YYYY-MM');
  
  -- Get current scan count
  SELECT COALESCE(scan_count, 0) INTO v_current_count
  FROM scan_usage
  WHERE user_id = p_user_id AND month = v_month;
  
  RETURN GREATEST(0, v_free_tier_limit - v_current_count);
END;
$$;

-- Function to check if user is premium
CREATE OR REPLACE FUNCTION is_premium_user(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
  SELECT is_premium, expires_at INTO v_is_premium, v_expires_at
  FROM subscriptions
  WHERE user_id = p_user_id;
  
  -- If no subscription or expired, return false
  IF v_is_premium IS NULL OR v_is_premium = FALSE THEN
    RETURN FALSE;
  END IF;
  
  -- If expired, return false
  IF v_expires_at IS NOT NULL AND v_expires_at < NOW() THEN
    RETURN FALSE;
  END IF;
  
  RETURN v_is_premium;
END;
$$;

-- Function to clean up expired cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_cache()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM food_search_cache
  WHERE expires_at < NOW();
END;
$$;

-- Grant execute permissions on functions to authenticated users
GRANT EXECUTE ON FUNCTION get_remaining_scans(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_premium_user(UUID) TO authenticated;
