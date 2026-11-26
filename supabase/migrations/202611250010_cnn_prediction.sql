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
    'import.start', 'import.map', 'import.validate', 'import.confirm', 'writing.predict','writing.confirm'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event', 'test_attempt',
    'test_answer_save', 'vocabulary_revision', 'ocr_scan', 'media', 'feedback_report', 'test_revision',
    'scenario_revision', 'quiz_attempt', 'roleplay_session', 'transcription_draft', 'admin_media',
    'import_batch','prediction_attempt'));
CREATE TABLE app.model_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_version text NOT NULL UNIQUE CHECK (char_length(model_version) BETWEEN 1 AND 100),
  status text NOT NULL CHECK (status IN ('candidate','published','archived')),
  weights_sha256 text NOT NULL CHECK (weights_sha256 ~ '^[0-9a-f]{64}$'),
  preprocess_version text NOT NULL,
  confidence_threshold numeric CHECK (confidence_threshold BETWEEN 0 AND 1),
  margin_threshold numeric CHECK (margin_threshold BETWEEN 0 AND 1),
  CHECK ((confidence_threshold IS NULL) = (margin_threshold IS NULL))
);
CREATE UNIQUE INDEX one_published_cnn ON app.model_versions ((1)) WHERE status='published';
CREATE TABLE app.model_classes (
  model_id uuid NOT NULL REFERENCES app.model_versions(id),
  class_index integer NOT NULL CHECK (class_index >= 0),
  character_id uuid NOT NULL REFERENCES app.characters(id),
  PRIMARY KEY (model_id,class_index),
  UNIQUE (model_id,character_id)
);
REVOKE ALL ON app.model_versions,app.model_classes FROM PUBLIC,anon,authenticated;
GRANT SELECT ON app.model_versions,app.model_classes TO app_api;
CREATE TABLE app.prediction_attempts (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  model_id uuid NOT NULL REFERENCES app.model_versions(id),
  operation_id uuid NOT NULL UNIQUE,
  candidates jsonb NOT NULL CHECK (jsonb_typeof(candidates)='array' AND jsonb_array_length(candidates)=3),
  uncertainty text NOT NULL CHECK (uncertainty IN ('not_calibrated','low_confidence','normal')),
  confirmed_character_id uuid,
  confirmed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id,owner_id),
  CHECK ((confirmed_character_id IS NULL) = (confirmed_at IS NULL)),
  FOREIGN KEY (model_id,confirmed_character_id) REFERENCES app.model_classes(model_id,character_id),
  FOREIGN KEY (operation_id,owner_id) REFERENCES app.operations(id,owner_id)
);
ALTER TABLE app.prediction_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.prediction_attempts FROM PUBLIC,anon,authenticated;
CREATE POLICY own_prediction ON app.prediction_attempts TO app_api
  USING (owner_id=nullif(current_setting('app.actor_id',true),'')::uuid)
  WITH CHECK (owner_id=nullif(current_setting('app.actor_id',true),'')::uuid AND app_private.actor_can_write());
GRANT SELECT, INSERT ON app.prediction_attempts TO app_api;
GRANT UPDATE (confirmed_character_id,confirmed_at) ON app.prediction_attempts TO app_api;
ALTER TABLE app.activity_events DROP CONSTRAINT activity_events_check,
  ADD COLUMN prediction_attempt_id uuid UNIQUE,
  ADD FOREIGN KEY (prediction_attempt_id,owner_id) REFERENCES app.prediction_attempts(id,owner_id),
  ADD CHECK (num_nonnulls(review_event_id,test_attempt_id,quiz_attempt_id,prediction_attempt_id)=1);
GRANT INSERT (owner_id,prediction_attempt_id,occurred_at) ON app.activity_events TO app_api;

COMMIT;
