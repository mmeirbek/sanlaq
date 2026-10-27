"""Ақ сүйек: сүйек, отау-көмбе двух команд и фигурки игроков на кольце своего
цвета. Сохраняются ×2 в assets/sprites/aq_suyek/. Көмбе и сүйек ставит на карту
scenes/world/aq_suyek.gd, фигурки — схемы экрана-объяснения (briefing_art.py).

Отау и фигурка рисуются на холсте CELL×CELL пикселей арта.
"""
import os

import characters as ch
from item_icons import ellipse, ramp
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "aq_suyek")
CELL = 36

def bone():
    """Сүйек 24×12 — белая кость с бликом, светится в темноте."""
    canvas = Canvas(24, 12)
    shape = rows({y: (5, 18) for y in range(5, 8)}) | ellipse(4, 4, 2.6, 2.6) | ellipse(4, 8, 2.6, 2.6) \
        | ellipse(19, 4, 2.6, 2.6) | ellipse(19, 8, 2.6, 2.6)
    paint(canvas, shape, (c("parchment"), c("cream"), c("cloth_shadow")))
    outline(canvas)
    return canvas


def otau(door):
    """Отау — маленькая юрта-көмбе у левого края холста; дверь в цвете команды."""
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
        "bone": bone(),
        "otau_human": otau(("blue_light", "blue", "blue_dark")),
        "otau_bot": otau(("rust_light", "rust", "rust_dark")),
        "token_human": token("base_02", ["shoes_masi_01", "pants_shalbar_01", "torso_kamzol_01", "head_takiya_01"],
                             "RUNNER"),
        "token_bot": token("base", ["shoes_kebis_01", "pants_shalbar_decorated_01", "torso_shapan_01",
                                    "head_tymaq_01"], "SEEKER"),
    }
    return art


def build():
    return [save(canvas, os.path.join(OUT_DIR, name + ".png")) for name, canvas in drawings().items()]
