import hashlib
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from psycopg.types.json import Jsonb
from starlette.concurrency import run_in_threadpool

from .accounts import Accounts, fingerprint
from .errors import ApiError, invalid_input
from .ocr_results import insert_tokens, token_page
from .ocr_text import OcrLine, make_tokens
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .storage import BUCKET, ImageStorage

ACTIVE = {"queued", "processing"}

SCAN_COLUMNS = """
s.id, s.status, s.image_media_id, s.raw_text, s.current_revision, s.version, s.created_at,
r.text AS corrected_text,
CASE
  WHEN m.state = 'deleted' THEN 'deleted'
  WHEN m.state = 'delete_pending' OR m.expires_at <= clock_timestamp() THEN 'expired'
  WHEN m.state = 'ready' THEN 'ready'
  ELSE 'unavailable'
END AS image_state
"""
SCAN_TABLES = """
FROM app.ocr_scans s
LEFT JOIN app.media_assets m ON m.id = s.image_media_id AND m.owner_id = s.owner_id
LEFT JOIN app.ocr_revisions r ON r.owner_id = s.owner_id AND r.scan_id = s.id
  AND r.revision = s.current_revision
"""

JOB_COLUMNS = """
id, scan_id, session_id, draft_id, turn_id, status, kind, created_at, queue_deadline, processing_deadline, warnings, safe_error_code
"""


def not_found() -> ApiError:
    return ApiError(404, "NOT_FOUND", "Không tìm thấy nội dung yêu cầu.")


def expired_media() -> ApiError:
    return ApiError(410, "MEDIA_EXPIRED", "Ảnh đã hết hạn hoặc không còn.")


def job_dto(row: dict, request_id: str) -> dict:
    return {
        "job_id": str(row["id"]),
        "kind": row["kind"],
        "status": row["status"],
        "created_at": row["created_at"].isoformat(),
        "queue_deadline": row["queue_deadline"].isoformat(),
        "processing_deadline": (
            row["processing_deadline"].isoformat()
            if row["processing_deadline"]
            else None
        ),
        "target": {
            field: str(row[field]) if row.get(field) else None
            for field in ("scan_id", "session_id", "draft_id", "turn_id")
        },
        "warnings": row["warnings"],
        "error": {
            "code": row["safe_error_code"],
            "message": "Tác vụ đã vượt thời gian xử lý."
            if row["safe_error_code"] == "JOB_TIMEOUT"
            else "Tác vụ không hoàn tất.",
            "retryable": row["safe_error_code"]
            in {"JOB_TIMEOUT", "PROVIDER_UNAVAILABLE"},
            "request_id": request_id,
        }
        if row["safe_error_code"]
        else None,
    }


def scan_summary(row: dict) -> dict:
    text = row["corrected_text"]
    return {
        "id": str(row["id"]),
        "status": row["status"],
        "text_preview": text[:200] if text else None,
        "image_state": row["image_state"],
        "revision": row["current_revision"],
        "version": row["version"],
        "created_at": row["created_at"].isoformat(),
    }


