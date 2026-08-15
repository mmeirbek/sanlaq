#!/usr/bin/env python3
"""Генератор ассетов персонажа для Соқыртеке.
Тело: 4 направления x 6 кадров (idle0,1 / walk0..3). Право = зеркало левого.
Одежда по слотам + превью предметов + бесшовные трава/вода + блоб воды + шаблон.
Логическая сетка 16x16 -> x4 = 64x64 кадр. Лист = 4 строки x 6 колонок.
"""
import math, os, random, sys
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
CHAR = os.path.join(ROOT, "assets/character")
ITEMS_DIR = os.path.join(ROOT, "assets/items")
TILES = os.path.join(ROOT, "assets/tiles")

SIZE = 16
SCALE = 4
FRAME = SIZE * SCALE
DIRS = ["down", "up", "left", "right"]
FRAMES = 6

OUTLINE = (38, 31, 25, 255)
SKIN = (244, 219, 178, 255)
SKIN_DARK = (214, 184, 140, 255)
HAIR = (72, 50, 34, 255)
EYE = (30, 26, 22, 255)
GOLD = (234, 194, 91, 255)

# Варианты остаются совместимы с той же одеждой: меняются только лицо, кожа и волосы.
BASE_VARIANTS = [
    {"file": "base.png", "skin": SKIN, "skin_dark": SKIN_DARK, "hair": HAIR, "hair_style": "short"},
    {"file": "base_02.png", "skin": (202, 139, 91, 255), "skin_dark": (166, 102, 69, 255), "hair": (40, 29, 25, 255), "hair_style": "braid"},
    {"file": "base_03.png", "skin": (231, 185, 133, 255), "skin_dark": (194, 145, 102, 255), "hair": (108, 63, 31, 255), "hair_style": "fringe"},
]

ITEMS = {
    "head_borik_01":             {"slot": "head",  "color": (74, 48, 28),    "hat": "band", "accent": (214, 174, 96)},
    "head_takiya_01":            {"slot": "head",  "color": (158, 34, 34),   "hat": "cap", "accent": (245, 206, 104)},
    "head_saukele_01":           {"slot": "head",  "color": (196, 48, 68),   "hat": "tall", "accent": (252, 225, 163)},
    "head_tymaq_01":             {"slot": "head",  "color": (150, 100, 55),  "hat": "flaps", "accent": (238, 221, 181)},
    "head_kimeshek_01":          {"slot": "head",  "color": (232, 230, 224), "hat": "wrap", "accent": (117, 139, 170)},
    "torso_kamzol_01":           {"slot": "torso", "color": (156, 40, 54),   "robe": False, "cut": "fitted", "accent": (244, 194, 91)},
    "torso_koylek_01":           {"slot": "torso", "color": (46, 140, 80),   "robe": False, "cut": "dress", "accent": (243, 220, 142)},
    "torso_shapan_01":           {"slot": "torso", "color": (38, 66, 128),   "robe": True, "cut": "robe", "accent": (230, 184, 84)},
    "pants_shalbar_01":          {"slot": "pants", "color": (84, 64, 46), "accent": (149, 117, 71)},
    "pants_shalbar_decorated_01":{"slot": "pants", "color": (150, 40, 44), "accent": (238, 187, 83), "decorated": True},
    "shoes_kebis_01":            {"slot": "shoes", "color": (106, 82, 52), "accent": (225, 185, 99)},
    "shoes_masi_01":             {"slot": "shoes", "color": (128, 76, 40), "accent": (183, 115, 60)},
    "shoes_saptama_etik_01":     {"slot": "shoes", "color": (44, 44, 48), "accent": (174, 137, 75)},
}
SLOT_FOLDER = {"head": "head", "torso": "torso", "pants": "pants", "shoes": "shoes"}


