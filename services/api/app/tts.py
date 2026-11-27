import asyncio
import base64
import binascii
import hashlib
import io
import json
import os
import wave
from datetime import timedelta
from typing import Protocol
from uuid import uuid4

import httpx

from .accounts import Accounts, fingerprint
from .errors import ApiError, unavailable
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Media, Result
from .postgres import Database, one
from .reviews import server_time
from .storage import ImageStorage
from .vocabulary import missing


class SpeechProvider(Protocol):
    model: str
    voice: str

    async def speak(self, text: str) -> bytes: ...


class GeminiSpeech:
    def __init__(self, key, model, voice):
        self.key, self.model, self.voice = key, model, voice

    async def speak(self, text: str) -> bytes:
        body = {
            "model": self.model,
            "store": False,
            "input": [
                {"type": "user_input", "content": [{"type": "text", "text": text}]}
            ],
            "response_format": {
                "type": "audio",
                "mime_type": "audio/wav",
                "sample_rate": 24000,
            },
            "generation_config": {"speech_config": [{"voice": self.voice}]},
        }
        try:
            async with httpx.AsyncClient(timeout=14, follow_redirects=False) as client:
                response = await client.post(
                    "https://generativelanguage.googleapis.com/v1beta/interactions",
                    headers={"x-goog-api-key": self.key},
                    json=body,
                )
                response.raise_for_status()
            blocks = [
                block
                for step in response.json()["steps"]
                if step.get("type") == "model_output"
                for block in step.get("content", [])
                if block.get("type") == "audio"
            ]
            data = blocks[-1]["data"]
            if len(data) > 8_000_000:
                raise ValueError("speech response too large")
            wav = base64.b64decode(data, validate=True)
            with wave.open(io.BytesIO(wav), "rb") as audio:
                if (
                    audio.getnchannels() != 1
                    or audio.getsampwidth() != 2
                    or audio.getframerate() != 24000
                ):
                    raise ValueError("unexpected output format")
                samples = audio.getnframes()
                if (
                    not 0 < samples <= 24000 * 60
                    or len(audio.readframes(samples)) != samples * 2
                ):
                    raise ValueError("invalid audio")
            return wav
        except (
            httpx.HTTPError,
            KeyError,
            IndexError,
            TypeError,
            ValueError,
            AttributeError,
            binascii.Error,
            wave.Error,
            EOFError,
        ) as exc:
            raise unavailable(
                "PROVIDER_UNAVAILABLE", "Chưa tạo được giọng đọc."
            ) from exc


def speech_from_env():
    key = os.getenv("GEMINI_API_KEY", "").strip()
    model = os.getenv("HANYU_TTS_MODEL", "").strip()
    voice = os.getenv("HANYU_TTS_VOICE", "").strip()
    return GeminiSpeech(key, model, voice) if key and model and voice else None


