import asyncio
import os
import unittest
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from uuid import UUID, uuid4

import psycopg
from fastapi.testclient import TestClient
from test_api import png

from app.backend import PostgresBackend
from app.cleanup_ocr import clean_batch
from app.errors import ApiError, unavailable
from app.main import create_app
from app.ocr_providers import ProviderFailure
from app.ocr_text import OcrLine
from app.ocr_worker import OcrQueue, OcrWorker
from app.ports import Identity
from app.postgres import Database

DSN = os.getenv("HANYU_TEST_DATABASE_URL")
TERMS = "terms-dev-v1"


class TestTokens:
    configured = True

    def __init__(self, identities):
        self.identities = identities

    async def verify(self, token):
        return self.identities[token]


class FixtureImages:
    def __init__(self):
        self.objects = {}
        self.fail_upload = self.fail_remove = False
        self.uploads = 0

    async def store(self, object_key, media):
        self.objects[object_key] = media.data
        self.uploads += 1
        if self.fail_upload:
            raise unavailable(
                "PROVIDER_UNAVAILABLE", "Upload interrupted after writing"
            )

    async def fetch(self, object_key):
        return self.objects[object_key]

    async def sign(self, object_key, ttl_seconds):
        assert object_key in self.objects
        assert 0 < ttl_seconds <= 300
        return f"https://example.test/private/{object_key}?token=fixture"

    async def remove(self, object_key):
        if self.fail_remove:
            raise unavailable("PROVIDER_UNAVAILABLE", "Storage offline")
        self.objects.pop(object_key, None)


class ProviderFixture:
    def __init__(self, name, model, lines):
        self.name, self.model, self.lines = name, model, lines
        self.calls = 0

    async def read(self, image):
        self.calls += 1
        if self.lines is None:
            raise ProviderFailure()
        return self.lines


def run_async(awaitable):
    return asyncio.run(awaitable, loop_factory=asyncio.SelectorEventLoop)


