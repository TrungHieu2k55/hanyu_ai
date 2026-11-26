import asyncio
import hashlib
import json
import unicodedata
from dataclasses import replace

from .accounts import fingerprint
from .errors import ApiError, invalid_input, unavailable
from .operations import lock_owner
from .ports import Call, Result
from .postgres import many, one
from .vocabulary import clean_text, missing

LESSON_FIELDS = "id, revision, kind, hsk_level, title, explanation, exercise, solution"


def normalize_answer(text: str) -> str:
    return "".join(
        char
        for char in unicodedata.normalize("NFKC", text).casefold()
        if not char.isspace() and not unicodedata.category(char).startswith("P")
    )


def public_lesson(row: dict, *, offline: bool = False) -> dict:
    result = dict(row)
    if not offline:
        result.pop("solution")
        result["exercise"] = {
            key: value
            for key, value in row["exercise"].items()
            if key not in {"audio_text", "tone_audio"}
        }
    return result


def grade(lesson: dict, body: dict) -> bool:
    kind, exercise = lesson["kind"], lesson["exercise"]
    answer = body["answer"]
    accepted = lesson["solution"]["accepted"]
    if kind in {"pronunciation", "dictation"}:
        if not isinstance(answer, str) or not normalize_answer(answer):
            raise invalid_input()
        return normalize_answer(answer) in {normalize_answer(text) for text in accepted}
    options = {option["id"] for option in exercise["options"]}
    if kind == "sentence_order":
        if (
            not isinstance(answer, list)
            or len(answer) != len(options)
            or set(answer) != options
        ):
            raise invalid_input()
    elif not isinstance(answer, str) or answer not in options:
        raise invalid_input()
    return answer in accepted


