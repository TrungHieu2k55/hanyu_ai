import asyncio
import unittest
from datetime import UTC, datetime, time
from uuid import uuid4
from zoneinfo import ZoneInfo

import psycopg
from fastapi.testclient import TestClient
from test_accounts_postgres import POLICIES
from test_api import wav
from test_exam_postgres import FixtureVoice
from test_ocr_postgres import DSN, TERMS, FixtureImages, TestTokens

from app.backend import PostgresBackend
from app.main import create_app
from app.ports import Identity
from app.postgres import Database
from app.study_tools import next_reminder

BASE = "/v1/study"


class Speech:
    def __init__(self):
        self.calls = 0

    async def transcribe(self, model, media):
        self.calls += 1
        assert model == "test-stt" and media.content_type == "audio/wav"
        return {"transcript": "你好，我叫小明。"}


class ReminderTests(unittest.TestCase):
    def test_missing_dst_hour_skips_to_next_week(self):
        next_at = next_reminder(
            datetime(2026, 3, 7, tzinfo=UTC),
            ZoneInfo("America/New_York"),
            time(2, 30),
            [7],
        )
        self.assertEqual(next_at, datetime(2026, 3, 15, 6, 30, tzinfo=UTC))


@unittest.skipUnless(DSN, "Set HANYU_TEST_DATABASE_URL with migrations installed")
class StudyApiTests(unittest.TestCase):
    def setUp(self):
        conn = psycopg.connect(DSN, autocommit=True, prepare_threshold=None)
        self.addCleanup(conn.close)
        self.conn = conn
        users = {actor: Identity(uuid4(), uuid4()) for actor in ("a", "b")}
        self.stt = Speech()
        self.client = TestClient(
            create_app(
                verifier=TestTokens(users),
                backend=PostgresBackend(
                    Database(DSN, bytes(range(32)), TERMS),
                    FixtureImages(),
                    policies=POLICIES,
                    learning_storage=FixtureImages(),
                    speech_provider=FixtureVoice(),
                    study_transcriber=self.stt,
                    live_conversation_models={"transcription": "test-stt"},
                ),
            ),
            backend_options={"loop_factory": asyncio.SelectorEventLoop},
        )
        self.addCleanup(self.client.close)
        for actor, user in users.items():
            conn.execute("INSERT INTO auth.users VALUES (%s)", (user.user_id,))
            conn.execute(
                "INSERT INTO auth.sessions (id,user_id) VALUES (%s,%s)",
                (user.session_id, user.user_id),
            )
            self.call(
                "POST",
                "/v1/me/bootstrap",
                201,
                actor=actor,
                json={
                    "display_name": actor,
                    "terms_version": TERMS,
                    "training_policy_version": POLICIES["training_policy_version"],
                    "training_opt_in": False,
                },
            )
        self.users = users

    def call(self, method, path, status=200, *, actor="a", key=None, **kwargs):
        response = self.client.request(
            method,
            path,
            headers={
                "Authorization": f"Bearer {actor}",
                "Idempotency-Key": str(key or uuid4()),
            },
            **kwargs,
        )
        self.assertEqual(response.status_code, status, response.text)
        return response

    def test_curriculum_online_offline_and_private_attempts(self):
        all_lessons = self.call("GET", f"{BASE}/lessons").json()["items"]
        self.assertEqual(
            {row["kind"] for row in all_lessons},
            {
                "pinyin",
                "radical",
                "grammar",
                "sentence_order",
                "pronunciation",
                "dictation",
            },
        )
        dictation = self.call("GET", f"{BASE}/lessons/dictation-tea").json()
        self.assertNotIn("audio_text", dictation["exercise"])
        self.assertNotIn("solution", dictation)
        pack = self.call("GET", f"{BASE}/offline-packs/1").json()
        self.assertEqual(len(pack["version"]), 64)
        self.assertIn(
            "solution",
            next(row for row in pack["items"] if row["id"] == "dictation-tea"),
        )
        self.call("POST", f"{BASE}/lessons/dictation-tea/audio", json={"revision": 1})
        self.call(
            "POST",
            f"{BASE}/lessons/pinyin-four-tones/audio",
            json={"revision": 1, "option_id": "c"},
        )
        path = f"{BASE}/lessons/sentence-school/attempts"
        self.call("POST", path, 422, json={"revision": 1, "answer": ["school"]})
        self.assertFalse(
            self.call(
                "POST",
                path,
                json={
                    "revision": 1,
                    "answer": ["school", "go", "i"],
                },
            ).json()["correct"]
        )
        body = {"revision": 1, "answer": ["i", "go", "school"]}
        key = uuid4()
        answer = self.call("POST", path, key=key, json=body).json()
        self.assertTrue(answer["correct"])
        replay = self.call("POST", path, key=key, json=body)
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.assertEqual(replay.json(), answer)
        self.call(
            "POST",
            path,
            key=key,
            json={"revision": 1, "answer": ["school", "go", "i"]},
            status=409,
        )
        self.assertEqual(self.call("GET", f"{BASE}/goals").json()["completed"], 1)
        self.assertEqual(
            self.call("GET", f"{BASE}/mistakes", actor="b").json()["items"], []
        )
        self.assertEqual(
            self.call("GET", f"{BASE}/mistakes").json()["items"][0]["source"], "lesson"
        )

    def test_private_deck_and_reminder(self):
        deck = f"{BASE}/decks/{uuid4()}"
        created = self.call("PUT", deck, json={"name": "Bộ từ đi học"}).json()
        self.assertEqual(len(self.call("GET", f"{BASE}/decks").json()["items"]), 1)
        self.call("GET", deck, 404, actor="b")
        word = self.call(
            "POST",
            "/v1/learning-items",
            201,
            json={
                "source": {
                    "kind": "personal_new",
                    "personal": {
                        "source": {"kind": "manual"},
                        "hanzi": "学校",
                        "pinyin": "xuéxiào",
                        "vietnamese": "trường học",
                    },
                }
            },
        ).json()
        item = f"{deck}/items/{word['id']}"
        self.call("PUT", item, 204)
        self.call("PUT", item, 204)
        self.assertEqual(
            self.call("GET", deck).json()["items"][0]["item_id"], word["id"]
        )
        self.call("DELETE", item, 204)
        self.call("DELETE", deck, 204)
        self.call("GET", deck, 404)
        self.assertIsNotNone(created["id"])
        reminder = f"{BASE}/reminder"
        body = {
            "enabled": True,
            "local_time": "19:30",
            "timezone": "Asia/Ho_Chi_Minh",
            "weekdays": [5, 1],
        }
        self.assertIsNotNone(self.call("PUT", reminder, json=body).json()["next_at"])
        self.assertEqual(self.call("GET", reminder).json()["weekdays"], [1, 5])
        self.assertFalse(self.call("GET", reminder, actor="b").json()["enabled"])
        self.call("PUT", reminder, 422, json={**body, "timezone": "bad/time-zone"})

    def test_lookup_replay_and_speech(self):
        entry, revision = uuid4(), uuid4()
        self.conn.execute(
            "INSERT INTO app.vocabulary (id,hanzi,reading_key,sense_id) VALUES (%s,'书','shu1',%s)",
            (entry, uuid4()),
        )
        self.conn.execute(
            """INSERT INTO app.vocabulary_revisions
           (id,entry_id,revision,status,pinyin_display,vietnamese,source_name,source_external_id,
            source_version,license,reviewed_at,published_at,content_hash)
           VALUES (%s,%s,1,'published','shū','sách','test','shu','v1','test',now(),now(),%s)""",
            (revision, entry, "a" * 64),
        )
        self.conn.execute(
            "UPDATE app.vocabulary SET published_revision_id=%s WHERE id=%s",
            (revision, entry),
        )
        self.conn.execute(
            "UPDATE app.vocabulary_revisions SET part_of_speech='danh từ' WHERE id=%s",
            (revision,),
        )
        words = self.call(
            "GET", f"{BASE}/dictionary", params={"q": "书", "part_of_speech": "danh từ"}
        ).json()
        self.assertEqual([item["entry_id"] for item in words["items"]], [str(entry)])
        none = self.call(
            "GET", f"{BASE}/dictionary", params={"q": "书", "with_examples": 1}
        ).json()
        self.assertEqual(none["items"], [])
        key = uuid4()
        path = f"{BASE}/lookups/{entry}"
        self.call("POST", path, 204, key=key)
        response = self.call("POST", path, 204, key=key)
        self.assertEqual(response.headers["Idempotency-Replayed"], "true")
        self.assertEqual(
            self.call("GET", f"{BASE}/lookups", actor="b").json()["items"], []
        )
        self.assertEqual(
            self.call("GET", f"{BASE}/lookups").json()["items"][0]["entry_id"],
            str(entry),
        )
        self.call("DELETE", f"{BASE}/lookups", 204)
        self.assertEqual(self.call("GET", f"{BASE}/lookups").json()["items"], [])
        speech = f"{BASE}/lessons/pronunciation-intro/transcriptions"
        key = uuid4()
        params = {
            "data": {"revision": "1"},
            "files": {"audio": ("clip.wav", wav(1), "audio/wav")},
        }
        response = self.call("POST", speech, key=key, **params)
        self.assertEqual(
            self.call("POST", speech, key=key, **params).json(), response.json()
        )
        self.assertEqual(self.stt.calls, 1)
        self.assertTrue(
            self.call(
                "POST",
                f"{BASE}/lessons/pronunciation-intro/attempts",
                json={
                    "revision": 1,
                    "answer": response.json()["transcript"],
                },
            ).json()["correct"]
        )
