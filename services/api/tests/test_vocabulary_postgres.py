import asyncio
import unittest
from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from psycopg.types.json import Jsonb
from test_accounts_postgres import POLICIES
from test_ocr_postgres import DSN, TERMS, FixtureImages, TestTokens

from app.backend import PostgresBackend
from app.main import create_app
from app.ports import Identity
from app.postgres import Database


@unittest.skipUnless(DSN, "Set HANYU_TEST_DATABASE_URL with migrations installed")
class VocabularyTests(unittest.TestCase):
    def setUp(self):
        self.conn = psycopg.connect(DSN, autocommit=True, prepare_threshold=None)
        self.addCleanup(self.conn.close)
        self.users = {actor: Identity(uuid4(), uuid4()) for actor in ("a", "b")}
        self.client = TestClient(
            create_app(
                verifier=TestTokens(self.users),
                backend=PostgresBackend(
                    Database(DSN, bytes(range(32)), TERMS),
                    FixtureImages(),
                    policies=POLICIES,
                ),
            ),
            backend_options={"loop_factory": asyncio.SelectorEventLoop},
        )
        self.addCleanup(self.client.close)
        for actor, user in self.users.items():
            self.conn.execute("INSERT INTO auth.users VALUES (%s)", (user.user_id,))
            self.conn.execute(
                "INSERT INTO auth.sessions (id, user_id) VALUES (%s, %s)",
                (user.session_id, user.user_id),
            )
            created = self.client.post(
                "/v1/me/bootstrap",
                headers=self.headers(actor),
                json={
                    "display_name": actor,
                    "terms_version": TERMS,
                    "training_policy_version": POLICIES["training_policy_version"],
                    "training_opt_in": False,
                },
            )
            self.assertEqual(created.status_code, 201, created.text)
        self.published = self.add_word(1, "朋友", "péngyou", "Bạn bè")
        self.draft = self.add_word(1, "明天", "míngtiān", "ngày mai", published=False)
        self.add_word(2, "理解", "lǐjiě", "hiểu rõ")

    @staticmethod
    def headers(actor="a", key=None):
        return {
            "Authorization": f"Bearer {actor}",
            "Idempotency-Key": str(key or uuid4()),
        }

    def add_word(
        self,
        level,
        hanzi,
        pinyin,
        vietnamese,
        *,
        published=True,
        reading_key="peng2you5",
    ):
        entry, revision = uuid4(), uuid4()
        self.conn.execute(
            "INSERT INTO app.vocabulary (id, hanzi, reading_key, sense_id) VALUES (%s, %s, %s, %s)",
            (entry, hanzi, reading_key, uuid4()),
        )
        self.conn.execute(
            """
            INSERT INTO app.vocabulary_revisions
                (id, entry_id, revision, status, pinyin_display, vietnamese, hsk_level, examples,
                 source_name, source_external_id, source_version, license, content_hash, reviewed_at, published_at)
            VALUES (%s, %s, 1, %s, %s, %s, %s, %s, 'fixture', %s, 'v1', 'test', %s, now(), now())
            """,
            (
                revision,
                entry,
                "published" if published else "draft",
                pinyin,
                vietnamese,
                level,
                Jsonb([]),
                str(entry),
                "0" * 64,
            ),
        )
        if published:
            self.conn.execute(
                "UPDATE app.vocabulary SET published_revision_id = %s WHERE id = %s",
                (revision, entry),
            )
        return str(entry)

    def test_search_publication_scope_and_pagination(self):
        for query in ("朋友", "péngyou", "pengyou", "peng2you5", "ban be"):
            response = self.client.get(
                "/v1/vocabulary",
                params={"q": query, "hsk_level": 1},
                headers=self.headers(),
            )
            self.assertEqual(response.status_code, 200, response.text)
            self.assertIn(
                self.published,
                [r["entry_id"] for r in response.json()["items"]],
                ascii(query),
            )
        self.assertEqual(
            self.client.get(
                f"/v1/vocabulary/{self.draft}", headers=self.headers()
            ).status_code,
            404,
        )
        first = self.client.get(
            "/v1/vocabulary", params={"limit": 1}, headers=self.headers()
        ).json()
        cursor = first["next_cursor"]
        self.assertIsNotNone(cursor)
        same = self.client.get(
            "/v1/vocabulary",
            params={"limit": 1, "cursor": cursor},
            headers=self.headers(),
        ).json()
        self.assertNotEqual(first["items"][0]["entry_id"], same["items"][0]["entry_id"])
        other = self.client.get(
            "/v1/vocabulary", params={"cursor": cursor}, headers=self.headers("b")
        )
        self.assertEqual(other.json()["code"], "INVALID_CURSOR")

    def test_save_replay_archive_restore_and_queue(self):
        endpoint = "/v1/learning-items"
        body = {
            "source": {"kind": "canonical", "entry_id": self.published},
            "note": "Một ghi chú",
        }
        request_headers = self.headers()
        first = self.client.post(endpoint, headers=request_headers, json=body)
        self.assertEqual(first.status_code, 201, first.text)
        item = first.json()
        self.assertEqual(item["schedule"]["ease_factor"], 2.5)
        self.assertEqual(item["selected_note_id"], item["notes"][0]["id"])
        replay = self.client.post(endpoint, headers=request_headers, json=body)
        self.assertEqual(replay.json(), item)
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.assertEqual(
            self.client.post(
                endpoint, headers=request_headers, json={**body, "note": "Khác"}
            ).json()["code"],
            "IDEMPOTENCY_CONFLICT",
        )
        item_path = f"{endpoint}/{item['id']}"
        self.assertEqual(
            self.client.get(item_path, headers=self.headers("b")).status_code, 404
        )
        self.assertEqual(
            self.client.get(endpoint, headers=self.headers("b")).json()["items"], []
        )
        word = self.client.get(
            f"/v1/vocabulary/{self.published}", headers=self.headers()
        )
        self.assertEqual(word.json()["learning_item_id"], item["id"])
        queue = "/v1/reviews/queue"
        self.assertEqual(
            self.client.get(queue, headers=self.headers()).json()["due_count"], 1
        )
        change = {"status": "archived", "expected_version": item["version"]}
        archived = self.client.patch(item_path, json=change, headers=self.headers())
        self.assertEqual(archived.status_code, 200, archived.text)
        self.assertEqual(
            self.client.get(queue, headers=self.headers()).json()["due_count"], 0
        )
        stale = self.client.patch(item_path, json=change, headers=self.headers())
        self.assertEqual(stale.json()["code"], "STALE_VERSION")
        restored = self.client.post(
            endpoint, json={"source": body["source"]}, headers=self.headers()
        )
        self.assertEqual(restored.status_code, 200, restored.text)
        self.assertEqual(restored.json()["schedule"], item["schedule"])
        self.assertEqual(restored.json()["notes"], item["notes"])
        self.assertEqual(
            self.client.get(queue, headers=self.headers()).json()["due_count"], 1
        )

    def test_private_source_cannot_be_attached_by_another_owner(self):
        path = "/v1/learning-items"
        source = {
            "kind": "personal_new",
            "personal": {"hanzi": "新词", "source": {"kind": "manual"}},
        }
        response = self.client.post(
            path, json={"source": source}, headers=self.headers()
        )
        self.assertEqual(response.status_code, 201, response.text)
        item = response.json()
        attach = {
            "kind": "personal_existing",
            "personal_entry_id": item["personal_entry_id"],
        }
        self.assertEqual(
            self.client.post(
                path, json={"source": attach}, headers=self.headers("b")
            ).status_code,
            404,
        )
        own = self.client.post(path, json={"source": attach}, headers=self.headers())
        self.assertEqual(own.status_code, 200, own.text)
        self.assertEqual(own.json()["id"], item["id"])

    def test_personal_notes_version_default_withdrawal_and_replay(self):
        source = {"kind": "canonical", "entry_id": self.published}
        item = self.client.post(
            "/v1/learning-items", json={"source": source}, headers=self.headers()
        ).json()
        path = f"/v1/learning-items/{item['id']}"
        note_path = path + "/notes"
        save_headers = self.headers()
        response = self.client.post(
            note_path, json={"text": "Private"}, headers=save_headers
        )
        self.assertEqual(response.status_code, 201, response.text)
        note = response.json()
        self.assertEqual(
            self.client.get(path, headers=self.headers()).json()["selected_note_id"],
            note["id"],
        )
        self.assertEqual(
            self.client.get(note_path, headers=self.headers()).json()["items"], [note]
        )
        self.assertEqual(
            self.client.get(note_path, headers=self.headers("b")).status_code, 404
        )
        url = f"/v1/notes/{note['id']}"
        edit = {"text": "Edited", "expected_version": 1}
        updated = self.client.patch(url, json=edit, headers=self.headers())
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(
            self.client.patch(url, json=edit, headers=self.headers()).json()["code"],
            "STALE_VERSION",
        )
        new = self.client.post(
            note_path, json={"text": "Another"}, headers=self.headers()
        ).json()
        membership = self.client.get(path, headers=self.headers()).json()
        selection = self.client.patch(
            path + "/default-note",
            json={
                "note_id": new["id"],
                "expected_version": membership["version"],
            },
            headers=self.headers(),
        )
        self.assertEqual(selection.json()["selected_note_id"], new["id"])
        delete = self.headers()
        params = {"expected_version": new["version"]}
        new_url = f"/v1/notes/{new['id']}"
        self.assertEqual(
            self.client.delete(new_url, params=params, headers=delete).status_code, 204
        )
        self.assertEqual(
            self.client.delete(new_url, params=params, headers=delete).headers[
                "Idempotency-Replayed"
            ],
            "true",
        )
        self.assertIsNone(
            self.client.get(path, headers=self.headers()).json()["selected_note_id"]
        )
        self.assertEqual(
            self.client.delete(
                url, params={"expected_version": 2}, headers=self.headers()
            ).status_code,
            204,
        )
        replay = self.client.post(
            note_path, json={"text": "Private"}, headers=save_headers
        )
        self.assertEqual(replay.json()["code"], "RESOURCE_GONE")

    def test_personal_edit_and_authorized_sample_mapping(self):
        entry = self.client.get(
            f"/v1/vocabulary/{self.published}", headers=self.headers()
        ).json()
        self.conn.execute(
            "INSERT INTO app.vocabulary_sample_mappings VALUES ('sample','v1',%s)",
            (self.published,),
        )
        result = self.client.post(
            "/v1/vocabulary/resolve-sample",
            headers=self.headers(),
            json={"sample_id": "sample", "content_version": "v1"},
        )
        self.assertEqual(result.status_code, 200, result.text)
        self.assertEqual(result.json()["revision_id"], entry["revision_id"])
        self.assertEqual(
            self.client.get("/v1/learning-items", headers=self.headers()).json()[
                "items"
            ],
            [],
        )
        source = {
            "kind": "personal_new",
            "personal": {
                "hanzi": "书",
                "vietnamese": "sách",
                "source": {"kind": "manual"},
            },
        }
        item = self.client.post(
            "/v1/learning-items", headers=self.headers(), json={"source": source}
        ).json()
        edit = f"/v1/personal-entries/{item['personal_entry_id']}"
        body = {"expected_version": item["personal_version"], "vietnamese": None}
        self.assertEqual(
            self.client.patch(edit, headers=self.headers("b"), json=body).status_code,
            404,
        )
        result = self.client.patch(edit, headers=self.headers(), json=body)
        self.assertEqual(result.status_code, 200, result.text)
        self.assertIsNone(result.json()["vietnamese"])

    def test_personal_link_keeps_note_and_due_schedule(self):
        source = {
            "kind": "personal_new",
            "personal": {"hanzi": "朋友", "source": {"kind": "manual"}},
        }
        initial = self.client.post(
            "/v1/learning-items",
            headers=self.headers(),
            json={"source": source, "note": "My note"},
        ).json()
        path = f"/v1/personal-entries/{initial['personal_entry_id']}/link"
        body = {
            "expected_version": initial["personal_version"],
            "entry_id": self.published,
            "confirm": True,
            "selected_note_id": initial["selected_note_id"],
        }
        key = self.headers()
        merged = self.client.post(path, headers=key, json=body)
        self.assertEqual(merged.status_code, 200, merged.text)
        target = merged.json()
        self.assertEqual(target["schedule"], initial["schedule"])
        self.assertEqual(target["notes"][0]["text"], "My note")
        self.assertEqual(target["selected_note_id"], initial["selected_note_id"])
        self.assertEqual(self.client.post(path, headers=key, json=body).json(), target)
        old = self.client.get(
            f"/v1/learning-items/{initial['id']}", headers=self.headers()
        ).json()
        self.assertEqual(
            (old["status"], old["merged_into_id"]), ("merged", target["id"])
        )

    def test_search_ranks_exact_then_prefix_and_keeps_pinyin_umlaut(self):
        meaning = self.add_word(3, "海", "hǎi", "Nghĩa khác 龙", reading_key="hai3")
        prefix = self.add_word(3, "龙虾", "lóngxiā", "tôm hùm", reading_key="long2xia1")
        exact = self.add_word(3, "龙", "lóng", "rồng", reading_key="long2")
        params = {"q": "龙", "hsk_level": 3, "limit": 1}
        ids = []
        for expected in (exact, prefix, meaning):
            response = self.client.get(
                "/v1/vocabulary", params=params, headers=self.headers()
            )
            self.assertEqual(response.status_code, 200, response.text)
            payload = response.json()
            ids.append(payload["items"][0]["entry_id"])
            self.assertEqual(ids[-1], expected)
            params["cursor"] = payload["next_cursor"]
        self.assertIsNone(params["cursor"])
        umlaut = self.add_word(3, "绿", "lǜ", "xanh", reading_key="lv4")
        plain = self.add_word(3, "路", "lù", "đường", reading_key="lu4")
        for query, expected in (
            ("lǜ", umlaut),
            ("lü", umlaut),
            ("lv4", umlaut),
            ("lù", plain),
            ("lu4", plain),
        ):
            result = self.client.get(
                "/v1/vocabulary",
                params={"q": query, "hsk_level": 3},
                headers=self.headers(),
            )
            self.assertEqual(result.status_code, 200, result.text)
            self.assertEqual(
                [r["entry_id"] for r in result.json()["items"]], [expected]
            )
