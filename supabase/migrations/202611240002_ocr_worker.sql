BEGIN;

CREATE ROLE app_worker NOLOGIN NOBYPASSRLS;
GRANT USAGE ON SCHEMA app_private TO app_worker;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit', 'job.cancel'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision'));

CREATE TABLE app.ocr_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  scan_id uuid NOT NULL,
  revision integer NOT NULL CHECK (revision >= 0),
  text text NOT NULL CHECK (char_length(text) <= 10000),
  text_hash text NOT NULL CHECK (text_hash ~ '^[0-9a-f]{64}$'),
  origin text NOT NULL CHECK ((origin = 'provider' AND revision = 0) OR (origin = 'user' AND revision > 0)),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  UNIQUE (scan_id, revision),
  FOREIGN KEY (scan_id, owner_id) REFERENCES app.ocr_scans (id, owner_id)
);

CREATE TABLE app.ocr_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  revision_id uuid NOT NULL,
  position integer NOT NULL CHECK (position >= 0),
  hanzi text NOT NULL CHECK (char_length(hanzi) BETWEEN 1 AND 100),
  pinyin text CHECK (char_length(pinyin) BETWEEN 1 AND 300),
  vietnamese text CHECK (char_length(vietnamese) BETWEEN 1 AND 1000),
  confidence numeric(7,6) CHECK (confidence BETWEEN 0 AND 1),
  entry_id uuid,
  lookup_state text NOT NULL DEFAULT 'pending' CHECK (lookup_state IN ('pending', 'matched', 'unmatched', 'error')),
  saved_item_id uuid,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  UNIQUE (revision_id, position),
  FOREIGN KEY (revision_id, owner_id) REFERENCES app.ocr_revisions (id, owner_id)
);

ALTER TABLE app.ocr_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.ocr_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.ocr_revisions, app.ocr_tokens FROM PUBLIC, anon, authenticated;
CREATE POLICY own_revisions ON app.ocr_revisions TO app_api
USING (owner_id = nullif(current_setting('app.actor_id', true), '')::uuid)
WITH CHECK (owner_id = nullif(current_setting('app.actor_id', true), '')::uuid
  AND origin = 'user' AND app_private.actor_can_write());
CREATE POLICY own_tokens ON app.ocr_tokens TO app_api
USING (owner_id = nullif(current_setting('app.actor_id', true), '')::uuid)
WITH CHECK (owner_id = nullif(current_setting('app.actor_id', true), '')::uuid AND app_private.actor_can_write());
GRANT SELECT, INSERT ON app.ocr_revisions, app.ocr_tokens TO app_api;
GRANT UPDATE (current_revision) ON app.ocr_scans TO app_api;

CREATE INDEX ocr_claim_order ON app.ai_jobs (created_at, id) WHERE status IN ('queued', 'processing');
CREATE INDEX ocr_processing_due ON app.ai_jobs (processing_deadline, locked_until) WHERE status = 'processing';

