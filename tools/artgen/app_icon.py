"""Иконка приложения: золотой шаңырақ на бордовой плитке с золотой рамкой.
32×32 пикселя арта, сохраняется ×16 — 512×512, как ждут Godot и web-экспорт.
"""
import os

from item_icons import ellipse
from palette import ROOT, color as c
from pixel import Canvas, fill, save

OUT = os.path.join(ROOT, "assets", "sprites", "ui", "app_icon.png")
SIZE = 32


def icon():
    canvas = Canvas(SIZE, SIZE, c("burgundy"))
    canvas.ring(0, c("outline"), c("outline"), c("outline"), c("outline"))
    canvas.ring(1, c("gold_light"), c("gold_light"), c("gold_dark"), c("gold_dark"))
    canvas.ring(2, c("burgundy_dark"), c("burgundy_dark"), c("burgundy_dark"), c("burgundy_dark"))
    cx = cy = SIZE / 2
    rim = ellipse(cx, cy, 11, 11) - ellipse(cx, cy, 8, 8)
    fill(canvas, rim, c("gold"))
    fill(canvas, {(x, y) for x, y in rim if x + y < SIZE - 2}, c("gold_light"))
    # Күлдіреуіш: две пары перекрещенных дуг внутри венца.
    inner = ellipse(cx, cy, 8, 8)
    bars = {(x, y) for x, y in inner if abs(x + 0.5 - cx) < 1.2 or abs(y + 0.5 - cy) < 1.2}
    fill(canvas, bars, c("gold_dark"))
    fill(canvas, {(x, y) for x, y in inner if (x, y) not in bars}, c("ink"))
    # Уықтар — лучи от венца к рамке.
    for k in range(4, SIZE - 4, 3):
        for x, y in ((k, 4), (k, SIZE - 5), (4, k), (SIZE - 5, k)):
            if (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2 > 12 ** 2:
                canvas.put(x, y, c("gold_dark"))
    return canvas


def build():
    return [save(icon(), OUT, scale=16)]
