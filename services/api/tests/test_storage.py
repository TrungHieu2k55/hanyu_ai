import unittest
from unittest.mock import AsyncMock, patch

import httpx

from app.errors import ApiError
from app.ports import Media
from app.storage import BUCKET, SupabaseImageStorage


class SupabaseStorageTests(unittest.IsolatedAsyncioTestCase):
    async def test_upload_sign_and_delete_use_private_storage_contract(self):
        store = SupabaseImageStorage("https://project.supabase.co", "sb_secret_fixture")
        key = "ocr/asset-id"
        path = f"/object/sign/{BUCKET}/{key}"
        request = AsyncMock(
            side_effect=[
                httpx.Response(200),
                httpx.Response(200, json={"signedURL": f"{path}?token=fixture"}),
                httpx.Response(200, json=[]),
            ]
        )
        with patch.object(store, "request", request):
            await store.store(
                key, Media(data=b"validated bytes", content_type="image/png")
            )
            url = await store.sign(key, 240)
            await store.remove(key)
        self.assertEqual(
            url, f"https://project.supabase.co/storage/v1{path}?token=fixture"
        )
        self.assertEqual(
            request.await_args_list[0].args, ("POST", f"/object/{BUCKET}/{key}")
        )
        self.assertEqual(
            request.await_args_list[0].kwargs["headers"]["x-upsert"], "false"
        )
        self.assertEqual(request.await_args_list[1].kwargs["json"], {"expiresIn": 240})
        self.assertEqual(request.await_args_list[2].kwargs["json"], {"prefixes": [key]})
        self.assertNotIn("Authorization", store.headers)

    async def test_do_not_sign_foreign_url(self):
        store = SupabaseImageStorage("https://project.supabase.co", "fixture")
        with (
            patch.object(
                store,
                "request",
                AsyncMock(
                    return_value=httpx.Response(
                        200,
                        json={"signedURL": "https://foreign.test/object?token=fixture"},
                    )
                ),
            ),
            self.assertRaises(ApiError) as error,
        ):
            await store.sign("ocr/asset-id", 240)
        self.assertEqual(
            (error.exception.status, error.exception.code),
            (503, "PROVIDER_UNAVAILABLE"),
        )
