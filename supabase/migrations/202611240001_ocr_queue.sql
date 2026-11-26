BEGIN;

CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS app_private;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_api') THEN
    CREATE ROLE app_api NOLOGIN NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_cleanup') THEN
    CREATE ROLE app_cleanup NOLOGIN NOBYPASSRLS;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname IN ('app_api', 'app_cleanup')
      AND (rolsuper OR rolbypassrls OR rolcreaterole OR rolcreatedb OR rolcanlogin)
  ) THEN
    RAISE EXCEPTION 'The application group roles must be NOLOGIN and unprivileged';
  END IF;
END
$$;

REVOKE ALL ON SCHEMA app, app_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA app, app_private TO app_api;
GRANT USAGE ON SCHEMA app_private TO app_cleanup;

CREATE TABLE app.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id),
  owner_id uuid NOT NULL,
  display_name text NOT NULL CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 80),
  role text NOT NULL DEFAULT 'learner' CHECK (role IN ('learner', 'admin')),
  hsk_target smallint NOT NULL DEFAULT 1 CHECK (hsk_target BETWEEN 1 AND 3),
  daily_minutes smallint NOT NULL DEFAULT 15 CHECK (daily_minutes BETWEEN 5 AND 120),
  sound_enabled boolean NOT NULL DEFAULT true,
  avatar_media_id uuid,
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  updated_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK (owner_id = id),
  UNIQUE (id, owner_id)
);

CREATE TABLE app.operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  operation text NOT NULL CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'job.cancel')),
  client_key uuid NOT NULL,
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[0-9a-f]{64}$'),
  status text NOT NULL CHECK (status IN ('processing', 'completed', 'rejected')),
  resource_type text CHECK (resource_type IN ('job', 'profile', 'consent')),
  resource_id uuid,
  safe_result jsonb,
  replay_until timestamptz NOT NULL DEFAULT (transaction_timestamp() + interval '24 hours'),
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK ((resource_type IS NULL) = (resource_id IS NULL)),
  UNIQUE (id, owner_id),
  UNIQUE (owner_id, operation, client_key)
);

CREATE TABLE app.consent_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  purpose text NOT NULL CHECK (purpose IN ('terms', 'training_handwriting')),
  policy_version text NOT NULL CHECK (char_length(policy_version) BETWEEN 1 AND 80),
  granted boolean NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  operation_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK (purpose <> 'terms' OR granted),
  UNIQUE (id, owner_id),
  UNIQUE (operation_id, purpose),
  FOREIGN KEY (operation_id, owner_id) REFERENCES app.operations (id, owner_id)
);
CREATE INDEX consent_latest_by_owner ON app.consent_events (owner_id, purpose, occurred_at DESC, id DESC);

-- The account-deletion change will add the foreign key to its saga table.
CREATE TABLE app_private.subject_tombstones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_hash text NOT NULL UNIQUE CHECK (subject_hash ~ '^[0-9a-f]{64}$'),
  deletion_id uuid NOT NULL,
  retain_until timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);

CREATE TABLE app.media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  scope text NOT NULL DEFAULT 'personal' CHECK (scope = 'personal'),
  kind text NOT NULL CHECK (kind IN ('ocr_image', 'avatar')),
  bucket text NOT NULL,
  object_key text NOT NULL,
  mime_type text NOT NULL CHECK (mime_type IN ('image/png', 'image/jpeg', 'image/webp')),
  size_bytes bigint NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 8388608),
  sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  state text NOT NULL DEFAULT 'staging'
    CHECK (state IN ('staging', 'ready', 'delete_pending', 'deleted', 'failed')),
  expires_at timestamptz,
  deleted_at timestamptz,
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  UNIQUE (bucket, object_key)
);
ALTER TABLE app.profiles ADD FOREIGN KEY (avatar_media_id, owner_id) REFERENCES app.media_assets (id, owner_id);
CREATE INDEX ocr_media_expiry ON app.media_assets (expires_at, id)
WHERE kind = 'ocr_image' AND state IN ('staging', 'ready', 'delete_pending');

CREATE TABLE app.ocr_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  operation_id uuid NOT NULL UNIQUE,
  image_media_id uuid,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'canceled')),
  raw_text text,
  provider text,
  provider_model text,
  current_revision integer NOT NULL DEFAULT 0 CHECK (current_revision >= 0),
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  FOREIGN KEY (operation_id, owner_id) REFERENCES app.operations (id, owner_id),
  FOREIGN KEY (image_media_id, owner_id) REFERENCES app.media_assets (id, owner_id)
);
CREATE INDEX scans_by_owner ON app.ocr_scans (owner_id, created_at DESC, id DESC);

