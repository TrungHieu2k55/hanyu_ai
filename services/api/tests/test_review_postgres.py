import asyncio
import unittest
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from test_accounts_postgres import POLICIES
from test_ocr_postgres import DSN, TERMS, FixtureImages, TestTokens

from app.backend import PostgresBackend
from app.main import create_app
from app.ports import Identity
from app.postgres import Database
from app.sm2 import next_schedule


class Sm2Tests(unittest.TestCase):
    def test_reference_vectors(self):
        cases = (
            (0, 0, "2.5", 4, 1, 1, "2.5"),
            (1, 1, "2.5", 4, 2, 6, "2.5"),
            (2, 6, "2.5", 4, 3, 15, "2.5"),
            (2, 6, "2.5", 3, 3, 15, "2.36"),
            (2, 6, "2.5", 5, 3, 15, "2.6"),
            (3, 15, "2.5", 0, 0, 1, "1.7"),
            (2, 5, "2.5", 4, 3, 13, "2.5"),
            (2, 6, "1.3", 3, 3, 8, "1.3"),
        )
        accepted = datetime(2026, 11, 25, 15, tzinfo=UTC)
        for n, interval, ease, quality, next_n, next_interval, next_ease in cases:
            with self.subTest(n=n, interval=interval, ease=ease, quality=quality):
                schedule = next_schedule(
                    {
                        "repetitions": n,
                        "interval_days": interval,
                        "ease_factor": Decimal(ease),
                        "version": 2,
                        "algorithm_version": "hanyu-sm2-v1",
                    },
                    quality,
                    accepted,
                )
                self.assertEqual(schedule["repetitions"], next_n)
                self.assertEqual(schedule["interval_days"], next_interval)
                self.assertEqual(schedule["ease_factor"], Decimal(next_ease))
                self.assertEqual(
                    schedule["due_at"], accepted + timedelta(days=next_interval)
                )
                self.assertEqual(schedule["version"], 3)


