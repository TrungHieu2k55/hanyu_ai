from uuid import uuid4

from psycopg.types.json import Jsonb

from .accounts import Accounts, fingerprint
from .errors import ApiError
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .sm2 import next_schedule, schedule_dto
from .vocabulary import Vocabulary, check_version, missing

_CARD = """
SELECT id, item_id, position, state, content_snapshot, revealed_at, schedule_version, session_id
FROM app.review_session_items WHERE owner_id = %s
"""
_OPEN = {"active", "paused"}
_SNAPSHOT_FIELDS = ("hanzi", "pinyin", "vietnamese", "note")


def card_dto(row: dict) -> dict:
    return {
        "session_item_id": str(row["id"]),
        "item_id": str(row["item_id"]),
        "position": row["position"],
        "state": row["state"],
        **{field: row["content_snapshot"][field] for field in _SNAPSHOT_FIELDS},
        "revealed_at": row["revealed_at"].isoformat() if row["revealed_at"] else None,
        "schedule_version": row["schedule_version"],
    }


def closed() -> ApiError:
    return ApiError(
        409, "INVALID_STATE", "Phiên ôn hoặc thẻ không còn ở trạng thái đang ôn."
    )


def stale() -> ApiError:
    return ApiError(409, "STALE_REVIEW", "Lịch ôn đã thay đổi. Hãy tải lại phiên.")


async def server_time(tx):
    return (await one(tx, "SELECT clock_timestamp() AS now"))["now"]


