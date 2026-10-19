-- profiles was readable by anyone with the app's publishable key, email
-- addresses included (a policy created in the dashboard, not in these
-- migrations, allowed it). Signed-out callers now get nothing; signed-in
-- users can read every column except email (friends, leaderboards and the
-- user's own row keep working; their own email comes from the session).
--
-- Column-level grant: a column added to profiles later is NOT readable by
-- clients until it's granted here too (on purpose: new columns start
-- private).

REVOKE ALL ON public.profiles FROM anon;
REVOKE SELECT ON public.profiles FROM authenticated;

DO $$
DECLARE
  v_cols TEXT;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
  INTO v_cols
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'profiles'
    AND column_name <> 'email';
  EXECUTE format('GRANT SELECT (%s) ON public.profiles TO authenticated', v_cols);
END;
$$;
