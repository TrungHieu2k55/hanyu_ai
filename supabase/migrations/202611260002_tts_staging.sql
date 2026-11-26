BEGIN;

CREATE TABLE app.tts_uploads (
  lease uuid PRIMARY KEY,
  object_key text NOT NULL UNIQUE CHECK (object_key ~ '^tts/[a-f0-9-]+[.]wav$'),
  cleanup_after timestamptz NOT NULL DEFAULT clock_timestamp() + interval '10 minutes'
);
CREATE INDEX tts_uploads_due ON app.tts_uploads (cleanup_after, lease);
REVOKE ALL ON app.tts_uploads FROM PUBLIC, anon, authenticated;
GRANT INSERT, DELETE ON app.tts_uploads TO app_api;
GRANT SELECT (lease) ON app.tts_uploads TO app_api;

INSERT INTO app.tts_uploads (lease, object_key, cleanup_after)
SELECT lease, object_key, greatest(clock_timestamp(), lease_until) + interval '10 minutes'
FROM app.tts_cache WHERE state <> 'ready';

CREATE FUNCTION app_private.claim_tts_cleanup(p_limit integer)
RETURNS TABLE (id uuid, object_key text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS $$
  WITH due AS (
    SELECT u.lease FROM app.tts_uploads u
    WHERE u.cleanup_after <= clock_timestamp()
      AND NOT EXISTS (SELECT FROM app.tts_cache c WHERE c.object_key = u.object_key AND c.state = 'ready')
    ORDER BY u.cleanup_after, u.lease
    LIMIT greatest(1, least(p_limit, 100)) FOR UPDATE OF u SKIP LOCKED
  )
  UPDATE app.tts_uploads u SET cleanup_after = clock_timestamp() + interval '5 minutes'
  FROM due WHERE u.lease = due.lease RETURNING u.lease, u.object_key
$$;

CREATE FUNCTION app_private.finish_tts_cleanup(p_lease uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS $$
  DELETE FROM app.tts_uploads WHERE lease = p_lease
$$;
REVOKE ALL ON FUNCTION app_private.claim_tts_cleanup(integer), app_private.finish_tts_cleanup(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.claim_tts_cleanup(integer), app_private.finish_tts_cleanup(uuid)
  TO app_cleanup;

COMMIT;
