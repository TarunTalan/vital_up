-- Users with a generated username (Google sign-in) must choose their own.
--
-- profiles.username_confirmed is false while the username is the one
-- ensure_profile() generated. The app asks for a username on the personal
-- details step of onboarding (or with a prompt on the home screen for users
-- past onboarding) and saves it with set_username(), which confirms it.
--
-- Username rules are also enforced here for every change, including edits
-- from the Profile page: 3-20 letters, digits, dots or underscores, unique
-- regardless of case.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username_confirmed BOOLEAN NOT NULL DEFAULT TRUE;

-- Existing profiles created without a sign-up username were generated.
UPDATE profiles p SET username_confirmed = FALSE
FROM auth.users u
WHERE u.id = p.id AND u.raw_user_meta_data->>'username' IS NULL;

-- "Tarun" and "tarun" are the same username.
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_key ON public.profiles (LOWER(username));

CREATE OR REPLACE FUNCTION _username_error(p_username TEXT, p_user UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_username IS NULL OR p_username !~ '^[A-Za-z0-9._]{3,20}$' THEN 'invalid_username'
    WHEN EXISTS (
      SELECT 1 FROM profiles WHERE LOWER(username) = LOWER(p_username) AND id IS DISTINCT FROM p_user
    ) THEN 'username_taken'
  END;
$$;

REVOKE EXECUTE ON FUNCTION _username_error(TEXT, UUID) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION validate_profile_username()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_error TEXT;
BEGIN
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    v_error := _username_error(NEW.username, NEW.id);
    IF v_error IS NOT NULL THEN
      RAISE EXCEPTION '%', v_error USING ERRCODE = 'check_violation';
    END IF;
    -- Picking any username yourself counts as choosing one.
    NEW.username_confirmed := TRUE;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_validate_username ON profiles;
CREATE TRIGGER profiles_validate_username
  BEFORE UPDATE OF username ON profiles
  FOR EACH ROW EXECUTE FUNCTION validate_profile_username();

-- Whether [p_username] can be the caller's username (their current one
-- counts as available).
CREATE OR REPLACE FUNCTION username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT _username_error(BTRIM(p_username), auth.uid()) IS NULL;
$$;

-- Sets and confirms the caller's username. Keeping the suggested username
-- is allowed. Raises invalid_username or username_taken.
CREATE OR REPLACE FUNCTION set_username(p_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username TEXT := BTRIM(p_username);
  v_error TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  v_error := _username_error(v_username, auth.uid());
  IF v_error IS NOT NULL THEN
    RAISE EXCEPTION '%', v_error;
  END IF;

  UPDATE profiles SET username = v_username, username_confirmed = TRUE WHERE id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found';
  END IF;
  RETURN v_username;
EXCEPTION WHEN unique_violation THEN
  -- Taken by someone else between the check and the update.
  RAISE EXCEPTION 'username_taken';
END;
$$;

GRANT EXECUTE ON FUNCTION username_available(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION set_username(TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION username_available(TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION set_username(TEXT) FROM anon;

-- New profiles: confirmed only when the sign-up username was used.
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
  v_chosen BOOLEAN;
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
      v_chosen := attempt = 1 AND v_meta->>'username' IS NOT NULL
        AND _username_error(v_meta->>'username', u.id) IS NULL;
      v_username := CASE
        WHEN v_chosen THEN v_meta->>'username'
        ELSE _available_username(SPLIT_PART(u.email, '@', 1))
      END;

      INSERT INTO profiles (id, username, email, display_name, avatar_url, username_confirmed)
      VALUES (
        u.id,
        v_username,
        u.email,
        NULLIF(BTRIM(COALESCE(v_meta->>'full_name', v_meta->>'name', '')), ''),
        COALESCE(v_meta->>'avatar_url', v_meta->>'picture'),
        v_chosen
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
