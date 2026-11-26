from datetime import date, timedelta

from .accounts import Accounts
from .errors import invalid_input
from .ports import Call, Result
from .postgres import Database, many, one

_TIMEZONE = "Asia/Ho_Chi_Minh"
_DASHBOARD = """
WITH active_items AS (
    SELECT id FROM app.learning_items WHERE owner_id = %(owner)s AND status = 'active'
), latest_review AS (
    SELECT DISTINCT ON (active.id) active.id, e.quality
    FROM app.review_events e
    JOIN app.learning_items source ON source.owner_id = e.owner_id AND source.id = e.item_id
    JOIN active_items active ON active.id = coalesce(source.merged_into_id, source.id)
    WHERE e.owner_id = %(owner)s
    ORDER BY active.id, e.accepted_at DESC, e.id DESC
), membership AS (
    SELECT count(*) AS saved_words, count(r.id) AS studied_words,
           count(*) FILTER (WHERE r.quality >= 3) AS self_reported_remembered_words
    FROM active_items i LEFT JOIN latest_review r ON r.id = i.id
), review_counts AS (
    SELECT count(*) AS review_count,
           count(*) FILTER (WHERE e.quality >= 3) AS remembered_review_count
    FROM app.activity_events a
    JOIN app.review_events e ON e.owner_id = a.owner_id AND e.id = a.review_event_id
    WHERE a.owner_id = %(owner)s AND a.local_day BETWEEN %(start)s AND %(end)s
), attended_days AS (
    SELECT DISTINCT local_day
    FROM app.activity_events
    WHERE owner_id = %(owner)s AND local_day <= %(today)s
), numbered_days AS (
    SELECT local_day, local_day - row_number() OVER (ORDER BY local_day)::integer AS run
    FROM attended_days
), runs AS (
    SELECT max(local_day) AS last_day, count(*) AS days FROM numbered_days GROUP BY run
), streak AS (
    SELECT coalesce(max(days) FILTER (
               WHERE last_day IN (%(today)s, %(today)s::date - 1)
           ), 0) AS current_streak,
           coalesce(max(days), 0) AS longest_streak
    FROM runs
)
SELECT membership.*, review_counts.*, streak.*,
       round(100.0 * remembered_review_count / nullif(review_count, 0), 2) AS review_accuracy_percent
FROM membership CROSS JOIN review_counts CROSS JOIN streak
"""


def date_range(query: dict, today: date) -> tuple[date, date]:
    try:
        end = date.fromisoformat(query["to"]) if "to" in query else today
        start = (
            date.fromisoformat(query["from"])
            if "from" in query
            else end - timedelta(days=29)
        )
    except (ValueError, OverflowError) as exc:
        raise invalid_input() from exc
    if not 0 <= (end - start).days < 366:
        raise invalid_input()
    return start, end


def activity_source(row: dict):
    return next(
        (kind, row[field])
        for kind, field in (
            ("review", "review_event_id"),
            ("test", "test_attempt_id"),
            ("quiz", "quiz_attempt_id"),
            ("prediction", "prediction_attempt_id"),
            ("roleplay", "turn_id"),
        )
        if row[field] is not None
    )


class Progress:
    def __init__(self, db: Database, accounts: Accounts):
        self.db = db
        self.accounts = accounts

    @staticmethod
    async def _today(tx) -> date:
        row = await one(
            tx,
            "SELECT (clock_timestamp() AT TIME ZONE %s)::date AS today",
            (_TIMEZONE,),
        )
        return row["today"]

    async def dashboard(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            today = await self._today(tx)
            start, end = date_range(call.query, today)
            row = await one(
                tx,
                _DASHBOARD,
                {
                    "owner": call.identity.user_id,
                    "today": today,
                    "start": start,
                    "end": end,
                },
            )
        accuracy = row["review_accuracy_percent"]
        return Result(
            200,
            {
                **row,
                "from": start.isoformat(),
                "to": end.isoformat(),
                "timezone": _TIMEZONE,
                "review_accuracy_percent": None
                if accuracy is None
                else float(accuracy),
            },
        )

    async def activities(self, call: Call) -> Result:
        owner = call.identity.user_id
        limit = call.query.get("limit", 20)
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            start, end = date_range(call.query, await self._today(tx))
            scope = f"activities:{owner}:{start.isoformat()}:{end.isoformat()}"
            after, cursor_id = self.db.read_cursor(scope, call.query.get("cursor"))
            sql = """SELECT id, review_event_id, test_attempt_id, quiz_attempt_id, prediction_attempt_id, turn_id, occurred_at, local_day
                     FROM app.activity_events WHERE owner_id = %s AND local_day BETWEEN %s AND %s"""
            args = [owner, start, end]
            if after is not None:
                sql += " AND (occurred_at, id) < (%s, %s)"
                args.extend((after, cursor_id))
            rows = await many(
                tx,
                sql + " ORDER BY occurred_at DESC, id DESC LIMIT %s",
                (*args, limit + 1),
            )
        page = rows[:limit]
        cursor = None
        if len(rows) > limit:
            last = page[-1]
            cursor = self.db.cursor(
                scope, {"id": last["id"], "created_at": last["occurred_at"]}
            )
        return Result(
            200,
            {
                "items": [
                    {
                        "id": str(row["id"]),
                        "kind": (source := activity_source(row))[0],
                        "resource_id": str(source[1]),
                        "occurred_at": row["occurred_at"].isoformat(),
                        "local_day": row["local_day"].isoformat(),
                    }
                    for row in page
                ],
                "next_cursor": cursor,
            },
        )