CREATE FUNCTION app_private.claim_ocr_job()
RETURNS TABLE (job_id uuid, owner_id uuid, lease_token uuid, lease_version bigint,
               processing_deadline timestamptz, provider_config jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog
AS $$
  WITH tick AS MATERIALIZED (SELECT clock_timestamp() AS at),
  candidate AS (
    SELECT j.id FROM app.ai_jobs j CROSS JOIN tick t
    WHERE j.kind = 'ocr' AND (
      (j.status = 'queued' AND j.queue_deadline > t.at)
      OR (j.status = 'processing' AND j.locked_until <= t.at
          AND j.processing_deadline > t.at AND j.execution_attempts < 2)
    )
    ORDER BY j.created_at, j.id
    LIMIT 1 FOR UPDATE OF j SKIP LOCKED
  ), claimed AS (
    UPDATE app.ai_jobs j
    SET status = 'processing',
        processing_started_at = coalesce(j.processing_started_at, t.at),
        processing_deadline = coalesce(j.processing_deadline, t.at + interval '25 seconds'),
        lease_token = gen_random_uuid(),
        lease_version = j.lease_version + 1,
        locked_until = least(t.at + interval '10 seconds',
                             coalesce(j.processing_deadline, t.at + interval '25 seconds')),
        execution_attempts = j.execution_attempts + 1
    FROM candidate c CROSS JOIN tick t WHERE j.id = c.id
    RETURNING j.*
  ), scan_updated AS (
    UPDATE app.ocr_scans s SET status = 'processing', version = s.version + 1
    FROM claimed c WHERE s.id = c.scan_id AND s.owner_id = c.owner_id AND s.status = 'queued'
  )
  SELECT c.id, c.owner_id, c.lease_token, c.lease_version, c.processing_deadline, c.provider_config
  FROM claimed c
$$;

CREATE FUNCTION app_private.heartbeat_ocr_job(p_job uuid, p_lease uuid, p_version bigint)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog
AS $$
  WITH tick AS MATERIALIZED (SELECT clock_timestamp() AS at), extended AS (
    UPDATE app.ai_jobs j SET locked_until = least(t.at + interval '10 seconds', j.processing_deadline)
    FROM tick t
    WHERE j.id = p_job AND j.kind = 'ocr' AND j.status = 'processing'
      AND j.lease_token = p_lease AND j.lease_version = p_version
      AND j.locked_until > t.at AND j.processing_deadline > t.at
    RETURNING j.id
  )
  SELECT EXISTS (SELECT FROM extended)
$$;

CREATE FUNCTION app_private.ocr_input(
    p_job uuid, p_lease uuid, p_version bigint, p_subject_hash text
)
RETURNS TABLE (bucket text, object_key text, mime_type text, sha256 text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog
AS $$
  SELECT m.bucket, m.object_key, m.mime_type, m.sha256
  FROM app.ai_jobs j
  JOIN app.ocr_scans s ON s.id = j.scan_id AND s.owner_id = j.owner_id
  JOIN app.media_assets m ON m.id = s.image_media_id AND m.owner_id = s.owner_id
  WHERE j.id = p_job AND j.kind = 'ocr' AND j.status = 'processing'
    AND j.lease_token = p_lease AND j.lease_version = p_version
    AND j.processing_deadline > clock_timestamp() AND j.locked_until > clock_timestamp()
    AND m.kind = 'ocr_image' AND m.state = 'ready' AND m.expires_at > clock_timestamp()
    AND NOT EXISTS (SELECT FROM app_private.subject_tombstones WHERE subject_hash = p_subject_hash)
$$;

CREATE FUNCTION app_private.finish_ocr_job(
  p_job uuid, p_lease uuid, p_version bigint, p_subject_hash text,
  p_raw text, p_hash text, p_provider text, p_model text, p_tokens jsonb,
  p_warnings jsonb, p_error text
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
  job app.ai_jobs%ROWTYPE;
  revision_id uuid;
  terminal text := CASE WHEN p_error IS NULL THEN 'completed' ELSE 'failed' END;
BEGIN
  SELECT j.* INTO job FROM app.ai_jobs j
  WHERE j.id = p_job AND j.kind = 'ocr' AND j.status = 'processing'
    AND j.lease_token = p_lease AND j.lease_version = p_version
  FOR UPDATE;
  IF NOT FOUND OR job.processing_deadline <= clock_timestamp() OR job.locked_until <= clock_timestamp()
    OR EXISTS (SELECT FROM app_private.subject_tombstones WHERE subject_hash = p_subject_hash)
  THEN
    RETURN false;
  END IF;

  IF p_error IS NULL THEN
    IF p_provider IS NULL OR p_model IS NULL OR p_raw IS NULL
      OR job.provider_config ->> p_provider IS DISTINCT FROM p_model
    THEN
      RAISE EXCEPTION 'OCR result does not match pinned provider settings';
    END IF;
    INSERT INTO app.ocr_revisions (owner_id, scan_id, revision, text, text_hash, origin)
    VALUES (job.owner_id, job.scan_id, 0, p_raw, p_hash, 'provider') RETURNING id INTO revision_id;
    INSERT INTO app.ocr_tokens (owner_id, revision_id, position, hanzi, pinyin, confidence)
    SELECT job.owner_id, revision_id, (i - 1)::integer,
           token ->> 'hanzi', token ->> 'pinyin', (token ->> 'confidence')::numeric
    FROM jsonb_array_elements(p_tokens) WITH ORDINALITY AS entries(token, i);
  END IF;

  UPDATE app.ocr_scans
  SET status = terminal, raw_text = p_raw, provider = p_provider, provider_model = p_model,
      version = version + 1
  WHERE id = job.scan_id AND owner_id = job.owner_id AND status = 'processing';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OCR job and scan diverged';
  END IF;
  UPDATE app.ai_jobs SET status = terminal, safe_error_code = p_error, warnings = p_warnings,
      completed_at = clock_timestamp(), lease_token = NULL, locked_until = NULL
  WHERE id = job.id;
  IF job.processing_deadline <= clock_timestamp() OR job.locked_until <= clock_timestamp()
    OR EXISTS (SELECT FROM app_private.subject_tombstones WHERE subject_hash = p_subject_hash)
  THEN
    RAISE EXCEPTION 'OCR lease ended before writing result' USING ERRCODE = '57014';
  END IF;
  RETURN true;
END
$$;

CREATE FUNCTION app_private.sweep_ocr_jobs()
RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog
AS $$
  WITH candidates AS (
    SELECT j.id FROM app.ai_jobs j
    WHERE j.kind = 'ocr' AND (
      (j.status = 'queued' AND j.queue_deadline <= clock_timestamp())
      OR (j.status = 'processing' AND (
        j.processing_deadline <= clock_timestamp()
        OR (j.execution_attempts >= 2 AND j.locked_until <= clock_timestamp())
      ))
    ) ORDER BY j.created_at LIMIT 50 FOR UPDATE SKIP LOCKED
  ), expired AS (
    UPDATE app.ai_jobs j SET status = 'failed', safe_error_code = 'JOB_TIMEOUT',
        completed_at = clock_timestamp(), lease_token = NULL, locked_until = NULL
    FROM candidates c WHERE j.id = c.id RETURNING j.scan_id, j.owner_id
  ), failed_scans AS (
    UPDATE app.ocr_scans s SET status = 'failed', version = s.version + 1
    FROM expired e WHERE s.id = e.scan_id AND s.owner_id = e.owner_id
      AND s.status IN ('queued', 'processing')
  )
  SELECT count(*)::integer FROM expired
$$;

REVOKE ALL ON FUNCTION app_private.claim_ocr_job(),
  app_private.heartbeat_ocr_job(uuid, uuid, bigint),
  app_private.ocr_input(uuid, uuid, bigint, text),
  app_private.finish_ocr_job(uuid, uuid, bigint, text, text, text, text, text, jsonb, jsonb, text),
  app_private.sweep_ocr_jobs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.claim_ocr_job(),
  app_private.heartbeat_ocr_job(uuid, uuid, bigint),
  app_private.ocr_input(uuid, uuid, bigint, text),
  app_private.finish_ocr_job(uuid, uuid, bigint, text, text, text, text, text, jsonb, jsonb, text),
  app_private.sweep_ocr_jobs() TO app_worker;

COMMIT;
