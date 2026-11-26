import hashlib
import re
import secrets
from time import time

from .accounts import Accounts
from .errors import ApiError, unavailable
from .operations import lock_owner
from .ports import Call, Result
from .postgres import Database, one

_RECEIPT = re.compile(r"Bearer ([A-Za-z0-9_-]{43})", re.IGNORECASE)


def receipt_token(headers: list[str]) -> str:
    match = _RECEIPT.fullmatch(headers[0]) if len(headers) == 1 else None
    if match is None:
        raise no_receipt()
    return match[1]


def no_receipt():
    return ApiError(404, "NOT_FOUND", "Biên nhận không hợp lệ hoặc đã hết hạn.")


def token_hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


class Deletions:
    def __init__(self, db: Database, accounts: Accounts, enabled: bool):
        self.db, self.accounts, self.enabled = db, accounts, enabled

    async def request(self, call: Call) -> Result:
        owner = call.identity.user_id
        auth_time = call.identity.authenticated_at
        if auth_time is None or not 0 <= time() - auth_time <= 300:
            raise ApiError(
                403, "REAUTH_REQUIRED", "Hãy đăng nhập lại để xác nhận xóa tài khoản."
            )
        if not self.enabled:
            raise unavailable(
                "CONTENT_UNAVAILABLE", "Tác vụ xóa tài khoản chưa được cấu hình."
            )
        token = secrets.token_urlsafe(32)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity, terms=False)
            row = await one(
                tx,
                "SELECT * FROM app_private.begin_account_deletion(%s,%s,%s,%s)",
                (
                    call.identity.session_id,
                    self.db.subject_hash(owner),
                    token_hash(token),
                    call.idempotency_key,
                ),
            )
            if row is None:
                raise ApiError(
                    403, "ACCOUNT_DELETING", "Tài khoản không thể tạo thêm yêu cầu xóa."
                )
        return Result(
            202,
            {
                "status": "requested",
                "receipt_token": token,
                "receipt_expires_at": row["receipt_expires_at"].isoformat(),
            },
        )

    async def status(self, token: str) -> Result:
        async with self.db.transaction(receipt=True) as tx:
            row = await one(
                tx,
                "SELECT * FROM app_private.deletion_status(%s)",
                (token_hash(token),),
            )
        if row is None:
            raise no_receipt()
        return Result(200, {**row, "updated_at": row["updated_at"].isoformat()})
