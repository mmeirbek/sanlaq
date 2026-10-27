"""Иллюстрации режимов для экрана выбора — с одного взгляда понятно, во что играть.

96×56 пикселей арта, сохраняются ×2 в assets/sprites/modes/<id>.png. Соқыртеке
собирается из тех же спрайтов персонажей, остальное рисуется простыми формами
в общей палитре.
"""
import os

import characters as ch
from item_icons import ellipse
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save

WIDTH, HEIGHT = 96, 56
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "modes")


def _ground(canvas, top, ramp_names, seed=7):
    """Полоса земли от top до низа с редкими травинками."""
    light, base, dark = (c(n) for n in ramp_names)
    fill(canvas, rows({y: (0, WIDTH - 1) for y in range(top, HEIGHT)}), base)
    for x in range(0, WIDTH, 5):
        y = top + 2 + (x * seed) % (HEIGHT - top - 3)
        fill(canvas, {(x, y), (x + 1, y - 1)}, light)
        fill(canvas, {(x + 2, y)}, dark)


def _character(body, items, direction, frame):
    """Кадр персонажа в одежде — та же сборка, что в игре."""
    sprite = ch.body_sheet(body).image.copy()
    for item in items:
        sprite.alpha_composite(ch.item_sheet(item).image)
    row = ch.DIRECTIONS.index(direction)
    return sprite.crop((frame * ch.CELL, row * ch.CELL, (frame + 1) * ch.CELL, (row + 1) * ch.CELL))


def sokyroteke():
    """Ловец с повязкой на глазах и двое убегающих."""
    canvas = Canvas(WIDTH, HEIGHT, c("grass_mid"))
    _ground(canvas, 0, ("grass_light", "grass_mid", "grass_dark"))
    seeker = _character("base", ["shoes_kebis_01", "pants_shalbar_01", "torso_koylek_01"], "down", 0)
    canvas.image.alpha_composite(seeker, (8, 20))
    _blindfold(canvas, 8, 20)
    runner_a = _character("base_02", ["shoes_masi_01", "pants_shalbar_decorated_01", "torso_kamzol_01", "head_takiya_01"], "right", 2)
    runner_b = _character("base_03", ["shoes_saptama_etik_01", "pants_shalbar_01", "torso_shapan_01", "head_borik_01"], "right", 4)
    canvas.image.alpha_composite(runner_a, (46, 18))
    canvas.image.alpha_composite(runner_b, (66, 24))
    return canvas


def abai_says():
    """Дастархан с тремя блюдами: баурсак, құрт, қымыз."""
    canvas = Canvas(WIDTH, HEIGHT, c("felt"))
    fill(canvas, rows({y: (0, WIDTH - 1) for y in range(0, 14)}), c("felt_dark"))
    cloth = rows({y: (6, 89) for y in range(16, 52)})
    paint(canvas, cloth, (c("red_light"), c("burgundy_light"), c("burgundy")))
    fill(canvas, {(x, y) for x, y in cloth if y in (18, 49) and x % 4 < 2}, c("gold"))
    for cx in (24, 48, 72):
        plate = ellipse(cx, 36, 10, 6)
        paint(canvas, plate, (c("parchment"), c("parchment_dark"), c("cloth_shadow")))
    for dx, dy in ((-4, -2), (0, -4), (4, -2), (-2, 1), (3, 1)):
        paint(canvas, ellipse(24 + dx, 36 + dy, 2.5, 2.5), (c("gold_light"), c("ember"), c("gold_dark")))
    for dx, dy in ((-4, -1), (0, -3), (4, -1), (0, 1)):
        paint(canvas, ellipse(48 + dx, 36 + dy, 2.5, 2.5), (c("parchment"), c("cloth_shadow"), c("muted")))
    bowl = ellipse(72, 34, 7, 5)
    paint(canvas, bowl, (c("wood_light"), c("wood"), c("wood_dark")))
    fill(canvas, ellipse(72, 32, 5, 2), c("parchment"))
    outline(canvas)
    return canvas


