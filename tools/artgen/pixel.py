"""Минимальный холст для пиксель-арта: рисуем в пикселях арта, сохраняем в
целом масштабе ×PIXEL (nearest), как требует правило единой сетки."""
import os

from PIL import Image

from palette import PIXEL, TRANSPARENT


class Canvas:
    def __init__(self, width, height, fill=TRANSPARENT):
        self.image = Image.new("RGBA", (width, height), fill)
        self.width, self.height = width, height

    def put(self, x, y, color):
        if 0 <= x < self.width and 0 <= y < self.height:
            self.image.putpixel((x, y), color)

    def rect(self, x0, y0, x1, y1, color):
        """Закрашенный прямоугольник, обе границы включительно."""
        for y in range(max(y0, 0), min(y1, self.height - 1) + 1):
            for x in range(max(x0, 0), min(x1, self.width - 1) + 1):
                self.image.putpixel((x, y), color)

    def ring(self, inset, top, left, bottom, right):
        """Кольцо толщиной 1 пиксель на расстоянии inset от края, каждая сторона
        своим цветом (блик сверху, тень снизу). Углы кольца берут цвет верха/низа."""
        x0, y0 = inset, inset
        x1, y1 = self.width - 1 - inset, self.height - 1 - inset
        self.rect(x0, y0, x0, y1, left)
        self.rect(x1, y0, x1, y1, right)
        self.rect(x0, y0, x1, y0, top)
        self.rect(x0, y1, x1, y1, bottom)

    def stamp(self, pattern, x, y, colors):
        """Рисует шаблон из строк: символ -> цвет из словаря colors, '.' пропуск."""
        for dy, row in enumerate(pattern):
            for dx, ch in enumerate(row):
                if ch in colors:
                    self.put(x + dx, y + dy, colors[ch])

    def mirrored(self):
        out = Canvas(self.width, self.height)
        out.image = self.image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        return out


def flip_pattern(pattern, horizontal=False, vertical=False):
    rows = [row[::-1] if horizontal else row for row in pattern]
    return rows[::-1] if vertical else rows


def save(canvas, path, scale=PIXEL):
    """Сохраняет холст, увеличенный в целое число раз без сглаживания."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image = canvas.image.resize((canvas.width * scale, canvas.height * scale), Image.Resampling.NEAREST)
    image.save(path)
    return path
