-- Cloud backup of the small per-user data the app keeps on the device:
-- settings, goals, reminders, stress check-ins, workout notes and the active
-- diet plan (lib/core/sync/backup_sync.dart). One row per user per kind,
-- holding that kind's data as JSON.
--
-- Sync model (same as 20261008_synced_logs.sql, plus last-writer-wins):
--   * id is '<user_id>:<kind>', so a device always upserts the same row;
--   * changed_at is when the data was edited on the device. An upsert
--     whose changed_at is not newer than the stored row's is ignored. A
--     device's first upload uses the epoch, so a new phone uploading its
--     defaults never overwrites an existing backup;
--   * updated_at is set by the server (trigger) and used as the pull cursor.
--
-- Users can read and write only their own rows. Rows go with the account
-- (ON DELETE CASCADE).

CREATE TABLE IF NOT EXISTS public.user_backups (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  kind TEXT NOT NULL CHECK (kind ~ '^[a-z_]{1,40}$'),
  data JSONB NOT NULL,
  changed_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  UNIQUE (user_id, kind),
  CHECK (id = user_id::text || ':' || kind),
  -- Generous for a diet plan or 90 days of check-ins; stops runaway rows.
  CHECK (pg_column_size(data) <= 512 * 1024)
);

CREATE INDEX IF NOT EXISTS idx_user_backups_user_updated
  ON public.user_backups (user_id, updated_at);

-- Keeps the newer edit and stamps the pull cursor.
CREATE OR REPLACE FUNCTION public.user_backups_last_writer_wins()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.changed_at <= OLD.changed_at THEN
    -- Skip this update; the stored row is as new or newer.
    RETURN NULL;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS user_backups_touch ON public.user_backups;
CREATE TRIGGER user_backups_touch
  BEFORE INSERT OR UPDATE ON public.user_backups
  FOR EACH ROW EXECUTE FUNCTION public.user_backups_last_writer_wins();

ALTER TABLE public.user_backups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own rows" ON public.user_backups;
CREATE POLICY "Users can read own rows" ON public.user_backups
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own rows" ON public.user_backups;
CREATE POLICY "Users can insert own rows" ON public.user_backups
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own rows" ON public.user_backups;
CREATE POLICY "Users can update own rows" ON public.user_backups
  FOR UPDATE TO authenticated USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

REVOKE ALL ON public.user_backups FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.user_backups TO authenticated;
