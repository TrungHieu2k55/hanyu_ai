BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
    'job.cancel', 'learning.save', 'learning.state', 'note.create', 'note.edit', 'note.delete',
    'note.default', 'review.start', 'review.state', 'review.reveal', 'review.rate'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item',
    'personal_note', 'review_session', 'review_session_item', 'review_event'));

CREATE TABLE app.review_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'abandoned')),
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  CHECK ((status IN ('completed', 'abandoned')) = (ended_at IS NOT NULL))
);
CREATE UNIQUE INDEX one_open_review_session ON app.review_sessions (owner_id)
  WHERE status IN ('active', 'paused');

CREATE TABLE app.review_session_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  session_id uuid NOT NULL,
  item_id uuid NOT NULL,
  position smallint NOT NULL CHECK (position BETWEEN 1 AND 20),
  content_snapshot jsonb NOT NULL CHECK (jsonb_typeof(content_snapshot) = 'object'),
  schedule_version bigint NOT NULL CHECK (schedule_version >= 1),
  revealed_at timestamptz,
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'reviewed', 'skipped')),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, item_id, owner_id),
  UNIQUE (session_id, position),
  UNIQUE (session_id, item_id),
  FOREIGN KEY (session_id, owner_id) REFERENCES app.review_sessions (id, owner_id),
  FOREIGN KEY (item_id, owner_id) REFERENCES app.learning_items (id, owner_id),
  CHECK (state <> 'reviewed' OR revealed_at IS NOT NULL)
);

CREATE TABLE app.review_events (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  item_id uuid NOT NULL,
  session_item_id uuid NOT NULL UNIQUE,
  operation_id uuid NOT NULL UNIQUE,
  quality smallint NOT NULL CHECK (quality IN (0, 3, 4, 5)),
  before_state jsonb NOT NULL CHECK (jsonb_typeof(before_state) = 'object'),
  after_state jsonb NOT NULL CHECK (jsonb_typeof(after_state) = 'object'),
  algorithm_version text NOT NULL DEFAULT 'hanyu-sm2-v1' CHECK (algorithm_version = 'hanyu-sm2-v1'),
  accepted_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  FOREIGN KEY (session_item_id, item_id, owner_id)
    REFERENCES app.review_session_items (id, item_id, owner_id),
  FOREIGN KEY (operation_id, owner_id) REFERENCES app.operations (id, owner_id)
);
CREATE INDEX review_history ON app.review_events (owner_id, accepted_at DESC, id);

CREATE TABLE app.activity_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  review_event_id uuid NOT NULL UNIQUE,
  occurred_at timestamptz NOT NULL,
  local_day date GENERATED ALWAYS AS ((occurred_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date) STORED,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  FOREIGN KEY (review_event_id, owner_id) REFERENCES app.review_events (id, owner_id)
);
CREATE INDEX activity_by_local_day ON app.activity_events (owner_id, local_day, id);

DO $$
DECLARE item text;
BEGIN
  FOREACH item IN ARRAY ARRAY['review_sessions','review_session_items','review_events','activity_events']
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
GRANT SELECT ON app.review_sessions, app.review_session_items, app.review_events, app.activity_events TO app_api;
GRANT INSERT (owner_id) ON app.review_sessions TO app_api;
GRANT UPDATE (status, version, ended_at) ON app.review_sessions TO app_api;
GRANT INSERT (owner_id, session_id, item_id, position, content_snapshot, schedule_version)
  ON app.review_session_items TO app_api;
GRANT UPDATE (state, revealed_at) ON app.review_session_items TO app_api;
GRANT INSERT (id, owner_id, item_id, session_item_id, operation_id, quality, before_state, after_state, accepted_at)
  ON app.review_events TO app_api;
GRANT INSERT (owner_id, review_event_id, occurred_at) ON app.activity_events TO app_api;
GRANT UPDATE (ease_factor, interval_days, repetitions, due_at, last_quality, version)
  ON app.review_schedules TO app_api;

COMMIT;
