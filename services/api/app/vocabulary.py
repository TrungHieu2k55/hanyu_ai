import json
from unicodedata import category, normalize

from psycopg.types.json import Jsonb

from .accounts import Accounts, fingerprint
from .errors import ApiError, invalid_input
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .sm2 import schedule_dto

_WORD = """
SELECT v.id AS entry_id, r.id AS revision_id, v.hanzi, r.pinyin_display AS pinyin,
       r.vietnamese, r.hsk_level, 'reviewed' AS source_kind, r.examples,
       i.id AS learning_item_id, v.created_at, v.reading_key
FROM app.vocabulary v
JOIN app.vocabulary_revisions r ON r.id = v.published_revision_id AND r.status = 'published'
LEFT JOIN app.learning_items i ON i.entry_id = v.id AND i.owner_id = %s AND i.status = 'active'
"""
_MATCH_TIER = r"""
CASE
    WHEN q.han IS NULL OR words.hanzi = q.han THEN 0
    WHEN starts_with(words.hanzi, q.han) THEN 1
    WHEN q.pinyin <> '' AND (
        strpos(regexp_replace(lower(words.reading_key),'[[:space:]]','','g'),q.pinyin)>0
        OR strpos(regexp_replace(translate(
            replace(replace(lower(normalize(words.pinyin,NFD)),U&'u\0308','v'),'u:','v'),
            q.marks,''),'[[:space:]]','','g'),q.pinyin)>0
    ) THEN 2
    WHEN q.meaning <> '' AND strpos(replace(replace(lower(translate(
        normalize(words.vietnamese,NFD),q.marks,'')),'đ','d'),'Đ','d'),q.meaning)>0 THEN 3
    ELSE 4
END
"""
_COMBINING_MARKS = "".join(chr(code) for code in range(0x300, 0x370))

_ITEMS = """
SELECT i.id, i.entry_id, i.personal_entry_id, coalesce(v.hanzi, p.hanzi) AS hanzi,
       coalesce(r.pinyin_display, p.pinyin) AS pinyin,
       coalesce(r.vietnamese, p.vietnamese) AS vietnamese,
       i.status, i.version, s.due_at, i.created_at, i.merged_into_id,
       i.selected_note_id, p.version AS personal_version, s.ease_factor, s.last_quality,
       s.interval_days, s.repetitions, s.version AS schedule_version, s.algorithm_version, n.text AS note
FROM app.learning_items i
LEFT JOIN app.vocabulary v ON v.id = i.entry_id
LEFT JOIN app.vocabulary_revisions r ON r.id = i.vocabulary_revision_id
LEFT JOIN app.personal_entries p ON p.id = i.personal_entry_id AND p.owner_id = i.owner_id
LEFT JOIN app.review_schedules s ON s.item_id = i.id AND s.owner_id = i.owner_id
LEFT JOIN app.personal_notes n ON n.id = i.selected_note_id AND n.item_id = i.id AND n.owner_id = i.owner_id
"""
_ITEM_FIELDS = (
    "id",
    "entry_id",
    "personal_entry_id",
    "hanzi",
    "pinyin",
    "vietnamese",
    "status",
    "version",
)
_WORD_IDS = ("entry_id", "revision_id", "learning_item_id")


def missing() -> ApiError:
    return ApiError(404, "NOT_FOUND", "Không tìm thấy mục này.")


def uuid_str(value):
    return str(value) if value is not None else None


def clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = normalize("NFC", value.strip())
    if not value or any(category(c) == "Cs" or c == "\0" for c in value):
        raise invalid_input()
    return value


def vocabulary_search_terms(query: str | None) -> tuple[str, str]:
    if query is None:
        return "", ""
    decomposed = normalize("NFD", query.lower())
    plain = decomposed.translate(str.maketrans("", "", _COMBINING_MARKS))
    meaning = plain.replace("đ", "d")
    pinyin = decomposed.replace("u" + chr(0x308), "v").replace("u:", "v")
    pinyin = "".join(pinyin.translate(str.maketrans("", "", _COMBINING_MARKS)).split())
    if not (meaning or pinyin):
        raise invalid_input()
    return pinyin, meaning


