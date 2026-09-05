#!/usr/bin/env python3
"""Готовит иконки слов для режима «Абай айтады».

Генератор (game-asset-mcp) отдаёт JPG 4:3 со случайными именами и разной долей
пустого фона. Скрипт приводит их к единому виду: обрезает по содержимому,
масштабирует предмет до одинакового «веса» в кадре, кладёт по центру квадрата и
сохраняет PNG в assets/words/food/<id>.png.

Фон заливается тем же цветом, что определён у исходника, — так подложка внутри
рамки карточки сливается без видимого прямоугольного шва.

Запуск:
    python3 tools/prepare_word_icons.py baursak=game-asset-mcp/assets/xxx.jpg kurt=...
"""

import os
import sys

from PIL import Image, ImageChops

OUT_DIR = os.path.join("assets", "words", "food")
SIZE = 256
# Какую долю стороны занимает сам предмет. Держит иконки одинаковыми по весу,
# даже если генератор оставил вокруг разное количество пустоты.
CONTENT_FRACTION = 0.86
# Насколько пиксель может отличаться от фона, чтобы всё ещё считаться фоном.
BG_TOLERANCE = 18
# SanlaqDesignTokens.CREAM (#f7f1e3). Генератор отдаёт то кремовый фон, то белый —
# приводим все иконки к одной подложке, иначе сетка карточек выглядит разнобойно.
CREAM = (247, 241, 227)


def detect_bg(img: Image.Image) -> tuple:
	"""Фон = медиана угловых пикселей: генератор всегда кладёт однотонную подложку."""
	w, h = img.size
	corners = [img.getpixel(p) for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
	return tuple(sorted(c[i] for c in corners)[len(corners) // 2] for i in range(3))


def content_mask(img: Image.Image, bg: tuple) -> Image.Image:
	"""Маска: белое там, где предмет, чёрное там, где фон."""
	diff = ImageChops.difference(img, Image.new("RGB", img.size, bg)).convert("L")
	return diff.point(lambda v: 255 if v > BG_TOLERANCE else 0)


def prepare(word_id: str, src_path: str) -> str:
	img = Image.open(src_path).convert("RGB")
	bg = detect_bg(img)
	mask = content_mask(img, bg)
	box = mask.getbbox()
	if box is None:
		raise SystemExit(f"{word_id}: на картинке не нашлось содержимого поверх фона ({src_path})")

	# Меняем родной фон на кремовый до масштабирования: замена по маске, а не
	# вставкой прямоугольника, поэтому шва по краю кропа не остаётся.
	img = Image.composite(img, Image.new("RGB", img.size, CREAM), mask)

	crop = img.crop(box)
	target = int(SIZE * CONTENT_FRACTION)
	scale = min(target / crop.width, target / crop.height)
	new_size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
	crop = crop.resize(new_size, Image.LANCZOS)

	canvas = Image.new("RGB", (SIZE, SIZE), CREAM)
	canvas.paste(crop, ((SIZE - new_size[0]) // 2, (SIZE - new_size[1]) // 2))

	os.makedirs(OUT_DIR, exist_ok=True)
	out_path = os.path.join(OUT_DIR, f"{word_id}.png")
	canvas.save(out_path, "PNG")
	return out_path


def main(argv: list) -> None:
	if not argv:
		raise SystemExit(__doc__)
	for pair in argv:
		if "=" not in pair:
			raise SystemExit(f"Ожидался формат id=путь, получено: {pair}")
		word_id, src_path = pair.split("=", 1)
		out_path = prepare(word_id, src_path)
		print(f"{word_id:<12} → {out_path}")


if __name__ == "__main__":
	main(sys.argv[1:])
