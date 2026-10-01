-- Every confirmed user gets a profile.
--
-- handle_new_user() used to create a profile only when sign-up metadata had a
-- `username`, which email sign-up sets but Google sign-in never does. Google
-- users therefore had no profile: Profile and Settings failed to load, nobody
-- could friend them and they were missing from leaderboards and broadcasts.
-- They now get a generated username (from their email) that they can change
-- in Profile, plus their Google name and photo.
--
-- It also re-copied the sign-up username onto the profile on every
-- auth.users update (each sign-in touches the row), undoing renames made in
-- Profile. The username is now only set when the profile is created.

-- A free username for [p_seed]: letters, digits, dots and underscores,
-- 3-20 characters (the app's sign-up rules), with a number added if taken.
CREATE OR REPLACE FUNCTION _available_username(p_seed TEXT)
RETURNS TEXT
LANGUAGE plpgsql
VOLATILE
SET search_path = public
AS $$
DECLARE
  v_base TEXT := LOWER(REGEXP_REPLACE(COALESCE(p_seed, ''), '[^A-Za-z0-9._]', '', 'g'));
  v_candidate TEXT;
BEGIN
  v_base := LEFT(BTRIM(v_base, '._'), 15);
  IF LENGTH(v_base) < 3 THEN
    v_base := 'user';
  END IF;

  v_candidate := v_base;
  FOR i IN 1..20 LOOP
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE LOWER(username) = LOWER(v_candidate)) THEN
      RETURN v_candidate;
    END IF;
    v_candidate := v_base || '_' || (1000 + FLOOR(RANDOM() * 9000))::INT;
  END LOOP;
  -- Practically unreachable; still within 20 characters.
  RETURN LEFT(v_base, 11) || '_' || SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 8);
END;
$$;

-- Creates the profile for [p_user] if it has none. Never raises: a failure
-- here must not block sign-in (it is retried on the next sign-in).
CREATE OR REPLACE FUNCTION ensure_profile(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  u auth.users%ROWTYPE;
  v_meta JSONB;
  v_username TEXT;
BEGIN
  SELECT * INTO u FROM auth.users WHERE id = p_user;
  IF NOT FOUND OR u.email_confirmed_at IS NULL OR u.email IS NULL THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = p_user) THEN
    RETURN;
  END IF;

  v_meta := COALESCE(u.raw_user_meta_data, '{}'::jsonb);

  FOR attempt IN 1..3 LOOP
    BEGIN
      -- The sign-up username was already checked by the app; keep it if free.
      v_username := CASE
        WHEN attempt = 1 AND v_meta->>'username' IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM profiles WHERE LOWER(username) = LOWER(v_meta->>'username'))
          THEN v_meta->>'username'
        ELSE _available_username(SPLIT_PART(u.email, '@', 1))
      END;

      INSERT INTO profiles (id, username, email, display_name, avatar_url)
      VALUES (
        u.id,
        v_username,
        u.email,
        NULLIF(BTRIM(COALESCE(v_meta->>'full_name', v_meta->>'name', '')), ''),
        COALESCE(v_meta->>'avatar_url', v_meta->>'picture')
      )
      ON CONFLICT (id) DO NOTHING;
      RETURN;
    EXCEPTION WHEN unique_violation THEN
      -- Username taken in a race (retry with a new one) or the email belongs
      -- to another profile (retrying won't help; give up quietly).
      IF EXISTS (SELECT 1 FROM profiles WHERE email = u.email AND id <> u.id) THEN
        RAISE WARNING 'ensure_profile: email % already used by another profile', u.email;
        RETURN;
      END IF;
    END;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'ensure_profile(%) failed: %', p_user, SQLERRM;
END;
$$;

REVOKE EXECUTE ON FUNCTION ensure_profile(UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION _available_username(TEXT) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL THEN
    PERFORM ensure_profile(NEW.id);
    -- Keep the profile's email in step with the account (username is left
    -- alone so renames in Profile stick).
    BEGIN
      UPDATE profiles SET email = NEW.email
      WHERE id = NEW.id AND NEW.email IS NOT NULL AND email IS DISTINCT FROM NEW.email
        AND NOT EXISTS (SELECT 1 FROM profiles o WHERE o.email = NEW.email AND o.id <> NEW.id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'handle_new_user: email sync failed for %: %', NEW.id, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill users who signed up before this fix.
SELECT ensure_profile(u.id)
FROM auth.users u
WHERE u.email_confirmed_at IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM profiles p WHERE p.id = u.id);
