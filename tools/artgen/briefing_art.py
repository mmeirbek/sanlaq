"""Схемы шагов для экранов-объяснений: по 4 на режим, 96×48 пикселей арта, без
текста внутри. Сохраняются ×2 в assets/sprites/briefing/<mode_id>_<n>.png, где n —
номер шага с единицы. Собираются из готового арта (персонажи, иконки, қазан,
следы ақ сүйек) — схема выглядит как сама игра.
"""
import os

from PIL import Image

import mode_art
from item_icons import ellipse, ramp
from palette import PIXEL, ROOT, color as c
from pixel import Canvas, fill, paint, rows, save

OUT_DIR = os.path.join(ROOT, "assets", "sprites", "briefing")
W, H = 96, 48
SPRITES = os.path.join(ROOT, "assets", "sprites")


# --- Общие детали ------------------------------------------------------------

def art(path):
    """Готовый спрайт в пикселях арта: файлы сохранены ×PIXEL без сглаживания."""
    image = Image.open(os.path.join(ROOT, path)).convert("RGBA")
    return image.resize((image.width // PIXEL, image.height // PIXEL), Image.Resampling.NEAREST)


def icon(path, size=16):
    """Иконка 32×32, уменьшенная до size: на схеме нужна лишь узнаваемость."""
    return art(path).resize((size, size), Image.Resampling.NEAREST)


def put(canvas, image, x, y):
    canvas.image.alpha_composite(image, (x, y))


def frame(base="ink"):
    """Тёмная подложка с кромкой — схема читается и на бордо, и на пергаменте."""
    canvas = Canvas(W, H, c(base))
    canvas.ring(0, c("gold_dark"), c("gold_dark"), c("outline"), c("outline"))
    return canvas


def grass(canvas):
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            canvas.put(x, y, c("grass_mid") if (x * 7 + y * 3) % 11 else c("grass"))


def arrow(canvas, x0, y0, x1, y1, color_name="gold_light"):
    """Стрелка ступеньками от (x0, y0) к (x1, y1) с наконечником-уголком."""
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        canvas.put(round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps), c(color_name))
    dx = (x1 > x0) - (x1 < x0)
    dy = (y1 > y0) - (y1 < y0)
    for k in (1, 2):
        canvas.put(x1 - dx * k - dy * k, y1 - dy * k + dx * k, c(color_name))
        canvas.put(x1 - dx * k + dy * k, y1 - dy * k - dx * k, c(color_name))


def check(canvas, x, y):
    put(canvas, art("assets/ui/frames/check.png"), x, y)


def cross(canvas, x, y):
    put(canvas, art("assets/ui/frames/cross.png"), x, y)


def silhouette(image, color_name):
    """Тот же спрайт одним цветом — «кто-то там есть, но не видно, кто»."""
    out = Image.new("RGBA", image.size)
    for y in range(image.height):
        for x in range(image.width):
            if image.getpixel((x, y))[3]:
                out.putpixel((x, y), c(color_name))
    return out


def figure(body="base", items=("shoes_kebis_01", "pants_shalbar_01", "torso_koylek_01"), direction="down"):
    return mode_art._character(body, list(items), direction, 0)


KID = ("base_02", ("shoes_masi_01", "pants_shalbar_decorated_01", "torso_kamzol_01", "head_takiya_01"))
ELDER = ("base", ("shoes_saptama_etik_01", "pants_shalbar_01", "torso_shapan_01", "head_tymaq_01"))
GIRL = ("base_03", ("shoes_kebis_01", "pants_shalbar_01", "torso_koylek_01", "head_kimeshek_01"))


def card(canvas, x, y, w, h, lit=False):
    fill(canvas, rows({yy: (x, x + w - 1) for yy in range(y, y + h)}),
         c("burgundy_light") if lit else c("burgundy_dark"))
    border = c("gold_light") if lit else c("gold_dark")
    fill(canvas, rows({y: (x, x + w - 1), y + h - 1: (x, x + w - 1)}), border)
    fill(canvas, {(x, yy) for yy in range(y, y + h)} | {(x + w - 1, yy) for yy in range(y, y + h)}, border)


def bar(canvas, x, y, w, lit=False):
    """Строка ответа в квизе."""
    card(canvas, x, y, w, 6, lit)


# --- Тоғыз құмалақ -----------------------------------------------------------

def mini_pit(canvas, x, y, stones, ring=None, tuzdyk=False):
    """Лунка 9×11 и до 9 камешков сеткой 3×3; ring — цвет кольца вокруг."""
    hole = ellipse(x + 4.5, y + 5.5, 4.5, 5.5)
    fill(canvas, hole, c("burgundy") if tuzdyk else c("leather_dark"))
    if ring:
        for px, py in hole:
            if any((nx, ny) not in hole for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1))):
                canvas.put(px, py, c(ring))
    if tuzdyk:
        fill(canvas, {(x + 4, y + 4), (x + 3, y + 5), (x + 5, y + 5), (x + 4, y + 6)}, c("gold_light"))
        return
    for i in range(min(stones, 9)):
        canvas.put(x + 2 + (i % 3) * 2, y + 7 - (i // 3) * 2, c("parchment"))


def wood(canvas):
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            canvas.put(x, y, c("wood_dark") if y % 6 == 0 and (x + y) % 9 else c("wood"))


def togyz_sowing():
    """Из выбранной лунки камни идут по одному в следующие против часовой."""
    canvas = frame()
    wood(canvas)
    for i in range(9):
        mini_pit(canvas, 3 + i * 10, 4, 9)
    for i in range(9):
        stones = 1 if i == 0 else 10 if i <= 4 else 9
        mini_pit(canvas, 3 + i * 10, 22, stones, ring="gold_light" if i == 0 else "parchment" if i <= 4 else None)
    arrow(canvas, 7, 40, 47, 40)
    return canvas


def togyz_capture(tuzdyk):
    """Последний камень лёг к сопернику: чёт — взятие, ровно три — тұздық."""
    canvas = frame()
    wood(canvas)
    for i in range(3):
        if i == 2:
            mini_pit(canvas, 6 + i * 14, 6, 3 if tuzdyk else 4, ring="gold_light", tuzdyk=tuzdyk)
        else:
            mini_pit(canvas, 6 + i * 14, 6, 9)
        mini_pit(canvas, 6 + i * 14, 28, 9)
    put(canvas, art("assets/sprites/togyz/kazan.png"), 60, 14)
    arrow(canvas, 45, 11, 58, 20)
    return canvas


def togyz_win():
    """Полный қазан побеждает почти полный: побеждает тот, кто первым набрал."""
    canvas = frame()
    wood(canvas)
    kazan = art("assets/sprites/togyz/kazan.png")
    put(canvas, kazan, 12, 16)
    put(canvas, silhouette(kazan, "wood_dark"), 54, 18)
    check(canvas, 23, 4)
    return canvas


# --- Абай айтады -------------------------------------------------------------

FOODS = ["baursak", "qymyz", "kurt", "qazy", "shubat", "irimshik"]


def food_grid(canvas, lit, x0=34):
    for i, food in enumerate(FOODS):
        x, y = x0 + (i % 3) * 20, 4 + (i // 3) * 20
        card(canvas, x, y, 19, 19, lit=i == lit)
        put(canvas, icon(f"assets/sprites/food/{food}.png"), x + 2, y + 2)


def abai_show():
    """Абай по очереди подсвечивает карточки — запоминай порядок."""
    canvas = frame()
    put(canvas, figure(ELDER[0], ELDER[1]), 0, 10)
    food_grid(canvas, lit=1)
    for x, y in ((53, 2), (73, 2), (53, 24), (73, 24)):
        canvas.put(x, y, c("sun"))
    return canvas


def abai_repeat():
    """Игрок нажимает те же карточки в том же порядке."""
    canvas = frame()
    put(canvas, figure(KID[0], KID[1]), 0, 10)
    food_grid(canvas, lit=4)
    check(canvas, 26, 6)
    return canvas


def abai_growth():
    """Каждый раунд тізбек длиннее на одну карточку."""
    canvas = frame()
    for row in range(3):
        y = 4 + row * 14
        for k in range(row + 2):
            x = 14 + k * 16
            card(canvas, x, y, 13, 13)
            put(canvas, icon(f"assets/sprites/food/{FOODS[(row + k) % 6]}.png", 10), x + 2, y + 2)
        arrow(canvas, 8, y + 6, 11, y + 6, "gold")
    return canvas


def abai_turns():
    """Устройство идёт по кругу, ошибившийся выбывает."""
    canvas = frame()
    people = [KID, GIRL, ELDER]
    for i, (body, items) in enumerate(people):
        sprite = figure(body, items)
        put(canvas, sprite if i < 2 else silhouette(sprite, "ink_soft"), 4 + i * 32, 8)
    fill(canvas, rows({41: (12, 26)}), c("gold_light"))
    arrow(canvas, 30, 24, 36, 24)
    arrow(canvas, 62, 24, 68, 24)
    cross(canvas, 84, 4)
    return canvas


# --- Соқыртеке ---------------------------------------------------------------

def seeker():
    """Ловец с повязкой — та же картинка, что у роли в лобби."""
    return mode_art.role_seeker().image


def chase_vision():
    """Ловец видит только в кругу вокруг себя."""
    canvas = frame()
    grass(canvas)
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            d = ((x - 30) ** 2 + (y - 26) ** 2) ** 0.5
            if d > 21 or (d > 18 and (x + y) % 2):
                canvas.put(x, y, c("night") if (x + y) % 2 else c("grass_deep"))
    put(canvas, seeker(), 12, 8)
    put(canvas, figure(KID[0], KID[1], "left"), 30, 12)
    for x, y in ((60, 2), (74, 16)):
        put(canvas, silhouette(figure(GIRL[0], GIRL[1]), "ink_soft"), x, y)
    return canvas


def chase_catch():
    """Поймал — узнай вещь на пойманном."""
    canvas = frame()
    grass(canvas)
    put(canvas, seeker(), 0, 10)
    put(canvas, figure(KID[0], KID[1], "left"), 16, 10)
    fill(canvas, rows({y: (38, 93) for y in range(4, 44)}), c("ink"))
    card(canvas, 38, 4, 56, 40)
    put(canvas, icon("assets/sprites/items/head_takiya_01.png"), 42, 14)
    for i in range(3):
        bar(canvas, 62, 10 + i * 10, 28, lit=i == 1)
    return canvas


def chase_answer():
    """Верно — бегун выбывает; неверно — ловец замедлен на время."""
    canvas = frame()
    card(canvas, 4, 6, 42, 36)
    check(canvas, 8, 10)
    put(canvas, silhouette(figure(KID[0], KID[1]), "burgundy_light"), 16, 10)
    card(canvas, 50, 6, 42, 36)
    cross(canvas, 54, 10)
    ring = ellipse(78, 24, 9, 9) - ellipse(78, 24, 6, 6)
    fill(canvas, ring, c("burgundy_light"))
    fill(canvas, {(x, y) for x, y in ring if x >= 78 or y < 24}, c("red_light"))
    return canvas


def chase_field():
    """На поле — пруд замедляет, в юрте можно спрятаться; раунд на время."""
    canvas = frame()
    grass(canvas)
    pond = ellipse(18, 32, 13, 7)
    paint(canvas, pond, ramp("water_light", "water", "water_dark"))
    put(canvas, art("assets/sprites/aq_suyek/otau_bot.png"), 34, 6)
    ring = ellipse(78, 22, 11, 11) - ellipse(78, 22, 8, 8)
    fill(canvas, ring, c("ink_soft"))
    fill(canvas, {(x, y) for x, y in ring if not (x < 78 and y < 22)}, c("gold_light"))
    fill(canvas, rows({y: (77, 78) for y in range(15, 23)}), c("gold_light"))
    return canvas


# --- Ақ сүйек ----------------------------------------------------------------

AQ = "assets/sprites/aq_suyek/"


def aq_night(canvas):
    """Ночная трава в шахматку — как поле за кругом света."""
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            canvas.put(x, y, c("night") if (x + y) % 2 else c("grass_deep"))


def aq_teams():
    """Две көмбе по краям, сүйек брошен в ночное поле между ними."""
    canvas = frame("night")
    aq_night(canvas)
    put(canvas, art(AQ + "otau_human.png"), 2, 8)
    put(canvas, art(AQ + "otau_bot.png"), 72, 8)
    for i, (x, y) in enumerate([(26, 30), (29, 22), (33, 16), (38, 12), (44, 12), (49, 16), (53, 23)]):
        fill(canvas, rows({y: (x, x + 1)}), c("parchment" if i % 2 else "cream"))
    put(canvas, art(AQ + "bone.png"), 44, 30)
    return canvas


def aq_question():
    """Верный ответ на вопрос — видно, куда упал сүйек: место светится."""
    canvas = frame()
    card(canvas, 4, 4, 40, 40)
    for i in range(3):
        bar(canvas, 8, 10 + i * 10, 32, lit=i == 1)
    check(canvas, 44, 6)
    arrow(canvas, 46, 30, 54, 30)
    fill(canvas, rows({y: (58, 92) for y in range(10, 44)}), c("night"))
    ring = ellipse(75, 30, 15, 8) - ellipse(75, 30, 13, 6.5)
    fill(canvas, ring, c("gold_light"))
    put(canvas, art(AQ + "bone.png"), 63, 24)
    return canvas


def aq_carry():
    """Нашедший несёт сүйек к своей көмбе, соперник догоняет."""
    canvas = frame("night")
    aq_night(canvas)
    put(canvas, art(AQ + "otau_human.png"), 2, 8)
    runner = art(AQ + "token_human.png")
    put(canvas, runner, 30, 10)
    put(canvas, art(AQ + "bone.png"), 36, 2)
    arrow(canvas, 32, 42, 22, 42, "blue_light")
    put(canvas, art(AQ + "token_bot.png"), 58, 10)
    arrow(canvas, 72, 42, 60, 42, "red_light")
    return canvas


def aq_score():
    """Донёс до көмбе — очко; партия — до двух очков из трёх раундов."""
    canvas = frame("night")
    aq_night(canvas)
    put(canvas, art(AQ + "otau_human.png"), 4, 8)
    put(canvas, art(AQ + "bone.png"), 22, 32)
    check(canvas, 30, 6)
    for i, lit in enumerate((True, True, False)):
        cx = 60 + i * 12
        diamond = {(x, y) for x in range(cx - 4, cx + 5) for y in range(20, 29) if abs(x - cx) + abs(y - 24) <= 4}
        fill(canvas, diamond, c("gold_light") if lit else c("ink_soft"))
    return canvas


DIAGRAMS = {
    "sokyroteke": [chase_vision, chase_catch, chase_answer, chase_field],
    "abai_says": [abai_show, abai_repeat, abai_growth, abai_turns],
    "togyz_qumalaq": [togyz_sowing, lambda: togyz_capture(False), lambda: togyz_capture(True), togyz_win],
    "aq_suyek": [aq_teams, aq_question, aq_carry, aq_score],
}


def build():
    paths = []
    for mode_id, steps in DIAGRAMS.items():
        for i, draw in enumerate(steps):
            paths.append(save(draw(), os.path.join(OUT_DIR, f"{mode_id}_{i + 1}.png")))
    return paths
