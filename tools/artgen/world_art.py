"""Мир Соқыртеке в виде 3/4: трава, пруды, камни, брёвна, кусты, цветы, ковры,
юрта и орнаментальная арена.

Размеры подогнаны под механику (scripts/systems/map_manager.gd): камни и
брёвна — по своим коллизиям, юрта — по кольцу стен из scenes/world/yurt.tscn.
Воду рисует шейдер resources/shaders/pond.gdshader прямо по зонам. Всё
сохраняется ×2 в assets/sprites/world/.
"""
import math
import os

import numpy as np
from PIL import Image

from characters import ramp
from item_icons import ellipse
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "world")
ARENA_RADIUS = 180  # 360 px мира


def ground_shadow(canvas, mask, color_name="grass_dark"):
    """Тень на земле (по умолчанию — на траве): только там, где ещё пусто, и без
    контура — рисуется после outline()."""
    for x, y in mask:
        if 0 <= x < canvas.width and 0 <= y < canvas.height and not canvas.image.getpixel((x, y))[3]:
            canvas.put(x, y, c(color_name))


# --- Трава -------------------------------------------------------------------

def _tiled_noise(size, cells, seed):
    """Периодический value noise: края совпадают, плитка бесшовная."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells))
    ys, xs = np.mgrid[0:size, 0:size] / size * cells
    x0, y0 = np.floor(xs).astype(int), np.floor(ys).astype(int)
    fx, fy = xs - x0, ys - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
    top = grid[y0 % cells, x0 % cells] * (1 - fx) + grid[y0 % cells, x1] * fx
    bottom = grid[y1, x0 % cells] * (1 - fx) + grid[y1, x1] * fx
    return top * (1 - fy) + bottom * fy


def grass_tile(size=128):
    """Спокойная бесшовная трава: фон grass_mid, мягкие светлые пятна с
    шахматным переходом и редкие травинки. Контраст низкий — трава не должна
    спорить с персонажами."""
    canvas = Canvas(size, size)
    noise = _tiled_noise(size, 4, 11) * 0.65 + _tiled_noise(size, 16, 12) * 0.35
    for y in range(size):
        for x in range(size):
            v = noise[y, x]
            light = v > 0.6 or (v > 0.55 and (x + y) % 2 == 0)
            canvas.put(x, y, c("grass") if light else c("grass_mid"))
    _blades(canvas, noise, 0.58, ("grass_light", "grass"), ("grass", "grass_dark"))
    return canvas


def wild_grass_tile(size=128):
    """Некошеная степь за забором: темнее игрового поля, чтобы край читался."""
    canvas = Canvas(size, size)
    noise = _tiled_noise(size, 4, 21) * 0.65 + _tiled_noise(size, 16, 22) * 0.35
    for y in range(size):
        for x in range(size):
            v = noise[y, x]
            light = v > 0.6 or (v > 0.55 and (x + y) % 2 == 0)
            canvas.put(x, y, c("grass_mid") if light else c("grass_dark"))
    _blades(canvas, noise, 0.58, ("grass", "grass_mid"), ("grass_mid", "grass_deep"))
    return canvas


def _blades(canvas, noise, threshold, on_light, on_dark):
    """Редкие травинки «V» на плитке; цвет зависит от пятна под ними."""
    size = canvas.width
    rng = np.random.default_rng(5)
    for _ in range(size // 2):
        x, y = int(rng.integers(0, size)), int(rng.integers(0, size))
        tip, base = on_light if noise[y, x] > threshold else on_dark
        canvas.put(x, y, c(tip))
        canvas.put(x, (y + 1) % size, c(base))
        canvas.put((x + 2) % size, (y + 1) % size, c(tip))


# --- Забор по краю поля -----------------------------------------------------

def fence_horizontal():
    """Звено забора вдоль верхнего/нижнего края: столбик и две жерди, 16×14.
    Плитка повторяется по горизонтали."""
    canvas = Canvas(16, 14)
    post = rows({y: (1, 4) for y in range(0, 13)})
    rails = rows({y: (0, 15) for y in (4, 5, 9, 10)})
    paint(canvas, rails - post, ramp("wood_light", "wood", "wood_dark"))
    paint(canvas, post, ramp("wood_light", "wood", "wood_dark"))
    fill(canvas, {(x, 13) for x in range(0, 16)}, c("grass_dark"))
    fill(canvas, {(x, y) for x, y in rails if y in (5, 10) and x > 4}, c("wood_dark"))
    return canvas


def fence_vertical():
    """Звено забора вдоль боковых краёв, вид с торца: столбик и жердь, 8×16.
    Плитка повторяется по вертикали."""
    canvas = Canvas(8, 16)
    rail = rows({y: (3, 4) for y in range(0, 16)})
    post = rows({y: (2, 5) for y in range(2, 14)})
    paint(canvas, rail, ramp("wood", "wood", "wood_dark"))
    paint(canvas, post, ramp("wood_light", "wood", "wood_dark"))
    fill(canvas, {(x, 14) for x in range(1, 7)}, c("grass_dark"))
    return canvas


# --- Камни, брёвна, кусты, мелочь -------------------------------------------

def rock(variant):
    """Валун 20×15 (40×30 мира) — по кругу коллизии радиуса 18 мира. Центр
    коллизии — центр картинки по x и строка 9 по y."""
    canvas = Canvas(22, 20)
    body = ellipse(11, 10, 9, 7) if variant == 0 else ellipse(12, 11, 8, 6) | ellipse(8, 8.5, 5, 4.5)
    paint(canvas, body, ramp("stone_light", "stone", "stone_dark"))
    fill(canvas, {(7, 6), (8, 6), (7, 7)} if variant == 0 else {(6, 6), (7, 5)}, c("stone_light"))
    fill(canvas, {(13, 12), (14, 11)} if variant == 0 else {(14, 13), (15, 12)}, c("stone_dark"))
    outline(canvas)
    ground_shadow(canvas, ellipse(12, 17.5, 10, 2))
    return canvas


def log(vertical):
    """Бревно 28×14 (56×28 мира) — ровно по прямоугольнику коллизии; лежит
    вдоль x или (vertical) вдоль y."""
    canvas = Canvas(30, 18)
    body = rows({y: (4, 27) for y in range(2, 14)})
    paint(canvas, body, ramp("wood_light", "wood", "wood_dark"))
    fill(canvas, {(x, 6) for x in range(8, 24, 5)} | {(x, 10) for x in range(10, 26, 6)}, c("wood_dark"))
    end = ellipse(4.5, 8, 3, 6)
    paint(canvas, end, ramp("path_light", "wood_light", "wood"))
    fill(canvas, {(4, 7), (4, 8)}, c("wood_dark"))
    if vertical:
        canvas.image = canvas.image.transpose(Image.Transpose.ROTATE_270)
        canvas.width, canvas.height = canvas.height, canvas.width
    outline(canvas)
    w, h = canvas.width, canvas.height
    ground_shadow(canvas, rows({h - 1: (2, w - 2)}))
    return canvas


def bush():
    """Куст с ягодами, ~22×18; декор, коллизии нет."""
    canvas = Canvas(24, 20)
    leaves = ellipse(12, 10, 10, 8) | ellipse(7, 8, 5, 5) | ellipse(17, 8, 5, 5)
    paint(canvas, leaves, ramp("green_light", "green", "green_dark"))
    fill(canvas, {(9, 7), (14, 5), (17, 10), (7, 11), (12, 12)}, c("red_light"))
    outline(canvas)
    ground_shadow(canvas, ellipse(12, 18, 10, 2))
    return canvas


def flowers(kind):
    """Пучок из трёх цветков 11×9 — мелкий декор травы."""
    canvas = Canvas(11, 9)
    petal = [c("red_light"), c("sun"), c("parchment")][kind]
    stems = {(2, 5), (2, 6), (2, 7), (5, 3), (5, 4), (5, 5), (5, 6), (5, 7), (8, 6), (8, 7)}
    fill(canvas, stems, c("green"))
    fill(canvas, {(1, 8), (2, 8), (4, 8), (5, 8), (6, 8), (8, 8), (9, 8)}, c("green_dark"))
    for x, y in ((2, 3), (5, 1), (8, 4)):
        fill(canvas, {(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)}, petal)
        canvas.put(x, y, c("gold_dark"))
    return canvas


def tuft():
    """Пучок высокой травы 9×7."""
    canvas = Canvas(9, 7)
    blades = {(1, 3), (1, 4), (2, 5), (3, 1), (3, 2), (3, 3), (3, 4), (4, 5), (5, 0), (5, 1), (5, 2),
              (5, 3), (5, 4), (6, 5), (7, 2), (7, 3), (7, 4)}
    fill(canvas, blades, c("grass_light"))
    fill(canvas, {(x, 6) for x in range(1, 8)} | {(2, 4), (4, 4), (6, 4)}, c("grass_dark"))
    return canvas


def shadow():
    """Тень под ногами персонажа 16×5: шахматка контура читается как
    полупрозрачная на любой земле, оставаясь непрозрачным пиксель-артом."""
    canvas = Canvas(16, 5)
    for x, y in ellipse(8, 2.5, 8, 2.5):
        if (x + y) % 2 == 0 or ((x - 8 + 0.5) / 6) ** 2 + ((y - 2) / 1.5) ** 2 <= 1:
            canvas.put(x, y, c("outline"))
    return canvas


def wade():
    """Вода поверх ног бредущего персонажа, 18×5: тело — цвет воды (на пруду
    его не видно), сверху светлая кромка — круг вокруг ног."""
    canvas = Canvas(18, 5)
    body = ellipse(9, 2.5, 9, 2.5)
    fill(canvas, body, c("water"))
    fill(canvas, {(x, y) for x, y in body if (x, y - 1) not in body}, c("water_light"))
    fill(canvas, {(0, 2), (17, 2)}, c("water_foam"))
    return canvas


def rug():
    """Сырмақ 85×38 (170×76 мира) с орнаментальной каймой и ромбом в центре."""
    canvas = Canvas(85, 38)
    body = rows({y: (0, 84) for y in range(0, 38)})
    fill(canvas, body, c("burgundy"))
    for inset, col in ((2, "gold"), (4, "burgundy_dark")):
        fill(canvas, {(x, y) for x, y in body if min(x, y, 84 - x, 37 - y) == inset}, c(col))
    for x in range(8, 78, 6):
        fill(canvas, {(x, 2), (x + 1, 2)}, c("parchment"))
        fill(canvas, {(x, 35), (x + 1, 35)}, c("parchment"))
    for y in range(19 - 10, 19 + 11):
        half = 10 - abs(y - 19)
        for x in range(42 - half, 43 + half):
            canvas.put(x, y, c("gold") if abs(x - 42) + abs(y - 19) >= half - 1 else c("burgundy_light"))
    outline(canvas)
    return canvas


# --- Юрта ---------------------------------------------------------------------

def yurt():
    """Юрта в виде 3/4, 104×112 (208×224 мира). Низ картинки — передняя кромка
    стены (центр юрты + 104 px мира), дверь спереди — там же, где проём в кольце
    стен yurt.tscn."""
    w, h = 104, 112
    canvas = Canvas(w, h)
    cx = w / 2
    walls = {(x, y) for y in range(56, 104) for x in range(2, w - 2)
             if y < 100 or (abs(x + 0.5 - cx) / 50) ** 2 + ((y - 100) / 4) ** 2 <= 1}
    roof = {(x, y) for y in range(8, 64) for x in range(w)
            if abs(x + 0.5 - cx) <= 6 + (y - 8) * (50 - 6) / (60 - 8)}
    roof |= {(x, y) for x, y in ellipse(cx, 60, 51, 6) if y >= 56}
    # Стена — цилиндр: светлее слева, темнее справа.
    for x, y in walls:
        t = (x - 2) / (w - 4)
        canvas.put(x, y, c("parchment") if t < 0.2 else c("felt") if t < 0.75 else c("felt_dark"))
    # Орнаментальная лента (басқұр).
    band = {(x, y) for x, y in walls if 64 <= y <= 70}
    fill(canvas, band, c("burgundy"))
    for x in range(4, w - 4, 6):
        fill(canvas, {(x, 66), (x + 1, 67), (x + 2, 66), (x + 1, 65)}, c("gold"))
    fill(canvas, {(x, y) for x, y in band if y in (64, 70)}, c("gold_dark"))
    # Купол: войлок, тень справа, жерди-уықтар от шаңырақа.
    for x, y in roof:
        canvas.put(x, y, c("felt_dark") if x > cx + (y - 8) * 0.55 else c("felt"))
    for k in range(-4, 5):
        for y in range(12, 60):
            x = int(cx + k * (y - 8) * 0.18)
            if (x, y) in roof and y % 2 == 0:
                canvas.put(x, y, c("cloth_shadow"))
    fill(canvas, {(x, y) for x, y in roof if y >= 58}, c("cloth_shadow"))
    # Шаңырақ — деревянный венец наверху.
    crown = ellipse(cx, 8, 8, 3.5)
    paint(canvas, crown, ramp("wood_light", "wood", "wood_dark"))
    fill(canvas, ellipse(cx, 8, 4, 1.5), c("ink"))
    # Дверь: красная, с золотым ромбом, в деревянной раме.
    door = rows({y: (43, 60) for y in range(76, 103)})
    paint(canvas, door, ramp("rust_light", "rust", "rust_dark"))
    fill(canvas, {(x, y) for x, y in door if x in (43, 60) or y == 76}, c("wood_dark"))
    for y in range(83, 96):
        half = 6 - abs(y - 89)
        if half >= 0:
            fill(canvas, {(51 - half, y), (52 + half, y)}, c("gold"))
    fill(canvas, {(51, 89), (52, 89)}, c("gold_light"))
    outline(canvas)
    ground_shadow(canvas, ellipse(cx + 2, 106, 52, 5))
    return canvas


# --- Арена --------------------------------------------------------------------

def _diamond(canvas, cx, cy, radius, colors):
    """Ромб с кольцами colors от края к центру."""
    for y in range(cy - radius, cy + radius + 1):
        for x in range(cx - radius, cx + radius + 1):
            d = radius - (abs(x - cx) + abs(y - cy))
            if d >= 0:
                canvas.put(x, y, colors[min(d, len(colors) - 1)])


def arena():
    """Той-алаң: утоптанное кольцо с орнаментом и ромб в центре. Трава внутри
    прозрачная — под ней обычная плитка травы."""
    r = ARENA_RADIUS
    size = 2 * r + 8
    canvas = Canvas(size, size)
    cx = cy = size // 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r - 14 <= d <= r:
                canvas.put(x, y, c("path") if r - 12 < d < r - 2 else c("path_dark"))
            elif r - 18 <= d < r - 14:
                canvas.put(x, y, c("gold_dark") if d >= r - 16 else c("gold"))
    for i in range(16):
        a = math.tau * i / 16
        _diamond(canvas, int(cx + math.cos(a) * (r - 7)), int(cy + math.sin(a) * (r - 7)), 5,
                 [c("outline"), c("gold"), c("burgundy")])
    _diamond(canvas, cx, cy, 56, [c("outline")] + [c("path_dark")] * 3 + [c("path")] * 14 + [c("gold")] * 3
             + [c("burgundy")] * 14 + [c("gold")] * 3 + [c("path_light")] * 20)
    for i in range(4):
        a = math.tau * i / 4 - math.pi / 2
        _diamond(canvas, int(cx + math.cos(a) * 78), int(cy + math.sin(a) * 78), 12,
                 [c("outline"), c("gold"), c("gold"), c("burgundy"), c("burgundy_light")])
    return canvas


def drawings():
    art = {"grass": grass_tile(), "grass_wild": wild_grass_tile(), "fence_h": fence_horizontal(),
           "fence_v": fence_vertical(), "rock_0": rock(0), "rock_1": rock(1), "log_h": log(False),
           "log_v": log(True), "bush": bush(), "tuft": tuft(), "rug": rug(), "yurt": yurt(), "arena": arena(),
           "shadow": shadow(), "wade": wade()}
    for kind in range(3):
        art[f"flowers_{kind}"] = flowers(kind)
    return art


def build():
    return [save(canvas, os.path.join(OUT_DIR, name + ".png")) for name, canvas in drawings().items()]
