BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate',
    'exam.start', 'exam.answer', 'exam.submit', 'profile.update', 'personal.edit', 'personal.link', 'sample.resolve',
    'ocr.delete', 'media.delete', 'feedback.create', 'feedback.update'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event', 'test_attempt',
    'test_answer_save', 'vocabulary_revision', 'ocr_scan', 'media', 'feedback_report'));

GRANT UPDATE (display_name, hsk_target, daily_minutes, sound_enabled, version, updated_at)
  ON app.profiles TO app_api;
GRANT UPDATE (hanzi, pinyin, vietnamese, linked_entry_id, linked_at, version) ON app.personal_entries TO app_api;
GRANT UPDATE (merged_into_id) ON app.learning_items TO app_api;
GRANT UPDATE (item_id, source_item_id) ON app.personal_notes TO app_api;
GRANT UPDATE (archived_at), INSERT (ease_factor,interval_days,repetitions,due_at,last_quality,algorithm_version)
  ON app.review_schedules TO app_api;

CREATE TABLE app.vocabulary_sample_mappings (
  sample_id text NOT NULL CHECK (char_length(sample_id) BETWEEN 1 AND 100),
  content_version text NOT NULL CHECK (char_length(content_version) BETWEEN 1 AND 80),
  entry_id uuid NOT NULL REFERENCES app.vocabulary(id),
  PRIMARY KEY (sample_id, content_version)
);
REVOKE ALL ON app.vocabulary_sample_mappings FROM PUBLIC, anon, authenticated;
GRANT SELECT ON app.vocabulary_sample_mappings TO app_api;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['ocr_scans','ocr_revisions','ocr_tokens','ai_jobs']
  LOOP
    EXECUTE format('GRANT DELETE ON app.%I TO app_api', t);
    EXECUTE format(
      'CREATE POLICY can_purge ON app.%I AS RESTRICTIVE FOR DELETE TO app_api USING (app_private.actor_can_write())',
      t
    );
  END LOOP;
END
$$;

CREATE FUNCTION app_private.actor_is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT app_private.actor_can_write() AND EXISTS (
    SELECT FROM app.profiles
    WHERE id = nullif(current_setting('app.actor_id', true), '')::uuid AND role = 'admin'
  )
$$;
REVOKE ALL ON FUNCTION app_private.actor_is_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.actor_is_admin() TO app_api;

CREATE TABLE app.feedback_reports (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  operation_id uuid NOT NULL UNIQUE,
  kind text NOT NULL CHECK (kind IN ('support','content')),
  target_kind text CHECK (target_kind IN ('vocabulary','question','scenario','roleplay_turn')),
  target_id uuid,
  context_snapshot jsonb NOT NULL DEFAULT '{}',
  message text NOT NULL CHECK (char_length(btrim(message)) BETWEEN 1 AND 4000),
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','reviewing','resolved','no_change')),
  resolution_note text CHECK (char_length(btrim(resolution_note)) BETWEEN 1 AND 4000),
  assigned_admin_id uuid REFERENCES app.profiles(id) ON DELETE SET NULL,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK ((target_kind IS NULL) = (target_id IS NULL)),
  CHECK (kind <> 'content' OR target_id IS NOT NULL),
  CHECK ((status IN ('resolved','no_change')) = (closed_at IS NOT NULL)),
  FOREIGN KEY (operation_id, owner_id) REFERENCES app.operations (id, owner_id)
);
CREATE INDEX feedback_owner_sort ON app.feedback_reports(owner_id, created_at DESC, id DESC);
CREATE INDEX feedback_admin_sort ON app.feedback_reports(status, created_at DESC, id DESC);
ALTER TABLE app.feedback_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.feedback_reports FROM PUBLIC, anon, authenticated;
CREATE POLICY read_feedback ON app.feedback_reports FOR SELECT TO app_api USING (
  owner_id = nullif(current_setting('app.actor_id', true), '')::uuid OR app_private.actor_is_admin()
);
CREATE POLICY create_feedback ON app.feedback_reports FOR INSERT TO app_api WITH CHECK (
  owner_id = nullif(current_setting('app.actor_id', true), '')::uuid AND app_private.actor_can_write()
);
CREATE POLICY admin_feedback ON app.feedback_reports FOR UPDATE TO app_api
  USING (app_private.actor_is_admin()) WITH CHECK (app_private.actor_is_admin());
GRANT SELECT ON app.feedback_reports TO app_api;
GRANT INSERT (id, owner_id, operation_id, kind, target_kind, target_id, context_snapshot, message)
  ON app.feedback_reports TO app_api;
GRANT UPDATE (status, resolution_note, assigned_admin_id, closed_at) ON app.feedback_reports TO app_api;

CREATE TABLE app_private.admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid REFERENCES app.profiles(id) ON DELETE SET NULL,
  operation_id uuid UNIQUE,
  action text NOT NULL,
  target_kind text NOT NULL,
  target_id uuid NOT NULL,
  state_before text,
  state_after text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
ALTER TABLE app_private.admin_audit_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app_private.admin_audit_logs FROM PUBLIC, anon, authenticated;
CREATE POLICY admin_audit_write ON app_private.admin_audit_logs FOR INSERT TO app_api WITH CHECK (
  admin_id = nullif(current_setting('app.actor_id', true), '')::uuid AND app_private.actor_is_admin()
);
GRANT INSERT (admin_id, operation_id, action, target_kind, target_id, state_before, state_after)
  ON app_private.admin_audit_logs TO app_api;

COMMIT;
