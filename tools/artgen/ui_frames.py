"""Пиксельные рамки интерфейса: кнопки, панели, карточки, поля, переключатели.

Все рамки — 9-slice по образцу кнопок и карточек atilla: тёмный контур,
золотое кольцо с бликом сверху и тенью снизу, тёмная линия и заливка со
скосом. Углы срезаны ступенькой. Текста на картинках нет — подписи кладёт
интерфейс, чтобы они переводились.

Отступы 9-slice (в пикселях базового разрешения) пишутся в frames.json — их
читает tools/build_theme.gd, так что числа не дублируются.
"""
import json
import os

from palette import PIXEL, ROOT, TRANSPARENT, color as c
from pixel import Canvas, save

OUT_DIR = os.path.join(ROOT, "assets", "ui", "frames")

# Слой рамки: (верх, бока, низ). Скос у верхних углов считается верхом.
O = c("OUTLINE")
OUTLINE_LAYER = (O, O, O)
GOLD_OUTER = (c("GOLD_LIGHT"), c("GOLD"), c("GOLD"))
GOLD_INNER = (c("GOLD"), c("GOLD"), c("GOLD_DARK"))


def bevel(top, side, bottom):
    return (c(top), c(side), c(bottom))


def chamfer_frame(layers, fill, chamfer, center=2, size=None):
    """Рамка из слоёв снаружи внутрь со срезанными на `chamfer` углами.

    Возвращает (холст, отступ 9-slice в пикселях арта). Отступ покрывает и
    слои, и скос угла; середина в `center` пикселей тянется. `size` —
    (ширина, высота) для рамок фиксированного размера.
    """
    margin = len(layers) + chamfer
    width, height = size or (2 * margin + center,) * 2
    canvas = Canvas(width, height)
    last_x, last_y = width - 1, height - 1
    for y in range(height):
        for x in range(width):
            # Расстояние до края в «слоях»; для угла — до диагонали скоса.
            sides = {"top": y, "left": x, "bottom": last_y - y, "right": last_x - x}
            diagonals = {
                "top": min(x + y, last_x - x + y) - chamfer,
                "bottom": min(x + last_y - y, last_x - x + last_y - y) - chamfer,
            }
            edge, depth = min({**sides, **diagonals}.items(), key=lambda kv: kv[1])
            if depth < 0:
                continue
            if depth >= len(layers):
                canvas.put(x, y, fill)
                continue
            top, side, bottom = layers[depth]
            canvas.put(x, y, {"top": top, "bottom": bottom}.get(edge, side))
    return canvas, margin


def button(fill, fill_light, fill_dark, gold_outer=GOLD_OUTER, gold_inner=GOLD_INNER):
    layers = [OUTLINE_LAYER, gold_outer, gold_inner, OUTLINE_LAYER,
              (c(fill_light), c(fill), c(fill_dark))]
    return chamfer_frame(layers, c(fill), chamfer=2)


def panel(fill, fill_light, fill_dark, gold_outer=GOLD_OUTER, gold_inner=GOLD_INNER, chamfer=4):
    layers = [OUTLINE_LAYER, gold_outer, gold_inner, OUTLINE_LAYER,
              (c(fill_light), c(fill), c(fill_dark))]
    return chamfer_frame(layers, c(fill), chamfer=chamfer)


