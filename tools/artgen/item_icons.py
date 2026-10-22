"""Иконки 13 предметов одежды — для квиза, шкафа и энциклопедии.

Цвета те же, что у слоёв персонажа (characters.py): в квизе игрок узнаёт вещь,
которую только что видел на пойманном. Плоская манера иконок atilla: контур,
три тона со светом сверху слева, крупный узнаваемый силуэт. 32×32 пикселя арта,
сохраняются ×2 в assets/sprites/items/<id>.png.
"""
import os

from characters import GOLD, SHIRT_WHITE, ramp
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save

SIZE = 32
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "items")


# --- Фигуры ------------------------------------------------------------------

def ellipse(cx, cy, rx, ry):
    """Пиксели эллипса с центром (cx, cy) в координатах сетки."""
    return {(x, y) for y in range(int(cy - ry) - 1, int(cy + ry) + 2)
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1}


def box(x0, y0, x1, y1):
    return rows({y: (x0, x1) for y in range(y0, y1 + 1)})


def taper(y0, y1, half_top, half_bottom, cx=16):
    """Трапеция, симметричная относительно cx: полуширина меняется сверху вниз."""
    spans = {}
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        half = round(half_top + (half_bottom - half_top) * t)
        spans[y] = (cx - half, cx + half - 1)
    return rows(spans)


def below(mask, y):
    return {(px, py) for px, py in mask if py <= y}


def dots(xs, y):
    return {(x, y) for x in xs}


FUR = ramp("fur_light", "fur", "fur_dark")
BROWN_FUR = ramp("wood_light", "wood", "wood_dark")
RED = ramp("red_light", "burgundy_light", "burgundy")
BURGUNDY = ramp("burgundy_light", "burgundy", "burgundy_dark")
BLUE = ramp("blue_light", "blue", "blue_dark")
GREEN = ramp("green_light", "green", "green_dark")
LEATHER = ramp("leather_light", "leather", "leather_dark")


# --- Бас киім ----------------------------------------------------------------

def head_borik(cv):
    crown = below(ellipse(16, 16, 9, 10), 16)
    band = taper(16, 22, 12, 12) - {(4, 16), (27, 16), (4, 22), (27, 22)}
    paint(cv, crown, ramp("leather_light", "leather_dark", "outline"))
    paint(cv, band, FUR)
    fill(cv, {(x, y) for x, y in band if (x + y) % 4 == 0 and 17 <= y <= 21 and 6 <= x <= 25}, c("fur_dark"))
    fill(cv, box(15, 4, 16, 6), c("gold"))


def head_tymaq(cv):
    crown = below(ellipse(16, 13, 8, 8), 13)
    brim = box(6, 13, 25, 16)
    flaps = box(5, 16, 10, 25) | box(21, 16, 26, 25)
    flaps -= {(5, 25), (10, 25), (21, 25), (26, 25)}
    paint(cv, crown, ramp("teal", "teal_dark", "outline"))
    paint(cv, brim | flaps, BROWN_FUR)


def head_takiya(cv):
    cap = {(x, y) for x, y in ellipse(16, 20, 11, 11) if 9 <= y <= 21}
    paint(cv, cap, BURGUNDY)
    fill(cv, dots(range(8, 25, 3), 15), c("gold_light"))
    fill(cv, {(x, y) for x, y in cap if y in (19, 20)}, c("gold"))


def head_kimeshek(cv):
    hood = ellipse(16, 14, 11, 11)
    face = ellipse(16, 14, 5, 6.5)
    bib = taper(22, 29, 8, 11)
    cloth = (hood | bib) - face
    paint(cv, cloth, SHIRT_WHITE)
    paint(cv, face, ramp("skin_light", "skin", "skin_dark"))
    fill(cv, {(14, 13), (18, 13)}, c("ink"))
    trim = {(x, y) for x, y in cloth if any(n in face for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))}
    trim |= {(x, 29) for x, y in bib if y == 29}
    fill(cv, trim, c("burgundy_light"))


def head_saukele(cv):
    cone = taper(4, 22, 1, 7)
    rim = box(8, 22, 23, 24)
    paint(cv, cone, RED)
    fill(cv, {(x, y) for x, y in cone if y in (9, 15, 20)}, c("gold"))
    paint(cv, rim, ramp("fur_light", "fur_light", "fur"))
    fill(cv, box(15, 1, 16, 3), c("gold_light"))
    pendants = box(6, 24, 7, 29) | box(24, 24, 25, 29)
    paint(cv, pendants, GOLD)


# --- Сырт киім ---------------------------------------------------------------

def torso_shapan(cv):
    body = taper(7, 28, 6, 9)
    sleeves = taper(8, 20, 2, 3, cx=6) | taper(8, 20, 2, 3, cx=26)
    paint(cv, sleeves, BLUE)
    paint(cv, body, BLUE)
    fill(cv, {(16, y) for y in range(9, 28)}, c("gold"))
    fill(cv, {(x, y) for x, y in body if y == 28}, c("gold"))
    fill(cv, {(x, y) for x, y in sleeves if y == 20}, c("gold"))
    fill(cv, {(x, y) for x, y in body if y == 16 and x != 16}, c("leather"))
    fill(cv, {(14, 7), (15, 8), (17, 8), (18, 7)}, c("gold_light"))


