import csv
import hashlib
import io
import json
from re import fullmatch
from unicodedata import normalize
from uuid import NAMESPACE_URL, uuid4, uuid5

from psycopg.types.json import Jsonb

from .accounts import Accounts, fingerprint
from .admin_content import AdminContent
from .contract import validator
from .errors import ApiError, invalid_input, unavailable
from .operations import lock_owner, lock_vocabulary_writes, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .storage import ImageStorage
from .vocabulary import missing, uuid_str

_FIELDS = (
    "id",
    "status",
    "mapping_version",
    "validated_hash",
    "total_rows",
    "valid_rows",
    "invalid_rows",
    "inserted_rows",
    "updated_rows",
)
_REQUIRED = {
    "hanzi",
    "reading_key",
    "pinyin_display",
    "vietnamese",
    "source_name",
    "source_external_id",
    "source_version",
    "license",
}
_AUDIO_EXT = {
    "audio/wav": "wav",
    "audio/mpeg": "mp3",
    "audio/mp4": "m4a",
    "audio/ogg": "ogg",
}


def batch_dto(row):
    return {k: str(row[k]) if k == "id" else row[k] for k in _FIELDS}


def csv_records(data):
    try:
        decoded = data.decode("utf-8-sig")
        if "\0" in decoded:
            raise ValueError
        rows = list(csv.reader(io.StringIO(decoded, newline=""), strict=True))
    except (UnicodeError, csv.Error, ValueError) as exc:
        raise invalid_input() from exc
    if not 2 <= len(rows) <= 1001 or len(set(rows[0])) != len(rows[0]):
        raise invalid_input()
    return rows[0], rows[1:]


def stage_rows(header, rows, columns):
    fields = {
        target: header.index(source)
        for source, target in columns.items()
        if source in header
    }
    validator_ = validator({"$ref": "#/components/schemas/AdminWordCreate"})
    result = []
    for number, values in enumerate(rows, 2):
        errors = []
        row = {
            target: normalize("NFC", values[index].strip())
            for target, index in fields.items()
            if index < len(values)
        }
        candidate = None
        if len(values) != len(header) or not _REQUIRED <= {
            k for k, v in row.items() if v
        }:
            errors.append(
                {
                    "field": "row",
                    "code": "MISSING_DATA",
                    "message": "Thiếu cột, giá trị hoặc sai số trường.",
                }
            )
        else:
            content = {
                k: v
                for k, v in row.items()
                if k not in {"hanzi", "reading_key", "sense_id", "hsk_level"}
            }
            if row.get("hsk_level"):
                content["hsk_level"] = (
                    int(row["hsk_level"])
                    if row["hsk_level"] in {"1", "2", "3"}
                    else row["hsk_level"]
                )
            reading = "".join(
                row["reading_key"].lower().replace("ü", "v").replace("u:", "v").split()
            )
            candidate = {
                "hanzi": row["hanzi"],
                "reading_key": reading,
                "content": content,
            }
            if row.get("sense_id"):
                candidate["sense_id"] = row["sense_id"]
            if (
                not validator_.is_valid(candidate)
                or fullmatch(r"(?:[a-z]+[1-5])+", reading) is None
            ):
                errors.append(
                    {
                        "field": "row",
                        "code": "INVALID_VALUE",
                        "message": "Kiểm lại Pinyin, HSK, định danh và độ dài nội dung.",
                    }
                )
        result.append(
            {
                "line_number": number,
                "errors": errors,
                "content": candidate if not errors else None,
            }
        )
    return result


def comparable_content(content: dict) -> tuple:
    return (
        *(
            content.get(field)
            for field in (
                "pinyin_display",
                "vietnamese",
                "hsk_level",
                "license",
                "part_of_speech",
            )
        ),
        content.get("examples", []),
    )


def source_conflict(message: str) -> ApiError:
    return ApiError(409, "SOURCE_VERSION_CONFLICT", message)


