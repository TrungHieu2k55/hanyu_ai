import asyncio
import hashlib
import io
import math
import os
from pathlib import Path
from threading import Lock
from typing import Protocol
from uuid import UUID, uuid4

from psycopg.types.json import Jsonb

from .accounts import Accounts, fingerprint
from .errors import ApiError, unavailable
from .operations import lock_owner, receipt, write_receipt
from .ports import Call, Result
from .postgres import Database, many, one
from .vocabulary import missing, uuid_str


class Model(Protocol):
    version: str
    sha256: str
    preprocess_version: str

    def logits(self, image: bytes) -> list[float]: ...


class OnnxModel:
    def __init__(self, version: str, path: str, expected_hash: str):
        import onnxruntime
        from hanyu_cnn.preprocess import InvalidInk, PreprocessConfig, preprocess
        from PIL import Image

        with Path(path).open("rb") as artifact:
            model = artifact.read(64 * 1024 * 1024 + 1)
        if (
            len(model) > 64 * 1024 * 1024
            or hashlib.sha256(model).hexdigest() != expected_hash
        ):
            raise ValueError(
                "CNN weight file is too large or its checksum does not match"
            )
        self._session = onnxruntime.InferenceSession(
            model, providers=["CPUExecutionProvider"]
        )
        self._prepare = preprocess
        self._image = Image
        self._invalid_ink = InvalidInk
        self._config = PreprocessConfig()
        self.version, self.sha256 = version, expected_hash
        self.preprocess_version = self._config.version

    def logits(self, image: bytes) -> list[float]:
        try:
            with self._image.open(io.BytesIO(image)) as canvas:
                tensor = self._prepare(canvas, self._config)[None]
        except self._invalid_ink as exc:
            raise ApiError(
                422, "INVALID_CANVAS", "Hãy viết chữ trước khi nhận diện."
            ) from exc
        result = self._session.run(None, {self._session.get_inputs()[0].name: tensor})[
            0
        ]
        if result.ndim != 2 or result.shape[0] != 1:
            raise ValueError("unexpected CNN output")
        return result[0].tolist()


def model_from_env():
    version, path, checksum = [
        os.getenv(var, "").strip()
        for var in ("HANYU_CNN_VERSION", "HANYU_CNN_ONNX", "HANYU_CNN_SHA256")
    ]
    if not any((version, path, checksum)):
        return None
    if not all((version, path, checksum)):
        raise ValueError("Configure CNN version, path and checksum together")
    return OnnxModel(version, path, checksum)


def rank(logits, classes):
    if (
        len(classes) < 3
        or len(logits) != len(classes)
        or not all(math.isfinite(x) for x in logits)
    ):
        raise unavailable(
            "MODEL_UNAVAILABLE", "Đầu ra CNN không phù hợp danh sách chữ."
        )
    peak = max(logits)
    weights = [math.exp(x - peak) for x in logits]
    total = sum(weights)
    ordered = sorted(range(len(weights)), key=weights.__getitem__, reverse=True)[:3]
    return [
        {
            "character_id": str(classes[i]["character_id"]),
            "hanzi": classes[i]["hanzi"],
            "rank": position,
            "confidence": weights[i] / total,
        }
        for position, i in enumerate(ordered, 1)
    ]


