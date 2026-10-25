"""Тоғыз құмалақ: лунка-отау, её подсветка и туздық, камешек-құмалақ и қазан.
Сохраняются ×2 в assets/sprites/togyz/.

Лунка — тёмная выемка в дереве; камешки экран раскладывает поверх неё
(до 12 штук сеткой 3×4), число камней пишется отдельно и видно всегда.
"""
import os

from item_icons import ellipse, ramp
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, save

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "togyz")
PIT_W, PIT_H = 28, 36


def _pit_hole():
    return ellipse(PIT_W / 2, PIT_H / 2, PIT_W / 2 - 1, PIT_H / 2 - 1)


def pit(rim, inside):
    """Овальная выемка: тень сверху (дерево нависает), светлый край снизу."""
    canvas = Canvas(PIT_W, PIT_H)
    hole = _pit_hole()
    fill(canvas, hole, c(inside[1]))
    for x, y in hole:
        if (x, y - 2) not in hole:
            canvas.put(x, y, c(inside[2]))
        elif (x, y + 1) not in hole:
            canvas.put(x, y, c(inside[0]))
    ring = {(x, y) for x, y in hole if (x - 1, y) not in hole or (x + 1, y) not in hole
            or (x, y - 1) not in hole or (x, y + 1) not in hole}
    fill(canvas, ring, c(rim))
    return canvas


def pit_ring(color_name):
    """Кольцо вокруг лунки, рисуется поверх неё."""
    canvas = Canvas(PIT_W + 4, PIT_H + 4)
    outer = ellipse(PIT_W / 2 + 2, PIT_H / 2 + 2, PIT_W / 2 + 1, PIT_H / 2 + 1)
    inner = ellipse(PIT_W / 2 + 2, PIT_H / 2 + 2, PIT_W / 2 - 1, PIT_H / 2 - 1)
    fill(canvas, outer - inner, c(color_name))
    return canvas


def tuzdyk_mark():
    """Знак туздыка в лунке: золотой ромб-орнамент."""
    canvas = Canvas(14, 14)
    for y in range(14):
        for x in range(14):
            d = abs(x - 6.5) + abs(y - 6.5)
            if d <= 6.5:
                canvas.put(x, y, c("gold") if d > 4.5 else c("burgundy") if d > 2.5 else c("gold_light"))
    outline(canvas)
    return canvas


def stone():
    """Құмалақ 6×6: светлый камешек с бликом."""
    canvas = Canvas(6, 6)
    paint(canvas, ellipse(3, 3, 2.6, 2.6), ramp("parchment", "felt", "felt_dark"))
    canvas.put(2, 1, c("parchment"))
    outline(canvas)
    return canvas


def kazan():
    """Қазан 32×24 — котёл, куда собираются камни игрока."""
    canvas = Canvas(32, 24)
    body = {(x, y) for x, y in ellipse(16, 10, 13, 12) if y >= 10}
    paint(canvas, body, ramp("steel_light", "steel", "steel_dark"))
    rim = ellipse(16, 10, 14, 3)
    paint(canvas, rim, ramp("steel_light", "steel_dark", "ink"))
    heap = {(x, y) for x, y in ellipse(16, 10, 11, 2.2)} | {(x, y) for x, y in ellipse(16, 8, 7, 2.5)}
    paint(canvas, heap, ramp("parchment", "felt", "felt_dark"))
    for x in (2, 29):
        fill(canvas, {(x, 9), (x, 10), (x, 11)}, c("steel_dark"))
    outline(canvas)
    return canvas


def drawings():
    return {
        "pit": pit("wood_dark", ("leather", "leather_dark", "ink")),
        "pit_tuzdyk": pit("gold_dark", ("burgundy_light", "burgundy", "burgundy_dark")),
        # Кольцо доступного хода и вспышка лунки, куда только что упал камень.
        "pit_ring": pit_ring("gold_light"),
        "pit_glow": pit_ring("parchment"),
        "tuzdyk_mark": tuzdyk_mark(),
        "stone": stone(),
        "kazan": kazan(),
    }


def build():
    return [save(canvas, os.path.join(OUT_DIR, name + ".png")) for name, canvas in drawings().items()]
