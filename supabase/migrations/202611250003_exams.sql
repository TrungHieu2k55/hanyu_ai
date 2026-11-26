BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate',
    'exam.start', 'exam.answer', 'exam.submit'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event', 'test_attempt', 'test_answer_save'));

CREATE TABLE app.tests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hsk_level smallint NOT NULL UNIQUE CHECK (hsk_level BETWEEN 1 AND 3),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 200),
  published_revision_id uuid,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
CREATE TABLE app.test_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id uuid NOT NULL REFERENCES app.tests (id),
  revision integer NOT NULL CHECK (revision > 0),
  package_kind text NOT NULL DEFAULT 'p0' CHECK (package_kind IN ('p0','legacy')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','published','withdrawn')),
  duration_seconds integer NOT NULL DEFAULT 1200 CHECK (duration_seconds > 0),
  listening_count smallint NOT NULL DEFAULT 10 CHECK (listening_count >= 0),
  reading_count smallint NOT NULL DEFAULT 10 CHECK (reading_count >= 0),
  source text NOT NULL CHECK (btrim(source) <> ''),
  license text NOT NULL CHECK (btrim(license) <> ''),
  reviewer_id uuid REFERENCES app.profiles (id) ON DELETE SET NULL,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (test_id, revision), UNIQUE (id, test_id),
  CHECK (package_kind <> 'p0' OR (duration_seconds = 1200 AND listening_count = 10 AND reading_count = 10)),
  CHECK (status <> 'published' OR published_at IS NOT NULL)
);
ALTER TABLE app.tests ADD FOREIGN KEY (published_revision_id, id) REFERENCES app.test_revisions (id, test_id);

