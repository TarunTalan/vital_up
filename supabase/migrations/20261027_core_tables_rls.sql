-- Row level security for the tables created in the dashboard (profiles,
-- user_health_data, proprietary_products), which no migration covered.
--
-- Re-runnable: every table is guarded with to_regclass and every policy is
-- dropped before it's created. The dashboard may already have policies
-- under other names; RESTRICTIVE policies here cap them (they are ANDed
-- with every permissive one), and the permissive ones grant what the app
-- needs in case there are none. Service role and SECURITY DEFINER
-- functions owned by postgres bypass RLS as before.

-- ---------------------------------------------------------------------------
-- 1. profiles
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.profiles') IS NULL THEN
    RETURN;
  END IF;

  ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
  REVOKE ALL ON public.profiles FROM anon;
  -- Clients only add their own row; deleting is the delete-account
  -- function's job (service role).
  REVOKE DELETE, TRUNCATE ON public.profiles FROM authenticated;

  -- Readable by signed-in users (friends, leaderboards); the column grant
  -- from 20261022 already keeps email out.
  DROP POLICY IF EXISTS profiles_read_signed_in ON public.profiles;
  CREATE POLICY profiles_read_signed_in ON public.profiles
    FOR SELECT TO authenticated USING (true);

  DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
  CREATE POLICY profiles_insert_own ON public.profiles
    FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
  DROP POLICY IF EXISTS profiles_insert_own_only ON public.profiles;
  CREATE POLICY profiles_insert_own_only ON public.profiles
    AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

  DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
  CREATE POLICY profiles_update_own ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid()) WITH CHECK (id = auth.uid());
  DROP POLICY IF EXISTS profiles_update_own_only ON public.profiles;
  CREATE POLICY profiles_update_own_only ON public.profiles
    AS RESTRICTIVE FOR UPDATE TO authenticated
    USING (id = auth.uid()) WITH CHECK (id = auth.uid());

  DROP POLICY IF EXISTS profiles_no_client_delete ON public.profiles;
  CREATE POLICY profiles_no_client_delete ON public.profiles
    AS RESTRICTIVE FOR DELETE TO authenticated USING (false);
END
$$;

-- Columns only the server sets. Adds to 20261021's version: city and
-- country_code go through set_my_city (which also moves the user's local
-- community), timezone through set_my_timezone (it decides the user's
-- day for points and streaks), and the id never changes.
CREATE OR REPLACE FUNCTION public._protect_profile_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- The signed-in user's own address, from their token.
    NEW.email := auth.jwt() ->> 'email';
    NEW.username_confirmed := TRUE;
  ELSE
    NEW.id := OLD.id;
    NEW.email := OLD.email;
    NEW.username_confirmed := OLD.username_confirmed;
    NEW.city := OLD.city;
    NEW.country_code := OLD.country_code;
    NEW.timezone := OLD.timezone;
  END IF;

  -- Our storage (the user's own folder) or the Google account photo.
  IF NEW.avatar_url IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.avatar_url IS DISTINCT FROM OLD.avatar_url)
     AND NOT (
       NEW.avatar_url LIKE 'https://lh3.googleusercontent.com/%'
       OR NEW.avatar_url ~ ('^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/avatars/'
                            || NEW.id::text || '/')
     ) THEN
    RAISE EXCEPTION 'avatar_url not allowed' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public._protect_profile_columns() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. user_health_data: the user's own row only
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.user_health_data') IS NULL THEN
    RETURN;
  END IF;

  ALTER TABLE public.user_health_data ENABLE ROW LEVEL SECURITY;
  REVOKE ALL ON public.user_health_data FROM anon;
  REVOKE DELETE, TRUNCATE ON public.user_health_data FROM authenticated;

  DROP POLICY IF EXISTS user_health_data_read_own ON public.user_health_data;
  CREATE POLICY user_health_data_read_own ON public.user_health_data
    FOR SELECT TO authenticated USING (id = auth.uid());
  DROP POLICY IF EXISTS user_health_data_read_own_only ON public.user_health_data;
  CREATE POLICY user_health_data_read_own_only ON public.user_health_data
    AS RESTRICTIVE FOR SELECT TO authenticated USING (id = auth.uid());

  DROP POLICY IF EXISTS user_health_data_insert_own ON public.user_health_data;
  CREATE POLICY user_health_data_insert_own ON public.user_health_data
    FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
  DROP POLICY IF EXISTS user_health_data_insert_own_only ON public.user_health_data;
  CREATE POLICY user_health_data_insert_own_only ON public.user_health_data
    AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

  DROP POLICY IF EXISTS user_health_data_update_own ON public.user_health_data;
  CREATE POLICY user_health_data_update_own ON public.user_health_data
    FOR UPDATE TO authenticated
    USING (id = auth.uid()) WITH CHECK (id = auth.uid());
  DROP POLICY IF EXISTS user_health_data_update_own_only ON public.user_health_data;
  CREATE POLICY user_health_data_update_own_only ON public.user_health_data
    AS RESTRICTIVE FOR UPDATE TO authenticated
    USING (id = auth.uid()) WITH CHECK (id = auth.uid());

  DROP POLICY IF EXISTS user_health_data_no_client_delete ON public.user_health_data;
  CREATE POLICY user_health_data_no_client_delete ON public.user_health_data
    AS RESTRICTIVE FOR DELETE TO authenticated USING (false);
END
$$;

-- ---------------------------------------------------------------------------
-- 3. proprietary_products: shared catalogue
-- ---------------------------------------------------------------------------
-- Everyone may read it (it holds no personal data; offline foods are
-- fetched at start-up). Signed-in users may add a product nobody has
-- entered yet, but no longer change existing ones: any user could
-- otherwise overwrite a product's nutrition for everyone. The scan-food
-- function (service role) still maintains it.
DO $$
BEGIN
  IF to_regclass('public.proprietary_products') IS NULL THEN
    RETURN;
  END IF;

  ALTER TABLE public.proprietary_products ENABLE ROW LEVEL SECURITY;
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.proprietary_products FROM anon;
  REVOKE UPDATE, DELETE, TRUNCATE ON public.proprietary_products FROM authenticated;
  GRANT SELECT ON public.proprietary_products TO anon, authenticated;
  GRANT INSERT ON public.proprietary_products TO authenticated;

  DROP POLICY IF EXISTS proprietary_products_read ON public.proprietary_products;
  CREATE POLICY proprietary_products_read ON public.proprietary_products
    FOR SELECT TO anon, authenticated USING (true);

  DROP POLICY IF EXISTS proprietary_products_insert ON public.proprietary_products;
  CREATE POLICY proprietary_products_insert ON public.proprietary_products
    FOR INSERT TO authenticated WITH CHECK (true);

  DROP POLICY IF EXISTS proprietary_products_no_client_update ON public.proprietary_products;
  CREATE POLICY proprietary_products_no_client_update ON public.proprietary_products
    AS RESTRICTIVE FOR UPDATE TO anon, authenticated USING (false);
  DROP POLICY IF EXISTS proprietary_products_no_client_delete ON public.proprietary_products;
  CREATE POLICY proprietary_products_no_client_delete ON public.proprietary_products
    AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);
END
$$;