def layout(direction, frame):
    """Крупный читаемый силуэт на сетке 16x16: бег даёт явный шаг, руки качаются."""
    phase = frame % 6
    stride = [0, 0, 1, 0, -1, 0][phase]
    bob = [0, 0, -1, 0, 0, -1][phase]
    arm = [0, 0, 1, 0, -1, 0][phase]

    head = (5, 1 + bob, 11, 6 + bob)
    hair = (5, 0 + bob, 11, 3 + bob)
    torso = (5, 6 + bob, 11, 12 + bob)
    arm_l = (3 - arm, 7 + abs(arm) + bob, 5 - arm, 12 + abs(arm) + bob)
    arm_r = (11 + arm, 7 + abs(arm) + bob, 13 + arm, 12 + abs(arm) + bob)
    leg_l = (6 + stride, 11, 8 + stride, 15)
    leg_r = (8 - stride, 11, 10 - stride, 15)
    foot_l = (5 + stride, 14, 8 + stride, 16)
    foot_r = (8 - stride, 14, 11 - stride, 16)

    if direction == "up":
        return dict(head=head, hair=(5, 0, 11, 4), torso=torso, arm_l=arm_l,
                    arm_r=arm_r, leg_l=leg_l, leg_r=leg_r, foot_l=foot_l, foot_r=foot_r)
    if direction == "left":
        return dict(head=(6, 1 + bob, 12, 6 + bob), hair=(6, 0 + bob, 12, 3 + bob), torso=(5, 6 + bob, 11, 12 + bob),
                    arm_l=(4 - arm, 7 + abs(arm) + bob, 6 - arm, 12 + abs(arm) + bob), arm_r=(10 + arm, 7 + abs(arm) + bob, 12 + arm, 12 + abs(arm) + bob),
                    leg_l=leg_l, leg_r=leg_r, foot_l=foot_l, foot_r=foot_r)
    return dict(head=head, hair=hair, torso=torso, arm_l=arm_l, arm_r=arm_r,
                leg_l=leg_l, leg_r=leg_r, foot_l=foot_l, foot_r=foot_r)


def outline_r(d, r, col):
    x0, y0, x1, y1 = r
    d.rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), fill=col)


def draw_part(d, r, color):
    outline_r(d, r, OUTLINE)
    d.rectangle(r, fill=color)


def draw_face(d, direction, layout_info, hair_style):
    """Лицо мальчика: глаза + улыбка. Строка глаз = 4, рот = 5 (лоб 3 открыт чёлкой)."""
    if direction == "down":
        for ex in (7, 9):
            d.point((ex, 4), fill=EYE)
        d.point((8, 5), fill=EYE)
        if hair_style == "fringe":
            d.point((9, 5), fill=EYE)
    elif direction == "left":
        d.point((8, 4), fill=EYE)
        for mx in (7, 8):
            d.point((mx, 5), fill=EYE)


def draw_hair(d, direction, L, hair, hair_style, skin):
    """Три силуэта волос делают персонажей различимыми без смены размера кадров."""
    r = L["hair"]
    draw_part(d, r, hair)
    x0, y0, x1, y1 = r
    if direction == "down":
        # чёлка по центру нижнего ряда волос + убрать линию волос под лицо
        d.rectangle((x0 + 1, y1, x1 - 1, y1 + 1), fill=skin)
        d.rectangle((x0 + 1, y1 + 1, x1 - 1, y1 + 2), fill=skin)
    elif direction == "left":
        d.rectangle((x0 + 1, y1, x0 + 3, y1 + 1), fill=skin)
        d.rectangle((x0 + 1, y1 + 1, x0 + 3, y1 + 2), fill=skin)
    if hair_style == "braid" and direction != "up":
        d.rectangle((x1 + 1, y0 + 2, x1 + 2, y1 + 3), fill=hair)
        d.point((x1 + 2, y1 + 4), fill=GOLD)
    elif hair_style == "fringe" and direction == "down":
        d.rectangle((x0 + 2, y1 - 1, x0 + 4, y1), fill=hair)