CREATE TABLE app.learning_audio (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  object_key text NOT NULL UNIQUE CHECK (object_key ~ '^exams/[a-zA-Z0-9_-]+[.](mp3|wav|m4a|ogg)$'),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('hanyu-learning-private','hanyu-learning-private',false,16777216,
  ARRAY['audio/mpeg','audio/wav','audio/mp4','audio/ogg'])
ON CONFLICT (id) DO UPDATE SET public = false;

CREATE TABLE app.questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  test_revision_id uuid NOT NULL REFERENCES app.test_revisions (id),
  position smallint NOT NULL CHECK (position BETWEEN 1 AND 20),
  kind text NOT NULL CHECK (kind IN ('listening','reading')),
  prompt text NOT NULL CHECK (char_length(btrim(prompt)) BETWEEN 1 AND 2000),
  options jsonb NOT NULL CHECK (
    jsonb_typeof(options) = 'array' AND jsonb_array_length(options) = 4 AND
    NOT jsonb_path_exists(options, '$[*] ? (@.type() != "string")')
  ),
  audio_media_id uuid REFERENCES app.learning_audio (id),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, test_revision_id), UNIQUE(test_revision_id, position),
  CHECK (kind <> 'listening' OR audio_media_id IS NOT NULL)
);
CREATE TABLE app_private.answer_keys (
  question_id uuid PRIMARY KEY REFERENCES app.questions (id),
  correct_index smallint NOT NULL CHECK (correct_index BETWEEN 0 AND 3),
  explanation text NOT NULL CHECK (char_length(btrim(explanation)) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
REVOKE ALL ON app_private.answer_keys FROM PUBLIC, anon, authenticated, app_api;
GRANT SELECT ON app.tests, app.test_revisions, app.questions, app.learning_audio TO app_api;

CREATE TABLE app.test_attempts (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  operation_id uuid NOT NULL UNIQUE,
  test_id uuid NOT NULL,
  test_revision_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress','submitted','timed_out','legacy_unverified')),
  started_at timestamptz NOT NULL,
  deadline_at timestamptz NOT NULL,
  submitted_at timestamptz,
  score smallint CHECK (score BETWEEN 0 AND 100),
  listening_score smallint CHECK (listening_score BETWEEN 0 AND 50),
  reading_score smallint CHECK (reading_score BETWEEN 0 AND 50),
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK (deadline_at > started_at),
  CHECK (status NOT IN ('submitted','timed_out') OR
        (submitted_at IS NOT NULL AND listening_score IS NOT NULL AND reading_score IS NOT NULL
         AND score IS NOT NULL AND score = listening_score + reading_score)),
  CHECK (status <> 'in_progress' OR
        (submitted_at IS NULL AND score IS NULL AND listening_score IS NULL AND reading_score IS NULL)),
  UNIQUE (id, owner_id), UNIQUE (id, test_revision_id, owner_id),
  FOREIGN KEY (operation_id, owner_id) REFERENCES app.operations (id, owner_id),
  FOREIGN KEY (test_revision_id, test_id) REFERENCES app.test_revisions (id,test_id)
);
CREATE UNIQUE INDEX test_open_attempt ON app.test_attempts (owner_id, test_id) WHERE status = 'in_progress';
CREATE INDEX test_history ON app.test_attempts (owner_id, created_at DESC, id DESC);
CREATE TABLE app.test_answer_saves (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  attempt_id uuid NOT NULL,
  test_revision_id uuid NOT NULL,
  question_id uuid NOT NULL,
  selected_index smallint CHECK (selected_index BETWEEN 0 AND 3),
  answer_version bigint NOT NULL CHECK (answer_version >= 1),
  accepted_at timestamptz NOT NULL,
  operation_id uuid NOT NULL UNIQUE,
  UNIQUE (attempt_id, question_id, answer_version),
  FOREIGN KEY (attempt_id, test_revision_id, owner_id) REFERENCES app.test_attempts (id, test_revision_id, owner_id),
  FOREIGN KEY (question_id, test_revision_id) REFERENCES app.questions (id, test_revision_id),
  FOREIGN KEY (operation_id, owner_id) REFERENCES app.operations (id, owner_id)
);
CREATE TABLE app.test_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  attempt_id uuid NOT NULL,
  test_revision_id uuid NOT NULL,
  question_id uuid NOT NULL,
  selected_index smallint CHECK (selected_index BETWEEN 0 AND 3),
  answer_version bigint NOT NULL CHECK (answer_version >= 1),
  accepted_at timestamptz NOT NULL,
  last_operation_id uuid NOT NULL,
  UNIQUE (attempt_id, question_id),
  FOREIGN KEY (attempt_id, test_revision_id, owner_id) REFERENCES app.test_attempts (id, test_revision_id, owner_id),
  FOREIGN KEY (question_id, test_revision_id) REFERENCES app.questions (id, test_revision_id),
  FOREIGN KEY (last_operation_id, owner_id) REFERENCES app.operations (id, owner_id)
);
ALTER TABLE app.activity_events ALTER COLUMN review_event_id DROP NOT NULL,
  ADD COLUMN test_attempt_id uuid UNIQUE,
  ADD FOREIGN KEY (test_attempt_id, owner_id) REFERENCES app.test_attempts (id, owner_id),
  ADD CHECK (num_nonnulls(review_event_id, test_attempt_id) = 1);

DO $$
DECLARE item text;
BEGIN
  FOREACH item IN ARRAY ARRAY['test_attempts','test_answers','test_answer_saves']
  LOOP
    EXECUTE format('ALTER TABLE app.%I ENABLE ROW LEVEL SECURITY', item);
    EXECUTE format('REVOKE ALL ON app.%I FROM PUBLIC, anon, authenticated', item);
    EXECUTE format(
      'CREATE POLICY own_rows ON app.%I TO app_api USING (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid) WITH CHECK (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid AND app_private.actor_can_write())',
      item
    );
  END LOOP;
END
$$;
GRANT SELECT ON app.test_attempts, app.test_answers, app.test_answer_saves TO app_api;
GRANT INSERT (id, owner_id, operation_id, test_id, test_revision_id, started_at, deadline_at),
  UPDATE (version) ON app.test_attempts TO app_api;
GRANT INSERT ON app.test_answers, app.test_answer_saves TO app_api;
GRANT UPDATE (selected_index, answer_version, accepted_at, last_operation_id) ON app.test_answers TO app_api;

CREATE FUNCTION app_private.exam_package_ready(p_revision uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT count(*) = 20
    AND count(*) FILTER (WHERE q.kind = 'listening') = 10
    AND count(*) FILTER (WHERE q.kind = 'reading') = 10
  FROM app.questions q JOIN app_private.answer_keys k ON k.question_id = q.id
  JOIN app.test_revisions r ON r.id = q.test_revision_id AND r.status = 'published' AND r.package_kind = 'p0'
  WHERE q.test_revision_id = p_revision
    AND NOT EXISTS (
      SELECT FROM jsonb_array_elements_text(q.options) AS option(value)
      WHERE char_length(btrim(option.value)) NOT BETWEEN 1 AND 1000
    )
$$;

CREATE FUNCTION app_private.exam_finalize(p_attempt uuid, p_submit boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE
  a app.test_attempts%ROWTYPE;
  now_at timestamptz;
  listening integer;
  reading integer;
  answered boolean;
BEGIN
  SELECT * INTO a FROM app.test_attempts t WHERE t.id = p_attempt
    AND t.owner_id = nullif(current_setting('app.actor_id', true), '')::uuid FOR UPDATE;
  IF NOT FOUND OR a.status <> 'in_progress' OR NOT app_private.actor_can_write() THEN RETURN; END IF;
  now_at := clock_timestamp();
  IF NOT p_submit AND now_at < a.deadline_at THEN RETURN; END IF;
  SELECT count(*) FILTER (WHERE q.kind = 'listening' AND u.selected_index = k.correct_index) * 5,
         count(*) FILTER (WHERE q.kind = 'reading' AND u.selected_index = k.correct_index) * 5,
         count(u.selected_index) > 0
    INTO listening, reading, answered
  FROM app.questions q JOIN app_private.answer_keys k ON k.question_id = q.id
  LEFT JOIN app.test_answers u ON u.attempt_id = a.id AND u.question_id = q.id AND u.owner_id = a.owner_id
  WHERE q.test_revision_id = a.test_revision_id;
  UPDATE app.test_attempts SET
    status = CASE WHEN now_at >= a.deadline_at THEN 'timed_out' ELSE 'submitted' END,
    submitted_at = now_at, score = listening + reading, listening_score = listening,
    reading_score = reading, version = version + 1
  WHERE id = a.id;
  IF answered THEN
    INSERT INTO app.activity_events(owner_id, test_attempt_id, occurred_at) VALUES (a.owner_id, a.id, now_at);
  END IF;
END
$$;

CREATE FUNCTION app_private.exam_explanations(p_attempt uuid)
RETURNS TABLE (question_id uuid, selected_index smallint, correct_index smallint, is_correct boolean, explanation text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT q.id, u.selected_index, k.correct_index, coalesce(u.selected_index = k.correct_index, false), k.explanation
  FROM app.test_attempts a JOIN app.questions q ON q.test_revision_id = a.test_revision_id
  JOIN app_private.answer_keys k ON k.question_id = q.id
  LEFT JOIN app.test_answers u ON u.attempt_id = a.id AND u.question_id = q.id AND u.owner_id = a.owner_id
  WHERE a.id = p_attempt AND a.owner_id = nullif(current_setting('app.actor_id', true), '')::uuid
    AND a.status IN ('submitted','timed_out') ORDER BY q.position
$$;
REVOKE ALL ON FUNCTION app_private.exam_package_ready(uuid), app_private.exam_finalize(uuid, boolean),
  app_private.exam_explanations(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.exam_package_ready(uuid), app_private.exam_finalize(uuid, boolean),
  app_private.exam_explanations(uuid) TO app_api;

COMMIT;
