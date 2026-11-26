import unicodedata
from dataclasses import dataclass
from itertools import groupby

from pypinyin import Style, lazy_pinyin


@dataclass(frozen=True)
class OcrLine:
    text: str
    confidence: float | None = None


def is_han(character: str) -> bool:
    return unicodedata.name(character, "").startswith(
        ("CJK UNIFIED IDEOGRAPH", "CJK COMPATIBILITY IDEOGRAPH")
    )


def make_tokens(lines: list[OcrLine], dictionary: set[str] | None = None) -> list[dict]:
    words = dictionary or set()
    sizes = sorted({len(word) for word in words if len(word) > 1}, reverse=True)
    tokens = []
    for line in lines:
        for chinese, group in groupby(line.text, is_han):
            if not chinese:
                continue
            chars = unicodedata.normalize("NFC", "".join(group))
            pronunciations = lazy_pinyin(
                chars, style=Style.TONE, errors=lambda text: list(text)
            )
            position = 0
            while position < len(chars):
                size = next(
                    (
                        n
                        for n in sizes
                        if position + n <= len(chars)
                        and chars[position : position + n] in words
                    ),
                    1,
                )
                hanzi = chars[position : position + size]
                reading = " ".join(pronunciations[position : position + size])
                tokens.append(
                    {
                        "hanzi": hanzi,
                        "pinyin": reading
                        if reading.replace(" ", "") != hanzi
                        else None,
                        "confidence": line.confidence,
                    }
                )
                position += size
    return tokens
