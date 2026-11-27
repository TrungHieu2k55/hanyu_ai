BEGIN;

CREATE TABLE app.study_lessons (
  id text NOT NULL,
  revision integer NOT NULL CHECK (revision > 0),
  kind text NOT NULL CHECK (kind IN ('pinyin','radical','grammar','sentence_order','pronunciation','dictation')),
  hsk_level smallint NOT NULL CHECK (hsk_level BETWEEN 1 AND 3),
  title text NOT NULL,
  explanation text NOT NULL,
  exercise jsonb NOT NULL,
  solution jsonb NOT NULL,
  published boolean NOT NULL DEFAULT false,
  released_at timestamptz,
  CHECK (NOT published OR released_at IS NOT NULL),
  PRIMARY KEY (id, revision)
);
CREATE UNIQUE INDEX current_study_lesson ON app.study_lessons (id) WHERE published;
ALTER TABLE app.study_lessons ENABLE ROW LEVEL SECURITY;
CREATE POLICY published_lessons ON app.study_lessons FOR SELECT TO app_api USING (released_at IS NOT NULL);
GRANT SELECT ON app.study_lessons TO app_api;

CREATE TABLE app.study_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles(id) ON DELETE CASCADE,
  client_key uuid NOT NULL,
  payload_hash text NOT NULL,
  lesson_id text NOT NULL,
  revision integer NOT NULL,
  correct boolean NOT NULL,
  feedback text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (owner_id, client_key),
  FOREIGN KEY (lesson_id, revision) REFERENCES app.study_lessons(id, revision)
);
CREATE INDEX study_attempts_history ON app.study_attempts (owner_id, created_at DESC, id DESC);
CREATE TABLE app.study_decks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES app.profiles(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 80),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, owner_id)
);
CREATE INDEX study_decks_owner ON app.study_decks(owner_id, created_at, id);
CREATE TABLE app.study_deck_items (
  owner_id uuid NOT NULL REFERENCES app.profiles(id) ON DELETE CASCADE,
  deck_id uuid NOT NULL,
  item_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (deck_id, item_id),
  FOREIGN KEY (deck_id, owner_id) REFERENCES app.study_decks(id, owner_id) ON DELETE CASCADE,
  FOREIGN KEY (item_id, owner_id) REFERENCES app.learning_items(id, owner_id) ON DELETE CASCADE
);

CREATE TABLE app.study_lookups (
  owner_id uuid NOT NULL REFERENCES app.profiles(id) ON DELETE CASCADE,
  entry_id uuid NOT NULL REFERENCES app.vocabulary(id),
  viewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (owner_id, entry_id)
);
CREATE INDEX study_lookups_recent ON app.study_lookups(owner_id, viewed_at DESC, entry_id);
CREATE TABLE app.study_lookup_receipts (
  owner_id uuid NOT NULL REFERENCES app.profiles(id) ON DELETE CASCADE,
  client_key uuid NOT NULL,
  entry_id uuid NOT NULL REFERENCES app.vocabulary(id),
  PRIMARY KEY (owner_id, client_key)
);
CREATE TABLE app.study_reminders (
  owner_id uuid PRIMARY KEY REFERENCES app.profiles(id) ON DELETE CASCADE,
  enabled boolean NOT NULL,
  local_time time NOT NULL,
  timezone text NOT NULL,
  weekdays smallint[] NOT NULL CHECK (cardinality(weekdays) BETWEEN 1 AND 7 AND weekdays <@ ARRAY[1,2,3,4,5,6,7]::smallint[])
);

CREATE TABLE app.study_speech_quota (
  owner_id uuid NOT NULL REFERENCES app.profiles(id) ON DELETE CASCADE,
  day date NOT NULL,
  used smallint NOT NULL CHECK (used BETWEEN 1 AND 20),
  PRIMARY KEY (owner_id, day)
);

CREATE TABLE app.study_speech_requests (
  owner_id uuid NOT NULL REFERENCES app.profiles(id) ON DELETE CASCADE,
  client_key uuid NOT NULL,
  payload_hash text NOT NULL,
  transcript text,
  valid_until timestamptz NOT NULL DEFAULT clock_timestamp() + interval '30 seconds',
  PRIMARY KEY (owner_id, client_key)
);
CREATE INDEX study_speech_expiry ON app.study_speech_requests(valid_until);
CREATE INDEX study_speech_quota_day ON app.study_speech_quota(day);

