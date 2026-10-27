"""Пиксельный персонаж САҢЛАҚ по слоям: тело (3 варианта) и 13 предметов одежды.

Лист — контракт scripts/entities/character_visual.gd (см. assets/sprites/character/README.md):
4 строки (вниз, вверх, влево, вправо) × 6 кадров (покой ×2, шаг ×4). Клетка —
32×32 пикселя арта, лист сохраняется ×2: кадр 64×64, лист 384×256. Право —
зеркало лева.

Все слои рисуются в одной геометрии фигуры (Figure) и с одной позой на кадр,
поэтому сходятся пиксель в пиксель. Порядок наложения: тело → обувь → штаны →
торс → голова. У каждого слоя свой контур: где вещь заходит на другую, контур
читается как шов или пояс. Свет — сверху слева, как у рамок интерфейса.
"""
from dataclasses import dataclass

import os

from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save, shifted

CELL = 32
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "character")
DIRECTIONS = ["down", "up", "left", "right"]


@dataclass(frozen=True)
class Pose:
    """Поза кадра. lift — нога приподнята (вид спереди), stride — шаг вбок
    в профиль (+1: передняя нога вперёд), breath — плечи и голова ниже на пиксель."""
    lift_left: int = 0
    lift_right: int = 0
    stride: int = 0
    breath: int = 0


# Кадры листа: покой, вдох, шаг левой, переход, шаг правой, переход.
# Подпрыгивание при ходьбе добавляет character_visual.gd — в кадрах его нет.
POSES = [Pose(), Pose(breath=1), Pose(lift_left=1, stride=1), Pose(), Pose(lift_right=1, stride=-1), Pose()]


def ramp(light, base, dark):
    return (c(light), c(base), c(dark))


# --- Геометрия фигуры --------------------------------------------------------

class Figure:
    """Части тела в координатах клетки для направления и позы. Направление
    "right" рисуется как "left" и зеркалится при сборке листа."""

    def __init__(self, direction, pose):
        self.dir = "left" if direction == "right" else direction
        self.pose = pose
        self.side = self.dir == "left"
        self.up = pose.breath  # смещение верха тела

    # Голова — 10×10 с подрезанными углами, общая для всех направлений.
    def head(self):
        return shifted(rows({5: (13, 18), 6: (12, 19), **{y: (11, 20) for y in range(7, 13)},
                             13: (12, 19), 14: (13, 18)}), dy=self.up)

    def neck(self):
        return shifted(rows({15: (15, 17) if self.side else (14, 17)}), dy=self.up)

    def torso(self, bottom=22, flare=0):
        """Корпус от плеч до bottom; flare расширяет низ (длинная одежда)."""
        x0, x1 = (12, 19) if self.side else (11, 20)
        spans = {15: (x0 + 1, x1 - 1)}
        for y in range(16, bottom + 1):
            grow = flare * (y - 22) // 5 if y > 22 else 0
            spans[y] = (x0 - grow, x1 + grow)
        return shifted(rows(spans), dy=self.up)

    def arms(self, cuff=22):
        """Рукава до cuff. В профиль видна одна рука, она качается при шаге."""
        if self.side:
            swing = -self.pose.stride
            return shifted(rows({y: (15, 17) for y in range(16, cuff + 1)}), dx=swing, dy=self.up)
        return shifted(rows({y: (9, 10) for y in range(16, cuff + 1)}) | rows({y: (21, 22) for y in range(16, cuff + 1)}),
                       dy=self.up)

    def hands(self):
        if self.side:
            return shifted(rows({23: (15, 16)}), dx=-2 * self.pose.stride, dy=self.up)
        return shifted(rows({23: (9, 10)}) | rows({23: (21, 22)}), dy=self.up)

    def hips(self):
        return rows({23: (12, 19) if self.side else (11, 20)})

    def legs(self, top=24, bottom=29):
        """Обе ноги от top до bottom; приподнятая нога короче на пиксель."""
        return self.leg(True, top, bottom) | self.leg(False, top, bottom)

    def leg(self, left, top=24, bottom=29):
        if self.side:
            # В профиль: «левая» — передняя нога, шагает влево.
            dx = -2 * self.pose.stride if left else 2 * self.pose.stride
            x0 = 13 if left else 15
            return shifted(rows({y: (x0, x0 + 3) for y in range(top, bottom + 1)}), dx=dx)
        lift = self.pose.lift_left if left else self.pose.lift_right
        x0 = 11 if left else 17
        mask = rows({y: (x0, x0 + 3) for y in range(top, bottom + 1 - lift)})
        if top <= 25:
            mask |= rows({y: (15, 16) for y in range(top, min(bottom, 25) + 1)})
        return mask

    def foot(self, left, height=2):
        """Ступня/обувь высотой height (кебіс — 2, мәсі — 4, етік — 6)."""
        if self.side:
            dx = -2 * self.pose.stride if left else 2 * self.pose.stride
            x0 = 12 if left else 14
            spans = {31 - i: (x0 + 1, x0 + 4) for i in range(1, height)}
            spans[31] = (x0, x0 + 4)
            return shifted(rows(spans), dx=dx)
        lift = self.pose.lift_left if left else self.pose.lift_right
        x0, x1 = (10, 14) if left else (17, 21)
        spans = {31 - i: (x0 + (1 if left else 0), x1 - (0 if left else 1)) for i in range(1, height)}
        spans[31] = (x0, x1)
        return shifted(rows(spans), dy=-lift)

    def feet(self, height=2):
        return self.foot(True, height) | self.foot(False, height)


