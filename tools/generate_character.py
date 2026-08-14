#!/usr/bin/env python3
"""Генератор ассетов персонажа для Соқыртеке.
Тело: 4 направления x 6 кадров (idle0,1 / walk0..3). Право = зеркало левого.
Одежда по слотам + превью предметов + бесшовные трава/вода + блоб воды + шаблон.
Логическая сетка 16x16 -> x4 = 64x64 кадр. Лист = 4 строки x 6 колонок.
"""
import math, os, random
from PIL import Image, ImageDraw

ROOT = "/home/aibek/godot/sokyroteke"
CHAR = os.path.join(ROOT, "assets/character")
ITEMS_DIR = os.path.join(ROOT, "assets/items")
TILES = os.path.join(ROOT, "assets/tiles")

SIZE = 16
SCALE = 4
FRAME = SIZE * SCALE
DIRS = ["down", "up", "left", "right"]
FRAMES = 6

OUTLINE = (22, 20, 17, 255)
SKIN = (242, 214, 173, 255)
HAIR = (108, 74, 40, 255)
EYE = (28, 24, 20, 255)

ITEMS = {
    "head_borik_01":             {"slot": "head",  "color": (63, 51, 25),  "hat": "band"},
    "head_takiya_01":            {"slot": "head",  "color": (153, 38, 38), "hat": "cap"},
    "head_saukele_01":           {"slot": "head",  "color": (230, 38, 51), "hat": "tall"},
    "head_tymaq_01":             {"slot": "head",  "color": (128, 89, 51), "hat": "flaps"},
    "head_kimeshek_01":          {"slot": "head",  "color": (232, 230, 224, 255), "hat": "wrap"},
    "torso_kamzol_01":           {"slot": "torso", "color": (179, 26, 26), "robe": False},
    "torso_koylek_01":           {"slot": "torso", "color": (51, 153, 77), "robe": False},
    "torso_shapan_01":           {"slot": "torso", "color": (38, 77, 140), "robe": True},
    "pants_shalbar_01":          {"slot": "pants", "color": (64, 51, 38)},
    "pants_shalbar_decorated_01":{"slot": "pants", "color": (140, 26, 26)},
    "shoes_kebis_01":            {"slot": "shoes", "color": (77, 64, 38)},
    "shoes_masi_01":             {"slot": "shoes", "color": (77, 38, 13)},
    "shoes_saptama_etik_01":     {"slot": "shoes", "color": (26, 26, 26)},
}
SLOT_FOLDER = {"head": "head", "torso": "torso", "pants": "pants", "shoes": "shoes"}


def layout(direction, frame):
    """Прямоугольники частей тела на 16x16. Ноги/руки двигаются по кадрам."""
    leg = {0: (0, 1), 1: (0, 0), 2: (1, 0), 3: (0, 0), 4: (0, 1), 5: (0, 0)}[frame % 6]
    arm = {0: (0, 0), 1: (0, 0), 2: (0, 1), 3: (0, 0), 4: (0, 0), 5: (0, 0)}[frame % 6]
    ldx, ldy = leg
    adx, ady = arm

    head = (5, 1, 11, 6)
    hair = (5, 0, 11, 3)
    torso = (5, 6, 11, 12)
    arm_l = (3 + adx, 7 + ady, 5 + adx, 12 + ady)
    arm_r = (11 + adx, 7 + ady, 13 + adx, 12 + ady)
    leg_l = (6 + ldx, 11 + ldy, 8 + ldx, 16)
    leg_r = (8 - ldx, 11 + ldy, 10 - ldx, 16)
    foot_l = (5 + ldx, 15, 8 + ldx, 16)
    foot_r = (8 - ldx, 15, 11 - ldx, 16)

    if direction == "up":
        return dict(head=head, hair=(5, 0, 11, 4), torso=torso, arm_l=arm_l,
                    arm_r=arm_r, leg_l=leg_l, leg_r=leg_r, foot_l=foot_l, foot_r=foot_r)
    if direction == "left":
        return dict(head=(6, 1, 12, 6), hair=(6, 0, 12, 3), torso=(5, 6, 11, 12),
                    arm_l=(4 + adx, 7 + ady, 6 + adx, 12 + ady), arm_r=(10, 7, 12, 12),
                    leg_l=leg_l, leg_r=leg_r, foot_l=foot_l, foot_r=foot_r)
    return dict(head=head, hair=hair, torso=torso, arm_l=arm_l, arm_r=arm_r,
                leg_l=leg_l, leg_r=leg_r, foot_l=foot_l, foot_r=foot_r)


