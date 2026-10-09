-- Server-side input limits for everything users can write.
--
-- The app already trims and caps typed text (lib/core/utils/input_rules.dart,
-- InputLimits), but anyone with the anon key and a session can call the REST
-- API or the RPCs directly. These CHECK constraints and RPC guards make the
-- database enforce the same limits:
--
--   text (characters): name 50, username 3-20 ([A-Za-z0-9._], as in
--   20261007_username_confirmation.sql), email 254, search 100, short text
--   80 (titles, labels), note 500 (multi-line notes), city 60.
--   body / tracking: weight 20-350 kg, height 50-272 cm, water entry
--   1-5000 ml, calories <= 10000, grams <= 5000.
--   jsonb payloads: size caps (pg_column_size) so one row can't grow without
--   bound.
--
-- Single-line fields also reject control characters ([[:cntrl:]]);
-- multi-line notes allow tab and newline only.
--
-- Every constraint is added NOT VALID: it applies to new and updated rows but
-- does not scan or reject rows already stored. After checking existing data
-- (queries in the comments), each can be validated with the commented-out
-- VALIDATE CONSTRAINT line. Synced log ranges skip soft-deleted rows so an old
-- out-of-range entry can still be deleted.
--
-- Tables created outside these migrations (user_health_data,
-- proprietary_products) are only constrained when they and the columns exist,
-- and numeric checks there follow the column's actual type.
--
-- Safe to re-run: every constraint is dropped (if present) and re-added, and
-- functions are CREATE OR REPLACE with unchanged signatures.

-- ---------------------------------------------------------------------------
-- profiles (users update their own row through the REST API)
-- ---------------------------------------------------------------------------

-- Same rule as _username_error() (3-20 letters, digits, dots, underscores);
-- the trigger only covers updates, this also covers inserts.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_username_format;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_format
  CHECK (username IS NULL OR username ~ '^[A-Za-z0-9._]{3,20}$') NOT VALID;
-- SELECT id, username FROM profiles WHERE username !~ '^[A-Za-z0-9._]{3,20}$';
-- ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_username_format;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_email_length;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_email_length
  CHECK (email IS NULL OR (char_length(email) <= 254 AND email !~ '[[:cntrl:][:space:]]')) NOT VALID;
-- ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_email_length;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_display_name_length;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_display_name_length
  CHECK (display_name IS NULL OR (char_length(display_name) <= 50 AND display_name !~ '[[:cntrl:]]')) NOT VALID;
-- SELECT id, display_name FROM profiles WHERE char_length(display_name) > 50;
-- ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_display_name_length;

-- Supabase storage URLs or the Google profile photo URL.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_avatar_url_format;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_avatar_url_format
  CHECK (avatar_url IS NULL OR (
    char_length(avatar_url) <= 2048
    AND avatar_url ~* '^https?://'
    AND avatar_url !~ '[[:cntrl:][:space:]]')) NOT VALID;
-- ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_avatar_url_format;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_city_length;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_city_length
  CHECK (city IS NULL OR (char_length(city) <= 60 AND city !~ '[[:cntrl:]]')) NOT VALID;
-- ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_city_length;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_country_code_format;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_country_code_format
  CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$') NOT VALID;
-- ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_country_code_format;

-- IANA names are at most ~32 characters.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_timezone_length;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_timezone_length
  CHECK (timezone IS NULL OR (char_length(timezone) <= 64 AND timezone !~ '[[:cntrl:][:space:]]')) NOT VALID;
-- ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_timezone_length;

-- Columns some projects have on profiles but these migrations never create.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT v.col, v.max_len, v.multiline
    FROM (VALUES ('full_name', 50, FALSE), ('bio', 500, TRUE)) AS v(col, max_len, multiline)
    JOIN information_schema.columns c
      ON c.table_schema = 'public' AND c.table_name = 'profiles' AND c.column_name = v.col
     AND c.data_type IN ('text', 'character varying')
  LOOP
    EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS %I',
      'profiles_' || r.col || '_length');
    EXECUTE format(
      'ALTER TABLE public.profiles ADD CONSTRAINT %I CHECK (%I IS NULL OR (char_length(%I) <= %s AND %I !~ %L)) NOT VALID',
      'profiles_' || r.col || '_length', r.col, r.col, r.max_len, r.col,
      CASE WHEN r.multiline THEN '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]' ELSE '[[:cntrl:]]' END);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- user_health_data (onboarding / Health details; the app sends strings)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
  v_type TEXT;
  v_unit_type TEXT;
  v_num TEXT;
  v_unit TEXT;
  v_expr TEXT;
