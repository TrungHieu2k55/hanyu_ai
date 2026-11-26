BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap', 'consent.record', 'ocr.create', 'ocr.edit',
                           'job.cancel', 'learning.save', 'learning.state', 'note.create',
                           'note.edit', 'note.delete', 'note.default'));
ALTER TABLE app.operations DROP CONSTRAINT operations_resource_type_check,
  ADD CHECK (resource_type IN ('job', 'profile', 'consent', 'ocr_revision', 'learning_item', 'personal_note'));

CREATE TABLE app.vocabulary (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hanzi text NOT NULL CHECK (char_length(btrim(hanzi)) BETWEEN 1 AND 100),
  reading_key text NOT NULL CHECK (char_length(btrim(reading_key)) BETWEEN 1 AND 300),
  sense_id uuid NOT NULL,
  published_revision_id uuid,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (hanzi, reading_key, sense_id)
);
CREATE TABLE app.vocabulary_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL REFERENCES app.vocabulary (id),
  revision integer NOT NULL CHECK (revision >= 1),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','published','withdrawn')),
  pinyin_display text NOT NULL CHECK (char_length(btrim(pinyin_display)) BETWEEN 1 AND 300),
  vietnamese text NOT NULL CHECK (char_length(btrim(vietnamese)) BETWEEN 1 AND 1000),
  hsk_level smallint CHECK (hsk_level BETWEEN 1 AND 3),
  examples jsonb NOT NULL DEFAULT '[]' CHECK (
    jsonb_typeof(examples) = 'array' AND jsonb_array_length(examples) <= 5
  ),
  part_of_speech text,
  source_name text NOT NULL,
  source_external_id text NOT NULL,
  source_version text NOT NULL,
  license text NOT NULL,
  author_id uuid REFERENCES app.profiles (id) ON DELETE SET NULL,
  reviewer_id uuid REFERENCES app.profiles (id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  published_at timestamptz,
  content_hash text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, entry_id),
  UNIQUE (entry_id, revision),
  UNIQUE (entry_id, source_name, source_external_id, source_version),
  CHECK (status <> 'published' OR
    (length(btrim(license)) > 0 AND reviewed_at IS NOT NULL AND published_at IS NOT NULL))
);
ALTER TABLE app.vocabulary ADD FOREIGN KEY (published_revision_id, id)
  REFERENCES app.vocabulary_revisions (id, entry_id);

CREATE TABLE app.personal_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  hanzi text NOT NULL CHECK (char_length(btrim(hanzi)) BETWEEN 1 AND 100),
  pinyin text CHECK (char_length(btrim(pinyin)) BETWEEN 1 AND 300),
  vietnamese text CHECK (char_length(btrim(vietnamese)) BETWEEN 1 AND 1000),
  source_kind text NOT NULL CHECK (source_kind IN ('manual','ocr','roleplay')),
  source_context jsonb NOT NULL DEFAULT '{}',
  linked_entry_id uuid REFERENCES app.vocabulary (id),
  linked_at timestamptz,
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id)
);
CREATE TABLE app.learning_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  entry_id uuid REFERENCES app.vocabulary (id),
  vocabulary_revision_id uuid,
  personal_entry_id uuid,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','merged')),
  merged_into_id uuid,
  selected_note_id uuid,
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, owner_id),
  UNIQUE (owner_id, entry_id),
  UNIQUE (owner_id, personal_entry_id),
  CHECK (num_nonnulls(entry_id, personal_entry_id) = 1),
  CHECK ((entry_id IS NULL) = (vocabulary_revision_id IS NULL)),
  CHECK ((status = 'merged') = (merged_into_id IS NOT NULL) AND merged_into_id IS DISTINCT FROM id),
  FOREIGN KEY (vocabulary_revision_id, entry_id) REFERENCES app.vocabulary_revisions (id, entry_id),
  FOREIGN KEY (personal_entry_id, owner_id) REFERENCES app.personal_entries (id, owner_id),
  FOREIGN KEY (merged_into_id, owner_id) REFERENCES app.learning_items (id, owner_id)
);
CREATE TABLE app.personal_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  item_id uuid NOT NULL,
  text text NOT NULL CHECK (char_length(btrim(text)) BETWEEN 1 AND 4000),
  source_item_id uuid,
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  updated_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE (id, item_id, owner_id),
  FOREIGN KEY (item_id, owner_id) REFERENCES app.learning_items (id, owner_id),
  FOREIGN KEY (source_item_id, owner_id) REFERENCES app.learning_items (id, owner_id)
);
ALTER TABLE app.learning_items ADD FOREIGN KEY (selected_note_id, id, owner_id)
  REFERENCES app.personal_notes (id, item_id, owner_id);

CREATE TABLE app.review_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles (id),
  item_id uuid NOT NULL UNIQUE,
  ease_factor numeric(8,4) NOT NULL DEFAULT 2.5 CHECK (ease_factor >= 1.3),
  interval_days integer NOT NULL DEFAULT 0 CHECK (interval_days >= 0),
  repetitions integer NOT NULL DEFAULT 0 CHECK (repetitions >= 0),
  due_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  last_quality smallint CHECK (last_quality IN (0,3,4,5)),
  version bigint NOT NULL DEFAULT 1 CHECK (version >= 1),
  algorithm_version text NOT NULL DEFAULT 'hanyu-sm2-v1' CHECK (algorithm_version = 'hanyu-sm2-v1'),
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  FOREIGN KEY (item_id, owner_id) REFERENCES app.learning_items (id, owner_id)
);
CREATE INDEX learning_list_order ON app.learning_items (owner_id, created_at DESC, id DESC);
CREATE INDEX learning_notes_order ON app.personal_notes (owner_id, item_id, created_at DESC, id DESC);
CREATE INDEX review_schedule_due ON app.review_schedules (owner_id, due_at, item_id)
  WHERE archived_at IS NULL;

DO $$
DECLARE item text;
BEGIN
  FOREACH item IN ARRAY ARRAY['personal_entries','learning_items','personal_notes','review_schedules']
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

REVOKE ALL ON app.vocabulary, app.vocabulary_revisions FROM PUBLIC, anon, authenticated;
ALTER TABLE app.vocabulary_revisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY visible_vocabulary_revisions ON app.vocabulary_revisions FOR SELECT TO app_api USING (
  (status = 'published' AND EXISTS (
    SELECT 1 FROM app.vocabulary v WHERE v.id = entry_id AND v.published_revision_id = vocabulary_revisions.id
  ))
  OR (status IN ('published', 'withdrawn') AND EXISTS (
    SELECT 1 FROM app.learning_items i WHERE i.vocabulary_revision_id = vocabulary_revisions.id
  ))
);
GRANT SELECT ON app.vocabulary, app.vocabulary_revisions TO app_api;
GRANT SELECT ON app.personal_entries, app.learning_items, app.personal_notes, app.review_schedules TO app_api;
GRANT INSERT (owner_id, hanzi, pinyin, vietnamese, source_kind, source_context)
  ON app.personal_entries TO app_api;
GRANT INSERT (owner_id, entry_id, vocabulary_revision_id, personal_entry_id)
  ON app.learning_items TO app_api;
GRANT UPDATE (status, version, selected_note_id) ON app.learning_items TO app_api;
CREATE POLICY can_delete_note ON app.personal_notes AS RESTRICTIVE FOR DELETE TO app_api
  USING (app_private.actor_can_write());
GRANT INSERT (owner_id, item_id, text), UPDATE (text, version, updated_at), DELETE
  ON app.personal_notes TO app_api;
GRANT INSERT (owner_id, item_id) ON app.review_schedules TO app_api;

COMMIT;
