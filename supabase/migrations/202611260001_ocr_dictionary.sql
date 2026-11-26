BEGIN;
CREATE FUNCTION app_private.ocr_lexicon() RETURNS TABLE (hanzi text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT DISTINCT v.hanzi FROM app.vocabulary v JOIN app.vocabulary_revisions r
    ON r.id=v.published_revision_id WHERE r.status='published'
$$;
REVOKE ALL ON FUNCTION app_private.ocr_lexicon() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION app_private.ocr_lexicon() TO app_api,app_worker;

CREATE FUNCTION app_private.ocr_match_token() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  selected record;
BEGIN
  NEW.lookup_state := 'unmatched';
  NEW.entry_id := NULL;
  NEW.vietnamese := NULL;
  SELECT word.* INTO selected FROM (
    SELECT v.id,r.pinyin_display,r.vietnamese,count(*) OVER () AS matches
    FROM app.vocabulary v JOIN app.vocabulary_revisions r ON r.id=v.published_revision_id
    WHERE v.hanzi=NEW.hanzi AND r.status='published' LIMIT 1
  ) word WHERE word.matches=1;
  IF FOUND THEN
    NEW.entry_id := selected.id;
    NEW.pinyin := selected.pinyin_display;
    NEW.vietnamese := selected.vietnamese;
    NEW.lookup_state := 'matched';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION app_private.ocr_match_token() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER ocr_match_token BEFORE INSERT ON app.ocr_tokens
  FOR EACH ROW EXECUTE FUNCTION app_private.ocr_match_token();
COMMIT;