BEGIN
  IF to_regclass('public.user_health_data') IS NULL THEN
    RAISE NOTICE 'user_health_data not found; skipping its constraints';
    RETURN;
  END IF;

  -- Text lengths, for text columns only.
  FOR r IN
    SELECT v.col, v.max_len, v.multiline
    FROM (VALUES
      ('full_name', 50, FALSE),
      ('dob', 20, FALSE),
      ('gender', 20, FALSE),
      ('weight', 20, FALSE),
      ('weight_unit', 10, FALSE),
      ('height', 20, FALSE),
      ('height_unit', 10, FALSE),
      ('target_weight', 20, FALSE),
      ('target_weight_unit', 10, FALSE),
      ('calorie_goal', 20, FALSE),
      ('goal_duration_months', 20, FALSE),
      ('oxygen_level', 20, FALSE),
      ('bpm', 20, FALSE),
      ('blood_pressure_top', 20, FALSE),
      ('blood_pressure_bottom', 20, FALSE),
      ('smokes', 20, FALSE),
      ('activity', 80, FALSE),
      ('sleep', 80, FALSE),
      ('dietary_preference', 80, FALSE),
      ('health_conditions', 500, TRUE),
      ('medicines', 500, TRUE),
      ('allergies', 500, TRUE)
    ) AS v(col, max_len, multiline)
    JOIN information_schema.columns c
      ON c.table_schema = 'public' AND c.table_name = 'user_health_data' AND c.column_name = v.col
     AND c.data_type IN ('text', 'character varying')
  LOOP
    EXECUTE format('ALTER TABLE public.user_health_data DROP CONSTRAINT IF EXISTS %I',
      'user_health_data_' || r.col || '_length');
    EXECUTE format(
      'ALTER TABLE public.user_health_data ADD CONSTRAINT %I CHECK (%I IS NULL OR (char_length(%I) <= %s AND %I !~ %L)) NOT VALID',
      'user_health_data_' || r.col || '_length', r.col, r.col, r.max_len, r.col,
      CASE WHEN r.multiline THEN '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]' ELSE '[[:cntrl:]]' END);
  END LOOP;

  -- Numeric ranges. Text columns are only checked when they hold a plain
  -- number ('' and other formats such as feet "5-10" pass); 0 means unset.
  -- Weights follow their unit column (lb / lbs vs kg).
  FOR r IN
    SELECT * FROM (VALUES
      ('weight', 'weight_unit', 'weight'),
      ('target_weight', 'target_weight_unit', 'weight'),
      ('height', 'height_unit', 'height'),
      ('calorie_goal', NULL, 'calories')
    ) AS v(col, unit_col, kind)
  LOOP
    SELECT data_type INTO v_type FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'user_health_data' AND column_name = r.col;
    CONTINUE WHEN v_type IS NULL;

    IF v_type IN ('text', 'character varying') THEN
      v_num := format('btrim(%I)::numeric', r.col);
    ELSIF v_type IN ('smallint', 'integer', 'bigint', 'numeric', 'real', 'double precision') THEN
      v_num := format('%I::numeric', r.col);
    ELSE
      CONTINUE;
    END IF;

    v_unit := NULL;
    IF r.unit_col IS NOT NULL THEN
      SELECT data_type INTO v_unit_type FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'user_health_data' AND column_name = r.unit_col;
      IF v_unit_type IN ('text', 'character varying') THEN
        v_unit := format('lower(btrim(COALESCE(%I, %L)))', r.unit_col, '');
      END IF;
    END IF;

    v_expr := CASE r.kind
      WHEN 'weight' THEN
        CASE WHEN v_unit IS NULL THEN format('%s = 0 OR %s BETWEEN 20 AND 772', v_num, v_num)
        ELSE format(
          '%1$s = 0 OR CASE WHEN %2$s LIKE %3$L THEN %1$s BETWEEN 44 AND 772 ELSE %1$s BETWEEN 20 AND 350 END',
          v_num, v_unit, 'lb%') END
      WHEN 'height' THEN
        CASE WHEN v_unit IS NULL THEN format('%s = 0 OR %s BETWEEN 19 AND 272', v_num, v_num)
        ELSE format(
          '%1$s = 0 OR CASE WHEN %2$s IN (%3$L, %4$L) THEN %1$s BETWEEN 50 AND 272'
          ' WHEN %2$s IN (%5$L, %6$L) THEN %1$s BETWEEN 19 AND 108 ELSE TRUE END',
          v_num, v_unit, 'cm', '', 'in', 'inch') END
      ELSE format('%s BETWEEN 0 AND 10000', v_num)
    END;

    IF v_type IN ('text', 'character varying') THEN
      v_expr := format('CASE WHEN btrim(%I) ~ %L THEN (%s) ELSE TRUE END',
        r.col, '^[0-9]{1,6}(\.[0-9]{1,6})?$', v_expr);
    END IF;

    EXECUTE format('ALTER TABLE public.user_health_data DROP CONSTRAINT IF EXISTS %I',
      'user_health_data_' || r.col || '_range');
    EXECUTE format(
      'ALTER TABLE public.user_health_data ADD CONSTRAINT %I CHECK (%I IS NULL OR (%s)) NOT VALID',
      'user_health_data_' || r.col || '_range', r.col, v_expr);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- proprietary_products (barcode products saved by the app and scan-food)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
