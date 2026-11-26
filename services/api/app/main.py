import logging
import os
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response
from starlette.exceptions import HTTPException
from starlette.middleware.cors import CORSMiddleware
from starlette.requests import ClientDisconnect

from .auth import SupabaseJwtVerifier, authorize
from .backend import postgres_backend_from_env
from .contract import CONTRACT, parse_call, validator
from .deletions import receipt_token
from .errors import ApiError, error_response, invalid_input, request_id
from .ports import Backend, TokenVerifier

logger = logging.getLogger(__name__)


def create_app(
    *,
    verifier: TokenVerifier | None = None,
    backend: Backend | None = None,
) -> FastAPI:
    verifier = (
        verifier if verifier is not None else SupabaseJwtVerifier.from_environment()
    )
    backend = backend if backend is not None else postgres_backend_from_env()
    app = FastAPI(title=CONTRACT["info"]["title"], version="1.0.0", redoc_url=None)

    origins = [
        origin.strip()
        for origin in os.getenv("HANYU_CORS_ORIGINS", "").split(",")
        if origin.strip()
    ]
    if "*" in origins:
        raise ValueError("HANYU_CORS_ORIGINS must explicitly list allowed origins")
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE"],
            allow_headers=["Authorization", "Idempotency-Key", "Content-Type"],
            expose_headers=[
                "X-Request-ID",
                "X-Schema-Version",
                "Idempotency-Replayed",
                "Retry-After",
            ],
        )

    @app.middleware("http")
    async def apply_response_headers(request: Request, call_next):
        key = request_id(request)
        try:
            response = await call_next(request)
        except ClientDisconnect:
            response = error_response(request, invalid_input())
        except Exception:  # noqa: BLE001 - HTTP boundary protects error details.
            logger.error("request_id=%s code=INTERNAL_ERROR", key)
            response = error_response(request, internal_error())
        response.headers["X-Request-ID"] = key
        response.headers["X-Schema-Version"] = "1"
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.exception_handler(ApiError)
    async def api_error(request: Request, error: ApiError) -> JSONResponse:
        return error_response(request, error)

    @app.exception_handler(RequestValidationError)
    async def validation_error(
        request: Request, _: RequestValidationError
    ) -> JSONResponse:
        return error_response(request, invalid_input())

    @app.exception_handler(HTTPException)
    async def http_error(request: Request, error: HTTPException) -> JSONResponse:
        code = "NOT_FOUND" if error.status_code == 404 else "INVALID_INPUT"
        return error_response(
            request,
            ApiError(error.status_code, code, "Đường dẫn hoặc thao tác không hợp lệ."),
        )

    def schema() -> dict:
        return CONTRACT

    app.openapi = schema

    def endpoint(operation: dict[str, Any]):
        scope = operation["x-access"]
        response_schemas = {
            int(status): validator(schema)
            for status, response in operation["responses"].items()
            if status.startswith("2")
            if (
                schema := response.get("content", {})
                .get("application/json", {})
                .get("schema")
            )
        }

        async def run(request: Request) -> Response:
            if operation["operationId"] == "health":
                status = (
                    "ok"
                    if verifier.configured and await backend.healthy()
                    else "degraded"
                )
                return JSONResponse({"status": status, "api_version": "1"})

            name = operation["operationId"]
            identity = None
            key = None
            if scope == "receipt":
                token = receipt_token(request.headers.getlist("authorization"))
                result = await backend.deletion_status(token)
            else:
                identity = await authorize(
                    request,
                    verifier,
                    backend,
                    scope,
                    allow_unprovisioned=name in {"currentPolicies", "bootstrapMe"},
                )
                call = await parse_call(request, operation, identity)
                key = call.idempotency_key
                result = await backend.execute(call)
            if (
                result.status == 204
                and "204" in operation["responses"]
                and result.body is None
            ):
                response = Response(status_code=204)
            elif (
                (output := response_schemas.get(result.status))
                and result.body is not None
                and output.is_valid(result.body)
                and (
                    name not in {"getMe", "bootstrapMe", "updateMe", "updateAvatar"}
                    or (
                        identity is not None
                        and result.body.get("id") == str(identity.user_id)
                    )
                )
            ):
                response = JSONResponse(result.body, status_code=result.status)
            else:
                logger.error(
                    "request_id=%s code=INVALID_BACKEND_RESPONSE", request_id(request)
                )
                raise internal_error()
            if result.replayed and key is not None:
                response.headers["Idempotency-Replayed"] = "true"
            return response

        return run

    for path, operations in CONTRACT["paths"].items():
        for method, operation in operations.items():
            app.add_api_route(
                path,
                endpoint(operation),
                methods=[method.upper()],
                name=operation["operationId"],
            )
    return app


def internal_error() -> ApiError:
    return ApiError(500, "INTERNAL_ERROR", "Máy chủ chưa hoàn tất thao tác.")


app = create_app()