def togyz_qumalaq():
    """Деревянная доска: два ряда по девять отау и два қазана посередине."""
    canvas = Canvas(WIDTH, HEIGHT, c("ink"))
    board = rows({y: (2, 93) for y in range(4, 52)})
    paint(canvas, board, (c("wood_light"), c("wood"), c("wood_dark")))
    for row_y in (11, 45):
        for i in range(9):
            hole = ellipse(8 + i * 10, row_y, 3.5, 4)
            paint(canvas, hole, (c("wood_dark"), c("leather_dark"), c("outline")))
            for k in range(1 + (i * 3 + row_y) % 3):
                fill(canvas, {(7 + i * 10 + k, row_y - 1 + k % 2)}, c("parchment"))
    for kazan_x in (24, 72):
        kazan = rows({y: (kazan_x - 18, kazan_x + 18) for y in range(24, 33)})
        paint(canvas, kazan, (c("wood_dark"), c("leather_dark"), c("outline")))
        for k in range(0, 30, 3):
            fill(canvas, {(kazan_x - 15 + k, 27 + (k // 3) % 3)}, c("parchment"))
    fill(canvas, {(x, 28) for x in range(46, 50)}, c("gold"))
    return canvas


def aq_suyek():
    """Ночная степь, луна, звёзды и светящаяся белая кость в траве."""
    canvas = Canvas(WIDTH, HEIGHT, c("night"))
    for y in range(0, 36):
        if y > 22:
            fill(canvas, rows({y: (0, WIDTH - 1)}), c("night_violet") if y < 30 else c("dusk"))
    for x, y in ((8, 6), (22, 12), (37, 4), (55, 9), (81, 15), (66, 3), (14, 19), (44, 17)):
        fill(canvas, {(x, y)}, c("parchment"))
    moon = ellipse(80, 10, 6, 6) - ellipse(83, 8, 5, 5)
    fill(canvas, moon, c("sun"))
    _ground(canvas, 36, ("grass_dark", "grass_deep", "outline"), seed=5)
    glow = ellipse(48, 44, 16, 6)
    fill(canvas, glow, c("grass_dark"))
    bone = rows({44: (41, 55)}) | rows({43: (41, 55)}) | ellipse(41, 43.5, 2.5, 2.5) | ellipse(55, 43.5, 2.5, 2.5)
    paint(canvas, bone, (c("parchment"), c("parchment"), c("cloth_shadow")))
    return canvas


def dala_zholy():
    """Три героя «Дала жолы» на закатной степи под знаменем: Керей, Абылай, Қабанбай."""
    canvas = Canvas(WIDTH, HEIGHT, c("sunset"))
    for y in range(0, 20):
        fill(canvas, rows({y: (0, WIDTH - 1)}), c("sunset_pink") if y < 8 else c("peach"))
    sun = ellipse(70, 22, 9, 9)
    fill(canvas, {(x, y) for x, y in sun if y < 26}, c("sun"))
    _ground(canvas, 26, ("grass_light", "grass", "grass_dark"))
    fill(canvas, rows({y: (14, 15) for y in range(4, 46)}), c("wood_dark"))
    fill(canvas, rows({y: (16, 28 - abs(y - 11) // 2) for y in range(5, 18)}), c("burgundy_light"))
    fill(canvas, {(21, 10), (22, 11), (21, 12), (20, 11), (21, 11)}, c("gold_light"))
    heroes = [
        ("base", ["shoes_saptama_etik_01", "pants_shalbar_01", "torso_shapan_01", "head_borik_01"]),
        ("base_03", ["shoes_saptama_etik_01", "pants_shalbar_decorated_01", "torso_kamzol_01", "head_borik_01"]),
        ("base", ["shoes_saptama_etik_01", "pants_shalbar_decorated_01", "torso_sauyt_01", "head_dulyga_01"]),
    ]
    for i, (body, items) in enumerate(heroes):
        canvas.image.alpha_composite(_character(body, items, "down", 0), (26 + i * 20, 22))
    return canvas


def _blindfold(canvas, x, y):
    """Красная повязка на глазах персонажа, нарисованного в клетке с углом (x, y)."""
    fill(canvas, rows({y + 10: (x + 11, x + 20), y + 11: (x + 11, x + 20)}), c("red_light"))
    fill(canvas, {(x + 21, y + 11), (x + 22, y + 12)}, c("red_light"))


def role_seeker():
    """Роль «Соқыртеке»: ловец с завязанными глазами."""
    canvas = Canvas(ch.CELL, ch.CELL)
    canvas.image.alpha_composite(_character("base", ["shoes_kebis_01", "pants_shalbar_01", "torso_koylek_01"], "down", 0))
    _blindfold(canvas, 0, 0)
    return canvas


def role_runner():
    """Роль «Қашушы»: бегущий в профиль."""
    canvas = Canvas(ch.CELL, ch.CELL)
    canvas.image.alpha_composite(_character("base_02", ["shoes_masi_01", "pants_shalbar_decorated_01", "torso_kamzol_01", "head_takiya_01"], "right", 2))
    return canvas


ROLES = {"role_seeker": role_seeker, "role_runner": role_runner}

ART = {
    "sokyroteke": sokyroteke,
    "abai_says": abai_says,
    "togyz_qumalaq": togyz_qumalaq,
    "aq_suyek": aq_suyek,
    "dala_zholy": dala_zholy,
}


def build():
    drawings = {**ART, **ROLES}
    return [save(draw(), os.path.join(OUT_DIR, name + ".png")) for name, draw in drawings.items()]
