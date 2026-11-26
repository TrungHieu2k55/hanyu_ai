BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate',
    'exam.start', 'exam.answer', 'exam.submit', 'profile.update', 'personal.edit', 'personal.link',
    'sample.resolve', 'ocr.delete', 'media.delete', 'feedback.create', 'feedback.update',
    'admin.word.create', 'admin.word.revise', 'admin.test.revise', 'content.transition'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event', 'test_attempt',
    'test_answer_save', 'vocabulary_revision', 'ocr_scan', 'media', 'feedback_report', 'test_revision'));

CREATE POLICY admin_vocab_revision_read ON app.vocabulary_revisions FOR SELECT TO app_api USING (app_private.actor_is_admin());
CREATE POLICY admin_vocab_revision_insert ON app.vocabulary_revisions FOR INSERT TO app_api WITH CHECK (app_private.actor_is_admin());
CREATE POLICY admin_vocab_revision_update ON app.vocabulary_revisions FOR UPDATE TO app_api
  USING (app_private.actor_is_admin()) WITH CHECK (app_private.actor_is_admin());
GRANT INSERT (entry_id, revision, pinyin_display, vietnamese, hsk_level, examples, part_of_speech,
  source_name, source_external_id, source_version, license, author_id, content_hash) ON app.vocabulary_revisions TO app_api;
GRANT UPDATE (status, reviewer_id, reviewed_at, published_at) ON app.vocabulary_revisions TO app_api;

ALTER TABLE app.vocabulary ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_vocab_root ON app.vocabulary FOR SELECT TO app_api USING (true);
CREATE POLICY admin_vocab_root_insert ON app.vocabulary FOR INSERT TO app_api WITH CHECK (app_private.actor_is_admin());
CREATE POLICY admin_vocab_root_update ON app.vocabulary FOR UPDATE TO app_api
  USING (app_private.actor_is_admin()) WITH CHECK (app_private.actor_is_admin());
GRANT INSERT (id, hanzi, reading_key, sense_id), UPDATE (published_revision_id) ON app.vocabulary TO app_api;

ALTER TABLE app.tests ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_test_root ON app.tests FOR SELECT TO app_api USING (true);
CREATE POLICY admin_test_root_update ON app.tests FOR UPDATE TO app_api
  USING (app_private.actor_is_admin()) WITH CHECK (app_private.actor_is_admin());
GRANT UPDATE (published_revision_id) ON app.tests TO app_api;

ALTER TABLE app.test_revisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_test_revisions ON app.test_revisions FOR SELECT TO app_api USING (
  app_private.actor_is_admin()
  OR EXISTS (SELECT FROM app.tests t WHERE t.published_revision_id = test_revisions.id AND test_revisions.status = 'published')
  OR EXISTS (SELECT FROM app.test_attempts a WHERE a.test_revision_id = test_revisions.id)
);
CREATE POLICY admin_test_revision_insert ON app.test_revisions FOR INSERT TO app_api WITH CHECK (app_private.actor_is_admin());
CREATE POLICY admin_test_revision_update ON app.test_revisions FOR UPDATE TO app_api
  USING (app_private.actor_is_admin()) WITH CHECK (app_private.actor_is_admin());
GRANT INSERT (test_id, revision, source, license), UPDATE (status, reviewer_id, published_at) ON app.test_revisions TO app_api;

ALTER TABLE app.questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_test_questions ON app.questions FOR SELECT TO app_api USING (
  EXISTS (SELECT FROM app.test_revisions r WHERE r.id = questions.test_revision_id)
);
CREATE POLICY admin_test_question_insert ON app.questions FOR INSERT TO app_api WITH CHECK (app_private.actor_is_admin());
GRANT INSERT (id, test_revision_id, position, kind, prompt, options, audio_media_id) ON app.questions TO app_api;
ALTER TABLE app_private.answer_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_exam_key_select ON app_private.answer_keys FOR SELECT TO app_api USING (app_private.actor_is_admin());
CREATE POLICY admin_exam_key_insert ON app_private.answer_keys FOR INSERT TO app_api WITH CHECK (app_private.actor_is_admin());
GRANT SELECT ON app_private.answer_keys TO app_api;
GRANT INSERT (question_id, correct_index, explanation) ON app_private.answer_keys TO app_api;

ALTER TABLE app_private.admin_audit_logs ADD COLUMN reason text;
GRANT INSERT (reason) ON app_private.admin_audit_logs TO app_api;

COMMIT;