def body_frame(direction, frame, variant):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    L = layout(direction, frame)
    skin = variant["skin"]
    skin_dark = variant["skin_dark"]
    for key in ("foot_l", "foot_r"):
        draw_part(d, L[key], skin)
    for key in ("leg_l", "leg_r"):
        draw_part(d, L[key], skin)
    for key in ("arm_l", "arm_r"):
        draw_part(d, L[key], skin)
    draw_part(d, L["torso"], skin)
    # лёгкая тень внизу торса и по низу ног
    tx0, ty0, tx1, ty1 = L["torso"]
    d.rectangle((tx0 + 1, ty1 - 2, tx1 - 1, ty1), fill=skin_dark)
    for key in ("leg_l", "leg_r"):
        lx0, ly0, lx1, ly1 = L[key]
        d.rectangle((lx0 + 1, ly1 - 2, lx1 - 1, ly1), fill=skin_dark)
    draw_part(d, L["head"], skin)
    draw_hair(d, direction, L, variant["hair"], variant["hair_style"], skin)
    draw_face(d, direction, L, variant["hair_style"])
    return img


def garment_parts(item, direction, frame):
    """Возвращает (crown, extras): crown — шапка с открытым низом, extras — доп. части."""
    L = layout(direction, frame)
    slot = item["slot"]
    sway = [0, 0, 1, 0, -1, 0][frame % 6]
    if slot == "head":
        r = L["head"]
        hat = item.get("hat", "cap")
        hx0, hy0, hx1, hy1 = r
        crown = (hx0, hy0 - 1, hx1, hy0 + 2)
        extras = []
        if hat == "tall":
            crown = (hx0 - 1, hy0 - 1, hx1 + 1, hy0 + 2)
            extras = [(hx0 - 2 + sway, hy0 + 1, hx0 + sway, hy0 + 5),
                      (hx1 + sway, hy0 + 1, hx1 + 2 + sway, hy0 + 5)]
        elif hat == "flaps":
            extras = [(hx0 - 2 + sway, hy0 + 2, hx0 + sway, hy0 + 5),
                      (hx1 - sway, hy0 + 2, hx1 + 2 - sway, hy0 + 5)]
        elif hat == "wrap":
            extras = [(hx0 + sway, hy0 + 2, hx0 + 1 + sway, hy0 + 5),
                      (hx1 - 1 + sway, hy0 + 2, hx1 + sway, hy0 + 5)]
        return (crown, extras)
    if slot == "torso":
        parts = [L["torso"], L["arm_l"], L["arm_r"]]
        if item.get("cut") == "dress":
            parts.append((4 + sway, L["torso"][3] - 1, 12 + sway, 15))
        elif item.get("robe"):
            parts.append((4 + sway, L["torso"][1], 12 + sway, 15))
        return (None, parts)
    if slot == "pants":
        return (None, [L["leg_l"], L["leg_r"]])
    if slot == "shoes":
        return (None, [L["foot_l"], L["foot_r"]])
    return (None, [])


def draw_crown(d, r, color):
    """Шапка-тулья: заливка + контур сверху и по бокам (низ открыт, лицо видно)."""
    x0, y0, x1, y1 = r
    d.rectangle(r, fill=color)
    d.rectangle((x0 - 1, y0 - 1, x1 + 1, y0 - 1), fill=OUTLINE)
    d.rectangle((x0 - 1, y0 - 1, x0 - 1, y1), fill=OUTLINE)
    d.rectangle((x1 + 1, y0 - 1, x1 + 1, y1), fill=OUTLINE)


def draw_piece_outer(d, r, color, right_side):
    """Платок/борт: заливка + контур только по внешнему краю (к лицу — чисто)."""
    x0, y0, x1, y1 = r
    d.rectangle(r, fill=color)
    d.rectangle((x0 - 1, y0 - 1, x1 + 1, y0 - 1), fill=OUTLINE)
    d.rectangle((x0 - 1, y1 + 1, x1 + 1, y1 + 1), fill=OUTLINE)
    if right_side:
        d.rectangle((x1 + 1, y0 - 1, x1 + 1, y1 + 1), fill=OUTLINE)
    else:
        d.rectangle((x0 - 1, y0 - 1, x0 - 1, y1 + 1), fill=OUTLINE)


def draw_detail(d, rect, color):
    """Мелкие вышивки без тяжёлой чёрной рамки — читаются как пиксельный декор."""
    d.rectangle(rect, fill=color)