class HandwritingCnn:
    def __init__(self, db: Database, accounts: Accounts, model: Model | None):
        self.db, self.accounts, self.model = db, accounts, model
        self._slot = Lock()

    async def published(self, tx):
        if self.model is None:
            return None
        return await one(
            tx,
            """SELECT * FROM app.model_versions WHERE status='published'
                            AND model_version=%s AND weights_sha256=%s AND preprocess_version=%s""",
            (self.model.version, self.model.sha256, self.model.preprocess_version),
        )

    def _infer(self, image):
        try:
            return self.model.logits(image)
        finally:
            self._slot.release()

    async def predict(self, call: Call) -> Result:
        owner = call.identity.user_id
        operation = "writing.predict"
        digest = fingerprint(
            call, operation, {"sha256": hashlib.sha256(call.media.data).hexdigest()}
        )
        async with self.db.transaction(call.identity) as tx:
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._dto(tx, owner, prior), replayed=True)
            model = await self.published(tx)
            if model is None:
                raise unavailable(
                    "MODEL_UNAVAILABLE", "Chưa nạp model chữ viết đã công bố."
                )
            classes = await many(
                tx,
                """SELECT m.class_index,m.character_id,c.hanzi FROM app.model_classes m
                  JOIN app.characters c ON c.id=m.character_id WHERE m.model_id=%s ORDER BY m.class_index""",
                (model["id"],),
            )
            if any(c["class_index"] != index for index, c in enumerate(classes)):
                raise unavailable(
                    "MODEL_UNAVAILABLE", "Danh sách lớp CNN không liên tục."
                )
        if not self._slot.acquire(blocking=False):
            raise unavailable("MODEL_UNAVAILABLE", "Model đang xử lý ảnh khác.")
        try:
            logits = await asyncio.wait_for(
                asyncio.shield(asyncio.to_thread(self._infer, call.media.data)), 5
            )
        except TimeoutError as exc:
            raise ApiError(
                504, "MODEL_UNAVAILABLE", "Nhận diện quá thời gian.", retryable=True
            ) from exc
        except (ValueError, RuntimeError) as exc:
            raise unavailable(
                "MODEL_UNAVAILABLE", "Không thể nhận diện với model hiện tại."
            ) from exc
        candidates = rank(logits, classes)
        threshold = model["confidence_threshold"]
        if threshold is None:
            uncertainty = "not_calibrated"
        else:
            low = candidates[0]["confidence"] < float(threshold) or (
                candidates[0]["confidence"] - candidates[1]["confidence"]
                < float(model["margin_threshold"])
            )
            uncertainty = "low_confidence" if low else "normal"
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            if prior is not None:
                return Result(200, await self._dto(tx, owner, prior), replayed=True)
            identifier = uuid4()
            op = await write_receipt(
                tx, call, operation, digest, identifier, "prediction_attempt"
            )
            await tx.execute(
                """INSERT INTO app.prediction_attempts(id,owner_id,model_id,operation_id,candidates,uncertainty)
                VALUES (%s,%s,%s,%s,%s,%s)""",
                (identifier, owner, model["id"], op, Jsonb(candidates), uncertainty),
            )
            return Result(200, await self._dto(tx, owner, identifier))

    @staticmethod
    async def _dto(tx, owner, prediction):
        row = await one(
            tx,
            """SELECT p.id,m.model_version,p.candidates,p.uncertainty,p.confirmed_character_id,p.confirmed_at
            FROM app.prediction_attempts p JOIN app.model_versions m ON m.id=p.model_id
            WHERE p.owner_id=%s AND p.id=%s""",
            (owner, prediction),
        )
        if row is None:
            raise missing()
        return {
            **row,
            "id": str(row["id"]),
            "confirmed_character_id": uuid_str(row["confirmed_character_id"]),
            "confirmed_at": row["confirmed_at"].isoformat()
            if row["confirmed_at"]
            else None,
        }

    async def confirm(self, call: Call) -> Result:
        owner, prediction, character = (
            call.identity.user_id,
            call.path["prediction_id"],
            call.body["character_id"],
        )
        operation = "writing.confirm"
        digest = fingerprint(call, operation, {**call.path, **call.body})
        async with self.db.transaction(call.identity) as tx:
            await lock_owner(tx, owner)
            await self.accounts.require_access(tx, call.identity)
            prior = await receipt(tx, call, operation, digest)
            result = await self._dto(tx, owner, prediction)
            if prior is not None:
                return Result(200, result, replayed=True)
            if result["confirmed_character_id"] not in {None, character.lower()}:
                raise ApiError(409, "INVALID_STATE", "Đã xác nhận một chữ khác.")
            if result["confirmed_character_id"] is None:
                valid = await one(
                    tx,
                    """SELECT c.character_id FROM app.prediction_attempts p JOIN app.model_classes c
                    ON c.model_id=p.model_id WHERE p.id=%s AND p.owner_id=%s AND c.character_id=%s""",
                    (prediction, owner, character),
                )
                if valid is None:
                    raise missing()
                await tx.execute(
                    """UPDATE app.prediction_attempts SET confirmed_character_id=%s,confirmed_at=clock_timestamp()
                    WHERE id=%s AND owner_id=%s""",
                    (character, prediction, owner),
                )
                await tx.execute(
                    """INSERT INTO app.activity_events(owner_id,prediction_attempt_id,occurred_at)
                    VALUES (%s,%s,clock_timestamp())""",
                    (owner, prediction),
                )
            await write_receipt(
                tx, call, operation, digest, UUID(prediction), "prediction_attempt"
            )
            return Result(200, await self._dto(tx, owner, prediction))