@unittest.skipUnless(
    DSN, "Set HANYU_TEST_DATABASE_URL with the test migration installed"
)
class PostgresOcrTests(unittest.TestCase):
    def setUp(self):
        self.conn = psycopg.connect(DSN, autocommit=True)
        self.addCleanup(self.conn.close)
        self.db = Database(DSN, bytes(range(32)), TERMS)
        self.images = FixtureImages()
        self.users = {name: Identity(uuid4(), uuid4()) for name in ("a", "b")}
        for name, user in self.users.items():
            self.conn.execute(
                "INSERT INTO auth.users (id) VALUES (%s)", (user.user_id,)
            )
            self.conn.execute(
                "INSERT INTO auth.sessions (id, user_id) VALUES (%s, %s)",
                (user.session_id, user.user_id),
            )
            self.conn.execute(
                "INSERT INTO app.profiles (id, owner_id, display_name) VALUES (%s, %s, %s)",
                (user.user_id, user.user_id, f"Học viên {name}"),
            )
            operation = uuid4()
            self.conn.execute(
                """
                INSERT INTO app.operations (id, owner_id, operation, client_key, payload_hash, status)
                VALUES (%s, %s, 'profile.bootstrap', %s, %s, 'completed')
                """,
                (operation, user.user_id, uuid4(), "0" * 64),
            )
            self.conn.execute(
                """
                INSERT INTO app.consent_events (owner_id, purpose, policy_version, granted, operation_id)
                VALUES (%s, 'terms', %s, true, %s)
                """,
                (user.user_id, TERMS, operation),
            )
        self.client = self.new_client()
        self.addCleanup(self.client.close)

    def new_client(self):
        return TestClient(
            create_app(
                verifier=TestTokens(self.users),
                backend=PostgresBackend(
                    self.db,
                    self.images,
                    {"paddleocr": "pp-test", "gemini": "gemini-test"},
                ),
            ),
            backend_options={"loop_factory": asyncio.SelectorEventLoop},
        )

    @staticmethod
    def headers(actor="a", key=None):
        headers = {"Authorization": f"Bearer {actor}"}
        if key is not None:
            headers["Idempotency-Key"] = str(key)
        return headers

    def upload(self, key=None, color="white"):
        return self.client.post(
            "/v1/ocr/jobs",
            headers=self.headers(key=key or uuid4()),
            files={"image": ("test.png", png(color), "image/png")},
        )

    def start(self):
        r = self.upload()
        self.assertEqual(r.status_code, 202, r.text)
        return r.json()["job_id"]

    def test_worker_fallback_result_revision_pagination_and_replay(self):
        job = self.start_for_worker()
        primary = ProviderFixture("paddleocr", "pp-test", None)
        fallback = ProviderFixture(
            "gemini", "gemini-test", [OcrLine("你好"), OcrLine("汉" * 103)]
        )
        worker = OcrWorker(
            OcrQueue(self.db), self.images, {"paddleocr": primary, "gemini": fallback}
        )
        self.assertTrue(run_async(worker.run_once()))
        self.assertEqual((primary.calls, fallback.calls), (1, 1))
        finished = self.client.get(f"/v1/jobs/{job}", headers=self.headers()).json()
        self.assertEqual(finished["status"], "completed")
        self.assertEqual(finished["warnings"], ["PADDLEOCR_FAILED"])
        scan = finished["target"]["scan_id"]
        path = f"/v1/ocr/scans/{scan}"
        loaded = self.client.get(path, headers=self.headers())
        self.assertEqual(loaded.status_code, 200, loaded.text)
        data = loaded.json()
        self.assertEqual(data["raw_text"], "你好\n" + "汉" * 103)
        self.assertEqual(data["raw_text"], data["corrected_text"])
        self.assertEqual(len(data["tokens"]), 100)
        self.assertEqual(data["tokens"][0]["pinyin"], "nǐ")
        self.assertIsNone(data["tokens"][0]["vietnamese"])
        self.assertIsNone(data["tokens"][0]["confidence"])
        cursor = data["tokens_next_cursor"]
        tail = self.client.get(
            f"{path}/tokens",
            headers=self.headers(),
            params={"revision": 0, "cursor": cursor},
        )
        self.assertEqual(
            [item["position"] for item in tail.json()["items"]],
            [100, 101, 102, 103, 104],
        )
        self.assertEqual(
            self.client.get(
                f"{path}/tokens", headers=self.headers("b"), params={"revision": 0}
            ).status_code,
            404,
        )
        edit_headers = self.headers(key=uuid4())
        body = {"expected_version": data["version"], "text": "学习"}
        edited = self.client.post(f"{path}/revisions", headers=edit_headers, json=body)
        self.assertEqual(edited.status_code, 200, edited.text)
        self.assertEqual(edited.json()["corrected_text"], "学习")
        self.assertEqual(edited.json()["raw_text"], data["raw_text"])
        self.assertEqual(edited.json()["revision"], 1)
        self.assertEqual([t["hanzi"] for t in edited.json()["tokens"]], ["学", "习"])
        stale = self.client.post(
            f"{path}/revisions", headers=self.headers(key=uuid4()), json=body
        )
        self.assertEqual(
            (stale.status_code, stale.json()["code"]), (409, "STALE_VERSION")
        )
        choice = self.client.get(
            f"{path}/tokens",
            headers=self.headers(),
            params={"revision": 1, "cursor": cursor},
        )
        self.assertEqual(
            (choice.status_code, choice.json()["code"]), (400, "INVALID_CURSOR")
        )
        second = self.client.post(
            f"{path}/revisions",
            headers=self.headers(key=uuid4()),
            json={"expected_version": edited.json()["version"], "text": "中国"},
        )
        self.assertEqual(second.status_code, 200, second.text)
        replay = self.client.post(f"{path}/revisions", headers=edit_headers, json=body)
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.assertEqual(replay.json()["revision"], 1)
        self.assertEqual(replay.json()["corrected_text"], "学习")

    def test_worker_reclaim_has_same_deadline_and_cancel_blocks_late_commit(self):
        job = self.start_for_worker()
        queue = OcrQueue(self.db)
        first = run_async(queue.claim())
        self.assertEqual(str(first.job_id), job)
        self.assertTrue(run_async(queue.heartbeat(first)))
        self.conn.execute(
            "UPDATE app.ai_jobs SET locked_until = clock_timestamp() - interval '1 second' WHERE id=%s",
            (first.job_id,),
        )
        second = run_async(queue.claim())
        self.assertEqual(second.processing_deadline, first.processing_deadline)
        self.assertEqual(second.lease_version, first.lease_version + 1)
        self.assertNotEqual(second.lease_token, first.lease_token)
        self.assertFalse(
            run_async(
                queue.finish(first, raw="旧", provider="paddleocr", model="pp-test")
            )
        )
        canceled = self.client.post(
            f"/v1/jobs/{job}/cancel", headers=self.headers(key=uuid4())
        )
        self.assertEqual(canceled.json()["status"], "canceled")
        self.assertFalse(run_async(queue.heartbeat(second)))
        self.assertFalse(
            run_async(
                queue.finish(second, raw="新", provider="paddleocr", model="pp-test")
            )
        )
        self.assertEqual(
            self.client.get(f"/v1/jobs/{job}", headers=self.headers()).json()["status"],
            "canceled",
        )
        self.assertEqual(
            self.conn.execute(
                "SELECT count(*) FROM app.ocr_revisions WHERE owner_id=%s",
                (first.owner_id,),
            ).fetchone()[0],
            0,
        )

    def test_worker_no_text_completes_without_fallback(self):
        job = self.start_for_worker()
        primary = ProviderFixture("paddleocr", "pp-test", [])
        fallback = ProviderFixture("gemini", "gemini-test", [OcrLine("你好")])
        worker = OcrWorker(
            OcrQueue(self.db), self.images, {"paddleocr": primary, "gemini": fallback}
        )
        self.assertTrue(run_async(worker.run_once()))
        finished = self.client.get(f"/v1/jobs/{job}", headers=self.headers()).json()
        self.assertEqual(finished["warnings"], ["NO_TEXT_FOUND"])
        self.assertEqual(finished["status"], "completed")
        self.assertEqual(fallback.calls, 0)
        scan = finished["target"]["scan_id"]
        result = self.client.get(f"/v1/ocr/scans/{scan}", headers=self.headers()).json()
        self.assertEqual(result["raw_text"], "")
        self.assertEqual(result["tokens"], [])

    def test_worker_tombstone_blocks_input_and_sweep_expires_processing(self):
        job = self.start_for_worker()
        queue = OcrQueue(self.db)
        lease = run_async(queue.claim())
        self.assertEqual(str(lease.job_id), job)
        self.assertIsNotNone(run_async(queue.image(lease)))
        self.conn.execute(
            """
            INSERT INTO app_private.subject_tombstones (subject_hash, deletion_id, retain_until)
            VALUES (%s, %s, clock_timestamp() + interval '1 day')
            """,
            (self.db.subject_hash(lease.owner_id), uuid4()),
        )
        self.assertIsNone(run_async(queue.image(lease)))
        self.assertFalse(
            run_async(
                queue.finish(
                    lease,
                    raw="不写入",
                    provider="paddleocr",
                    model="pp-test",
                )
            )
        )
        self.conn.execute(
            "UPDATE app.ai_jobs SET processing_deadline = clock_timestamp() - interval '1 second' WHERE id=%s",
            (lease.job_id,),
        )
        self.assertGreaterEqual(run_async(queue.sweep()), 1)
        state = self.conn.execute(
            "SELECT status, safe_error_code FROM app.ai_jobs WHERE id=%s",
            (lease.job_id,),
        ).fetchone()
        self.assertEqual(state, ("failed", "JOB_TIMEOUT"))

    def start_for_worker(self):
        job = self.start()
        self.conn.execute(
            "UPDATE app.ai_jobs SET created_at = clock_timestamp() - interval '1 day' WHERE id=%s",
            (UUID(job),),
        )
        return job

    def test_ocr_ledger_survives_new_api_instance_and_owner_only_resources(self):
        key = uuid4()
        initial = self.upload(key)
        self.assertEqual(initial.status_code, 202, initial.text)
        replay = self.upload(key)
        self.assertEqual(replay.json(), initial.json())
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.assertEqual(self.images.uploads, 1)
        conflict = self.upload(key, "black")
        self.assertEqual(
            (conflict.status_code, conflict.json()["code"]),
            (409, "IDEMPOTENCY_CONFLICT"),
        )
        job = initial.json()["job_id"]
        with self.new_client() as restarted:
            response = restarted.get(f"/v1/jobs/{job}", headers=self.headers())
            self.assertEqual(response.status_code, 200, response.text)
            scan = response.json()["target"]["scan_id"]
            detail = restarted.get(f"/v1/ocr/scans/{scan}", headers=self.headers())
            self.assertEqual(detail.status_code, 200, detail.text)
            self.assertIsNone(detail.json()["raw_text"])
            self.assertEqual(detail.json()["image_state"], "ready")
            media = detail.json()["image_media_id"]
            signed = restarted.get(f"/v1/media/{media}/url", headers=self.headers())
            self.assertEqual(signed.status_code, 200, signed.text)
            self.assertNotIn("object_key", signed.json())
            for path in (
                f"/v1/jobs/{job}",
                f"/v1/ocr/scans/{scan}",
                f"/v1/media/{media}/url",
            ):
                self.assertEqual(
                    restarted.get(path, headers=self.headers("b")).status_code, 404
                )
        with self.conn.transaction():
            self.conn.execute("SET LOCAL ROLE app_api")
            self.conn.execute(
                "SELECT set_config('app.actor_id', %s, true)",
                (str(self.users["b"].user_id),),
            )
            self.assertIsNone(
                self.conn.execute(
                    "SELECT id FROM app.ai_jobs WHERE id=%s", (UUID(job),)
                ).fetchone()
            )
        with (
            self.conn.transaction(),
            self.assertRaises(psycopg.errors.InsufficientPrivilege),
        ):
            self.conn.execute("SET LOCAL ROLE authenticated")
            self.conn.execute("SELECT id FROM app.ai_jobs")

    def test_two_requests_with_the_same_intent_commit_one_job(self):
        release, entered = Event(), Event()
        original = self.images.store
        key = uuid4()

        async def pause_first_upload(object_key, media):
            if not entered.is_set():
                entered.set()
                if not await asyncio.to_thread(release.wait, 5):
                    raise RuntimeError(
                        "Fixture timed out waiting for the duplicate request"
                    )
            await original(object_key, media)

        self.images.store = pause_first_upload
        with ThreadPoolExecutor(max_workers=1) as executor:
            first = executor.submit(self.upload, key)
            try:
                self.assertTrue(entered.wait(5))
                duplicate = self.upload(key)
            finally:
                release.set()
            original_request = first.result(timeout=5)
        self.assertEqual(duplicate.status_code, 202, duplicate.text)
        self.assertEqual(original_request.status_code, 202, original_request.text)
        self.assertEqual(original_request.json(), duplicate.json())
        self.assertEqual(original_request.headers["Idempotency-Replayed"], "true")
        jobs = self.client.get("/v1/jobs", headers=self.headers()).json()["items"]
        self.assertEqual(len(jobs), 1)

    def test_cancel_expiration_pagination_and_live_session(self):
        first, second = self.start(), self.start()
        page = self.client.get(
            "/v1/jobs", params={"limit": 1, "status": "active"}, headers=self.headers()
        )
        self.assertEqual(page.status_code, 200, page.text)
        data = page.json()
        cursor = data["next_cursor"]
        self.assertEqual(data["items"][0]["job_id"], second)
        page = self.client.get(
            "/v1/jobs",
            params={"limit": 1, "cursor": cursor, "status": "active"},
            headers=self.headers(),
        )
        self.assertEqual(page.status_code, 200, page.text)
        self.assertEqual(page.json()["items"][0]["job_id"], first)
        invalid = self.client.get(
            "/v1/jobs", params={"cursor": cursor}, headers=self.headers()
        )
        self.assertEqual(
            (invalid.status_code, invalid.json()["code"]), (400, "INVALID_CURSOR")
        )
        cross = self.client.get(
            "/v1/jobs",
            params={"cursor": cursor, "status": "active"},
            headers=self.headers("b"),
        )
        self.assertEqual(
            (cross.status_code, cross.json()["code"]), (400, "INVALID_CURSOR")
        )

        key = uuid4()
        canceled = self.client.post(
            f"/v1/jobs/{second}/cancel", headers=self.headers(key=key)
        )
        self.assertEqual(canceled.status_code, 200, canceled.text)
        self.assertEqual(canceled.json()["status"], "canceled")
        replay = self.client.post(
            f"/v1/jobs/{second}/cancel", headers=self.headers(key=key)
        )
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.conn.execute(
            "UPDATE app.ai_jobs SET queue_deadline = clock_timestamp() - interval '1 second' WHERE id=%s",
            (UUID(first),),
        )
        timed = self.client.get(f"/v1/jobs/{first}", headers=self.headers())
        self.assertEqual(timed.status_code, 200, timed.text)
        self.assertEqual(timed.json()["error"]["code"], "JOB_TIMEOUT")
        self.assertEqual(
            timed.json()["error"]["request_id"], timed.headers["X-Request-ID"]
        )
        self.assertEqual(
            self.client.get("/v1/jobs?status=active", headers=self.headers()).json()[
                "items"
            ],
            [],
        )
        scans = self.client.get("/v1/ocr/scans", headers=self.headers())
        self.assertEqual(
            {item["status"] for item in scans.json()["items"]}, {"canceled", "failed"}
        )
        self.conn.execute(
            "DELETE FROM auth.sessions WHERE id=%s", (self.users["a"].session_id,)
        )
        revoked = self.client.get("/v1/me", headers=self.headers())
        self.assertEqual(
            (revoked.status_code, revoked.json()["code"]), (401, "SESSION_REVOKED")
        )

    def test_staged_upload_cleanup_retries_and_keeps_expired_scan(self):
        self.images.fail_upload = True
        failed = self.upload()
        self.assertEqual(failed.status_code, 503, failed.text)
        self.assertEqual(
            self.client.get("/v1/jobs", headers=self.headers()).json()["items"], []
        )
        self.images.fail_upload = False
        job = self.start()
        detail = self.client.get(f"/v1/jobs/{job}", headers=self.headers()).json()
        scan_id = detail["target"]["scan_id"]
        media_id = self.client.get(
            f"/v1/ocr/scans/{scan_id}", headers=self.headers()
        ).json()["image_media_id"]
        self.conn.execute(
            "UPDATE app.media_assets SET expires_at = clock_timestamp() - interval '1 second' WHERE owner_id=%s",
            (self.users["a"].user_id,),
        )
        self.assertEqual(
            self.client.get(
                f"/v1/media/{media_id}/url", headers=self.headers()
            ).status_code,
            410,
        )
        self.images.fail_remove = True
        self.assertEqual(
            asyncio.run(
                clean_batch(self.db, self.images),
                loop_factory=asyncio.SelectorEventLoop,
            ),
            (0, 2),
        )
        self.assertEqual(
            asyncio.run(
                clean_batch(self.db, self.images),
                loop_factory=asyncio.SelectorEventLoop,
            ),
            (0, 0),
        )
        self.conn.execute(
            "UPDATE app.media_assets SET expires_at = clock_timestamp() - interval '1 second' WHERE owner_id=%s",
            (self.users["a"].user_id,),
        )
        self.images.fail_remove = False
        self.assertEqual(
            asyncio.run(
                clean_batch(self.db, self.images),
                loop_factory=asyncio.SelectorEventLoop,
            ),
            (2, 0),
        )
        self.assertEqual(self.images.objects, {})
        r = self.client.get(f"/v1/ocr/scans/{scan_id}", headers=self.headers())
        self.assertEqual(r.json()["image_state"], "deleted")
        self.assertEqual(
            self.client.get(
                f"/v1/media/{media_id}/url", headers=self.headers()
            ).status_code,
            410,
        )

    def test_tombstone_blocks_writes_and_quota_ignores_replay(self):
        key = uuid4()
        self.assertEqual(self.upload(key).status_code, 202)
        for _ in range(4):
            self.assertEqual(self.upload().status_code, 202)
        self.assertEqual(self.upload(key).status_code, 202)
        limited = self.upload()
        self.assertEqual(
            (limited.status_code, limited.json()["code"]), (429, "QUOTA_EXCEEDED")
        )
        self.assertEqual(self.images.uploads, 5)
        actor = self.users["a"]
        self.conn.execute(
            """
            INSERT INTO app_private.subject_tombstones (subject_hash, deletion_id, retain_until)
            VALUES (%s, %s, clock_timestamp() + interval '1 day')
            """,
            (self.db.subject_hash(actor.user_id), uuid4()),
        )
        blocked = self.upload()
        self.assertEqual(
            (blocked.status_code, blocked.json()["code"]), (403, "ACCOUNT_DELETING")
        )

    def test_delete_scan_removes_job_and_queues_private_image_cleanup(self):
        job = self.start()
        link = self.client.get(f"/v1/jobs/{job}", headers=self.headers()).json()
        row = self.conn.execute(
            "SELECT scan_id FROM app.ai_jobs WHERE id = %s", (job,)
        ).fetchone()
        scan = str(row[0])
        doc = self.client.get(f"/v1/ocr/scans/{scan}", headers=self.headers()).json()
        expected = {"expected_version": doc["version"]}
        path = f"/v1/ocr/scans/{scan}"
        self.assertEqual(
            self.client.delete(
                path, params=expected, headers=self.headers("b", uuid4())
            ).status_code,
            404,
        )
        key = self.headers(key=uuid4())
        result = self.client.delete(path, params=expected, headers=key)
        self.assertEqual(result.status_code, 204, result.text)
        self.assertEqual(
            self.client.delete(path, params=expected, headers=key).headers[
                "Idempotency-Replayed"
            ],
            "true",
        )
        self.assertEqual(
            self.client.get(f"/v1/jobs/{job}", headers=self.headers()).status_code, 404
        )
        self.assertEqual(self.client.get(path, headers=self.headers()).status_code, 404)
        self.assertEqual(link["status"], "queued")
        queued = self.conn.execute(
            "SELECT count(*) FROM app.media_assets WHERE owner_id = %s AND state = 'delete_pending'",
            (self.users["a"].user_id,),
        ).fetchone()[0]
        self.assertEqual(queued, 1)
        self.conn.execute(
            "UPDATE app.media_assets SET expires_at = clock_timestamp() + interval '1 day' WHERE owner_id = %s AND state = 'delete_pending'",
            (self.users["a"].user_id,),
        )

    def test_ocr_dictionary_only_attaches_unique_published_words(self):
        hanzi = "山河"
        entry, revision = uuid4(), uuid4()
        self.conn.execute(
            "INSERT INTO app.vocabulary (id,hanzi,reading_key,sense_id) VALUES (%s,%s,'shan1he2',%s)",
            (entry, hanzi, uuid4()),
        )
        self.conn.execute(
            """INSERT INTO app.vocabulary_revisions
            (id,entry_id,revision,status,pinyin_display,vietnamese,hsk_level,source_name,source_external_id,
             source_version,license,reviewed_at,published_at,content_hash)
            VALUES (%s,%s,1,'published','shān hé','núi sông',1,'test','mountain','v1','test',now(),now(),%s)""",
            (revision, entry, "0" * 64),
        )
        self.conn.execute(
            "UPDATE app.vocabulary SET published_revision_id=%s WHERE id=%s",
            (revision, entry),
        )
        job = self.start_for_worker()
        worker = OcrWorker(
            OcrQueue(self.db),
            self.images,
            {
                "paddleocr": ProviderFixture(
                    "paddleocr", "pp-test", [OcrLine(f"{hanzi}明", 0.9)]
                )
            },
        )
        self.assertTrue(run_async(worker.run_once()))
        completed = self.client.get(f"/v1/jobs/{job}", headers=self.headers()).json()
        self.assertEqual(completed["status"], "completed")
        path = f"/v1/ocr/scans/{completed['target']['scan_id']}"
        scan = self.client.get(path, headers=self.headers()).json()
        self.assertEqual([item["hanzi"] for item in scan["tokens"]], [hanzi, "明"])
        token, unknown = scan["tokens"]
        self.assertEqual(
            (token["entry_id"], token["vietnamese"], token["lookup_state"]),
            (str(entry), "núi sông", "matched"),
        )
        self.assertIsNone(unknown["entry_id"])
        self.assertEqual(unknown["lookup_state"], "unmatched")
        saved = self.client.post(
            "/v1/learning-items",
            headers=self.headers(key=uuid4()),
            json={"source": {"kind": "canonical", "entry_id": str(entry)}},
        )
        self.assertEqual(saved.status_code, 201, saved.text)
        revised = self.client.post(
            path + "/revisions",
            headers=self.headers(key=uuid4()),
            json={"expected_version": scan["version"], "text": f"{hanzi}。"},
        )
        self.assertEqual(revised.status_code, 200, revised.text)
        self.assertEqual(
            revised.json()["tokens"][0]["saved_item_id"], saved.json()["id"]
        )

    def test_db_programming_errors_are_not_reported_as_retryable_connection_failures(
        self,
    ):
        async def fail_statement():
            async with self.db.transaction(self.users["a"]) as tx:
                await tx.execute("SELECT 1 / 0")

        with (
            self.assertLogs("app.postgres", level="ERROR") as logs,
            self.assertRaises(ApiError) as seen,
        ):
            run_async(fail_statement())
        self.assertEqual(
            (seen.exception.status, seen.exception.code, seen.exception.retryable),
            (500, "INTERNAL_ERROR", False),
        )
        self.assertIn("sqlstate=22012", logs.output[0])
