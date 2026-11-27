import io
import time
import unittest
import wave
from types import SimpleNamespace
from unittest.mock import Mock, patch
from uuid import uuid4

import jwt
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient
from jwt.exceptions import PyJWKClientConnectionError, PyJWKClientError
from PIL import Image

from app.auth import SupabaseJwtVerifier
from app.backend import PostgresBackend
from app.contract import CONTRACT
from app.errors import ApiError
from app.main import create_app
from app.ports import Access, Call, Identity, Result
from app.postgres import Database
from app.storage import ImageStorage

USER, OTHER, SESSION, JOB, KEY = [uuid4() for _ in range(5)]
STAMP = "2026-11-24T00:00:00Z"


class FixtureVerifier:
    configured = True

    async def verify(self, token: str) -> Identity:
        identities = {"learner-a": USER, "learner-b": OTHER}
        if token not in identities:
            raise ApiError(401, "UNAUTHORIZED", "Phiên đăng nhập không hợp lệ.")
        return Identity(identities[token], SESSION)


class FixtureBackend:
    ready = True

    async def healthy(self):
        return self.ready

    def __init__(self):
        self.calls: list[Call] = []
        self.access_state = Access(
            live_session=True, role="learner", terms_required=False
        )
        self.extra_output = False
        self.jobs: dict[tuple, tuple[bytes, dict]] = {}

    async def access(self, identity: Identity) -> Access:
        return self.access_state

    async def execute(self, call: Call) -> Result:
        self.calls.append(call)
        if call.operation == "getMe":
            data = {
                "id": str(call.identity.user_id),
                "display_name": "Học viên",
                "hsk_target": 1,
                "daily_minutes": 15,
                "sound_enabled": True,
                "role": self.access_state.role,
                "avatar_media_id": None,
                "version": 1,
                "terms_required": self.access_state.terms_required,
            }
            if self.extra_output:
                data["object_key"] = "must-not-leak"
            return Result(200, data)
        if call.operation in {"createOcrJob", "transcribeAudio"}:
            assert call.media and call.idempotency_key
            key = (call.identity.user_id, call.operation, call.idempotency_key)
            if key in self.jobs:
                saved_bytes, job = self.jobs[key]
                if saved_bytes != call.media.data:
                    raise ApiError(
                        409, "IDEMPOTENCY_CONFLICT", "Khóa đã dùng cho dữ liệu khác."
                    )
                return Result(202, job, replayed=True)
            job = {"job_id": str(JOB), "status": "queued", "created_at": STAMP}
            self.jobs[key] = (call.media.data, job)
            return Result(202, job)
        if call.operation == "getJob":
            if not any(key[0] == call.identity.user_id for key in self.jobs):
                raise ApiError(404, "NOT_FOUND", "Không tìm thấy job.")
            return Result(
                200,
                {
                    "job_id": str(JOB),
                    "kind": "ocr",
                    "status": "queued",
                    "created_at": STAMP,
                    "queue_deadline": STAMP,
                    "processing_deadline": None,
                    "target": {
                        "scan_id": str(JOB),
                        "session_id": None,
                        "draft_id": None,
                        "turn_id": None,
                    },
                    "warnings": [],
                    "error": None,
                },
            )
        if call.operation == "listJobs":
            return Result(200, {"items": [], "next_cursor": None})
        raise ApiError(503, "MODEL_UNAVAILABLE", "Chưa có model.", retryable=True)


def png(color="white") -> bytes:
    data = io.BytesIO()
    Image.new("RGB", (16, 16), color).save(data, "PNG")
    return data.getvalue()


def wav(seconds: int) -> bytes:
    data = io.BytesIO()
    with wave.open(data, "wb") as track:
        track.setparams((1, 2, 8000, 0, "NONE", "not compressed"))
        track.writeframes(bytes(8000 * 2 * seconds))
    return data.getvalue()


class BackendContractTests(unittest.TestCase):
    def test_backend_handlers_match_contract_operations(self):
        backend = PostgresBackend(Mock(spec=Database), Mock(spec=ImageStorage))
        operations = {
            operation["operationId"]
            for methods in CONTRACT["paths"].values()
            for operation in methods.values()
        }
        # The HTTP layer dispatches these through dedicated methods.
        expected = operations - {"health", "deletionStatus"}
        self.assertEqual(set(backend._handlers), expected)