def word_dto(row: dict) -> dict:
    return {
        k: uuid_str(v) if k in _WORD_IDS else v
        for k, v in row.items()
        if k not in {"created_at", "match_tier", "reading_key"}
    }


def item_summary(row: dict) -> dict:
    data = {k: row[k] for k in _ITEM_FIELDS}
    data.update({k: uuid_str(row[k]) for k in _ITEM_FIELDS[:3]})
    return {**data, "due_at": row["due_at"].isoformat() if row["due_at"] else None}


def note_dto(row: dict) -> dict:
    return {
        "id": str(row["id"]),
        "item_id": str(row["item_id"]),
        "text": row["text"],
        "version": row["version"],
    }


def check_version(row: dict, expected: int) -> None:
    if row["version"] != expected:
        raise ApiError(409, "STALE_VERSION", "Dữ liệu đã thay đổi. Hãy tải lại.")


class Vocabulary:
    def __init__(self, db: Database, accounts: Accounts):
        self.db = db
        self.accounts = accounts

    def _scope(self, call: Call, name: str) -> str:
        filters = {k: v for k, v in call.query.items() if k not in {"cursor", "limit"}}
        return json.dumps([name, str(call.identity.user_id), filters], sort_keys=True)

    def _page(self, rows, scope, limit, project) -> dict:
        cursor = None
        if len(rows) > limit:
            last = rows[limit - 1]
            cursor = self.db.cursor(
                scope, {"id": last["id"], "created_at": last["created_at"]}
            )
        return {"items": [project(r) for r in rows[:limit]], "next_cursor": cursor}

    async def dictionary(self, call: Call) -> Result:
        return await self.words(call, advanced=True)

    async def words(self, call: Call, *, advanced: bool = False) -> Result:
        query = clean_text(call.query.get("q"))
        pinyin, meaning = vocabulary_search_terms(query)
        level = call.query.get("hsk_level")
        limit = call.query.get("limit", 20)
        scope = self._scope(
            call, "advanced-dictionary" if advanced else "vocabulary-v2"
        )
        part = clean_text(call.query.get("part_of_speech"))
        with_examples = bool(call.query.get("with_examples", 0))
        after = self.db.read_vocabulary_cursor(scope, call.query.get("cursor"))
        sql = (
            "WITH words AS ("
            + _WORD
            + " WHERE (%s::smallint IS NULL OR r.hsk_level = %s)"
            " AND (%s::text IS NULL OR lower(r.part_of_speech)=lower(%s))"
            " AND (NOT %s OR jsonb_array_length(r.examples)>0)),"
            " q AS (SELECT %s::text AS han, %s::text AS pinyin, %s::text AS meaning, %s::text AS marks),"
            " ranked AS (SELECT words.*, "
            + _MATCH_TIER
            + " AS match_tier FROM words CROSS JOIN q)"
            " SELECT * FROM ranked WHERE match_tier < 4"
        )
        args = [
            call.identity.user_id,
            level,
            level,
            part,
            part,
            with_examples,
            query,
            pinyin,
            meaning,
            _COMBINING_MARKS,
        ]
        if after is not None:
            sql += ' AND (match_tier, hanzi COLLATE "C", entry_id) > (%s, %s, %s)'
            args.extend(after)
        sql += ' ORDER BY match_tier, hanzi COLLATE "C", entry_id LIMIT %s'
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(tx, sql, (*args, limit + 1))
        cursor = (
            self.db.vocabulary_cursor(scope, rows[limit - 1])
            if len(rows) > limit
            else None
        )
        return Result(
            200,
            {"items": [word_dto(row) for row in rows[:limit]], "next_cursor": cursor},
        )

    async def word(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await one(
                tx,
                _WORD + " WHERE v.id = %s",
                (call.identity.user_id, call.path["entry_id"]),
            )
        if row is None:
            raise missing()
        return Result(200, word_dto(row))

    async def resolve_sample(self, call: Call) -> Result:
        owner, body = call.identity.user_id, call.body
        operation = "sample.resolve"
        sample = clean_text(body["sample_id"])
        version = clean_text(body["content_version"])
        digest = fingerprint(
            call, operation, {"sample_id": sample, "content_version": version}
        )
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                row = await one(
                    tx,
                    "SELECT entry_id, id AS revision_id FROM app.vocabulary_revisions WHERE id = %s AND status = 'published'",
                    (prior,),
                )
                if row is None:
                    raise ApiError(
                        410, "RESOURCE_GONE", "Bản từ đã công bố không còn khả dụng."
                    )
                return Result(200, {k: str(v) for k, v in row.items()}, replayed=True)
            row = await one(
                tx,
                """SELECT r.entry_id, r.id AS revision_id FROM app.vocabulary_sample_mappings m
                    JOIN app.vocabulary v ON v.id = m.entry_id
                    JOIN app.vocabulary_revisions r ON r.id = v.published_revision_id AND r.status = 'published'
                    WHERE m.sample_id = %s AND m.content_version = %s""",
                (sample, version),
            )
            if row is None:
                known = await one(
                    tx,
                    "SELECT 1 FROM app.vocabulary_sample_mappings WHERE sample_id = %s LIMIT 1",
                    (sample,),
                )
                if known is not None:
                    raise ApiError(
                        409,
                        "SOURCE_VERSION_CONFLICT",
                        "Phiên bản từ mẫu không còn khả dụng.",
                    )
                raise missing()
            await write_receipt(
                tx, call, operation, digest, row["revision_id"], "vocabulary_revision"
            )
            return Result(200, {k: str(v) for k, v in row.items()})

    async def edit_personal(self, call: Call) -> Result:
        owner, personal = call.identity.user_id, call.path["entry_id"]
        body = {
            key: clean_text(value) if key != "expected_version" else value
            for key, value in call.body.items()
        }
        operation = "personal.edit"
        digest = fingerprint(call, operation, {"entry_id": personal, **body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._detail(tx, owner, prior), replayed=True)
            row = await one(
                tx,
                """SELECT i.id AS item_id, p.version, p.linked_entry_id FROM app.personal_entries p
                                   JOIN app.learning_items i ON i.personal_entry_id = p.id AND i.owner_id = p.owner_id
                                   WHERE p.owner_id = %s AND p.id = %s""",
                (owner, personal),
            )
            if row is None:
                raise missing()
            if row["linked_entry_id"] is not None:
                raise ApiError(
                    409,
                    "INVALID_STATE",
                    "Từ đã gộp. Hãy sửa ghi chú trên mục từ chuẩn.",
                )
            check_version(row, body["expected_version"])
            await tx.execute(
                """UPDATE app.personal_entries SET hanzi = coalesce(%s, hanzi),
                  pinyin = CASE WHEN %s THEN %s ELSE pinyin END,
                  vietnamese = CASE WHEN %s THEN %s ELSE vietnamese END, version = version + 1
                  WHERE owner_id = %s AND id = %s""",
                (
                    body.get("hanzi"),
                    "pinyin" in body,
                    body.get("pinyin"),
                    "vietnamese" in body,
                    body.get("vietnamese"),
                    owner,
                    personal,
                ),
            )
            await write_receipt(
                tx, call, operation, digest, row["item_id"], "learning_item"
            )
            return Result(200, await self._detail(tx, owner, row["item_id"]))

    async def link_personal(self, call: Call) -> Result:
        owner, personal = call.identity.user_id, call.path["entry_id"]
        operation = "personal.link"
        body = call.body
        digest = fingerprint(call, operation, {"personal_id": personal, **body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._detail(tx, owner, prior), replayed=True)
            source = await one(
                tx,
                """SELECT p.version, p.linked_entry_id, i.id, i.status FROM app.personal_entries p
                JOIN app.learning_items i ON i.personal_entry_id = p.id AND i.owner_id = p.owner_id
                WHERE p.owner_id = %s AND p.id = %s""",
                (owner, personal),
            )
            if source is None:
                raise missing()
            if source["linked_entry_id"] is not None:
                raise ApiError(409, "INVALID_STATE", "Từ cá nhân đã được gộp.")
            check_version(source, body["expected_version"])
            entry, revision, _ = await self._source(
                tx, owner, {"kind": "canonical", "entry_id": body["entry_id"]}
            )
            target = await self._canonical_target(tx, owner, source, entry, revision)
            await self._merge_notes(
                tx, owner, source["id"], target, body.get("selected_note_id")
            )
            await tx.execute(
                """UPDATE app.personal_entries SET linked_entry_id = %s, linked_at = clock_timestamp(),
                version = version + 1 WHERE owner_id = %s AND id = %s""",
                (entry, owner, personal),
            )
            await tx.execute(
                """UPDATE app.review_schedules SET archived_at = clock_timestamp(), version = version + 1
                WHERE owner_id = %s AND item_id = %s""",
                (owner, source["id"]),
            )
            await tx.execute(
                """UPDATE app.learning_items SET status = 'merged', merged_into_id = %s,
                version = version + 1 WHERE owner_id = %s AND id = %s""",
                (target["id"], owner, source["id"]),
            )
            await write_receipt(
                tx, call, operation, digest, target["id"], "learning_item"
            )
            return Result(200, await self._detail(tx, owner, target["id"]))

    async def _canonical_target(self, tx, owner, source, entry, revision):
        target = await one(
            tx,
            "SELECT id, selected_note_id FROM app.learning_items WHERE owner_id = %s AND entry_id = %s",
            (owner, entry),
        )
        if target is not None:
            return target
        target = await one(
            tx,
            """INSERT INTO app.learning_items (owner_id, entry_id, vocabulary_revision_id)
                                 VALUES (%s,%s,%s) RETURNING id, selected_note_id""",
            (owner, entry, revision),
        )
        await tx.execute(
            """INSERT INTO app.review_schedules
            (owner_id,item_id,ease_factor,interval_days,repetitions,due_at,last_quality,algorithm_version)
            SELECT owner_id,%s,ease_factor,interval_days,repetitions,due_at,last_quality,algorithm_version
            FROM app.review_schedules WHERE owner_id = %s AND item_id = %s""",
            (target["id"], owner, source["id"]),
        )
        if source["status"] == "archived":
            await self._set_status(tx, owner, target["id"], "archived")
        return target

    async def _merge_notes(self, tx, owner, source, target, selected):
        if selected is not None:
            note = await self._note(tx, owner, selected)
            if note["item_id"] not in {source, target["id"]}:
                raise missing()
            selected = note["id"]
        await tx.execute(
            "UPDATE app.learning_items SET selected_note_id = NULL WHERE owner_id = %s AND id = %s",
            (owner, source),
        )
        await tx.execute(
            """UPDATE app.personal_notes SET item_id = %s, source_item_id = coalesce(source_item_id, %s),
            version = version + 1, updated_at = clock_timestamp() WHERE owner_id = %s AND item_id = %s""",
            (target["id"], source, owner, source),
        )
        if target["selected_note_id"] is None and selected is not None:
            await self._select_note(tx, owner, target["id"], selected)

    async def items(self, call: Call) -> Result:
        scope = self._scope(call, "learning-items")
        limit = call.query.get("limit", 20)
        where, args = ["i.owner_id = %s"], [call.identity.user_id]
        for field, clause in (
            ("status", "i.status = %s"),
            ("entry_id", "i.entry_id = %s"),
        ):
            if field in call.query:
                where.append(clause)
                args.append(call.query[field])
        after = self.db.read_cursor(scope, call.query.get("cursor"))
        if after[0] is not None:
            where.append("(i.created_at, i.id) < (%s, %s)")
            args.extend(after)
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(
                tx,
                _ITEMS
                + " WHERE "
                + " AND ".join(where)
                + " ORDER BY i.created_at DESC, i.id DESC LIMIT %s",
                (*args, limit + 1),
            )
        return Result(200, self._page(rows, scope, limit, item_summary))

    async def item(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            item = await self._detail(tx, call.identity.user_id, call.path["item_id"])
        return Result(200, item)

    async def _detail(self, tx, owner, item) -> dict:
        row = await one(
            tx, _ITEMS + " WHERE i.owner_id = %s AND i.id = %s", (owner, item)
        )
        if row is None:
            raise missing()
        note_page = await self._note_rows(tx, owner, str(row["id"]), 100, None)
        summary = item_summary(row)
        summary.pop("due_at")
        schedule = (
            None
            if row["due_at"] is None
            else schedule_dto({**row, "version": row["schedule_version"]})
        )
        return {
            **summary,
            "source_kind": "reviewed" if row["entry_id"] else "personal",
            "merged_into_id": uuid_str(row["merged_into_id"]),
            "selected_note_id": uuid_str(row["selected_note_id"]),
            "personal_version": row["personal_version"],
            "schedule": schedule,
            "notes": note_page["items"],
            "notes_next_cursor": note_page["next_cursor"],
        }

    async def save(self, call: Call) -> Result:
        owner = call.identity.user_id
        body = call.body
        source = body["source"]
        note = clean_text(body.get("note"))
        operation = "learning.save"
        digest = fingerprint(call, operation, body)
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                return Result(
                    200, await self._detail(tx, owner, previous), replayed=True
                )
            entry, revision, personal = await self._source(tx, owner, source)
            existing = await one(
                tx,
                """SELECT id, status FROM app.learning_items
                       WHERE owner_id = %s AND (entry_id = %s OR personal_entry_id = %s)""",
                (owner, entry, personal),
            )
            if existing is not None:
                if existing["status"] == "merged":
                    raise ApiError(409, "INVALID_STATE", "Từ này đã được gộp.")
                item = existing["id"]
                if existing["status"] == "archived":
                    await self._set_status(tx, owner, item, "active")
            else:
                created = await one(
                    tx,
                    """INSERT INTO app.learning_items (owner_id, entry_id, vocabulary_revision_id, personal_entry_id)
                           VALUES (%s, %s, %s, %s) RETURNING id""",
                    (owner, entry, revision, personal),
                )
                item = created["id"]
                await tx.execute(
                    "INSERT INTO app.review_schedules (owner_id, item_id) VALUES (%s, %s)",
                    (owner, item),
                )
            if note is not None:
                await self._add_note(tx, owner, item, note)
            await write_receipt(tx, call, operation, digest, item, "learning_item")
            return Result(
                201 if existing is None else 200, await self._detail(tx, owner, item)
            )

    async def _source(self, tx, owner, source):
        if source["kind"] == "canonical":
            row = await one(tx, _WORD + " WHERE v.id = %s", (owner, source["entry_id"]))
            if row is None:
                raise missing()
            return row["entry_id"], row["revision_id"], None
        if source["kind"] == "personal_existing":
            row = await one(
                tx,
                "SELECT id FROM app.personal_entries WHERE owner_id = %s AND id = %s",
                (owner, source["personal_entry_id"]),
            )
            if row is None:
                raise missing()
            return None, None, row["id"]
        value = source["personal"]
        context = value["source"]
        if context["kind"] == "roleplay":
            turn = await one(
                tx,
                "SELECT id FROM app.roleplay_turns WHERE owner_id=%s AND id=%s",
                (owner, context["resource_id"]),
            )
            if turn is None:
                raise missing()
        if context["kind"] == "ocr":
            row = await one(
                tx,
                """SELECT id FROM app.ocr_revisions WHERE owner_id = %s AND scan_id = %s AND id = %s""",
                (owner, context["resource_id"], context["revision_id"]),
            )
            if row is None:
                raise missing()
        row = await one(
            tx,
            """INSERT INTO app.personal_entries
                   (owner_id, hanzi, pinyin, vietnamese, source_kind, source_context)
                   VALUES (%s, %s, %s, %s, %s, %s) RETURNING id""",
            (
                owner,
                clean_text(value["hanzi"]),
                clean_text(value.get("pinyin")),
                clean_text(value.get("vietnamese")),
                context["kind"],
                Jsonb(context),
            ),
        )
        return None, None, row["id"]

    @staticmethod
    async def _set_status(tx, owner, item, status) -> None:
        await tx.execute(
            "UPDATE app.learning_items SET status = %s, version = version + 1 WHERE owner_id = %s AND id = %s",
            (status, owner, item),
        )

    async def state(self, call: Call) -> Result:
        owner, item = call.identity.user_id, call.path["item_id"]
        operation = "learning.state"
        digest = fingerprint(call, operation, {"item_id": item, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            previous = await receipt(tx, call, operation, digest)
            if previous is not None:
                return Result(
                    200, await self._detail(tx, owner, previous), replayed=True
                )
            row = await one(
                tx,
                "SELECT id, status, version FROM app.learning_items WHERE owner_id = %s AND id = %s",
                (owner, item),
            )
            if row is None:
                raise missing()
            if row["status"] == "merged":
                raise ApiError(409, "INVALID_STATE", "Từ này đã được gộp.")
            if row["version"] != call.body["expected_version"]:
                raise ApiError(409, "STALE_VERSION", "Từ đã thay đổi. Hãy tải lại.")
            if row["status"] != call.body["status"]:
                await self._set_status(tx, owner, item, call.body["status"])
            await write_receipt(tx, call, operation, digest, row["id"], "learning_item")
            return Result(200, await self._detail(tx, owner, item))

    async def _note_rows(self, tx, owner, item, limit, cursor):
        scope = f"learning-notes:{owner}:{item}"
        date, note = self.db.read_cursor(scope, cursor)
        sql = """SELECT id, item_id, text, version, created_at FROM app.personal_notes
                 WHERE owner_id = %s AND item_id = %s"""
        args = [owner, item]
        if date is not None:
            sql += " AND (created_at, id) < (%s, %s)"
            args.extend((date, note))
        rows = await many(
            tx, sql + " ORDER BY created_at DESC, id DESC LIMIT %s", (*args, limit + 1)
        )
        return self._page(rows, scope, limit, note_dto)

    @staticmethod
    async def _membership(tx, owner, item):
        row = await one(
            tx,
            """SELECT id, status, version, selected_note_id FROM app.learning_items
                               WHERE owner_id = %s AND id = %s""",
            (owner, item),
        )
        if row is None:
            raise missing()
        return row

    @staticmethod
    async def _note(tx, owner, note):
        row = await one(
            tx,
            """SELECT id, item_id, text, version FROM app.personal_notes
                               WHERE owner_id = %s AND id = %s""",
            (owner, note),
        )
        if row is None:
            raise missing()
        return row

    @staticmethod
    async def _select_note(tx, owner, item, note):
        await tx.execute(
            """UPDATE app.learning_items SET selected_note_id = %s, version = version + 1
               WHERE owner_id = %s AND id = %s AND selected_note_id IS DISTINCT FROM %s""",
            (note, owner, item, note),
        )

    async def _add_note(self, tx, owner, item, text):
        first = (
            await one(
                tx,
                "SELECT 1 FROM app.personal_notes WHERE owner_id = %s AND item_id = %s LIMIT 1",
                (owner, item),
            )
            is None
        )
        note = await one(
            tx,
            """INSERT INTO app.personal_notes (owner_id, item_id, text)
                   VALUES (%s, %s, %s) RETURNING id, item_id, text, version""",
            (owner, item, text),
        )
        if first:
            await self._select_note(tx, owner, item, note["id"])
        return note

    async def notes(self, call: Call) -> Result:
        owner, item = call.identity.user_id, call.path["item_id"]
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            await self._membership(tx, owner, item)
            page = await self._note_rows(
                tx, owner, item, call.query.get("limit", 20), call.query.get("cursor")
            )
        return Result(200, page)

    async def create_note(self, call: Call) -> Result:
        owner, item = call.identity.user_id, call.path["item_id"]
        text = clean_text(call.body["text"])
        operation = "note.create"
        digest = fingerprint(call, operation, {"item": item, "text": text})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(
                    201,
                    note_dto(await self._replayed_note(tx, owner, prior)),
                    replayed=True,
                )
            member = await self._membership(tx, owner, item)
            if member["status"] == "merged":
                raise ApiError(409, "INVALID_STATE", "Từ này đã được gộp.")
            row = await self._add_note(tx, owner, item, text)
            await write_receipt(tx, call, operation, digest, row["id"], "personal_note")
            return Result(201, note_dto(row))

    async def _replayed_note(self, tx, owner, note):
        try:
            return await self._note(tx, owner, note)
        except ApiError as exc:
            if exc.status != 404:
                raise
            raise ApiError(410, "RESOURCE_GONE", "Ghi chú đã được xóa.") from exc

    async def edit_note(self, call: Call) -> Result:
        owner, note = call.identity.user_id, call.path["note_id"]
        text, version = clean_text(call.body["text"]), call.body["expected_version"]
        operation = "note.edit"
        digest = fingerprint(
            call, operation, {"note": note, "text": text, "version": version}
        )
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(
                    200,
                    note_dto(await self._replayed_note(tx, owner, prior)),
                    replayed=True,
                )
            row = await self._note(tx, owner, note)
            check_version(row, version)
            changed = await one(
                tx,
                """UPDATE app.personal_notes SET text = %s, version = version + 1, updated_at = clock_timestamp()
                       WHERE owner_id = %s AND id = %s RETURNING id, item_id, text, version""",
                (text, owner, note),
            )
            await write_receipt(tx, call, operation, digest, row["id"], "personal_note")
            return Result(200, note_dto(changed))

    async def delete_note(self, call: Call) -> Result:
        owner, note = call.identity.user_id, call.path["note_id"]
        operation = "note.delete"
        version = call.query["expected_version"]
        digest = fingerprint(call, operation, {"note": note, "version": version})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(204, replayed=True)
            row = await self._note(tx, owner, note)
            check_version(row, version)
            member = await self._membership(tx, owner, row["item_id"])
            if member["selected_note_id"] == row["id"]:
                await self._select_note(tx, owner, row["item_id"], None)
            await tx.execute(
                "DELETE FROM app.personal_notes WHERE owner_id = %s AND id = %s",
                (owner, note),
            )
            await write_receipt(tx, call, operation, digest, row["id"], "personal_note")
            return Result(204)

    async def default_note(self, call: Call) -> Result:
        owner, item = call.identity.user_id, call.path["item_id"]
        note = call.body["note_id"]
        operation = "note.default"
        digest = fingerprint(call, operation, {"item": item, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._detail(tx, owner, prior), replayed=True)
            member = await self._membership(tx, owner, item)
            check_version(member, call.body["expected_version"])
            if note is not None:
                row = await self._note(tx, owner, note)
                if row["item_id"] != member["id"]:
                    raise missing()
                note = row["id"]
            await self._select_note(tx, owner, item, note)
            await write_receipt(
                tx, call, operation, digest, member["id"], "learning_item"
            )
            return Result(200, await self._detail(tx, owner, item))

    @staticmethod
    async def due_rows(tx, owner, now, limit: int):
        return await many(
            tx,
            "SELECT due.*, count(*) OVER () AS due_count FROM ("
            + _ITEMS
            + " WHERE i.owner_id = %s AND i.status = 'active' AND s.archived_at IS NULL AND s.due_at <= %s"
            ") due ORDER BY due_at, id LIMIT %s",
            (owner, now, limit),
        )

    async def queue(self, call: Call) -> Result:
        owner = call.identity.user_id
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            now = (await one(tx, "SELECT clock_timestamp() AS now"))["now"]
            rows = await self.due_rows(tx, owner, now, 20)
        return Result(
            200,
            {
                "due_count": rows[0]["due_count"] if rows else 0,
                "items": [item_summary(r) for r in rows],
                "server_time": now.isoformat(),
            },
        )