BEGIN
  IF to_regclass('public.proprietary_products') IS NULL THEN
    RAISE NOTICE 'proprietary_products not found; skipping its constraints';
    RETURN;
  END IF;

  -- Product names come from Open Food Facts / FatSecret too, which can be
  -- longer than the app's 80-character food name, so this cap is wider.
  FOR r IN
    SELECT v.col, v.max_len
    FROM (VALUES
      ('barcode', 64), ('product_name', 200), ('serving_size', 80), ('source', 40)
    ) AS v(col, max_len)
    JOIN information_schema.columns c
      ON c.table_schema = 'public' AND c.table_name = 'proprietary_products' AND c.column_name = v.col
     AND c.data_type IN ('text', 'character varying')
  LOOP
    EXECUTE format('ALTER TABLE public.proprietary_products DROP CONSTRAINT IF EXISTS %I',
      'proprietary_products_' || r.col || '_length');
    EXECUTE format(
      'ALTER TABLE public.proprietary_products ADD CONSTRAINT %I CHECK (%I IS NULL OR (char_length(%I) <= %s AND %I !~ %L)) NOT VALID',
      'proprietary_products_' || r.col || '_length', r.col, r.col, r.max_len, r.col, '[[:cntrl:]]');
  END LOOP;

  -- Nutrition per serving / 100 g: calories <= 10000, grams <= 5000,
  -- sodium <= 5000 g in mg.
  FOR r IN
    SELECT v.col, v.max_val
    FROM (VALUES
      ('calories', 10000), ('protein_g', 5000), ('carbs_g', 5000), ('fat_g', 5000),
      ('fiber_g', 5000), ('sugar_g', 5000), ('sodium_mg', 5000000)
    ) AS v(col, max_val)
    JOIN information_schema.columns c
      ON c.table_schema = 'public' AND c.table_name = 'proprietary_products' AND c.column_name = v.col
     AND c.data_type IN ('smallint', 'integer', 'bigint', 'numeric', 'real', 'double precision')
  LOOP
    EXECUTE format('ALTER TABLE public.proprietary_products DROP CONSTRAINT IF EXISTS %I',
      'proprietary_products_' || r.col || '_range');
    EXECUTE format(
      'ALTER TABLE public.proprietary_products ADD CONSTRAINT %I CHECK (%I IS NULL OR %I BETWEEN 0 AND %s) NOT VALID',
      'proprietary_products_' || r.col || '_range', r.col, r.col, r.max_val);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- Synced logs (20261008_synced_logs.sql). Soft-deleted rows are exempt so
-- old entries can still be deleted.
-- ---------------------------------------------------------------------------

-- One water entry: 1-5000 ml (the table allowed up to 10000).
ALTER TABLE public.water_logs DROP CONSTRAINT IF EXISTS water_logs_amount_ml_range;
ALTER TABLE public.water_logs ADD CONSTRAINT water_logs_amount_ml_range
  CHECK (deleted_at IS NOT NULL OR amount_ml BETWEEN 1 AND 5000) NOT VALID;
