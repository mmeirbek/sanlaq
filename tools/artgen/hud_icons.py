"""Иконки HUD Соқыртеке и сенсорного управления.

Мелкие иконки плашки (часы, бегуны, способности, замедление, стрелки) и стик.
Сохраняются ×2 в assets/ui/hud/<id>.png.
"""
import math
import os

from item_icons import ellipse
from palette import ROOT, color as c
from pixel import Canvas, fill, outline, paint, rows, save

OUT_DIR = os.path.join(ROOT, "assets", "ui", "hud")


def clock():
    """Часы 12×12: золотой обод, пергаментный циферблат, стрелки на «без
    четверти» — читается как «время»."""
    canvas = Canvas(12, 12)
    fill(canvas, ellipse(6, 6, 5.5, 5.5), c("gold"))
    fill(canvas, ellipse(6, 6, 4, 4), c("parchment"))
    fill(canvas, {(5, 3), (5, 4), (5, 5), (5, 6), (6, 6), (7, 6)}, c("ink"))
    outline(canvas)
    return canvas


def _bust(skin, hair, shirt, shirt_dark):
    """Голова и плечи 12×12 — значок одного бегуна."""
    canvas = Canvas(12, 12)
    fill(canvas, rows({y: (2, 9) for y in range(8, 12)}) | rows({7: (3, 8)}), shirt)
    fill(canvas, {(x, 11) for x in range(2, 10)} | {(9, y) for y in range(8, 12)}, shirt_dark)
    fill(canvas, ellipse(6, 4, 3, 3.5), skin)
    fill(canvas, rows({0: (4, 7), 1: (3, 8), 2: (3, 8)}), hair)
    fill(canvas, {(4, 4), (7, 4)}, c("ink"))
    outline(canvas)
    return canvas


def runner():
    return _bust(c("skin"), c("hair_brown"), c("RUNNER"), c("blue"))


def runner_caught():
    """Пойманный бегун: серый силуэт и красный крест — видно и без цвета."""
    canvas = _bust(c("stone_light"), c("stone_dark"), c("stone"), c("stone_dark"))
    cross = {(x, x) for x in range(1, 11)} | {(x, 11 - x) for x in range(1, 11)}
    fill(canvas, cross, c("red_light"))
    return canvas


def sprint():
    """Рывок 16×16: красный сапог и три линии скорости."""
    canvas = Canvas(16, 16)
    boot = rows({y: (7, 11) for y in range(2, 10)}) | rows({y: (5, 14) for y in range(10, 14)})
    paint(canvas, boot, (c("rust_light"), c("rust"), c("rust_dark")))
    fill(canvas, {(x, 13) for x in range(5, 15)}, c("leather_dark"))
    fill(canvas, {(x, 4) for x in range(8, 11)}, c("gold_light"))
    for y, (x0, x1) in {5: (1, 4), 8: (0, 4), 11: (1, 3)}.items():
        fill(canvas, {(x, y) for x in range(x0, x1 + 1)}, c("gold_light"))
    outline(canvas)
    return canvas


def echo():
    """«Үн тыңдау» 16×16: источник звука и три расходящиеся дуги — как
    звуковые волны в самой игре."""
    canvas = Canvas(16, 16)
    fill(canvas, ellipse(3, 8, 2, 2), c("gold_light"))
    for radius in (4.5, 8.5, 12.5):
        arc = {(int(2 + radius * math.cos(a / 40)), int(8 + radius * math.sin(a / 40)))
               for a in range(-26, 27)}
        fill(canvas, {(x, y) for x, y in arc if 0 <= x < 16 and 1 <= y < 15}, c("gold_light"))
    outline(canvas)
    return canvas


def slow():
    """Замедление 16×12: улитка — понятна даже малышам."""
    canvas = Canvas(16, 12)
    body = rows({9: (1, 14), 10: (0, 14)}) | rows({y: (12, 14) for y in range(5, 9)})
    paint(canvas, body, (c("path_light"), c("path"), c("path_dark")))
    shell = ellipse(7, 5.5, 4.5, 4.5)
    paint(canvas, shell, (c("gold_light"), c("gold"), c("gold_dark")))
    fill(canvas, {(7, 5), (8, 5), (8, 6), (7, 7), (6, 7), (6, 6), (6, 4), (7, 3), (8, 3)}, c("gold_dark"))
    fill(canvas, {(13, 3), (13, 4), (14, 3)}, c("path_dark"))
    outline(canvas)
    return canvas


def arrow(direction):
    """Стрелка 8×12 для кнопок «предыдущий / следующий игрок»."""
    canvas = Canvas(8, 12)
    shape = {(x, y) for y in range(1, 11) for x in range(1, 7) if x - 1 <= 5 - abs(y - 5.5) + 0.5}
    paint(canvas, shape, (c("CREAM"), c("PARCHMENT_DARK"), c("MUTED")))
    outline(canvas)
    return canvas.mirrored() if direction == "left" else canvas


def joystick_base():
    """Основание стика 88×88 (176 px): золотое кольцо и четыре шеврона;
    середина пустая — мир под стиком видно."""
    size, center = 88, 44
    canvas = Canvas(size, size)
    bands = ((43.5, "outline"), (42.5, "gold_light"), (41.5, "gold"), (40.5, "gold_dark"), (39.5, "outline"))
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - center, y + 0.5 - center)
            for radius, name in bands:
                if radius - 1 < d <= radius:
                    canvas.put(x, y, c(name))
    for angle in range(4):
        a = angle * math.pi / 2
        tip_x, tip_y = center + math.cos(a) * 33, center + math.sin(a) * 33
        for k in range(5):
            for side in (-1, 1):
                px = tip_x - math.cos(a) * k + math.sin(a) * k * side
                py = tip_y - math.sin(a) * k - math.cos(a) * k * side
                canvas.put(int(px), int(py), c("gold"))
    return canvas


def joystick_knob():
    """Ручка стика 32×32 (64 px — не меньше пальца)."""
    canvas = Canvas(32, 32)
    paint(canvas, ellipse(16, 16, 15, 15), (c("gold_light"), c("gold"), c("gold_dark")))
    fill(canvas, ellipse(16, 16, 9, 9), c("gold"))
    fill(canvas, {(9, 8), (10, 7), (11, 7), (8, 9)}, c("sun"))
    outline(canvas)
    return canvas


def drawings():
    return {
        "clock": clock(), "runner": runner(), "runner_caught": runner_caught(),
        "sprint": sprint(), "echo": echo(), "slow": slow(),
        "arrow_left": arrow("left"), "arrow_right": arrow("right"),
        "joystick_base": joystick_base(), "joystick_knob": joystick_knob(),
    }


def build():
    return [save(canvas, os.path.join(OUT_DIR, name + ".png")) for name, canvas in drawings().items()]
