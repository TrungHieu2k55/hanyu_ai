import asyncio
import unittest
from contextlib import redirect_stdout
from io import StringIO
from time import time
from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from test_api import png
from test_ocr_postgres import DSN, TERMS, FixtureImages, TestTokens, run_async

from app.backend import PostgresBackend
from app.deletion_worker import purge_one
from app.main import create_app
from app.ports import Identity
from app.postgres import Database
from app.smoke import LEARNER_PATHS, run_checks

TRAINING = "training-dev-v1"
POLICIES = {
    "terms_version": TERMS,
    "terms_markdown": "# Điều khoản kiểm thử",
    "privacy_version": "privacy-dev-v1",
    "privacy_markdown": "# Quyền riêng tư kiểm thử",
    "training_policy_version": TRAINING,
    "training_markdown": "# Góp mẫu luyện viết kiểm thử",
}


@unittest.skipUnless(DSN, "Set HANYU_TEST_DATABASE_URL with migrations installed")
class AccountsPostgresTests(unittest.TestCase):
    def setUp(self):
        self.conn = psycopg.connect(DSN, autocommit=True)
        self.addCleanup(self.conn.close)
        self.users = {actor: Identity(uuid4(), uuid4()) for actor in ("a", "b")}
        for user in self.users.values():
            self.conn.execute("INSERT INTO auth.users VALUES (%s)", (user.user_id,))
            self.conn.execute(
                "INSERT INTO auth.sessions (id, user_id) VALUES (%s, %s)",
                (user.session_id, user.user_id),
            )
        self.client = self.new_client()
        self.body = {
            "display_name": "Học viên mới",
            "terms_version": TERMS,
            "training_policy_version": TRAINING,
            "training_opt_in": False,
        }

    def new_client(self, policies=POLICIES, *, deletion_enabled=False):
        db = Database(
            DSN, bytes(range(32)), policies["terms_version"] if policies else TERMS
        )
        client = TestClient(
            create_app(
                verifier=TestTokens(self.users),
                backend=PostgresBackend(
                    db,
                    FixtureImages(),
                    {"paddleocr": "pp-test"},
                    policies=policies,
                    deletion_enabled=deletion_enabled,
                ),
            ),
            backend_options={"loop_factory": asyncio.SelectorEventLoop},
        )
        self.addCleanup(client.close)
        return client

    @staticmethod
    def headers(actor="a", key=None):
        return {
            "Authorization": f"Bearer {actor}",
            "Idempotency-Key": str(key or uuid4()),
        }

    def boot(self, key=None, **overrides):
        return self.client.post(
            "/v1/me/bootstrap",
            json={**self.body, **overrides},
            headers=self.headers(key=key),
        )

    def upload(self, client):
        return client.post(
            "/v1/ocr/jobs",
            headers=self.headers(),
            files={"image": ("test.png", png("white"), "image/png")},
        )

    def test_new_account_requires_current_policies_and_can_start_ocr_without_training(
        self,
    ):
        headers = self.headers()
        self.assertEqual(self.client.get("/v1/policies/current").status_code, 401)
        self.assertEqual(
            self.client.get("/v1/policies/current", headers=headers).json(), POLICIES
        )
        self.assertEqual(
            self.boot(terms_version="old").json()["code"], "POLICY_OUTDATED"
        )
        self.assertEqual(
            self.boot(training_policy_version="old").json()["code"], "POLICY_OUTDATED"
        )
        self.assertEqual(
            self.client.get("/v1/me", headers=headers).json()["code"],
            "PROFILE_NOT_READY",
        )
        self.assertEqual(
            self.client.get("/v1/me/consents", headers=headers).status_code, 404
        )
        self.assertEqual(self.boot(role="admin").status_code, 422)
        created = self.boot()
        self.assertEqual(created.status_code, 201, created.text)
        self.assertEqual(created.json()["role"], "learner")
        self.assertFalse(created.json()["terms_required"])
        self.assertEqual(
            self.client.get("/v1/me", headers=headers).json(), created.json()
        )
        self.assertEqual(
            {
                row["purpose"]: row["granted"]
                for row in self.client.get("/v1/me/consents", headers=headers).json()[
                    "items"
                ]
            },
            {"terms": True, "training_handwriting": False},
        )
        self.assertEqual(self.upload(self.client).status_code, 202)

    def test_smoke_reads_learner_routes_for_bootstrapped_account(self):
        self.assertEqual(self.boot().status_code, 201)
        output = StringIO()
        with redirect_stdout(output):
            result = run_checks(self.client, token="a")
        self.assertEqual(result, 0, output.getvalue())
        for path in LEARNER_PATHS:
            self.assertIn(f"PASS GET {path}: HTTP 200", output.getvalue())

    def test_profile_bootstrap_replay_and_new_intent_do_not_overwrite(self):
        key = uuid4()
        first = self.boot(key)
        replay = self.boot(key, hsk_target=1, daily_minutes=15)
        self.assertEqual(first.status_code, 201, first.text)
        self.assertEqual(replay.status_code, 200, replay.text)
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.assertEqual(replay.json(), first.json())
        self.assertEqual(
            self.boot(key, hsk_target=3).json()["code"], "IDEMPOTENCY_CONFLICT"
        )
        self.assertEqual(
            self.boot(hsk_target=3, training_opt_in=True).json(), first.json()
        )
        self.assertEqual(
            self.conn.execute(
                "SELECT count(*) FROM app.consent_events WHERE owner_id = %s",
                (self.users["a"].user_id,),
            ).fetchone()[0],
            2,
        )

    def test_reacceptance_and_training_withdrawal_are_scoped_and_idempotent(self):
        self.assertEqual(self.boot(training_opt_in=True).status_code, 201)
        actor_b = self.client.post(
            "/v1/me/bootstrap", headers=self.headers("b"), json=self.body
        )
        self.assertEqual(actor_b.status_code, 201)
        next_terms = "terms-dev-v2"
        client = self.new_client({**POLICIES, "terms_version": next_terms})
        self.assertEqual(self.upload(client).json()["code"], "TERMS_REQUIRED")
        path = "/v1/me/consents"
        headers = self.headers()
        training = {
            "purpose": "training_handwriting",
            "policy_version": TRAINING,
            "granted": False,
        }
        withdrawal = client.post(path, json=training, headers=headers)
        self.assertEqual(withdrawal.status_code, 201, withdrawal.text)
        replay = client.post(path, json=training, headers=headers)
        self.assertEqual(replay.json(), withdrawal.json())
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.assertEqual(
            client.post(
                path, json={**training, "granted": True}, headers=headers
            ).json()["code"],
            "IDEMPOTENCY_CONFLICT",
        )
        terms = {"purpose": "terms", "policy_version": next_terms, "granted": True}
        self.assertEqual(
            client.post(
                path, json={**terms, "granted": False}, headers=self.headers()
            ).status_code,
            422,
        )
        self.assertEqual(
            client.post(path, json=terms, headers=self.headers()).status_code, 201
        )
        self.assertEqual(self.upload(client).status_code, 202)
        own = {
            row["purpose"]: row
            for row in client.get(path, headers=self.headers()).json()["items"]
        }
        other = {
            row["purpose"]: row
            for row in client.get(path, headers=self.headers("b")).json()["items"]
        }
        self.assertEqual(own["training_handwriting"], withdrawal.json())
        self.assertEqual(own["terms"]["policy_version"], next_terms)
        self.assertEqual(other["terms"]["policy_version"], TERMS)
        self.assertNotEqual(
            other["training_handwriting"]["id"], withdrawal.json()["id"]
        )

    def test_unconfigured_policies_revoked_session_and_database_role(self):
        client = self.new_client(None)
        self.assertEqual(
            client.get("/v1/policies/current", headers=self.headers()).status_code, 503
        )
        self.assertEqual(
            client.post(
                "/v1/me/bootstrap", headers=self.headers(), json=self.body
            ).status_code,
            503,
        )
        self.conn.execute(
            "DELETE FROM auth.sessions WHERE id = %s", (self.users["a"].session_id,)
        )
        self.assertEqual(self.boot().json()["code"], "SESSION_REVOKED")
        grants = self.conn.execute(
            """
            SELECT has_column_privilege('app_api', 'app.profiles', 'role', 'INSERT'),
                   has_table_privilege('app_api', 'app.consent_events', 'UPDATE'),
                   has_column_privilege('authenticated', 'app.profiles', 'display_name', 'INSERT')
            """
        ).fetchone()
        self.assertEqual(grants, (False, False, False))

    def test_profile_update_and_feedback_admin_queue(self):
        self.assertEqual(self.boot().status_code, 201)
        self.assertEqual(
            self.client.post(
                "/v1/me/bootstrap", headers=self.headers("b"), json=self.body
            ).status_code,
            201,
        )
        profile = self.client.get("/v1/me", headers=self.headers()).json()
        body = {
            "expected_version": profile["version"],
            "display_name": "New name",
            "sound_enabled": False,
        }
        updated = self.client.patch("/v1/me", headers=self.headers(), json=body)
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertFalse(updated.json()["sound_enabled"])
        self.assertEqual(
            self.client.patch("/v1/me", headers=self.headers(), json=body).json()[
                "code"
            ],
            "STALE_VERSION",
        )

        self.conn.execute(
            "UPDATE app.profiles SET role = 'admin' WHERE id = %s",
            (self.users["b"].user_id,),
        )
        headers = self.headers()
        report = self.client.post(
            "/v1/feedback",
            headers=headers,
            json={"kind": "support", "message": "Need help"},
        )
        self.assertEqual(report.status_code, 201, report.text)
        item = report.json()
        self.assertEqual(
            self.client.post(
                "/v1/feedback",
                headers=headers,
                json={"kind": "support", "message": "Need help"},
            ).json(),
            item,
        )
        self.assertEqual(
            self.client.get("/v1/feedback", headers=self.headers()).json()["items"],
            [item],
        )
        self.assertEqual(
            self.client.get(
                f"/v1/feedback/{item['id']}", headers=self.headers("b")
            ).status_code,
            404,
        )
        self.assertEqual(
            self.client.get("/v1/admin/reports", headers=self.headers()).status_code,
            403,
        )
        self.assertEqual(
            self.client.get("/v1/admin/reports", headers=self.headers("b")).json()[
                "items"
            ][0]["id"],
            item["id"],
        )
        url = f"/v1/admin/reports/{item['id']}"
        self.assertEqual(self.client.get(url, headers=self.headers("b")).json(), item)
        patch = {
            "expected_state_token": item["state_token"],
            "status": "resolved",
            "resolution_note": "Resolved",
        }
        closed = self.client.patch(url, headers=self.headers("b"), json=patch)
        self.assertEqual(closed.status_code, 200, closed.text)
        self.assertIsNotNone(closed.json()["closed_at"])
        self.assertEqual(
            self.client.patch(url, headers=self.headers("b"), json=patch).json()[
                "code"
            ],
            "STALE_VERSION",
        )
        self.assertEqual(
            self.client.get(
                f"/v1/feedback/{item['id']}", headers=self.headers()
            ).json()["status"],
            "resolved",
        )

    def test_avatar_replacement_and_linked_media_lifecycle(self):
        self.assertEqual(self.boot().status_code, 201)
        version = self.client.get("/v1/me", headers=self.headers()).json()["version"]
        key = self.headers()
        upload = {"image": ("avatar.png", png("white"), "image/png")}
        first = self.client.post(
            "/v1/me/avatar",
            headers=key,
            files=upload,
            data={"expected_version": str(version)},
        )
        self.assertEqual(first.status_code, 200, first.text)
        media = first.json()["avatar_media_id"]
        self.assertEqual(
            self.client.post(
                "/v1/me/avatar",
                headers=key,
                files=upload,
                data={"expected_version": str(version)},
            ).headers["Idempotency-Replayed"],
            "true",
        )
        self.assertEqual(
            self.client.get(
                f"/v1/media/{media}/url", headers=self.headers()
            ).status_code,
            200,
        )
        self.assertEqual(
            self.client.delete(
                f"/v1/media/{media}", headers=self.headers(key=uuid4())
            ).json()["code"],
            "RESOURCE_IN_USE",
        )
        second = self.client.post(
            "/v1/me/avatar",
            headers=self.headers(key=uuid4()),
            files=upload,
            data={"expected_version": str(version + 1)},
        )
        self.assertEqual(second.status_code, 200, second.text)
        self.assertNotEqual(second.json()["avatar_media_id"], media)
        removed = self.client.delete(
            f"/v1/media/{media}", headers=self.headers(key=uuid4())
        )
        self.assertEqual(removed.status_code, 202, removed.text)
        self.assertEqual(removed.json()["state"], "delete_pending")
        self.conn.execute(
            "UPDATE app.media_assets SET expires_at = clock_timestamp() + interval '1 day' WHERE id=%s",
            (media,),
        )

    def test_account_deletion_requires_fresh_auth_and_status_uses_only_receipt(self):
        self.assertEqual(self.boot().status_code, 201)
        self.assertEqual(
            self.client.post(
                "/v1/me/bootstrap", headers=self.headers("b"), json=self.body
            ).status_code,
            201,
        )
        body = {"confirm": "DELETE_MY_ACCOUNT"}
        path = "/v1/account-deletions"
        old = self.client.post(path, headers=self.headers(key=uuid4()), json=body)
        self.assertEqual(old.json()["code"], "REAUTH_REQUIRED")
        owner = self.users["a"]
        self.users["a"] = Identity(owner.user_id, owner.session_id, int(time()))
        client = self.new_client(deletion_enabled=True)
        accepted = client.post(path, headers=self.headers(key=uuid4()), json=body)
        self.assertEqual(accepted.status_code, 202, accepted.text)
        self.assertEqual(
            client.get("/v1/me", headers=self.headers()).json()["code"],
            "ACCOUNT_DELETING",
        )
        self.assertEqual(
            client.get(path + "/status", headers=self.headers()).status_code, 404
        )
        receipt = {"Authorization": "Bearer " + accepted.json()["receipt_token"]}
        self.assertEqual(
            client.get(path + "/status", headers=receipt).json()["status"], "requested"
        )
        self.conn.execute(
            "UPDATE app_private.account_deletions SET available_at=now() WHERE owner_id=%s",
            (owner.user_id,),
        )

        async def delete_auth(user):
            self.conn.execute("DELETE FROM auth.users WHERE id=%s", (user,))

        db = Database(DSN, bytes(range(32)), TERMS)
        self.assertTrue(
            run_async(purge_one(db, FixtureImages(), FixtureImages(), delete_auth))
        )
        status = client.get(path + "/status", headers=receipt)
        self.assertEqual(status.status_code, 200, status.text)
        self.assertEqual(status.json()["status"], "completed")
        self.assertIsNone(
            self.conn.execute(
                "SELECT id FROM app.profiles WHERE id=%s", (owner.user_id,)
            ).fetchone()
        )
        self.assertEqual(
            client.get("/v1/me", headers=self.headers("b")).status_code, 200
        )