-- SELECT count(*) FROM water_logs WHERE deleted_at IS NULL AND amount_ml > 5000;
-- ALTER TABLE public.water_logs VALIDATE CONSTRAINT water_logs_amount_ml_range;

-- 20-350 kg (the table allowed up to 400).
ALTER TABLE public.weight_logs DROP CONSTRAINT IF EXISTS weight_logs_weight_kg_range;
ALTER TABLE public.weight_logs ADD CONSTRAINT weight_logs_weight_kg_range
  CHECK (deleted_at IS NOT NULL OR weight_kg BETWEEN 20 AND 350) NOT VALID;
-- SELECT count(*) FROM weight_logs WHERE deleted_at IS NULL AND weight_kg > 350;
-- ALTER TABLE public.weight_logs VALIDATE CONSTRAINT weight_logs_weight_kg_range;

ALTER TABLE public.weight_logs DROP CONSTRAINT IF EXISTS weight_logs_source_length;
ALTER TABLE public.weight_logs ADD CONSTRAINT weight_logs_source_length
  CHECK (char_length(source) <= 40 AND source !~ '[[:cntrl:]]') NOT VALID;
-- ALTER TABLE public.weight_logs VALIDATE CONSTRAINT weight_logs_source_length;

-- One sleep entry is at most a day.
ALTER TABLE public.sleep_logs DROP CONSTRAINT IF EXISTS sleep_logs_duration_range;
ALTER TABLE public.sleep_logs ADD CONSTRAINT sleep_logs_duration_range
  CHECK (deleted_at IS NOT NULL OR duration_minutes <= 1440) NOT VALID;
-- ALTER TABLE public.sleep_logs VALIDATE CONSTRAINT sleep_logs_duration_range;

ALTER TABLE public.sleep_logs DROP CONSTRAINT IF EXISTS sleep_logs_source_length;
ALTER TABLE public.sleep_logs ADD CONSTRAINT sleep_logs_source_length
  CHECK (char_length(source) <= 40 AND source !~ '[[:cntrl:]]') NOT VALID;
-- ALTER TABLE public.sleep_logs VALIDATE CONSTRAINT sleep_logs_source_length;

ALTER TABLE public.meal_logs DROP CONSTRAINT IF EXISTS meal_logs_total_calories_range;
ALTER TABLE public.meal_logs ADD CONSTRAINT meal_logs_total_calories_range
  CHECK (deleted_at IS NOT NULL OR total_calories BETWEEN 0 AND 10000) NOT VALID;
-- SELECT count(*) FROM meal_logs WHERE deleted_at IS NULL AND total_calories NOT BETWEEN 0 AND 10000;
-- ALTER TABLE public.meal_logs VALIDATE CONSTRAINT meal_logs_total_calories_range;

-- A meal's items and nutrition; photos are not uploaded.
ALTER TABLE public.meal_logs DROP CONSTRAINT IF EXISTS meal_logs_data_size;
ALTER TABLE public.meal_logs ADD CONSTRAINT meal_logs_data_size
  CHECK (pg_column_size(data) <= 256 * 1024) NOT VALID;
-- ALTER TABLE public.meal_logs VALIDATE CONSTRAINT meal_logs_data_size;

ALTER TABLE public.activity_sessions DROP CONSTRAINT IF EXISTS activity_sessions_activity_type_length;
ALTER TABLE public.activity_sessions ADD CONSTRAINT activity_sessions_activity_type_length
  CHECK (char_length(activity_type) BETWEEN 1 AND 40 AND activity_type !~ '[[:cntrl:]]') NOT VALID;
-- ALTER TABLE public.activity_sessions VALIDATE CONSTRAINT activity_sessions_activity_type_length;

ALTER TABLE public.activity_sessions DROP CONSTRAINT IF EXISTS activity_sessions_data_size;
ALTER TABLE public.activity_sessions ADD CONSTRAINT activity_sessions_data_size
  CHECK (pg_column_size(data) <= 256 * 1024) NOT VALID;
-- ALTER TABLE public.activity_sessions VALIDATE CONSTRAINT activity_sessions_data_size;

