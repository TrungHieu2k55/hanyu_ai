BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate',
    'exam.start', 'exam.answer', 'exam.submit', 'profile.update', 'personal.edit', 'personal.link',
    'sample.resolve', 'ocr.delete', 'media.delete', 'feedback.create', 'feedback.update',
    'admin.word.create', 'admin.word.revise', 'admin.test.revise', 'content.transition',
    'admin.scenario.revise', 'writing.quiz', 'roleplay.start', 'roleplay.end', 'roleplay.delete',
    'roleplay.text_draft', 'roleplay.confirm', 'profile.avatar'));
GRANT UPDATE (avatar_media_id) ON app.profiles TO app_api;
CREATE INDEX avatar_media_cleanup ON app.media_assets (expires_at,id)
  WHERE kind = 'avatar' AND state IN ('staging','delete_pending');

CREATE OR REPLACE FUNCTION app_private.claim_ocr_media_cleanup(p_limit integer)
RETURNS TABLE (id uuid, bucket text, object_key text, version bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS $$
  WITH due AS (
    SELECT m.id FROM app.media_assets m
    WHERE ((kind = 'ocr_image' AND state IN ('staging', 'ready', 'delete_pending'))
          OR (kind = 'avatar' AND state IN ('staging','delete_pending')))
      AND expires_at <= clock_timestamp()
    ORDER BY expires_at, m.id LIMIT greatest(1, least(p_limit, 100)) FOR UPDATE SKIP LOCKED
  )
  UPDATE app.media_assets m
  SET state = 'delete_pending', version = m.version + 1,
      expires_at = clock_timestamp() + interval '5 minutes'
  FROM due WHERE m.id = due.id
  RETURNING m.id, m.bucket, m.object_key, m.version
$$;
CREATE OR REPLACE FUNCTION app_private.finish_ocr_media_cleanup(p_id uuid, p_version bigint)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS $$
  UPDATE app.media_assets SET state = 'deleted', deleted_at = clock_timestamp(), version = version + 1
  WHERE id = p_id AND version = p_version AND state = 'delete_pending' AND kind IN ('ocr_image','avatar')
$$;

COMMIT;