class StudyCurriculum:
    def __init__(self, db, accounts, tts, transcriber=None, stt_model=None):
        self.db, self.accounts, self.tts = db, accounts, tts
        self.transcriber, self.stt_model = transcriber, stt_model

    @staticmethod
    async def _lesson(tx, lesson_id, revision=None, *, offline_submission=False):
        row = await one(
            tx,
            f"""SELECT {LESSON_FIELDS} FROM app.study_lessons
            WHERE id=%s AND (published OR (%s AND released_at IS NOT NULL))
            AND (%s::integer IS NULL OR revision=%s)""",
            (lesson_id, offline_submission, revision, revision),
        )
        if row is None:
            raise missing()
        return row

    async def list_lessons(self, call: Call) -> Result:
        level, kind = call.query.get("level"), call.query.get("kind")
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(
                tx,
                f"""SELECT {LESSON_FIELDS} FROM app.study_lessons WHERE published
                AND (%s::smallint IS NULL OR hsk_level=%s)
                AND (%s::text IS NULL OR kind=%s) ORDER BY hsk_level,id LIMIT 100""",
                (level, level, kind, kind),
            )
        return Result(200, {"items": [public_lesson(row) for row in rows]})

    async def get_lesson(self, call: Call) -> Result:
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            row = await self._lesson(tx, call.path["lesson_id"])
        return Result(200, public_lesson(row))

    async def submit(self, call: Call) -> Result:
        owner, lesson_id = call.identity.user_id, call.path["lesson_id"]
        body = call.body
        digest = fingerprint(call, "study.attempt", {"lesson_id": lesson_id, **body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            row = await one(
                tx,
                """SELECT a.id,a.correct,a.payload_hash,a.lesson_id,a.revision,a.feedback
                FROM app.study_attempts a WHERE a.owner_id=%s AND a.client_key=%s""",
                (owner, call.idempotency_key),
            )
            replay = row is not None
            if replay and row["payload_hash"] != digest:
                raise ApiError(
                    409,
                    "IDEMPOTENCY_CONFLICT",
                    "Khóa thao tác đã dùng với dữ liệu khác.",
                )
            if not replay:
                lesson = await self._lesson(
                    tx, lesson_id, body["revision"], offline_submission=True
                )
                row = await one(
                    tx,
                    """INSERT INTO app.study_attempts
                    (owner_id,client_key,payload_hash,lesson_id,revision,correct,feedback)
                    VALUES (%s,%s,%s,%s,%s,%s,%s)
                    RETURNING id,correct,lesson_id,revision,feedback""",
                    (
                        owner,
                        call.idempotency_key,
                        digest,
                        lesson_id,
                        body["revision"],
                        grade(lesson, body),
                        lesson["solution"]["feedback"],
                    ),
                )
        return Result(
            200,
            {
                "id": str(row["id"]),
                "lesson_id": row["lesson_id"],
                "revision": row["revision"],
                "correct": row["correct"],
                "feedback": row["feedback"],
            },
            replayed=replay,
        )

    async def offline_pack(self, call: Call) -> Result:
        level = call.path["level"]
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            rows = await many(
                tx,
                f"""SELECT {LESSON_FIELDS} FROM app.study_lessons
                WHERE published AND hsk_level=%s ORDER BY id LIMIT 101""",
                (level,),
            )
        if len(rows) > 100:
            raise unavailable("CONTENT_UNAVAILABLE", "Gói học liệu vượt giới hạn.")
        items = [public_lesson(row, offline=True) for row in rows]
        version = hashlib.sha256(
            json.dumps(items, ensure_ascii=False, sort_keys=True).encode()
        ).hexdigest()
        return Result(
            200,
            {"level": level, "format_version": 1, "version": version, "items": items},
        )

    async def audio(self, call: Call) -> Result:
        return await self.tts.content(
            replace(
                call,
                body={
                    "kind": "study_lesson",
                    "lesson_id": call.path["lesson_id"],
                    "revision_id": call.body["revision"],
                    "option_id": call.body.get("option_id"),
                },
            )
        )

    async def transcribe(self, call: Call) -> Result:
        if self.transcriber is None or self.stt_model is None:
            raise unavailable(
                "PROVIDER_UNAVAILABLE", "Chưa cấu hình nhận diện giọng nói."
            )
        owner = call.identity.user_id
        digest = fingerprint(
            call,
            "study.speech",
            {
                "lesson_id": call.path["lesson_id"],
                **call.body,
                "mime": call.media.content_type,
                "audio_hash": hashlib.sha256(call.media.data).hexdigest(),
            },
        )
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await tx.execute(
                """DELETE FROM app.study_speech_requests WHERE owner_id=%s
                AND valid_until<clock_timestamp()-interval '1 day'""",
                (owner,),
            )
            await tx.execute(
                "DELETE FROM app.study_speech_quota WHERE owner_id=%s AND day<CURRENT_DATE-7",
                (owner,),
            )
            prior = await one(
                tx,
                """SELECT payload_hash,transcript,valid_until>clock_timestamp() AS live
                FROM app.study_speech_requests WHERE owner_id=%s AND client_key=%s""",
                (owner, call.idempotency_key),
            )
            if prior:
                if prior["payload_hash"] != digest:
                    raise ApiError(
                        409,
                        "IDEMPOTENCY_CONFLICT",
                        "Khóa thao tác đã dùng với bản thu khác.",
                    )
                if prior["transcript"] is not None:
                    return Result(
                        200, {"transcript": prior["transcript"]}, replayed=True
                    )
                if prior["live"]:
                    raise ApiError(
                        409,
                        "OPERATION_IN_PROGRESS",
                        "Bản thu đang được xử lý.",
                        retryable=True,
                    )
            lesson = await self._lesson(
                tx, call.path["lesson_id"], call.body["revision"]
            )
            if lesson["kind"] != "pronunciation":
                raise missing()
            allowed = await one(
                tx,
                """INSERT INTO app.study_speech_quota(owner_id,day,used)
                VALUES (%s,(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,1)
                ON CONFLICT(owner_id,day) DO UPDATE SET used=app.study_speech_quota.used+1
                WHERE app.study_speech_quota.used<20 RETURNING used""",
                (owner,),
            )
            if allowed is None:
                raise ApiError(
                    429, "QUOTA_EXCEEDED", "Đã hết lượt chuyển giọng nói hôm nay."
                )
            await tx.execute(
                """INSERT INTO app.study_speech_requests(owner_id,client_key,payload_hash)
                VALUES (%s,%s,%s) ON CONFLICT (owner_id,client_key) DO UPDATE
                SET valid_until=excluded.valid_until""",
                (owner, call.idempotency_key, digest),
            )
        try:
            async with asyncio.timeout(12):
                data = await self.transcriber.transcribe(self.stt_model, call.media)
        except TimeoutError as exc:
            raise ApiError(
                504, "PROVIDER_TIMEOUT", "Chưa nhận được bản chép lời.", retryable=True
            ) from exc
        text = (
            clean_text(data.get("transcript"))
            if isinstance(data, dict) and isinstance(data.get("transcript"), str)
            else None
        )
        if text is None or not 1 <= len(text) <= 2000:
            raise unavailable(
                "PROVIDER_UNAVAILABLE", "Chưa nhận được bản chép lời hợp lệ."
            )
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            await tx.execute(
                """UPDATE app.study_speech_requests SET transcript=%s
                WHERE owner_id=%s AND client_key=%s""",
                (text, owner, call.idempotency_key),
            )
        return Result(200, {"transcript": text})
