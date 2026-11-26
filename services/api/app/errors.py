from uuid import uuid4

from fastapi import Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(
        self, status: int, code: str, message: str, *, retryable: bool = False
    ):
        super().__init__(code)
        self.status = status
        self.code = code
        self.message = message
        self.retryable = retryable


def request_id(request: Request) -> str:
    if not hasattr(request.state, "request_id"):
        request.state.request_id = str(uuid4())
    return request.state.request_id


def error_response(request: Request, error: ApiError) -> JSONResponse:
    headers = {"WWW-Authenticate": "Bearer"} if error.status == 401 else {}
    if error.status == 429 or (error.status == 503 and error.retryable):
        headers["Retry-After"] = "5"
    return JSONResponse(
        {
            "code": error.code,
            "message": error.message,
            "retryable": error.retryable,
            "request_id": request_id(request),
        },
        status_code=error.status,
        headers=headers,
    )


def invalid_input() -> ApiError:
    return ApiError(422, "INVALID_INPUT", "Dữ liệu gửi lên không hợp lệ.")


def unavailable(code: str, message: str) -> ApiError:
    return ApiError(503, code, message, retryable=True)
