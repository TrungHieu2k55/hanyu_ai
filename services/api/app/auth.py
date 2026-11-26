import os
from urllib.parse import urlsplit
from uuid import UUID

import jwt
from fastapi import Request
from fastapi.security.utils import get_authorization_scheme_param
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientConnectionError, PyJWKClientError, PyJWTError
from starlette.concurrency import run_in_threadpool

from .errors import ApiError, unavailable
from .ports import Backend, Identity, TokenVerifier


def unauthorized() -> ApiError:
    return ApiError(
        401, "UNAUTHORIZED", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn."
    )


class SupabaseJwtVerifier:
    def __init__(self, project_url: str, algorithm: str = "ES256"):
        self.issuer = f"{project_url.rstrip('/')}/auth/v1"
        self.algorithm = algorithm
        self.jwks: PyJWKClient | None = None
        if project_url:
            parts = urlsplit(project_url)
            if (
                parts.scheme != "https"
                or not parts.hostname
                or parts.username is not None
                or parts.path.rstrip("/")
                or parts.query
                or parts.fragment
            ):
                raise ValueError("SUPABASE_URL must be an HTTPS origin")
            if algorithm not in {"ES256", "RS256"}:
                raise ValueError("SUPABASE_JWT_ALGORITHM must be ES256 or RS256")
            self.jwks = PyJWKClient(f"{self.issuer}/.well-known/jwks.json", timeout=4)

    @property
    def configured(self) -> bool:
        return self.jwks is not None

    @classmethod
    def from_environment(cls) -> "SupabaseJwtVerifier":
        return cls(
            os.getenv("SUPABASE_URL", "").strip(),
            os.getenv("SUPABASE_JWT_ALGORITHM", "ES256").strip(),
        )

    async def verify(self, token: str) -> Identity:
        if self.jwks is None:
            raise unavailable("AUTH_UNAVAILABLE", "Chưa cấu hình nguồn xác thực.")
        return await run_in_threadpool(self._verify, token, self.jwks)

    def _verify(self, token: str, jwks: PyJWKClient) -> Identity:
        try:
            header = jwt.get_unverified_header(token)
            if (
                header.get("alg") != self.algorithm
                or not isinstance(header.get("kid"), str)
                or not header["kid"]
            ):
                raise unauthorized()
            signing_key = jwks.get_signing_key(header["kid"])
            if signing_key.algorithm_name != self.algorithm:
                raise unauthorized()
            claims = jwt.decode(
                token,
                signing_key.key,
                algorithms=[self.algorithm],
                issuer=self.issuer,
                audience="authenticated",
                options={"require": ["exp", "sub", "iss", "aud", "session_id"]},
            )
            if (
                claims.get("role") != "authenticated"
                or claims.get("is_anonymous", False) is not False
            ):
                raise unauthorized()
            methods = claims.get("amr")
            fresh = (
                (
                    entry["timestamp"]
                    for entry in methods
                    if isinstance(entry, dict)
                    and entry.get("method") in {"password", "oauth"}
                    and type(entry.get("timestamp")) is int
                )
                if isinstance(methods, list)
                else ()
            )
            return Identity(
                UUID(claims["sub"]),
                UUID(claims["session_id"]),
                max(fresh, default=None),
            )
        except PyJWKClientConnectionError as exc:
            raise unavailable(
                "AUTH_UNAVAILABLE", "Chưa đọc được khóa xác thực."
            ) from exc
        except (
            PyJWKClientError,
            PyJWTError,
            ValueError,
            TypeError,
            AttributeError,
        ) as exc:
            raise unauthorized() from exc


async def authorize(
    request: Request,
    verifier: TokenVerifier,
    backend: Backend,
    scope: str,
    *,
    allow_unprovisioned: bool = False,
) -> Identity:
    header = request.headers.getlist("authorization")
    if len(header) != 1:
        raise unauthorized()
    scheme, token = get_authorization_scheme_param(header[0])
    if (
        scheme.lower() != "bearer"
        or not token
        or len(token) > 8192
        or any(c.isspace() for c in token)
    ):
        raise unauthorized()
    identity = await verifier.verify(token)
    access = await backend.access(identity)
    if not access.live_session:
        raise ApiError(401, "SESSION_REVOKED", "Phiên đăng nhập đã bị thu hồi.")
    if access.deleting:
        raise ApiError(403, "ACCOUNT_DELETING", "Tài khoản đang được xử lý xóa.")
    if access.role is None and not allow_unprovisioned:
        raise ApiError(404, "PROFILE_NOT_READY", "Hồ sơ học tập chưa sẵn sàng.")
    if scope == "admin" and access.role != "admin":
        raise ApiError(403, "FORBIDDEN", "Cần quyền quản trị.")
    if scope in {"learner", "admin"}:
        if access.role not in {"learner", "admin"}:
            raise ApiError(403, "FORBIDDEN", "Tài khoản chưa được cấp quyền.")
        if access.terms_required:
            raise ApiError(403, "TERMS_REQUIRED", "Hãy xác nhận điều khoản hiện hành.")
    return identity
