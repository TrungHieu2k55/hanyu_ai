BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap','consent.record','ocr.create','ocr.edit','job.cancel',
    'learning.save','learning.state','note.create','note.edit','note.delete','note.default',
    'review.start','review.state','review.reveal','review.rate','exam.start','exam.answer','exam.submit',
    'profile.update','personal.edit','personal.link','sample.resolve','ocr.delete','media.delete',
    'feedback.create','feedback.update','admin.word.create','admin.word.revise','admin.test.revise',
    'content.transition','admin.scenario.revise','writing.quiz','roleplay.start','roleplay.end',
    'roleplay.delete','roleplay.text_draft','roleplay.confirm','profile.avatar','admin.media',
    'import.start','import.map','import.validate','import.confirm','writing.predict','writing.confirm','tts.content'));

CREATE TABLE app.tts_cache (
  id uuid PRIMARY KEY,
  cache_key text NOT NULL UNIQUE CHECK (cache_key ~ '^[0-9a-f]{64}$'),
  state text NOT NULL CHECK (state IN ('processing','ready','failed')),
  object_key text NOT NULL UNIQUE CHECK (object_key ~ '^tts/[a-f0-9-]+[.]wav$'),
  lease uuid NOT NULL,
  lease_until timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON app.tts_cache FROM PUBLIC,anon,authenticated;
GRANT SELECT, INSERT, UPDATE ON app.tts_cache TO app_api;

COMMIT;
