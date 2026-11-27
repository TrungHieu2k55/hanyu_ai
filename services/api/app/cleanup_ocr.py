import asyncio
import os

from .errors import ApiError
from .postgres import Database, many
from .storage import BUCKET, LEARNING_BUCKET, ImageStorage, SupabaseImageStorage


async def clean_batch(
    db: Database,
    storage: ImageStorage,
    limit: int = 20,
    *,
    learning_storage: ImageStorage | None = None,
) -> tuple[int, int]:
    async with db.transaction() as tx:
        await tx.execute("SELECT app_private.purge_study_speech()")
        pending = await many(
            tx, "SELECT * FROM app_private.claim_ocr_media_cleanup(%s)", (limit,)
        )
    deleted = failed = 0
    for item in pending:
        if item["bucket"] != BUCKET:
            failed += 1
            continue
        try:
            await storage.remove(item["object_key"])
        except ApiError:
            failed += 1
            continue
        async with db.transaction() as tx:
            await tx.execute(
                "SELECT app_private.finish_ocr_media_cleanup(%s, %s)",
                (item["id"], item["version"]),
            )
        deleted += 1
    if learning_storage is not None:
        for claim, finish in (
            (
                "app_private.claim_admin_media_cleanup",
                "app_private.finish_admin_media_cleanup",
            ),
            ("app_private.claim_tts_cleanup", "app_private.finish_tts_cleanup"),
        ):
            async with db.transaction() as tx:
                shared = await many(tx, f"SELECT * FROM {claim}(%s)", (limit,))
            for item in shared:
                try:
                    await learning_storage.remove(item["object_key"])
                except ApiError:
                    failed += 1
                    continue
                async with db.transaction() as tx:
                    await tx.execute(f"SELECT {finish}(%s)", (item["id"],))
                deleted += 1
    return deleted, failed


async def main() -> int:
    dsn, url, key = [
        os.getenv(name, "").strip()
        for name in (
            "HANYU_CLEANUP_DATABASE_URL",
            "SUPABASE_URL",
            "SUPABASE_STORAGE_KEY",
        )
    ]
    if not all((dsn, url, key)):
        print("Set the cleanup database URL, Supabase origin and Storage key.")
        return 2
    try:
        removed, pending = await clean_batch(
            Database(dsn, b"", ""),
            SupabaseImageStorage(url, key),
            learning_storage=SupabaseImageStorage(url, key, bucket=LEARNING_BUCKET),
        )
    except ApiError as exc:
        print(f"OCR cleanup: {exc.code}")
        return 1
    print(f"OCR cleanup: deleted={removed} pending_retry={pending}")
    return int(pending > 0)


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main(), loop_factory=asyncio.SelectorEventLoop))
