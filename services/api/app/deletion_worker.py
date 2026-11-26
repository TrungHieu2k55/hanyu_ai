import asyncio
import os

import httpx

from .errors import ApiError, unavailable
from .postgres import Database, many, one
from .storage import BUCKET, LEARNING_BUCKET, SupabaseImageStorage


async def purge_one(db, personal, learning, delete_auth) -> bool:
    async with db.transaction() as tx:
        claim = await one(tx, "SELECT * FROM app_private.claim_account_deletion()")
    if claim is None:
        return False
    args = (claim["id"], claim["lease_token"])
    error = None
    try:
        async with asyncio.timeout(240):
            if not claim["data_purged"]:
                async with db.transaction() as tx:
                    objects = await many(
                        tx,
                        "SELECT * FROM app_private.prepare_deletion_objects(%s,%s)",
                        args,
                    )
                for resource in objects:
                    if resource["bucket"] == BUCKET:
                        await personal.remove(resource["object_key"])
                    elif resource["bucket"] == LEARNING_BUCKET:
                        await learning.remove(resource["object_key"])
                    else:
                        raise unavailable(
                            "PROVIDER_UNAVAILABLE",
                            "Kho dữ liệu cá nhân không được cấu hình.",
                        )
                async with db.transaction() as tx:
                    result = await one(
                        tx,
                        "SELECT app_private.purge_deletion_data(%s,%s) AS done",
                        args,
                    )
                if not result["done"]:
                    return True
            await delete_auth(claim["owner_id"])
    except (ApiError, TimeoutError):
        error = "DELETION_RETRY"
    async with db.transaction() as tx:
        await tx.execute(
            "SELECT app_private.finish_account_deletion(%s,%s,%s)", (*args, error)
        )
    return True


async def main() -> int:
    dsn, url, key = [
        os.getenv(var, "").strip()
        for var in (
            "HANYU_DELETION_DATABASE_URL",
            "SUPABASE_URL",
            "SUPABASE_STORAGE_KEY",
        )
    ]
    if not all((dsn, url, key)):
        print("Set the deletion database URL, Supabase origin and server credential.")
        return 2
    personal = SupabaseImageStorage(url, key)
    learning = SupabaseImageStorage(url, key, bucket=LEARNING_BUCKET)

    async def delete_auth(subject):
        try:
            async with httpx.AsyncClient(timeout=8, follow_redirects=False) as client:
                response = await client.request(
                    "DELETE",
                    f"{url.rstrip('/')}/auth/v1/admin/users/{subject}",
                    headers=personal.headers,
                    json={"should_soft_delete": False},
                )
            if not response.is_success and response.status_code != 404:
                raise unavailable("AUTH_UNAVAILABLE", "Auth chưa xóa xong tài khoản.")
        except httpx.HTTPError as exc:
            raise unavailable(
                "AUTH_UNAVAILABLE", "Auth chưa xóa xong tài khoản."
            ) from exc

    await purge_one(Database(dsn, b"", ""), personal, learning, delete_auth)
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main(), loop_factory=asyncio.SelectorEventLoop))
