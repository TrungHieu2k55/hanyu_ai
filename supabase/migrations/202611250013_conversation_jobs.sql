BEGIN;

ALTER TABLE app.operations DROP CONSTRAINT operations_operation_check,
  ADD CHECK (operation IN ('profile.bootstrap','consent.record','ocr.create','ocr.edit','job.cancel',
    'learning.save','learning.state','note.create','note.edit','note.delete','note.default',
    'review.start','review.state','review.reveal','review.rate','exam.start','exam.answer','exam.submit',
    'profile.update','personal.edit','personal.link','sample.resolve','ocr.delete','media.delete',
    'feedback.create','feedback.update','admin.word.create','admin.word.revise','admin.test.revise',
    'content.transition','admin.scenario.revise','writing.quiz','roleplay.start','roleplay.end',
    'roleplay.delete','roleplay.text_draft','roleplay.confirm','profile.avatar','admin.media',
    'import.start','import.map','import.validate','import.confirm','writing.predict','writing.confirm',
    'tts.content','roleplay.transcription','roleplay.turn','roleplay.audio'));

ALTER TABLE app.media_assets DROP CONSTRAINT media_assets_kind_check,DROP CONSTRAINT media_assets_mime_type_check,
  DROP CONSTRAINT media_assets_size_bytes_check,
  ADD CHECK (kind IN ('ocr_image','avatar','roleplay_input','roleplay_audio')),
  ADD CHECK (mime_type IN ('image/png','image/jpeg','image/webp','audio/wav','audio/webm','audio/ogg','audio/mp4')),
  ADD CHECK (size_bytes BETWEEN 1 AND 10485760);
UPDATE storage.buckets SET file_size_limit=10485760,
  allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp','audio/wav','audio/webm','audio/ogg','audio/mp4']
WHERE id='hanyu-ocr-private';

CREATE TABLE app.roleplay_turns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles(id),
  session_id uuid NOT NULL,
  draft_id uuid NOT NULL UNIQUE,
  operation_id uuid NOT NULL UNIQUE,
  turn_number smallint NOT NULL CHECK (turn_number BETWEEN 1 AND 8),
  transcript text NOT NULL CHECK (char_length(transcript) BETWEEN 1 AND 500),
  reply_hanzi text NOT NULL CHECK (char_length(reply_hanzi) BETWEEN 1 AND 2000),
  reply_pinyin text NOT NULL CHECK (char_length(reply_pinyin) BETWEEN 1 AND 4000),
  reply_vietnamese text NOT NULL CHECK (char_length(reply_vietnamese) BETWEEN 1 AND 4000),
  feedback jsonb NOT NULL,
  llm_model text NOT NULL,
  text_version integer NOT NULL DEFAULT 1,
  audio_media_id uuid,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(id,session_id,owner_id), UNIQUE(id,owner_id), UNIQUE(session_id,turn_number),
  FOREIGN KEY (session_id,owner_id) REFERENCES app.roleplay_sessions(id,owner_id),
  FOREIGN KEY (draft_id,session_id,owner_id) REFERENCES app.transcription_drafts(id,session_id,owner_id),
  FOREIGN KEY (operation_id,owner_id) REFERENCES app.operations(id,owner_id),
  FOREIGN KEY (audio_media_id,owner_id) REFERENCES app.media_assets(id,owner_id)
);
ALTER TABLE app.roleplay_turns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.roleplay_turns FROM PUBLIC,anon,authenticated;
CREATE POLICY own_turns ON app.roleplay_turns TO app_api
  USING (owner_id=nullif(current_setting('app.actor_id',true),'')::uuid)
  WITH CHECK (owner_id=nullif(current_setting('app.actor_id',true),'')::uuid AND app_private.actor_can_write());
CREATE POLICY purge_turns ON app.roleplay_turns AS RESTRICTIVE FOR DELETE TO app_api
  USING (app_private.actor_can_write());
GRANT SELECT,DELETE ON app.roleplay_turns TO app_api;

