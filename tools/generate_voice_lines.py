#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Генератор озвучки для экранов-объяснений (брифингов).

Читает казахские строки прямо из `data/briefings/*.tres`, берёт английские
переводы из `assets/i18n/ui_strings.csv` и синтезирует по файлу на строку в
`assets/audio/voice/kk/` и `assets/audio/voice/en/`.

Запуск (только macOS — используется системная утилита `say`):

    python3 tools/generate_voice_lines.py            # сгенерировать недостающее
    python3 tools/generate_voice_lines.py --force    # перезаписать всё
    python3 tools/generate_voice_lines.py --list     # только показать, что нужно

Имена файлов совпадают с тем, что ждёт `ModeBriefing.voice_id()`:
`<id режима>_<номер строки>.wav`, нумерация сквозная — сначала `how_to_play`,
затем `skills`. Так что после перезаписи любой строки в `.tres` достаточно
удалить соответствующий .wav и прогнать скрипт снова.

Если озвучку захочется записать живым голосом — просто положи свои файлы с теми
же именами, скрипт их не трогает (без `--force`), а игра предпочитает файл
любому синтезатору.
"""

import argparse
import csv
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRIEFINGS_DIR = os.path.join(ROOT, "data", "briefings")
CSV_PATH = os.path.join(ROOT, "assets", "i18n", "ui_strings.csv")
VOICE_DIR = os.path.join(ROOT, "assets", "audio", "voice")

# Голоса macOS. Aru — единственный казахский голос в системе; для английского
# берём любой из перечисленных, какой найдётся первым.
VOICES = {
    "kk": ["Aru"],
    "en": ["Samantha", "Ava", "Daniel", "Alex"],
}
# 22050 Гц моно — речь звучит чисто, а Godot при импорте сожмёт ещё сильнее.
DATA_FORMAT = "LEI16@22050"

ARRAY_RE = re.compile(r'(\w+)\s*=\s*Array\[String\]\(\[(.*?)\]\)', re.DOTALL)
STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"', re.DOTALL)
FIELD_RE = re.compile(r'^(\w+)\s*=\s*"([^"]*)"\s*$', re.MULTILINE)


def read_briefings():
    """[(id режима, [строки в порядке нумерации])] из всех .tres."""
    out = []
    for name in sorted(os.listdir(BRIEFINGS_DIR)):
        if not name.endswith(".tres"):
            continue
        text = open(os.path.join(BRIEFINGS_DIR, name), encoding="utf-8").read()
        fields = dict(FIELD_RE.findall(text))
        arrays = {k: STRING_RE.findall(v) for k, v in ARRAY_RE.findall(text)}
        mode_id = fields.get("id", "")
        if not mode_id:
            print("пропускаю %s: нет поля id" % name)
            continue
        out.append((mode_id, arrays.get("how_to_play", []) + arrays.get("skills", [])))
    return out


def read_translations():
    """{казахская строка: английский перевод} из ui_strings.csv."""
    with open(CSV_PATH, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    return {r[0]: r[2] for r in rows[1:] if len(r) >= 3}


def pick_voice(lang):
    try:
        listing = subprocess.run(["say", "-v", "?"], capture_output=True, text=True).stdout
    except FileNotFoundError:
        sys.exit("нужна macOS-утилита `say` — на других системах положи файлы вручную")
    available = {line.split()[0] for line in listing.splitlines() if line.strip()}
    for voice in VOICES[lang]:
        if voice in available:
            return voice
    return None


def synthesize(text, voice, out_path):
    subprocess.run(
        ["say", "-v", voice, "--data-format=" + DATA_FORMAT, "-o", out_path, text],
        check=True,
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="перезаписать существующие файлы")
    ap.add_argument("--list", action="store_true", help="только показать список файлов")
    args = ap.parse_args()

    briefings = read_briefings()
    translations = read_translations()

    total, made, skipped = 0, 0, 0
    for lang in ("kk", "en"):
        voice = None if args.list else pick_voice(lang)
        if not args.list and voice is None:
            print("нет голоса для '%s' (искал: %s) — пропускаю язык"
                  % (lang, ", ".join(VOICES[lang])))
            continue
        out_dir = os.path.join(VOICE_DIR, lang)
        os.makedirs(out_dir, exist_ok=True)

        for mode_id, lines in briefings:
            for i, kk_line in enumerate(lines):
                total += 1
                name = "%s_%02d" % (mode_id, i + 1)
                out_path = os.path.join(out_dir, name + ".wav")
                text = kk_line if lang == "kk" else translations.get(kk_line)
                if text is None:
                    print("НЕТ ПЕРЕВОДА для %s: %s" % (name, kk_line[:50]))
                    continue
                if args.list:
                    print("%s/%s.wav  <- %s" % (lang, name, text[:60]))
                    continue
                if os.path.exists(out_path) and not args.force:
                    skipped += 1
                    continue
                synthesize(text, voice, out_path)
                made += 1
                print("%s/%s.wav (%s)" % (lang, name, voice))

    if args.list:
        print("\nвсего строк: %d" % total)
    else:
        print("\nсоздано: %d, уже было: %d, всего: %d" % (made, skipped, total))


if __name__ == "__main__":
    main()
