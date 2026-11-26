import asyncio
import unittest
from datetime import datetime, timedelta
from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from psycopg.types.json import Jsonb
from test_accounts_postgres import POLICIES
from test_api import png, wav
from test_ocr_postgres import DSN, TERMS, FixtureImages, TestTokens, run_async

from app.backend import PostgresBackend
from app.cleanup_ocr import clean_batch
from app.conversation import ConversationWorker, TransientConversationError
from app.main import create_app
from app.ports import Identity
from app.postgres import Database


class FixtureModel:
    version = "test-cnn"
    sha256 = "1" * 64
    preprocess_version = "fixture"

    def logits(self, image):
        assert image
        return [0.0, 2.0, 1.0]


class FixtureVoice:
    model = "fixture-voice"
    voice = "fixture"

    async def speak(self, text):
        assert text
        return b"fixture-audio"


class FixtureConversation:
    calls = 0

    async def transcribe(self, model, media):
        assert model == "fixture-stt" and media.data
        return {"transcript": "多少钱"}

    async def reply(self, model, data):
        self.calls += 1
        if self.calls == 1:
            raise TransientConversationError
        assert model == "fixture-turn" and data["confirmed_text"] == "多少钱？"
        return {
            "reply_hanzi": "十元",
            "reply_pinyin": "shí yuán",
            "reply_vietnamese": "Mười tệ",
            "feedback": {"summary_vi": "Câu hỏi phù hợp", "issues": []},
        }


