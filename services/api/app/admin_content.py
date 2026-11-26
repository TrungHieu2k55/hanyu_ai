import hashlib
import json
import re
from uuid import UUID, uuid4

from psycopg.types.json import Jsonb

from .accounts import Accounts, fingerprint
from .errors import ApiError, invalid_input
from .operations import lock_owner, lock_vocabulary_writes, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .vocabulary import clean_text, missing, uuid_str

_WORD_FIELDS = (
    "pinyin_display",
    "vietnamese",
    "hsk_level",
    "part_of_speech",
    "examples",
    "source_name",
    "source_external_id",
    "source_version",
    "license",
)
_WORD = """
SELECT v.id AS entry_id, v.hanzi, v.reading_key, v.sense_id, v.published_revision_id,
       r.*, r.created_at AS cursor_date
FROM app.vocabulary v JOIN app.vocabulary_revisions r ON r.entry_id = v.id
"""
_TEST = """
SELECT t.id AS test_id, t.hsk_level, r.*
FROM app.tests t JOIN app.test_revisions r ON r.test_id = t.id
"""
_QUESTION = """
SELECT q.id AS question_id, r.test_id, q.test_revision_id, q.created_at, q.position,
       q.kind, q.prompt, q.options, q.audio_media_id, k.correct_index, k.explanation
FROM app.questions q JOIN app.test_revisions r ON r.id = q.test_revision_id
JOIN app_private.answer_keys k ON k.question_id = q.id
"""
_LATEST_WORD = """r.revision = (SELECT max(x.revision) FROM app.vocabulary_revisions x WHERE x.entry_id = v.id)"""
_LATEST_TEST = """r.revision = (SELECT max(x.revision) FROM app.test_revisions x WHERE x.test_id = t.id)"""
_TRANSITIONS = {
    ("draft", "in_review"),
    ("in_review", "draft"),
    ("in_review", "published"),
    ("published", "withdrawn"),
}


def meta(row):
    return {
        "id": str(row["id"]),
        "revision": row["revision"],
        "status": row["status"],
        "published_at": row["published_at"].isoformat()
        if row["published_at"]
        else None,
    }


def word(row):
    return {
        "entry_id": str(row["entry_id"]),
        "hanzi": row["hanzi"],
        "reading_key": row["reading_key"],
        "sense_id": str(row["sense_id"]),
        "published_revision_id": uuid_str(row["published_revision_id"]),
        "latest": meta(row),
        "content": {k: row[k] for k in _WORD_FIELDS},
    }


def question_summary(row):
    return {
        **{k: str(row[k]) for k in ("question_id", "test_id", "test_revision_id")},
        **{k: row[k] for k in ("position", "kind", "prompt")},
    }


def question_content(row):
    return {
        **{
            k: row[k]
            for k in (
                "position",
                "kind",
                "prompt",
                "options",
                "correct_index",
                "explanation",
            )
        },
        "audio_media_id": uuid_str(row["audio_media_id"]),
    }


