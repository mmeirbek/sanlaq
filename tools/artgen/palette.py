"""Палитра для генераторов арта — читается из scripts/ui/ui_tokens.gd.

Цвета объявлены в одном месте (UiTokens), чтобы интерфейс и сгенерированный
арт не расходились. Здесь они разбираются из строк вида
    const GOLD := Color("d99a55")
"""
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TOKENS_PATH = os.path.join(ROOT, "scripts", "ui", "ui_tokens.gd")

_COLOR_RE = re.compile(r'^const\s+([A-Z_]+)\s*:=\s*Color\("([0-9a-fA-F]{6})"\)', re.MULTILINE)
_INT_RE = re.compile(r'^const\s+PIXEL\s*:=\s*(\d+)', re.MULTILINE)


def _load():
    text = open(TOKENS_PATH, encoding="utf-8").read()
    colors = {name: tuple(int(hex_[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
              for name, hex_ in _COLOR_RE.findall(text)}
    pixel = int(_INT_RE.search(text).group(1))
    return colors, pixel


PALETTE, PIXEL = _load()
TRANSPARENT = (0, 0, 0, 0)


def color(name):
    """RGBA-цвет токена по имени, например color("GOLD")."""
    return PALETTE[name]