class Reviews:
    def __init__(self, db: Database, accounts: Accounts, vocabulary: Vocabulary):
        self.db = db
        self.accounts = accounts
        self.vocabulary = vocabulary

    @staticmethod
    async def _session(tx, owner, session):
        row = await one(
            tx,
            "SELECT id, status, version FROM app.review_sessions WHERE owner_id = %s AND id = %s",
            (owner, session),
        )
        if row is None:
            raise missing()
        return row

    @staticmethod
    async def _card(tx, owner, card):
        row = await one(tx, _CARD + " AND id = %s", (owner, card))
        if row is None:
            raise missing()
        return row

    async def _view(self, tx, owner, session):
        cards = await many(
            tx,
            """SELECT c.*, s.version AS session_version, s.status AS session_status
                   FROM app.review_sessions s JOIN app.review_session_items c
                     ON c.session_id = s.id AND c.owner_id = s.owner_id
                   WHERE s.owner_id = %s AND s.id = %s ORDER BY c.position""",
            (owner, session),
        )
        if not cards:
            raise missing()
        return {
            "id": str(cards[0]["session_id"]),
            "version": cards[0]["session_version"],
            "status": cards[0]["session_status"],
            "total": len(cards),
            "reviewed_count": sum(c["state"] == "reviewed" for c in cards),
            "skipped_count": sum(c["state"] == "skipped" for c in cards),
            "cards": [card_dto(card) for card in cards],
        }

    async def get(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            return Result(
                200,
                await self._view(tx, call.identity.user_id, call.path["session_id"]),
            )

    async def start(self, call: Call) -> Result:
        owner = call.identity.user_id
        limit = call.body.get("limit", 20)
        operation = "review.start"
        payload = fingerprint(call, operation, {"limit": limit})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, payload)
            if prior is not None:
                return Result(200, await self._view(tx, owner, prior), replayed=True)
            existing = await one(
                tx,
                "SELECT id, status FROM app.review_sessions WHERE owner_id = %s AND status IN ('active', 'paused')",
                (owner,),
            )
            now = await server_time(tx)
            if existing is not None:
                session = existing["id"]
                if existing["status"] == "active":
                    await self._refresh_pending(tx, owner, session, now, "active")
                await write_receipt(
                    tx, call, operation, payload, session, "review_session"
                )
                return Result(200, await self._view(tx, owner, session))
            due = await self.vocabulary.due_rows(tx, owner, now, limit)
            if not due:
                raise ApiError(409, "NO_DUE_CARDS", "Không có thẻ đến hạn.")
            row = await one(
                tx,
                "INSERT INTO app.review_sessions (owner_id) VALUES (%s) RETURNING id",
                (owner,),
            )
            session = row["id"]
            cards = [
                {
                    "item_id": str(item["id"]),
                    "position": position,
                    "content_snapshot": {k: item[k] for k in _SNAPSHOT_FIELDS},
                    "schedule_version": item["schedule_version"],
                }
                for position, item in enumerate(due, 1)
            ]
            await tx.execute(
                """INSERT INTO app.review_session_items
                       (owner_id, session_id, item_id, position, content_snapshot, schedule_version)
                   SELECT %s, %s, x.item_id, x.position, x.content_snapshot, x.schedule_version
                   FROM jsonb_to_recordset(%s) AS x
                       (item_id uuid, position smallint, content_snapshot jsonb, schedule_version bigint)""",
                (owner, session, Jsonb(cards)),
            )
            await write_receipt(tx, call, operation, payload, session, "review_session")
            return Result(201, await self._view(tx, owner, session))

    @staticmethod
    async def _advance(tx, owner, session, status):
        await tx.execute(
            """UPDATE app.review_sessions SET status = %s, version = version + 1,
                   ended_at = CASE WHEN %s IN ('completed', 'abandoned') THEN clock_timestamp() ELSE NULL END
               WHERE owner_id = %s AND id = %s""",
            (status, status, owner, session),
        )

    async def _refresh_pending(self, tx, owner, session, now, current_status):
        changed = await tx.execute(
            """UPDATE app.review_session_items c SET state = 'skipped'
               WHERE c.owner_id = %s AND c.session_id = %s AND c.state = 'pending'
                 AND NOT EXISTS (
                   SELECT 1 FROM app.learning_items i JOIN app.review_schedules s
                     ON s.item_id = i.id AND s.owner_id = i.owner_id
                   WHERE i.owner_id = c.owner_id AND i.id = c.item_id AND i.status = 'active'
                     AND s.archived_at IS NULL AND s.due_at <= %s AND s.version = c.schedule_version
                 )""",
            (owner, session, now),
        )
        status = await self._completion_status(tx, owner, session)
        if changed.rowcount or current_status != status:
            await self._advance(tx, owner, session, status)

    @staticmethod
    async def _completion_status(tx, owner, session):
        pending = await one(
            tx,
            "SELECT 1 FROM app.review_session_items WHERE owner_id = %s AND session_id = %s AND state = 'pending' LIMIT 1",
            (owner, session),
        )
        return "active" if pending is not None else "completed"

    async def state(self, call: Call) -> Result:
        owner, session = call.identity.user_id, call.path["session_id"]
        operation = "review.state"
        payload = fingerprint(call, operation, {"session_id": session, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, payload)
            if prior is not None:
                return Result(200, await self._view(tx, owner, prior), replayed=True)
            row = await self._session(tx, owner, session)
            check_version(row, call.body["expected_version"])
            target = call.body["status"]
            if row["status"] not in _OPEN and row["status"] != target:
                raise closed()
            if target == "active":
                await self._refresh_pending(
                    tx, owner, session, await server_time(tx), row["status"]
                )
            elif row["status"] != target:
                await self._advance(tx, owner, session, target)
            await write_receipt(
                tx, call, operation, payload, row["id"], "review_session"
            )
            return Result(200, await self._view(tx, owner, session))

    @staticmethod
    async def _schedule(tx, owner, item_id):
        return await one(
            tx,
            """SELECT s.*, i.status AS item_status FROM app.review_schedules s
                   JOIN app.learning_items i ON i.id = s.item_id AND i.owner_id = s.owner_id
                   WHERE s.owner_id = %s AND s.item_id = %s""",
            (owner, item_id),
        )

    @staticmethod
    def _check_schedule(schedule, card, now):
        if (
            schedule is None
            or schedule["item_status"] != "active"
            or schedule["archived_at"] is not None
            or schedule["due_at"] > now
            or schedule["version"] != card["schedule_version"]
        ):
            raise stale()

    async def reveal(self, call: Call) -> Result:
        owner, card = call.identity.user_id, call.path["session_item_id"]
        operation = "review.reveal"
        payload = fingerprint(call, operation, {"session_item_id": card})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, payload)
            if prior is not None:
                return Result(
                    200, card_dto(await self._card(tx, owner, prior)), replayed=True
                )
            row = await self._card(tx, owner, card)
            session = await self._session(tx, owner, row["session_id"])
            if session["status"] != "active" or row["state"] != "pending":
                raise closed()
            now = await server_time(tx)
            schedule = await self._schedule(tx, owner, row["item_id"])
            self._check_schedule(schedule, row, now)
            if row["revealed_at"] is None:
                await tx.execute(
                    "UPDATE app.review_session_items SET revealed_at = %s WHERE owner_id = %s AND id = %s",
                    (now, owner, card),
                )
                await self._advance(tx, owner, session["id"], "active")
                row["revealed_at"] = now
            await write_receipt(
                tx, call, operation, payload, row["id"], "review_session_item"
            )
            return Result(200, card_dto(row))

    async def _rating_result(self, tx, owner, event_id):
        event = await one(
            tx,
            """SELECT e.session_item_id, e.after_state, c.session_id FROM app.review_events e
               JOIN app.review_session_items c ON c.id = e.session_item_id
                   AND c.item_id = e.item_id AND c.owner_id = e.owner_id
               WHERE e.owner_id = %s AND e.id = %s""",
            (owner, event_id),
        )
        if event is None:
            raise ApiError(410, "RESOURCE_GONE", "Lượt ôn không còn khả dụng.")
        return {
            "event_id": str(event_id),
            "session_item_id": str(event["session_item_id"]),
            "schedule": event["after_state"],
            "session": await self._view(tx, owner, event["session_id"]),
        }

    async def rate(self, call: Call) -> Result:
        owner, card = call.identity.user_id, call.path["session_item_id"]
        operation = "review.rate"
        payload = fingerprint(call, operation, {"session_item_id": card, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, payload)
            if prior is not None:
                return Result(
                    201, await self._rating_result(tx, owner, prior), replayed=True
                )
            row = await self._card(tx, owner, card)
            session = await self._session(tx, owner, row["session_id"])
            if row["state"] == "reviewed":
                raise stale()
            if session["status"] != "active" or row["state"] != "pending":
                raise closed()
            if row["revealed_at"] is None:
                raise ApiError(409, "INVALID_STATE", "Hãy lật thẻ trước khi đánh giá.")
            if call.body["expected_schedule_version"] != row["schedule_version"]:
                raise stale()
            schedule = await self._schedule(tx, owner, row["item_id"])
            now = await server_time(tx)
            self._check_schedule(schedule, row, now)
            event = await self._commit_rating(
                tx, call, owner, row, schedule, now, operation, payload
            )
            return Result(201, await self._rating_result(tx, owner, event))

    async def _commit_rating(
        self, tx, call, owner, card, schedule, now, operation, payload
    ):
        quality = call.body["quality"]
        updated = next_schedule(schedule, quality, now)
        item = card["item_id"]
        event = uuid4()
        operation_id = await write_receipt(
            tx, call, operation, payload, event, "review_event"
        )
        await tx.execute(
            """INSERT INTO app.review_events (id, owner_id, item_id, session_item_id, operation_id, quality,
                                               before_state, after_state, accepted_at)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (
                event,
                owner,
                item,
                card["id"],
                operation_id,
                quality,
                Jsonb(schedule_dto(schedule)),
                Jsonb(schedule_dto(updated)),
                now,
            ),
        )
        await tx.execute(
            """UPDATE app.review_schedules SET ease_factor = %s, interval_days = %s, repetitions = %s,
                        due_at = %s, last_quality = %s, version = %s WHERE owner_id = %s AND item_id = %s""",
            (
                updated["ease_factor"],
                updated["interval_days"],
                updated["repetitions"],
                updated["due_at"],
                quality,
                updated["version"],
                owner,
                item,
            ),
        )
        await tx.execute(
            "UPDATE app.learning_items SET version = version + 1 WHERE owner_id = %s AND id = %s",
            (owner, item),
        )
        await tx.execute(
            "UPDATE app.review_session_items SET state = 'reviewed' WHERE owner_id = %s AND id = %s",
            (owner, card["id"]),
        )
        await tx.execute(
            "INSERT INTO app.activity_events (owner_id, review_event_id, occurred_at) VALUES (%s, %s, %s)",
            (owner, event, now),
        )
        status = await self._completion_status(tx, owner, card["session_id"])
        await self._advance(tx, owner, card["session_id"], status)
        return event