# --- Рисование ---------------------------------------------------------------

def paint_upper(canvas, fig, body, sleeves, body_mask=None, sleeve_mask=None):
    """Корпус и рукава отдельно: на стыке светотень даёт шов, а рука в профиль
    читается поверх корпуса."""
    paint(canvas, body_mask if body_mask is not None else fig.torso(), body)
    paint(canvas, sleeve_mask if sleeve_mask is not None else fig.arms(), sleeves)


# --- Тело --------------------------------------------------------------------

BODIES = {
    # Короткая тёмная стрижка.
    "base": dict(skin=ramp("skin_light", "skin", "skin_dark"), hair=ramp("ink_soft", "ink", "outline"), style="short"),
    # Смуглая кожа, две косички.
    "base_02": dict(skin=ramp("skin", "skin_dark", "skin_deep"), hair=ramp("ink_soft", "ink", "outline"), style="braids"),
    # Светлая кожа, каштановая чёлка.
    "base_03": dict(skin=ramp("skin_light", "skin_light", "skin"), hair=ramp("leather_light", "hair_brown", "leather"), style="fringe"),
}
UNDERWEAR = ramp("parchment_dark", "cloth_shadow", "muted")


def draw_body(canvas, fig, body):
    skin, hair = body["skin"], body["hair"]
    paint(canvas, fig.legs(), UNDERWEAR)
    paint_upper(canvas, fig, UNDERWEAR, UNDERWEAR)
    paint(canvas, fig.hands(), skin)
    paint(canvas, fig.feet(), skin)
    fill(canvas, fig.neck(), skin[2])
    paint(canvas, fig.head(), skin)
    up = fig.up
    if fig.dir == "down":
        for eye_x in (14, 17):
            fill(canvas, {(eye_x, 10 + up), (eye_x, 11 + up)}, c("ink"))
        fill(canvas, {(15, 13 + up), (16, 13 + up)}, skin[2])
        fill(canvas, {(12, 12 + up), (19, 12 + up)}, c("rose_light"))
    elif fig.dir == "left":
        fill(canvas, {(13, 10 + up), (13, 11 + up)}, c("ink"))
        fill(canvas, {(12, 13 + up)}, skin[2])
        fill(canvas, {(12, 12 + up)}, c("rose_light"))
    paint(canvas, hair_mask(fig, body["style"]), hair)


def hair_mask(fig, style):
    up = fig.up
    if fig.dir == "up":
        mask = rows({5: (13, 18), 6: (12, 19), **{y: (11, 20) for y in range(7, 13)}, 13: (12, 19)})
    elif fig.dir == "left":
        mask = rows({5: (13, 18), 6: (12, 19), 7: (11, 20), 8: (15, 20), 9: (16, 20), 10: (17, 20), 11: (18, 20), 12: (18, 20)})
    else:
        mask = rows({5: (13, 18), 6: (12, 19), 7: (11, 20), 8: (11, 12), 9: (11, 11)}) | rows({8: (19, 20), 9: (20, 20)})
        if style == "fringe":
            mask |= rows({8: (13, 16)})
    if style == "braids":
        if fig.dir == "left":
            mask |= rows({y: (19, 20) for y in range(13, 19)})
        else:
            mask |= rows({y: (10, 11) for y in range(11, 19)}) | rows({y: (20, 21) for y in range(11, 19)})
    return shifted(mask, dy=up)


