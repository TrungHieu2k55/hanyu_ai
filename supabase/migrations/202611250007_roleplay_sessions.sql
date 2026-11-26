BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate',
    'exam.start', 'exam.answer', 'exam.submit', 'profile.update', 'personal.edit', 'personal.link',
    'sample.resolve', 'ocr.delete', 'media.delete', 'feedback.create', 'feedback.update',
    'admin.word.create', 'admin.word.revise', 'admin.test.revise', 'content.transition',
    'admin.scenario.revise', 'writing.quiz', 'roleplay.start', 'roleplay.end', 'roleplay.delete',
    'roleplay.text_draft', 'roleplay.confirm'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event', 'test_attempt',
    'test_answer_save', 'vocabulary_revision', 'ocr_scan', 'media', 'feedback_report', 'test_revision',
    'scenario_revision', 'quiz_attempt', 'roleplay_session', 'transcription_draft'));

CREATE TABLE app.roleplay_sessions (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  operation_id uuid NOT NULL UNIQUE,
  scenario_revision_id uuid NOT NULL REFERENCES app.scenario_revisions(id),
  scenario_snapshot jsonb NOT NULL CHECK (jsonb_typeof(scenario_snapshot) = 'object'),
  hsk_level smallint NOT NULL CHECK (hsk_level BETWEEN 1 AND 3),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','ended','completed')),
  completed_turns smallint NOT NULL DEFAULT 0 CHECK (completed_turns BETWEEN 0 AND 8),
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  CHECK ((status = 'active') = (ended_at IS NULL)),
  FOREIGN KEY (operation_id,owner_id) REFERENCES app.operations(id,owner_id)
);
CREATE INDEX roleplay_history ON app.roleplay_sessions (owner_id,created_at DESC,id DESC);
CREATE TABLE app.transcription_drafts (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  session_id uuid NOT NULL,
  operation_id uuid NOT NULL UNIQUE,
  audio_media_id uuid,
  raw_transcript text CHECK (char_length(raw_transcript) <= 2000),
  manual_text text CHECK (char_length(btrim(manual_text)) BETWEEN 1 AND 500),
  confirmed_text text CHECK (char_length(btrim(confirmed_text)) BETWEEN 1 AND 500),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','confirmed','consumed','discarded')),
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  confirmed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id,session_id,owner_id),
  CHECK (status NOT IN ('confirmed','consumed') OR (confirmed_text IS NOT NULL AND confirmed_at IS NOT NULL)),
  FOREIGN KEY (session_id,owner_id) REFERENCES app.roleplay_sessions(id,owner_id),
  FOREIGN KEY (operation_id,owner_id) REFERENCES app.operations(id,owner_id),
  FOREIGN KEY (audio_media_id,owner_id) REFERENCES app.media_assets(id,owner_id)
);
CREATE INDEX roleplay_drafts_by_session ON app.transcription_drafts(owner_id,session_id,id);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['roleplay_sessions','transcription_drafts']
  LOOP
    EXECUTE format('ALTER TABLE app.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON app.%I FROM PUBLIC, anon, authenticated', t);
    EXECUTE format(
      'CREATE POLICY own_rows ON app.%I TO app_api USING (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid) WITH CHECK (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid AND app_private.actor_can_write())',
      t
    );
    EXECUTE format('CREATE POLICY can_purge ON app.%I AS RESTRICTIVE FOR DELETE TO app_api USING (app_private.actor_can_write())',t);
  END LOOP;
END
$$;
GRANT SELECT, DELETE ON app.roleplay_sessions, app.transcription_drafts TO app_api;
GRANT INSERT (id, owner_id, operation_id, scenario_revision_id, scenario_snapshot, hsk_level),
  UPDATE (status, version, ended_at) ON app.roleplay_sessions TO app_api;
GRANT INSERT (id, owner_id, session_id, operation_id, manual_text),
  UPDATE (confirmed_text, confirmed_at, status, version) ON app.transcription_drafts TO app_api;

COMMIT;