class HttpTests(unittest.TestCase):
    def setUp(self):
        self.backend = FixtureBackend()
        self.client = TestClient(
            create_app(verifier=FixtureVerifier(), backend=self.backend)
        )
        self.auth = {"Authorization": "Bearer learner-a"}
        self.mutate = {**self.auth, "Idempotency-Key": str(KEY)}

    def tearDown(self):
        self.client.close()

    def check_error(self, response, status, code):
        self.assertEqual(response.status_code, status, response.text)
        error = response.json()
        self.assertEqual(set(error), {"code", "message", "retryable", "request_id"})
        self.assertEqual(error["code"], code)
        self.assertEqual(error["request_id"], response.headers["X-Request-ID"])
        self.assertEqual(response.headers["Cache-Control"], "no-store")
        self.assertEqual(response.headers["X-Schema-Version"], "1")
        return error

    def test_runtime_paths_match_openapi_without_legacy_routes(self):
        paths = self.client.get("/openapi.json").json()["paths"]
        self.assertEqual(paths, CONTRACT["paths"])
        for path, methods in paths.items():
            for method, operation in methods.items():
                result = self.client.request(method, path)
                self.assertEqual(
                    result.status_code,
                    200
                    if path == "/health"
                    else 404
                    if operation["x-access"] == "receipt"
                    else 401,
                    path,
                )
                if method in {"post", "delete"}:
                    self.assertIn(
                        "Idempotency-Key", [p["name"] for p in operation["parameters"]]
                    )
        self.check_error(self.client.post("/v1/ocr"), 404, "NOT_FOUND")

    def test_default_health_and_missing_dependencies(self):
        with patch.dict("os.environ", {"SUPABASE_URL": ""}):
            client = TestClient(create_app())
        self.addCleanup(client.close)
        self.assertEqual(
            client.get("/health").json(), {"status": "degraded", "api_version": "1"}
        )
        self.assertEqual(
            self.check_error(
                client.get("/v1/me", headers=self.auth), 503, "AUTH_UNAVAILABLE"
            )["retryable"],
            True,
        )

    def test_missing_invalid_revoked_and_terms_required(self):
        r = self.client.get("/v1/me", headers={"X-Request-ID": "ignored"})
        self.assertEqual(r.headers["WWW-Authenticate"], "Bearer")
        self.assertNotEqual(
            self.check_error(r, 401, "UNAUTHORIZED")["request_id"], "ignored"
        )
        self.check_error(
            self.client.get("/v1/me", headers={"Authorization": "Bearer invalid"}),
            401,
            "UNAUTHORIZED",
        )
        self.backend.access_state = Access(live_session=False)
        self.check_error(
            self.client.get("/v1/me", headers=self.auth), 401, "SESSION_REVOKED"
        )
        self.backend.access_state = Access(live_session=True)
        self.check_error(
            self.client.get("/v1/me", headers=self.auth), 404, "PROFILE_NOT_READY"
        )
        self.backend.access_state = Access(live_session=True, role="learner")
        self.assertTrue(
            self.client.get("/v1/me", headers=self.auth).json()["terms_required"]
        )
        self.check_error(
            self.client.get("/v1/jobs", headers=self.auth), 403, "TERMS_REQUIRED"
        )
        self.backend.access_state = Access(
            live_session=True, deleting=True, role="learner"
        )
        self.check_error(
            self.client.get("/v1/me", headers=self.auth), 403, "ACCOUNT_DELETING"
        )

    def test_request_schema_and_response_allowlist(self):
        self.check_error(
            self.client.post(
                "/v1/roleplay/sessions",
                headers=self.auth,
                json={"scenario_id": "tourist", "hsk_level": 1},
            ),
            422,
            "INVALID_INPUT",
        )
        self.check_error(
            self.client.post(
                "/v1/roleplay/sessions",
                headers=self.mutate,
                json={"scenario_id": "tourist", "hsk_level": 1, "user_id": str(OTHER)},
            ),
            422,
            "INVALID_INPUT",
        )
        self.check_error(
            self.client.post(
                "/v1/tts",
                headers=self.mutate,
                json={"kind": "question", "revision_id": str(JOB)},
            ),
            422,
            "INVALID_INPUT",
        )
        self.check_error(
            self.client.post(
                "/v1/tts",
                headers=self.mutate,
                json={"kind": "vocabulary", "revision_id": str(JOB), "text": "你好"},
            ),
            422,
            "INVALID_INPUT",
        )
        self.check_error(
            self.client.get("/v1/jobs?limit=101", headers=self.auth),
            422,
            "INVALID_INPUT",
        )
        r = self.client.get("/v1/jobs?status=active", headers=self.auth)
        self.assertEqual(r.json(), {"items": [], "next_cursor": None})
        self.assertEqual(
            self.backend.calls[-1].query, {"limit": 20, "status": "active"}
        )
        self.backend.extra_output = True
        result = self.client.get("/v1/me", headers=self.auth)
        self.check_error(result, 500, "INTERNAL_ERROR")
        self.assertNotIn("must-not-leak", result.text)

    def test_upload_limits_format_decoding_and_audio_duration(self):
        def upload(path, field, data, mime):
            return self.client.post(
                path, headers=self.mutate, files={field: ("sample", data, mime)}
            )

        self.check_error(
            upload("/v1/handwriting/predict", "image", b"bad", "image/png"),
            422,
            "INVALID_CANVAS",
        )
        self.check_error(
            upload("/v1/handwriting/predict", "image", png(), "image/jpeg"),
            415,
            "INVALID_FILE_TYPE",
        )
        self.check_error(
            upload(
                "/v1/handwriting/predict", "image", bytes(1024 * 1024 + 1), "image/png"
            ),
            413,
            "FILE_TOO_LARGE",
        )
        self.check_error(
            upload("/v1/ocr/jobs", "wrong", png(), "image/png"), 422, "INVALID_INPUT"
        )
        self.check_error(
            upload("/v1/handwriting/predict", "image", png(), "image/png"),
            503,
            "MODEL_UNAVAILABLE",
        )
        audio = f"/v1/roleplay/sessions/{SESSION}/transcription-jobs"
        self.check_error(
            upload(audio, "audio", wav(21), "audio/wav"), 422, "INVALID_AUDIO"
        )
        self.assertEqual(upload(audio, "audio", wav(1), "audio/wav").status_code, 202)
        self.assertEqual(self.backend.calls[-1].path, {"session_id": str(SESSION)})

    def test_ocr_key_replay_and_owner_context_with_fixture(self):
        def ocr(data):
            return self.client.post(
                "/v1/ocr/jobs",
                headers=self.mutate,
                files={"image": ("scan.png", data, "image/png")},
            )

        first = ocr(png())
        self.assertEqual(first.status_code, 202)
        replay = ocr(png())
        self.assertEqual(replay.json(), first.json())
        self.assertEqual(replay.headers["Idempotency-Replayed"], "true")
        self.check_error(ocr(png("black")), 409, "IDEMPOTENCY_CONFLICT")
        self.assertEqual(self.backend.calls[0].identity.user_id, USER)
        self.assertEqual(self.backend.calls[0].idempotency_key, KEY)
        self.assertEqual(len(self.backend.jobs), 1)
        own = self.client.get(f"/v1/jobs/{JOB}", headers=self.auth)
        self.assertEqual(own.status_code, 200, own.text)
        self.check_error(
            self.client.get(
                f"/v1/jobs/{JOB}", headers={"Authorization": "Bearer learner-b"}
            ),
            404,
            "NOT_FOUND",
        )