ALTER TABLE app.ai_jobs ALTER COLUMN scan_id DROP NOT NULL,
  DROP CONSTRAINT ai_jobs_kind_check,DROP CONSTRAINT ai_jobs_budget_seconds_check,
  ADD COLUMN session_id uuid, ADD COLUMN draft_id uuid, ADD COLUMN turn_id uuid, ADD COLUMN input_media_id uuid,
  ADD CHECK (
    (kind='ocr' AND scan_id IS NOT NULL AND session_id IS NULL AND draft_id IS NULL AND turn_id IS NULL AND input_media_id IS NULL AND budget_seconds=25)
    OR (kind='transcription' AND scan_id IS NULL AND session_id IS NOT NULL AND draft_id IS NOT NULL AND turn_id IS NULL AND input_media_id IS NOT NULL AND budget_seconds=15)
    OR (kind='turn' AND scan_id IS NULL AND session_id IS NOT NULL AND draft_id IS NOT NULL AND input_media_id IS NULL AND budget_seconds=45)
    OR (kind='turn_audio' AND scan_id IS NULL AND session_id IS NOT NULL AND draft_id IS NULL AND turn_id IS NOT NULL AND input_media_id IS NULL AND budget_seconds=18)
  ),
  ADD FOREIGN KEY (session_id,owner_id) REFERENCES app.roleplay_sessions(id,owner_id),
  ADD FOREIGN KEY (draft_id,session_id,owner_id) REFERENCES app.transcription_drafts(id,session_id,owner_id),
  ADD FOREIGN KEY (turn_id,session_id,owner_id) REFERENCES app.roleplay_turns(id,session_id,owner_id),
  ADD FOREIGN KEY (input_media_id,owner_id) REFERENCES app.media_assets(id,owner_id);
CREATE UNIQUE INDEX one_active_roleplay_job ON app.ai_jobs(session_id) WHERE session_id IS NOT NULL AND status IN ('queued','processing');
GRANT INSERT (audio_media_id) ON app.transcription_drafts TO app_api;
ALTER TABLE app.activity_events DROP CONSTRAINT activity_events_check,
  ADD COLUMN turn_id uuid UNIQUE,
  ADD FOREIGN KEY (turn_id,owner_id) REFERENCES app.roleplay_turns(id,owner_id),
  ADD CHECK (num_nonnulls(review_event_id,test_attempt_id,quiz_attempt_id,prediction_attempt_id,turn_id)=1);
GRANT DELETE ON app.activity_events TO app_api;
CREATE POLICY purge_activity ON app.activity_events AS RESTRICTIVE FOR DELETE TO app_api USING (app_private.actor_can_write());

