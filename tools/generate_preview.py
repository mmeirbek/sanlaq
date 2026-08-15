#!/usr/bin/env python3
"""Сборка превью-листа комплектов для ревью: слоты + полные костюмы.
Переиспользует генератор ассетов (ручной запуск после generate_character.py).
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_character as G

OUT = os.path.join(G.ROOT, "tools/preview/outfit_grid.png")

CREAM = (247, 241, 227, 255)
BORDER = (206, 190, 158, 255)
INK = (22, 20, 17, 255)
GOLD = (234, 194, 91, 255)

CELL = 240
LABEL = 34
PAD = 40
FONT_SM = 22
FONT_H = 30

def font(size):
    return ImageFont.truetype(os.path.join(G.ROOT, "assets/fonts/NotoSans-Bold.ttf"), size)

def tile(item_ids, direction="down", frame=0):
    img = G.body_frame(direction, frame)
    for iid in item_ids:
        img = Image.alpha_composite(img, G.garment_frame(G.ITEMS[iid], direction, frame))
    return img.resize((192, 192), Image.NEAREST)

def cent_text(d, cx, cy, text, f, fill=INK):
    w = d.textlength(text, font=f)
    d.text((cx - w / 2, cy), text, font=f, fill=fill)

def draw_header(d, cx, y, text):
    f = font(FONT_H)
    tw = d.textlength(text, font=f)
    d.rectangle((cx - tw / 2 - 14, y - 8, cx + tw / 2 + 14, y + 30), fill=BORDER)
    cent_text(d, cx, y, text, f, fill=INK)

def draw_cell(sheet, d, cx, cy, img, label):
    img = img.resize((192, 192), Image.NEAREST)
    x0, y0, x1, y1 = cx - CELL // 2, cy - 10, cx + CELL // 2, cy + 180
    d.rounded_rectangle((x0, y0, x1, y1), radius=12, fill=(255, 255, 255, 255), outline=BORDER, width=2)
    d.rectangle((x0, y0, x1, y0 + 1), fill=GOLD)
    sheet.paste(img, (cx - 96, y0 + 10), img)
    f = font(FONT_SM)
    tw = d.textlength(label, font=f)
    d.text((cx - tw / 2, y1 - 30), label, font=f, fill=INK)

SLOTS = [
    ("Бас киімдер · уборы", [
        ("Бөрік", ["head_borik_01"]),
        ("Тақия", ["head_takiya_01"]),
        ("Сәукеле", ["head_saukele_01"]),
        ("Тымақ", ["head_tymaq_01"]),
        ("Кимешек", ["head_kimeshek_01"]),
    ]),
    ("Камзол · көйлек · шапан", [
        ("Камзол", ["torso_kamzol_01"]),
        ("Көйлек", ["torso_koylek_01"]),
        ("Шапан", ["torso_shapan_01"]),
    ]),
    ("Шалбар", [
        ("Шалбар", ["pants_shalbar_01"]),
        ("Оюлы шалбар", ["pants_shalbar_decorated_01"]),
    ]),
    ("Кебіс · мәсі · етік", [
        ("Кебіс", ["shoes_kebis_01"]),
        ("Мәсі", ["shoes_masi_01"]),
        ("Саптама етік", ["shoes_saptama_etik_01"]),
    ]),
]

OUTFITS = [
    ("Праздничный · Бөрік + камзол + мәсі", ["head_borik_01", "torso_kamzol_01", "pants_shalbar_decorated_01", "shoes_masi_01"]),
    ("Повседневный · Тақия + көйлек + кебіс", ["head_takiya_01", "torso_koylek_01", "pants_shalbar_01", "shoes_kebis_01"]),
    ("Зимний · Тымақ + шапан + саптама", ["head_tymaq_01", "torso_shapan_01", "pants_shalbar_01", "shoes_saptama_etik_01"]),
    ("Нарядный · Сәукеле + шапан + мәсі", ["head_saukele_01", "torso_shapan_01", "pants_shalbar_decorated_01", "shoes_masi_01"]),
    ("Домашний · Кимешек + көйлек + кебіс", ["head_kimeshek_01", "torso_koylek_01", "pants_shalbar_01", "shoes_kebis_01"]),
    ("Дорожный · Бөрік + шапан + саптама", ["head_borik_01", "torso_shapan_01", "pants_shalbar_01", "shoes_saptama_etik_01"]),
]

MAX_COLS = 5
width = PAD * 2 + MAX_COLS * CELL

rows = 1
for _, items in SLOTS:
    rows += 1 + (len(items) + MAX_COLS - 1) // MAX_COLS
rows += 2 * (1 + (len(OUTFITS) + 2) // 3)
height = PAD * 2 + rows * CELL

sheet = Image.new("RGBA", (width, height), CREAM)
d = ImageDraw.Draw(sheet)

y_cursor = PAD
for title, items in SLOTS:
    draw_header(d, width / 2, y_cursor, title)
    y_cursor += 72
    for i, (label, ids) in enumerate(items):
        col = i % MAX_COLS
        if i and col == 0:
            y_cursor += CELL
        cx = PAD + col * CELL + CELL // 2
        draw_cell(sheet, d, cx, y_cursor, tile(ids), label)
    y_cursor += CELL

draw_header(d, width / 2, y_cursor, "Комплекты · толық киімдер")
y_cursor += 72
for i, (label, ids) in enumerate(OUTFITS):
    col = i % 3
    if i and col == 0:
        y_cursor += CELL
    cx = PAD + col * CELL + CELL // 2
    draw_cell(sheet, d, cx, y_cursor, tile(ids, "down", 0), label)
y_cursor += CELL

draw_header(d, width / 2, y_cursor, "Комплекты · вид сбоку")
y_cursor += 72
for i, (label, ids) in enumerate(OUTFITS):
    col = i % 3
    if i and col == 0:
        y_cursor += CELL
    cx = PAD + col * CELL + CELL // 2
    draw_cell(sheet, d, cx, y_cursor, tile(ids, "left", 0), label)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
px = sheet.load()
x0, y0, x1, y1 = width, height, 0, 0
for yy in range(height):
    for xx in range(width):
        if px[xx, yy] != CREAM:
            x0 = min(x0, xx); y0 = min(y0, yy)
            x1 = max(x1, xx); y1 = max(y1, yy)
sheet = sheet.crop((max(0, x0 - PAD // 2), max(0, y0 - PAD // 2),
                     min(width, x1 + PAD // 2), min(height, y1 + PAD // 2)))
sheet.save(OUT)
print("PREVIEW GRID:", OUT, "%dx%d" % sheet.size)