def outline_r(d, r, col):
    x0, y0, x1, y1 = r
    d.rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), fill=col)


def draw_part(d, r, color):
    outline_r(d, r, OUTLINE)
    d.rectangle(r, fill=color)


def draw_face(d, direction, layout_info):
    if direction == "down":
        for ex in (6, 9):
            d.point((ex, 3), fill=EYE)
        for mx, my in ((6, 4), (7, 5), (8, 5), (9, 4)):
            d.point((mx, my), fill=EYE)
    elif direction == "left":
        d.point((8, 3), fill=EYE)
        d.point((8, 4), fill=EYE)


def body_frame(direction, frame):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    L = layout(direction, frame)
    for key in ("foot_l", "foot_r"):
        draw_part(d, L[key], SKIN)
    for key in ("leg_l", "leg_r"):
        draw_part(d, L[key], SKIN)
    for key in ("arm_l", "arm_r"):
        draw_part(d, L[key], SKIN)
    draw_part(d, L["torso"], SKIN)
    draw_part(d, L["head"], SKIN)
    outline_r(d, L["hair"], HAIR)
    d.rectangle(L["hair"], fill=HAIR)
    draw_face(d, direction, L)
    return img


def garment_parts(item, direction, frame):
    L = layout(direction, frame)
    slot = item["slot"]
    if slot == "head":
        r = L["head"]
        hat = item.get("hat", "cap")
        if hat == "band":
            return [r, (5, 0, 11, 3)]
        if hat == "tall":
            return [r, (4, 0, 12, 3)]
        if hat == "flaps":
            return [r, (3, 2, 5, 6), (11, 2, 13, 6)]
        if hat == "wrap":
            return [r, (5, 0, 11, 3)]
        return [r]
    if slot == "torso":
        parts = [L["torso"], L["arm_l"], L["arm_r"]]
        if item.get("robe"):
            parts.append((5, 6, 11, 15))
        return parts
    if slot == "pants":
        return [L["leg_l"], L["leg_r"]]
    if slot == "shoes":
        return [L["foot_l"], L["foot_r"]]
    return []


def garment_frame(item, direction, frame):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    color = item["color"]
    if len(color) == 3:
        color = (color[0], color[1], color[2], 255)
    for r in garment_parts(item, direction, frame):
        draw_part(d, r, color)
    return img


def upscale(img):
    return img.resize((FRAME, FRAME), Image.NEAREST)


def build_sheet(frame_fn):
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME * len(DIRS)), (0, 0, 0, 0))
    for di, direction in enumerate(DIRS):
        for fi in range(FRAMES):
            img = upscale(frame_fn(direction, fi))
            if direction == "right":
                img = img.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(img, (fi * FRAME, di * FRAME))
    return sheet


def gen_character():
    os.makedirs(CHAR, exist_ok=True)
    os.makedirs(os.path.join(CHAR, "base"), exist_ok=True)
    for s in SLOT_FOLDER.values():
        os.makedirs(os.path.join(CHAR, s), exist_ok=True)
    base = build_sheet(lambda d, f: body_frame(d, f))
    base.save(os.path.join(CHAR, "base", "base.png"))
    for item_id, item in ITEMS.items():
        folder = SLOT_FOLDER[item["slot"]]
        sheet = build_sheet(lambda d, f, it=item: garment_frame(it, d, f))
        sheet.save(os.path.join(CHAR, folder, "%s.png" % item_id))
    os.makedirs(ITEMS_DIR, exist_ok=True)
    for item_id, item in ITEMS.items():
        g = garment_frame(item, "down", 0)
        preview = g.resize((128, 128), Image.NEAREST)
        preview.save(os.path.join(ITEMS_DIR, "%s.png" % item_id))
    base.save(os.path.join(CHAR, "TEMPLATE.png"))


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


gen_character()
gen_tiles()
print("ALL DONE")
