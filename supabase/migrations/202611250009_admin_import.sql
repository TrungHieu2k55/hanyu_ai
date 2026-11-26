BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate',
    'exam.start', 'exam.answer', 'exam.submit', 'profile.update', 'personal.edit', 'personal.link',
    'sample.resolve', 'ocr.delete', 'media.delete', 'feedback.create', 'feedback.update',
    'admin.word.create', 'admin.word.revise', 'admin.test.revise', 'content.transition',
    'admin.scenario.revise', 'writing.quiz', 'roleplay.start', 'roleplay.end', 'roleplay.delete',
    'roleplay.text_draft', 'roleplay.confirm', 'profile.avatar', 'admin.media',
    'import.start', 'import.map', 'import.validate', 'import.confirm'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event', 'test_attempt',
    'test_answer_save', 'vocabulary_revision', 'ocr_scan', 'media', 'feedback_report', 'test_revision',
    'scenario_revision', 'quiz_attempt', 'roleplay_session', 'transcription_draft', 'admin_media', 'import_batch'));

CREATE POLICY deny_learning_direct_objects ON storage.objects AS RESTRICTIVE
FOR ALL TO anon, authenticated
USING (bucket_id <> 'hanyu-learning-private') WITH CHECK (bucket_id <> 'hanyu-learning-private');
UPDATE storage.buckets SET allowed_mime_types = array_append(allowed_mime_types,'text/csv')
  WHERE id = 'hanyu-learning-private' AND NOT ('text/csv' = ANY(allowed_mime_types));

CREATE TABLE app.admin_media_uploads (
  id uuid PRIMARY KEY,
  owner_id uuid REFERENCES app.profiles(id),
  kind text NOT NULL CHECK (kind IN ('learning_audio','import_file')),
  object_key text NOT NULL UNIQUE,
  sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  state text NOT NULL DEFAULT 'staging' CHECK (state IN ('staging','ready','delete_pending','deleted')),
  expires_at timestamptz,
  CHECK ((kind = 'import_file') = (owner_id IS NOT NULL)),
  UNIQUE (id,owner_id)
);
CREATE TABLE app.import_batches (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  file_media_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'uploaded' CHECK (status IN ('uploaded','mapped','invalid','validated','completed','failed')),
  mapping jsonb,
  mapping_version bigint NOT NULL DEFAULT 1 CHECK (mapping_version >= 1),
  validated_hash text CHECK (validated_hash ~ '^[0-9a-f]{64}$'),
  total_rows integer NOT NULL DEFAULT 0,
  valid_rows integer NOT NULL DEFAULT 0,
  invalid_rows integer NOT NULL DEFAULT 0,
  inserted_rows integer NOT NULL DEFAULT 0,
  updated_rows integer NOT NULL DEFAULT 0,
  UNIQUE (id,owner_id),
  FOREIGN KEY (file_media_id,owner_id) REFERENCES app.admin_media_uploads(id,owner_id)
);
CREATE TABLE app.import_rows (
  batch_id uuid NOT NULL,
  owner_id uuid NOT NULL,
  line_number integer NOT NULL CHECK (line_number BETWEEN 1 AND 1001),
  errors jsonb NOT NULL DEFAULT '[]',
  content jsonb,
  entry_id uuid REFERENCES app.vocabulary(id),
  revision_id uuid REFERENCES app.vocabulary_revisions(id),
  PRIMARY KEY (batch_id,line_number),
  FOREIGN KEY (batch_id,owner_id) REFERENCES app.import_batches(id,owner_id)
);
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['admin_media_uploads','import_batches','import_rows']
  LOOP
    EXECUTE format('ALTER TABLE app.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('REVOKE ALL ON app.%I FROM PUBLIC, anon, authenticated',t);
    EXECUTE format('CREATE POLICY admin_owns_upload ON app.%I TO app_api USING (
      app_private.actor_is_admin() AND (owner_id IS NULL OR owner_id = nullif(current_setting(''app.actor_id'',true),'''')::uuid))
      WITH CHECK (app_private.actor_is_admin() AND (owner_id IS NULL OR owner_id = nullif(current_setting(''app.actor_id'',true),'''')::uuid))',t);
  END LOOP;
END $$;
GRANT SELECT, INSERT, UPDATE ON app.admin_media_uploads, app.import_batches, app.import_rows TO app_api;
GRANT DELETE ON app.import_rows TO app_api;
ALTER TABLE app.learning_audio ENABLE ROW LEVEL SECURITY;
CREATE POLICY learner_audio ON app.learning_audio FOR SELECT TO app_api USING (
  app_private.actor_is_admin() OR EXISTS (
    SELECT FROM app.questions q JOIN app.test_attempts a ON a.test_revision_id=q.test_revision_id
    WHERE q.audio_media_id=learning_audio.id
  )
);
CREATE POLICY admin_audio_insert ON app.learning_audio FOR INSERT TO app_api WITH CHECK (app_private.actor_is_admin());
GRANT INSERT (id,object_key) ON app.learning_audio TO app_api;

CREATE FUNCTION app_private.claim_admin_media_cleanup(p_limit integer)
RETURNS TABLE (id uuid, object_key text)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS $$
  WITH due AS (
    SELECT m.id FROM app.admin_media_uploads m
    WHERE m.state IN ('staging','ready','delete_pending') AND m.expires_at <= clock_timestamp()
      AND NOT EXISTS (SELECT FROM app.questions q WHERE q.audio_media_id = m.id)
    ORDER BY m.expires_at, m.id LIMIT greatest(1, least(p_limit, 100)) FOR UPDATE SKIP LOCKED
  )
  UPDATE app.admin_media_uploads m SET state = 'delete_pending',
    expires_at = clock_timestamp() + interval '5 minutes'
  FROM due WHERE m.id = due.id RETURNING m.id,m.object_key
$$;
CREATE FUNCTION app_private.finish_admin_media_cleanup(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
  UPDATE app.admin_media_uploads SET state='deleted' WHERE id=p_id AND state='delete_pending';
  DELETE FROM app.learning_audio WHERE id=p_id AND NOT EXISTS (SELECT FROM app.questions WHERE audio_media_id=p_id);
  DELETE FROM app.import_rows WHERE batch_id IN (SELECT id FROM app.import_batches WHERE file_media_id=p_id);
END
$$;
REVOKE ALL ON FUNCTION app_private.claim_admin_media_cleanup(integer),app_private.finish_admin_media_cleanup(uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION app_private.claim_admin_media_cleanup(integer),app_private.finish_admin_media_cleanup(uuid)
  TO app_cleanup;

COMMIT;
