from datetime import UTC, datetime, time, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .errors import ApiError, invalid_input
from .operations import lock_owner
from .ports import Call, Result
from .postgres import many, one
from .vocabulary import clean_text, missing

STUDY_ZONE = ZoneInfo("Asia/Ho_Chi_Minh")


def next_reminder(now: datetime, zone: ZoneInfo, at: time, days: list[int]):
    first_day = now.astimezone(zone).date()
    for offset in range(15):
        day = first_day + timedelta(days=offset)
        if day.isoweekday() not in days:
            continue
        local = datetime.combine(day, at)
        instant = local.replace(tzinfo=zone).astimezone(UTC)
        if instant.astimezone(zone).replace(tzinfo=None) == local and instant > now:
            return instant
    return None


def deck_dto(row):
    return {"id": str(row["id"]), "name": row["name"]}


class StudyTools:
    def __init__(self, db, accounts):
        self.db, self.accounts = db, accounts

    @staticmethod
    async def _deck(tx, owner, deck):
        row = await one(
            tx,
            "SELECT id,name FROM app.study_decks WHERE owner_id=%s AND id=%s",
            (owner, deck),
        )
        if row is None:
            raise missing()
        return row

    async def list_decks(self, call: Call) -> Result:
        owner = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(
                tx,
                "SELECT id,name FROM app.study_decks WHERE owner_id=%s ORDER BY created_at,id",
                (owner,),
            )
        return Result(200, {"items": [deck_dto(row) for row in rows]})

    async def get_deck(self, call: Call) -> Result:
        owner, deck = call.identity.user_id, call.path["deck_id"]
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await self._deck(tx, owner, deck)
            items = await many(
                tx,
                """SELECT i.id,i.status,i.merged_into_id FROM app.study_deck_items d
                JOIN app.learning_items i ON i.id=d.item_id AND i.owner_id=d.owner_id
                WHERE d.owner_id=%s AND d.deck_id=%s ORDER BY d.created_at,i.id""",
                (owner, deck),
            )
        return Result(
            200,
            {
                **deck_dto(row),
                "items": [
                    {
                        "item_id": str(item["id"]),
                        "status": item["status"],
                        "merged_into_id": str(item["merged_into_id"])
                        if item["merged_into_id"]
                        else None,
                    }
                    for item in items
                ],
            },
        )

    async def put_deck(self, call: Call) -> Result:
        owner, deck = call.identity.user_id, call.path["deck_id"]
        name = clean_text(call.body["name"])
        if name is None:
            raise invalid_input()
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            row = await one(
                tx,
                "SELECT id FROM app.study_decks WHERE owner_id=%s AND id=%s",
                (owner, deck),
            )
            if row is None:
                count = await one(
                    tx,
                    "SELECT count(*) AS n FROM app.study_decks WHERE owner_id=%s",
                    (owner,),
                )
                if count["n"] >= 100:
                    raise ApiError(409, "LIMIT_REACHED", "Đã đạt giới hạn số bộ từ.")
            row = await one(
                tx,
                """INSERT INTO app.study_decks (id,owner_id,name) VALUES (%s,%s,%s)
                ON CONFLICT(id,owner_id) DO UPDATE SET name=excluded.name
                RETURNING id,name""",
                (deck, owner, name),
            )
            if row is None:
                raise missing()
        return Result(200, deck_dto(row))

    async def delete_deck(self, call: Call) -> Result:
        owner, deck = call.identity.user_id, call.path["deck_id"]
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await tx.execute(
                "DELETE FROM app.study_decks WHERE owner_id=%s AND id=%s", (owner, deck)
            )
        return Result(204)

    async def put_deck_item(self, call: Call) -> Result:
        owner, deck, item = (
            call.identity.user_id,
            call.path["deck_id"],
            call.path["item_id"],
        )
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._deck(tx, owner, deck)
            target = await one(
                tx,
                "SELECT id FROM app.learning_items WHERE owner_id=%s AND id=%s AND status='active'",
                (owner, item),
            )
            if target is None:
                raise missing()
            state = await one(
                tx,
                """SELECT count(*) AS n, coalesce(bool_or(item_id=%s),false) AS existing
                FROM app.study_deck_items WHERE owner_id=%s AND deck_id=%s""",
                (item, owner, deck),
            )
            if state["n"] >= 250 and not state["existing"]:
                raise ApiError(409, "LIMIT_REACHED", "Bộ từ đã đủ 250 mục.")
            await tx.execute(
                """INSERT INTO app.study_deck_items (owner_id,deck_id,item_id) VALUES (%s,%s,%s)
                ON CONFLICT(deck_id,item_id) DO NOTHING""",
                (owner, deck, item),
            )
        return Result(204)

    async def delete_deck_item(self, call: Call) -> Result:
        owner, deck, item = (
            call.identity.user_id,
            call.path["deck_id"],
            call.path["item_id"],
        )
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._deck(tx, owner, deck)
            await tx.execute(
                "DELETE FROM app.study_deck_items WHERE owner_id=%s AND deck_id=%s AND item_id=%s",
                (owner, deck, item),
            )
        return Result(204)

    async def lookup_history(self, call: Call) -> Result:
        owner = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(
                tx,
                """SELECT v.id,v.hanzi,r.pinyin_display,r.vietnamese,h.viewed_at FROM app.study_lookups h
                JOIN app.vocabulary v ON v.id=h.entry_id JOIN app.vocabulary_revisions r ON r.id=v.published_revision_id
                WHERE h.owner_id=%s AND r.status='published' ORDER BY h.viewed_at DESC,h.entry_id LIMIT 100""",
                (owner,),
            )
        return Result(
            200,
            {
                "items": [
                    {
                        "entry_id": str(row["id"]),
                        "hanzi": row["hanzi"],
                        "pinyin": row["pinyin_display"],
                        "vietnamese": row["vietnamese"],
                        "viewed_at": row["viewed_at"].isoformat(),
                    }
                    for row in rows
                ]
            },
        )

    async def record_lookup(self, call: Call) -> Result:
        owner, entry = call.identity.user_id, call.path["entry_id"]
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await one(
                tx,
                """SELECT entry_id FROM app.study_lookup_receipts
                WHERE owner_id=%s AND client_key=%s""",
                (owner, call.idempotency_key),
            )
            if prior is not None:
                if str(prior["entry_id"]) != entry:
                    raise ApiError(
                        409,
                        "IDEMPOTENCY_CONFLICT",
                        "Khóa thao tác đã dùng với từ khác.",
                    )
                return Result(204, replayed=True)
            active = await one(
                tx,
                """SELECT v.id FROM app.vocabulary v JOIN app.vocabulary_revisions r
                ON r.id=v.published_revision_id WHERE v.id=%s AND r.status='published'""",
                (entry,),
            )
            if active is None:
                raise missing()
            await tx.execute(
                "INSERT INTO app.study_lookup_receipts(owner_id,client_key,entry_id) VALUES (%s,%s,%s)",
                (owner, call.idempotency_key, entry),
            )
            await tx.execute(
                """INSERT INTO app.study_lookups(owner_id,entry_id) VALUES (%s,%s)
                ON CONFLICT(owner_id,entry_id) DO UPDATE SET viewed_at=excluded.viewed_at""",
                (owner, entry),
            )
        return Result(204)

    async def clear_lookups(self, call: Call) -> Result:
        owner = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await tx.execute(
                "DELETE FROM app.study_lookups WHERE owner_id=%s", (owner,)
            )
            await tx.execute(
                "DELETE FROM app.study_lookup_receipts WHERE owner_id=%s", (owner,)
            )
        return Result(204)

    async def mistakes(self, call: Call) -> Result:
        owner = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(
                tx,
                """WITH recent_exams AS (
                  SELECT id,submitted_at FROM app.test_attempts
                  WHERE owner_id=%s AND status IN ('submitted','timed_out') ORDER BY submitted_at DESC,id LIMIT 20
                )
                SELECT * FROM (
                  SELECT 'lesson' AS source,id AS event_id,lesson_id AS reference,created_at AS happened_at
                  FROM app.study_attempts WHERE owner_id=%s AND NOT correct
                  UNION ALL
                  SELECT 'review',id,item_id::text,accepted_at
                  FROM app.review_events WHERE owner_id=%s AND quality=0
                  UNION ALL
                  SELECT 'exam',e.id,q.question_id::text,e.submitted_at
                  FROM recent_exams e CROSS JOIN LATERAL app_private.exam_explanations(e.id) q
                  WHERE q.selected_index IS NOT NULL AND NOT q.is_correct
                ) mistakes ORDER BY happened_at DESC,event_id,reference LIMIT 100""",
                (owner, owner, owner),
            )
        return Result(
            200,
            {
                "items": [
                    {
                        "source": row["source"],
                        "event_id": str(row["event_id"]),
                        "reference": row["reference"],
                        "happened_at": row["happened_at"].isoformat(),
                    }
                    for row in rows
                ]
            },
        )

    async def goals(self, call: Call) -> Result:
        owner = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            stats = await one(
                tx,
                """WITH study_day AS (SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS day)
                SELECT day,
                  (SELECT count(*) FROM app.activity_events WHERE owner_id=%s AND local_day=day) AS reviews_today,
                  (SELECT count(*) FROM app.activity_events WHERE owner_id=%s) AS reviews,
                  (SELECT count(DISTINCT lesson_id) FROM app.study_attempts
                     WHERE owner_id=%s AND correct AND (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=day) AS lessons_today,
                  (SELECT count(DISTINCT lesson_id) FROM app.study_attempts WHERE owner_id=%s AND correct) AS lessons
                FROM study_day""",
                (owner, owner, owner, owner),
            )
        completed = stats["reviews_today"] + stats["lessons_today"]
        return Result(
            200,
            {
                "day": stats["day"].isoformat(),
                "target": 5,
                "completed": completed,
                "achieved": completed >= 5,
                "achievements": [
                    {
                        "id": "review-first",
                        "target": 1,
                        "progress": stats["reviews"],
                        "unlocked": stats["reviews"] >= 1,
                    },
                    {
                        "id": "review-ten",
                        "target": 10,
                        "progress": stats["reviews"],
                        "unlocked": stats["reviews"] >= 10,
                    },
                    {
                        "id": "lesson-three",
                        "target": 3,
                        "progress": stats["lessons"],
                        "unlocked": stats["lessons"] >= 3,
                    },
                ],
            },
        )

    @staticmethod
    def _reminder(row):
        instant = (
            next_reminder(
                datetime.now(UTC),
                ZoneInfo(row["timezone"]),
                row["local_time"],
                row["weekdays"],
            )
            if row["enabled"]
            else None
        )
        return {
            "enabled": row["enabled"],
            "local_time": row["local_time"].isoformat(timespec="minutes"),
            "timezone": row["timezone"],
            "weekdays": row["weekdays"],
            "next_at": instant.isoformat() if instant else None,
        }

    async def get_reminder(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await one(
                tx,
                "SELECT * FROM app.study_reminders WHERE owner_id=%s",
                (call.identity.user_id,),
            )
        return Result(
            200,
            self._reminder(row)
            if row
            else {
                "enabled": False,
                "local_time": "19:00",
                "timezone": STUDY_ZONE.key,
                "weekdays": list(range(1, 8)),
                "next_at": None,
            },
        )

    async def put_reminder(self, call: Call) -> Result:
        body = call.body
        try:
            zone = ZoneInfo(body["timezone"])
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise invalid_input() from exc
        at = time.fromisoformat(body["local_time"])
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await one(
                tx,
                """INSERT INTO app.study_reminders(owner_id,enabled,local_time,timezone,weekdays)
                VALUES (%s,%s,%s,%s,%s) ON CONFLICT(owner_id) DO UPDATE SET enabled=excluded.enabled,
                local_time=excluded.local_time,timezone=excluded.timezone,weekdays=excluded.weekdays
                RETURNING *""",
                (
                    call.identity.user_id,
                    body["enabled"],
                    at,
                    zone.key,
                    sorted(body["weekdays"]),
                ),
            )
        return Result(200, self._reminder(row))