def draw_garment_details(d, item, direction, frame):
    L = layout(direction, frame)
    accent = item.get("accent", GOLD)
    if len(accent) == 3:
        accent = (*accent, 255)
    slot = item["slot"]
    sway = [0, 0, 1, 0, -1, 0][frame % 6]

    if slot == "head":
        hx0, hy0, hx1, _ = L["head"]
        hat = item.get("hat", "cap")
        draw_detail(d, (hx0, hy0 + 2, hx1, hy0 + 2), accent)
        if hat == "tall":
            draw_detail(d, (hx0 + 2, hy0 - 1, hx0 + 3, hy0), accent)
            draw_detail(d, (hx1 - 2, hy0 - 2, hx1 - 1, hy0 - 1), accent)
            # Перо на сәукеле колышется во время бега.
            draw_detail(d, (hx1 - 1 + sway, hy0 - 4, hx1 + sway, hy0 - 2), accent)
        elif hat == "cap":
            draw_detail(d, (hx0 + 2, hy0 + 1, hx0 + 3, hy0 + 1), accent)
        elif hat == "flaps":
            draw_detail(d, (hx0 - 1, hy0 + 3, hx0, hy0 + 4), accent)
            draw_detail(d, (hx1, hy0 + 3, hx1 + 1, hy0 + 4), accent)
        elif hat == "wrap":
            draw_detail(d, (hx0, hy0 + 1, hx0 + 1, hy0 + 4), accent)
        return

    if slot == "torso":
        tx0, ty0, tx1, ty1 = L["torso"]
        cut = item.get("cut", "fitted")
        # Пояс + центральная застёжка есть у всех торсов, но раскладка разная.
        draw_detail(d, (tx0, ty1 - 2, tx1, ty1 - 1), accent)
        if cut == "fitted":
            draw_detail(d, (tx0 + 3, ty0 + 1, tx0 + 3, ty1 - 3), accent)
            draw_detail(d, (tx0 + 1, ty0 + 2, tx0 + 1, ty0 + 3), accent)
            draw_detail(d, (tx1 - 1, ty0 + 2, tx1 - 1, ty0 + 3), accent)
        elif cut == "dress":
            draw_detail(d, (tx0 + 1, ty0 + 1, tx1 - 1, ty0 + 1), accent)
            for x in range(5, 12, 3):
                draw_detail(d, (x + sway, 13, x + 1 + sway, 14), accent)
        elif cut == "robe":
            draw_detail(d, (tx0 + 1, ty0, tx0 + 1, 14), accent)
            draw_detail(d, (tx1 - 1, ty0, tx1 - 1, 14), accent)
            draw_detail(d, (tx0 + 3, ty0 + 2, tx1 - 2, ty0 + 2), accent)
        return

    if slot == "pants":
        if item.get("decorated"):
            for leg in (L["leg_l"], L["leg_r"]):
                x0, y0, _, y1 = leg
                draw_detail(d, (x0 + 1, y0 + 1, x0 + 1, y1 - 1), accent)
        return

    if slot == "shoes":
        for foot in (L["foot_l"], L["foot_r"]):
            x0, y0, x1, _ = foot
            draw_detail(d, (x0 + 1, y0, x1, y0), accent)


def garment_frame(item, direction, frame):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    color = item["color"]
    if len(color) == 3:
        color = (color[0], color[1], color[2], 255)
    crown, extras = garment_parts(item, direction, frame)
    if crown:
        draw_crown(d, crown, color)
    if item.get("hat") == "wrap":
        for i, r in enumerate(extras):
            draw_piece_outer(d, r, color, right_side=(i == 1))
    else:
        for r in extras:
            draw_part(d, r, color)
    draw_garment_details(d, item, direction, frame)
    if item["slot"] == "torso":
        # не перекрывать лицо верхним контуром торса между плечами
        L = layout(direction, frame)
        top = L["torso"][1] - 1
        xa = L["arm_l"][2] + 1
        xb = L["arm_r"][0] - 1
        if xa <= xb:
            d.rectangle((xa, top, xb, top), fill=(0, 0, 0, 0))
    return img


