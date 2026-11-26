"""Shared deterministic train/inference preprocessing of isolated ink images."""

from dataclasses import asdict, dataclass

import numpy as np
from PIL import Image, ImageOps


@dataclass(frozen=True)
class PreprocessConfig:
    version: str = "ink64-v1-provisional"
    size: int = 64
    content_size: int = 48
    foreground_threshold: int = 220
    minimum_ink_pixels: int = 8
    max_pixels: int = 16_000_000

    def __post_init__(self):
        if not 0 < self.content_size <= self.size or not 0 < self.foreground_threshold < 255:
            raise ValueError("Invalid preprocessing dimensions or threshold")
        if self.minimum_ink_pixels < 1 or self.max_pixels < 1:
            raise ValueError("Pixel limits must be positive")

    def to_dict(self):
        return asdict(self)


class InvalidInk(ValueError):
    pass


def preprocess(image: Image.Image, config: PreprocessConfig = PreprocessConfig()) -> np.ndarray:
    if image.width * image.height > config.max_pixels:
        raise InvalidInk("Image exceeds configured pixel limit")
    image = ImageOps.exif_transpose(image).convert("RGBA")
    background = Image.new("RGBA", image.size, "white")
    gray = np.asarray(Image.alpha_composite(background, image).convert("L"))
    mask = gray < config.foreground_threshold
    if np.count_nonzero(mask) < config.minimum_ink_pixels:
        raise InvalidInk("Blank canvas or insufficient ink")
    ys, xs = np.nonzero(mask)
    crop = Image.fromarray(gray).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    ratio = config.content_size / max(crop.size)
    dimensions = tuple(max(1, min(config.content_size, round(v * ratio))) for v in crop.size)
    resized = crop.resize(dimensions, Image.Resampling.BILINEAR)
    canvas = Image.new("L", (config.size, config.size), 255)
    canvas.paste(resized, ((config.size - resized.width) // 2, (config.size - resized.height) // 2))
    return np.ascontiguousarray((255 - np.asarray(canvas, dtype=np.float32))[None] / 255)
