-- Cloud copies of the logs the app records offline (water, sleep, meals,
-- workouts, weight), so history survives a
-- reinstall or a new phone (lib/core/sync/sync_service.dart).
--
-- Sync model:
--   * ids are generated on the device, so the same entry never duplicates;
--   * the app upserts rows it has changed and pulls rows whose updated_at is
--     newer than its last pull;
--   * deletes are soft (deleted_at) so other devices learn about them;
--   * updated_at is always set by the server (trigger), never trusted from
--     the client, so every device can use it as a pull cursor.
--
-- Users can read and write only their own rows. Rows go with the account
-- (ON DELETE CASCADE).

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Water: one row per glass / amount logged.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.water_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount_ml INTEGER NOT NULL CHECK (amount_ml > 0 AND amount_ml <= 10000),
  logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- ---------------------------------------------------------------------------
-- Sleep: manual bed / wake entries (Health Connect nights stay on the phone).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sleep_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes >= 0),
  source TEXT NOT NULL DEFAULT 'manual',
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  CHECK (end_time >= start_time)
);

-- ---------------------------------------------------------------------------
-- Meals: the whole logged meal (items + nutrition) as JSON. Photos stay on
-- the device that took them.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.meal_logs (
  id TEXT PRIMARY KEY CHECK (length(id) BETWEEN 1 AND 64),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  captured_at TIMESTAMP WITH TIME ZONE NOT NULL,
  meal_type SMALLINT NOT NULL CHECK (meal_type BETWEEN 0 AND 3),
  total_calories REAL NOT NULL DEFAULT 0,
  data JSONB NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- ---------------------------------------------------------------------------
-- Workouts: the session summary plus its GPS route, packed as
-- [[lat, lng, epoch_ms, accuracy, speed, altitude], ...].
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.activity_sessions (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  activity_type TEXT NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE,
  data JSONB NOT NULL,
  track JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  CHECK (length(id) BETWEEN 1 AND 64)
);

-- ---------------------------------------------------------------------------
-- Weight: body weight entries, always in kilograms.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.weight_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  weight_kg NUMERIC(5, 2) NOT NULL CHECK (weight_kg BETWEEN 20 AND 400),
  logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual',
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- ---------------------------------------------------------------------------
-- Shared setup: pull index, updated_at trigger, row level security.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['water_logs', 'sleep_logs', 'meal_logs', 'activity_sessions', 'weight_logs']
  LOOP
    EXECUTE format(
      'CREATE INDEX IF NOT EXISTS %I ON public.%I (user_id, updated_at)',
      'idx_' || t || '_user_updated', t);

    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', t || '_touch', t);
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at()',
      t || '_touch', t);

    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

    EXECUTE format('DROP POLICY IF EXISTS "Users can read own rows" ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY "Users can read own rows" ON public.%I '
      'FOR SELECT TO authenticated USING (auth.uid() = user_id)', t);

    EXECUTE format('DROP POLICY IF EXISTS "Users can insert own rows" ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY "Users can insert own rows" ON public.%I '
      'FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)', t);

    EXECUTE format('DROP POLICY IF EXISTS "Users can update own rows" ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY "Users can update own rows" ON public.%I '
      'FOR UPDATE TO authenticated USING (auth.uid() = user_id) '
      'WITH CHECK (auth.uid() = user_id)', t);

    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON public.%I TO authenticated', t);
  END LOOP;
END;
$$;