def upscale(img):
    return img.resize((FRAME, FRAME), Image.NEAREST)


def build_sheet(frame_fn):
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME * len(DIRS)), (0, 0, 0, 0))
    for di, direction in enumerate(DIRS):
        for fi in range(FRAMES):
            # Правая сторона — именно зеркало левой боковой позы, не фронтальной.
            source_direction = "left" if direction == "right" else direction
            img = upscale(frame_fn(source_direction, fi))
            if direction == "right":
                img = img.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(img, (fi * FRAME, di * FRAME))
    return sheet


def gen_character():
    os.makedirs(CHAR, exist_ok=True)
    os.makedirs(os.path.join(CHAR, "base"), exist_ok=True)
    for s in SLOT_FOLDER.values():
        os.makedirs(os.path.join(CHAR, s), exist_ok=True)
    for variant in BASE_VARIANTS:
        base = build_sheet(lambda d, f, v=variant: body_frame(d, f, v))
        base.save(os.path.join(CHAR, "base", variant["file"]))
    for item_id, item in ITEMS.items():
        folder = SLOT_FOLDER[item["slot"]]
        sheet = build_sheet(lambda d, f, it=item: garment_frame(it, d, f))
        sheet.save(os.path.join(CHAR, folder, "%s.png" % item_id))
    os.makedirs(ITEMS_DIR, exist_ok=True)
    for item_id, item in ITEMS.items():
        g = garment_frame(item, "down", 0)
        preview = g.resize((128, 128), Image.NEAREST)
        preview.save(os.path.join(ITEMS_DIR, "%s.png" % item_id))
    # Шаблон остаётся базовым вариантом для ручной отрисовки поверх него.
    template = build_sheet(lambda d, f: body_frame(d, f, BASE_VARIANTS[0]))
    template.save(os.path.join(CHAR, "TEMPLATE.png"))


def seamless(kind):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if kind == "grass":
        base = (70, 124, 48, 255)
        img.paste(base, (0, 0, 128, 128))
        rnd = random.Random(7)
        for _ in range(500):
            x = rnd.randrange(0, 128); y = rnd.randrange(0, 128)
            v = rnd.randint(-28, 30)
            c = (70 + v, 124 + v, 48 + v, 255)
            for px in (x, x - 128):
                for py in (y, y - 128):
                    d.point((px % 128, py % 128), fill=c)
    else:
        base = (40, 102, 196, 255)
        img.paste(base, (0, 0, 128, 128))
        rnd = random.Random(13)
        for _ in range(120):
            x = rnd.randrange(0, 128); y = rnd.randrange(0, 128)
            r = rnd.randint(4, 14)
            v = rnd.randint(16, 46)
            c = (40 + v, 102 + v, 196 + v, 255)
            for cx in (x, x - 128):
                for cy in (y, y - 128):
                    d.ellipse((cx % 128 - r, cy % 128 - r, cx % 128 + r, cy % 128 + r), fill=c)
    return img


def water_blob():
    tex = seamless("water")
    mask = Image.new("L", (128, 128), 0)
    md = ImageDraw.Draw(mask)
    rnd = random.Random(5)
    cx = cy = 64
    # неровный многоугольник-облако
    pts = []
    n = 18
    for i in range(n):
        a = math.tau * i / n
        rad = rnd.uniform(40, 56)
        pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    md.polygon(pts, fill=255)
    # мягкие края
    for _ in range(3):
        mask = mask.filter(__import__("PIL.ImageFilter", fromlist=["ImageFilter"]).GaussianBlur(3))
    out = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    out.paste(tex, (0, 0), mask)
    return out


def gen_tiles():
    seamless("grass").save(os.path.join(TILES, "ground.png"))
    seamless("water").save(os.path.join(TILES, "water_seamless.png"))
    water_blob().save(os.path.join(TILES, "water_blob.png"))


if __name__ == "__main__":
    gen_character()
    if "--characters-only" not in sys.argv:
        gen_tiles()
    print("CHARACTERS DONE" if "--characters-only" in sys.argv else "ALL DONE")
