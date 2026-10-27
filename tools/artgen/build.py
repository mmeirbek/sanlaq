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

import app_icon  # noqa: E402
import aq_suyek_art  # noqa: E402
import briefing_art  # noqa: E402
import characters  # noqa: E402
import food_icons  # noqa: E402
import hud_icons  # noqa: E402
import item_icons  # noqa: E402
import mode_art  # noqa: E402
import togyz_art  # noqa: E402
import ui_frames  # noqa: E402
import world_art  # noqa: E402
from palette import ROOT  # noqa: E402


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    for path in (ui_frames.build() + characters.build() + item_icons.build() + mode_art.build()
                 + world_art.build() + hud_icons.build()
                 + food_icons.build() + togyz_art.build() + aq_suyek_art.build()
                 + briefing_art.build() + app_icon.build()):
        print("записан", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
