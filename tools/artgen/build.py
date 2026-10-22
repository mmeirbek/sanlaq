#!/usr/bin/env python3
"""Пересобирает весь сгенерированный арт САҢЛАҚ.

    python tools/artgen/build.py

Нужен Pillow. После сборки откройте проект в Godot (или запустите
`godot --headless --import --path .`), а если менялись рамки — пересоберите
тему: `godot --headless --path . --script res://tools/build_theme.gd`.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ui_frames  # noqa: E402
from palette import ROOT  # noqa: E402


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    for path in ui_frames.build():
        print("записан", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