class AdminContent:
    def __init__(self, db: Database, accounts: Accounts):
        self.db = db
        self.accounts = accounts

    async def words(self, call: Call) -> Result:
        status, limit = call.query.get("status"), call.query.get("limit", 20)
        scope = json.dumps(["admin-words", str(call.identity.user_id), status])
        date, row_id = self.db.read_cursor(scope, call.query.get("cursor"))
        sql = _WORD + " WHERE " + _LATEST_WORD
        args = []
        if status is not None:
            sql += " AND r.status = %s"
            args.append(status)
        if date is not None:
            sql += " AND (r.created_at, r.id) < (%s, %s)"
            args.extend((date, row_id))
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            rows = await many(
                tx,
                sql + " ORDER BY r.created_at DESC, r.id DESC LIMIT %s",
                (*args, limit + 1),
            )
        return Result(
            200,
            {
                "items": [word(r) for r in rows[:limit]],
                "next_cursor": self.db.cursor(scope, rows[limit - 1])
                if len(rows) > limit
                else None,
            },
        )

    async def get_word(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            row = await one(
                tx,
                _WORD + " WHERE v.id = %s AND " + _LATEST_WORD,
                (call.path["entry_id"],),
            )
        if row is None:
            raise missing()
        return Result(200, word(row))

    async def revise_word(self, call: Call) -> Result:
        owner, body = call.identity.user_id, call.body
        new = call.operation == "adminCreateWord"
        operation = "admin.word.create" if new else "admin.word.revise"
        digest = fingerprint(call, operation, {**call.path, **body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                row = await one(tx, _WORD + " WHERE r.id = %s", (prior,))
                return Result(201, word(row), replayed=True)
            await lock_vocabulary_writes(tx)
            if new:
                entry = await self._create_root(tx, body)
                revision = 1
            else:
                entry = call.path["entry_id"]
                root = await one(
                    tx,
                    "SELECT id FROM app.vocabulary WHERE id = %s FOR UPDATE",
                    (entry,),
                )
                if root is None:
                    raise missing()
                revision = await self._next_revision(
                    tx,
                    "vocabulary_revisions",
                    "entry_id",
                    entry,
                    body["expected_latest_revision"],
                )
            result = await self._create_revision(
                tx, owner, entry, revision, body["content"]
            )
            op = await write_receipt(
                tx, call, operation, digest, result["id"], "vocabulary_revision"
            )
            await self._audit(
                tx, owner, op, operation, "vocabulary", result["id"], None, "draft"
            )
            return Result(
                201, word(await one(tx, _WORD + " WHERE r.id = %s", (result["id"],)))
            )

    @staticmethod
    async def _create_root(tx, body):
        hanzi = clean_text(body["hanzi"])
        reading = "".join(
            clean_text(body["reading_key"])
            .lower()
            .replace("ü", "v")
            .replace("u:", "v")
            .split()
        )
        if re.fullmatch(r"(?:[a-z]+[1-5])+", reading) is None:
            raise invalid_input()
        row = await one(
            tx,
            """INSERT INTO app.vocabulary (id, hanzi, reading_key, sense_id)
            VALUES (%s,%s,%s,%s) ON CONFLICT (hanzi,reading_key,sense_id) DO NOTHING RETURNING id""",
            (uuid4(), hanzi, reading, body.get("sense_id") or uuid4()),
        )
        if row is None:
            raise ApiError(409, "ENTRY_EXISTS", "Từ điển đã có mục này.")
        return row["id"]

    @staticmethod
    async def _next_revision(tx, table, field, key, expected):
        row = await one(
            tx,
            f"SELECT coalesce(max(revision),0) AS latest FROM app.{table} WHERE {field} = %s",
            (key,),
        )
        if row["latest"] != expected:
            raise ApiError(409, "STALE_VERSION", "Đã có bản sửa mới. Hãy tải lại.")
        return expected + 1

    @staticmethod
    async def _create_revision(tx, owner, entry, revision, body):
        content = {
            k: clean_text(body.get(k))
            for k in _WORD_FIELDS
            if k not in {"examples", "hsk_level"}
        }
        content["hsk_level"] = body.get("hsk_level")
        content["examples"] = [
            {k: clean_text(v) for k, v in e.items()} for e in body.get("examples", [])
        ]
        digest = hashlib.sha256(
            json.dumps(content, sort_keys=True).encode()
        ).hexdigest()
        row = await one(
            tx,
            """INSERT INTO app.vocabulary_revisions
          (author_id, entry_id, revision, pinyin_display, vietnamese, hsk_level, part_of_speech, examples,
           source_name, source_external_id, source_version, license, content_hash)
          VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
          ON CONFLICT (entry_id,source_name,source_external_id,source_version) DO NOTHING RETURNING id""",
            (
                owner,
                entry,
                revision,
                *(
                    Jsonb(content[k]) if k == "examples" else content[k]
                    for k in _WORD_FIELDS
                ),
                digest,
            ),
        )
        if row is None:
            raise ApiError(
                409, "SOURCE_VERSION_CONFLICT", "Phiên bản nguồn đã tồn tại."
            )
        return row

    async def tests(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            rows = await many(
                tx, _TEST + " WHERE " + _LATEST_TEST + " ORDER BY t.hsk_level"
            )
            items = [await self._test_dto(tx, row) for row in rows]
        return Result(200, {"items": items})

    async def get_test(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            row = await one(
                tx,
                _TEST + " WHERE t.id = %s AND " + _LATEST_TEST,
                (call.path["test_id"],),
            )
            if row is None:
                raise missing()
            return Result(200, await self._test_dto(tx, row))

    @staticmethod
    async def _test_dto(tx, row):
        questions = await many(
            tx,
            _QUESTION + " WHERE q.test_revision_id = %s ORDER BY q.position",
            (row["id"],),
        )
        return {
            "test_id": str(row["test_id"]),
            "hsk_level": row["hsk_level"],
            "latest": meta(row),
            "content": {
                "duration_seconds": row["duration_seconds"],
                "source": row["source"],
                "license": row["license"],
                "questions": [question_content(q) for q in questions],
            },
        }

    async def revise_test(self, call: Call) -> Result:
        owner, test_id, body = call.identity.user_id, call.path["test_id"], call.body
        operation = "admin.test.revise"
        digest = fingerprint(call, operation, {"test_id": test_id, **body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity, admin=True)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                return Result(
                    201,
                    await self._test_dto(
                        tx, await one(tx, _TEST + " WHERE r.id = %s", (previous,))
                    ),
                    replayed=True,
                )
            root = await one(
                tx, "SELECT id FROM app.tests WHERE id = %s FOR UPDATE", (test_id,)
            )
            if root is None:
                raise missing()
            revision = await self._next_revision(
                tx,
                "test_revisions",
                "test_id",
                test_id,
                body["expected_latest_revision"],
            )
            content = body["content"]
            questions = content["questions"]
            if len({q["position"] for q in questions}) != len(questions):
                raise invalid_input()
            inserted = await one(
                tx,
                """INSERT INTO app.test_revisions (test_id,revision,source,license)
                VALUES (%s,%s,%s,%s) RETURNING id""",
                (
                    test_id,
                    revision,
                    clean_text(content["source"]),
                    clean_text(content["license"]),
                ),
            )
            for q in questions:
                await self._insert_question(tx, inserted["id"], q)
            op = await write_receipt(
                tx, call, operation, digest, inserted["id"], "test_revision"
            )
            await self._audit(
                tx, owner, op, operation, "tests", inserted["id"], None, "draft"
            )
            row = await one(tx, _TEST + " WHERE r.id = %s", (inserted["id"],))
            return Result(201, await self._test_dto(tx, row))

    @staticmethod
    async def _insert_question(tx, revision, q):
        media = q["audio_media_id"]
        if media is None and q["kind"] == "listening":
            raise invalid_input()
        if (
            media is not None
            and await one(
                tx, "SELECT id FROM app.learning_audio WHERE id = %s", (media,)
            )
            is None
        ):
            raise missing()
        if media is not None:
            attachment = await one(
                tx,
                "SELECT state FROM app.admin_media_uploads WHERE id=%s FOR UPDATE",
                (media,),
            )
            if attachment is not None and attachment["state"] != "ready":
                raise missing()
        identifier = uuid4()
        await tx.execute(
            """INSERT INTO app.questions (id,test_revision_id,position,kind,prompt,options,audio_media_id)
                         VALUES (%s,%s,%s,%s,%s,%s,%s)""",
            (
                identifier,
                revision,
                q["position"],
                q["kind"],
                clean_text(q["prompt"]),
                Jsonb([clean_text(o) for o in q["options"]]),
                media,
            ),
        )
        await tx.execute(
            """INSERT INTO app_private.answer_keys (question_id,correct_index,explanation)
                         VALUES (%s,%s,%s)""",
            (identifier, q["correct_index"], clean_text(q["explanation"])),
        )

    async def questions(self, call: Call) -> Result:
        test_id, limit = call.query.get("test_id"), call.query.get("limit", 20)
        scope = json.dumps(["admin-questions", str(call.identity.user_id), test_id])
        date, cursor_id = self.db.read_cursor(scope, call.query.get("cursor"))
        sql = _QUESTION + " WHERE true"
        args = []
        if test_id is not None:
            sql += " AND r.test_id = %s"
            args.append(test_id)
        if date is not None:
            sql += " AND (q.created_at,q.id) < (%s,%s)"
            args.extend((date, cursor_id))
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            rows = await many(
                tx,
                sql + " ORDER BY q.created_at DESC,q.id DESC LIMIT %s",
                (*args, limit + 1),
            )
        after = rows[limit - 1] if len(rows) > limit else None
        return Result(
            200,
            {
                "items": [question_summary(r) for r in rows[:limit]],
                "next_cursor": self.db.cursor(
                    scope, {**after, "id": after["question_id"]}
                )
                if after
                else None,
            },
        )

    async def get_question(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            row = await one(
                tx, _QUESTION + " WHERE q.id = %s", (call.path["question_id"],)
            )
        if row is None:
            raise missing()
        return Result(
            200,
            {k: str(row[k]) for k in ("question_id", "test_id", "test_revision_id")}
            | {"content": question_content(row)},
        )

    async def scenarios(self, call: Call) -> Result:
        admin = call.operation in {"adminListScenarios", "adminGetScenario"}
        key = call.path.get("scenario_id")
        sql = """SELECT s.id AS scenario_id, s.title, r.* FROM app.scenarios s
                 JOIN app.scenario_revisions r ON r.scenario_id = s.id WHERE """
        sql += (
            "r.revision = (SELECT max(x.revision) FROM app.scenario_revisions x WHERE x.scenario_id = s.id)"
            if admin
            else "r.id = s.published_revision_id AND r.status = 'published'"
        )
        args = ()
        if key is not None:
            sql += " AND s.id = %s"
            args = (key,)
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=admin)
            rows = await many(tx, sql + " ORDER BY s.id", args)
        items = [self._scenario_dto(r, admin) for r in rows]
        if key is not None:
            if not items:
                raise missing()
            return Result(200, items[0])
        return Result(200, {"items": items})

    @staticmethod
    def _scenario_dto(row, admin):
        content = row["content"]
        if admin:
            return {
                "scenario_id": row["scenario_id"],
                "latest": meta(row),
                "content": content,
            }
        return {
            "id": row["scenario_id"],
            "revision_id": str(row["id"]),
            "title": row["title"],
            "max_turns": 8,
            **{k: content[k] for k in ("learner_role", "ai_role", "goal", "opening")},
        }

    async def revise_scenario(self, call: Call) -> Result:
        owner, key, body = call.identity.user_id, call.path["scenario_id"], call.body
        operation = "admin.scenario.revise"
        digest = fingerprint(call, operation, {"scenario_id": key, **body})
        content = {
            k: clean_text(v) if isinstance(v, str) else v
            for k, v in body["content"].items()
        }
        content["opening"] = {k: clean_text(v) for k, v in content["opening"].items()}
        words = {UUID(word_id) for word_id in content["vocabulary_entry_ids"]}
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity, admin=True)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                row = await one(
                    tx,
                    "SELECT * FROM app.scenario_revisions WHERE id = %s",
                    (previous,),
                )
                return Result(201, self._scenario_dto(row, True), replayed=True)
            if (
                await one(
                    tx, "SELECT id FROM app.scenarios WHERE id = %s FOR UPDATE", (key,)
                )
                is None
            ):
                raise missing()
            if words:
                found = await one(
                    tx,
                    "SELECT count(*) AS n FROM app.vocabulary WHERE id = ANY(%s)",
                    (list(words),),
                )
                if found["n"] != len(words):
                    raise missing()
            revision = await self._next_revision(
                tx,
                "scenario_revisions",
                "scenario_id",
                key,
                body["expected_latest_revision"],
            )
            row = await one(
                tx,
                """INSERT INTO app.scenario_revisions (scenario_id,revision,content)
                VALUES (%s,%s,%s) RETURNING *""",
                (key, revision, Jsonb(content)),
            )
            op = await write_receipt(
                tx, call, operation, digest, row["id"], "scenario_revision"
            )
            await self._audit(
                tx, owner, op, operation, "scenarios", row["id"], None, "draft"
            )
            return Result(201, self._scenario_dto(row, True))

    async def transition(self, call: Call) -> Result:
        owner, kind, revision = (
            call.identity.user_id,
            call.path["content_kind"],
            call.path["revision_id"],
        )
        vocabulary = kind == "vocabulary"
        table, root_field, resource = {
            "vocabulary": ("vocabulary_revisions", "entry_id", "vocabulary_revision"),
            "tests": ("test_revisions", "test_id", "test_revision"),
            "scenarios": ("scenario_revisions", "scenario_id", "scenario_revision"),
        }[kind]
        operation = "content.transition"
        digest = fingerprint(call, operation, {**call.path, **call.body})
        target = call.body["target_status"]
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            row = await one(tx, f"SELECT * FROM app.{table} WHERE id = %s", (revision,))
            if row is None:
                raise missing()
            if prior is not None:
                return Result(200, meta(row), replayed=True)
            key = row[root_field]
            await tx.execute(
                f"SELECT id FROM app.{kind} WHERE id = %s FOR UPDATE", (key,)
            )
            row = await one(
                tx, f"SELECT * FROM app.{table} WHERE id = %s FOR UPDATE", (revision,)
            )
            before = row["status"]
            if before != target:
                if before != call.body["expected_status"]:
                    raise ApiError(409, "STALE_VERSION", "Trạng thái đã thay đổi.")
                if (before, target) not in _TRANSITIONS:
                    raise ApiError(
                        409, "INVALID_STATE", "Không thể chuyển sang trạng thái này."
                    )
                row = await self._transition_row(
                    tx, owner, kind, table, vocabulary, row, key, target
                )
            op = await write_receipt(tx, call, operation, digest, row["id"], resource)
            if before != target:
                await self._audit(
                    tx,
                    owner,
                    op,
                    operation,
                    kind,
                    row["id"],
                    before,
                    target,
                    clean_text(call.body.get("reason")),
                )
            return Result(200, meta(row))

    @staticmethod
    async def _transition_row(tx, owner, kind, table, vocabulary, row, key, target):
        if target == "published":
            reviewed = ", reviewed_at = clock_timestamp()" if vocabulary else ""
            updated = await one(
                tx,
                f"""UPDATE app.{table} SET status = %s, reviewer_id = %s,
              published_at = clock_timestamp(){reviewed} WHERE id = %s RETURNING *""",
                (target, owner, row["id"]),
            )
            if kind == "tests":
                ready = await one(
                    tx,
                    "SELECT app_private.exam_package_ready(%s) AS ready",
                    (row["id"],),
                )
                if not ready["ready"]:
                    raise ApiError(
                        409,
                        "INVALID_STATE",
                        "Đề cần đủ 10 câu nghe và 10 câu đọc hoàn chỉnh.",
                    )
            await tx.execute(
                f"UPDATE app.{kind} SET published_revision_id = %s WHERE id = %s",
                (row["id"], key),
            )
        else:
            updated = await one(
                tx,
                f"UPDATE app.{table} SET status = %s WHERE id = %s RETURNING *",
                (target, row["id"]),
            )
            if target == "withdrawn":
                await tx.execute(
                    f"UPDATE app.{kind} SET published_revision_id = NULL WHERE id = %s AND published_revision_id = %s",
                    (key, row["id"]),
                )
        return updated

    @staticmethod
    async def _audit(
        tx, owner, operation, action, kind, target, before, after, reason=None
    ):
        await tx.execute(
            """INSERT INTO app_private.admin_audit_logs
            (admin_id, operation_id, action, target_kind, target_id, state_before, state_after, reason)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
            (owner, operation, action, kind, target, before, after, reason),
        )