def torso_kamzol(cv):
    vest = taper(6, 26, 7, 8)
    vest -= taper(6, 11, 2, 0)  # вырез
    vest -= box(9, 6, 9, 9) | box(22, 6, 22, 9)  # проймы
    paint(cv, vest, RED)
    edge = {(x, y) for x, y in vest if (x - 1, y) not in vest and x >= 15 or (x + 1, y) not in vest and x <= 16}
    fill(cv, {(x, y) for x, y in edge if 13 <= x <= 18} | {(x, 26) for x, y in vest if y == 26}, c("gold"))
    fill(cv, dots((13, 18), 18) | dots((13, 18), 22), c("gold_light"))


def torso_koylek(cv):
    # Т-силуэт: плечи соединяют рукава с корпусом.
    body = taper(8, 26, 7, 7)
    sleeves = box(4, 8, 8, 23) | box(23, 8, 27, 23) | box(4, 8, 27, 10)
    paint(cv, sleeves, GREEN)
    paint(cv, body - box(4, 8, 27, 10), GREEN)
    fill(cv, {(16, y) for y in range(8, 13)} | {(15, 8), (17, 8)}, c("green_dark"))
    fill(cv, {(x, y) for x, y in sleeves if y == 23}, c("green_light"))


# --- Шалбар ------------------------------------------------------------------

def _trousers(cv, colors):
    waist = box(8, 5, 23, 7)
    legs = box(8, 8, 15, 27) | box(16, 8, 23, 27)
    legs -= box(15, 13, 16, 27)
    paint(cv, legs, colors)
    paint(cv, waist, LEATHER)
    return legs


def pants_shalbar(cv):
    _trousers(cv, LEATHER)


def pants_shalbar_decorated(cv):
    legs = _trousers(cv, BURGUNDY)
    fill(cv, {(x, y) for x, y in legs if x in (8, 23) and y >= 8}, c("gold"))
    cuffs = {(x, y) for x, y in legs if y >= 25}
    fill(cv, cuffs, c("gold"))
    fill(cv, {(x, 26) for x, y in cuffs if x % 2 == 0}, c("burgundy"))


# --- Аяқ киім ----------------------------------------------------------------

def shoes_kebis(cv):
    # Низкая туфля в профиль: загнутый вверх носок, тёмный вырез, каблучок.
    upper = rows({16: (14, 25), 17: (11, 26), 18: (9, 26), 19: (7, 26), 20: (6, 26), 21: (5, 26)})
    toe = rows({15: (3, 4), 16: (3, 5), 17: (4, 6), 18: (5, 7)})
    sole = box(5, 22, 26, 23)
    heel = box(22, 24, 25, 25)
    paint(cv, upper | toe, LEATHER)
    paint(cv, sole | heel, ramp("leather_dark", "leather_dark", "outline"))
    fill(cv, box(16, 16, 24, 17), c("leather_dark"))
    fill(cv, dots((9, 12, 15), 20), c("gold"))


def shoes_masi(cv):
    shaft = box(12, 9, 20, 21)
    foot = rows({21: (8, 22), 22: (6, 23), 23: (5, 23), 24: (5, 23)})
    paint(cv, shaft | foot, ramp("leather", "leather_dark", "outline"))
    fill(cv, {(x, 13) for x in range(13, 20)}, c("leather_light"))


def shoes_saptama_etik(cv):
    shaft = box(12, 3, 21, 22)
    foot = rows({22: (8, 22), 23: (6, 23), 24: (5, 23), 25: (5, 23)})
    heel = box(19, 26, 22, 27)
    paint(cv, shaft | foot, ramp("ink_soft", "ink", "outline"))
    paint(cv, heel, ramp("leather", "leather_dark", "outline"))
    fill(cv, box(12, 3, 21, 4), c("gold"))
    fill(cv, dots((15, 18), 8), c("gold_light"))


ICONS = {
    "head_borik_01": head_borik,
    "head_kimeshek_01": head_kimeshek,
    "head_saukele_01": head_saukele,
    "head_takiya_01": head_takiya,
    "head_tymaq_01": head_tymaq,
    "torso_kamzol_01": torso_kamzol,
    "torso_koylek_01": torso_koylek,
    "torso_shapan_01": torso_shapan,
    "pants_shalbar_01": pants_shalbar,
    "pants_shalbar_decorated_01": pants_shalbar_decorated,
    "shoes_kebis_01": shoes_kebis,
    "shoes_masi_01": shoes_masi,
    "shoes_saptama_etik_01": shoes_saptama_etik,
}


def icon(item_id):
    canvas = Canvas(SIZE, SIZE)
    ICONS[item_id](canvas)
    outline(canvas)
    return canvas


def build():
    return [save(icon(item_id), os.path.join(OUT_DIR, item_id + ".png")) for item_id in ICONS]