-- GPS route: ~6 numbers per point; 8 MB is many hours at one point a second.
ALTER TABLE public.activity_sessions DROP CONSTRAINT IF EXISTS activity_sessions_track_size;
ALTER TABLE public.activity_sessions ADD CONSTRAINT activity_sessions_track_size
  CHECK (pg_column_size(track) <= 8 * 1024 * 1024) NOT VALID;
-- ALTER TABLE public.activity_sessions VALIDATE CONSTRAINT activity_sessions_track_size;

-- user_backups already caps data at 512 KB and checks kind/id.

-- ---------------------------------------------------------------------------
-- push_tokens (FCM / APNs tokens; platform is already android | ios)
-- ---------------------------------------------------------------------------
ALTER TABLE public.push_tokens DROP CONSTRAINT IF EXISTS push_tokens_token_format;
ALTER TABLE public.push_tokens ADD CONSTRAINT push_tokens_token_format
  CHECK (char_length(token) BETWEEN 20 AND 4096 AND token !~ '[[:cntrl:][:space:]]') NOT VALID;
-- ALTER TABLE public.push_tokens VALIDATE CONSTRAINT push_tokens_token_format;

-- ---------------------------------------------------------------------------
-- RPCs that take free text. Each is the latest definition with input checks
-- added; behaviour is otherwise unchanged.
-- ---------------------------------------------------------------------------

