"""Палитра для генераторов арта.

- assets/palette/sanlaq.gpl — общая палитра всего пиксель-арта (имена в нижнем
  регистре: "gold", "skin_dark", "water_deep"...);
- scripts/ui/ui_tokens.gd — смысловые цвета интерфейса (имена ВЕРХНИМ регистром:
  "GOLD", "OUTLINE"...). Все они обязаны быть и в палитре.

color(name) понимает оба вида имён. quantize() сводит любую картинку (например,
перенесённую из atilla) к палитре.
"""
import os
import re

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PALETTE_PATH = os.path.join(ROOT, "assets", "palette", "sanlaq.gpl")
TOKENS_PATH = os.path.join(ROOT, "scripts", "ui", "ui_tokens.gd")

_GPL_RE = re.compile(r"^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\w+)\s*$", re.MULTILINE)
_TOKEN_RE = re.compile(r'^const\s+([A-Z_]+)\s*:=\s*Color\("([0-9a-fA-F]{6})"\)', re.MULTILINE)
_PIXEL_RE = re.compile(r'^const\s+PIXEL\s*:=\s*(\d+)', re.MULTILINE)


def _load_palette():
    text = open(PALETTE_PATH, encoding="utf-8").read()
    return {name: (int(r), int(g), int(b), 255) for r, g, b, name in _GPL_RE.findall(text)}


def _load_tokens():
    text = open(TOKENS_PATH, encoding="utf-8").read()
    tokens = {name: tuple(int(hex_[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
              for name, hex_ in _TOKEN_RE.findall(text)}
    return tokens, int(_PIXEL_RE.search(text).group(1))


PALETTE = _load_palette()
TOKENS, PIXEL = _load_tokens()
TRANSPARENT = (0, 0, 0, 0)


def color(name):
    """RGBA по имени: токен интерфейса ("GOLD") или цвет палитры ("skin_dark")."""
    return TOKENS[name] if name in TOKENS else PALETTE[name]


def quantize(image, dither=0.0):
    """Сводит картинку к палитре. dither — сила упорядоченного дизеринга
    (0 — без него; ~16 сохраняет плавные переходы неба на фонах).
    Альфа становится 0 или 255."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    height, width, _ = rgb.shape
    if dither:
        bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16 - 0.5
        rgb = rgb + np.tile(bayer, (height // 4 + 1, width // 4 + 1))[:height, :width, None] * dither
    palette = np.array([c[:3] for c in PALETTE.values()], dtype=np.float32)
    flat = rgb.reshape(-1, 3)
    out = np.empty_like(flat)
    # Кусками, чтобы большие фоны не съели память.
    for start in range(0, len(flat), 65536):
        chunk = flat[start:start + 65536]
        # «Redmean» — простая метрика, близкая к восприятию глаза.
        mean_red = (chunk[:, None, 0] + palette[None, :, 0]) / 2
        diff = chunk[:, None, :] - palette[None, :, :]
        dist = ((2 + mean_red / 256) * diff[..., 0] ** 2 + 4 * diff[..., 1] ** 2
                + (2 + (255 - mean_red) / 256) * diff[..., 2] ** 2)
        out[start:start + 65536] = palette[dist.argmin(axis=1)]
    result = np.dstack([out.reshape(height, width, 3), np.where(alpha >= 128, 255, 0)]).astype(np.uint8)
    return Image.fromarray(result, "RGBA")
