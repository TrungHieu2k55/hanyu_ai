import asyncio
import hashlib
import logging
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

import httpx
from psycopg.types.json import Jsonb
from starlette.concurrency import run_in_threadpool

from .errors import ApiError
from .ocr_providers import (
    OcrProvider,
    ProviderFailure,
    build_providers,
    pinned_models_from_env,
)
from .ocr_text import make_tokens
from .ports import Media
from .postgres import Database, many, one
from .storage import BUCKET, ImageStorage, SupabaseImageStorage

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class Lease:
    job_id: UUID
    owner_id: UUID
    lease_token: UUID
    lease_version: int
    processing_deadline: datetime
    provider_config: dict[str, str]

    def key(self) -> tuple:
        return self.job_id, self.lease_token, self.lease_version


class OcrQueue:
    def __init__(self, db: Database):
        self.db = db

    async def claim(self) -> Lease | None:
        async with self.db.transaction(worker=True) as tx:
            data = await one(tx, "SELECT * FROM app_private.claim_ocr_job()")
            return Lease(**data) if data is not None else None

    async def image(self, lease: Lease) -> dict | None:
        async with self.db.transaction(worker=True) as tx:
            return await one(
                tx,
                "SELECT * FROM app_private.ocr_input(%s, %s, %s, %s)",
                (*lease.key(), self.db.subject_hash(lease.owner_id)),
            )

    async def lexicon(self) -> set[str]:
        async with self.db.transaction(worker=True) as tx:
            rows = await many(tx, "SELECT hanzi FROM app_private.ocr_lexicon()")
        return {row["hanzi"] for row in rows}

    async def heartbeat(self, lease: Lease) -> bool:
        async with self.db.transaction(worker=True) as tx:
            response = await one(
                tx,
                "SELECT app_private.heartbeat_ocr_job(%s, %s, %s) AS kept",
                lease.key(),
            )
            return response["kept"]

    async def sweep(self) -> int:
        async with self.db.transaction(worker=True) as tx:
            row = await one(tx, "SELECT app_private.sweep_ocr_jobs() AS expired")
            return row["expired"]

    async def finish(
        self,
        lease: Lease,
        *,
        raw: str | None = None,
        provider: str | None = None,
        model: str | None = None,
        tokens: list[dict] | None = None,
        warnings: tuple[str, ...] = (),
        error: str | None = None,
    ) -> bool:
        digest = hashlib.sha256(raw.encode()).hexdigest() if raw is not None else None
        async with self.db.transaction(worker=True) as tx:
            response = await one(
                tx,
                "SELECT app_private.finish_ocr_job(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) AS saved",
                (
                    *lease.key(),
                    self.db.subject_hash(lease.owner_id),
                    raw,
                    digest,
                    provider,
                    model,
                    Jsonb(tokens or []),
                    Jsonb(list(warnings)),
                    error,
                ),
            )
            return response["saved"]