-- From 20261003_friends.sql; rejects oversized search text up front.
CREATE OR REPLACE FUNCTION send_friend_request(p_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_target UUID;
  v_row friendships%ROWTYPE;
  v_pending INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  -- Usernames are 3-20 characters (21 with a leading @); anything else
  -- can't match, so fail fast with the error the app already shows.
  IF char_length(BTRIM(COALESCE(p_username, ''))) > 21
     OR char_length(BTRIM(LTRIM(BTRIM(COALESCE(p_username, '')), '@'))) NOT BETWEEN 3 AND 20 THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = '22001';
  END IF;

  SELECT id INTO v_target FROM profiles
  WHERE LOWER(username) = LOWER(BTRIM(LTRIM(BTRIM(COALESCE(p_username, '')), '@')));
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;
  IF v_target = v_user THEN
    RAISE EXCEPTION 'cannot_add_self';
  END IF;

  SELECT * INTO v_row FROM friendships
  WHERE (requester_id = v_user AND addressee_id = v_target)
     OR (requester_id = v_target AND addressee_id = v_user);

  IF FOUND THEN
    IF v_row.status = 'accepted' THEN
      RAISE EXCEPTION 'already_friends';
    END IF;
    IF v_row.requester_id = v_user THEN
      RAISE EXCEPTION 'already_requested';
    END IF;
    -- They asked first: accept.
    UPDATE friendships SET status = 'accepted', responded_at = NOW()
    WHERE requester_id = v_target AND addressee_id = v_user;
    RETURN 'accepted';
  END IF;

  -- Stops one account spamming requests.
  SELECT COUNT(*) INTO v_pending FROM friendships
  WHERE requester_id = v_user AND status = 'pending';
  IF v_pending >= 50 THEN
    RAISE EXCEPTION 'too_many_requests';
  END IF;

  INSERT INTO friendships (requester_id, addressee_id) VALUES (v_user, v_target);
  RETURN 'pending';
END;
$$;

GRANT EXECUTE ON FUNCTION send_friend_request(TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION send_friend_request(TEXT) FROM anon;

-- From 20261002_gamification.sql; also rejects control characters in the
-- city and country codes that aren't two letters.
CREATE OR REPLACE FUNCTION set_my_city(p_city TEXT, p_country_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_city TEXT := NULLIF(INITCAP(BTRIM(REGEXP_REPLACE(COALESCE(p_city, ''), '\s+', ' ', 'g'))), '');
  v_cc TEXT := NULLIF(UPPER(BTRIM(COALESCE(p_country_code, ''))), '');
  v_slug TEXT;
  v_community UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF v_city IS NOT NULL AND LENGTH(v_city) > 60 THEN
    RAISE EXCEPTION 'city too long' USING ERRCODE = '22001';
  END IF;
  IF v_city IS NOT NULL AND v_city ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'invalid city' USING ERRCODE = '22023';
  END IF;
  IF v_cc IS NOT NULL AND v_cc !~ '^[A-Z]{2}$' THEN
    RAISE EXCEPTION 'invalid country code' USING ERRCODE = '22023';
  END IF;

  IF v_city IS NOT NULL THEN
    v_slug := BTRIM(REGEXP_REPLACE(LOWER(v_city), '[^a-z0-9]+', '-', 'g'), '-');
    IF v_slug = '' THEN
      -- Nothing Latin left (e.g. a city written in another script): a
      -- stable hash keeps each city its own community instead of every
      -- such name collapsing into one 'local-xx-' slug. No letters or
      -- digits at all ('!!!') is not a city.
      -- (Locale-independent: non-ASCII letters are neither space nor punct.)
      IF v_city !~ '[^[:space:][:punct:]]' THEN
        RAISE EXCEPTION 'invalid city' USING ERRCODE = '22023';
      END IF;
      v_slug := 'u' || LEFT(MD5(LOWER(v_city)), 16);
    END IF;
    v_slug := 'local-' || LOWER(COALESCE(v_cc, 'xx')) || '-' || v_slug;
  END IF;

  UPDATE profiles SET city = v_city, country_code = v_cc WHERE id = v_user;

  DELETE FROM community_members cm
  USING communities c
  WHERE cm.community_id = c.id AND c.type = 'local' AND cm.user_id = v_user;

  IF v_city IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO communities (slug, name, type, city, country_code, description, icon_key, sort)
  VALUES (v_slug, v_city, 'local', v_city, v_cc, 'People near you in ' || v_city, 'local', 5)
  ON CONFLICT (slug) DO UPDATE SET slug = EXCLUDED.slug
  RETURNING id INTO v_community;

  INSERT INTO community_members (community_id, user_id) VALUES (v_community, v_user)
  ON CONFLICT DO NOTHING;

  RETURN v_community;
END;
$$;

GRANT EXECUTE ON FUNCTION set_my_city(TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION set_my_city(TEXT, TEXT) FROM anon;

-- From 20261009_weekly_summary.sql; bounds the zone name before using it.
CREATE OR REPLACE FUNCTION public.set_my_timezone(p_tz TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_tz IS NOT NULL AND (char_length(p_tz) > 64 OR p_tz ~ '[[:cntrl:][:space:]]') THEN
    RAISE EXCEPTION 'invalid time zone' USING ERRCODE = '22023';
  END IF;
  -- Rejects names Postgres doesn't know (raises invalid_parameter_value).
  PERFORM now() AT TIME ZONE p_tz;
  UPDATE profiles SET timezone = p_tz
  WHERE id = auth.uid() AND timezone IS DISTINCT FROM p_tz;
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_timezone(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_timezone(TEXT) TO authenticated;

-- From 20261005_push_tokens.sql; checks the platform and token characters
-- with a clear error instead of a constraint violation.
CREATE OR REPLACE FUNCTION register_push_token(p_token TEXT, p_platform TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_token IS NULL OR LENGTH(p_token) NOT BETWEEN 20 AND 4096 THEN
    RAISE EXCEPTION 'invalid token';
  END IF;
  IF p_token ~ '[[:cntrl:][:space:]]' THEN
    RAISE EXCEPTION 'invalid token' USING ERRCODE = '22023';
  END IF;
  IF p_platform IS NULL OR p_platform NOT IN ('android', 'ios') THEN
    RAISE EXCEPTION 'invalid platform' USING ERRCODE = '22023';
  END IF;

  INSERT INTO push_tokens (token, user_id, platform)
  VALUES (p_token, auth.uid(), p_platform)
  ON CONFLICT (token) DO UPDATE
  SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = NOW();

  -- Caps tokens per account (reinstalls leave stale ones behind).
  DELETE FROM push_tokens
  WHERE user_id = auth.uid() AND token IN (
    SELECT token FROM push_tokens WHERE user_id = auth.uid()
    ORDER BY updated_at DESC OFFSET 10);
END;
$$;

GRANT EXECUTE ON FUNCTION register_push_token(TEXT, TEXT) TO authenticated;
REVOKE EXECUTE ON FUNCTION register_push_token(TEXT, TEXT) FROM anon;

-- From 20261007_username_confirmation.sql. The Google name and photo come
-- from auth metadata, which the user controls; they are now cleaned to fit
-- the profile constraints above, so a long name can't stop the profile from
-- being created.
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
  v_name TEXT;
  v_avatar TEXT;
BEGIN
  SELECT * INTO u FROM auth.users WHERE id = p_user;
  IF NOT FOUND OR u.email_confirmed_at IS NULL OR u.email IS NULL THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = p_user) THEN
    RETURN;
  END IF;

  v_meta := COALESCE(u.raw_user_meta_data, '{}'::jsonb);

  -- Display name: no control characters, at most 50 characters.
  v_name := NULLIF(BTRIM(LEFT(BTRIM(REGEXP_REPLACE(
    COALESCE(v_meta->>'full_name', v_meta->>'name', ''), '[[:cntrl:]]', ' ', 'g')), 50)), '');
  -- Photo: an http(s) URL without spaces, at most 2048 characters.
  v_avatar := COALESCE(v_meta->>'avatar_url', v_meta->>'picture');
  IF v_avatar IS NOT NULL AND (char_length(v_avatar) > 2048 OR v_avatar !~* '^https?://'
      OR v_avatar ~ '[[:cntrl:][:space:]]') THEN
    v_avatar := NULL;
  END IF;

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
        v_name,
        v_avatar,
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

-- set_username() / username_available() already enforce the username rule
-- through _username_error(), so they are unchanged.

-- From 20261010_challenges.sql; caps the friend list before filtering it.
CREATE OR REPLACE FUNCTION public.create_challenge(
  p_metric TEXT,
  p_days INTEGER,
  p_friend_ids UUID[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_id UUID;
  v_friends UUID[];
  v_actor JSONB;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_metric NOT IN ('active_minutes', 'distance_km', 'workouts') THEN
    RAISE EXCEPTION 'invalid_metric';
  END IF;
  IF p_days NOT IN (3, 7, 14) THEN RAISE EXCEPTION 'invalid_duration'; END IF;
  -- The app sends 1-9 distinct friends; refuse oversized arrays before
  -- scanning them.
  IF p_friend_ids IS NULL OR cardinality(p_friend_ids) = 0 THEN
    RAISE EXCEPTION 'no_friends_selected';
  END IF;
  IF cardinality(p_friend_ids) > 9 THEN RAISE EXCEPTION 'too_many_friends'; END IF;

  -- Only accepted friends, without duplicates or the caller.
  SELECT ARRAY_AGG(DISTINCT f.friend) INTO v_friends
  FROM (
    SELECT CASE WHEN fr.requester_id = v_user THEN fr.addressee_id ELSE fr.requester_id END AS friend
    FROM friendships fr
    WHERE fr.status = 'accepted' AND v_user IN (fr.requester_id, fr.addressee_id)
  ) f
  WHERE f.friend = ANY (p_friend_ids);

  IF v_friends IS NULL OR array_length(v_friends, 1) = 0 THEN
    RAISE EXCEPTION 'no_friends_selected';
  END IF;
  IF array_length(v_friends, 1) > 9 THEN RAISE EXCEPTION 'too_many_friends'; END IF;
  IF (SELECT COUNT(*) FROM challenges WHERE creator_id = v_user
        AND created_at > now() - INTERVAL '1 day') >= 5 THEN
    RAISE EXCEPTION 'too_many_challenges';
  END IF;

  INSERT INTO challenges (creator_id, metric, starts_at, ends_at)
  VALUES (v_user, p_metric, now(), now() + make_interval(days => p_days))
  RETURNING id INTO v_id;

  INSERT INTO challenge_participants (challenge_id, user_id, status, responded_at)
  VALUES (v_id, v_user, 'joined', now());
  INSERT INTO challenge_participants (challenge_id, user_id)
  SELECT v_id, unnest(v_friends);

  v_actor := COALESCE(_notification_actor(v_user), '{}'::jsonb);
  INSERT INTO notifications (user_id, type, title, body, actor_id, data)
  SELECT friend, 'challenge', 'New challenge',
    '@' || COALESCE(v_actor->>'username', 'A friend') || ' challenged you: most '
      || CASE p_metric WHEN 'active_minutes' THEN 'active minutes'
                       WHEN 'distance_km' THEN 'distance'
                       ELSE 'workouts' END
      || ' in ' || p_days || ' days',
    v_user,
    v_actor || jsonb_build_object('challenge_id', v_id, 'route', 'challenges')
  FROM unnest(v_friends) AS friend;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_challenge(TEXT, INTEGER, UUID[]) TO authenticated;
