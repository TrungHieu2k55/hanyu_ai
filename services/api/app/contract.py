import json
from collections.abc import AsyncIterator
from pathlib import Path
from typing import Any
from uuid import UUID

from fastapi import Request
from jsonschema import Draft202012Validator
from python_multipart.exceptions import MultipartParseError
from starlette.concurrency import run_in_threadpool
from starlette.datastructures import UploadFile
from starlette.formparsers import MultiPartException, MultiPartParser

from .errors import invalid_input, request_id
from .media import MIB, invalid_type, media_limit, too_large, verify_audio, verify_image
from .ports import Call, Identity, Media

CONTRACT = json.loads(
    Path(__file__).with_name("openapi.json").read_text(encoding="utf-8")
)
JSON_LIMIT = 64 * 1024


def validator(schema: dict[str, Any]) -> Draft202012Validator:
    return Draft202012Validator(
        {"components": CONTRACT["components"], **schema},
        format_checker=Draft202012Validator.FORMAT_CHECKER,
    )


class RequestTooLarge(MultiPartException):
    pass


async def limited_body(request: Request, size: int) -> AsyncIterator[bytes]:
    length = request.headers.get("content-length")
    if length is not None:
        try:
            declared = int(length)
        except ValueError as exc:
            raise invalid_input() from exc
        if declared < 0:
            raise invalid_input()
        if declared > size:
            raise RequestTooLarge("body limit exceeded")
    read = 0
    async for chunk in request.stream():
        read += len(chunk)
        if read > size:
            raise RequestTooLarge("body limit exceeded")
        yield chunk


def reject_duplicate_keys(items: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def reject_nonfinite(_: str) -> Any:
    raise ValueError("nonfinite number")


async def json_body(request: Request, schema: dict[str, Any]) -> dict[str, Any]:
    if (
        request.headers.get("content-type", "").partition(";")[0].strip().lower()
        != "application/json"
    ):
        raise invalid_type()
    try:
        data = bytearray()
        async for chunk in limited_body(request, JSON_LIMIT):
            data.extend(chunk)
        parsed = json.loads(
            data.decode("utf-8"),
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_nonfinite,
        )
    except (UnicodeError, ValueError, RecursionError) as exc:
        raise invalid_input() from exc
    if not isinstance(parsed, dict) or not validator(schema).is_valid(parsed):
        raise invalid_input()
    return parsed


async def multipart_body(
    request: Request, field: str, operation: str, fields=None
) -> tuple[Media, dict | None]:
    if (
        request.headers.get("content-type", "").partition(";")[0].strip().lower()
        != "multipart/form-data"
    ):
        raise invalid_type()
    limit = media_limit(operation)
    parser = MultiPartParser(
        request.headers,
        limited_body(request, limit + 32 * 1024),
        max_files=1,
        max_fields=len(fields or {}),
    )
    try:
        form = await parser.parse()
    except RequestTooLarge:
        raise
    except (MultiPartException, MultipartParseError) as exc:
        raise invalid_input() from exc
    try:
        fields = fields or {}
        values = form.getlist(field)
        if (
            set(form) != {field, *fields}
            or len(values) != 1
            or not isinstance(values[0], UploadFile)
        ):
            raise invalid_input()
        body = {}
        for name, schema in fields.items():
            parts = form.getlist(name)
            if len(parts) != 1 or not isinstance(parts[0], str):
                raise invalid_input()
            value = parts[0]
            if schema.get("type") == "integer":
                try:
                    value = int(value)
                except ValueError as exc:
                    raise invalid_input() from exc
            if not validator(schema).is_valid(value):
                raise invalid_input()
            body[name] = value
        upload = values[0]
        data = await upload.read(limit + 1)
        if len(data) > limit:
            raise too_large()
        media = Media(data=data, content_type=(upload.content_type or "").lower())
    finally:
        await form.close()
    if operation == "updateAvatar" and media.content_type not in {
        "image/jpeg",
        "image/png",
    }:
        raise invalid_type()
    if operation == "uploadLearningMedia":
        if body["kind"] == "import_file":
            if len(media.data) > 5 * MIB:
                raise too_large()
            if media.content_type not in {"text/csv", "text/plain", "application/csv"}:
                raise invalid_type()
            media = Media(data=media.data, content_type="text/csv")
        else:
            await verify_audio(media, learning=True)
    elif field == "audio":
        await verify_audio(media)
    else:
        await run_in_threadpool(
            verify_image, media, canvas=operation == "predictCharacter"
        )
    return media, body or None


def read_parameters(
    request: Request, rules: list[dict[str, Any]]
) -> tuple[dict, dict, UUID | None]:
    path: dict[str, Any] = {}
    query: dict[str, Any] = {}
    query_names = {p["name"] for p in rules if p["in"] == "query"}
    if set(request.query_params) - query_names:
        raise invalid_input()
    key = None
    for rule in rules:
        name, location, schema = rule["name"], rule["in"], rule["schema"]
        if location == "path":
            matches = [request.path_params[name]]
        elif location == "query":
            matches = request.query_params.getlist(name)
        else:
            matches = request.headers.getlist(name)
        if len(matches) > 1 or (not matches and rule.get("required")):
            raise invalid_input()
        if not matches:
            if location == "query" and "default" in schema:
                query[name] = schema["default"]
            continue
        value: Any = matches[0]
        if schema.get("type") == "integer":
            try:
                value = int(value)
            except ValueError as exc:
                raise invalid_input() from exc
        if not validator(schema).is_valid(value):
            raise invalid_input()
        if schema.get("format") == "uuid":
            try:
                value = str(UUID(value))
            except ValueError as exc:
                raise invalid_input() from exc
        if location == "path":
            path[name] = value
        elif location == "query":
            query[name] = value
        else:
            key = UUID(value)
    return path, query, key


async def parse_call(
    request: Request, operation: dict[str, Any], identity: Identity
) -> Call:
    path, query, key = read_parameters(request, operation.get("parameters", []))
    name = operation["operationId"]
    media, body = None, None
    content = operation.get("requestBody", {}).get("content", {})
    try:
        if "application/json" in content:
            body = await json_body(request, content["application/json"]["schema"])
        elif "multipart/form-data" in content:
            schema = content["multipart/form-data"]["schema"]
            (field,) = (
                k
                for k, v in schema["properties"].items()
                if v.get("format") == "binary"
            )
            fields = {k: v for k, v in schema["properties"].items() if k != field}
            media, body = await multipart_body(request, field, name, fields)
        else:
            async for chunk in limited_body(request, JSON_LIMIT):
                if chunk:
                    raise invalid_input()
    except RequestTooLarge as exc:
        raise too_large() from exc
    return Call(name, identity, path, query, key, body, media, request_id(request))
