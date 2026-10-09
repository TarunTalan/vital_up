-- Sign-up and password-reset checks that work before sign-in.
--
-- The app used to read `profiles` directly while signed out to see whether a
-- username or email was taken. With RLS limiting profiles to signed-in users
-- those reads return nothing, so every username looked free; with RLS open
-- they would expose other users' emails. These functions answer only yes/no
-- and apply the same rules as _username_error() (3-20 letters, digits, dots
-- or underscores, unique regardless of case).
--
-- ensure_profile() still has the final say: if the username is taken between
-- this check and the email confirmation, the profile gets a generated
-- username with username_confirmed = FALSE and the app asks for a new one.

CREATE OR REPLACE FUNCTION signup_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- No user yet, so any existing profile with this name counts as taken.
  SELECT LENGTH(COALESCE(p_username, '')) <= 64
    AND _username_error(BTRIM(p_username), NULL) IS NULL;
$$;

CREATE INDEX IF NOT EXISTS profiles_email_lower_idx ON public.profiles (LOWER(email));

-- Whether an account already uses [p_email] (case-insensitive).
CREATE OR REPLACE FUNCTION email_registered(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT LENGTH(COALESCE(p_email, '')) BETWEEN 3 AND 254
    AND EXISTS (SELECT 1 FROM profiles WHERE LOWER(email) = LOWER(BTRIM(p_email)));
$$;

REVOKE EXECUTE ON FUNCTION signup_username_available(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION email_registered(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION signup_username_available(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION email_registered(TEXT) TO anon, authenticated;