CREATE FUNCTION app_private.purge_study_speech() RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  DELETE FROM app.study_speech_requests WHERE valid_until < clock_timestamp() - interval '1 day';
  DELETE FROM app.study_speech_quota WHERE day < (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 7;
$$;
REVOKE ALL ON FUNCTION app_private.purge_study_speech() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION app_private.purge_study_speech() TO app_cleanup;

DO $$
DECLARE item text;
BEGIN
  FOREACH item IN ARRAY ARRAY['study_attempts','study_decks','study_deck_items','study_lookups','study_lookup_receipts','study_reminders','study_speech_quota','study_speech_requests']
  LOOP
    EXECUTE format('ALTER TABLE app.%I ENABLE ROW LEVEL SECURITY', item);
    EXECUTE format('REVOKE ALL ON app.%I FROM PUBLIC, anon, authenticated', item);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON app.%I TO app_api', item);
    EXECUTE format('CREATE POLICY own_rows ON app.%I TO app_api USING (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid) WITH CHECK (owner_id = nullif(current_setting(''app.actor_id'', true), '''')::uuid AND app_private.actor_can_write())', item);
  END LOOP;
END
$$;
REVOKE ALL ON app.study_lessons FROM PUBLIC, anon, authenticated;

-- Original demo exercises. Replace by publishing reviewed revisions.
INSERT INTO app.study_lessons(id,revision,kind,hsk_level,title,explanation,exercise,solution,published,released_at) VALUES
  ('pinyin-four-tones', 1, 'pinyin', 1, 'Bốn thanh điệu với ma', 'Mā cao và ngang. Má đi lên. Mǎ hạ rồi lên khi đọc riêng. Mà đi xuống.', '{"prompt":"Âm nào mang thanh 3?","options":[{"id":"a","text":"mā"},{"id":"b","text":"má"},{"id":"c","text":"mǎ"},{"id":"d","text":"mà"}],"tone_audio":{"a":"妈","b":"麻","c":"马","d":"骂"}}', '{"accepted":["c"],"feedback":"Dấu ˇ trong mǎ biểu thị thanh 3."}', true, now()),
  ('radical-person', 1, 'radical', 1, 'Bộ Nhân trong 你', 'Dạng đứng của 人 là 亻. Trong 你, 亻 là bộ bên trái.', '{"prompt":"Bộ nào đứng bên trái chữ 你?","options":[{"id":"a","text":"亻"},{"id":"b","text":"口"},{"id":"c","text":"木"}]}', '{"accepted":["a"],"feedback":"Chữ 你 (nǐ) có bộ 亻 bên trái."}', true, now()),
  ('grammar-ma', 1, 'grammar', 1, 'Câu hỏi với 吗', 'Đặt 吗 cuối câu trần thuật để tạo câu hỏi có/không.', '{"prompt":"Câu nào hỏi «Bạn là học sinh à?»","options":[{"id":"a","text":"你是学生吗？"},{"id":"b","text":"我是学生。"}]}', '{"accepted":["a"],"feedback":"吗 đánh dấu câu hỏi có/không."}', true, now()),
  ('grammar-because', 1, 'grammar', 2, 'Nối nguyên nhân và kết quả', '因为 nêu nguyên nhân, 所以 dẫn kết quả.', '{"prompt":"Chọn từ nối kết quả. 因为下雨，___ 我坐公交车。","options":[{"id":"a","text":"所以"},{"id":"b","text":"但是"},{"id":"c","text":"或者"}]}', '{"accepted":["a"],"feedback":"所以 có nghĩa «cho nên»."}', true, now()),
  ('grammar-concession', 1, 'grammar', 3, 'Diễn đạt sự nhượng bộ', '虽然 nêu điều được thừa nhận, 但是 đưa ra ý tương phản.', '{"prompt":"Điền từ nối. 虽然他很忙，___ 他每天都学习。","options":[{"id":"a","text":"所以"},{"id":"b","text":"但是"},{"id":"c","text":"因为"}]}', '{"accepted":["b"],"feedback":"虽然…但是… tương đương «tuy… nhưng…»."}', true, now()),
  ('sentence-school', 1, 'sentence_order', 1, 'Ghép câu đi học', 'Câu đơn có thể theo thứ tự chủ ngữ – động từ – tân ngữ.', '{"prompt":"Xếp thành câu «Tôi đi đến trường».","options":[{"id":"school","text":"学校"},{"id":"go","text":"去"},{"id":"i","text":"我"}]}', '{"accepted":[["i","go","school"]],"feedback":"我去学校。"}', true, now()),
  ('pronunciation-intro', 1, 'pronunciation', 1, 'Nói một câu tự giới thiệu', 'Nghe câu mẫu và nói lại. Kết quả so bản chép lời với câu mẫu.', '{"prompt":"Nói câu mẫu.","reference_text":"你好，我叫小明。","reference_pinyin":"Nǐ hǎo, wǒ jiào Xiǎomíng."}', '{"accepted":["你好我叫小明"],"feedback":"你好，我叫小明。 Xin chào, tôi tên là Tiểu Minh."}', true, now()),
  ('dictation-tea', 1, 'dictation', 1, 'Nghe và viết lại câu', 'Nghe câu mẫu rồi gõ Hán tự.', '{"prompt":"Nghe rồi nhập câu bằng chữ Hán.","audio_text":"我喝茶。"}', '{"accepted":["我喝茶"],"feedback":"我喝茶。 Tôi uống trà."}', true, now());

COMMIT;
