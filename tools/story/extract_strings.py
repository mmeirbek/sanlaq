"""Строки «Тарих жолы» для перевода: собирает видимый игроку текст из
data/story/*.tres в assets/i18n/story_strings.csv (keys,kk,en). Уже сделанные
переводы сохраняются; новые строки приходят с пустым en, удалённые из данных —
выпадают. Запуск после port_atilla.py или правки текстов:

    python3 tools/story/extract_strings.py

В конце печатает, сколько строк ещё без перевода (tools/localization_test.gd
ловит их на экранах).
"""
import csv
import glob
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CSV_PATH = os.path.join(ROOT, "assets", "i18n", "story_strings.csv")
## Поля для сверки историком (check_note) и ключи — не для игрока.
SKIP_FIELDS = {"check_note", "id", "look", "icon", "npc", "dialogue", "next_dialogue", "entry", "checkpoint",
               "hero", "chapter", "flag", "unlock"}
CYRILLIC = re.compile("[Ѐ-ӿ]")
SCALAR = re.compile(r'^(\w+) = "((?:[^"\\]|\\.)*)"', re.M)
ARRAY = re.compile(r'^(\w+) = (?:Array\[String\]|PackedStringArray)\(\[?(.*?)\]?\)$', re.M)
ITEM = re.compile(r'"((?:[^"\\]|\\.)*)"')


def unescape(text):
    return text.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def collect():
    found = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "story", "*.tres"))):
        source = open(path, encoding="utf-8").read()
        values = [(m.start(), m.group(1), m.group(2)) for m in SCALAR.finditer(source)]
        for m in ARRAY.finditer(source):
            values += [(m.start(), m.group(1), v) for v in ITEM.findall(m.group(2))]
        for _, field, value in sorted(values):
            text = unescape(value)
            if field not in SKIP_FIELDS and CYRILLIC.search(text) and text not in found:
                found.append(text)
    return found


def main():
    known = {}
    if os.path.exists(CSV_PATH):
        with open(CSV_PATH, encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                known[row["keys"]] = row["en"]
    strings = collect()
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["keys", "kk", "en"])
        for text in strings:
            writer.writerow([text, text, known.get(text, "")])
    missing = sum(1 for text in strings if not known.get(text))
    print(f"{len(strings)} строк, без перевода: {missing}")


if __name__ == "__main__":
    main()
