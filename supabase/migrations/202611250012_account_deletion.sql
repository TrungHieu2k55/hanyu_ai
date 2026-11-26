BEGIN;

CREATE TABLE app_private.account_deletions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid UNIQUE,
  subject_hash text NOT NULL UNIQUE CHECK (subject_hash ~ '^[0-9a-f]{64}$'),
  receipt_hash text NOT NULL UNIQUE CHECK (receipt_hash ~ '^[0-9a-f]{64}$'),
  receipt_expires_at timestamptz NOT NULL,
  idempotency_key uuid NOT NULL,
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','processing','completed','failed')),
  data_purged boolean NOT NULL DEFAULT false,
  error_code text,
  lease_token uuid,
  available_at timestamptz NOT NULL DEFAULT clock_timestamp()+interval '60 seconds',
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((status='completed') = (owner_id IS NULL))
);
REVOKE ALL ON app_private.account_deletions FROM PUBLIC,anon,authenticated,app_api;

CREATE FUNCTION app_private.begin_account_deletion(p_session uuid,p_subject_hash text,p_receipt text,p_key uuid)
RETURNS TABLE (receipt_expires_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  actor uuid := nullif(current_setting('app.actor_id',true),'')::uuid;
  deletion uuid;
  expiry timestamptz := clock_timestamp()+interval '7 days';
BEGIN
  IF actor IS NULL OR p_subject_hash IS DISTINCT FROM nullif(current_setting('app.subject_hash',true),'')
     OR NOT app_private.actor_can_write() OR NOT EXISTS (SELECT FROM app.profiles WHERE id=actor)
     OR NOT EXISTS (SELECT FROM auth.sessions WHERE id=p_session AND user_id=actor)
  THEN RETURN; END IF;
  INSERT INTO app_private.account_deletions(owner_id,subject_hash,receipt_hash,receipt_expires_at,idempotency_key)
  VALUES(actor,p_subject_hash,p_receipt,expiry,p_key) RETURNING id INTO deletion;
  INSERT INTO app_private.subject_tombstones(subject_hash,deletion_id,retain_until)
  VALUES(p_subject_hash,deletion,clock_timestamp()+interval '180 days');
  UPDATE app.ai_jobs SET status='canceled',completed_at=clock_timestamp(),lease_token=NULL,locked_until=NULL
  WHERE owner_id=actor AND status IN ('queued','processing');
  RETURN QUERY SELECT expiry;
END $$;

CREATE FUNCTION app_private.deletion_status(p_receipt text)
RETURNS TABLE(status text,updated_at timestamptz,retryable boolean,error_code text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT d.status,d.updated_at,d.status='failed',d.error_code
  FROM app_private.account_deletions d WHERE d.receipt_hash=p_receipt AND d.receipt_expires_at>clock_timestamp()
$$;

CREATE FUNCTION app_private.claim_account_deletion()
RETURNS TABLE(id uuid,owner_id uuid,lease_token uuid,data_purged boolean)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH chosen AS (SELECT d.id FROM app_private.account_deletions d
     WHERE d.status IN ('requested','failed','processing') AND d.available_at<=clock_timestamp()
     ORDER BY d.available_at,d.id LIMIT 1 FOR UPDATE SKIP LOCKED)
  UPDATE app_private.account_deletions d SET status='processing',error_code=NULL,lease_token=gen_random_uuid(),
     available_at=clock_timestamp()+interval '5 minutes',updated_at=clock_timestamp()
  FROM chosen WHERE d.id=chosen.id RETURNING d.id,d.owner_id,d.lease_token,d.data_purged
$$;

CREATE FUNCTION app_private.prepare_deletion_objects(p_id uuid,p_lease uuid)
RETURNS TABLE(bucket text,object_key text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid;
BEGIN
  SELECT d.owner_id INTO actor FROM app_private.account_deletions d
  WHERE d.id=p_id AND d.lease_token=p_lease AND d.status='processing' AND d.available_at>clock_timestamp()
  FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  DELETE FROM auth.sessions WHERE user_id=actor;
  RETURN QUERY
    SELECT m.bucket,m.object_key FROM app.media_assets m WHERE m.owner_id=actor AND m.state<>'deleted'
    UNION ALL SELECT 'hanyu-learning-private'::text,u.object_key FROM app.admin_media_uploads u
      WHERE u.owner_id=actor AND u.state<>'deleted';
END $$;

CREATE FUNCTION app_private.purge_deletion_data(p_id uuid,p_lease uuid) RETURNS boolean
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
    'personal_entries','test_answers','test_answer_saves','test_attempts','transcription_drafts','roleplay_sessions',
    'prediction_attempts','quiz_attempts','ocr_tokens','ocr_revisions','ai_jobs','ocr_scans','media_assets',
    'consent_events','operations']
  LOOP
    EXECUTE format('DELETE FROM app.%I WHERE owner_id=$1',item) USING actor;
  END LOOP;
  DELETE FROM app.profiles WHERE id=actor;
  UPDATE app_private.account_deletions SET data_purged=true WHERE id=p_id;
  RETURN true;
END $$;

CREATE FUNCTION app_private.finish_account_deletion(p_id uuid,p_lease uuid,p_error text)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH changed AS (UPDATE app_private.account_deletions
    SET status=CASE WHEN p_error IS NULL THEN 'completed' ELSE 'failed' END,error_code=p_error,
        owner_id=CASE WHEN p_error IS NULL THEN NULL ELSE owner_id END,lease_token=NULL,
        available_at=clock_timestamp()+interval '5 minutes',updated_at=clock_timestamp()
    WHERE id=p_id AND lease_token=p_lease AND status='processing' AND (p_error IS NOT NULL OR data_purged)
    RETURNING id)
  SELECT EXISTS(SELECT FROM changed)
$$;

REVOKE ALL ON FUNCTION app_private.begin_account_deletion(uuid,text,text,uuid), app_private.deletion_status(text),
 app_private.claim_account_deletion(),app_private.prepare_deletion_objects(uuid,uuid),
 app_private.purge_deletion_data(uuid,uuid),app_private.finish_account_deletion(uuid,uuid,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION app_private.begin_account_deletion(uuid,text,text,uuid),app_private.deletion_status(text) TO app_api;
GRANT EXECUTE ON FUNCTION app_private.claim_account_deletion(),app_private.prepare_deletion_objects(uuid,uuid),
 app_private.purge_deletion_data(uuid,uuid),app_private.finish_account_deletion(uuid,uuid,text) TO app_cleanup;

COMMIT;
