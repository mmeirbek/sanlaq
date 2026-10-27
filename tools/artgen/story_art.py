"""Арт «Дала жолы»: реквизит аула, степи и Түркістана, части юрты и стадии её
сборки, маркеры, иконки статей энциклопедии. Сохраняется ×2 в
assets/sprites/story/<имя>.png. Мир тот же, что у Соқыртеке (world_art.py):
вид 3/4, свет сверху слева, тень на траве.
"""
import os

from PIL import Image

import world_art
from item_icons import box, ellipse, ramp, taper
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save, shifted

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "story")
WOOD = ("wood_light", "wood", "wood_dark")
FELT = ("parchment", "felt", "felt_dark")


def r(names):
    return ramp(*names)


def shadow(canvas, cx, cy, rx, ry=2, on="grass_dark"):
    world_art.ground_shadow(canvas, ellipse(cx, cy, rx, ry), on)


# --- Аул ------------------------------------------------------------------------

def campfire(frame):
    """Костёр 24×22: кольцо камней, поленья и пламя в два кадра."""
    canvas = Canvas(24, 22)
    for x, y in ((5, 17), (9, 19), (14, 19), (18, 17), (4, 14), (19, 14)):
        paint(canvas, ellipse(x, y, 2.2, 1.6), r(("stone_light", "stone", "stone_dark")))
    paint(canvas, rows({y: (6, 17) for y in range(15, 17)}), r(WOOD))
    flame = taper(4 + frame, 14, 1, 5, cx=12) | taper(7 - frame, 14, 0, 3, cx=9 + frame)
    paint(canvas, flame, (c("sun"), c("ember"), c("rust")))
    fill(canvas, taper(9, 14, 0, 2, cx=12), c("sun"))
    outline(canvas)
    return canvas