class OcrWorker:
    def __init__(
        self, queue: OcrQueue, storage: ImageStorage, providers: dict[str, OcrProvider]
    ):
        self.queue, self.storage, self.providers = queue, storage, providers

    async def _pulse(self, lease: Lease) -> None:
        while True:
            await asyncio.sleep(3)
            if not await self.queue.heartbeat(lease):
                return

    async def _recognize(self, lease: Lease) -> dict:
        settings = await self.queue.image(lease)
        if settings is None or settings["bucket"] != BUCKET:
            raise ApiError(410, "MEDIA_EXPIRED", "Ảnh không còn sẵn sàng.")
        data = await self.storage.fetch(settings["object_key"])
        if hashlib.sha256(data).hexdigest() != settings["sha256"]:
            raise ApiError(422, "INVALID_INPUT", "Ảnh lưu trữ không khớp bản tải lên.")
        image = Media(data, settings["mime_type"])
        warnings: list[str] = []
        for name in ("paddleocr", "gemini"):
            provider = self.providers.get(name)
            if provider is None or provider.model != lease.provider_config.get(name):
                continue
            if await self.queue.image(lease) is None:
                raise ApiError(410, "MEDIA_EXPIRED", "Ảnh không còn sẵn sàng.")
            try:
                async with asyncio.timeout(12):
                    lines = await provider.read(image)
                raw = "\n".join(line.text for line in lines)
                if len(raw) > 10000:
                    raise ApiError(
                        422, "INVALID_INPUT", "Văn bản nhận được vượt giới hạn."
                    )
                if "\0" in raw:
                    raise ProviderFailure()
                try:
                    raw.encode()
                except UnicodeError as exc:
                    raise ProviderFailure() from exc
                if not raw.strip():
                    raw = ""
                    warnings.append("NO_TEXT_FOUND")
                return {
                    "raw": raw,
                    "provider": provider.name,
                    "model": provider.model,
                    "tokens": await run_in_threadpool(
                        make_tokens, lines, await self.queue.lexicon()
                    )
                    if raw
                    else [],
                    "warnings": tuple(warnings),
                }
            except TimeoutError:
                if name == "paddleocr":
                    warnings.append("PADDLEOCR_FAILED")
            except ProviderFailure as exc:
                if not exc.retryable:
                    break
                if name == "paddleocr":
                    warnings.append("PADDLEOCR_FAILED")
        raise ApiError(
            503,
            "PROVIDER_UNAVAILABLE",
            "Dịch vụ nhận diện chưa trả được kết quả.",
            retryable=True,
        )

    async def _pipeline(self, lease: Lease) -> dict:
        remaining = (lease.processing_deadline - datetime.now(UTC)).total_seconds()
        async with asyncio.timeout(max(0, remaining - 0.4)):
            return await self._recognize(lease)

    async def run_once(self) -> bool:
        lease = await self.queue.claim()
        if lease is None:
            return False
        pipeline = asyncio.create_task(self._pipeline(lease))
        pulse = asyncio.create_task(self._pulse(lease))
        try:
            done, _ = await asyncio.wait(
                {pipeline, pulse}, return_when=asyncio.FIRST_COMPLETED
            )
            if pulse in done:
                await pulse
                return True
            try:
                output = pipeline.result()
            except ApiError as exc:
                output = {"error": exc.code}
            except TimeoutError:
                output = {"error": "JOB_TIMEOUT"}
            saved = await self.queue.finish(lease, **output)
            logger.info("ocr_job=%s stored=%s", lease.job_id, saved)
            return True
        finally:
            pipeline.cancel()
            pulse.cancel()
            await asyncio.gather(pipeline, pulse, return_exceptions=True)

    async def _maintenance(self) -> None:
        while True:
            try:
                await self.queue.sweep()
            except ApiError as exc:
                logger.warning("ocr_sweep code=%s", exc.code)
            await asyncio.sleep(5)

    async def run(self) -> None:
        maintenance = asyncio.create_task(self._maintenance())
        try:
            while True:
                try:
                    if not await self.run_once():
                        await asyncio.sleep(1)
                except ApiError as exc:
                    logger.warning("ocr_worker code=%s", exc.code)
                    await asyncio.sleep(2)
        finally:
            maintenance.cancel()
            await asyncio.gather(maintenance, return_exceptions=True)


async def main() -> int:
    dsn, url, key, signing = [
        os.getenv(name, "").strip()
        for name in (
            "HANYU_WORKER_DATABASE_URL",
            "SUPABASE_URL",
            "SUPABASE_STORAGE_KEY",
            "HANYU_SIGNING_KEY",
        )
    ]
    if not (dsn and url and key and len(signing.encode()) >= 32):
        print(
            "Configure the worker database URL, Supabase origin, Storage key and signing key."
        )
        return 2
    queue = OcrQueue(Database(dsn, signing.encode(), ""))
    try:
        async with httpx.AsyncClient(timeout=12, follow_redirects=False) as client:
            providers = build_providers(client, pinned_models_from_env())
            if not providers:
                print("Configure at least one OCR provider.")
                return 2
            worker = OcrWorker(queue, SupabaseImageStorage(url, key), providers)
            await worker.run()
    except ValueError:
        print("OCR provider or Storage settings are invalid.")
        return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(asyncio.run(main(), loop_factory=asyncio.SelectorEventLoop))
    except KeyboardInterrupt:
        raise SystemExit(0) from None