CREATE TABLE app.ai_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  operation_id uuid NOT NULL UNIQUE,
  kind text NOT NULL CHECK (kind = 'ocr'),
  scan_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'processing', 'completed', 'failed', 'canceled')),
  queue_deadline timestamptz NOT NULL DEFAULT (transaction_timestamp() + interval '60 seconds'),
  processing_started_at timestamptz,
  processing_deadline timestamptz,
  budget_seconds smallint NOT NULL DEFAULT 25 CHECK (budget_seconds = 25),
  lease_token uuid,
  lease_version bigint NOT NULL DEFAULT 0 CHECK (lease_version >= 0),
  locked_until timestamptz,
  execution_attempts smallint NOT NULL DEFAULT 0 CHECK (execution_attempts BETWEEN 0 AND 2),
  provider_config jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(provider_config) = 'object'),
  warnings jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(warnings) = 'array'),
  safe_error_code text,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK (status <> 'processing' OR (
    processing_started_at IS NOT NULL AND processing_deadline IS NOT NULL
    AND lease_token IS NOT NULL AND locked_until IS NOT NULL
  )),
  CHECK ((status IN ('completed', 'failed', 'canceled')) = (completed_at IS NOT NULL)),
  CHECK ((status = 'failed') = (safe_error_code IS NOT NULL)),
  UNIQUE (id, owner_id),
  FOREIGN KEY (operation_id, owner_id) REFERENCES app.operations (id, owner_id),
  FOREIGN KEY (scan_id, owner_id) REFERENCES app.ocr_scans (id, owner_id)
);
CREATE INDEX jobs_by_owner ON app.ai_jobs (owner_id, created_at DESC, id DESC);
CREATE INDEX queued_jobs_by_owner ON app.ai_jobs (owner_id, queue_deadline) WHERE status = 'queued';

CREATE FUNCTION app_private.read_access(p_owner uuid, p_session uuid, p_subject_hash text)
RETURNS TABLE (live_session boolean, deleting boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog
AS $$
  SELECT EXISTS (
    SELECT FROM auth.sessions WHERE id = p_session AND user_id = p_owner
  ), EXISTS (
    SELECT FROM app_private.subject_tombstones WHERE subject_hash = p_subject_hash
  )
  WHERE p_owner = nullif(current_setting('app.actor_id', true), '')::uuid
$$;
REVOKE ALL ON FUNCTION app_private.read_access(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.read_access(uuid, uuid, text) TO app_api;

CREATE FUNCTION app_private.actor_can_write()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog
AS $$
  SELECT nullif(current_setting('app.subject_hash', true), '') IS NOT NULL
    AND NOT EXISTS (
      SELECT FROM app_private.subject_tombstones
      WHERE subject_hash = current_setting('app.subject_hash', true)
    )
$$;
REVOKE ALL ON FUNCTION app_private.actor_can_write() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.actor_can_write() TO app_api;

CREATE FUNCTION app_private.claim_ocr_media_cleanup(p_limit integer)
RETURNS TABLE (id uuid, bucket text, object_key text, version bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog
AS $$
  WITH due AS (
    SELECT m.id FROM app.media_assets m
    WHERE kind = 'ocr_image' AND state IN ('staging', 'ready', 'delete_pending')
      AND expires_at <= clock_timestamp()
    ORDER BY expires_at, m.id LIMIT greatest(1, least(p_limit, 100)) FOR UPDATE SKIP LOCKED
  )
  UPDATE app.media_assets m
  SET state = 'delete_pending', version = m.version + 1,
      expires_at = clock_timestamp() + interval '5 minutes'
  FROM due WHERE m.id = due.id
  RETURNING m.id, m.bucket, m.object_key, m.version
$$;

CREATE FUNCTION app_private.finish_ocr_media_cleanup(p_id uuid, p_version bigint)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog
AS $$
  UPDATE app.media_assets SET state = 'deleted', deleted_at = clock_timestamp(), version = version + 1
  WHERE id = p_id AND version = p_version AND state = 'delete_pending' AND kind = 'ocr_image'
$$;
REVOKE ALL ON FUNCTION app_private.claim_ocr_media_cleanup(integer),
  app_private.finish_ocr_media_cleanup(uuid, bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.claim_ocr_media_cleanup(integer),
  app_private.finish_ocr_media_cleanup(uuid, bigint) TO app_cleanup;

DO $$
DECLARE item text;
BEGIN
  FOREACH item IN ARRAY ARRAY['profiles', 'operations', 'consent_events', 'media_assets', 'ocr_scans', 'ai_jobs']
  LOOP
    EXECUTE format('ALTER TABLE app.%I ENABLE ROW LEVEL SECURITY', item);
    EXECUTE format('REVOKE ALL ON TABLE app.%I FROM PUBLIC, anon, authenticated', item);
    EXECUTE format(
      'CREATE POLICY own_rows ON app.%I TO app_api USING (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid) WITH CHECK (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid AND app_private.actor_can_write())',
      item
    );
  END LOOP;
END
$$;
ALTER TABLE app_private.subject_tombstones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app_private.subject_tombstones FROM PUBLIC, anon, authenticated;
GRANT SELECT ON app.profiles, app.operations, app.consent_events, app.media_assets, app.ocr_scans, app.ai_jobs TO app_api;
GRANT INSERT ON app.operations, app.media_assets, app.ocr_scans, app.ai_jobs TO app_api;
GRANT UPDATE (state, expires_at, version) ON app.media_assets TO app_api;
GRANT UPDATE (status, version) ON app.ocr_scans TO app_api;
GRANT UPDATE (status, completed_at, safe_error_code, lease_token, locked_until) ON app.ai_jobs TO app_api;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('hanyu-ocr-private', 'hanyu-ocr-private', false, 8388608, ARRAY['image/jpeg', 'image/png', 'image/webp']);
CREATE POLICY deny_ocr_direct_objects ON storage.objects AS RESTRICTIVE
FOR ALL TO anon, authenticated
USING (bucket_id <> 'hanyu-ocr-private') WITH CHECK (bucket_id <> 'hanyu-ocr-private');

COMMIT;