class Tts:
    def __init__(
        self,
        db: Database,
        accounts: Accounts,
        storage: ImageStorage | None,
        provider: SpeechProvider | None,
    ):
        self.db, self.accounts, self.storage, self.provider = (
            db,
            accounts,
            storage,
            provider,
        )

    @staticmethod
    async def _source(tx, owner, body):
        kind, revision = body["kind"], body["revision_id"]
        if kind == "question":
            row = await one(
                tx,
                """SELECT m.id,m.object_key FROM app.questions q
              JOIN app.learning_audio m ON m.id=q.audio_media_id
              WHERE q.id=%s AND q.test_revision_id=%s AND EXISTS (SELECT FROM app.test_attempts a
                WHERE owner_id=%s AND a.test_revision_id=q.test_revision_id AND a.status<>'legacy_unverified')""",
                (body["question_id"], revision, owner),
            )
        elif kind == "study_lesson":
            row = await one(
                tx,
                """SELECT CASE WHEN kind='pinyin' THEN exercise->'tone_audio'->>(%s::text)
                  ELSE coalesce(exercise->>'audio_text',exercise->>'reference_text') END AS text
                FROM app.study_lessons WHERE id=%s AND revision=%s AND published
                  AND CASE WHEN kind='pinyin' THEN (exercise->'tone_audio') ? (%s::text)
                    ELSE kind IN ('dictation','pronunciation') AND %s::text IS NULL END""",
                (
                    body["option_id"],
                    body["lesson_id"],
                    revision,
                    body["option_id"],
                    body["option_id"],
                ),
            )
        elif kind == "vocabulary":
            row = await one(
                tx,
                """SELECT v.hanzi AS text FROM app.vocabulary v
                              JOIN app.vocabulary_revisions r ON r.id=v.published_revision_id
                              WHERE r.id=%s AND r.status='published'""",
                (revision,),
            )
        else:
            row = await one(
                tx,
                """SELECT r.content->'opening'->>'hanzi' AS text FROM app.scenarios s
                              JOIN app.scenario_revisions r ON r.id=s.published_revision_id
                              WHERE r.id=%s AND r.status='published'""",
                (revision,),
            )
        if row is None:
            raise missing()
        return row

    async def content(self, call: Call) -> Result:
        owner = call.identity.user_id
        operation = "tts.content"
        digest = fingerprint(call, operation, call.body)
        if self.storage is None:
            raise unavailable("CONTENT_UNAVAILABLE", "Kho audio chưa được cấu hình.")
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            source = await self._source(tx, owner, call.body)
            cached = True
            claimed = None
            if "text" not in source:
                media = source
            else:
                media = (
                    await one(
                        tx,
                        "SELECT id,object_key FROM app.tts_cache WHERE id=%s AND state='ready'",
                        (prior,),
                    )
                    if prior
                    else None
                )
                if media is None:
                    if self.provider is None:
                        raise unavailable(
                            "PROVIDER_UNAVAILABLE",
                            "Chưa cấu hình nhà cung cấp giọng đọc.",
                        )
                    cache_key = hashlib.sha256(
                        json.dumps(
                            [
                                call.body,
                                source["text"],
                                self.provider.model,
                                self.provider.voice,
                                "wav-24000",
                            ],
                            sort_keys=True,
                        ).encode()
                    ).hexdigest()
                    media = await one(
                        tx,
                        "SELECT id,object_key FROM app.tts_cache WHERE cache_key=%s AND state='ready'",
                        (cache_key,),
                    )
                    if media is None:
                        claimed = await self._claim(tx, cache_key)
        if claimed is not None:
            media = await self._generate(call, claimed, source["text"])
            cached = False
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            await self._source(tx, owner, call.body)
            replay = await receipt(tx, call, operation, digest)
            if replay is None:
                await write_receipt(tx, call, operation, digest, media["id"], "media")
            now = await server_time(tx)
        return Result(
            200,
            {
                "media_id": str(media["id"]),
                "cached": cached,
                "url": await self.storage.sign(media["object_key"], 300),
                "expires_at": (now + timedelta(seconds=300)).isoformat(),
            },
            replayed=replay is not None,
        )

    @staticmethod
    async def _claim(tx, cache_key):
        identifier, lease = uuid4(), uuid4()
        row = await one(
            tx,
            """INSERT INTO app.tts_cache(id,cache_key,state,object_key,lease,lease_until)
          VALUES (%s,%s,'processing',%s,%s,clock_timestamp()+interval '30 seconds')
          ON CONFLICT (cache_key) DO UPDATE SET lease=excluded.lease,lease_until=excluded.lease_until,
            state='processing',object_key=excluded.object_key
          WHERE app.tts_cache.state='failed' OR (app.tts_cache.state='processing' AND app.tts_cache.lease_until<=clock_timestamp())
          RETURNING id,object_key,lease""",
            (identifier, cache_key, f"tts/{identifier}.wav", lease),
        )
        if row is None:
            raise ApiError(
                409,
                "OPERATION_IN_PROGRESS",
                "Đang tạo giọng đọc. Hãy thử lại.",
                retryable=True,
            )
        await tx.execute(
            "INSERT INTO app.tts_uploads (lease, object_key) VALUES (%s,%s)",
            (row["lease"], row["object_key"]),
        )
        return row

    async def _generate(self, call, claimed, text):
        try:
            async with asyncio.timeout(25):
                async with asyncio.timeout(15):
                    audio = await self.provider.speak(text)
                await self.storage.store(
                    claimed["object_key"], Media(audio, "audio/wav")
                )
        except (ApiError, TimeoutError) as exc:
            async with self.db.transaction(call.identity) as tx:
                await tx.execute(
                    "UPDATE app.tts_cache SET state='failed' WHERE id=%s AND lease=%s AND state='processing'",
                    (claimed["id"], claimed["lease"]),
                )
            if isinstance(exc, TimeoutError):
                raise unavailable(
                    "PROVIDER_UNAVAILABLE", "Tạo giọng đọc quá thời gian."
                ) from exc
            raise
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            saved = await one(
                tx,
                """UPDATE app.tts_cache SET state='ready',updated_at=clock_timestamp()
                WHERE id=%s AND lease=%s AND state='processing' AND lease_until>clock_timestamp()
                RETURNING id,object_key""",
                (claimed["id"], claimed["lease"]),
            )
            if saved is None:
                raise ApiError(
                    409,
                    "OPERATION_IN_PROGRESS",
                    "Phiên tạo audio hết hạn, hãy thử lại.",
                    retryable=True,
                )
            await tx.execute(
                "DELETE FROM app.tts_uploads WHERE lease = %s", (claimed["lease"],)
            )
            return saved