# --- Одежда ------------------------------------------------------------------

GOLD = ramp("gold_light", "gold", "gold_dark")
SHIRT_WHITE = ramp("parchment", "parchment_dark", "cloth_shadow")


def torso_koylek(canvas, fig):
    """Көйлек — зелёная рубаха с длинными рукавами и вырезом."""
    green = ramp("green_light", "green", "green_dark")
    paint_upper(canvas, fig, green, green)
    if fig.dir == "down":
        fill(canvas, {(15, 15 + fig.up), (16, 15 + fig.up), (15, 16 + fig.up)}, c("green_dark"))


def torso_kamzol(canvas, fig):
    """Камзол — красный жилет без рукавов с золотой каймой поверх белой рубахи."""
    vest = fig.torso()
    if fig.dir == "down":
        paint(canvas, vest, SHIRT_WHITE)
        vest -= shifted(rows({y: (15, 16) for y in range(15, 19)}), dy=fig.up)
    paint(canvas, vest, ramp("red_light", "burgundy_light", "burgundy"))
    paint(canvas, fig.arms(), SHIRT_WHITE)
    up = fig.up
    if fig.dir == "down":
        fill(canvas, {(14, y + up) for y in range(17, 23)} | {(17, y + up) for y in range(17, 23)}, c("gold"))
    fill(canvas, {(x, 22 + up) for x, y in vest if y == 22 + up}, c("gold"))


def torso_shapan(canvas, fig):
    """Шапан — длинный синий халат до колен с широкими рукавами и золотой каймой."""
    robe = fig.torso(bottom=27, flare=2)
    sleeves = fig.arms(cuff=22)
    blue = ramp("blue_light", "blue", "blue_dark")
    paint_upper(canvas, fig, blue, blue, robe, sleeves)
    up = fig.up
    fill(canvas, {(x, 27 + up) for x, y in robe if y == 27 + up}, c("gold"))
    fill(canvas, {(x, y) for x, y in sleeves if y == 22 + up}, c("gold"))
    if fig.dir == "down":
        fill(canvas, {(16, y + up) for y in range(16, 27)}, c("gold"))
    fill(canvas, {(x, 20 + up) for x, y in robe if y == 20 + up}, c("leather"))  # белбеу — пояс


def pants_shalbar(canvas, fig):
    """Шалбар — простые бурые штаны."""
    paint(canvas, fig.hips() | fig.legs(), ramp("leather_light", "leather", "leather_dark"))


def pants_shalbar_decorated(canvas, fig):
    """Әшекейлі шалбар — бордовые штаны с золотым лампасом и узорным низом."""
    legs = fig.hips() | fig.legs()
    paint(canvas, legs, ramp("burgundy_light", "burgundy", "burgundy_dark"))
    if fig.side:
        fill(canvas, {(x, y) for x, y in fig.leg(True) if (x - 1, y) not in legs or x == min(p[0] for p in fig.leg(True))}, c("gold"))
    else:
        for left in (True, False):
            leg = fig.leg(left)
            edge = min(x for x, _ in leg) if left else max(x for x, _ in leg)
            fill(canvas, {(edge, y) for x, y in leg if x == edge}, c("gold"))
    bottom = {(x, y) for x, y in legs if (x, y + 1) not in legs}
    fill(canvas, bottom, c("gold_light"))


def shoes_kebis(canvas, fig):
    """Кебіс — низкие кожаные туфли."""
    paint(canvas, fig.feet(2), ramp("leather_light", "leather", "leather_dark"))


def shoes_masi(canvas, fig):
    """Мәсі — мягкие сапожки до щиколотки."""
    paint(canvas, fig.feet(4), ramp("leather", "leather_dark", "outline"))


