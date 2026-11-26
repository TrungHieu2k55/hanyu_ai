from dataclasses import dataclass, field
from typing import Any, Literal, Protocol
from uuid import UUID

from .errors import ApiError, unavailable


@dataclass(frozen=True)
class Identity:
    user_id: UUID
    session_id: UUID
    authenticated_at: int | None = field(default=None, compare=False)


class TokenVerifier(Protocol):
    @property
    def configured(self) -> bool: ...

    async def verify(self, token: str) -> Identity: ...


@dataclass(frozen=True)
class Access:
    live_session: bool
    deleting: bool = False
    role: Literal["learner", "admin"] | None = None
    terms_required: bool = True


@dataclass(frozen=True)
class Media:
    data: bytes = field(repr=False)
    content_type: str


@dataclass(frozen=True)
class Call:
    operation: str
    identity: Identity
    path: dict[str, Any]
    query: dict[str, Any]
    idempotency_key: UUID | None
    body: dict[str, Any] | None = field(repr=False)
    media: Media | None = field(repr=False)
    request_id: str


@dataclass(frozen=True)
class Result:
    status: int
    body: dict[str, Any] | None = field(default=None, repr=False)
    replayed: bool = False


class Backend(Protocol):
    """Persist actor-scoped operations, ownership, and idempotency in P6 transactions."""

    @property
    def ready(self) -> bool: ...

    async def healthy(self) -> bool: ...

    async def access(self, identity: Identity) -> Access:
        """Check the live session, deletion state, profile and current terms."""

    async def execute(self, call: Call) -> Result: ...

    async def deletion_status(self, token: str) -> Result: ...


class UnconfiguredBackend:
    ready = False

    async def healthy(self) -> bool:
        return self.ready

    async def deletion_status(self, token: str) -> Result:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy biên nhận.")

    async def access(self, identity: Identity) -> Access:
        raise unavailable(
            "AUTH_UNAVAILABLE", "Chưa kết nối kho xác thực phiên đăng nhập."
        )

    async def execute(self, call: Call) -> Result:
        if call.operation == "predictCharacter":
            raise unavailable(
                "MODEL_UNAVAILABLE", "Chưa có model nhận diện được công bố."
            )
        raise unavailable(
            "CONTENT_UNAVAILABLE", "Chưa kết nối kho dữ liệu của thao tác."
        )