class JwtTests(unittest.TestCase):
    def test_real_signature_and_claim_validation_with_stub_key_source(self):
        signing = ec.generate_private_key(ec.SECP256R1())
        verifier = SupabaseJwtVerifier("https://project.supabase.co")
        key = SimpleNamespace(algorithm_name="ES256", key=signing.public_key())
        payload = {
            "iss": verifier.issuer,
            "aud": "authenticated",
            "role": "authenticated",
            "sub": str(USER),
            "session_id": str(SESSION),
            "exp": int(time.time()) + 120,
        }
        client = TestClient(create_app(verifier=verifier, backend=FixtureBackend()))
        self.addCleanup(client.close)

        def call(**changes):
            token = jwt.encode(
                {**payload, **changes},
                signing,
                algorithm="ES256",
                headers={"kid": "test"},
            )
            return client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})

        with patch.object(verifier.jwks, "get_signing_key", return_value=key):
            self.assertEqual(call().json()["id"], str(USER))
            for changes in [
                {"exp": int(time.time()) - 10},
                {"aud": "wrong"},
                {"is_anonymous": True},
                {"session_id": "invalid"},
                {"iss": "https://other.supabase.co/auth/v1"},
                {"role": "service_role"},
                {"nbf": int(time.time()) + 100},
            ]:
                self.assertEqual(call(**changes).status_code, 401, changes)
            forged = jwt.encode(
                payload,
                ec.generate_private_key(ec.SECP256R1()),
                algorithm="ES256",
                headers={"kid": "test"},
            )
            self.assertEqual(
                client.get(
                    "/v1/me", headers={"Authorization": f"Bearer {forged}"}
                ).status_code,
                401,
            )
        with patch.object(
            verifier.jwks, "get_signing_key", side_effect=PyJWKClientError
        ):
            self.assertEqual(call().status_code, 401)
        with patch.object(
            verifier.jwks, "get_signing_key", side_effect=PyJWKClientConnectionError
        ):
            self.assertEqual(call().status_code, 503)
