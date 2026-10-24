"""Ақ сүйек: ночное поле 5×5 — клетка травы, следы-подсказки, кольцо шага,
сүйек, отау-көмбе и фигурки двоих игроков. Сохраняются ×2 в assets/sprites/aq_suyek/.

Клетка — CELL×CELL пикселей арта. Всё, что лежит в клетке (след, кольцо,
отау, фигурка), рисуется на холсте того же размера: экран просто кладёт
картинки друг на друга в углу клетки.
"""
import os

import numpy as np

import characters as ch
from item_icons import ellipse, ramp
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "aq_suyek")
CELL = 36

# Подсказки по спецификации: чем ближе сүйек, тем горячее цвет следа.
HINTS = {
    "found": ("parchment", "cream"),
    "very_close": ("red_light", "rust"),
    "close": ("ember", "rust_light"),
    "near": ("sun", "gold"),
    "far": ("blue_light", "blue"),
}


def cell():
    """Ночная трава: тёмная клетка с бликами травинок и ступенчатой кромкой."""
    canvas = Canvas(CELL, CELL, c("grass_deep"))
    # Ночь: каждый второй пиксель через строку — тёмный.
    fill(canvas, {(x, y) for y in range(0, CELL, 2) for x in range(y % 4 // 2, CELL, 2)}, c("night"))
    rng = np.random.default_rng(3)
    for x, y in rng.integers(2, CELL - 2, size=(26, 2)):
        fill(canvas, {(int(x), int(y)), (int(x) + 1, int(y) - 1)}, c("grass_dark"))
    for x, y in rng.integers(3, CELL - 3, size=(6, 2)):
        fill(canvas, {(int(x), int(y))}, c("night_blue"))
    canvas.ring(0, c("grass_dark"), c("grass_dark"), c("night"), c("night"))
    return canvas


def hint(colors):
    """След-подсказка: рамка цвета подсказки и шахматная подсветка внутри —
    клетка «светится», но трава под ней видна, без полупрозрачности."""
    light, base = (c(n) for n in colors)
    canvas = Canvas(CELL, CELL)
    canvas.ring(1, light, light, base, base)
    canvas.ring(2, base, base, base, base)
    for y in range(3, CELL - 3):
        for x in range(3, CELL - 3):
            if (x + y) % 4 == 0:
                canvas.put(x, y, base)
    return canvas


def reach():
    """Кольцо клетки, куда можно шагнуть: золотые уголки."""
    canvas = Canvas(CELL, CELL)
    for x0, y0, dx, dy in ((0, 0, 1, 1), (CELL - 1, 0, -1, 1), (0, CELL - 1, 1, -1), (CELL - 1, CELL - 1, -1, -1)):
        for k in range(8):
            fill(canvas, {(x0 + dx * k, y0), (x0, y0 + dy * k)}, c("gold_light"))
            fill(canvas, {(x0 + dx * k, y0 + dy), (x0 + dx, y0 + dy * k)}, c("gold"))
    return canvas


def bone():
    """Сүйек 24×12 — белая кость с бликом, светится в темноте."""
    canvas = Canvas(24, 12)
    shape = rows({y: (5, 18) for y in range(5, 8)}) | ellipse(4, 4, 2.6, 2.6) | ellipse(4, 8, 2.6, 2.6) \
        | ellipse(19, 4, 2.6, 2.6) | ellipse(19, 8, 2.6, 2.6)
    paint(canvas, shape, (c("parchment"), c("cream"), c("cloth_shadow")))
    outline(canvas)
    return canvas


def otau(door):
    """Отау — маленькая юрта-көмбе у левого края клетки; дверь в цвете хозяина.
    Правая половина клетки свободна: там встаёт фигурка, вернувшаяся домой."""
    canvas = Canvas(CELL, CELL)
    cx = 11
    walls = rows({y: (2, 19) for y in range(20, 31)})
    roof = {(x, y) for y in range(10, 21) for x in range(22) if abs(x + 0.5 - cx) <= 2 + (y - 10) * 0.75}
    for x, y in walls:
        canvas.put(x, y, c("felt") if x < 14 else c("felt_dark"))
    fill(canvas, {(x, y) for x, y in walls if y == 22}, c("burgundy"))
    for x, y in roof:
        canvas.put(x, y, c("felt_dark") if x > cx + (y - 10) * 0.35 else c("felt"))
    fill(canvas, rows({10: (10, 12)}), c("wood"))
    paint(canvas, rows({y: (8, 13) for y in range(25, 31)}), ramp(*door))
    outline(canvas)
    return canvas


def token(body, items, ring):
    """Фигурка игрока: персонаж в одежде на кольце своего цвета."""
    canvas = Canvas(CELL, CELL)
    fill(canvas, ellipse(cx := CELL / 2, 31, 10, 3) - ellipse(cx, 31, 7, 1.6), c(ring))
    sprite = ch.body_sheet(body).image.copy()
    for item in items:
        sprite.alpha_composite(ch.item_sheet(item).image)
    frame = sprite.crop((0, 0, ch.CELL, ch.CELL))
    canvas.image.alpha_composite(frame, ((CELL - ch.CELL) // 2, 1))
    return canvas


def drawings():
    art = {
        "cell": cell(),
        "reach": reach(),
        "bone": bone(),
        "otau_human": otau(("blue_light", "blue", "blue_dark")),
        "otau_bot": otau(("rust_light", "rust", "rust_dark")),
        "token_human": token("base_02", ["shoes_masi_01", "pants_shalbar_01", "torso_kamzol_01", "head_takiya_01"],
                             "RUNNER"),
        "token_bot": token("base", ["shoes_kebis_01", "pants_shalbar_decorated_01", "torso_shapan_01",
                                    "head_tymaq_01"], "SEEKER"),
    }
    for name, colors in HINTS.items():
        art["hint_" + name] = hint(colors)
    return art


def build():
    return [save(canvas, os.path.join(OUT_DIR, name + ".png")) for name, canvas in drawings().items()]
