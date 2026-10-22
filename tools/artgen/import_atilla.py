#!/usr/bin/env python3
"""Переносит арт из atilla (mmeirbek/atilla, коммит 1b6d80a) в САҢЛАҚ, сводя его
к общей палитре и пиксельной сетке.

    python tools/artgen/import_atilla.py --atilla ~/Desktop/atilla

Результат коммитится в репозиторий, поэтому запускать скрипт нужно, только если
в atilla поменялся исходный арт.

- Логотип SANLAQ — 320 пикселей арта в ширину, без дизеринга.
- Фоны меню — 640×360 пикселей арта (весь экран при ×2) с лёгким дизерингом,
  чтобы небо на закате осталось плавным.
"""
import argparse
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from palette import PIXEL, ROOT, quantize  # noqa: E402

SPRITES = os.path.join(ROOT, "assets", "sprites")
LOGO_WIDTH = 320
BACKGROUND_SIZE = (640, 360)
SKY_DITHER = 16

# Исходник в atilla -> файл в САҢЛАҚ.
BACKGROUNDS = {
    "Assets/ATTILA/Art/Menu/Background/ProvidedMainMenuBackground.png": "backgrounds/menu_main.png",
    "Assets/ATTILA/Art/Menu/Background/TemporarySteppeSunset.png": "backgrounds/menu_steppe.png",
}
LOGO = ("Assets/ATTILA/Art/Menu/Logo/SanlaqLogo.png", "ui/logo.png")


def _save(image, relative):
    path = os.path.join(SPRITES, relative)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.resize((image.width * PIXEL, image.height * PIXEL), Image.Resampling.NEAREST).save(path)
    return path


def import_logo(atilla):
    source = Image.open(os.path.join(atilla, LOGO[0])).convert("RGBA")
    source = source.crop(source.getbbox())
    height = round(source.height * LOGO_WIDTH / source.width)
    small = source.resize((LOGO_WIDTH, height), Image.Resampling.LANCZOS)
    return _save(quantize(small), LOGO[1])


def import_backgrounds(atilla):
    written = []
    for source_path, target in BACKGROUNDS.items():
        source = Image.open(os.path.join(atilla, source_path)).convert("RGBA")
        small = source.resize(BACKGROUND_SIZE, Image.Resampling.LANCZOS)
        written.append(_save(quantize(small, dither=SKY_DITHER), target))
    return written


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--atilla", required=True, help="путь к клону mmeirbek/atilla")
    atilla = os.path.expanduser(parser.parse_args().atilla)
    for path in [import_logo(atilla)] + import_backgrounds(atilla):
        print("записан", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
