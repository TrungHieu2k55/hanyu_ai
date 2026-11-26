import io
import os
import subprocess
import tempfile
import warnings
import wave
from pathlib import Path

from PIL import Image, UnidentifiedImageError
from starlette.concurrency import run_in_threadpool

from .errors import ApiError, unavailable
from .ports import Media

MIB = 1024 * 1024
IMAGE_TYPES = {"image/jpeg": "JPEG", "image/png": "PNG", "image/webp": "WEBP"}
AUDIO_TYPES = {
    "audio/wav": "wav",
    "audio/webm": "matroska",
    "audio/ogg": "ogg",
    "audio/mp4": "mov",
}


def media_limit(operation: str) -> int:
    if operation == "uploadLearningMedia":
        return 10 * MIB
    if operation == "updateAvatar":
        return 2 * MIB
    if operation == "predictCharacter":
        return MIB
    return (10 if operation == "transcribeAudio" else 8) * MIB


def too_large() -> ApiError:
    return ApiError(413, "FILE_TOO_LARGE", "Dung lượng vượt giới hạn cho phép.")


def invalid_type() -> ApiError:
    return ApiError(415, "INVALID_FILE_TYPE", "Định dạng tệp không được hỗ trợ.")


def invalid_audio() -> ApiError:
    return ApiError(
        422, "INVALID_AUDIO", "Bản thu không đọc được hoặc dài hơn 20 giây."
    )


def verify_image(media: Media, *, canvas: bool) -> None:
    allowed = {"image/png": "PNG"} if canvas else IMAGE_TYPES
    if media.content_type not in allowed:
        raise invalid_type()
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(media.data)) as image:
                if image.format != allowed[media.content_type]:
                    raise invalid_type()
                if (
                    image.width * image.height > 16_000_000
                    or getattr(image, "n_frames", 1) != 1
                ):
                    raise ValueError("invalid image dimensions")
                image.verify()
            with Image.open(io.BytesIO(media.data)) as image:
                image.load()
    except (
        UnidentifiedImageError,
        OSError,
        ValueError,
        SyntaxError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ) as exc:
        raise ApiError(
            422,
            "INVALID_CANVAS" if canvas else "INVALID_INPUT",
            "Ảnh trống, bị hỏng hoặc vượt giới hạn kích thước.",
        ) from exc


def verify_wav(data: bytes, max_seconds: int) -> bool:
    try:
        with wave.open(io.BytesIO(data), "rb") as audio:
            rate, frames = audio.getframerate(), audio.getnframes()
            if rate < 1 or not 0 < frames <= rate * max_seconds:
                raise invalid_audio()
            sample_bytes = audio.getnchannels() * audio.getsampwidth()
            if len(audio.readframes(frames)) != frames * sample_bytes:
                raise invalid_audio()
            return True
    except (wave.Error, EOFError):
        return False


async def verify_audio(media: Media, *, learning: bool = False) -> None:
    formats = (
        {
            "audio/wav": "wav",
            "audio/mpeg": "mp3",
            "audio/mp4": "mov",
            "audio/ogg": "ogg",
        }
        if learning
        else AUDIO_TYPES
    )
    max_seconds = 1200 if learning else 20
    if media.content_type not in formats:
        raise invalid_type()
    if media.content_type == "audio/wav" and verify_wav(media.data, max_seconds):
        return
    executable = os.getenv("HANYU_FFMPEG", "").strip()
    if not executable:
        if media.content_type == "audio/wav":
            raise invalid_audio()
        raise unavailable("PROVIDER_UNAVAILABLE", "Bộ giải mã audio chưa cấu hình.")
    audio_format = formats[media.content_type]
    with tempfile.TemporaryDirectory(prefix="hanyu-audio-") as directory:
        path = Path(directory) / "upload"
        await run_in_threadpool(path.write_bytes, media.data)
        try:
            result = await run_in_threadpool(
                subprocess.run,
                [
                    executable,
                    "-nostdin",
                    "-v",
                    "error",
                    "-xerror",
                    "-protocol_whitelist",
                    "file,pipe",
                    "-f",
                    audio_format,
                    "-i",
                    str(path),
                    "-map",
                    "0:a:0",
                    "-ac",
                    "1",
                    "-ar",
                    "16000",
                    "-t",
                    f"{max_seconds}.10",
                    "-f",
                    "s16le",
                    "pipe:1",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=6,
                check=False,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        except OSError as exc:
            raise unavailable(
                "PROVIDER_UNAVAILABLE", "Bộ giải mã audio không sẵn sàng."
            ) from exc
        except subprocess.TimeoutExpired as exc:
            raise unavailable(
                "PROVIDER_UNAVAILABLE", "Bộ giải mã audio quá thời gian."
            ) from exc
        if (
            result.returncode != 0
            or not 0 < len(result.stdout) <= max_seconds * 16000 * 2
        ):
            raise invalid_audio()