def shoes_saptama_etik(canvas, fig):
    """Саптама етік — высокие чёрные сапоги с золотой каймой."""
    boots = fig.feet(6)
    paint(canvas, boots, ramp("ink_soft", "ink", "outline"))
    fill(canvas, {(x, y) for x, y in boots if (x, y - 1) not in boots}, c("gold"))


def head_borik(canvas, fig):
    """Бөрік — тёмная шапка с меховым околышем и шишечкой."""
    up = fig.up
    crown = shifted(rows({1: (14, 17), 2: (13, 18), 3: (12, 19), 4: (12, 19)}), dy=up)
    band = shifted(rows({5: (11, 20), 6: (10, 21), 7: (10, 21)}), dy=up)
    paint(canvas, crown, ramp("leather_light", "leather_dark", "outline"))
    paint(canvas, band, ramp("fur_light", "fur", "fur_dark"))
    fill(canvas, {(15, up), (16, up)}, c("gold"))


def head_tymaq(canvas, fig):
    """Тымақ — меховая шапка с наушами до подбородка."""
    up = fig.up
    crown = shifted(rows({2: (13, 18), 3: (12, 19), 4: (12, 19)}), dy=up)
    brim = shifted(rows({5: (10, 21), 6: (10, 21), 7: (10, 21)}), dy=up)
    if fig.dir == "left":
        flaps = shifted(rows({y: (18, 21) for y in range(8, 15)}), dy=up)
    elif fig.dir == "up":
        flaps = shifted(rows({y: (10, 21) for y in range(8, 15)}), dy=up)
    else:
        flaps = shifted(rows({y: (9, 11) for y in range(8, 15)}) | rows({y: (20, 22) for y in range(8, 15)}), dy=up)
    paint(canvas, crown, ramp("teal", "teal_dark", "outline"))
    paint(canvas, brim | flaps, ramp("wood_light", "wood", "wood_dark"))


def head_takiya(canvas, fig):
    """Тақия — маленькая тюбетейка с золотыми точками."""
    up = fig.up
    cap = shifted(rows({3: (13, 18), 4: (12, 19), 5: (11, 20), 6: (11, 20)}), dy=up)
    paint(canvas, cap, ramp("burgundy_light", "burgundy", "burgundy_dark"))
    fill(canvas, {(x, 5 + up) for x in (12, 14, 17, 19)}, c("gold_light"))


def head_kimeshek(canvas, fig):
    """Кимешек — белое покрывало вокруг лица с вышитой каймой, спадает на плечи."""
    up = fig.up
    cover = rows({3: (13, 18), 4: (12, 19), **{y: (10, 21) for y in range(5, 18)}})
    if fig.dir == "down":
        face = rows({8: (13, 18), 9: (12, 19), 10: (12, 19), 11: (12, 19), 12: (12, 19), 13: (13, 18), 14: (14, 17)})
    elif fig.dir == "left":
        # В профиль лицо открыто вперёд, полотно огибает затылок.
        face = rows({y: (10, 15) for y in range(8, 15)} | {7: (10, 12), 15: (10, 13), 16: (10, 11)})
    else:
        face = set()
    cover = shifted(cover - face, dy=up)
    face = shifted(face, dy=up)
    paint(canvas, cover, SHIRT_WHITE)
    # Вышивка вокруг лица и по нижнему краю.
    trim = {(x, y) for x, y in cover if any(n in face for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))}
    trim |= {(x, y) for x, y in cover if (x, y + 1) not in cover}
    fill(canvas, trim, c("burgundy_light"))


def head_saukele(canvas, fig):
    """Сәукеле — высокий красный конус с золотыми поясами и подвесками."""
    up = fig.up
    cone = shifted(rows({0: (15, 16), 1: (15, 16), 2: (14, 17), 3: (14, 17), 4: (13, 18), 5: (13, 18), 6: (12, 19)}), dy=up)
    rim = shifted(rows({7: (11, 20)}), dy=up)
    paint(canvas, cone, ramp("red_light", "burgundy_light", "burgundy"))
    fill(canvas, {(x, y) for x, y in cone if y in (2 + up, 5 + up)}, c("gold"))
    paint(canvas, rim, ramp("fur_light", "fur_light", "fur"))
    if fig.dir != "up":
        pendants = {(11, y + up) for y in range(8, 13)} | {(20, y + up) for y in range(8, 13)}
        if fig.dir == "left":
            pendants = {(19, y + up) for y in range(8, 13)}
        fill(canvas, pendants, c("gold"))