def frames():
    """Имя -> (холст, отступ 9-slice в пикселях арта)."""
    pressed_gold = (bevel("GOLD_DARK", "GOLD", "GOLD"), bevel("GOLD", "GOLD", "GOLD"))
    hover_gold = (bevel("GOLD_LIGHT", "GOLD_LIGHT", "GOLD"), bevel("GOLD_LIGHT", "GOLD", "GOLD"))
    muted_gold = (bevel("MUTED", "MUTED", "GOLD_DARK"), bevel("GOLD_DARK", "GOLD_DARK", "GOLD_DARK"))
    focus_layers = [bevel("CREAM", "CREAM", "CREAM")] + [(TRANSPARENT,) * 3] * 4
    return {
        # Основная кнопка: бордо на золоте.
        "button_normal": button("BURGUNDY", "BURGUNDY_LIGHT", "BURGUNDY_DARK"),
        "button_hover": button("BURGUNDY_LIGHT", "BURGUNDY_LIGHT", "BURGUNDY", *hover_gold),
        # Нажатая: скос перевёрнут, свет снизу — кнопка «утоплена».
        "button_pressed": button("BURGUNDY_DARK", "OUTLINE", "BURGUNDY", *pressed_gold),
        "button_disabled": button("INK_SOFT", "INK_SOFT", "INK", *muted_gold),
        # Второстепенная: «чернила» на золоте.
        "button_secondary_normal": button("INK_SOFT", "INK_SOFT", "INK"),
        "button_secondary_hover": button("BURGUNDY_DARK", "BURGUNDY", "INK", *hover_gold),
        "button_secondary_pressed": button("INK", "OUTLINE", "INK_SOFT", *pressed_gold),
        # Кольцо фокуса рисуется поверх кнопки на месте контура.
        "button_focus": chamfer_frame(focus_layers, TRANSPARENT, chamfer=2),
        # Панели.
        "panel_burgundy": panel("BURGUNDY_DARK", "BURGUNDY", "OUTLINE"),
        "panel_parchment": panel("PARCHMENT", "PARCHMENT", "PARCHMENT_DARK",
                                 bevel("GOLD", "GOLD_DARK", "GOLD_DARK"), bevel("GOLD_DARK", "GOLD_DARK", "GOLD_DARK")),
        # Плашка HUD: тоньше и спокойнее, чтобы не спорить с картой.
        "panel_hud": chamfer_frame([OUTLINE_LAYER, bevel("GOLD", "GOLD_DARK", "GOLD_DARK"),
                                    bevel("INK_SOFT", "INK", "INK")], c("INK"), chamfer=1),
        # Карточки (режимы, энциклопедия, шкаф).
        "card": panel("BURGUNDY_DARK", "BURGUNDY", "OUTLINE", chamfer=3),
        "card_hover": panel("BURGUNDY", "BURGUNDY_LIGHT", "BURGUNDY_DARK", *hover_gold, chamfer=3),
        "card_selected": panel("BURGUNDY_LIGHT", "EMBER", "BURGUNDY", *hover_gold, chamfer=3),
        # Утопленное поле: ввод текста, дорожка слайдера.
        "inset": chamfer_frame([OUTLINE_LAYER, bevel("OUTLINE", "INK", "INK_SOFT")], c("INK"), chamfer=1),
        # Заполненная часть слайдера.
        "slider_fill": chamfer_frame([OUTLINE_LAYER, bevel("GOLD_LIGHT", "GOLD", "GOLD_DARK")], c("GOLD"), chamfer=1),
    }


def diamond(radius, layers, fill, center=None):
    """Ромб с кольцами по манхэттенскому расстоянию от центра: layers[0] — внешнее."""
    size = 2 * radius + 1
    canvas = Canvas(size, size)
    for y in range(size):
        for x in range(size):
            d = radius - (abs(x - radius) + abs(y - radius))
            if d < 0:
                continue
            if d < len(layers):
                top, bottom = layers[d]
                canvas.put(x, y, top if y <= radius else bottom)
            else:
                canvas.put(x, y, fill)
    if center:
        canvas.put(radius, radius, center)
    return canvas


def ornament_cap():
    """Навершие кнопки — ромб с перемычкой к рамке, как по бокам кнопок atilla.
    Левое; правое — зеркальное."""
    gem = diamond(6, [(O, O), (c("GOLD_LIGHT"), c("GOLD_DARK")), (c("GOLD"), c("GOLD")), (O, O)],
                  c("BURGUNDY"), center=c("GOLD_LIGHT"))
    canvas = Canvas(gem.width + 4, gem.height)
    canvas.image.paste(gem.image, (0, 0))
    mid = gem.height // 2
    canvas.rect(gem.width - 1, mid - 2, canvas.width - 1, mid + 2, O)
    canvas.rect(gem.width - 2, mid - 1, canvas.width - 1, mid - 1, c("GOLD_LIGHT"))
    canvas.rect(gem.width - 2, mid, canvas.width - 1, mid, c("GOLD"))
    canvas.rect(gem.width - 2, mid + 1, canvas.width - 1, mid + 1, c("GOLD_DARK"))
    return canvas