class AdminImport:
    def __init__(self, db: Database, accounts: Accounts, storage: ImageStorage | None):
        self.db = db
        self.accounts = accounts
        self.storage = storage

    def _storage(self):
        if self.storage is None:
            raise unavailable("CONTENT_UNAVAILABLE", "Kho học liệu chưa được cấu hình.")
        return self.storage

    async def upload(self, call: Call) -> Result:
        actor, media, kind = call.identity.user_id, call.media, call.body["kind"]
        operation = "admin.media"
        sha = hashlib.sha256(media.data).hexdigest()
        digest = fingerprint(
            call, operation, {"kind": kind, "sha": sha, "type": media.content_type}
        )
        identifier = uuid4()
        if kind == "import_file":
            csv_records(media.data)
            object_key = f"imports/{identifier}.csv"
        else:
            object_key = f"exams/{identifier}.{_AUDIO_EXT[media.content_type]}"
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._upload_dto(tx, prior), replayed=True)
            await tx.execute(
                """INSERT INTO app.admin_media_uploads(id,owner_id,kind,object_key,sha256,expires_at)
                     VALUES (%s,%s,%s,%s,%s,clock_timestamp()+interval '1 hour')""",
                (
                    identifier,
                    actor if kind == "import_file" else None,
                    kind,
                    object_key,
                    sha,
                ),
            )
        await self._storage().store(object_key, media)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, actor)
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._upload_dto(tx, prior), replayed=True)
            saved = await one(
                tx,
                """UPDATE app.admin_media_uploads SET state='ready',
                      expires_at=clock_timestamp()+CASE WHEN kind='import_file' THEN interval '90 days' ELSE interval '7 days' END
                      WHERE id=%s AND state='staging' AND expires_at>clock_timestamp() RETURNING id""",
                (identifier,),
            )
            if saved is None:
                raise ApiError(410, "RESOURCE_GONE", "Tệp tải lên đã hết hạn.")
            if kind == "learning_audio":
                await tx.execute(
                    "INSERT INTO app.learning_audio(id,object_key) VALUES (%s,%s)",
                    (identifier, object_key),
                )
            op = await write_receipt(
                tx, call, operation, digest, identifier, "admin_media"
            )
            await AdminContent._audit(
                tx, actor, op, operation, kind, identifier, None, "ready"
            )
            return Result(200, await self._upload_dto(tx, identifier))

    @staticmethod
    async def _upload_dto(tx, identifier):
        row = await one(
            tx,
            "SELECT id,kind,expires_at FROM app.admin_media_uploads WHERE id=%s AND state='ready'",
            (identifier,),
        )
        if row is None:
            raise ApiError(410, "RESOURCE_GONE", "Tệp tải lên đã hết hạn.")
        return {
            "media_id": str(row["id"]),
            "kind": row["kind"],
            "state": "ready",
            "expires_at": row["expires_at"].isoformat()
            if row["kind"] == "import_file"
            else None,
        }

    @staticmethod
    async def _batch(tx, actor, batch):
        row = await one(
            tx,
            "SELECT * FROM app.import_batches WHERE owner_id=%s AND id=%s",
            (actor, batch),
        )
        if row is None:
            raise missing()
        return row

    async def start(self, call: Call) -> Result:
        actor, file_id = call.identity.user_id, call.body["file_media_id"]
        operation = "import.start"
        digest = fingerprint(call, operation, call.body)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, actor)
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(
                    201, batch_dto(await self._batch(tx, actor, prior)), replayed=True
                )
            file = await one(
                tx,
                """SELECT id FROM app.admin_media_uploads WHERE owner_id=%s AND id=%s
                AND kind='import_file' AND state='ready' AND expires_at>clock_timestamp()""",
                (actor, file_id),
            )
            if file is None:
                raise missing()
            batch = uuid4()
            await tx.execute(
                "INSERT INTO app.import_batches(id,owner_id,file_media_id) VALUES (%s,%s,%s)",
                (batch, actor, file_id),
            )
            await write_receipt(tx, call, operation, digest, batch, "import_batch")
            return Result(201, batch_dto(await self._batch(tx, actor, batch)))

    async def get(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            return Result(
                200,
                batch_dto(
                    await self._batch(tx, call.identity.user_id, call.path["batch_id"])
                ),
            )

    async def rows(self, call: Call) -> Result:
        actor, batch = call.identity.user_id, call.path["batch_id"]
        limit = call.query.get("limit", 20)
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            row = await self._batch(tx, actor, batch)
            scope = f"import:{actor}:{batch}:{row['mapping_version']}:{row['validated_hash']}"
            after = self.db.read_position(scope, call.query.get("cursor"))
            rows = await many(
                tx,
                """SELECT line_number,errors,entry_id,revision_id FROM app.import_rows
                  WHERE owner_id=%s AND batch_id=%s AND line_number>%s ORDER BY line_number LIMIT %s""",
                (actor, batch, after, limit + 1),
            )
        return Result(
            200,
            {
                "items": [
                    {
                        **row,
                        "entry_id": uuid_str(row["entry_id"]),
                        "revision_id": uuid_str(row["revision_id"]),
                    }
                    for row in rows[:limit]
                ],
                "next_cursor": self.db.position_cursor(
                    scope, rows[limit - 1]["line_number"]
                )
                if len(rows) > limit
                else None,
            },
        )

    async def map(self, call: Call) -> Result:
        actor, batch = call.identity.user_id, call.path["batch_id"]
        operation = "import.map"
        digest = fingerprint(call, operation, {**call.path, **call.body})
        mapping = call.body["columns"]
        if len(set(mapping.values())) != len(mapping) or any(
            not k.strip() for k in mapping
        ):
            raise invalid_input()
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, actor)
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            row = await self._batch(tx, actor, batch)
            if prior is not None:
                return Result(200, batch_dto(row), replayed=True)
            if row["status"] == "completed":
                raise ApiError(409, "INVALID_STATE", "Lô đã được nhập.")
            if row["mapping_version"] != call.body["expected_mapping_version"]:
                raise ApiError(409, "STALE_VERSION", "Ánh xạ đã thay đổi.")
            await tx.execute(
                """UPDATE app.import_batches SET mapping=%s,mapping_version=mapping_version+1,
                status='mapped',validated_hash=NULL,total_rows=0,valid_rows=0,invalid_rows=0
                WHERE id=%s AND owner_id=%s""",
                (Jsonb(mapping), batch, actor),
            )
            await tx.execute(
                "DELETE FROM app.import_rows WHERE owner_id=%s AND batch_id=%s",
                (actor, batch),
            )
            await write_receipt(tx, call, operation, digest, row["id"], "import_batch")
            return Result(200, batch_dto(await self._batch(tx, actor, batch)))

    async def validate(self, call: Call) -> Result:
        actor, batch = call.identity.user_id, call.path["batch_id"]
        operation = "import.validate"
        digest = fingerprint(call, operation, call.path)
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity, admin=True)
            prior = await receipt(tx, call, operation, digest)
            original = await self._batch(tx, actor, batch)
            if prior is not None:
                return Result(200, batch_dto(original), replayed=True)
            if original["status"] not in {"mapped", "invalid", "validated"}:
                raise ApiError(409, "INVALID_STATE", "Cần ánh xạ trước khi kiểm tra.")
            file = await one(
                tx,
                """SELECT object_key,sha256 FROM app.admin_media_uploads WHERE id=%s AND owner_id=%s
                    AND state='ready' AND expires_at>clock_timestamp()""",
                (original["file_media_id"], actor),
            )
            if file is None:
                raise missing()
        data = await self._storage().fetch(file["object_key"])
        if hashlib.sha256(data).hexdigest() != file["sha256"]:
            raise ApiError(409, "SOURCE_VERSION_CONFLICT", "Tệp CSV đã thay đổi.")
        header, rows = csv_records(data)
        staged = stage_rows(header, rows, original["mapping"])
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, actor)
            await self.accounts.require_access(tx, call.identity, admin=True)
            previous = await receipt(tx, call, operation, digest)
            current = await self._batch(tx, actor, batch)
            if previous is not None:
                return Result(200, batch_dto(current), replayed=True)
            if (
                current["mapping_version"] != original["mapping_version"]
                or current["status"] == "completed"
            ):
                raise ApiError(409, "STALE_VERSION", "Lô nhập đã thay đổi.")
            await self._validate_sources(tx, staged)
            await tx.execute(
                "DELETE FROM app.import_rows WHERE owner_id=%s AND batch_id=%s",
                (actor, batch),
            )
            await tx.execute(
                """INSERT INTO app.import_rows(batch_id,owner_id,line_number,errors,content)
                SELECT %s,%s,x.line_number,x.errors,x.content FROM jsonb_to_recordset(%s)
                AS x(line_number integer,errors jsonb,content jsonb)""",
                (batch, actor, Jsonb(staged)),
            )
            invalid = sum(bool(r["errors"]) for r in staged)
            value = hashlib.sha256(
                json.dumps(
                    [file["sha256"], current["mapping_version"], current["mapping"]],
                    sort_keys=True,
                ).encode()
            ).hexdigest()
            await tx.execute(
                """UPDATE app.import_batches SET status=%s,validated_hash=%s,total_rows=%s,
                valid_rows=%s,invalid_rows=%s WHERE id=%s AND owner_id=%s""",
                (
                    "invalid" if invalid else "validated",
                    None if invalid else value,
                    len(staged),
                    len(staged) - invalid,
                    invalid,
                    batch,
                    actor,
                ),
            )
            await write_receipt(
                tx, call, operation, digest, current["id"], "import_batch"
            )
            return Result(200, batch_dto(await self._batch(tx, actor, batch)))

    async def confirm(self, call: Call) -> Result:
        actor, batch = call.identity.user_id, call.path["batch_id"]
        operation = "import.confirm"
        digest = fingerprint(call, operation, {**call.path, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, actor)
            await self.accounts.require_access(tx, call.identity, admin=True)
            previous = await receipt(tx, call, operation, digest)
            row = await self._batch(tx, actor, batch)
            if previous is not None:
                return Result(200, batch_dto(row), replayed=True)
            if (
                row["mapping_version"] != call.body["expected_mapping_version"]
                or row["validated_hash"] != call.body["validated_hash"]
            ):
                raise ApiError(
                    409, "STALE_VERSION", "Hãy kiểm tra lại dữ liệu trước khi nhập."
                )
            if row["status"] not in {"validated", "completed"}:
                raise ApiError(409, "INVALID_STATE", "Lô chưa hợp lệ.")
            if row["status"] == "validated":
                media = await one(
                    tx,
                    """SELECT id FROM app.admin_media_uploads WHERE id=%s AND state='ready'
                    AND expires_at>clock_timestamp() FOR UPDATE""",
                    (row["file_media_id"],),
                )
                if media is None:
                    raise ApiError(410, "RESOURCE_GONE", "Tệp nhập đã hết hạn.")
                await lock_vocabulary_writes(tx)
                await self._apply_rows(tx, actor, row)
                await tx.execute(
                    "UPDATE app.admin_media_uploads SET expires_at=clock_timestamp()+interval '90 days' WHERE id=%s",
                    (row["file_media_id"],),
                )
            op = await write_receipt(
                tx, call, operation, digest, row["id"], "import_batch"
            )
            if row["status"] == "validated":
                await AdminContent._audit(
                    tx,
                    actor,
                    op,
                    operation,
                    "import_batch",
                    row["id"],
                    "validated",
                    "completed",
                )
            return Result(200, batch_dto(await self._batch(tx, actor, batch)))

    async def _apply_rows(self, tx, actor, batch):
        rows = await many(
            tx,
            "SELECT line_number,content FROM app.import_rows WHERE batch_id=%s AND owner_id=%s ORDER BY line_number",
            (batch["id"], actor),
        )
        if len(rows) != batch["valid_rows"]:
            raise ApiError(409, "INVALID_STATE", "Dữ liệu kiểm tra đã hết hạn.")
        inserted = updated = 0
        for row in rows:
            entry, revision, change = await self._import_word(tx, actor, row["content"])
            inserted += change == "new"
            updated += change == "updated"
            await tx.execute(
                "UPDATE app.import_rows SET entry_id=%s,revision_id=%s WHERE batch_id=%s AND line_number=%s",
                (entry, revision, batch["id"], row["line_number"]),
            )
        await tx.execute(
            """UPDATE app.import_batches SET status='completed',inserted_rows=%s,updated_rows=%s
            WHERE owner_id=%s AND id=%s""",
            (inserted, updated, actor, batch["id"]),
        )

    @staticmethod
    async def _target(tx, row):
        content = row["content"]
        source = (content["source_name"], content["source_external_id"])
        sense = row.get("sense_id") or uuid5(
            NAMESPACE_URL, json.dumps(["hanyu-ai:vocabulary", *source])
        )
        matched = await many(
            tx,
            """SELECT DISTINCT v.id,v.hanzi,v.reading_key,v.sense_id FROM app.vocabulary v
            JOIN app.vocabulary_revisions r ON r.entry_id=v.id WHERE r.source_name=%s AND r.source_external_id=%s LIMIT 2""",
            source,
        )
        if len(matched) > 1:
            raise source_conflict("Định danh nguồn cần được duyệt lại.")
        if matched:
            root = matched[0]
            if (
                root["hanzi"] != row["hanzi"]
                or root["reading_key"] != row["reading_key"]
                or (
                    row.get("sense_id")
                    and str(root["sense_id"]) != row["sense_id"].lower()
                )
            ):
                raise source_conflict("Nguồn đã gắn với mục từ khác.")
            return root, source, str(root["sense_id"])
        root = await one(
            tx,
            "SELECT id FROM app.vocabulary WHERE hanzi=%s AND reading_key=%s AND sense_id=%s",
            (row["hanzi"], row["reading_key"], sense),
        )
        return root, source, str(sense).lower()

    @staticmethod
    async def _existing_revision(tx, entry, source, content):
        old = await one(
            tx,
            """SELECT id,pinyin_display,vietnamese,hsk_level,license,part_of_speech,examples FROM app.vocabulary_revisions
              WHERE entry_id=%s AND source_name=%s AND source_external_id=%s AND source_version=%s""",
            (entry, *source, content["source_version"]),
        )
        if old is not None and comparable_content(old) != comparable_content(content):
            raise source_conflict("Nguồn cùng phiên bản có nội dung khác.")
        return old

    async def _validate_sources(self, tx, rows):
        accepted_sources = {}
        accepted_versions = {}
        for staged in rows:
            row = staged["content"]
            if row is None:
                continue
            content = row["content"]
            source = (content["source_name"], content["source_external_id"])
            version = (*source, content["source_version"])
            try:
                if source in accepted_sources:
                    entry, hanzi, reading, sense = accepted_sources[source]
                    if (
                        hanzi != row["hanzi"]
                        or reading != row["reading_key"]
                        or (row.get("sense_id") and sense != row["sense_id"].lower())
                    ):
                        raise source_conflict(
                            "Hai dòng dùng cùng nguồn cho mục từ khác nhau."
                        )
                else:
                    root, _, sense = await self._target(tx, row)
                    entry = root["id"] if root else None
                comparable = comparable_content(content)
                if version in accepted_versions:
                    if accepted_versions[version] != comparable:
                        raise source_conflict(
                            "Hai dòng cùng phiên bản nguồn có nội dung khác nhau."
                        )
                elif entry is not None:
                    await self._existing_revision(tx, entry, source, content)
                accepted_sources[source] = (
                    entry,
                    row["hanzi"],
                    row["reading_key"],
                    sense,
                )
                accepted_versions[version] = comparable
            except ApiError as exc:
                if exc.code != "SOURCE_VERSION_CONFLICT":
                    raise
                staged["errors"].append(
                    {
                        "field": "source_external_id",
                        "code": exc.code,
                        "message": exc.message,
                    }
                )
                staged["content"] = None

    async def _import_word(self, tx, actor, row):
        content = row["content"]
        root, source, sense = await self._target(tx, row)
        entry = (
            root["id"]
            if root
            else await AdminContent._create_root(tx, {**row, "sense_id": sense})
        )
        await tx.execute(
            "SELECT id FROM app.vocabulary WHERE id=%s FOR UPDATE", (entry,)
        )
        old = await self._existing_revision(tx, entry, source, content)
        if old is not None:
            return entry, old["id"], "same"
        seq = await one(
            tx,
            "SELECT coalesce(max(revision),0)+1 AS n FROM app.vocabulary_revisions WHERE entry_id=%s",
            (entry,),
        )
        saved = await AdminContent._create_revision(tx, actor, entry, seq["n"], content)
        return entry, saved["id"], "new" if root is None else "updated"