class OcrService:
    def __init__(
        self,
        db: Database,
        accounts: Accounts,
        storage: ImageStorage,
        models: dict[str, str],
        learning_storage: ImageStorage | None,
    ):
        self.db = db
        self.accounts = accounts
        self.storage = storage
        self.models = models.copy()
        self.learning_storage = learning_storage

    @staticmethod
    async def _check_ocr_quota(tx, user: UUID) -> None:
        row = await one(
            tx,
            """
            SELECT count(*) AS total FROM app.operations
            WHERE owner_id = %s AND operation = 'ocr.create'
              AND created_at > clock_timestamp() - interval '1 minute'
            """,
            (user,),
        )
        if row["total"] >= 5:
            raise ApiError(
                429, "QUOTA_EXCEEDED", "Đã đủ lượt OCR trong phút này.", retryable=True
            )

    async def create(self, call: Call) -> Result:
        assert call.media is not None and call.idempotency_key is not None
        user = call.identity.user_id
        media = call.media
        sha = hashlib.sha256(media.data).hexdigest()
        fingerprint = hashlib.sha256(
            f"ocr.create\n{user}\n{media.content_type}\n{sha}".encode()
        ).hexdigest()
        media_id = uuid4()
        object_key = f"ocr/{media_id}"
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            existing = await receipt(tx, call, "ocr.create", fingerprint)
            if existing is not None:
                return await self._created_response(tx, user, existing)
            await self._check_ocr_quota(tx, user)
            await tx.execute(
                """
                INSERT INTO app.media_assets (id, owner_id, scope, kind, bucket, object_key,
                                              mime_type, size_bytes, sha256, expires_at)
                VALUES (%s, %s, 'personal', 'ocr_image', %s, %s, %s, %s, %s,
                        clock_timestamp() + interval '10 minutes')
                """,
                (
                    media_id,
                    user,
                    BUCKET,
                    object_key,
                    media.content_type,
                    len(media.data),
                    sha,
                ),
            )

        await self.storage.store(object_key, media)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, user)
            await self.accounts.require_access(tx, call.identity)
            existing = await receipt(tx, call, "ocr.create", fingerprint)
            if existing is not None:
                return await self._created_response(tx, user, existing)
            await self._check_ocr_quota(tx, user)
            stage = await one(
                tx,
                """
                UPDATE app.media_assets SET state = 'ready', version = version + 1,
                                            expires_at = clock_timestamp() + interval '7 days'
                WHERE id = %s AND owner_id = %s AND state = 'staging' AND expires_at > clock_timestamp()
                RETURNING id
                """,
                (media_id, user),
            )
            if stage is None:
                raise expired_media()
            job_id = uuid4()
            receipt_id = await write_receipt(
                tx, call, "ocr.create", fingerprint, job_id
            )
            scan = await one(
                tx,
                """
                INSERT INTO app.ocr_scans (owner_id, operation_id, image_media_id)
                VALUES (%s, %s, %s) RETURNING id
                """,
                (user, receipt_id, media_id),
            )
            job = await one(
                tx,
                """
                INSERT INTO app.ai_jobs (id, owner_id, operation_id, kind, scan_id, provider_config)
                VALUES (%s, %s, %s, 'ocr', %s, %s) RETURNING created_at
                """,
                (job_id, user, receipt_id, scan["id"], Jsonb(self.models)),
            )
        return Result(
            202,
            {
                "job_id": str(job_id),
                "status": "queued",
                "created_at": job["created_at"].isoformat(),
            },
        )

    async def _created_response(self, tx, owner: UUID, id_: UUID) -> Result:
        row = await self._job_row(tx, owner, id_)
        if row is None:
            raise ApiError(410, "RESOURCE_GONE", "Tác vụ đã được xóa.")
        return Result(
            202,
            {
                "job_id": str(id_),
                "status": "queued",
                "created_at": row["created_at"].isoformat(),
            },
            replayed=True,
        )

    @staticmethod
    async def _expire(tx, user: UUID) -> None:
        await tx.execute(
            """
            WITH expired AS (
              UPDATE app.ai_jobs SET status = 'failed', safe_error_code = 'JOB_TIMEOUT',
                                    completed_at = clock_timestamp(), lease_token = NULL, locked_until = NULL
              WHERE owner_id = %s AND (
                (status = 'queued' AND queue_deadline <= clock_timestamp())
                OR (status = 'processing' AND (
                  processing_deadline <= clock_timestamp()
                  OR (execution_attempts >= 2 AND locked_until <= clock_timestamp())
                ))
              )
              RETURNING scan_id
            )
            UPDATE app.ocr_scans SET status = 'failed', version = version + 1
            WHERE owner_id = %s AND status IN ('queued', 'processing') AND id IN (SELECT scan_id FROM expired)
            """,
            (user, user),
        )

    @staticmethod
    async def _job_row(tx, user: UUID, job: UUID) -> dict | None:
        return await one(
            tx,
            f"""
            SELECT {JOB_COLUMNS} FROM app.ai_jobs WHERE id = %s AND owner_id = %s
            """,
            (job, user),
        )

    async def get_job(self, call: Call) -> Result:
        user = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, user)
            row = await self._job_row(tx, user, UUID(call.path["job_id"]))
        if row is None:
            raise not_found()
        return Result(200, job_dto(row, call.request_id))

    async def cancel(self, call: Call) -> Result:
        user = call.identity.user_id
        id_ = UUID(call.path["job_id"])
        fingerprint = hashlib.sha256(f"job.cancel\n{user}\n{id_}".encode()).hexdigest()
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, user)
            await self.accounts.require_access(tx, call.identity)
            previous = await receipt(tx, call, "job.cancel", fingerprint)
            await self._expire(tx, user)
            row = await self._job_row(tx, user, id_)
            if row is None:
                if previous is not None:
                    raise ApiError(410, "RESOURCE_GONE", "Tác vụ đã được xóa.")
                raise not_found()
            if previous is not None:
                return Result(200, job_dto(row, call.request_id), replayed=True)
            if row["status"] in ACTIVE:
                changed = await one(
                    tx,
                    """
                    UPDATE app.ai_jobs
                    SET status = 'canceled', completed_at = clock_timestamp(),
                        lease_token = NULL, locked_until = NULL
                    WHERE owner_id = %s AND id = %s AND status IN ('queued', 'processing')
                    RETURNING scan_id
                    """,
                    (user, id_),
                )
                if changed is not None:
                    await tx.execute(
                        """
                        UPDATE app.ocr_scans SET status = 'canceled', version = version + 1
                        WHERE owner_id = %s AND id = %s AND status IN ('queued', 'processing')
                        """,
                        (user, changed["scan_id"]),
                    )
                row = await self._job_row(tx, user, id_)
            await write_receipt(tx, call, "job.cancel", fingerprint, id_)
        return Result(200, job_dto(row, call.request_id))

    async def list_jobs(self, call: Call) -> Result:
        user = call.identity.user_id
        state = call.query.get("status")
        scope = f"jobs:{user}:{state or 'all'}"
        date, id_ = self.db.read_cursor(scope, call.query.get("cursor"))
        limit = call.query["limit"]
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, user)
            rows = await many(
                tx,
                f"""
                SELECT {JOB_COLUMNS} FROM app.ai_jobs
                WHERE owner_id = %(owner)s
                  AND (%(state)s::text IS NULL OR status = %(state)s::text
                       OR (%(state)s::text = 'active' AND status IN ('queued', 'processing')))
                  AND (%(date)s::timestamptz IS NULL
                       OR (created_at, id) < (%(date)s::timestamptz, %(id)s::uuid))
                ORDER BY created_at DESC, id DESC LIMIT %(limit)s
                """,
                {
                    "owner": user,
                    "state": state,
                    "date": date,
                    "id": id_,
                    "limit": limit + 1,
                },
            )
        return self._page(rows, scope, limit, lambda row: job_dto(row, call.request_id))

    async def list_scans(self, call: Call) -> Result:
        user = call.identity.user_id
        scope = f"scans:{user}"
        date, id_ = self.db.read_cursor(scope, call.query.get("cursor"))
        limit = call.query["limit"]
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, user)
            rows = await many(
                tx,
                f"""
                SELECT {SCAN_COLUMNS} {SCAN_TABLES}
                WHERE s.owner_id = %(owner)s AND (%(date)s::timestamptz IS NULL
                    OR (s.created_at, s.id) < (%(date)s::timestamptz, %(id)s::uuid))
                ORDER BY s.created_at DESC, s.id DESC LIMIT %(limit)s
                """,
                {"owner": user, "date": date, "id": id_, "limit": limit + 1},
            )
        return self._page(rows, scope, limit, scan_summary)

    def _page(self, rows, scope, limit, project) -> Result:
        items = rows[:limit]
        return Result(
            200,
            {
                "items": [project(row) for row in items],
                "next_cursor": self.db.cursor(scope, items[-1])
                if len(rows) > limit
                else None,
            },
        )

    async def _scan_row(self, tx, owner: UUID, scan: UUID) -> dict:
        row = await one(
            tx,
            f"""
            SELECT {SCAN_COLUMNS} {SCAN_TABLES} WHERE s.owner_id = %s AND s.id = %s
            """,
            (owner, scan),
        )
        if row is None:
            raise not_found()
        return row

    @staticmethod
    async def _revision(tx, owner: UUID, scan: UUID, revision: int) -> dict | None:
        if revision > 2147483647:
            return None
        return await one(
            tx,
            """
            SELECT id, revision, text FROM app.ocr_revisions
            WHERE owner_id = %s AND scan_id = %s AND revision = %s
            """,
            (owner, scan, revision),
        )

    async def _scan_details(
        self, tx, owner, row, *, revision=None, version=None
    ) -> dict:
        if revision is None and row["status"] == "completed":
            revision = await self._revision(
                tx, owner, row["id"], row["current_revision"]
            )
        tokens = {"items": [], "next_cursor": None}
        if revision is not None:
            tokens = await token_page(tx, self.db, owner, row["id"], revision)
        summary = scan_summary(row)
        summary.pop("text_preview")
        if revision is not None:
            summary["revision"] = revision["revision"]
        if version is not None:
            summary["version"] = version
        return {
            **summary,
            "image_media_id": str(row["image_media_id"])
            if row["image_media_id"]
            else None,
            "raw_text": row["raw_text"],
            "corrected_text": revision["text"] if revision is not None else None,
            "tokens": tokens["items"],
            "tokens_next_cursor": tokens["next_cursor"],
        }

    async def get_scan(self, call: Call) -> Result:
        user, scan = call.identity.user_id, UUID(call.path["scan_id"])
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            await self._expire(tx, user)
            row = await self._scan_row(tx, user, scan)
            return Result(200, await self._scan_details(tx, user, row))

    async def list_scan_tokens(self, call: Call) -> Result:
        user, scan = call.identity.user_id, UUID(call.path["scan_id"])
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await self._scan_row(tx, user, scan)
            if row["status"] != "completed":
                raise ApiError(409, "RESULT_NOT_READY", "Scan chưa có kết quả để tra.")
            revision = await self._revision(tx, user, scan, call.query["revision"])
            if revision is None:
                raise not_found()
            return Result(
                200,
                await token_page(
                    tx,
                    self.db,
                    user,
                    scan,
                    revision,
                    call.query["limit"],
                    call.query.get("cursor"),
                ),
            )

    async def edit_scan(self, call: Call) -> Result:
        assert call.body is not None and call.idempotency_key is not None
        user, scan = call.identity.user_id, UUID(call.path["scan_id"])
        text, expected = call.body["text"], int(call.body["expected_version"])
        try:
            if "\0" in text:
                raise ValueError("invalid codepoint")
            text_hash = hashlib.sha256(text.encode()).hexdigest()
        except ValueError as exc:
            raise invalid_input() from exc
        fingerprint = hashlib.sha256(
            f"ocr.edit\n{user}\n{scan}\n{expected}\n{text_hash}".encode()
        ).hexdigest()
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, user)
            await self.accounts.require_access(tx, call.identity)
            previous = await receipt(tx, call, "ocr.edit", fingerprint)
            row = await self._scan_row(tx, user, scan)
            if previous is not None:
                revision = await one(
                    tx,
                    """
                    SELECT id, revision, text FROM app.ocr_revisions
                    WHERE id = %s AND scan_id = %s AND owner_id = %s
                    """,
                    (previous, scan, user),
                )
                if revision is None:
                    raise ApiError(410, "RESOURCE_GONE", "Bản sửa đã được xóa.")
                snapshot = await self._scan_details(
                    tx, user, row, revision=revision, version=expected + 1
                )
                return Result(200, snapshot, replayed=True)
            if row["status"] != "completed":
                raise ApiError(409, "RESULT_NOT_READY", "Scan chưa có kết quả để sửa.")
            if row["version"] != expected:
                raise ApiError(
                    409,
                    "STALE_VERSION",
                    "Kết quả đã thay đổi. Hãy tải lại trước khi sửa.",
                )
            revision = await one(
                tx,
                """
                INSERT INTO app.ocr_revisions (owner_id, scan_id, revision, text, text_hash, origin)
                VALUES (%s, %s, %s, %s, %s, 'user') RETURNING id, revision, text
                """,
                (user, scan, row["current_revision"] + 1, text, text_hash),
            )
            lexicon = {
                row["hanzi"]
                for row in await many(tx, "SELECT hanzi FROM app_private.ocr_lexicon()")
            }
            await insert_tokens(
                tx,
                user,
                revision["id"],
                await run_in_threadpool(make_tokens, [OcrLine(text)], lexicon),
            )
            await tx.execute(
                """
                UPDATE app.ocr_scans SET current_revision = %s, version = version + 1
                WHERE id = %s AND owner_id = %s
                """,
                (revision["revision"], scan, user),
            )
            await write_receipt(
                tx, call, "ocr.edit", fingerprint, revision["id"], "ocr_revision"
            )
            return Result(
                200,
                await self._scan_details(
                    tx,
                    user,
                    row,
                    revision=revision,
                    version=expected + 1,
                ),
            )

    async def update_avatar(self, call: Call) -> Result:
        owner, media = call.identity.user_id, call.media
        sha = hashlib.sha256(media.data).hexdigest()
        operation = "profile.avatar"
        digest = fingerprint(
            call, operation, {**call.body, "sha256": sha, "type": media.content_type}
        )
        identifier = uuid4()
        object_key = f"avatars/{identifier}"
        expected = call.body["expected_version"]
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            profile = await self.accounts._profile(tx, owner)
            if prior is not None:
                return Result(200, profile, replayed=True)
            if profile["version"] != expected:
                raise ApiError(409, "STALE_VERSION", "Hồ sơ đã thay đổi. Hãy tải lại.")
            await tx.execute(
                """INSERT INTO app.media_assets
                (id,owner_id,kind,bucket,object_key,mime_type,size_bytes,sha256,expires_at)
                VALUES (%s,%s,'avatar',%s,%s,%s,%s,%s,clock_timestamp() + interval '10 minutes')""",
                (
                    identifier,
                    owner,
                    BUCKET,
                    object_key,
                    media.content_type,
                    len(media.data),
                    sha,
                ),
            )
        await self.storage.store(object_key, media)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            profile = await self.accounts._profile(tx, owner)
            if prior is not None:
                return Result(200, profile, replayed=True)
            if profile["version"] != expected:
                raise ApiError(409, "STALE_VERSION", "Hồ sơ đã thay đổi. Hãy tải lại.")
            stage = await one(
                tx,
                """UPDATE app.media_assets SET state='ready',expires_at=NULL,version=version+1
                WHERE owner_id=%s AND id=%s AND state='staging' AND expires_at>clock_timestamp()
                RETURNING id""",
                (owner, identifier),
            )
            if stage is None:
                raise expired_media()
            await tx.execute(
                """UPDATE app.profiles SET avatar_media_id=%s,version=version+1,updated_at=clock_timestamp()
                WHERE owner_id=%s AND id=%s""",
                (identifier, owner, owner),
            )
            if profile["avatar_media_id"] is not None:
                await self._queue_image_removal(tx, owner, profile["avatar_media_id"])
            await write_receipt(tx, call, operation, digest, owner, "profile")
            return Result(200, await self.accounts._profile(tx, owner))

    async def delete_scan(self, call: Call) -> Result:
        owner, scan = call.identity.user_id, call.path["scan_id"]
        operation = "ocr.delete"
        digest = fingerprint(call, operation, {**call.path, **call.query})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(204, replayed=True)
            # The worker takes the job lock before committing scan results.
            await tx.execute(
                "SELECT id FROM app.ai_jobs WHERE owner_id = %s AND scan_id = %s FOR UPDATE",
                (owner, scan),
            )
            row = await self._scan_row(tx, owner, scan)
            if row["version"] != call.query["expected_version"]:
                raise ApiError(
                    409, "STALE_VERSION", "Lượt quét đã thay đổi. Hãy tải lại."
                )
            await self._queue_image_removal(tx, owner, row["image_media_id"])
            await tx.execute(
                "DELETE FROM app.ai_jobs WHERE owner_id = %s AND scan_id = %s",
                (owner, scan),
            )
            await tx.execute(
                """DELETE FROM app.ocr_tokens WHERE owner_id = %s AND revision_id IN (
                SELECT id FROM app.ocr_revisions WHERE owner_id = %s AND scan_id = %s)""",
                (owner, owner, scan),
            )
            await tx.execute(
                "DELETE FROM app.ocr_revisions WHERE owner_id = %s AND scan_id = %s",
                (owner, scan),
            )
            await tx.execute(
                "DELETE FROM app.ocr_scans WHERE owner_id = %s AND id = %s",
                (owner, scan),
            )
            await write_receipt(tx, call, operation, digest, row["id"], "ocr_scan")
        return Result(204)

    @staticmethod
    async def _queue_image_removal(tx, owner, media_id):
        await tx.execute(
            """UPDATE app.media_assets SET state = 'delete_pending',
                            expires_at = clock_timestamp(), version = version + 1
                            WHERE owner_id = %s AND id = %s AND kind IN ('ocr_image', 'avatar','roleplay_input','roleplay_audio')
                              AND state NOT IN ('delete_pending','deleted')""",
            (owner, media_id),
        )

    async def delete_media(self, call: Call) -> Result:
        owner, media = call.identity.user_id, call.path["media_id"]
        operation = "media.delete"
        digest = fingerprint(call, operation, call.path)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            row = await one(
                tx,
                """SELECT id, state, kind FROM app.media_assets WHERE id = %s
                                   AND owner_id = %s AND scope = 'personal'""",
                (media, owner),
            )
            if row is None:
                raise not_found()
            linked = await one(
                tx,
                "SELECT id FROM app.profiles WHERE owner_id=%s AND avatar_media_id=%s",
                (owner, media),
            )
            if linked is not None:
                raise ApiError(
                    409, "RESOURCE_IN_USE", "Hãy gỡ liên kết của tệp trước khi xóa."
                )
            if prior is None:
                await self._expire(tx, owner)
                active = await one(
                    tx,
                    """SELECT j.id FROM app.ai_jobs j
                    JOIN app.ocr_scans s ON s.id = j.scan_id AND s.owner_id = j.owner_id
                    WHERE s.image_media_id = %s AND j.owner_id = %s AND j.status IN ('queued','processing')
                    LIMIT 1 FOR UPDATE OF j""",
                    (media, owner),
                )
                if active is None:
                    active = await one(
                        tx,
                        """SELECT id FROM app.ai_jobs WHERE owner_id=%s AND input_media_id=%s
                        AND status IN ('queued','processing') FOR UPDATE""",
                        (owner, media),
                    )
                if active is not None:
                    raise ApiError(
                        409, "RESOURCE_IN_USE", "Tác vụ OCR đang sử dụng ảnh này."
                    )
                await self._queue_image_removal(tx, owner, row["id"])
                await write_receipt(tx, call, operation, digest, row["id"], "media")
            current = await one(
                tx,
                "SELECT state FROM app.media_assets WHERE id = %s AND owner_id = %s",
                (media, owner),
            )
        return Result(
            202,
            {"media_id": str(row["id"]), "state": current["state"]},
            replayed=prior is not None,
        )

    async def sign_media(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await one(
                tx,
                """
                SELECT id, object_key, expires_at, state FROM app.media_assets m
                WHERE m.id = %s AND m.owner_id = %s AND m.bucket = %s AND (
                    (m.kind = 'ocr_image' AND EXISTS (
                        SELECT FROM app.ocr_scans s WHERE s.image_media_id = m.id AND s.owner_id = m.owner_id))
                    OR (m.kind = 'avatar' AND EXISTS (
                        SELECT FROM app.profiles p WHERE p.avatar_media_id = m.id AND p.owner_id = m.owner_id))
                    OR (m.kind='roleplay_input' AND EXISTS (
                        SELECT FROM app.transcription_drafts d WHERE d.audio_media_id=m.id AND d.owner_id=m.owner_id))
                    OR (m.kind='roleplay_audio' AND EXISTS (
                        SELECT FROM app.roleplay_turns t WHERE t.audio_media_id=m.id AND t.owner_id=m.owner_id))
                  )
                """,
                (UUID(call.path["media_id"]), call.identity.user_id, BUCKET),
            )
            audio = None
            if row is None and self.learning_storage is not None:
                audio = await one(
                    tx,
                    """SELECT m.id, m.object_key FROM app.learning_audio m
                       WHERE m.id = %s AND EXISTS (
                         SELECT FROM app.questions q JOIN app.test_attempts a
                           ON a.test_revision_id = q.test_revision_id
                         WHERE a.owner_id = %s AND a.status <> 'legacy_unverified'
                           AND q.audio_media_id = m.id
                       )""",
                    (call.path["media_id"], call.identity.user_id),
                )
        if audio is not None:
            now = datetime.now(UTC)
            url = await self.learning_storage.sign(audio["object_key"], 300)
            return Result(
                200,
                {
                    "media_id": str(audio["id"]),
                    "url": url,
                    "expires_at": (now + timedelta(seconds=300)).isoformat(),
                },
            )
        if row is None:
            raise not_found()
        now = datetime.now(UTC)
        ttl = (
            min(300, int((row["expires_at"] - now).total_seconds()))
            if row["expires_at"]
            else 300
        )
        if row["state"] != "ready" or ttl <= 0:
            raise expired_media()
        url = await self.storage.sign(row["object_key"], ttl)
        return Result(
            200,
            {
                "media_id": str(row["id"]),
                "url": url,
                "expires_at": (now + timedelta(seconds=ttl)).isoformat(),
            },
        )
