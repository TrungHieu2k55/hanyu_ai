import asyncio
import base64
import hashlib
import hmac
import json
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Any
from uuid import UUID

import psycopg
from psycopg.errors import QueryCanceled
from psycopg.rows import dict_row

from .errors import ApiError, unavailable
from .ports import Identity

logger = logging.getLogger(__name__)
_TEMPORARY_SQLSTATES = {"40001", "40P01", "55P03", "57P01", "57P02", "57P03"}


def server_loop_factory() -> asyncio.AbstractEventLoop:
    # Psycopg requires a selector loop on Windows.
    return asyncio.SelectorEventLoop()


class Database:
    def __init__(self, dsn: str, signing_key: bytes, terms_version: str):
        self._dsn = dsn
        self._signing_key = signing_key
        self.terms_version = terms_version

    @asynccontextmanager
    async def transaction(
        self,
        identity: Identity | None = None,
        *,
        auth: bool = False,
        worker: bool = False,
        receipt: bool = False,
    ) -> AsyncIterator[psycopg.AsyncConnection]:
        try:
            connection = await psycopg.AsyncConnection.connect(
                self._dsn,
                connect_timeout=5,
                row_factory=dict_row,
            )
            async with connection:
                if worker:
                    await connection.execute("SET LOCAL ROLE app_worker")
                elif receipt:
                    await connection.execute("SET LOCAL ROLE app_api")
                elif identity is None:
                    await connection.execute("SET LOCAL ROLE app_cleanup")
                else:
                    await connection.execute("SET LOCAL ROLE app_api")
                    await connection.execute(
                        "SELECT set_config('app.actor_id', %s, true), set_config('app.subject_hash', %s, true)",
                        (str(identity.user_id), self.subject_hash(identity.user_id)),
                    )
                await connection.execute("SET LOCAL statement_timeout = '5s'")
                yield connection
        except QueryCanceled as exc:
            if auth:
                raise unavailable(
                    "AUTH_UNAVAILABLE", "Chưa kiểm tra được phiên đăng nhập."
                ) from exc
            raise ApiError(
                504, "DB_TIMEOUT", "Kho dữ liệu phản hồi quá chậm.", retryable=True
            ) from exc
        except psycopg.Error as exc:
            state = exc.sqlstate
            transient = (
                state in _TEMPORARY_SQLSTATES
                or (state is not None and state.startswith(("08", "53")))
                or (
                    state is None
                    and isinstance(
                        exc, (psycopg.OperationalError, psycopg.InterfaceError)
                    )
                )
            )
            if transient:
                code = "AUTH_UNAVAILABLE" if auth else "CONTENT_UNAVAILABLE"
                raise unavailable(code, "Chưa kết nối được kho dữ liệu.") from exc
            logger.error("database_operation_failed sqlstate=%s", state or "unknown")
            raise ApiError(
                500, "INTERNAL_ERROR", "Máy chủ chưa hoàn tất thao tác."
            ) from exc

    def subject_hash(self, user_id: UUID) -> str:
        return hmac.new(
            self._signing_key,
            b"subject:" + str(user_id).encode(),
            hashlib.sha256,
        ).hexdigest()

    def cursor(self, scope: str, row: dict[str, Any]) -> str:
        return self._sign_cursor(scope, [row["created_at"].isoformat(), str(row["id"])])

    def read_cursor(
        self, scope: str, token: str | None
    ) -> tuple[datetime | None, UUID | None]:
        if token is None:
            return None, None
        try:
            timestamp, item = self._verify_cursor(scope, token)
            date = datetime.fromisoformat(timestamp)
            if date.tzinfo is None:
                raise ValueError("invalid timestamp")
            return date, UUID(item)
        except (ValueError, TypeError, AttributeError) as exc:
            raise invalid_cursor() from exc

    def vocabulary_cursor(self, scope: str, row: dict[str, Any]) -> str:
        return self._sign_cursor(
            scope, [row["match_tier"], row["hanzi"], str(row["entry_id"])]
        )

    def read_vocabulary_cursor(
        self, scope: str, token: str | None
    ) -> tuple[int, str, UUID] | None:
        if token is None:
            return None
        try:
            tier, hanzi, entry = self._verify_cursor(scope, token)
            if (
                type(tier) is not int
                or not 0 <= tier <= 3
                or not isinstance(hanzi, str)
                or not 1 <= len(hanzi) <= 100
            ):
                raise ValueError("invalid vocabulary cursor")
            return tier, hanzi, UUID(entry)
        except (ValueError, TypeError, AttributeError) as exc:
            raise invalid_cursor() from exc

    def position_cursor(self, scope: str, position: int) -> str:
        return self._sign_cursor(scope, [position])

    def read_position(self, scope: str, token: str | None) -> int:
        if token is None:
            return -1
        try:
            (position,) = self._verify_cursor(scope, token)
            if type(position) is not int or not 0 <= position < 10000:
                raise ValueError("invalid token position")
            return position
        except (ValueError, TypeError) as exc:
            raise invalid_cursor() from exc

    def _sign_cursor(self, scope: str, values: list) -> str:
        data = json.dumps(
            [1, self._scope_hash(scope), values], separators=(",", ":")
        ).encode()
        signature = hmac.digest(self._signing_key, b"cursor:" + data, "sha256")
        return base64.urlsafe_b64encode(signature + data).decode().rstrip("=")

    def _verify_cursor(self, scope: str, token: str) -> list:
        packed = base64.b64decode(
            token + "=" * (-len(token) % 4), altchars=b"-_", validate=True
        )
        signature, data = packed[:32], packed[32:]
        valid = hmac.digest(self._signing_key, b"cursor:" + data, "sha256")
        if not hmac.compare_digest(signature, valid):
            raise ValueError("invalid signature")
        version, subject, *fields = json.loads(data)
        if version != 1 or subject != self._scope_hash(scope):
            raise ValueError("invalid scope")
        if len(fields) == 2 and all(isinstance(value, str) for value in fields):
            return fields
        if len(fields) != 1 or not isinstance(fields[0], list):
            raise ValueError("invalid cursor values")
        return fields[0]

    def _scope_hash(self, scope: str) -> str:
        return hmac.new(
            self._signing_key, b"scope:" + scope.encode(), hashlib.sha256
        ).hexdigest()


def invalid_cursor() -> ApiError:
    return ApiError(400, "INVALID_CURSOR", "Mốc phân trang không hợp lệ.")


async def one(connection, sql: str, params=()) -> dict[str, Any] | None:
    return await (await connection.execute(sql, params)).fetchone()


async def many(connection, sql: str, params=()) -> list[dict[str, Any]]:
    return await (await connection.execute(sql, params)).fetchall()
