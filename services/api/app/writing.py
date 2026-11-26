from datetime import timedelta
from uuid import uuid4

from .accounts import Accounts, fingerprint
from .cnn import HandwritingCnn
from .errors import invalid_input, unavailable
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .reviews import server_time
from .storage import ImageStorage
from .vocabulary import missing

_STROKES = """
SELECT c.id, c.hanzi, c.created_at, r.id AS revision_id, r.stroke_count,
       r.object_key, r.source, r.license
FROM app.characters c JOIN app.character_revisions r ON r.id = c.published_revision_id
WHERE r.status = 'published'
"""
_QUIZ_FIELDS = "id, status, score, formula_version, required_strokes, completed_strokes"


def quiz_dto(row):
    return {**row, "id": str(row["id"])}


class Writing:
    def __init__(
        self,
        db: Database,
        accounts: Accounts,
        storage: ImageStorage | None,
        cnn: HandwritingCnn,
    ):
        self.db = db
        self.accounts = accounts
        self.storage = storage
        self.cnn = cnn

    async def characters(self, call: Call) -> Result:
        mode, limit = call.query.get("mode"), call.query.get("limit", 20)
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            version = await self.cnn.published(tx)
            model_id = version["id"] if version else None
            scope = f"characters:{call.identity.user_id}:{mode}:{model_id}"
            date, cursor_id = self.db.read_cursor(scope, call.query.get("cursor"))
            sql = """SELECT c.id,c.hanzi,c.created_at,r.id AS revision_id,r.stroke_count,
                            m.character_id IS NOT NULL AS supports_cnn
                     FROM app.characters c
                     LEFT JOIN app.character_revisions r ON r.id=c.published_revision_id AND r.status='published'
                     LEFT JOIN app.model_classes m ON m.model_id=%s AND m.character_id=c.id"""
            where = {
                "cnn": "m.character_id IS NOT NULL",
                "strokes": "r.id IS NOT NULL",
            }.get(mode, "(r.id IS NOT NULL OR m.character_id IS NOT NULL)")
            args = [model_id]
            if date is not None:
                where += " AND (c.created_at,c.id) < (%s,%s)"
                args.extend((date, cursor_id))
            rows = await many(
                tx,
                sql
                + " WHERE "
                + where
                + " ORDER BY c.created_at DESC,c.id DESC LIMIT %s",
                (*args, limit + 1),
            )
        items = [
            {
                "id": str(r["id"]),
                "hanzi": r["hanzi"],
                "revision_id": str(r["revision_id"]) if r["revision_id"] else None,
                "stroke_count": r["stroke_count"],
                "supports_strokes": r["revision_id"] is not None,
                "supports_cnn": r["supports_cnn"],
                "model_version": version["model_version"]
                if r["supports_cnn"]
                else None,
            }
            for r in rows[:limit]
        ]
        return Result(
            200,
            {
                "items": items,
                "next_cursor": self.db.cursor(scope, rows[limit - 1])
                if len(rows) > limit
                else None,
            },
        )

    async def strokes(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await one(
                tx, _STROKES + " AND c.id = %s", (call.path["character_id"],)
            )
            now = await server_time(tx)
        if row is None:
            raise missing()
        if self.storage is None:
            raise unavailable(
                "CONTENT_UNAVAILABLE", "Kho dữ liệu nét chưa được cấu hình."
            )
        url = await self.storage.sign(row["object_key"], 300)
        return Result(
            200,
            {
                "character_id": str(row["id"]),
                "revision_id": str(row["revision_id"]),
                "stroke_count": row["stroke_count"],
                "asset_url": url,
                "expires_at": (now + timedelta(seconds=300)).isoformat(),
                "source": row["source"],
                "license": row["license"],
            },
        )

    async def quiz(self, call: Call) -> Result:
        owner, body = call.identity.user_id, call.body
        operation = "writing.quiz"
        digest = fingerprint(call, operation, body)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                row = await one(
                    tx,
                    f"SELECT {_QUIZ_FIELDS} FROM app.quiz_attempts WHERE owner_id=%s AND id=%s",
                    (owner, previous),
                )
                return Result(201, quiz_dto(row), replayed=True)
            revision = await one(
                tx, _STROKES + " AND r.id=%s", (body["character_revision_id"],)
            )
            if revision is None:
                raise missing()
            required, completed = revision["stroke_count"], body["completed_strokes"]
            if completed > required:
                raise invalid_input()
            is_complete = required == completed
            status = "completed" if is_complete else "in_progress"
            # A final score is only available at full completion, where C/S is exactly 1.
            score = (
                max(0, 100 - 5 * body["mistakes"] - 10 * body["hints"])
                if is_complete
                else None
            )
            identifier = uuid4()
            op_id = await write_receipt(
                tx, call, operation, digest, identifier, "quiz_attempt"
            )
            row = await one(
                tx,
                f"""INSERT INTO app.quiz_attempts
                (id,owner_id,operation_id,character_revision_id,required_strokes,completed_strokes,
                 mistakes,hints,duration_ms,status,score)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING {_QUIZ_FIELDS}""",
                (
                    identifier,
                    owner,
                    op_id,
                    revision["revision_id"],
                    required,
                    completed,
                    body["mistakes"],
                    body["hints"],
                    body["duration_ms"],
                    status,
                    score,
                ),
            )
            if is_complete:
                await tx.execute(
                    """INSERT INTO app.activity_events (owner_id,quiz_attempt_id,occurred_at)
                    VALUES (%s,%s,clock_timestamp())""",
                    (owner, identifier),
                )
            return Result(201, quiz_dto(row))
