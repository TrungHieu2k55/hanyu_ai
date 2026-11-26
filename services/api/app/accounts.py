import hashlib
import json
import os
from pathlib import Path
from unicodedata import category
from uuid import UUID, uuid4

from .contract import validator
from .errors import ApiError, invalid_input, unavailable
from .operations import lock_owner, receipt, write_receipt
from .ports import Access, Call, Identity, Result
from .postgres import Database, many, one

_TERMS = "terms"
_TRAINING = "training_handwriting"
_CONSENT_COLUMNS = "id, purpose, policy_version, granted, occurred_at"


def policies_from_env(terms_version: str) -> dict | None:
    path = os.getenv("HANYU_POLICY_BUNDLE_FILE", "").strip()
    if not path:
        return None
    try:
        with Path(path).open(encoding="utf-8") as file:
            raw = file.read(4_000_001)
        if len(raw) > 4_000_000:
            raise ValueError
        bundle = json.loads(raw)
    except (OSError, ValueError) as exc:
        raise ValueError(
            "HANYU_POLICY_BUNDLE_FILE must contain a UTF-8 Policy object"
        ) from exc
    if (
        not validator({"$ref": "#/components/schemas/Policy"}).is_valid(bundle)
        or not all(value.strip() for value in bundle.values())
        or bundle["terms_version"] != terms_version
    ):
        raise ValueError("Invalid policy bundle or mismatched HANYU_TERMS_VERSION")
    return bundle


def fingerprint(call: Call, operation: str, body: dict) -> str:
    intent = [str(call.identity.user_id), operation, body]
    return hashlib.sha256(json.dumps(intent, sort_keys=True).encode()).hexdigest()


def display_name(value: str) -> str:
    name = value.strip()
    if not name or any(category(char) in {"Cc", "Cs"} for char in name):
        raise invalid_input()
    return name


def consent_dto(row: dict) -> dict:
    return {
        **row,
        "id": str(row["id"]),
        "occurred_at": row["occurred_at"].isoformat(),
    }


