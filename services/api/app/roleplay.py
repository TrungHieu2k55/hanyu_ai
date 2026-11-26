from uuid import uuid4

from psycopg.types.json import Jsonb

from .accounts import Accounts, fingerprint
from .errors import ApiError
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .vocabulary import check_version, clean_text, missing

_SESSION = (
    "id, scenario_snapshot, hsk_level, status, completed_turns, version, created_at"
)
_DRAFT = "id, session_id, raw_transcript, manual_text, confirmed_text, status, version"


def session_summary(row):
    return {
        "id": str(row["id"]),
        "hsk_level": row["hsk_level"],
        "status": row["status"],
        "completed_turns": row["completed_turns"],
        "version": row["version"],
        "created_at": row["created_at"].isoformat(),
    }


def draft_dto(row):
    return {
        "id": str(row["id"]),
        "session_id": str(row["session_id"]),
        "raw_transcript": row["raw_transcript"],
        "confirmed_text": row["confirmed_text"] or row["manual_text"],
        "status": row["status"],
        "version": row["version"],
    }


class Roleplay:
    def __init__(self, db: Database, accounts: Accounts):
        self.db = db
        self.accounts = accounts

    @staticmethod
    async def _session(tx, owner, session, *, replay=False):
        row = await one(
            tx,
            f"SELECT {_SESSION} FROM app.roleplay_sessions WHERE owner_id=%s AND id=%s",
            (owner, session),
        )
        if row is None:
            if replay:
                raise ApiError(410, "RESOURCE_GONE", "Phiên đã được xóa.")
            raise missing()
        return row

    @staticmethod
    async def _draft(tx, owner, session, draft, *, replay=False):
        row = await one(
            tx,
            f"""SELECT {_DRAFT} FROM app.transcription_drafts
                WHERE owner_id=%s AND session_id=%s AND id=%s""",
            (owner, session, draft),
        )
        if row is None:
            if replay:
                raise ApiError(410, "RESOURCE_GONE", "Bản nháp đã được xóa.")
            raise missing()
        return row

    @staticmethod
    async def _view(tx, owner, row):
        turns = await many(
            tx,
            """SELECT id,session_id,turn_number,transcript,reply_hanzi,reply_pinyin,reply_vietnamese,
             feedback,text_version,audio_media_id FROM app.roleplay_turns
             WHERE owner_id=%s AND session_id=%s ORDER BY turn_number""",
            (owner, row["id"]),
        )
        active = await one(
            tx,
            """SELECT id FROM app.ai_jobs WHERE owner_id=%s AND session_id=%s
                  AND ((status='queued' AND queue_deadline>clock_timestamp())
                    OR (status='processing' AND processing_deadline>clock_timestamp()))""",
            (owner, row["id"]),
        )
        items = [
            {
                **turn,
                "id": str(turn["id"]),
                "session_id": str(turn["session_id"]),
                "audio_media_id": str(turn["audio_media_id"])
                if turn["audio_media_id"]
                else None,
                "content_score": None,
                "scoring_version": None,
            }
            for turn in turns
        ]
        return {
            **session_summary(row),
            "scenario": row["scenario_snapshot"],
            "active_job_id": str(active["id"]) if active else None,
            "turns": items,
        }

    async def start(self, call: Call) -> Result:
        owner, body = call.identity.user_id, call.body
        operation = "roleplay.start"
        digest = fingerprint(call, operation, body)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(
                    201,
                    await self._view(
                        tx, owner, await self._session(tx, owner, prior, replay=True)
                    ),
                    replayed=True,
                )
            scenario = await one(
                tx,
                """SELECT s.id, s.title, r.id AS revision_id, r.content
                FROM app.scenarios s JOIN app.scenario_revisions r ON r.id=s.published_revision_id
                WHERE s.id=%s AND r.status='published'""",
                (body["scenario_id"],),
            )
            if scenario is None:
                raise missing()
            snapshot = {
                "id": scenario["id"],
                "title": scenario["title"],
                "revision_id": str(scenario["revision_id"]),
                "max_turns": 8,
                **{
                    k: scenario["content"][k]
                    for k in ("learner_role", "ai_role", "goal", "opening")
                },
            }
            session = uuid4()
            op_id = await write_receipt(
                tx, call, operation, digest, session, "roleplay_session"
            )
            row = await one(
                tx,
                f"""INSERT INTO app.roleplay_sessions
                (id,owner_id,operation_id,scenario_revision_id,scenario_snapshot,hsk_level)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING {_SESSION}""",
                (
                    session,
                    owner,
                    op_id,
                    scenario["revision_id"],
                    Jsonb(snapshot),
                    body["hsk_level"],
                ),
            )
            return Result(201, await self._view(tx, owner, row))

    async def get(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await self._session(
                tx, call.identity.user_id, call.path["session_id"]
            )
            return Result(200, await self._view(tx, call.identity.user_id, row))

    async def list(self, call: Call) -> Result:
        owner, limit = call.identity.user_id, call.query.get("limit", 20)
        scope = f"roleplay:{owner}"
        date, cursor_id = self.db.read_cursor(scope, call.query.get("cursor"))
        sql = f"SELECT {_SESSION} FROM app.roleplay_sessions WHERE owner_id=%s"
        args = [owner]
        if date is not None:
            sql += " AND (created_at,id) < (%s,%s)"
            args.extend((date, cursor_id))
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(
                tx,
                sql + " ORDER BY created_at DESC,id DESC LIMIT %s",
                (*args, limit + 1),
            )
        return Result(
            200,
            {
                "items": [
                    {
                        **session_summary(r),
                        "scenario_id": r["scenario_snapshot"]["id"],
                        "title": r["scenario_snapshot"]["title"],
                    }
                    for r in rows[:limit]
                ],
                "next_cursor": self.db.cursor(scope, rows[limit - 1])
                if len(rows) > limit
                else None,
            },
        )

    async def end_or_delete(self, call: Call) -> Result:
        owner, session = call.identity.user_id, call.path["session_id"]
        delete = call.operation == "deleteRoleplay"
        operation = "roleplay.delete" if delete else "roleplay.end"
        params = call.query if delete else call.body
        digest = fingerprint(call, operation, {"session_id": session, **params})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                if delete:
                    return Result(204, replayed=True)
                return Result(
                    200,
                    await self._view(
                        tx, owner, await self._session(tx, owner, prior, replay=True)
                    ),
                    replayed=True,
                )
            row = await self._session(tx, owner, session)
            check_version(row, params["expected_version"])
            if delete or row["status"] == "active":
                await tx.execute(
                    """UPDATE app.ai_jobs SET status='canceled',completed_at=clock_timestamp(),
                    lease_token=NULL,locked_until=NULL WHERE owner_id=%s AND session_id=%s
                    AND status IN ('queued','processing')""",
                    (owner, session),
                )
            if delete:
                await tx.execute(
                    """UPDATE app.media_assets SET state='delete_pending',expires_at=clock_timestamp(),
                    version=version+1 WHERE owner_id=%s AND state NOT IN ('deleted','delete_pending') AND id IN (
                    SELECT audio_media_id FROM app.transcription_drafts WHERE owner_id=%s AND session_id=%s
                    UNION SELECT audio_media_id FROM app.roleplay_turns WHERE owner_id=%s AND session_id=%s
                    )""",
                    (owner, owner, session, owner, session),
                )
                await tx.execute(
                    """DELETE FROM app.activity_events WHERE owner_id=%s AND turn_id IN
                    (SELECT id FROM app.roleplay_turns WHERE owner_id=%s AND session_id=%s)""",
                    (owner, owner, session),
                )
                await tx.execute(
                    "DELETE FROM app.ai_jobs WHERE owner_id=%s AND session_id=%s",
                    (owner, session),
                )
                await tx.execute(
                    "DELETE FROM app.roleplay_turns WHERE owner_id=%s AND session_id=%s",
                    (owner, session),
                )
                await tx.execute(
                    "DELETE FROM app.transcription_drafts WHERE owner_id=%s AND session_id=%s",
                    (owner, session),
                )
                await tx.execute(
                    "DELETE FROM app.roleplay_sessions WHERE owner_id=%s AND id=%s",
                    (owner, session),
                )
            elif row["status"] == "active":
                await tx.execute(
                    """UPDATE app.transcription_drafts SET status='discarded',version=version+1
                    WHERE owner_id=%s AND session_id=%s AND status IN ('draft','confirmed')""",
                    (owner, session),
                )
                row = await one(
                    tx,
                    f"""UPDATE app.roleplay_sessions SET status='ended',ended_at=clock_timestamp(),
                    version=version+1 WHERE owner_id=%s AND id=%s RETURNING {_SESSION}""",
                    (owner, session),
                )
            await write_receipt(
                tx, call, operation, digest, row["id"], "roleplay_session"
            )
            return (
                Result(204) if delete else Result(200, await self._view(tx, owner, row))
            )

    async def draft(self, call: Call) -> Result:
        owner, session = call.identity.user_id, call.path["session_id"]
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await self._draft(tx, owner, session, call.path["draft_id"])
        return Result(200, draft_dto(row))

    async def write_draft(self, call: Call) -> Result:
        owner, session = call.identity.user_id, call.path["session_id"]
        create = call.operation == "createTextDraft"
        operation = "roleplay.text_draft" if create else "roleplay.confirm"
        body = {**call.body, "text": clean_text(call.body["text"])}
        digest = fingerprint(call, operation, {**call.path, **body})
        status = 201 if create else 200
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(
                    status,
                    draft_dto(
                        await self._draft(tx, owner, session, prior, replay=True)
                    ),
                    replayed=True,
                )
            row = await self._session(tx, owner, session)
            if row["status"] != "active":
                raise ApiError(409, "INVALID_STATE", "Phiên hội thoại đã kết thúc.")
            if create:
                identifier = uuid4()
                op_id = await write_receipt(
                    tx, call, operation, digest, identifier, "transcription_draft"
                )
                draft = await one(
                    tx,
                    f"""INSERT INTO app.transcription_drafts
                    (id, owner_id, session_id, operation_id, manual_text)
                    VALUES (%s,%s,%s,%s,%s) RETURNING {_DRAFT}""",
                    (identifier, owner, session, op_id, body["text"]),
                )
            else:
                draft = await self._draft(tx, owner, session, call.path["draft_id"])
                if draft["status"] not in {"draft", "confirmed"}:
                    raise ApiError(409, "INVALID_STATE", "Bản nháp không còn sửa được.")
                in_flight = await one(
                    tx,
                    """SELECT id FROM app.ai_jobs WHERE owner_id=%s AND draft_id=%s
                     AND ((status='queued' AND queue_deadline>clock_timestamp())
                     OR (status='processing' AND processing_deadline>clock_timestamp()))""",
                    (owner, draft["id"]),
                )
                if in_flight is not None:
                    raise ApiError(
                        409, "TURN_IN_PROGRESS", "Phiên đang xử lý bản nháp."
                    )
                check_version(draft, body["expected_version"])
                draft = await one(
                    tx,
                    f"""UPDATE app.transcription_drafts SET confirmed_text=%s,status='confirmed',
                   confirmed_at=clock_timestamp(),version=version+1 WHERE owner_id=%s AND session_id=%s AND id=%s
                   RETURNING {_DRAFT}""",
                    (body["text"], owner, session, draft["id"]),
                )
                await write_receipt(
                    tx, call, operation, digest, draft["id"], "transcription_draft"
                )
            return Result(status, draft_dto(draft))
