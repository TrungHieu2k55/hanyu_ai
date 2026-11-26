import argparse
import ipaddress
import os
import re
from urllib.parse import urlsplit

import httpx

from .contract import CONTRACT, validator

LEARNER_PATHS = (
    "/v1/me",
    "/v1/vocabulary",
    "/v1/study/lessons",
    "/v1/roleplay/scenarios",
    "/v1/tests",
)
ERROR_CODE = re.compile(r"[A-Z][A-Z0-9_]{0,63}")


def api_origin(value: str) -> str:
    message = "Use an HTTPS API origin or an HTTP loopback address."
    try:
        url = urlsplit(value)
        host, port = url.hostname, url.port
    except ValueError:
        raise argparse.ArgumentTypeError(message) from None
    if (
        not host
        or url.username is not None
        or url.password is not None
        or url.path not in {"", "/"}
        or url.query
        or url.fragment
    ):
        raise argparse.ArgumentTypeError(message)
    try:
        loopback = ipaddress.ip_address(host).is_loopback
    except ValueError:
        loopback = host == "localhost"
    if url.scheme != "https" and not (url.scheme == "http" and loopback):
        raise argparse.ArgumentTypeError(message)
    authority = f"[{host}]" if ":" in host else host
    return f"{url.scheme}://{authority}" + (f":{port}" if port is not None else "")


def check(
    client: httpx.Client,
    path: str,
    expected_status: int,
    *,
    token: str = "",
    require_ready: bool = False,
) -> bool:
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    try:
        response = client.get(path, headers=headers)
    except httpx.HTTPError as error:
        print(f"FAIL GET {path}: {type(error).__name__}")
        return False
    try:
        body = response.json()
    except ValueError:
        body = None

    actual = f"HTTP {response.status_code}"
    if response.status_code != expected_status:
        code = body.get("code") if isinstance(body, dict) else None
        if isinstance(code, str) and ERROR_CODE.fullmatch(code):
            actual += f" ({code})"
        print(f"FAIL GET {path}: expected HTTP {expected_status}, got {actual}")
        return False

    if expected_status == 401:
        if not isinstance(body, dict) or body.get("code") != "UNAUTHORIZED":
            print(f"FAIL GET {path}: expected the UNAUTHORIZED error envelope")
            return False
    else:
        definition = CONTRACT["paths"][path]["get"]["responses"]["200"]
        schema = definition["content"]["application/json"]["schema"]
        if not validator(schema).is_valid(body):
            print(f"FAIL GET {path}: response does not match OpenAPI")
            return False
        if path == "/health":
            actual += f" ({body['status']})"
            if require_ready and body["status"] != "ok":
                print(f"FAIL GET {path}: expected ready, got {actual}")
                return False
        elif isinstance(body.get("items"), list):
            actual += f" ({len(body['items'])} items)"

    print(f"PASS GET {path}: {actual}")
    return True


def run_checks(
    client: httpx.Client, *, token: str = "", require_ready: bool = False
) -> int:
    results = [
        check(client, "/health", 200, require_ready=require_ready),
        check(client, "/v1/me", 401),
    ]
    if token:
        results.extend(check(client, path, 200, token=token) for path in LEARNER_PATHS)
    else:
        print("SKIP learner checks: HANYU_SMOKE_TOKEN is unset")
    return 0 if all(results) else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only smoke checks for Hanyu API.")
    parser.add_argument("base_url", type=api_origin)
    parser.add_argument(
        "--require-ready",
        action="store_true",
        help="Fail unless /health is ok and a learner token is supplied.",
    )
    args = parser.parse_args()
    token = os.getenv("HANYU_SMOKE_TOKEN", "").strip()
    if args.require_ready and not token:
        parser.error("--require-ready needs HANYU_SMOKE_TOKEN")
    with httpx.Client(
        base_url=args.base_url, timeout=10, follow_redirects=False, trust_env=False
    ) as client:
        return run_checks(client, token=token, require_ready=args.require_ready)


if __name__ == "__main__":
    raise SystemExit(main())