class Accounts:
    def __init__(self, db: Database, policies: dict | None = None):
        self.db = db
        self._policies = policies.copy() if policies is not None else None

    def _current_policies(self) -> dict:
        if self._policies is None:
            raise unavailable("CONTENT_UNAVAILABLE", "Chưa có bộ chính sách hiện hành.")
        return self._policies

    @staticmethod
    def _check_version(received: str, current: str) -> None:
        if received != current:
            raise ApiError(
                409, "POLICY_OUTDATED", "Hãy đọc và xác nhận bản chính sách mới."
            )

    async def policies(self, call: Call) -> Result:
        return Result(200, self._current_policies())

    async def update(self, call: Call) -> Result:
        owner = call.identity.user_id
        body = call.body.copy()
        if "display_name" in body:
            body["display_name"] = display_name(body["display_name"])
        operation = "profile.update"
        digest = fingerprint(call, operation, body)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._profile(tx, owner), replayed=True)
            updated = await one(
                tx,
                """
                UPDATE app.profiles SET display_name = coalesce(%s, display_name),
                    hsk_target = coalesce(%s, hsk_target), daily_minutes = coalesce(%s, daily_minutes),
                    sound_enabled = coalesce(%s, sound_enabled), version = version + 1,
                    updated_at = clock_timestamp()
                WHERE id = %s AND owner_id = %s AND version = %s RETURNING id
                """,
                (
                    body.get("display_name"),
                    body.get("hsk_target"),
                    body.get("daily_minutes"),
                    body.get("sound_enabled"),
                    owner,
                    owner,
                    body["expected_version"],
                ),
            )
            if updated is None:
                raise ApiError(409, "STALE_VERSION", "Hồ sơ đã thay đổi. Hãy tải lại.")
            await write_receipt(tx, call, operation, digest, owner, "profile")
            return Result(200, await self._profile(tx, owner))

    async def bootstrap(self, call: Call) -> Result:
        owner = call.identity.user_id
        body = {
            "hsk_target": 1,
            "daily_minutes": 15,
            **call.body,
        }
        body["display_name"] = display_name(body["display_name"])
        operation = "profile.bootstrap"
        digest = fingerprint(call, operation, body)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.require_access(tx, call.identity, terms=False, profile=False)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                profile = await self._profile(tx, owner)
                if profile is None:
                    raise ApiError(
                        410, "RESOURCE_GONE", "Hồ sơ đã lưu không còn khả dụng."
                    )
                return Result(200, profile, replayed=True)
            existing = await self._profile(tx, owner)
            if existing is not None:
                await write_receipt(tx, call, operation, digest, owner, "profile")
                return Result(200, existing)
            policies = self._current_policies()
            self._check_version(body["terms_version"], policies["terms_version"])
            self._check_version(
                body["training_policy_version"], policies["training_policy_version"]
            )
            await tx.execute(
                """
                INSERT INTO app.profiles (id, owner_id, display_name, hsk_target, daily_minutes)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    owner,
                    owner,
                    body["display_name"],
                    body["hsk_target"],
                    body["daily_minutes"],
                ),
            )
            operation_id = await write_receipt(
                tx, call, operation, digest, owner, "profile"
            )
            await self._insert_consent(
                tx, owner, operation_id, uuid4(), _TERMS, body["terms_version"], True
            )
            await self._insert_consent(
                tx,
                owner,
                operation_id,
                uuid4(),
                _TRAINING,
                body["training_policy_version"],
                body["training_opt_in"],
            )
            return Result(201, await self._profile(tx, owner))

    async def list_consents(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.require_access(tx, call.identity, terms=False)
            rows = await many(
                tx,
                f"""
                SELECT DISTINCT ON (purpose) {_CONSENT_COLUMNS}
                FROM app.consent_events
                WHERE owner_id = %s
                ORDER BY purpose, occurred_at DESC, id DESC
                """,
                (call.identity.user_id,),
            )
        return Result(200, {"items": [consent_dto(row) for row in rows]})

    async def record_consent(self, call: Call) -> Result:
        owner = call.identity.user_id
        body = call.body
        operation = "consent.record"
        digest = fingerprint(call, operation, body)
        purpose, version, granted = (
            body["purpose"],
            body["policy_version"],
            body["granted"],
        )
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.require_access(tx, call.identity, terms=False)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                row = await one(
                    tx,
                    f"SELECT {_CONSENT_COLUMNS} FROM app.consent_events WHERE owner_id = %s AND id = %s",
                    (owner, previous),
                )
                if row is None:
                    raise ApiError(
                        410, "RESOURCE_GONE", "Lựa chọn đã lưu không còn khả dụng."
                    )
                return Result(201, consent_dto(row), replayed=True)
            version_key = (
                "terms_version" if purpose == _TERMS else "training_policy_version"
            )
            self._check_version(version, self._current_policies()[version_key])
            event_id = uuid4()
            operation_id = await write_receipt(
                tx, call, operation, digest, event_id, "consent"
            )
            event = await self._insert_consent(
                tx, owner, operation_id, event_id, purpose, version, granted
            )
            return Result(201, consent_dto(event))

    @staticmethod
    async def _insert_consent(
        tx, owner, operation_id, event_id, purpose, version, granted
    ) -> dict:
        return await one(
            tx,
            f"""
            INSERT INTO app.consent_events
                (owner_id, operation_id, id, purpose, policy_version, granted, occurred_at)
            VALUES (%s, %s, %s, %s, %s, %s, clock_timestamp())
            RETURNING {_CONSENT_COLUMNS}
            """,
            (owner, operation_id, event_id, purpose, version, granted),
        )

    async def _read_access(self, tx, who: Identity) -> Access:
        flags = await one(
            tx,
            "SELECT * FROM app_private.read_access(%s, %s, %s)",
            (who.user_id, who.session_id, self.db.subject_hash(who.user_id)),
        )
        if flags is None:
            raise unavailable("AUTH_UNAVAILABLE", "Chưa kiểm tra được phiên đăng nhập.")
        if not flags["live_session"] or flags["deleting"]:
            return Access(**flags)
        profile = await self._profile(tx, who.user_id)
        if profile is None:
            return Access(**flags)
        return Access(
            **flags, role=profile["role"], terms_required=profile["terms_required"]
        )

    async def access(self, identity: Identity) -> Access:
        async with self.db.transaction(identity, auth=True) as tx:
            return await self._read_access(tx, identity)

    async def require_access(
        self,
        tx,
        who: Identity,
        *,
        terms: bool = True,
        profile: bool = True,
        admin: bool = False,
    ) -> None:
        access = await self._read_access(tx, who)
        if not access.live_session:
            raise ApiError(401, "SESSION_REVOKED", "Phiên đăng nhập đã bị thu hồi.")
        if access.deleting:
            raise ApiError(403, "ACCOUNT_DELETING", "Tài khoản đang được xử lý xóa.")
        if profile and access.role is None:
            raise ApiError(404, "PROFILE_NOT_READY", "Hồ sơ học tập chưa sẵn sàng.")
        if admin and access.role != "admin":
            raise ApiError(403, "FORBIDDEN", "Cần quyền quản trị.")
        if terms and access.terms_required:
            raise ApiError(403, "TERMS_REQUIRED", "Hãy xác nhận điều khoản hiện hành.")

    async def _profile(self, tx, user: UUID) -> dict | None:
        profile = await one(
            tx,
            """
            SELECT p.id, p.display_name, p.hsk_target, p.daily_minutes, p.sound_enabled,
                   p.role, p.avatar_media_id, p.version,
                   NOT coalesce((
                     SELECT c.granted AND c.policy_version = %s FROM app.consent_events c
                     WHERE c.owner_id = p.id AND c.purpose = 'terms'
                     ORDER BY c.occurred_at DESC, c.id DESC LIMIT 1
                   ), false) AS terms_required
            FROM app.profiles p WHERE p.id = %s AND p.owner_id = %s
            """,
            (self.db.terms_version, user, user),
        )
        if profile is not None:
            profile["id"] = str(profile["id"])
            profile["avatar_media_id"] = (
                str(profile["avatar_media_id"]) if profile["avatar_media_id"] else None
            )
        return profile

    async def get_me(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.require_access(tx, call.identity, terms=False)
            profile = await self._profile(tx, call.identity.user_id)
        if profile is None:
            raise ApiError(404, "PROFILE_NOT_READY", "Hồ sơ học tập chưa sẵn sàng.")
        return Result(200, profile)