def well():
    """Колодец 26×30: сруб, ворот и ведро."""
    canvas = Canvas(26, 30)
    paint(canvas, box(4, 16, 21, 27), r(("stone_light", "stone", "stone_dark")))
    fill(canvas, {(x, y) for x, y in box(4, 16, 21, 27) if y % 4 == 0 or (x + (y // 4) * 3) % 6 == 0}, c("stone_dark"))
    paint(canvas, ellipse(13, 16, 9, 3), r(("ink_soft", "ink", "outline")))
    for x in (5, 20):
        paint(canvas, box(x, 3, x + 1, 15), r(WOOD))
    paint(canvas, box(5, 3, 21, 4), r(WOOD))
    paint(canvas, box(11, 6, 14, 10), r(("steel_light", "steel", "steel_dark")))
    outline(canvas)
    shadow(canvas, 13, 28, 11)
    return canvas


def cart():
    """Арба 40×28 — двухколёсная телега, на ней переезжают."""
    canvas = Canvas(40, 28)
    paint(canvas, box(6, 9, 33, 15), r(WOOD))
    fill(canvas, {(x, y) for x, y in box(6, 9, 33, 15) if x % 5 == 0}, c("wood_dark"))
    paint(canvas, rows({y: (33, 39) for y in (13, 14)}), r(WOOD))
    for cx in (12, 27):
        wheel = ellipse(cx, 20, 6.5, 6.5) - ellipse(cx, 20, 4.5, 4.5)
        paint(canvas, wheel, r(("wood_light", "wood_dark", "outline")))
        fill(canvas, {(cx, y) for y in range(15, 26)} | {(x, 20) for x in range(cx - 5, cx + 6)}, c("wood_dark"))
    paint(canvas, box(9, 5, 30, 8), r(FELT))
    outline(canvas)
    shadow(canvas, 20, 26, 17)
    return canvas


def horse(coat, frame=0):
    """Конь 44×36 в профиль влево; два кадра шага."""
    canvas = Canvas(44, 36)
    body = ellipse(22, 16, 12, 6)
    neck = {(x, y) for y in range(5, 16) for x in range(8, 16) if x - 8 >= (y - 5) * 0.2 and x - 8 <= 4 + (y - 5) * 0.5}
    head = ellipse(8, 7, 5, 3.2) | box(3, 6, 8, 10)
    step = 2 if frame else 0
    legs = set()
    for x0, dx in ((13, -step), (17, step), (27, step), (31, -step)):
        legs |= box(x0 + dx, 20, x0 + dx + 1, 29)
    hooves = {(x, 30) for x, y in legs if y == 29} | {(x + 1, 30) for x, y in legs if y == 29}
    tail = {(x, y) for y in range(13, 26) for x in range(33, 37) if abs(x - (34 + (y - 13) * 0.15)) < 1.5}
    paint(canvas, legs | body | neck | head, ramp(*coat))
    fill(canvas, hooves, c("ink"))
    mane = {(x, y) for x, y in neck if (x - 1, y) not in neck or (x - 2, y) not in neck}
    fill(canvas, mane | tail, c("ink_soft"))
    canvas.put(6, 6, c("outline"))
    paint(canvas, box(19, 9, 26, 11), r(("burgundy_light", "burgundy", "burgundy_dark")))
    outline(canvas)
    shadow(canvas, 22, 33, 15)
    return canvas


def camel(frame=0):
    """Түйе 46×40 в профиль влево, два горба."""
    canvas = Canvas(46, 40)
    body = ellipse(25, 19, 13, 6) | ellipse(20, 12, 5, 5) | ellipse(30, 12, 5, 5)
    neck = {(x, y) for y in range(8, 20) for x in range(6, 14) if abs(x - (12 - (20 - y) * 0.35)) < 2}
    head = ellipse(6, 8, 4.5, 2.5)
    step = 2 if frame else 0
    legs = set()
    for x0, dx in ((15, -step), (19, step), (30, step), (34, -step)):
        legs |= box(x0 + dx, 23, x0 + dx + 1, 34)
    paint(canvas, legs | body | neck | head, r(("fur_light", "fur", "fur_dark")))
    paint(canvas, box(21, 13, 29, 15), r(("rust_light", "rust", "rust_dark")))
    outline(canvas)
    shadow(canvas, 25, 37, 16)
    return canvas


def hay():
    canvas = Canvas(26, 20)
    stack = ellipse(13, 12, 11, 7) | ellipse(13, 7, 7, 5)
    paint(canvas, stack, r(("sun", "gold", "gold_dark")))
    fill(canvas, {(x, y) for x, y in stack if (x * 3 + y) % 7 == 0}, c("gold_dark"))
    outline(canvas)
    shadow(canvas, 13, 19, 11)
    return canvas


def sandyq():
    """Сандық 22×18 — расписной сундук."""
    canvas = Canvas(22, 18)
    paint(canvas, box(2, 5, 19, 14), r(("burgundy_light", "burgundy", "burgundy_dark")))
    paint(canvas, box(2, 3, 19, 5), r(("rust_light", "rust", "rust_dark")))
    for x in (5, 16):
        fill(canvas, box(x, 3, x, 14), c("gold"))
    fill(canvas, {(10, 8), (11, 8), (9, 9), (12, 9), (10, 10), (11, 10)}, c("gold_light"))
    outline(canvas)
    shadow(canvas, 11, 16, 10)
    return canvas


def tandyr():
    """Тандыр 20×20 — глиняная печь."""
    canvas = Canvas(20, 20)
    paint(canvas, ellipse(10, 11, 8, 7), r(("path_light", "path", "path_dark")))
    paint(canvas, ellipse(10, 6, 4, 2), r(("ink_soft", "ink", "outline")))
    outline(canvas)
    shadow(canvas, 10, 18, 8)
    return canvas


def firewood():
    """Вязанка отына 20×14 — её собирают."""
    canvas = Canvas(20, 14)
    for y, dx in ((5, 0), (8, 2), (8, -2), (11, 0)):
        paint(canvas, box(3 + dx, y - 1, 16 + dx, y), r(WOOD))
    fill(canvas, box(9, 3, 10, 12), c("rust"))
    outline(canvas)
    return canvas


# --- Киіз үй: части и стадии --------------------------------------------------

def kerege():
    """Сложенная кереге — решётка стен."""
    canvas = Canvas(26, 16)
    lattice = {(x, y) for x in range(2, 24) for y in range(3, 14) if (x + y) % 4 == 0 or (x - y) % 4 == 0}
    paint(canvas, lattice, r(WOOD))
    outline(canvas)
    return canvas


def uyk():
    """Вязанка уық — изогнутые жерди купола."""
    canvas = Canvas(28, 12)
    for y in (4, 6, 8):
        fill(canvas, {(x, y + (1 if x > 20 else 0)) for x in range(2, 25)}, c("rust_light"))
    fill(canvas, box(12, 3, 13, 9), c("ink"))
    outline(canvas)
    return canvas


def shanyrak():
    """Шаңырақ — деревянный венец купола с перекрестьем."""
    canvas = Canvas(22, 16)
    ring = ellipse(11, 8, 9, 6) - ellipse(11, 8, 6.5, 4)
    paint(canvas, ring, r(WOOD))
    fill(canvas, {(x, 8) for x in range(5, 18)} | {(11, y) for y in range(4, 13)}, c("wood_dark"))
    outline(canvas)
    return canvas


def felt():
    """Скатанный киіз."""
    canvas = Canvas(24, 14)
    paint(canvas, box(3, 3, 20, 11), r(FELT))
    paint(canvas, ellipse(20, 7, 3, 4.5), r(("parchment", "parchment", "felt")))
    fill(canvas, {(x, 6) for x in range(4, 18, 4)}, c("felt_dark"))
    outline(canvas)
    return canvas


def yurt_stage(stage):
    """Стадии сборки 104×112, на сетке yurt() из world_art: 0 — площадка,
    1 — кереге, 2 — плюс уық, 3 — плюс шаңырақ. Стадия 4 — готовая юрта мира."""
    w, h = 104, 112
    canvas = Canvas(w, h)
    cx = w / 2
    fill(canvas, {(x, y) for x, y in ellipse(cx, 100, 51, 6)}, c("path"))
    if stage >= 1:
        walls = {(x, y) for y in range(64, 104) for x in range(2, w - 2)
                 if y < 100 or (abs(x + 0.5 - cx) / 50) ** 2 + ((y - 100) / 4) ** 2 <= 1}
        lattice = {(x, y) for x, y in walls if (x + y) % 10 == 0 or (x - y) % 10 == 0 or y in (64, 65)}
        fill(canvas, lattice, c("wood"))
        fill(canvas, {(x, y) for x, y in lattice if (x + y) % 10 == 0 and (x - y) % 10 == 0}, c("wood_light"))
    if stage >= 2:
        for k in range(-8, 9, 2):
            for y in range(12, 65):
                x = int(cx + k * (y - 8) * 0.105)
                if 0 <= x < w:
                    canvas.put(x, y, c("rust_light"))
    if stage >= 3:
        crown = ellipse(cx, 10, 8, 3.5)
        paint(canvas, crown, r(WOOD))
        fill(canvas, ellipse(cx, 10, 4, 1.5), c("ink"))
    outline(canvas)
    return canvas


# --- Түркістан ----------------------------------------------------------------
# Город из atilla: глиняные стены с зубцами, башни, дома с плоской крышей,
# мавзолей с бирюзовым куполом, торговые ряды. Масштаб мира: метр — 20 px арта;
# вид 3/4 — глубина сжата вдвое, высота стен — около 0,7.

CLAY = ("path_light", "path", "path_dark")
TILE = ("blue_light", "teal", "teal_dark")


def _bricks(canvas, mask, course=4, brick=8):
    """Кладка: тёмные швы через ряд со сдвигом — глина читается кирпичом."""
    for x, y in mask:
        if y % course == 0 or (x + (y // course) % 2 * (brick // 2)) % brick == 0:
            canvas.put(x, y, c("path_dark"))


def city_ground():
    """Утоптанная глина города, плитка 64×64 (стыкуется по краям)."""
    canvas = Canvas(64, 64, c("path"))
    for y in range(64):
        for x in range(64):
            if (x * 7 + y * 13) % 29 == 0:
                canvas.put(x, y, c("path_dark"))
            elif (x * 11 + y * 5) % 37 == 0:
                canvas.put(x, y, c("path_light"))
    for x, y in ((9, 12), (40, 22), (24, 47), (54, 54)):
        paint(canvas, ellipse(x, y, 2, 1.5), r(("stone_light", "stone", "stone_dark")))
    return canvas


def paving():
    """Мостовая улицы — каменные плиты со сдвигом рядов, плитка 32×32."""
    canvas = Canvas(32, 32, c("stone"))
    for y in range(32):
        for x in range(32):
            shift = 8 if (y // 8) % 2 else 0
            if y % 8 == 7 or (x + shift) % 16 == 15:
                canvas.put(x, y, c("stone_dark"))
            elif y % 8 == 0 or (x + shift) % 16 == 0:
                canvas.put(x, y, c("stone_light"))
    return canvas


def wall_h():
    """Звено стены вдоль верхнего/нижнего края 40×64 (2 м): зубцы, дорожка
    поверху, кирпичная стена. Плитка повторяется по горизонтали."""
    canvas = Canvas(40, 64)
    fill(canvas, box(0, 10, 39, 17), c("path_dark"))
    for x in range(0, 40, 10):
        paint(canvas, box(x + 1, 2, x + 6, 10), r(CLAY))
    face = box(0, 18, 39, 61)
    fill(canvas, face, c("path"))
    fill(canvas, box(0, 18, 39, 19), c("path_light"))
    _bricks(canvas, box(0, 22, 39, 59))
    fill(canvas, box(0, 60, 39, 61), c("path_dark"))
    fill(canvas, box(0, 62, 39, 63), c("cloth_shadow"))
    fill(canvas, {(x, y) for x, y in box(0, 2, 39, 10) if canvas.image.getpixel((x, y))[3] and y == 2}, c("outline"))
    return canvas


def wall_v():
    """Звено стены вдоль боковых краёв 28×40, вид сверху: дорожка между
    зубцами. Плитка повторяется по вертикали."""
    canvas = Canvas(28, 40)
    fill(canvas, box(3, 0, 24, 39), c("path_dark"))
    fill(canvas, {(x, y) for x, y in box(3, 0, 24, 39) if (x * 3 + y * 5) % 17 == 0}, c("leather_dark"))
    for y in range(0, 40, 10):
        paint(canvas, box(0, y + 1, 3, y + 7), r(CLAY))
        paint(canvas, box(24, y + 1, 27, y + 7), r(CLAY))
    fill(canvas, box(0, 0, 0, 39), c("outline"))
    fill(canvas, box(27, 0, 27, 39), c("outline"))
    return canvas


def tower():
    """Круглая башня 60×104: зубчатый верх, кладка, тень справа."""
    canvas = Canvas(60, 104)
    body = {(x, y) for x, y in box(5, 22, 54, 96)} | ellipse(30, 96, 25, 5)
    for x, y in body:
        t = (x - 5) / 50
        canvas.put(x, y, c("path_light") if t < 0.25 else c("path") if t < 0.7 else c("path_dark"))
    _bricks(canvas, {(x, y) for x, y in body if 26 <= y <= 94 and 7 < x < 52}, course=5, brick=10)
    top = ellipse(30, 20, 28, 8)
    fill(canvas, top, c("path_dark"))
    fill(canvas, ellipse(30, 20, 22, 5), c("leather_dark"))
    for k in range(7):
        x = 4 + k * 8
        paint(canvas, box(x, 8 + abs(3 - k), x + 4, 16 + abs(3 - k)), r(CLAY))
    fill(canvas, box(27, 50, 32, 62), c("ink"))
    outline(canvas)
    shadow(canvas, 32, 101, 26, on="path_dark")
    return canvas


def house(width_m, depth_m, door_x=0.5):
    """Глиняный дом с плоской крышей. Ширина width_m, крыша в 3/4 —
    depth_m/2 м, стена — 2,5 м. Низ картинки — передняя стена."""
    w = int(width_m * 20) + 4
    roof_h = int(depth_m * 10)
    face_h = 50
    h = roof_h + face_h + 10
    canvas = Canvas(w, h)
    roof = box(2, 4, w - 3, 4 + roof_h)
    fill(canvas, roof, c("path_light"))
    fill(canvas, {(x, y) for x, y in roof if (x * 5 + y * 3) % 23 == 0}, c("path"))
    paint(canvas, box(0, 2, w - 1, 5), r(CLAY))
    face = box(2, 5 + roof_h, w - 3, 4 + roof_h + face_h)
    fill(canvas, face, c("path"))
    fill(canvas, box(2, 5 + roof_h, w - 3, 7 + roof_h), c("path_dark"))
    for x0 in range(2, w - 3, 28):
        fill(canvas, box(x0, 8 + roof_h, x0 + 1, 4 + roof_h + face_h), c("path_light"))
    base = 4 + roof_h + face_h
    dx = int(w * door_x)
    paint(canvas, box(dx - 7, base - 30, dx + 6, base), r(WOOD))
    fill(canvas, box(dx - 7, base - 32, dx + 6, base - 31), c("wood_dark"))
    fill(canvas, {(dx - 1, y) for y in range(base - 29, base)}, c("wood_dark"))
    for wx in (dx - 30, dx + 22):
        if 6 < wx < w - 14:
            fill(canvas, box(wx, base - 34, wx + 8, base - 24), c("ink"))
            fill(canvas, {(wx + 4, y) for y in range(base - 34, base - 23)}
                 | {(x, base - 29) for x in range(wx, wx + 9)}, c("wood"))
    outline(canvas)
    shadow(canvas, w // 2 + 2, h - 3, w // 2, on="path_dark")
    return canvas


def mausoleum():
    """Мавзолей 232×200: портал-пештак с аркой и изразцовой лентой, большой
    бирюзовый купол на барабане и малый слева. Низ — передняя кромка портала."""
    w, h = 232, 200
    canvas = Canvas(w, h)
    cx = w // 2
    # Корпус: плоская крыша и стена.
    fill(canvas, box(6, 92, w - 7, 108), c("path_light"))
    face = box(6, 108, w - 7, 186)
    fill(canvas, face, c("path"))
    _bricks(canvas, face, course=5, brick=10)
    fill(canvas, box(6, 108, w - 7, 110), c("path_dark"))
    # Малый купол слева и большой на барабане.
    paint(canvas, box(30, 78, 78, 94), r(TILE))
    paint(canvas, {(x, y) for x, y in ellipse(54, 78, 24, 22) if y <= 80}, r(TILE))
    drum = box(cx - 50 + 20, 60, cx + 50 + 20, 92)
    paint(canvas, drum, r(TILE))
    fill(canvas, {(x, y) for x, y in drum if y in (66, 86)}, c("gold"))
    fill(canvas, {(x, 76) for x in range(cx - 28, cx + 70) if x % 6 < 3}, c("parchment"))
    dome = {(x, y) for x, y in ellipse(cx + 22, 64, 56, 54) if y <= 66}
    for x, y in dome:
        t = (x - (cx - 34)) / 112
        canvas.put(x, y, c("blue_light") if t < 0.3 else c("teal") if t < 0.75 else c("teal_dark"))
    for k in range(-3, 4):
        for y in range(14, 66, 2):
            x = int(cx + 22 + k * (66 - y) * 0.12 + k * 10 * (y / 66))
            if (x, y) in dome:
                canvas.put(x, y, c("teal_dark"))
    paint(canvas, box(cx + 20, 1, cx + 23, 11), r(("sun", "gold", "gold_dark")))
    # Портал перед куполом: высокая стена, лента изразца, стрельчатая арка.
    portal = box(cx - 66, 30, cx + 65, 186)
    fill(canvas, portal, c("parchment"))
    fill(canvas, {(x, y) for x, y in portal if x > cx + 50}, c("parchment_dark"))
    _bricks(canvas, {(x, y) for x, y in portal if y > 64}, course=5, brick=10)
    band = box(cx - 66, 36, cx + 65, 56)
    paint(canvas, band, r(TILE))
    for x in range(cx - 60, cx + 60, 12):
        fill(canvas, {(x + 6 - abs(dy), 46 + dy) for dy in range(-5, 6)}
             | {(x + 6 + abs(dy), 46 + dy) for dy in range(-5, 6)}, c("gold"))
    for side in (cx - 66, cx + 56):
        paint(canvas, box(side, 22, side + 9, 186), r(("cream", "parchment", "parchment_dark")))
        paint(canvas, box(side - 1, 16, side + 10, 22), r(TILE))
    arch = {(x, y) for y in range(88, 187) for x in range(cx - 26, cx + 26)
            if y >= 122 or abs(x + 0.5 - cx) <= (y - 88) * 26 / 34}
    fill(canvas, arch, c("ink"))
    frame = {(x, y) for y in range(84, 187) for x in range(cx - 31, cx + 31)
             if (x, y) not in arch and (y >= 120 or abs(x + 0.5 - cx) <= (y - 84) * 31 / 36)}
    paint(canvas, frame, r(TILE))
    door = box(cx - 12, 150, cx + 11, 186)
    paint(canvas, door, r(WOOD))
    fill(canvas, {(cx, y) for y in range(150, 187)}, c("wood_dark"))
    fill(canvas, {(x, y) for x, y in door if (x + y) % 6 == 0}, c("wood_light"))
    outline(canvas)
    shadow(canvas, cx + 4, 194, 112, 3, on="path_dark")
    return canvas


def stall():
    """Базарный ряд 64×60: полосатый навес на столбах, прилавок с товаром."""
    canvas = Canvas(64, 60)
    for x in (6, 55):
        paint(canvas, box(x, 14, x + 2, 54), r(WOOD))
    awning = taper(6, 20, 26, 31, cx=32)
    for x, y in awning:
        canvas.put(x, y, c("burgundy") if (x // 6) % 2 else c("parchment"))
    fill(canvas, {(x, y) for x, y in awning if y == 20 and x % 6 < 3}, c("burgundy_dark"))
    paint(canvas, box(4, 38, 59, 54), r(WOOD))
    fill(canvas, box(4, 38, 59, 39), c("wood_light"))
    goods = [("rust", 12), ("sun", 20), ("green", 28), ("burgundy_light", 36), ("sun", 44), ("rust_light", 52)]
    for name, x in goods:
        paint(canvas, ellipse(x, 35, 3.5, 3), r((name, name, "outline")))
    paint(canvas, box(14, 26, 22, 34), r(("cream", "parchment", "parchment_dark")))
    outline(canvas)
    shadow(canvas, 32, 57, 30, on="path_dark")
    return canvas


def city_tree():
    """Карагач 48×72 — круглая крона на стволе."""
    canvas = Canvas(48, 72)
    paint(canvas, box(21, 40, 26, 66), r(WOOD))
    crown = ellipse(24, 26, 21, 20) | ellipse(13, 36, 10, 8) | ellipse(35, 36, 10, 8)
    paint(canvas, crown, r(("grass_light", "grass_mid", "grass_deep")))
    fill(canvas, {(x, y) for x, y in crown if (x * 3 + y * 7) % 11 == 0 and x < 30}, c("grass_light"))
    fill(canvas, {(x, y) for x, y in crown if (x * 5 + y * 3) % 13 == 0 and x > 24}, c("grass_dark"))
    outline(canvas)
    shadow(canvas, 25, 68, 14, on="path_dark")
    return canvas


# --- Маркеры и задания ----------------------------------------------------------

def marker():
    """Золотая стрелка над тем, к кому идти."""
    canvas = Canvas(14, 14)
    arrow = box(5, 1, 8, 6) | taper(6, 12, 6, 0, cx=7)
    paint(canvas, arrow, r(("sun", "gold_light", "gold")))
    outline(canvas)
    return canvas


def chevron():
    """Шеврон на земле — дорожка к цели."""
    canvas = Canvas(10, 8)
    shape = {(x, y) for x in range(10) for y in range(8) if 0 <= y - abs(x - 4.5) + 1 < 3}
    fill(canvas, shape, c("gold_light"))
    fill(canvas, {(x, y + 1) for x, y in shape if (x, y + 1) not in shape and y + 1 < 8}, c("gold_dark"))
    return canvas


def glow():
    """Пятно света на земле под тем, что нужно поднять."""
    canvas = Canvas(30, 12)
    for x, y in ellipse(15, 6, 15, 6):
        inner = ((x + 0.5 - 15) / 10) ** 2 + ((y + 0.5 - 6) / 4) ** 2 <= 1
        if inner or (x + y) % 2 == 0:
            canvas.put(x, y, c("sun") if inner and (x + y) % 2 == 0 else c("gold_light"))
    return canvas


def post():
    """Ат байлайтын баған — коновязь."""
    canvas = Canvas(14, 30)
    paint(canvas, box(5, 3, 8, 27), r(WOOD))
    paint(canvas, box(2, 7, 11, 8), r(WOOD))
    fill(canvas, {(5, 12), (8, 12), (6, 13), (7, 13)}, c("rust_light"))
    outline(canvas)
    shadow(canvas, 7, 28, 5)
    return canvas


def flag(color_names):
    """Белгі бәйге: шест с флажком."""
    canvas = Canvas(16, 30)
    paint(canvas, box(3, 2, 4, 27), r(WOOD))
    paint(canvas, rows({y: (5, 13 - abs(y - 7)) for y in range(2, 13)}), r(color_names))
    outline(canvas)
    shadow(canvas, 4, 28, 4)
    return canvas


def tracks():
    """Жау ізі — цепочка следов копыт."""
    canvas = Canvas(30, 16)
    for i, (x, y) in enumerate(((3, 11), (9, 7), (15, 10), (21, 6), (26, 9))):
        hoof = ellipse(x, y, 2.4, 2) - ellipse(x, y + 0.8, 1, 1)
        fill(canvas, hoof, c("path_dark") if i % 2 else c("ink_soft"))
    return canvas


# --- Мини-игры ----------------------------------------------------------------

def asyk(red=False):
    """Асық 18×14 — бараний альчик; сақа (red) крашена в красный и чуть крупнее."""
    canvas = Canvas(20, 16) if red else Canvas(18, 14)
    cx, cy = (10, 8) if red else (9, 7)
    body = ellipse(cx, cy, 7.5 if red else 6.5, 5 if red else 4.5) | ellipse(cx - 5, cy - 2, 2.6, 2.6) \
        | ellipse(cx + 5, cy + 2, 2.6, 2.6)
    colors = ("red_light", "burgundy_light", "burgundy") if red else ("parchment", "cream", "cloth_shadow")
    paint(canvas, body, r(colors))
    fill(canvas, box(cx - 3, cy, cx + 3, cy), c("burgundy" if red else "cloth_shadow"))
    outline(canvas)
    return canvas


def asyk_field():
    """Площадка 200×100: утоптанная земля, мелом очерченный круг и линия асыков."""
    w, h = 200, 100
    canvas = Canvas(w, h, c("path"))
    for y in range(h):
        for x in range(w):
            if (x * 11 + y * 7) % 23 == 0:
                canvas.put(x, y, c("path_dark"))
            elif (x * 5 + y * 13) % 31 == 0:
                canvas.put(x, y, c("path_light"))
    ring = ellipse(100, 44, 74, 28) - ellipse(100, 44, 72, 26.5)
    fill(canvas, ring, c("parchment"))
    fill(canvas, rows({44: (40, 160)}), c("parchment"))
    fill(canvas, rows({y: (0, w - 1) for y in range(h - 6, h)}), c("grass_dark"))
    canvas.ring(0, c("gold_dark"), c("gold_dark"), c("outline"), c("outline"))
    return canvas


def duel_arena():
    """Арена поединка 320×110: вечерняя степь, два войска вдали, вытоптанный круг."""
    w, h = 320, 110
    canvas = Canvas(w, h, c("dusk"))
    bands = [("night_violet", 0, 14), ("plum", 14, 28), ("mauve", 28, 40), ("rose_dark", 40, 48)]
    for name, y0, y1 in bands:
        fill(canvas, rows({y: (0, w - 1) for y in range(y0, y1)}), c(name))
    for x in range(0, w, 4):
        top = 44 + (x * 7) % 5
        fill(canvas, {(x, y) for y in range(top, 50)} | {(x + 1, y) for y in range(top + 1, 50)}, c("ink_soft"))
        if x % 12 == 0:
            fill(canvas, {(x + 1, y) for y in range(top - 6, top)}, c("steel"))
    fill(canvas, rows({y: (0, w - 1) for y in range(50, h)}), c("grass_dark"))
    for y in range(50, h):
        for x in range(w):
            if (x * 3 + y * 7) % 13 == 0:
                canvas.put(x, y, c("grass_deep"))
    trampled = ellipse(160, 84, 140, 20)
    fill(canvas, trampled, c("path_dark"))
    fill(canvas, {(x, y) for x, y in trampled if (x + y) % 5 == 0}, c("path"))
    canvas.ring(0, c("gold_dark"), c("gold_dark"), c("outline"), c("outline"))
    return canvas


# --- Карта маршрутов ------------------------------------------------------------

MAP_W, MAP_H = 320, 180


def _blob(cx, cy, rx, ry, wobble, seed):
    """Неровное пятно: эллипс, край которого гуляет — так выглядят моря и озёра."""
    import math
    out = set()
    for y in range(int(cy - ry - wobble - 1), int(cy + ry + wobble + 2)):
        for x in range(int(cx - rx - wobble - 1), int(cx + rx + wobble + 2)):
            angle = math.atan2((y - cy) / ry, (x - cx) / rx)
            edge = 1 + wobble / max(rx, ry) * math.sin(angle * 3 + seed) * math.cos(angle * 5 - seed)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= edge * edge:
                out.add((x, y))
    return out


def _river(canvas, points, color_name):
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            fill(canvas, {(x, y), (x + 1, y)}, c(color_name))


def route_map():
    """Карта 320×180: степь с Каспием, Аралом, Балқашем, Сырдарией, Шу и горами юга.
    Точки маршрутов глав (доли 0..1) ложатся на неё: Сарыарқа — центр-север,
    Сырдария и Түркістан — юг, Жетісу и Аңырақай — юго-восток."""
    canvas = Canvas(MAP_W, MAP_H, c("parchment_dark"))
    for y in range(MAP_H):
        for x in range(MAP_W):
            if (x * 7 + y * 13) % 29 == 0:
                canvas.put(x, y, c("path_light"))
    # Сарыарқа — холмистый центр.
    for cx, cy in ((160, 40), (178, 52), (146, 58), (196, 34), (130, 44)):
        fill(canvas, _blob(cx, cy, 9, 4, 2, cx), c("grass_light"))
        fill(canvas, {(x, y) for x, y in _blob(cx, cy, 9, 4, 2, cx) if y >= cy + 2}, c("grass"))
    seas = [(_blob(14, 96, 18, 58, 6, 1), "caspian"), (_blob(80, 100, 14, 12, 1.5, 2), "aral"),
            (_blob(214, 90, 32, 6, 3, 3), "balkash")]
    for mask, _name in seas:
        fill(canvas, mask, c("water"))
        fill(canvas, {(x, y) for x, y in mask if (x, y - 1) not in mask}, c("water_light"))
    # Горы юга и юго-востока: Тянь-Шань и Жетісу Алатауы, Қаратау.
    for x in range(176, 320, 7):
        peak = 150 + (x * 13) % 14
        paint(canvas, taper(peak - 10, peak + 6, 0, 6, cx=x), r(("stone_light", "stone", "stone_dark")))
        fill(canvas, taper(peak - 10, peak - 7, 0, 1, cx=x), c("parchment"))
    for x, y in ((128, 128), (134, 124), (140, 120)):
        paint(canvas, taper(y - 6, y + 4, 0, 4, cx=x), r(("rust_light", "rust", "rust_dark")))
    # Сырдария: с гор востока через Түркістан в Арал; Шу и Іле.
    _river(canvas, [(176, 156), (160, 146), (144, 138), (124, 130), (104, 118), (92, 108)], "water_dark")
    _river(canvas, [(220, 150), (214, 136), (200, 126), (186, 120)], "water_dark")
    _river(canvas, [(268, 140), (252, 120), (238, 100), (232, 94)], "water_dark")
    canvas.ring(0, c("gold_dark"), c("gold_dark"), c("outline"), c("outline"))
    canvas.ring(1, c("gold"), c("gold"), c("gold_dark"), c("gold_dark"))
    return canvas


def route_dot(colors):
    canvas = Canvas(8, 8)
    paint(canvas, ellipse(4, 4, 3.5, 3.5), r(colors))
    outline(canvas)
    return canvas


# --- Иконки статей энциклопедии ---------------------------------------------

def icon(draw):
    canvas = Canvas(32, 32)
    draw(canvas)
    outline(canvas)
    return canvas


def i_banner(cv):
    paint(cv, box(8, 3, 9, 29), r(WOOD))
    paint(cv, rows({y: (10, 26 - abs(y - 11) // 2) for y in range(4, 19)}), r(("red_light", "burgundy_light", "burgundy")))
    fill(cv, {(16, 9), (17, 10), (16, 11), (15, 10), (16, 10)}, c("gold_light"))


def i_horse(cv):
    paint(cv, ellipse(18, 18, 9, 5) | box(7, 7, 11, 16) | ellipse(7, 8, 4, 3), r(("rust_light", "rust", "rust_dark")))
    for x in (11, 14, 21, 24):
        fill(cv, box(x, 22, x + 1, 29), c("rust_dark"))
    fill(cv, box(6, 5, 7, 14), c("ink_soft"))


def i_swords(cv):
    for flip in (False, True):
        blade = {(x, y) for x in range(32) for y in range(32) if abs((31 - x if flip else x) - y) <= 1 and 4 <= y <= 22}
        paint(cv, blade, r(("steel_light", "steel", "steel_dark")))
        hilt = {(31 - x if flip else x, y) for x, y in box(22, 21, 26, 23)}
        fill(cv, hilt, c("gold"))


def i_yurt(cv):
    paint(cv, box(5, 16, 26, 27), r(FELT))
    paint(cv, taper(6, 16, 3, 11), r(FELT))
    fill(cv, box(5, 18, 26, 19), c("burgundy"))
    paint(cv, box(13, 21, 18, 27), r(("rust_light", "rust", "rust_dark")))


def i_naiza(cv):
    paint(cv, {(x, 31 - x) for x in range(4, 26)} | {(x + 1, 31 - x) for x in range(4, 26)}, r(WOOD))
    paint(cv, taper(2, 9, 0, 3, cx=26), r(("steel_light", "steel", "steel_dark")))
    fill(cv, box(19, 10, 22, 12), c("red_light"))


def i_zhuz(cv):
    for cx, cy, col in ((10, 11, ("sun", "gold", "gold_dark")), (22, 11, ("blue_light", "blue", "blue_dark")),
                        (16, 21, ("red_light", "burgundy_light", "burgundy"))):
        paint(cv, ellipse(cx, cy, 6, 6), r(col))


def i_dombra(cv):
    paint(cv, ellipse(11, 22, 7, 6), r(WOOD))
    paint(cv, {(x, 21 - (x - 11)) for x in range(11, 28)} | {(x, 22 - (x - 11)) for x in range(11, 28)}, r(WOOD))
    fill(cv, ellipse(11, 22, 2, 2), c("ink"))


def i_shapan(cv):
    paint(cv, taper(5, 28, 6, 11), r(("blue_light", "blue", "blue_dark")))
    paint(cv, box(3, 6, 8, 18) | box(23, 6, 28, 18), r(("blue_light", "blue", "blue_dark")))
    fill(cv, box(15, 5, 16, 28), c("gold"))


def i_sauyt(cv):
    paint(cv, taper(5, 26, 7, 9), r(("steel_light", "steel", "steel_dark")))
    fill(cv, {(x, y) for x, y in taper(7, 25, 6, 8) if (x + y) % 2 == 0}, c("steel_dark"))
    fill(cv, box(7, 17, 24, 18), c("leather_dark"))


def i_dastarkhan(cv):
    paint(cv, ellipse(16, 18, 14, 9), r(("parchment", "cream", "cloth_shadow")))
    for x, y in ((10, 16), (16, 20), (22, 16)):
        paint(cv, ellipse(x, y, 3.5, 2.5), r(("sun", "gold", "gold_dark")))
    paint(cv, ellipse(16, 13, 4, 2.5), r(("blue_light", "blue", "blue_dark")))


def i_asyk(cv):
    paint(cv, ellipse(16, 16, 10, 7) | ellipse(9, 13, 4, 4) | ellipse(23, 19, 4, 4), r(("parchment", "cream", "cloth_shadow")))
    fill(cv, box(13, 15, 19, 16), c("cloth_shadow"))


def i_blindfold(cv):
    paint(cv, ellipse(16, 16, 10, 11), r(("skin_light", "skin", "skin_dark")))
    paint(cv, box(5, 12, 27, 16), r(("red_light", "burgundy_light", "burgundy")))
    fill(cv, box(26, 16, 28, 22), c("burgundy_light"))


def i_talk(cv):
    """Сөйлесу — облачко реплики для кнопки действия."""
    paint(cv, box(4, 6, 27, 20) | ellipse(4.5, 13, 3, 7) | ellipse(27, 13, 3, 7), r(("parchment", "cream", "cloth_shadow")))
    paint(cv, {(x, y) for x in range(8, 15) for y in range(20, 27) if x - 8 <= 26 - y}, r(("parchment", "cream", "cloth_shadow")))
    for x in (10, 16, 22):
        fill(cv, box(x, 12, x + 1, 13), c("ink"))


ICONS = {"banner": i_banner, "horse": i_horse, "swords": i_swords, "yurt": i_yurt, "naiza": i_naiza,
         "zhuz": i_zhuz, "dombra": i_dombra, "shapan": i_shapan, "sauyt": i_sauyt,
         "dastarkhan": i_dastarkhan, "asyk": i_asyk, "blindfold": i_blindfold, "talk": i_talk}


def drawings():
    bay = ("rust_light", "rust", "rust_dark")
    grey = ("parchment", "cloth_shadow", "stone")
    art = {
        "campfire_0": campfire(0), "campfire_1": campfire(1), "well": well(), "cart": cart(),
        "horse_bay_0": horse(bay, 0), "horse_bay_1": horse(bay, 1),
        "horse_grey_0": horse(grey, 0), "horse_grey_1": horse(grey, 1),
        "camel": camel(), "hay": hay(), "sandyq": sandyq(), "tandyr": tandyr(), "firewood": firewood(),
        "kerege": kerege(), "uyk": uyk(), "shanyrak": shanyrak(), "felt": felt(),
        "marker": marker(), "chevron": chevron(), "glow": glow(), "post": post(), "tracks": tracks(),
        "flag_red": flag(("red_light", "burgundy_light", "burgundy")), "flag_gold": flag(("sun", "gold", "gold_dark")),
        "route_map": route_map(), "route_dot": route_dot(("sun", "gold_light", "gold")),
        "route_end": route_dot(("red_light", "burgundy_light", "burgundy")),
        "asyk": asyk(), "saka": asyk(red=True), "asyk_field": asyk_field(), "duel_arena": duel_arena(),
        "city_ground": city_ground(), "paving": paving(), "wall_h": wall_h(), "wall_v": wall_v(),
        "tower": tower(), "house_wide": house(8, 5.5, 0.4), "house_deep": house(6.5, 7, 0.6),
        "mausoleum": mausoleum(), "stall": stall(), "city_tree": city_tree(),
    }
    for stage in range(4):
        art[f"yurt_stage_{stage}"] = yurt_stage(stage)
    for name, draw in ICONS.items():
        art["icon_" + name] = icon(draw)
    return art


def build():
    return [save(canvas, os.path.join(OUT_DIR, name + ".png")) for name, canvas in drawings().items()]