@unittest.skipUnless(DSN, "Set HANYU_TEST_DATABASE_URL with migrations installed")
class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.conn = psycopg.connect(DSN, autocommit=True)
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

    @staticmethod
    def headers(actor="a"):
        return {"Authorization": f"Bearer {actor}", "Idempotency-Key": str(uuid4())}

    def save(self, hanzi, *, note=None):
        source = {
            "kind": "personal_new",
            "personal": {"hanzi": hanzi, "source": {"kind": "manual"}},
        }
        body = {"source": source}
        if note is not None:
            body["note"] = note
        response = self.client.post(
            "/v1/learning-items", json=body, headers=self.headers()
        )
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()

    def start(self, **body):
        return self.client.post(
            "/v1/reviews/sessions", json=body, headers=self.headers()
        )

    def test_rate_after_reveal_and_replay_without_duplicate_activity(self):
        self.assertEqual(self.start().json()["code"], "NO_DUE_CARDS")
        first = self.save("朋友", note="bạn bè")
        self.save("学习")
        response = self.start(limit=1)
        self.assertEqual(response.status_code, 201, response.text)
        session = response.json()
        self.assertEqual(self.start(limit=2).json(), session)
        session_path = f"/v1/reviews/sessions/{session['id']}"
        self.assertEqual(
            self.client.get(session_path, headers=self.headers("b")).status_code, 404
        )
        self.assertEqual(
            self.client.get(session_path, headers=self.headers()).json(), session
        )
        card = session["cards"][0]
        self.assertEqual(card["note"], "bạn bè")
        self.assertEqual(card["item_id"], first["id"])
        card_path = f"/v1/reviews/session-items/{card['session_item_id']}"
        ratings = card_path + "/ratings"
        body = {"expected_schedule_version": card["schedule_version"], "quality": 4}
        self.assertEqual(
            self.client.post(ratings, headers=self.headers("b"), json=body).status_code,
            404,
        )
        self.assertEqual(
            self.client.post(ratings, headers=self.headers(), json=body).json()["code"],
            "INVALID_STATE",
        )
        revealed = self.client.post(card_path + "/reveal", headers=self.headers())
        self.assertEqual(revealed.status_code, 200, revealed.text)
        self.assertIsNotNone(revealed.json()["revealed_at"])
        stale = self.client.post(
            ratings,
            headers=self.headers(),
            json={**body, "expected_schedule_version": 2},
        )
        self.assertEqual(stale.json()["code"], "STALE_REVIEW")
        headers = self.headers()
        result = self.client.post(ratings, headers=headers, json=body)
        self.assertEqual(result.status_code, 201, result.text)
        rated = result.json()
        self.assertEqual(rated["session"]["status"], "completed")
        self.assertEqual(rated["session"]["reviewed_count"], 1)
        self.assertEqual(rated["schedule"]["version"], 2)
        replay = self.client.post(ratings, headers=headers, json=body)
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.assertEqual(replay.json(), rated)
        self.assertEqual(
            self.client.post(ratings, headers=self.headers(), json=body).json()["code"],
            "STALE_REVIEW",
        )
        self.assertEqual(
            self.client.post(
                ratings, headers=headers, json={**body, "quality": 5}
            ).json()["code"],
            "IDEMPOTENCY_CONFLICT",
        )
        accepted, count = self.conn.execute(
            """SELECT e.accepted_at, count(a.id) FROM app.review_events e
               JOIN app.activity_events a ON a.review_event_id = e.id WHERE e.id = %s GROUP BY e.accepted_at""",
            (rated["event_id"],),
        ).fetchone()
        self.assertEqual(count, 1)
        self.assertEqual(
            datetime.fromisoformat(rated["schedule"]["due_at"]),
            accepted + timedelta(days=1),
        )
        queue = self.client.get("/v1/reviews/queue", headers=self.headers()).json()
        self.assertEqual(queue["due_count"], 1)

    def test_pause_resume_skips_archived_item_and_can_abandon(self):
        item = self.save("朋友")
        self.save("学习")
        session = self.start().json()
        url = f"/v1/reviews/sessions/{session['id']}"
        paused = self.client.patch(
            url,
            headers=self.headers(),
            json={
                "status": "paused",
                "expected_version": session["version"],
            },
        )
        self.assertEqual(paused.status_code, 200, paused.text)
        self.assertEqual(self.start().json()["status"], "paused")
        archived = self.client.patch(
            f"/v1/learning-items/{item['id']}",
            headers=self.headers(),
            json={
                "status": "archived",
                "expected_version": item["version"],
            },
        )
        self.assertEqual(archived.status_code, 200, archived.text)
        response = self.client.patch(
            url,
            headers=self.headers(),
            json={
                "status": "active",
                "expected_version": paused.json()["version"],
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        resumed = response.json()
        self.assertEqual(resumed["skipped_count"], 1)
        self.assertEqual([r["state"] for r in resumed["cards"]], ["skipped", "pending"])
        abandoned = self.client.patch(
            url,
            headers=self.headers(),
            json={
                "status": "abandoned",
                "expected_version": resumed["version"],
            },
        )
        self.assertEqual(abandoned.json()["status"], "abandoned")
        fresh = self.start()
        self.assertEqual(fresh.status_code, 201, fresh.text)
        self.assertNotEqual(fresh.json()["id"], session["id"])
        self.assertEqual(fresh.json()["total"], 1)

    def test_partial_review_survives_reload_and_pause(self):
        self.save("朋友")
        self.save("学习")
        session = self.start().json()
        first = session["cards"][0]
        card_path = f"/v1/reviews/session-items/{first['session_item_id']}"
        self.assertEqual(
            self.client.post(card_path + "/reveal", headers=self.headers()).status_code,
            200,
        )
        rating = self.client.post(
            card_path + "/ratings",
            headers=self.headers(),
            json={
                "quality": 3,
                "expected_schedule_version": first["schedule_version"],
            },
        )
        self.assertEqual(rating.status_code, 201, rating.text)
        progress = rating.json()["session"]
        self.assertEqual(progress["status"], "active")
        self.assertEqual(progress["reviewed_count"], 1)
        self.assertEqual(progress["total"], 2)
        url = f"/v1/reviews/sessions/{session['id']}"
        self.assertEqual(self.client.get(url, headers=self.headers()).json(), progress)
        paused = self.client.patch(
            url,
            headers=self.headers(),
            json={
                "status": "paused",
                "expected_version": progress["version"],
            },
        ).json()
        resumed = self.client.patch(
            url,
            headers=self.headers(),
            json={
                "status": "active",
                "expected_version": paused["version"],
            },
        ).json()
        self.assertEqual(
            [card["state"] for card in resumed["cards"]], ["reviewed", "pending"]
        )
        self.assertEqual(resumed["reviewed_count"], 1)

    def test_dashboard_and_activity_history_match_committed_reviews(self):
        for hanzi in ("朋友", "中国", "学习", "你好"):
            self.save(hanzi)
        session = self.start().json()
        rated = []
        for card, quality in zip(session["cards"], (0, 3, 5, 0), strict=True):
            url = f"/v1/reviews/session-items/{card['session_item_id']}"
            self.assertEqual(
                self.client.post(url + "/reveal", headers=self.headers()).status_code,
                200,
            )
            result = self.client.post(
                url + "/ratings",
                headers=self.headers(),
                json={
                    "quality": quality,
                    "expected_schedule_version": card["schedule_version"],
                },
            )
            self.assertEqual(result.status_code, 201, result.text)
            rated.append(result.json()["event_id"])
        self.save("老师")
        item_path = f"/v1/learning-items/{session['cards'][0]['item_id']}"
        saved = self.client.get(item_path, headers=self.headers()).json()
        archived = self.client.patch(
            item_path,
            headers=self.headers(),
            json={
                "expected_version": saved["version"],
                "status": "archived",
            },
        )
        self.assertEqual(archived.status_code, 200, archived.text)
        today = self.conn.execute(
            "SELECT (clock_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date"
        ).fetchone()[0]
        for event_id, days_ago in zip(rated, (1, 1, 2, 45), strict=True):
            local_day = today - timedelta(days=days_ago)
            occurred_at = self.conn.execute(
                "SELECT (%s::date + time '23:59:59') AT TIME ZONE 'Asia/Ho_Chi_Minh'",
                (local_day,),
            ).fetchone()[0]
            self.conn.execute(
                "UPDATE app.review_events SET accepted_at = %s WHERE id = %s",
                (occurred_at, event_id),
            )
            self.conn.execute(
                "UPDATE app.activity_events SET occurred_at = %s WHERE review_event_id = %s",
                (occurred_at, event_id),
            )

        start, end = today - timedelta(days=2), today - timedelta(days=1)
        params = {"from": start.isoformat(), "to": end.isoformat()}
        dashboard = self.client.get(
            "/v1/dashboard", params=params, headers=self.headers()
        )
        self.assertEqual(dashboard.status_code, 200, dashboard.text)
        self.assertEqual(
            dashboard.json(),
            {
                **params,
                "timezone": "Asia/Ho_Chi_Minh",
                "saved_words": 4,
                "studied_words": 3,
                "self_reported_remembered_words": 2,
                "review_count": 3,
                "remembered_review_count": 2,
                "review_accuracy_percent": 66.67,
                "current_streak": 2,
                "longest_streak": 2,
            },
        )
        no_activity = {"from": today.isoformat(), "to": today.isoformat()}
        empty = self.client.get(
            "/v1/dashboard", params=no_activity, headers=self.headers()
        ).json()
        self.assertIsNone(empty["review_accuracy_percent"])
        self.assertEqual(empty["current_streak"], 2)
        other = self.client.get("/v1/dashboard", headers=self.headers("b")).json()
        self.assertEqual(other["review_count"], 0)
        self.assertEqual(other["saved_words"], 0)
        self.assertEqual(other["current_streak"], 0)
        for invalid in (
            {"from": end.isoformat(), "to": start.isoformat()},
            {"from": "2000-01-01"},
            {"to": "bad"},
        ):
            self.assertEqual(
                self.client.get(
                    "/v1/dashboard", params=invalid, headers=self.headers()
                ).status_code,
                422,
            )

        pages = []
        cursor = None
        for _ in range(3):
            page_params = {
                **params,
                "limit": 1,
                **({"cursor": cursor} if cursor else {}),
            }
            page = self.client.get(
                "/v1/activities", params=page_params, headers=self.headers()
            )
            self.assertEqual(page.status_code, 200, page.text)
            cursor = page.json()["next_cursor"]
            pages.extend(page.json()["items"])
            if len(pages) == 1:
                scoped = {**params, "cursor": cursor}
                self.assertEqual(
                    self.client.get(
                        "/v1/activities", params=scoped, headers=self.headers("b")
                    ).json()["code"],
                    "INVALID_CURSOR",
                )
                self.assertEqual(
                    self.client.get(
                        "/v1/activities",
                        params={**scoped, "from": end.isoformat()},
                        headers=self.headers(),
                    ).json()["code"],
                    "INVALID_CURSOR",
                )
        self.assertIsNone(cursor)
        self.assertEqual({p["resource_id"] for p in pages}, set(rated[:3]))
        self.assertEqual(
            [p["local_day"] for p in pages],
            [end.isoformat(), end.isoformat(), start.isoformat()],
        )
        self.assertTrue(all(p["kind"] == "review" for p in pages))