@unittest.skipUnless(DSN, "Set HANYU_TEST_DATABASE_URL with migrations installed")
class ExamTests(unittest.TestCase):
    def setUp(self):
        self.conn = psycopg.connect(DSN, autocommit=True)
        self.addCleanup(self.conn.close)
        self.users = {actor: Identity(uuid4(), uuid4()) for actor in ("a", "b")}
        for user in self.users.values():
            self.conn.execute("INSERT INTO auth.users VALUES (%s)", (user.user_id,))
            self.conn.execute(
                "INSERT INTO auth.sessions (id, user_id) VALUES (%s,%s)",
                (user.session_id, user.user_id),
            )
        self.learning = FixtureImages()
        audio = self.learning
        audio.objects["exams/sample.mp3"] = b"fixture"
        audio.objects["strokes/sample.json"] = b"{}"
        self.personal = FixtureImages()
        self.db = Database(DSN, bytes(range(32)), TERMS)
        self.client = TestClient(
            create_app(
                verifier=TestTokens(self.users),
                backend=PostgresBackend(
                    self.db,
                    self.personal,
                    policies=POLICIES,
                    learning_storage=audio,
                    cnn_model=FixtureModel(),
                    speech_provider=FixtureVoice(),
                    live_conversation_models={
                        "transcription": "fixture-stt",
                        "turn": "fixture-turn",
                        "turn_audio": "fixture-voice",
                        "tts_voice": "fixture",
                    },
                ),
            ),
            backend_options={"loop_factory": asyncio.SelectorEventLoop},
        )
        self.addCleanup(self.client.close)
        for actor in self.users:
            response = self.client.post(
                "/v1/me/bootstrap",
                headers=self.headers(actor),
                json={
                    "display_name": actor,
                    "terms_version": TERMS,
                    "training_policy_version": POLICIES["training_policy_version"],
                    "training_opt_in": False,
                },
            )
            self.assertEqual(response.status_code, 201, response.text)
        row = self.conn.execute(
            "SELECT id FROM app.tests WHERE hsk_level = 1"
        ).fetchone()
        if row:
            self.test_id = str(row[0])
            self.audio_id = str(
                self.conn.execute(
                    "SELECT id FROM app.learning_audio WHERE object_key = 'exams/sample.mp3'"
                ).fetchone()[0]
            )
            return
        self.test_id, revision, self.audio_id = map(str, (uuid4(), uuid4(), uuid4()))
        self.conn.execute(
            "INSERT INTO app.tests (id,hsk_level,title) VALUES (%s,1,'Fixture')",
            (self.test_id,),
        )
        self.conn.execute(
            "INSERT INTO app.learning_audio (id,object_key) VALUES (%s,'exams/sample.mp3')",
            (self.audio_id,),
        )
        self.conn.execute(
            """INSERT INTO app.test_revisions (id,test_id,revision,source,license,status,published_at)
                              VALUES (%s,%s,1,'fixture','test','published',now())""",
            (revision, self.test_id),
        )
        for n in range(1, 21):
            question = uuid4()
            kind = "listening" if n <= 10 else "reading"
            self.conn.execute(
                """INSERT INTO app.questions (id,test_revision_id,position,kind,prompt,options,audio_media_id)
                    VALUES (%s,%s,%s,%s,'Prompt',%s,%s)""",
                (
                    question,
                    revision,
                    n,
                    kind,
                    Jsonb(["A", "B", "C", "D"]),
                    self.audio_id if n <= 10 else None,
                ),
            )
            self.conn.execute(
                "INSERT INTO app_private.answer_keys (question_id,correct_index,explanation) VALUES (%s,0,'Correct A')",
                (question,),
            )
        self.conn.execute(
            "UPDATE app.tests SET published_revision_id = %s WHERE id = %s",
            (revision, self.test_id),
        )

    @staticmethod
    def headers(actor="a"):
        return {"Authorization": f"Bearer {actor}", "Idempotency-Key": str(uuid4())}

    def start(self):
        return self.client.post(
            "/v1/test-attempts", headers=self.headers(), json={"test_id": self.test_id}
        )

    def test_exam_projection_resumption_revision_and_score(self):
        catalog = self.client.get("/v1/tests", headers=self.headers())
        self.assertEqual(catalog.status_code, 200, catalog.text)
        self.assertEqual(catalog.json()["items"][0]["id"], self.test_id)
        started = self.start()
        self.assertEqual(started.status_code, 201, started.text)
        attempt = started.json()
        path = f"/v1/test-attempts/{attempt['id']}"
        self.assertEqual(
            datetime.fromisoformat(attempt["deadline_at"])
            - datetime.fromisoformat(attempt["started_at"]),
            timedelta(minutes=20),
        )
        self.assertNotIn("correct_index", started.text)
        self.assertNotIn("explanation", started.text)
        self.assertEqual(self.start().json()["deadline_at"], attempt["deadline_at"])
        self.assertEqual(
            self.client.get(path, headers=self.headers("b")).status_code, 404
        )
        self.assertEqual(
            self.client.get(path + "/result", headers=self.headers()).json()["code"],
            "RESULT_NOT_READY",
        )
        audio = f"/v1/media/{self.audio_id}/url"
        self.assertEqual(
            self.client.get(audio, headers=self.headers()).status_code, 200
        )
        self.assertEqual(
            self.client.get(audio, headers=self.headers("b")).status_code, 404
        )
        query = f"{path}/answers/{attempt['questions'][0]['id']}"
        initial = {"selected_index": 1, "expected_answer_version": 0}
        key = self.headers()
        first = self.client.put(query, headers=key, json=initial)
        self.assertEqual(first.status_code, 200, first.text)
        self.assertEqual(
            self.client.put(query, headers=self.headers(), json=initial).json()["code"],
            "STALE_VERSION",
        )
        self.assertEqual(
            self.client.put(
                query,
                headers=self.headers(),
                json={
                    "selected_index": 0,
                    "expected_answer_version": 1,
                },
            ).status_code,
            200,
        )
        old = self.client.put(query, headers=key, json=initial)
        self.assertEqual(old.headers["Idempotency-Replayed"], "true")
        self.assertEqual(old.json(), first.json())
        current = self.client.get(path, headers=self.headers()).json()
        submitted = self.client.post(
            path + "/submit",
            headers=self.headers(),
            json={
                "expected_version": current["version"],
                "confirm": True,
            },
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)
        self.assertEqual(
            (
                submitted.json()["score"],
                submitted.json()["listening_score"],
                submitted.json()["reading_score"],
            ),
            (5, 5, 0),
        )
        self.assertEqual(submitted.json()["answers"][0]["correct_index"], 0)
        self.assertEqual(
            self.client.post(
                path + "/submit",
                headers=self.headers(),
                json={
                    "expected_version": 1,
                    "confirm": True,
                },
            ).json(),
            submitted.json(),
        )
        self.assertEqual(
            self.client.get(path + "/result", headers=self.headers()).json(),
            submitted.json(),
        )
        activities = self.client.get("/v1/activities", headers=self.headers()).json()[
            "items"
        ]
        self.assertEqual(
            [(r["kind"], r["resource_id"]) for r in activities],
            [("test", attempt["id"])],
        )

    def test_deadline_locks_before_late_answer_without_activity(self):
        attempt = self.start().json()
        path = f"/v1/test-attempts/{attempt['id']}"
        self.conn.execute(
            """UPDATE app.test_attempts SET started_at = now() - interval '21 minutes',
             deadline_at = now() - interval '1 minute' WHERE id = %s""",
            (attempt["id"],),
        )
        late = self.client.put(
            f"{path}/answers/{attempt['questions'][0]['id']}",
            headers=self.headers(),
            json={"selected_index": 0, "expected_answer_version": 0},
        )
        self.assertEqual(late.json()["code"], "TEST_EXPIRED")
        result = self.client.get(path + "/result", headers=self.headers()).json()
        self.assertEqual((result["status"], result["score"]), ("timed_out", 0))
        self.assertEqual(
            self.client.get("/v1/activities", headers=self.headers()).json()["items"],
            [],
        )
        history = self.client.get(
            "/v1/test-attempts", params={"status": "locked"}, headers=self.headers()
        ).json()
        self.assertEqual(history["items"][0]["id"], attempt["id"])

    def test_admin_revisions_and_publication_gate(self):
        self.conn.execute(
            "UPDATE app.profiles SET role='admin' WHERE id=%s",
            (self.users["b"].user_id,),
        )
        h = self.headers("b")
        assignment = {
            "hanzi": "词",
            "reading_key": "ci2",
            "content": {
                "pinyin_display": "cí",
                "vietnamese": "từ",
                "source_name": "fixture",
                "source_external_id": "c",
                "source_version": "1",
                "license": "test",
            },
        }
        create = self.client.post("/v1/admin/vocabulary", json=assignment, headers=h)
        self.assertEqual(create.status_code, 201, create.text)
        new = create.json()
        self.assertEqual(new["latest"]["status"], "draft")
        self.assertEqual(
            self.client.get(
                f"/v1/vocabulary/{new['entry_id']}", headers=self.headers()
            ).status_code,
            404,
        )
        self.assertEqual(
            self.client.get("/v1/admin/vocabulary", headers=self.headers()).status_code,
            403,
        )
        transition = (
            f"/v1/admin/content/vocabulary/revisions/{new['latest']['id']}/transitions"
        )
        for current, target in (("draft", "in_review"), ("in_review", "published")):
            response = self.client.post(
                transition,
                json={"expected_status": current, "target_status": target},
                headers=self.headers("b"),
            )
            self.assertEqual(response.status_code, 200, response.text)
        public = self.client.get(
            f"/v1/vocabulary/{new['entry_id']}", headers=self.headers()
        )
        self.assertEqual(public.status_code, 200, public.text)
        path = f"/v1/admin/vocabulary/{new['entry_id']}"
        revised = self.client.post(
            path + "/revisions",
            headers=self.headers("b"),
            json={
                "expected_latest_revision": 1,
                "content": {
                    **assignment["content"],
                    "vietnamese": "từ ngữ",
                    "source_version": "2",
                },
            },
        )
        self.assertEqual(revised.status_code, 201, revised.text)
        self.assertEqual(
            self.client.get(path, headers=h).json()["latest"]["status"], "draft"
        )
        self.assertEqual(
            self.client.get(
                f"/v1/vocabulary/{new['entry_id']}", headers=self.headers()
            ).json()["vietnamese"],
            "từ",
        )
        drafts = self.client.get(
            "/v1/admin/vocabulary", headers=h, params={"status": "draft"}
        ).json()["items"]
        self.assertIn(new["entry_id"], {r["entry_id"] for r in drafts})

        test_path = f"/v1/admin/tests/{self.test_id}"
        original = self.client.get(test_path, headers=h)
        self.assertEqual(original.status_code, 200, original.text)
        self.assertIn("correct_index", original.json()["content"]["questions"][0])
        summary = self.client.get(
            "/v1/admin/questions",
            headers=h,
            params={"test_id": self.test_id, "limit": 1},
        )
        self.assertEqual(summary.status_code, 200, summary.text)
        self.assertNotIn("correct_index", summary.text)
        question = self.client.get(
            f"/v1/admin/questions/{summary.json()['items'][0]['question_id']}",
            headers=h,
        )
        self.assertEqual(question.json()["content"]["correct_index"], 0)
        new_test = self.client.post(
            test_path + "/revisions",
            headers=self.headers("b"),
            json={
                "expected_latest_revision": 1,
                "content": {
                    "duration_seconds": 1200,
                    "source": "fixture",
                    "license": "test",
                    "questions": [],
                },
            },
        )
        self.assertEqual(new_test.status_code, 201, new_test.text)
        transition = f"/v1/admin/content/tests/revisions/{new_test.json()['latest']['id']}/transitions"
        self.assertEqual(
            self.client.post(
                transition,
                json={"expected_status": "draft", "target_status": "in_review"},
                headers=self.headers("b"),
            ).status_code,
            200,
        )
        failed = self.client.post(
            transition,
            json={"expected_status": "in_review", "target_status": "published"},
            headers=self.headers("b"),
        )
        self.assertEqual(failed.json()["code"], "INVALID_STATE")
        self.assertEqual(
            self.client.get("/v1/admin/tests", headers=h).json()["items"][0]["latest"][
                "status"
            ],
            "in_review",
        )

    def test_scenario_publication_and_roleplay_drafts(self):
        self.conn.execute(
            "UPDATE app.profiles SET role='admin' WHERE id=%s",
            (self.users["b"].user_id,),
        )
        edit = "/v1/admin/scenarios/directions"
        result = self.client.post(
            edit + "/revisions",
            headers=self.headers("b"),
            json={
                "expected_latest_revision": 0,
                "content": {
                    "learner_role": "Visitor",
                    "ai_role": "Local",
                    "goal": "Ask directions",
                    "opening": {
                        "hanzi": "你好",
                        "pinyin": "nǐ hǎo",
                        "vietnamese": "xin chào",
                    },
                    "system_prompt": "Internal prompt",
                    "source": "fixture",
                    "license": "test",
                    "vocabulary_entry_ids": [],
                },
            },
        )
        self.assertEqual(result.status_code, 201, result.text)
        revision = result.json()["latest"]["id"]
        self.assertEqual(
            self.client.get(edit, headers=self.headers("b")).json()["latest"]["status"],
            "draft",
        )
        self.assertEqual(
            self.client.get("/v1/roleplay/scenarios", headers=self.headers()).json()[
                "items"
            ],
            [],
        )
        flow = f"/v1/admin/content/scenarios/revisions/{revision}/transitions"
        for old, new in (("draft", "in_review"), ("in_review", "published")):
            result = self.client.post(
                flow,
                headers=self.headers("b"),
                json={"expected_status": old, "target_status": new},
            )
            self.assertEqual(result.status_code, 200, result.text)
        scene = self.client.get(
            "/v1/roleplay/scenarios/directions", headers=self.headers()
        ).json()
        self.assertEqual(scene["max_turns"], 8)
        self.assertNotIn("system_prompt", scene)
        tts_request = {"kind": "scenario_opening", "revision_id": revision}
        key = self.headers()
        self.learning.fail_upload = True
        failed = self.client.post("/v1/tts", headers=key, json=tts_request)
        self.assertEqual(failed.status_code, 503, failed.text)
        staged = self.conn.execute(
            "SELECT lease,object_key FROM app.tts_uploads"
        ).fetchone()
        self.assertIn(staged[1], self.learning.objects)
        self.conn.execute(
            "UPDATE app.tts_cache SET state='processing',lease_until=clock_timestamp()-interval '1 second' WHERE lease=%s",
            (staged[0],),
        )
        self.learning.fail_upload = False
        audio = self.client.post("/v1/tts", headers=key, json=tts_request)
        self.assertEqual(audio.status_code, 200, audio.text)
        self.assertFalse(audio.json()["cached"])
        ready = self.conn.execute(
            "SELECT object_key FROM app.tts_cache WHERE id=%s",
            (audio.json()["media_id"],),
        ).fetchone()[0]
        self.assertNotEqual(ready, staged[1])
        self.conn.execute(
            "UPDATE app.tts_uploads SET cleanup_after=clock_timestamp() WHERE lease=%s",
            (staged[0],),
        )
        run_async(clean_batch(self.db, self.personal, learning_storage=self.learning))
        self.assertNotIn(staged[1], self.learning.objects)
        self.assertIn(ready, self.learning.objects)
        cached = self.client.post("/v1/tts", headers=self.headers(), json=tts_request)
        self.assertTrue(cached.json()["cached"])
        self.assertEqual(cached.json()["media_id"], audio.json()["media_id"])
        self.assertEqual(
            self.client.get(
                "/v1/admin/scenarios", headers=self.headers("b")
            ).status_code,
            200,
        )
        root = "/v1/roleplay/sessions"
        key = self.headers()
        payload = {"scenario_id": "directions", "hsk_level": 1}
        started = self.client.post(root, headers=key, json=payload)
        self.assertEqual(started.status_code, 201, started.text)
        session = started.json()
        endpoint = f"{root}/{session['id']}"
        self.assertEqual(
            self.client.get(endpoint, headers=self.headers("b")).status_code, 404
        )
        self.assertEqual(
            self.client.get(root, headers=self.headers()).json()["items"][0]["id"],
            session["id"],
        )
        draft_created = self.client.post(
            endpoint + "/drafts", headers=self.headers(), json={"text": "请问"}
        )
        self.assertEqual(draft_created.status_code, 201, draft_created.text)
        draft = draft_created.json()
        url = f"{endpoint}/drafts/{draft['id']}"
        self.assertEqual(self.client.get(url, headers=self.headers()).json(), draft)
        confirmed = self.client.post(
            url + "/confirm",
            headers=self.headers(),
            json={"text": "请问在哪儿？", "expected_version": 1},
        )
        self.assertEqual(confirmed.status_code, 200, confirmed.text)
        self.assertEqual(confirmed.json()["status"], "confirmed")
        ended = self.client.post(
            endpoint + "/end",
            headers=self.headers(),
            json={"expected_version": session["version"], "confirm": True},
        )
        self.assertEqual(ended.status_code, 200, ended.text)
        self.assertEqual(
            self.client.get(url, headers=self.headers()).json()["status"], "discarded"
        )
        removal = self.client.delete(
            endpoint,
            headers=self.headers(),
            params={"expected_version": ended.json()["version"]},
        )
        self.assertEqual(removal.status_code, 204, removal.text)
        self.assertEqual(
            self.client.get(endpoint, headers=self.headers()).status_code, 404
        )
        self.assertEqual(
            self.client.post(root, headers=key, json=payload).json()["code"],
            "RESOURCE_GONE",
        )

    def test_stroke_asset_and_quiz_progress(self):
        char, revision = uuid4(), uuid4()
        self.conn.execute(
            "INSERT INTO app.characters(id,hanzi) VALUES (%s,'人')", (char,)
        )
        self.conn.execute(
            """INSERT INTO app.character_revisions(id,character_id,revision,status,stroke_count,
                    object_key,source,license) VALUES (%s,%s,1,'published',2,'strokes/sample.json','fixture','test')""",
            (revision, char),
        )
        self.conn.execute(
            "UPDATE app.characters SET published_revision_id=%s WHERE id=%s",
            (revision, char),
        )
        chars = self.client.get("/v1/characters", headers=self.headers()).json()
        self.assertEqual(chars["items"][0]["stroke_count"], 2)
        self.assertFalse(chars["items"][0]["supports_cnn"])
        strokes = self.client.get(
            f"/v1/characters/{char}/strokes", headers=self.headers()
        )
        self.assertEqual(strokes.status_code, 200, strokes.text)
        self.assertIn("strokes/sample.json", strokes.json()["asset_url"])
        route = "/v1/handwriting/quiz-attempts"
        body = {
            "character_revision_id": str(revision),
            "completed_strokes": 1,
            "mistakes": 2,
            "hints": 1,
            "duration_ms": 1000,
        }
        partial = self.client.post(route, headers=self.headers(), json=body)
        self.assertEqual(partial.status_code, 201, partial.text)
        self.assertIsNone(partial.json()["score"])
        h = self.headers()
        final = self.client.post(
            route, headers=h, json={**body, "completed_strokes": 2}
        )
        self.assertEqual(final.status_code, 201, final.text)
        self.assertEqual(final.json()["score"], 80)
        self.assertEqual(
            self.client.post(
                route, headers=h, json={**body, "completed_strokes": 2}
            ).json(),
            final.json(),
        )
        activities = self.client.get("/v1/activities", headers=self.headers()).json()[
            "items"
        ]
        self.assertEqual([a["kind"] for a in activities], ["quiz"])

    def test_admin_csv_import_validates_then_creates_draft(self):
        self.conn.execute(
            "UPDATE app.profiles SET role='admin' WHERE id=%s",
            (self.users["b"].user_id,),
        )
        h = self.headers("b")
        root = "/v1/admin/imports"
        csv = (
            chr(10)
            .join(
                [
                    "han,reading,display,meaning,src,external,version,rights,hsk",
                    f"{chr(23398)},xue2,xue,study,import-fixture,learn,1,test,1",
                ]
            )
            .encode()
        )
        upload = self.client.post(
            "/v1/admin/media",
            headers=h,
            files={"file": ("words.csv", csv, "text/csv")},
            data={"kind": "import_file"},
        )
        self.assertEqual(upload.status_code, 200, upload.text)
        self.assertEqual(
            self.client.post(
                "/v1/admin/media",
                headers=h,
                files={"file": ("words.csv", csv, "text/csv")},
                data={"kind": "import_file"},
            ).json(),
            upload.json(),
        )
        created = self.client.post(
            root,
            headers=self.headers("b"),
            json={"file_media_id": upload.json()["media_id"]},
        )
        self.assertEqual(created.status_code, 201, created.text)
        path = f"{root}/{created.json()['id']}"
        fields = {
            "han": "hanzi",
            "reading": "reading_key",
            "display": "pinyin_display",
            "meaning": "vietnamese",
            "src": "source_name",
            "external": "source_external_id",
            "version": "source_version",
            "rights": "license",
            "hsk": "hsk_level",
        }
        wrong = {k: v for k, v in fields.items() if k != "meaning"}
        m = self.client.patch(
            path + "/mapping",
            headers=self.headers("b"),
            json={"expected_mapping_version": 1, "columns": wrong},
        )
        self.assertEqual(m.status_code, 200, m.text)
        bad = self.client.post(path + "/validate", headers=self.headers("b"))
        self.assertEqual(bad.json()["status"], "invalid")
        rows = self.client.get(path + "/rows", headers=self.headers("b")).json()[
            "items"
        ]
        self.assertEqual(rows[0]["errors"][0]["code"], "MISSING_DATA")
        self.assertEqual(
            self.client.patch(
                path + "/mapping",
                headers=self.headers("b"),
                json={"expected_mapping_version": 2, "columns": fields},
            ).status_code,
            200,
        )
        ok = self.client.post(path + "/validate", headers=self.headers("b"))
        self.assertEqual(ok.status_code, 200, ok.text)
        self.assertEqual(ok.json()["status"], "validated")
        saved = self.client.post(
            path + "/confirm",
            headers=self.headers("b"),
            json={
                "expected_mapping_version": 3,
                "validated_hash": ok.json()["validated_hash"],
            },
        )
        self.assertEqual(saved.status_code, 200, saved.text)
        self.assertEqual(saved.json()["inserted_rows"], 1)
        self.assertEqual(
            self.client.get(path, headers=self.headers("b")).json()["status"],
            "completed",
        )
        row = self.client.get(path + "/rows", headers=self.headers("b")).json()[
            "items"
        ][0]
        self.assertEqual(
            self.client.get(
                f"/v1/vocabulary/{row['entry_id']}", headers=self.headers()
            ).status_code,
            404,
        )

        conflict_file = csv.replace(b",study,", b",new meaning,")
        conflicting_upload = self.client.post(
            "/v1/admin/media",
            headers=self.headers("b"),
            files={"file": ("another.csv", conflict_file, "text/csv")},
            data={"kind": "import_file"},
        ).json()
        second = self.client.post(
            root,
            headers=self.headers("b"),
            json={"file_media_id": conflicting_upload["media_id"]},
        ).json()
        conflict_path = f"{root}/{second['id']}"
        self.assertEqual(
            self.client.patch(
                conflict_path + "/mapping",
                headers=self.headers("b"),
                json={"expected_mapping_version": 1, "columns": fields},
            ).status_code,
            200,
        )
        conflict = self.client.post(
            conflict_path + "/validate", headers=self.headers("b")
        )
        self.assertEqual(conflict.status_code, 200, conflict.text)
        self.assertEqual(
            (conflict.json()["status"], conflict.json()["invalid_rows"]), ("invalid", 1)
        )
        row_errors = self.client.get(
            conflict_path + "/rows", headers=self.headers("b")
        ).json()["items"][0]["errors"]
        self.assertEqual(row_errors[0]["code"], "SOURCE_VERSION_CONFLICT")

    def test_published_cnn_attempt_and_confirmation(self):
        self.conn.execute(
            """INSERT INTO app.model_versions(model_version,status,weights_sha256,preprocess_version)
                          VALUES ('test-cnn','published',%s,'fixture')""",
            ("1" * 64,),
        )
        model = self.conn.execute(
            "SELECT id FROM app.model_versions WHERE model_version='test-cnn'"
        ).fetchone()[0]
        identifiers = []
        for index, hanzi in enumerate(("我", "你", "他")):
            char = uuid4()
            identifiers.append(str(char))
            self.conn.execute(
                "INSERT INTO app.characters(id,hanzi) VALUES (%s,%s)", (char, hanzi)
            )
            self.conn.execute(
                "INSERT INTO app.model_classes(model_id,class_index,character_id) VALUES (%s,%s,%s)",
                (model, index, char),
            )
        self.addCleanup(
            self.conn.execute,
            "UPDATE app.model_versions SET status='archived' WHERE id=%s",
            (model,),
        )
        chars = self.client.get(
            "/v1/characters", headers=self.headers(), params={"mode": "cnn"}
        )
        self.assertEqual(chars.status_code, 200, chars.text)
        self.assertEqual(len(chars.json()["items"]), 3)
        key = self.headers()
        payload = {"image": ("canvas.png", png("black"), "image/png")}
        prediction = self.client.post(
            "/v1/handwriting/predict", headers=key, files=payload
        )
        self.assertEqual(prediction.status_code, 200, prediction.text)
        result = prediction.json()
        self.assertEqual(result["model_version"], "test-cnn")
        self.assertEqual(result["uncertainty"], "not_calibrated")
        self.assertEqual(
            [x["character_id"] for x in result["candidates"]],
            [identifiers[i] for i in (1, 2, 0)],
        )
        self.assertEqual(
            self.client.post(
                "/v1/handwriting/predict", headers=key, files=payload
            ).json(),
            result,
        )
        url = f"/v1/handwriting/predictions/{result['id']}/confirm"
        self.assertEqual(
            self.client.post(
                url, headers=self.headers("b"), json={"character_id": identifiers[1]}
            ).status_code,
            404,
        )
        confirmed = self.client.post(
            url, headers=self.headers(), json={"character_id": identifiers[1]}
        )
        self.assertEqual(confirmed.status_code, 200, confirmed.text)
        self.assertEqual(
            self.client.post(
                url, headers=self.headers(), json={"character_id": identifiers[2]}
            ).json()["code"],
            "INVALID_STATE",
        )
        self.assertEqual(
            self.client.get("/v1/activities", headers=self.headers()).json()["items"][
                0
            ]["kind"],
            "prediction",
        )

    def test_voice_job_chain_fallback_retry_and_ownership(self):
        revision = uuid4()
        content = {
            "learner_role": "Buyer",
            "ai_role": "Seller",
            "goal": "Ask the price",
            "opening": {"hanzi": "你好", "pinyin": "nǐ hǎo", "vietnamese": "xin chào"},
            "system_prompt": "Stay in role",
            "source": "fixture",
            "license": "test",
            "vocabulary_entry_ids": [],
        }
        self.conn.execute(
            """INSERT INTO app.scenario_revisions (id,scenario_id,revision,status,content,published_at)
                     VALUES (%s,'taobao',1,'published',%s,now())""",
            (revision, Jsonb(content)),
        )
        self.conn.execute(
            "UPDATE app.scenarios SET published_revision_id=%s WHERE id='taobao'",
            (revision,),
        )
        root = "/v1/roleplay/sessions"
        created = self.client.post(
            root, headers=self.headers(), json={"scenario_id": "taobao", "hsk_level": 2}
        )
        self.assertEqual(created.status_code, 201, created.text)
        url = f"{root}/{created.json()['id']}"
        data = {"audio": ("hello.wav", wav(1), "audio/wav")}
        key = self.headers()
        queued = self.client.post(url + "/transcription-jobs", headers=key, files=data)
        self.assertEqual(queued.status_code, 202, queued.text)
        self.assertEqual(
            self.client.post(
                url + "/transcription-jobs", headers=key, files=data
            ).json(),
            queued.json(),
        )
        job_id = queued.json()["job_id"]
        poll = f"/v1/jobs/{job_id}"
        self.assertEqual(
            self.client.get(poll, headers=self.headers("b")).status_code, 404
        )
        self.assertEqual(
            self.client.get(url, headers=self.headers()).json()["active_job_id"], job_id
        )
        worker = ConversationWorker(self.db, self.personal, FixtureConversation(), None)
        self.assertTrue(run_async(worker.run_once()))
        done = self.client.get(poll, headers=self.headers())
        self.assertEqual(done.status_code, 200, done.text)
        self.assertEqual(done.json()["status"], "completed", done.text)
        draft_id = done.json()["target"]["draft_id"]
        path = f"{url}/drafts/{draft_id}"
        draft = self.client.get(path, headers=self.headers()).json()
        self.assertEqual(draft["raw_transcript"], "多少钱")
        self.assertEqual(draft["status"], "draft")
        missing_confirm = self.client.post(
            url + "/turn-jobs",
            headers=self.headers(),
            json={"draft_id": draft_id, "expected_draft_version": draft["version"]},
        )
        self.assertEqual(missing_confirm.json()["code"], "DRAFT_NOT_CONFIRMED")
        confirmed = self.client.post(
            path + "/confirm",
            headers=self.headers(),
            json={"text": "多少钱？", "expected_version": draft["version"]},
        ).json()
        turn = self.client.post(
            url + "/turn-jobs",
            headers=self.headers(),
            json={"draft_id": draft_id, "expected_draft_version": confirmed["version"]},
        )
        self.assertEqual(turn.status_code, 202, turn.text)
        self.assertTrue(run_async(worker.run_once()))
        result = self.client.get(
            f"/v1/jobs/{turn.json()['job_id']}", headers=self.headers()
        ).json()
        self.assertEqual(result["status"], "completed", result)
        self.assertIn("TTS_UNAVAILABLE", result["warnings"])
        entry = result["target"]["turn_id"]
        session = self.client.get(url, headers=self.headers()).json()
        self.assertEqual(session["completed_turns"], 1)
        self.assertIsNone(session["turns"][0]["audio_media_id"])
        audio = self.client.post(
            f"{url}/turns/{entry}/audio-jobs",
            headers=self.headers(),
            json={"text_version": 1},
        )
        self.assertEqual(audio.status_code, 202, audio.text)
        worker.speech = FixtureVoice()
        self.assertTrue(run_async(worker.run_once()))
        job = self.client.get(
            f"/v1/jobs/{audio.json()['job_id']}", headers=self.headers()
        ).json()
        self.assertEqual(job["status"], "completed", job)
        media = self.client.get(url, headers=self.headers()).json()["turns"][0][
            "audio_media_id"
        ]
        self.assertEqual(
            self.client.get(
                f"/v1/media/{media}/url", headers=self.headers()
            ).status_code,
            200,
        )
        self.assertEqual(
            self.client.get(
                f"/v1/media/{media}/url", headers=self.headers("b")
            ).status_code,
            404,
        )
        self.assertEqual(
            self.client.get("/v1/activities", headers=self.headers()).json()["items"][
                0
            ]["kind"],
            "roleplay",
        )