def torso_sauyt(canvas, fig):
    """Сауыт — стальная кольчуга до бёдер поверх бурой рубахи, кожаный пояс."""
    mail = fig.torso(bottom=24, flare=1)
    sleeves = fig.arms(cuff=20)
    steel = ramp("steel_light", "steel", "steel_dark")
    paint_upper(canvas, fig, steel, steel, mail, sleeves)
    up = fig.up
    # Кольца — шахматка тёмных точек по корпусу.
    fill(canvas, {(x, y) for x, y in mail if (x + y) % 2 == 0 and 17 + up <= y <= 23 + up
                  and (x - 1, y) in mail and (x + 1, y) in mail}, c("steel_dark"))
    fill(canvas, {(x, 20 + up) for x, y in mail if y == 20 + up}, c("leather_dark"))
    paint(canvas, shifted(rows({y: (9, 10) for y in range(21, 23)}) | rows({y: (21, 22) for y in range(21, 23)}), dy=up)
          if fig.dir in ("down", "up") else shifted(rows({y: (15, 17) for y in range(21, 23)}), dx=-fig.pose.stride, dy=up),
          ramp("leather_light", "leather", "leather_dark"))


def head_dulyga(canvas, fig):
    """Дулыға — островерхий стальной шлем с бармицей на плечи и золотым навершием."""
    up = fig.up
    dome = shifted(rows({1: (15, 16), 2: (14, 17), 3: (13, 18), 4: (12, 19), 5: (11, 20), 6: (11, 20)}), dy=up)
    if fig.dir == "left":
        aventail = shifted(rows({y: (17, 21) for y in range(7, 15)}), dy=up)
    elif fig.dir == "up":
        aventail = shifted(rows({y: (10, 21) for y in range(7, 15)}), dy=up)
    else:
        aventail = shifted(rows({y: (10, 11) for y in range(7, 15)}) | rows({y: (20, 21) for y in range(7, 15)}), dy=up)
    paint(canvas, aventail, ramp("steel", "steel_dark", "ink_soft"))
    paint(canvas, dome, ramp("steel_light", "steel", "steel_dark"))
    fill(canvas, {(15, up), (16, up)}, c("gold"))
    fill(canvas, {(x, 6 + up) for x, y in dome if y == 6 + up}, c("gold_dark"))


## Облики героев и жителей «Дала жолы»: этих вещей нет в шкафу и квизе.
STORY_ITEMS = {
    "torso_sauyt_01": torso_sauyt,
    "head_dulyga_01": head_dulyga,
}


ITEMS = {
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


# --- Сборка листа ------------------------------------------------------------

def frame(draw, direction, pose):
    """Один кадр слоя: draw(canvas, figure) + контур; «вправо» — зеркало «влево»."""
    canvas = Canvas(CELL, CELL)
    draw(canvas, Figure(direction, pose))
    outline(canvas)
    return canvas.mirrored() if direction == "right" else canvas


def sheet(draw):
    """Лист слоя 6×4 клеток в пикселях арта."""
    out = Canvas(CELL * len(POSES), CELL * len(DIRECTIONS))
    for row, direction in enumerate(DIRECTIONS):
        for col, pose in enumerate(POSES):
            out.image.paste(frame(draw, direction, pose).image, (col * CELL, row * CELL))
    return out


def body_sheet(name):
    return sheet(lambda canvas, fig: draw_body(canvas, fig, BODIES[name]))


def item_sheet(item_id):
    return sheet(ITEMS.get(item_id) or STORY_ITEMS[item_id])


def build():
    """Пишет листы тела и одежды в assets/sprites/character/<слот>/<id>.png."""
    written = []
    for name in BODIES:
        written.append(save(body_sheet(name), os.path.join(OUT_DIR, "base", name + ".png")))
    for item_id in list(ITEMS) + list(STORY_ITEMS):
        slot = item_id.split("_")[0]
        written.append(save(item_sheet(item_id), os.path.join(OUT_DIR, slot, item_id + ".png")))
    return written