CREATE OR REPLACE FUNCTION app_private.claim_ocr_media_cleanup(p_limit integer)
RETURNS TABLE (id uuid, bucket text, object_key text, version bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS $$
  WITH due AS (SELECT m.id FROM app.media_assets m
    WHERE ((kind <> 'avatar' AND state IN ('staging','ready','delete_pending')) OR
           (kind='avatar' AND state IN ('staging','delete_pending')))
      AND expires_at<=clock_timestamp()
    ORDER BY expires_at,m.id LIMIT greatest(1,least(p_limit,100)) FOR UPDATE SKIP LOCKED)
  UPDATE app.media_assets m SET state='delete_pending',version=m.version+1,
    expires_at=clock_timestamp()+interval '5 minutes'
  FROM due WHERE m.id=due.id RETURNING m.id,m.bucket,m.object_key,m.version
$$;
CREATE OR REPLACE FUNCTION app_private.finish_ocr_media_cleanup(p_id uuid,p_version bigint)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  UPDATE app.media_assets SET state='deleted',deleted_at=clock_timestamp(),version=version+1
  WHERE id=p_id AND version=p_version AND state='delete_pending'
$$;

CREATE FUNCTION app_private.claim_roleplay_job()
RETURNS TABLE(job_id uuid,owner_id uuid,kind text,lease_token uuid,lease_version bigint,processing_deadline timestamptz,provider_config jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH tick AS MATERIALIZED (SELECT clock_timestamp() AS at), candidate AS (
    SELECT j.id FROM app.ai_jobs j CROSS JOIN tick t
    WHERE j.kind<>'ocr' AND ((j.status='queued' AND j.queue_deadline>t.at)
      OR (j.status='processing' AND j.locked_until<=t.at AND j.processing_deadline>t.at AND j.execution_attempts<2))
    ORDER BY j.created_at,j.id LIMIT 1 FOR UPDATE OF j SKIP LOCKED
  ), claimed AS (
    UPDATE app.ai_jobs j SET status='processing',processing_started_at=coalesce(j.processing_started_at,t.at),
      processing_deadline=coalesce(j.processing_deadline,t.at+make_interval(secs=>j.budget_seconds)),
      lease_token=gen_random_uuid(),lease_version=j.lease_version+1,
      locked_until=least(t.at+interval '10 seconds',coalesce(j.processing_deadline,t.at+make_interval(secs=>j.budget_seconds))),
      execution_attempts=j.execution_attempts+1
    FROM candidate c CROSS JOIN tick t WHERE j.id=c.id RETURNING j.*
  )
  SELECT c.id,c.owner_id,c.kind,c.lease_token,c.lease_version,c.processing_deadline,c.provider_config FROM claimed c
$$;
CREATE FUNCTION app_private.heartbeat_roleplay_job(p_id uuid,p_lease uuid,p_version bigint) RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH extended AS (UPDATE app.ai_jobs SET locked_until=least(clock_timestamp()+interval '10 seconds',processing_deadline)
    WHERE id=p_id AND kind<>'ocr' AND status='processing' AND lease_token=p_lease AND lease_version=p_version
      AND locked_until>clock_timestamp() AND processing_deadline>clock_timestamp() RETURNING id)
  SELECT EXISTS(SELECT FROM extended)
$$;
CREATE FUNCTION app_private.roleplay_input(p_id uuid,p_lease uuid,p_version bigint,p_hash text)
RETURNS TABLE(object_key text,mime_type text,sha256 text,confirmed_text text,scenario jsonb,hsk_level smallint,
  history jsonb,reply_hanzi text,system_prompt text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT m.object_key,m.mime_type,m.sha256,d.confirmed_text,s.scenario_snapshot,s.hsk_level,
    (SELECT coalesce(jsonb_agg(jsonb_build_object('transcript',h.transcript,'reply_hanzi',h.reply_hanzi)
      ORDER BY h.turn_number),'[]') FROM app.roleplay_turns h WHERE h.session_id=s.id AND h.owner_id=s.owner_id),
    t.reply_hanzi,r.content->>'system_prompt'
  FROM app.ai_jobs j JOIN app.roleplay_sessions s ON s.id=j.session_id AND s.owner_id=j.owner_id
  JOIN app.scenario_revisions r ON r.id=s.scenario_revision_id
  LEFT JOIN app.transcription_drafts d ON d.id=j.draft_id AND d.owner_id=j.owner_id
  LEFT JOIN app.roleplay_turns t ON t.id=j.turn_id AND t.owner_id=j.owner_id
  LEFT JOIN app.media_assets m ON m.id=j.input_media_id AND m.owner_id=j.owner_id
    AND m.state='ready' AND m.expires_at>clock_timestamp()
  WHERE j.id=p_id AND j.status='processing' AND j.lease_token=p_lease AND j.lease_version=p_version
    AND j.locked_until>clock_timestamp() AND j.processing_deadline>clock_timestamp()
    AND (s.status='active' OR j.kind='turn_audio')
    AND NOT EXISTS (SELECT FROM app_private.subject_tombstones WHERE subject_hash=p_hash)
$$;

CREATE FUNCTION app_private.stage_roleplay_audio(p_id uuid,p_lease uuid,p_version bigint,p_media uuid,p_size bigint,p_sha text,p_hash text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid;
DECLARE key text := 'roleplay/' || p_media::text || '.wav';
BEGIN
 SELECT owner_id INTO actor FROM app.ai_jobs WHERE id=p_id AND lease_token=p_lease AND lease_version=p_version
   AND status='processing' AND kind IN ('turn','turn_audio') AND locked_until>clock_timestamp()
   AND NOT EXISTS(SELECT FROM app_private.subject_tombstones WHERE subject_hash=p_hash);
 IF NOT FOUND THEN RETURN NULL; END IF;
 INSERT INTO app.media_assets(id,owner_id,kind,bucket,object_key,mime_type,size_bytes,sha256,expires_at)
 VALUES(p_media,actor,'roleplay_audio','hanyu-ocr-private',key,'audio/wav',p_size,p_sha,clock_timestamp()+interval '10 minutes');
 RETURN key;
END $$;
CREATE FUNCTION app_private.finish_roleplay_job(p_id uuid,p_lease uuid,p_version bigint,p_hash text,
  p_payload jsonb,p_audio uuid,p_error text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE j app.ai_jobs%ROWTYPE;
DECLARE s app.roleplay_sessions%ROWTYPE;
DECLARE actor uuid;
DECLARE draft app.transcription_drafts%ROWTYPE;
DECLARE turn_key uuid;
DECLARE current_audio uuid;
DECLARE audio_id uuid;
BEGIN
 SELECT owner_id INTO actor FROM app.ai_jobs WHERE id=p_id AND kind<>'ocr';
 IF NOT FOUND THEN RETURN false; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(actor::text,0));
 SELECT * INTO j FROM app.ai_jobs WHERE id=p_id AND status='processing'
    AND lease_token=p_lease AND lease_version=p_version AND locked_until>clock_timestamp()
    AND processing_deadline>clock_timestamp() FOR UPDATE;
 IF NOT FOUND OR EXISTS(SELECT FROM app_private.subject_tombstones WHERE subject_hash=p_hash) THEN RETURN false; END IF;
 SELECT * INTO s FROM app.roleplay_sessions WHERE id=j.session_id AND owner_id=actor;
 IF NOT FOUND OR (s.status<>'active' AND j.kind<>'turn_audio') THEN RETURN false; END IF;
 IF p_error IS NULL THEN
    IF p_audio IS NOT NULL THEN
       UPDATE app.media_assets SET state='ready',version=version+1,expires_at=clock_timestamp()+interval '7 days'
       WHERE id=p_audio AND owner_id=actor AND state='staging' AND kind='roleplay_audio' RETURNING id INTO audio_id;
    END IF;
    IF j.kind='transcription' THEN
       UPDATE app.transcription_drafts SET raw_transcript=p_payload->>'transcript',version=version+1
       WHERE id=j.draft_id AND status='draft';
    ELSIF j.kind='turn' THEN
       SELECT * INTO draft FROM app.transcription_drafts WHERE id=j.draft_id AND owner_id=actor AND status='confirmed';
       IF NOT FOUND OR s.completed_turns>=8 THEN RETURN false; END IF;
       INSERT INTO app.roleplay_turns(owner_id,session_id,draft_id,operation_id,turn_number,transcript,
           reply_hanzi,reply_pinyin,reply_vietnamese,feedback,llm_model,audio_media_id)
       VALUES(actor,s.id,draft.id,j.operation_id,s.completed_turns+1,draft.confirmed_text,p_payload->>'reply_hanzi',
          p_payload->>'reply_pinyin',p_payload->>'reply_vietnamese',p_payload->'feedback',j.provider_config->>'model',audio_id)
       RETURNING id INTO turn_key;
       UPDATE app.transcription_drafts SET status='consumed',version=version+1 WHERE id=draft.id;
       UPDATE app.roleplay_sessions SET completed_turns=completed_turns+1,version=version+1,
         status=CASE WHEN completed_turns=7 THEN 'completed' ELSE status END,
         ended_at=CASE WHEN completed_turns=7 THEN clock_timestamp() ELSE NULL END WHERE id=s.id;
       INSERT INTO app.activity_events(owner_id,turn_id,occurred_at) VALUES(actor,turn_key,clock_timestamp());
    ELSE
       IF audio_id IS NULL THEN RETURN false; END IF;
       SELECT audio_media_id INTO current_audio FROM app.roleplay_turns WHERE id=j.turn_id;
       UPDATE app.roleplay_turns SET audio_media_id=audio_id WHERE id=j.turn_id;
       UPDATE app.media_assets SET state='delete_pending',expires_at=clock_timestamp(),version=version+1
       WHERE id=current_audio AND owner_id=actor AND state='ready';
    END IF;
 END IF;
 UPDATE app.ai_jobs SET status=CASE WHEN p_error IS NULL THEN 'completed' ELSE 'failed' END,
   safe_error_code=p_error,completed_at=clock_timestamp(),lease_token=NULL,locked_until=NULL,
   turn_id=coalesce(turn_key,turn_id),warnings=CASE WHEN p_error IS NULL AND j.kind='turn' AND audio_id IS NULL
      THEN '["TTS_UNAVAILABLE"]'::jsonb ELSE '[]'::jsonb END WHERE id=j.id;
 RETURN true;
END $$;
CREATE FUNCTION app_private.sweep_roleplay_jobs() RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  UPDATE app.ai_jobs SET status='failed',safe_error_code='JOB_TIMEOUT',completed_at=clock_timestamp(),lease_token=NULL,locked_until=NULL
  WHERE kind<>'ocr' AND ((status='queued' AND queue_deadline<=clock_timestamp())
    OR (status='processing' AND (processing_deadline<=clock_timestamp() OR (execution_attempts>=2 AND locked_until<=clock_timestamp()))))
$$;
REVOKE ALL ON FUNCTION app_private.claim_roleplay_job(),app_private.heartbeat_roleplay_job(uuid,uuid,bigint),
  app_private.roleplay_input(uuid,uuid,bigint,text),app_private.stage_roleplay_audio(uuid,uuid,bigint,uuid,bigint,text,text),
  app_private.finish_roleplay_job(uuid,uuid,bigint,text,jsonb,uuid,text),app_private.sweep_roleplay_jobs() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION app_private.claim_roleplay_job(),app_private.heartbeat_roleplay_job(uuid,uuid,bigint),
  app_private.roleplay_input(uuid,uuid,bigint,text),app_private.stage_roleplay_audio(uuid,uuid,bigint,uuid,bigint,text,text),
  app_private.finish_roleplay_job(uuid,uuid,bigint,text,jsonb,uuid,text),app_private.sweep_roleplay_jobs() TO app_worker;

CREATE OR REPLACE FUNCTION app_private.purge_deletion_data(p_id uuid,p_lease uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid;
DECLARE item text;
BEGIN
  SELECT owner_id INTO actor FROM app_private.account_deletions
  WHERE id=p_id AND lease_token=p_lease AND status='processing' AND available_at>clock_timestamp() FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  UPDATE app.profiles SET avatar_media_id=NULL WHERE id=actor;
  UPDATE app.learning_items SET selected_note_id=NULL,merged_into_id=NULL,
    status=CASE WHEN status='merged' THEN 'archived' ELSE status END WHERE owner_id=actor;
  FOREACH item IN ARRAY ARRAY['activity_events','feedback_reports','import_rows','import_batches','admin_media_uploads',
    'review_events','review_session_items','review_sessions','personal_notes','review_schedules','learning_items',
    'personal_entries','test_answers','test_answer_saves','test_attempts','ai_jobs','roleplay_turns','transcription_drafts','roleplay_sessions',
    'prediction_attempts','quiz_attempts','ocr_tokens','ocr_revisions','ocr_scans','media_assets',
    'consent_events','operations']
  LOOP
    EXECUTE format('DELETE FROM app.%I WHERE owner_id=$1',item) USING actor;
  END LOOP;
  DELETE FROM app.profiles WHERE id=actor;
  UPDATE app_private.account_deletions SET data_purged=true WHERE id=p_id;
  RETURN true;
END $$;

COMMIT;
