BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate',
    'exam.start', 'exam.answer', 'exam.submit', 'profile.update', 'personal.edit', 'personal.link',
    'sample.resolve', 'ocr.delete', 'media.delete', 'feedback.create', 'feedback.update',
    'admin.word.create', 'admin.word.revise', 'admin.test.revise', 'content.transition',
    'admin.scenario.revise', 'writing.quiz'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event', 'test_attempt',
    'test_answer_save', 'vocabulary_revision', 'ocr_scan', 'media', 'feedback_report', 'test_revision',
    'scenario_revision', 'quiz_attempt'));

CREATE TABLE app.scenarios (
  id text PRIMARY KEY CHECK (id IN ('tourist','directions','taobao','business')),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 200),
  published_revision_id uuid
);
INSERT INTO app.scenarios (id,title) VALUES ('tourist','Đón khách tại Đà Nẵng'),
  ('directions','Hỏi đường'), ('taobao','Mua hàng Taobao'), ('business','Giao tiếp thương mại');
CREATE TABLE app.scenario_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id text NOT NULL REFERENCES app.scenarios(id),
  revision integer NOT NULL CHECK (revision > 0),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','published','withdrawn')),
  content jsonb NOT NULL CHECK (jsonb_typeof(content) = 'object'),
  reviewer_id uuid REFERENCES app.profiles(id) ON DELETE SET NULL,
  published_at timestamptz,
  UNIQUE (id,scenario_id), UNIQUE (scenario_id,revision),
  CHECK (status <> 'published' OR published_at IS NOT NULL)
);
ALTER TABLE app.scenarios ADD FOREIGN KEY (published_revision_id,id) REFERENCES app.scenario_revisions(id,scenario_id);
ALTER TABLE app.scenarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.scenario_revisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.scenarios, app.scenario_revisions FROM PUBLIC, anon, authenticated;
CREATE POLICY shared_scenarios ON app.scenarios FOR SELECT TO app_api USING (true);
CREATE POLICY edit_scenario_pointer ON app.scenarios FOR UPDATE TO app_api
  USING (app_private.actor_is_admin()) WITH CHECK (app_private.actor_is_admin());
CREATE POLICY read_scenario_revision ON app.scenario_revisions FOR SELECT TO app_api USING (
  app_private.actor_is_admin() OR (status = 'published' AND EXISTS (
    SELECT FROM app.scenarios s WHERE s.published_revision_id = scenario_revisions.id
  ))
);
CREATE POLICY admin_scenario_insert ON app.scenario_revisions FOR INSERT TO app_api WITH CHECK (app_private.actor_is_admin());
CREATE POLICY admin_scenario_update ON app.scenario_revisions FOR UPDATE TO app_api
  USING (app_private.actor_is_admin()) WITH CHECK (app_private.actor_is_admin());
GRANT SELECT ON app.scenarios, app.scenario_revisions TO app_api;
GRANT UPDATE (published_revision_id) ON app.scenarios TO app_api;
GRANT INSERT (scenario_id,revision,content), UPDATE (status,reviewer_id,published_at) ON app.scenario_revisions TO app_api;

CREATE TABLE app.characters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hanzi text NOT NULL UNIQUE CHECK (char_length(btrim(hanzi)) BETWEEN 1 AND 2),
  published_revision_id uuid,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
CREATE TABLE app.character_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  character_id uuid NOT NULL REFERENCES app.characters (id),
  revision integer NOT NULL CHECK (revision >= 1),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','published','withdrawn')),
  stroke_count smallint NOT NULL CHECK (stroke_count BETWEEN 1 AND 100),
  object_key text NOT NULL CHECK (object_key ~ '^strokes/[a-zA-Z0-9_-]+[.]json$'),
  source text NOT NULL CHECK (char_length(btrim(source)) BETWEEN 1 AND 500),
  license text NOT NULL CHECK (char_length(btrim(license)) BETWEEN 1 AND 1000),
  UNIQUE (id,character_id), UNIQUE (character_id,revision)
);
ALTER TABLE app.characters ADD FOREIGN KEY (published_revision_id,id) REFERENCES app.character_revisions(id,character_id);
ALTER TABLE app.character_revisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY read_published_strokes ON app.character_revisions FOR SELECT TO app_api USING (
  status = 'published' AND EXISTS (SELECT FROM app.characters c WHERE c.published_revision_id = character_revisions.id)
);
REVOKE ALL ON app.characters, app.character_revisions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON app.characters, app.character_revisions TO app_api;
UPDATE storage.buckets SET allowed_mime_types = array_append(allowed_mime_types,'application/json')
  WHERE id = 'hanyu-learning-private' AND NOT ('application/json' = ANY(allowed_mime_types));

CREATE TABLE app.quiz_attempts (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  operation_id uuid NOT NULL UNIQUE,
  character_revision_id uuid NOT NULL REFERENCES app.character_revisions(id),
  required_strokes smallint NOT NULL CHECK (required_strokes BETWEEN 1 AND 100),
  completed_strokes smallint NOT NULL CHECK (completed_strokes BETWEEN 0 AND required_strokes),
  mistakes integer NOT NULL CHECK (mistakes BETWEEN 0 AND 10000),
  hints integer NOT NULL CHECK (hints BETWEEN 0 AND 10000),
  duration_ms integer NOT NULL CHECK (duration_ms BETWEEN 0 AND 86400000),
  status text NOT NULL CHECK (status IN ('in_progress','completed')),
  score smallint CHECK (score BETWEEN 0 AND 100),
  formula_version text NOT NULL DEFAULT 'stroke-v1' CHECK (formula_version = 'stroke-v1'),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id,owner_id),
  CHECK ((status = 'completed') = (completed_strokes = required_strokes AND score IS NOT NULL)),
  CHECK (status = 'completed' OR score IS NULL),
  FOREIGN KEY (operation_id,owner_id) REFERENCES app.operations(id,owner_id)
);
ALTER TABLE app.quiz_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.quiz_attempts FROM PUBLIC, anon, authenticated;
CREATE POLICY own_quiz ON app.quiz_attempts TO app_api
  USING (owner_id = nullif(current_setting('app.actor_id',true),'')::uuid)
  WITH CHECK (owner_id = nullif(current_setting('app.actor_id',true),'')::uuid AND app_private.actor_can_write());
GRANT SELECT, INSERT ON app.quiz_attempts TO app_api;
ALTER TABLE app.activity_events DROP CONSTRAINT activity_events_check,
  ADD COLUMN quiz_attempt_id uuid UNIQUE,
  ADD FOREIGN KEY (quiz_attempt_id,owner_id) REFERENCES app.quiz_attempts(id,owner_id),
  ADD CHECK (num_nonnulls(review_event_id,test_attempt_id,quiz_attempt_id) = 1);
GRANT INSERT (owner_id,quiz_attempt_id,occurred_at) ON app.activity_events TO app_api;

COMMIT;