def toggle(on):
    """Переключатель 22×12: утопленная дорожка и ручка; включённый — золото справа."""
    canvas, _ = chamfer_frame([OUTLINE_LAYER, bevel("OUTLINE", "INK", "INK_SOFT")],
                              c("GOLD_DARK") if on else c("INK"), chamfer=1, size=(22, 12))
    knob_bevel = bevel("GOLD_LIGHT", "GOLD", "GOLD_DARK") if on else bevel("CREAM", "MUTED", "GOLD_DARK")
    knob, _ = chamfer_frame([OUTLINE_LAYER, knob_bevel], knob_bevel[1], chamfer=1, size=(8, 8))
    canvas.image.paste(knob.image, (12 if on else 2, 2), knob.image)
    return canvas


def disc(radius):
    """Круглая подложка обратного отсчёта: контур, золотое кольцо, «чернила»."""
    size = 2 * radius
    canvas = Canvas(size, size)
    center = radius - 0.5
    rings = [(O, O), (c("GOLD_LIGHT"), c("GOLD_DARK")), (c("GOLD"), c("GOLD")), (O, O)]
    for y in range(size):
        for x in range(size):
            depth = int(radius - ((x - center) ** 2 + (y - center) ** 2) ** 0.5)
            if depth < 0:
                continue
            if depth < len(rings):
                top, bottom = rings[depth]
                canvas.put(x, y, top if y < radius else bottom)
            else:
                canvas.put(x, y, c("INK"))
    return canvas


# В пиксельных шрифтах нет ✓ и ✗ — интерфейс показывает их иконками.
CHECK = [
    "........OO",
    ".......OGO",
    "......OGO.",
    "O....OGO..",
    "OGO.OGO...",
    ".OGOGO....",
    "..OGO.....",
    "...O......",
]
CROSS = [
    "OO....OO",
    "OGO..OGO",
    ".OGOOGO.",
    "..OGGO..",
    "..OGGO..",
    ".OGOOGO.",
    "OGO..OGO",
    "OO....OO",
]


def glyph(pattern, fill):
    canvas = Canvas(len(pattern[0]), len(pattern))
    canvas.stamp(pattern, 0, 0, {"O": O, "G": c(fill)})
    return canvas


def icons():
    return {
        "check": glyph(CHECK, "SUCCESS"),
        "cross": glyph(CROSS, "DANGER"),
        "countdown_disc": disc(40),
        "cap_left": ornament_cap(),
        "cap_right": ornament_cap().mirrored(),
        "toggle_on": toggle(True),
        "toggle_off": toggle(False),
        "grabber": diamond(5, [(O, O), (c("GOLD_LIGHT"), c("GOLD_DARK"))], c("GOLD")),
        "grabber_highlight": diamond(5, [(O, O), (c("CREAM"), c("GOLD"))], c("GOLD_LIGHT")),
        "divider_gem": diamond(4, [(O, O), (c("GOLD_LIGHT"), c("GOLD_DARK"))], c("GOLD"), center=c("BURGUNDY")),
    }


def build():
    written, manifest = [], {}
    for name, (canvas, margin) in frames().items():
        written.append(save(canvas, os.path.join(OUT_DIR, name + ".png")))
        manifest[name] = {"margin": margin * PIXEL}
    for name, canvas in icons().items():
        written.append(save(canvas, os.path.join(OUT_DIR, name + ".png")))
    manifest_path = os.path.join(OUT_DIR, "frames.json")
    with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")
    return written + [manifest_path]
