import hashlib
import json
from uuid import uuid4

from .accounts import Accounts, fingerprint
from .errors import ApiError
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .vocabulary import clean_text, missing, uuid_str

_FIELDS = """id, kind, target_kind, target_id, message, status, resolution_note,
             assigned_admin_id, closed_at, created_at"""


def state_token(row):
    state = {
        "status": row["status"],
        "resolution_note": row["resolution_note"],
        "assigned_admin_id": uuid_str(row["assigned_admin_id"]),
        "closed_at": row["closed_at"].isoformat() if row["closed_at"] else None,
    }
    return hashlib.sha256(
        json.dumps(state, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def report_dto(row):
    return {
        "id": str(row["id"]),
        "kind": row["kind"],
        "message": row["message"],
        "status": row["status"],
        "resolution_note": row["resolution_note"],
        "created_at": row["created_at"].isoformat(),
        "closed_at": row["closed_at"].isoformat() if row["closed_at"] else None,
        "state_token": state_token(row),
        "context": {
            "target_kind": row["target_kind"],
            "target_id": uuid_str(row["target_id"]),
            "selected_text": None,
        },
    }


class Feedback:
    def __init__(self, db: Database, accounts: Accounts):
        self.db = db
        self.accounts = accounts

    @staticmethod
    async def _row(tx, report, *, owner=None, lock=False):
        sql = f"SELECT {_FIELDS} FROM app.feedback_reports WHERE id = %s"
        args = [report]
        if owner is not None:
            sql += " AND owner_id = %s"
            args.append(owner)
        if lock:
            sql += " FOR UPDATE"
        row = await one(tx, sql, args)
        if row is None:
            raise missing()
        return row

    @staticmethod
    async def _verify_target(tx, owner, kind, target):
        if kind is None:
            return
        if kind == "vocabulary":
            valid = await one(
                tx, "SELECT id FROM app.vocabulary_revisions WHERE id = %s", (target,)
            )
        elif kind == "question":
            valid = await one(
                tx,
                """SELECT q.id FROM app.questions q JOIN app.tests t
                ON t.published_revision_id = q.test_revision_id
                WHERE q.id = %s AND app_private.exam_package_ready(q.test_revision_id)
                UNION
                SELECT q.id FROM app.questions q JOIN app.test_attempts a ON a.test_revision_id = q.test_revision_id
                WHERE q.id = %s AND a.owner_id = %s AND a.status <> 'legacy_unverified'""",
                (target, target, owner),
            )
        elif kind == "scenario":
            valid = await one(
                tx,
                """SELECT r.id FROM app.scenario_revisions r JOIN app.scenarios s
                ON s.published_revision_id = r.id WHERE r.id = %s AND r.status = 'published'""",
                (target,),
            )
        else:
            valid = await one(
                tx,
                "SELECT id FROM app.roleplay_turns WHERE owner_id=%s AND id=%s",
                (owner, target),
            )
        if valid is None:
            raise missing()

    async def create(self, call: Call) -> Result:
        owner, body = call.identity.user_id, call.body
        message = clean_text(body["message"])
        target_kind, target = body.get("target_kind"), body.get("target_id")
        operation = "feedback.create"
        digest = fingerprint(call, operation, {**body, "message": message})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(
                    201,
                    report_dto(await self._row(tx, prior, owner=owner)),
                    replayed=True,
                )
            await self._verify_target(tx, owner, target_kind, target)
            report = uuid4()
            op_id = await write_receipt(
                tx, call, operation, digest, report, "feedback_report"
            )
            await tx.execute(
                """INSERT INTO app.feedback_reports
                (id, owner_id, operation_id, kind, target_kind, target_id, message)
                VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                (report, owner, op_id, body["kind"], target_kind, target, message),
            )
            return Result(201, report_dto(await self._row(tx, report, owner=owner)))

    async def get(self, call: Call) -> Result:
        admin = call.operation == "adminGetReport"
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=admin)
            row = await self._row(
                tx,
                call.path["report_id"],
                owner=None if admin else call.identity.user_id,
            )
        return Result(200, report_dto(row))

    async def list(self, call: Call) -> Result:
        admin = call.operation == "adminListReports"
        owner, status = call.identity.user_id, call.query.get("status")
        limit = call.query.get("limit", 20)
        scope = json.dumps(["feedback", admin, str(owner), status])
        after, cursor_id = self.db.read_cursor(scope, call.query.get("cursor"))
        sql = f"SELECT {_FIELDS} FROM app.feedback_reports WHERE true"
        args = []
        if not admin:
            sql += " AND owner_id = %s"
            args.append(owner)
        if status is not None:
            sql += " AND status = %s"
            args.append(status)
        if after is not None:
            sql += " AND (created_at, id) < (%s, %s)"
            args.extend((after, cursor_id))
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=admin)
            rows = await many(
                tx,
                sql + " ORDER BY created_at DESC, id DESC LIMIT %s",
                (*args, limit + 1),
            )
        return Result(
            200,
            {
                "items": [report_dto(r) for r in rows[:limit]],
                "next_cursor": self.db.cursor(scope, rows[limit - 1])
                if len(rows) > limit
                else None,
            },
        )

    async def update(self, call: Call) -> Result:
        owner, report, body = call.identity.user_id, call.path["report_id"], call.body
        note = clean_text(body["resolution_note"])
        operation = "feedback.update"
        digest = fingerprint(
            call, operation, {"id": report, **body, "resolution_note": note}
        )
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(
                    200, report_dto(await self._row(tx, prior)), replayed=True
                )
            row = await self._row(tx, report, lock=True)
            if state_token(row) != body["expected_state_token"]:
                raise ApiError(
                    409, "STALE_VERSION", "Báo lỗi đã thay đổi. Hãy tải lại."
                )
            if row["status"] in {"resolved", "no_change"}:
                raise ApiError(409, "INVALID_STATE", "Báo lỗi đã được đóng.")
            updated = await one(
                tx,
                f"""UPDATE app.feedback_reports SET status = %s, resolution_note = %s,
                assigned_admin_id = %s, closed_at = CASE WHEN %s = 'reviewing' THEN NULL ELSE clock_timestamp() END
                WHERE id = %s RETURNING {_FIELDS}""",
                (body["status"], note, owner, body["status"], report),
            )
            op_id = await write_receipt(
                tx, call, operation, digest, row["id"], "feedback_report"
            )
            await tx.execute(
                """INSERT INTO app_private.admin_audit_logs
                (admin_id, operation_id, action, target_kind, target_id, state_before, state_after)
                VALUES (%s,%s,'feedback.update','feedback_report',%s,%s,%s)""",
                (owner, op_id, row["id"], row["status"], updated["status"]),
            )
            return Result(200, report_dto(updated))
