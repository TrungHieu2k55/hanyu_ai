import json
import unittest

import httpx

from app.ocr_providers import GeminiVisionOcr, PaddleGeneralOcr, ProviderFailure
from app.ocr_text import OcrLine, make_tokens
from app.ports import Media

IMAGE = Media(b"test-image", "image/png")


class ProviderTests(unittest.IsolatedAsyncioTestCase):
    async def test_paddle_general_ocr_wire_format_and_line_confidence(self):
        def handle(request):
            self.assertEqual(request.url.path, "/ocr")
            self.assertEqual(request.headers["authorization"], "token fixture")
            self.assertEqual(
                json.loads(request.content),
                {
                    "file": "dGVzdC1pbWFnZQ==",
                    "fileType": 1,
                    "visualize": False,
                },
            )
            return httpx.Response(
                200,
                json={
                    "errorCode": 0,
                    "result": {
                        "ocrResults": [
                            {
                                "prunedResult": {
                                    "rec_texts": ["你好", "谢谢"],
                                    "rec_scores": [0.91, 2],
                                }
                            }
                        ]
                    },
                },
            )

        async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as client:
            provider = PaddleGeneralOcr(
                client, "https://paddle.test/ocr", "fixture", "pp-test"
            )
            lines = await provider.read(IMAGE)
        self.assertEqual(lines, [OcrLine("你好", 0.91), OcrLine("谢谢")])
        self.assertEqual(
            make_tokens(lines)[0], {"hanzi": "你", "pinyin": "nǐ", "confidence": 0.91}
        )

    async def test_gemini_validates_structured_text_and_does_not_invent_confidence(
        self,
    ):
        def handle(request):
            self.assertEqual(request.url.host, "generativelanguage.googleapis.com")
            self.assertEqual(request.headers["x-goog-api-key"], "fixture")
            payload = json.loads(request.content)
            self.assertEqual(
                payload["contents"][0]["parts"][1]["inlineData"]["mimeType"],
                "image/png",
            )
            self.assertEqual(
                payload["generationConfig"]["responseMimeType"], "application/json"
            )
            return httpx.Response(
                200,
                json={
                    "candidates": [
                        {
                            "finishReason": "STOP",
                            "content": {
                                "parts": [
                                    {"thought": True, "text": "ignored"},
                                    {"text": '{"text":"朋友"}'},
                                ],
                            },
                        }
                    ]
                },
            )

        async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as client:
            provider = GeminiVisionOcr(client, "fixture", "gemini-test")
            lines = await provider.read(IMAGE)
        self.assertEqual(lines, [OcrLine("朋友")])

    async def test_provider_429_and_invalid_schema_allow_fallback(self):
        status = httpx.Response(429)
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(lambda _: status)
        ) as client:
            provider = PaddleGeneralOcr(
                client, "https://paddle.test/ocr", "", "pp-test"
            )
            with self.assertRaises(ProviderFailure) as error:
                await provider.read(IMAGE)
        self.assertTrue(error.exception.retryable)

        bad = httpx.Response(200, json={"result": {"ocrResults": "invalid"}})
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(lambda _: bad)
        ) as client:
            provider = PaddleGeneralOcr(
                client, "https://paddle.test/ocr", "", "pp-test"
            )
            with self.assertRaises(ProviderFailure) as error:
                await provider.read(IMAGE)
        self.assertTrue(error.exception.retryable)
