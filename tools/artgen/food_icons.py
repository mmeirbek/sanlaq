"""Иконки национальных блюд для «Абай айтады»: 32×32 пикселя арта, как иконки
одежды. Сохраняются ×2 в assets/sprites/food/<id>.png; id — как в data/words.
"""
import os

from item_icons import box, ellipse, ramp
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "food")

GOLDEN = ramp("gold_light", "gold", "gold_dark")
WOOD = ramp("wood_light", "wood", "wood_dark")
WHITE = ramp("parchment", "cream", "cloth_shadow")


def _board(cv, cy=25, rx=14, ry=4):
    """Деревянная доска-табақ под блюдом."""
    paint(cv, ellipse(16, cy, rx, ry), WOOD)


def _balls(cv, centers, radius, colors):
    for cx, cy in centers:
        paint(cv, ellipse(cx, cy, radius, radius), colors)


def baursak(cv):
    """Горка золотых баурсаков на синей тарелке."""
    paint(cv, ellipse(16, 25, 14, 4.5), ramp("blue_light", "blue", "blue_dark"))
    _balls(cv, [(10, 20), (16, 21), (22, 20), (13, 15), (19, 15), (16, 10)], 4, GOLDEN)
    fill(cv, {(9, 18), (15, 19), (21, 18), (12, 13), (18, 13), (15, 8)}, c("sun"))


def beshbarmaq(cv):
    """Тесто-сочни и куски мяса на большом блюде."""
    paint(cv, ellipse(16, 21, 15, 7), ramp("stone_light", "stone", "stone_dark"))
    dough = ellipse(16, 20, 12, 5)
    paint(cv, dough, ramp("parchment", "felt", "felt_dark"))
    for x0, y in ((8, 18), (13, 21), (18, 17)):
        meat = rows({y: (x0, x0 + 6), y + 1: (x0 - 1, x0 + 7), y + 2: (x0, x0 + 6)})
        paint(cv, meat, ramp("rose_light", "rust", "rust_dark"))
    fill(cv, {(11, 16), (22, 21), (20, 23)}, c("green"))


def irimshik(cv):
    """Горка жёлтых кусочков ірімшік на доске."""
    _board(cv)
    heap = {(x, y) for y in range(12, 25) for x in range(4, 28) if abs(x - 15.5) <= (y - 11) * 0.95}
    fill(cv, heap, c("gold"))
    for x, y in [(x, y) for x, y in heap if (x * 3 + y * 5) % 7 == 0]:
        fill(cv, {(x, y), (x + 1, y)}, c("sun"))
    for x, y in [(x, y) for x, y in heap if (x * 5 + y * 3) % 9 == 0]:
        fill(cv, {(x, y)}, c("gold_dark"))


def kozhe(cv):
    """Глиняная кәсе с көже и деревянная ложка."""
    spoon = {(21 + k, 13 - k) for k in range(8)} | {(22 + k, 13 - k) for k in range(8)}
    fill(cv, spoon, c("wood"))
    bowl = {(x, y) for x, y in ellipse(16, 17, 13, 10) if y >= 17}
    paint(cv, bowl, ramp("rust_light", "rust", "rust_dark"))
    top = ellipse(16, 17, 13, 3)
    paint(cv, top, ramp("parchment", "felt", "felt_dark"))
    fill(cv, {(10, 17), (14, 16), (19, 18), (22, 17), (16, 18)}, c("felt_dark"))
    fill(cv, {(x, 21) for x in range(6, 27, 3)}, c("gold"))


def kurt(cv):
    """Белые шарики құрт на доске."""
    _board(cv)
    _balls(cv, [(9, 20), (16, 21), (23, 20), (12, 14), (20, 14)], 4, WHITE)
    fill(cv, {(8, 18), (15, 19), (22, 18), (11, 12), (19, 12)}, c("parchment"))


def qazy(cv):
    """Кружки қазы: тёмное мясо в белом ободке жира."""
    paint(cv, ellipse(16, 22, 15, 6), ramp("parchment", "parchment_dark", "felt_dark"))
    for cx, cy in ((10, 20), (17, 22), (23, 19), (14, 16), (20, 15)):
        paint(cv, ellipse(cx, cy, 4, 3), WHITE)
        paint(cv, ellipse(cx, cy, 3, 2), ramp("burgundy_light", "burgundy", "burgundy_dark"))


def qymyz(cv):
    """Кесе с қымызом: синяя чаша с золотой каймой, белый напиток."""
    bowl = {(x, y) for x, y in ellipse(16, 13, 14, 13) if y >= 13 and y <= 25}
    paint(cv, bowl, ramp("blue_light", "blue", "blue_dark"))
    fill(cv, {(x, 16) for x in range(4, 29) if (x, 16) in bowl}, c("gold"))
    fill(cv, rows({26: (12, 20), 27: (11, 21)}), c("blue_dark"))
    paint(cv, ellipse(16, 13, 14, 3.5), WHITE)


def shubat(cv):
    """Глиняный кувшин шұбата с орнаментом."""
    body = ellipse(16, 20, 9, 9)
    neck = box(13, 4, 18, 12)
    paint(cv, body | neck, ramp("rust_light", "rust", "rust_dark"))
    fill(cv, rows({4: (12, 19), 5: (12, 19)}), c("rust_dark"))
    fill(cv, {(x, 19) for x in range(8, 25) if (x, 19) in body}, c("gold"))
    for x in range(9, 24, 4):
        fill(cv, {(x, 21), (x + 1, 22), (x + 2, 21)}, c("burgundy"))
    handle = {(24, y) for y in range(10, 18)} | {(25, y) for y in range(11, 17)} | {(23, 10), (22, 10)}
    fill(cv, handle, c("rust_dark"))
    fill(cv, rows({3: (13, 18)}), c("cream"))


ICONS = {
    "baursak": baursak, "beshbarmaq": beshbarmaq, "irimshik": irimshik, "kozhe": kozhe,
    "kurt": kurt, "qazy": qazy, "qymyz": qymyz, "shubat": shubat,
}


def drawings():
    art = {}
    for name, draw in ICONS.items():
        canvas = Canvas(32, 32)
        draw(canvas)
        outline(canvas)
        art[name] = canvas
    return art


def build():
    return [save(canvas, os.path.join(OUT_DIR, name + ".png")) for name, canvas in drawings().items()]
