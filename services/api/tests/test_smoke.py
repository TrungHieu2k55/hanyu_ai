import argparse
import io
import unittest
from contextlib import redirect_stdout

import httpx

from app.smoke import api_origin, run_checks


class BackendSmokeTests(unittest.TestCase):
    def test_local_boot_checks_pass_with_degraded_health(self):
        def handle(request):
            self.assertNotIn("Authorization", request.headers)
            if request.url.path == "/health":
                return httpx.Response(200, json={"api_version": "1", "status": "degraded"})
            self.assertEqual(request.url.path, "/v1/me")
            return httpx.Response(401, json={"code": "UNAUTHORIZED"})

        output = io.StringIO()
        with (
            httpx.Client(
                base_url="http://localhost", transport=httpx.MockTransport(handle)
            ) as client,
            redirect_stdout(output),
        ):
            self.assertEqual(run_checks(client), 0)
            self.assertEqual(run_checks(client, require_ready=True), 1)
        self.assertIn("SKIP learner checks", output.getvalue())
        self.assertIn("expected ready", output.getvalue())

    def test_authenticated_failures_are_reported_without_echoing_credentials(self):
        calls = []

        def handle(request):
            token = request.headers.get("Authorization")
            calls.append((request.url.path, token))
            if request.url.path == "/health":
                self.assertIsNone(token)
                return httpx.Response(200, json={"api_version": "1", "status": "ok"})
            if token is None:
                return httpx.Response(401, json={"code": "UNAUTHORIZED"})
            return httpx.Response(
                403, json={"code": "TERMS_REQUIRED", "message": token}
            )

        output = io.StringIO()
        with (
            httpx.Client(
                base_url="http://localhost", transport=httpx.MockTransport(handle)
            ) as client,
            redirect_stdout(output),
        ):
            self.assertEqual(run_checks(client, token="private-credential"), 1)
        self.assertEqual(len(calls), 7)
        self.assertIn("HTTP 403 (TERMS_REQUIRED)", output.getvalue())
        self.assertNotIn("private-credential", output.getvalue())

    def test_api_origin_restricts_credential_destination(self):
        self.assertEqual(api_origin("http://[::1]:8000/"), "http://[::1]:8000")
        self.assertEqual(api_origin("https://dev.invalid"), "https://dev.invalid")
        for url in (
            "http://dev.invalid",
            "https://user:pass@dev.invalid",
            "https://dev.invalid/v1",
            "https://dev.invalid:99999",
        ):
            with self.subTest(url=url), self.assertRaises(argparse.ArgumentTypeError):
                api_origin(url)
