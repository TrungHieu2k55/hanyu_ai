import json
from datetime import timedelta
from uuid import uuid4

from .accounts import Accounts, fingerprint
from .errors import ApiError
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .reviews import server_time
from .vocabulary import check_version, missing, uuid_str

_QUESTIONS = """
SELECT id, position, kind, prompt, options, audio_media_id
FROM app.questions WHERE test_revision_id = %s ORDER BY position
"""
_ATTEMPT_COLUMNS = "id, test_revision_id, status, started_at, deadline_at, submitted_at, score, version, listening_score, reading_score"
_ANSWER_COLUMNS = "question_id, selected_index, answer_version, accepted_at"


def answer_dto(row: dict) -> dict:
    return {
        **row,
        "question_id": str(row["question_id"]),
        "accepted_at": row["accepted_at"].isoformat(),
    }


def attempt_summary(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "test_revision_id": str(row["test_revision_id"]),
        "status": row["status"],
        "score": row["score"],
        "started_at": row["started_at"].isoformat(),
        "deadline_at": row["deadline_at"].isoformat(),
        "provenance": "legacy_unverified_snapshot"
        if row["status"] == "legacy_unverified"
        else "native",
    }


class Exams:
    def __init__(self, db: Database, accounts: Accounts):
        self.db = db
        self.accounts = accounts

    @staticmethod
    async def _attempt(tx, owner, attempt):
        row = await one(
            tx,
            f"SELECT {_ATTEMPT_COLUMNS} FROM app.test_attempts WHERE owner_id = %s AND id = %s",
            (owner, attempt),
        )
        if row is None:
            raise missing()
        return row

    @staticmethod
    async def _expire(tx, owner):
        expired = await many(
            tx,
            """SELECT id FROM app.test_attempts WHERE owner_id = %s
                         AND status = 'in_progress' AND deadline_at <= clock_timestamp() ORDER BY id""",
            (owner,),
        )
        for attempt in expired:
            await tx.execute(
                "SELECT app_private.exam_finalize(%s, false)", (attempt["id"],)
            )

    async def _view(self, tx, row, owner) -> dict:
        if row["status"] == "legacy_unverified":
            return {
                "id": str(row["id"]),
                "status": row["status"],
                "score": row["score"],
                "started_at": row["started_at"].isoformat(),
                "provenance": "legacy_unverified_snapshot",
                "message": "Kết quả được giữ từ bản cũ và chưa xác minh đáp án.",
            }
        questions = await many(tx, _QUESTIONS, (row["test_revision_id"],))
        answers = await many(
            tx,
            f"""SELECT {_ANSWER_COLUMNS} FROM app.test_answers
                                       WHERE owner_id = %s AND attempt_id = %s ORDER BY question_id""",
            (owner, row["id"]),
        )
        return {
            **attempt_summary(row),
            "submitted_at": row["submitted_at"].isoformat()
            if row["submitted_at"]
            else None,
            "server_time": (await server_time(tx)).isoformat(),
            "version": row["version"],
            "questions": [
                {
                    **q,
                    "id": str(q["id"]),
                    "audio_media_id": uuid_str(q["audio_media_id"]),
                }
                for q in questions
            ],
            "answers": [answer_dto(a) for a in answers],
        }

    async def tests(self, call: Call) -> Result:
        owner = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, owner)
            rows = await many(
                tx,
                """
                SELECT t.id, r.id AS revision_id, t.hsk_level, t.title, r.duration_seconds,
                       20 AS question_count, r.listening_count, r.reading_count, a.id AS active_attempt_id
                FROM app.tests t JOIN app.test_revisions r ON r.id = t.published_revision_id
                LEFT JOIN app.test_attempts a ON a.owner_id = %s AND a.test_id = t.id AND a.status = 'in_progress'
                WHERE r.status = 'published' AND r.package_kind = 'p0'
                  AND app_private.exam_package_ready(r.id)
                ORDER BY t.hsk_level
                """,
                (owner,),
            )
        return Result(
            200,
            {
                "items": [
                    {
                        **r,
                        **{
                            k: uuid_str(r[k])
                            for k in ("id", "revision_id", "active_attempt_id")
                        },
                    }
                    for r in rows
                ]
            },
        )

    async def start(self, call: Call) -> Result:
        owner, test = call.identity.user_id, call.body["test_id"]
        operation = "exam.start"
        digest = fingerprint(call, operation, {"test_id": test})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, owner)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                row = await self._attempt(tx, owner, previous)
                return Result(200, await self._view(tx, row, owner), replayed=True)
            active = await one(
                tx,
                f"""SELECT {_ATTEMPT_COLUMNS} FROM app.test_attempts
                                      WHERE owner_id = %s AND test_id = %s AND status = 'in_progress'""",
                (owner, test),
            )
            if active is not None:
                await write_receipt(
                    tx, call, operation, digest, active["id"], "test_attempt"
                )
                return Result(200, await self._view(tx, active, owner))
            package = await one(
                tx,
                """SELECT r.id, r.duration_seconds FROM app.tests t JOIN app.test_revisions r
                 ON r.id = t.published_revision_id WHERE t.id = %s AND app_private.exam_package_ready(r.id)""",
                (test,),
            )
            if package is None:
                raise missing()
            attempt = uuid4()
            operation_id = await write_receipt(
                tx, call, operation, digest, attempt, "test_attempt"
            )
            now = await server_time(tx)
            await tx.execute(
                """
                INSERT INTO app.test_attempts (id, owner_id, operation_id, test_id, test_revision_id, started_at, deadline_at)
                VALUES (%s,%s,%s,%s,%s,%s,%s)
                """,
                (
                    attempt,
                    owner,
                    operation_id,
                    test,
                    package["id"],
                    now,
                    now + timedelta(seconds=package["duration_seconds"]),
                ),
            )
            return Result(
                201,
                await self._view(tx, await self._attempt(tx, owner, attempt), owner),
            )

    async def attempts(self, call: Call) -> Result:
        owner = call.identity.user_id
        status = call.query.get("status")
        limit = call.query.get("limit", 20)
        scope = json.dumps(["exam-history", str(owner), status])
        date, cursor_id = self.db.read_cursor(scope, call.query.get("cursor"))
        sql = f"SELECT {_ATTEMPT_COLUMNS}, created_at FROM app.test_attempts WHERE owner_id = %s"
        args = [owner]
        if status == "active":
            sql += " AND status = 'in_progress'"
        elif status == "locked":
            sql += " AND status <> 'in_progress'"
        if date is not None:
            sql += " AND (created_at, id) < (%s, %s)"
            args.extend((date, cursor_id))
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, owner)
            rows = await many(
                tx,
                sql + " ORDER BY created_at DESC, id DESC LIMIT %s",
                (*args, limit + 1),
            )
        next_cursor = (
            self.db.cursor(scope, rows[limit - 1]) if len(rows) > limit else None
        )
        return Result(
            200,
            {
                "items": [attempt_summary(r) for r in rows[:limit]],
                "next_cursor": next_cursor,
            },
        )

    async def get(self, call: Call) -> Result:
        owner, attempt = call.identity.user_id, call.path["attempt_id"]
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, owner)
            row = await self._attempt(tx, owner, attempt)
            return Result(200, await self._view(tx, row, owner))

    async def answer(self, call: Call) -> Result:
        owner, attempt, question = (
            call.identity.user_id,
            call.path["attempt_id"],
            call.path["question_id"],
        )
        operation = "exam.answer"
        digest = fingerprint(call, operation, {**call.path, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                saved = await one(
                    tx,
                    f"SELECT {_ANSWER_COLUMNS} FROM app.test_answer_saves WHERE owner_id = %s AND id = %s",
                    (owner, previous),
                )
                return Result(200, answer_dto(saved), replayed=True)
            row = await self._attempt(tx, owner, attempt)
            now = await server_time(tx)
            if row["status"] == "in_progress":
                if now < row["deadline_at"]:
                    saved = await self._save_answer(
                        tx, call, row, owner, question, now, operation, digest
                    )
                    return Result(200, answer_dto(saved))
                await tx.execute(
                    "SELECT app_private.exam_finalize(%s, false)", (attempt,)
                )
            elif row["status"] != "timed_out":
                raise ApiError(409, "TEST_LOCKED", "Bài làm đã được khóa.")
        raise ApiError(409, "TEST_EXPIRED", "Đã hết giờ làm bài.")

    async def _save_answer(
        self, tx, call, row, owner, question, now, operation, digest
    ):
        valid = await one(
            tx,
            "SELECT id FROM app.questions WHERE test_revision_id = %s AND id = %s",
            (row["test_revision_id"], question),
        )
        if valid is None:
            raise missing()
        existing = await one(
            tx,
            """SELECT answer_version FROM app.test_answers WHERE owner_id = %s
                                     AND attempt_id = %s AND question_id = %s""",
            (owner, row["id"], question),
        )
        version = existing["answer_version"] if existing is not None else 0
        if version != call.body["expected_answer_version"]:
            raise ApiError(409, "STALE_VERSION", "Đáp án đã đổi. Hãy tải lại.")
        saved_id = uuid4()
        operation_id = await write_receipt(
            tx, call, operation, digest, saved_id, "test_answer_save"
        )
        values = (
            owner,
            row["id"],
            row["test_revision_id"],
            question,
            call.body["selected_index"],
            version + 1,
            now,
            operation_id,
        )
        saved = await one(
            tx,
            f"""INSERT INTO app.test_answer_saves
                    (id, owner_id, attempt_id, test_revision_id, question_id, selected_index, answer_version,
                     accepted_at, operation_id) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    RETURNING {_ANSWER_COLUMNS}""",
            (saved_id, *values),
        )
        await tx.execute(
            """INSERT INTO app.test_answers (owner_id, attempt_id, test_revision_id, question_id,
                    selected_index, answer_version, accepted_at, last_operation_id) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (attempt_id, question_id) DO UPDATE SET selected_index = excluded.selected_index,
                    answer_version = excluded.answer_version, accepted_at = excluded.accepted_at,
                    last_operation_id = excluded.last_operation_id""",
            values,
        )
        await tx.execute(
            "UPDATE app.test_attempts SET version = version + 1 WHERE id = %s AND owner_id = %s",
            (row["id"], owner),
        )
        return saved

    @staticmethod
    async def _result(tx, row):
        if row["status"] == "legacy_unverified":
            raise ApiError(409, "LEGACY_UNVERIFIED", "Bài làm cũ chưa xác minh.")
        if row["status"] == "in_progress":
            raise ApiError(409, "RESULT_NOT_READY", "Chưa có kết quả bài làm.")
        answers = await many(
            tx, "SELECT * FROM app_private.exam_explanations(%s)", (row["id"],)
        )
        return {
            "attempt_id": str(row["id"]),
            "status": row["status"],
            "score": row["score"],
            "listening_score": row["listening_score"],
            "reading_score": row["reading_score"],
            "submitted_at": row["submitted_at"].isoformat(),
            "answers": [{**a, "question_id": str(a["question_id"])} for a in answers],
        }

    async def submit(self, call: Call) -> Result:
        owner, attempt = call.identity.user_id, call.path["attempt_id"]
        operation = "exam.submit"
        digest = fingerprint(call, operation, {"attempt_id": attempt, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                row = await self._attempt(tx, owner, previous)
                return Result(200, await self._result(tx, row), replayed=True)
            await self._expire(tx, owner)
            row = await self._attempt(tx, owner, attempt)
            if row["status"] == "in_progress":
                check_version(row, call.body["expected_version"])
                await tx.execute(
                    "SELECT app_private.exam_finalize(%s, true)", (attempt,)
                )
                row = await self._attempt(tx, owner, attempt)
            view = await self._result(tx, row)
            await write_receipt(tx, call, operation, digest, row["id"], "test_attempt")
            return Result(200, view)

    async def result(self, call: Call) -> Result:
        owner, attempt = call.identity.user_id, call.path["attempt_id"]
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, owner)
            return Result(
                200, await self._result(tx, await self._attempt(tx, owner, attempt))
            )
