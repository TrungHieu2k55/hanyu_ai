from typing import Protocol
from urllib.parse import quote, urlsplit

import httpx

from .errors import ApiError, unavailable
from .media import MIB
from .ports import Media

BUCKET = "hanyu-ocr-private"
LEARNING_BUCKET = "hanyu-learning-private"


class ImageStorage(Protocol):
    async def store(self, object_key: str, media: Media) -> None: ...

    async def sign(self, object_key: str, ttl_seconds: int) -> str: ...

    async def fetch(self, object_key: str) -> bytes: ...

    async def remove(self, object_key: str) -> None: ...


class SupabaseImageStorage:
    def __init__(self, project_url: str, api_key: str, *, bucket: str = BUCKET):
        origin = urlsplit(project_url)
        if (
            origin.scheme != "https"
            or not origin.hostname
            or origin.username is not None
            or origin.path.rstrip("/")
            or origin.query
            or origin.fragment
        ):
            raise ValueError("SUPABASE_URL must be an HTTPS origin")
        self.bucket = bucket
        self.base_url = f"{project_url.rstrip('/')}/storage/v1"
        self.headers = {"apikey": api_key}
        if not api_key.startswith("sb_secret_"):
            self.headers["Authorization"] = f"Bearer {api_key}"

    async def request(self, method: str, path: str, **kwargs) -> httpx.Response:
        try:
            async with httpx.AsyncClient(timeout=8, follow_redirects=False) as client:
                return await client.request(
                    method,
                    f"{self.base_url}{path}",
                    headers={**self.headers, **kwargs.pop("headers", {})},
                    **kwargs,
                )
        except httpx.HTTPError as exc:
            raise storage_unavailable() from exc

    def object_path(self, object_key: str) -> str:
        return f"{self.bucket}/{quote(object_key, safe='/')}"

    async def store(self, object_key: str, media: Media) -> None:
        response = await self.request(
            "POST",
            f"/object/{self.object_path(object_key)}",
            content=media.data,
            headers={"Content-Type": media.content_type, "x-upsert": "false"},
        )
        if not response.is_success:
            raise storage_unavailable()

    async def sign(self, object_key: str, ttl_seconds: int) -> str:
        path = f"/object/sign/{self.object_path(object_key)}"
        response = await self.request("POST", path, json={"expiresIn": ttl_seconds})
        if response.status_code == 404:
            raise ApiError(410, "MEDIA_EXPIRED", "Ảnh đã hết hạn hoặc không còn.")
        if not response.is_success:
            raise storage_unavailable()
        try:
            signed = response.json()["signedURL"]
            if signed.startswith("/storage/v1/"):
                signed = signed[len("/storage/v1") :]
            parsed = urlsplit(signed)
            if (
                parsed.scheme
                or parsed.netloc
                or parsed.fragment
                or parsed.path != path
                or not parsed.query.startswith("token=")
                or not parsed.query.removeprefix("token=")
            ):
                raise ValueError("invalid signed URL")
            return f"{self.base_url}{signed}"
        except (ValueError, KeyError, AttributeError, TypeError) as exc:
            raise storage_unavailable() from exc

    async def fetch(self, object_key: str) -> bytes:
        path = self.object_path(object_key)
        try:
            async with (
                httpx.AsyncClient(timeout=8, follow_redirects=False) as client,
                client.stream(
                    "GET",
                    f"{self.base_url}/object/authenticated/{path}",
                    headers=self.headers,
                ) as response,
            ):
                if response.status_code == 404:
                    raise ApiError(
                        410, "MEDIA_EXPIRED", "Ảnh đã hết hạn hoặc không còn."
                    )
                if not response.is_success:
                    raise storage_unavailable()
                data = bytearray()
                async for chunk in response.aiter_bytes():
                    if len(data) + len(chunk) > 10 * MIB:
                        raise storage_unavailable()
                    data.extend(chunk)
                return bytes(data)
        except httpx.HTTPError as exc:
            raise storage_unavailable() from exc

    async def remove(self, object_key: str) -> None:
        response = await self.request(
            "DELETE", f"/object/{self.bucket}", json={"prefixes": [object_key]}
        )
        if not response.is_success:
            raise storage_unavailable()


def storage_unavailable() -> ApiError:
    return unavailable(
        "PROVIDER_UNAVAILABLE", "Kho ảnh chưa sẵn sàng. Hãy thử lại sau."
    )
