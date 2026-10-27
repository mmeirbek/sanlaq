#!/usr/bin/env python3
"""Переносит контент «Дала жолы» из atilla в ресурсы Godot.

    python tools/story/port_atilla.py --atilla ~/Desktop/atilla

Читает Assets/ATTILA/Editor/MvpContentBuilder.cs (atilla, коммит 1b6d80a) и пишет:

- data/story/cast.tres — жители, герои, статьи энциклопедии;
- data/story/chapter_<герой>.tres — главы с шагами, людьми и диалогами.

Тексты переносятся как есть (решение плана). Координаты atilla — метры, ось z
смотрит на север; здесь y смотрит вниз, как на экране, поэтому y = -z.

ВНИМАНИЕ: скрипт одноразовый. После правок команды в .tres (docs/HISTORY_REVIEW.md)
повторный запуск их затрёт.
"""
import argparse
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "data", "story")
SOURCE = "Assets/ATTILA/Editor/MvpContentBuilder.cs"
CHECK = "[ПРОВЕРИТЬ] "

# --- Разбор C#: токены и выражения --------------------------------------------

TOKEN = re.compile(r'''
    (?P<ws>\s+|//[^\n]*)
  | (?P<str>"(?:[^"\\]|\\.)*")
  | (?P<num>-?\d*\.?\d+f?)
  | (?P<id>[A-Za-z_][A-Za-z_0-9.]*(?:<[A-Za-z_0-9.<>, ]+>)?(?:\[\])?)
  | (?P<op>[(){}\[\],=;?:<>])
''', re.X)


def tokenize(text):
    out = []
    for m in TOKEN.finditer(text):
        kind = m.lastgroup
        if kind == "ws":
            continue
        out.append((kind, m.group(kind)))
    return out


class Parser:
    def __init__(self, tokens, env):
        self.t = tokens
        self.i = 0
        self.env = env

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None)

    def take(self, value=None):
        tok = self.t[self.i]
        if value is not None and tok[1] != value:
            raise SyntaxError(f"ждали {value!r}, получили {tok!r} у {self.t[self.i:self.i + 6]}")
        self.i += 1
        return tok

    def expr(self):
        kind, value = self.peek()
        if kind == "str":
            self.take()
            return bytes(value[1:-1], "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
        if kind == "num":
            self.take()
            return float(value.rstrip("f")) if "." in value or value.endswith("f") else int(value)
        if value in ("new", "new[]"):
            return self.new()
        if kind == "id":
            self.take()
            if value in ("true", "false"):
                return value == "true"
            if value == "null":
                return None
            if self.peek()[1] == "(":
                return self.call(value)
            if value in self.env:
                return self.env[value]
            return Name(value)
        raise SyntaxError(f"не разобрано: {self.t[self.i:self.i + 6]}")

    def args(self, close=")"):
        items = []
        while self.peek()[1] != close:
            items.append(self.expr())
            if self.peek()[1] == ",":
                self.take()
        self.take(close)
        return items

    def call(self, name):
        self.take("(")
        values = self.args(")")
        fn = HELPERS.get(name)
        if fn is None:
            raise NameError(name)
        return fn(*values)

    def new(self):
        self.take()
        kind, value = self.peek()
        type_name = ""
        if kind == "id":
            type_name = value
            self.take()
        if self.peek()[1] == "(":
            self.take("(")
            values = self.args(")")
            if type_name in ("Vector2", "Color"):
                return tuple(values)
        if self.peek()[1] == "{":
            self.take("{")
            # { a = 1, b = 2 } — объект; { x, y } — список.
            if self.peek()[0] == "id" and self.peek(1)[1] == "=":
                obj = {}
                while self.peek()[1] != "}":
                    key = self.take()[1]
                    self.take("=")
                    obj[key] = self.expr()
                    if self.peek()[1] == ",":
                        self.take()
                self.take("}")
                return obj
            return self.args("}")
        return {}


class Name(str):
    """Имя вроде LocationId.Steppe или FacingHint.West."""


def block_after(text, signature):
    """Тело в фигурных скобках после сигнатуры, без строк-комментариев."""
    start = text.index(signature)
    i = j = text.index("{", start)
    depth = 0
    while j < len(text):
        ch = text[j]
        if ch == '"':
            j += 1
            while text[j] != '"':
                j += 2 if text[j] == "\\" else 1
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return re.sub(r"^\s*//.*$", "", text[i + 1:j], flags=re.M)
        j += 1
    raise ValueError(signature)


def statements(body):
    """Делит тело функции на операторы по ';' вне скобок и строк."""
    out, depth, cur, in_str, esc = [], 0, [], False, False
    for ch in body:
        cur.append(ch)
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch in "({[":
            depth += 1
        elif ch in ")}]":
            depth -= 1
        elif ch == ";" and depth == 0:
            out.append("".join(cur[:-1]).strip())
            cur = []
    return [s for s in out if s]


# --- Помощники MvpContentBuilder, переписанные на Python -----------------------

FACING = {"FacingHint.South": (0, 1), "FacingHint.North": (0, -1), "FacingHint.East": (1, 0), "FacingHint.West": (-1, 0)}
LOCATION = {"LocationId.Aul": 0, "LocationId.Steppe": 1, "LocationId.City": 2}
ACTION = {"BeatAction.None": 0, "BeatAction.Collect": 1, "BeatAction.Build": 2, "BeatAction.Escort": 3,
          "BeatAction.Find": 4, "BeatAction.SokyrTeke": 5, "BeatAction.Asyk": 6, "BeatAction.Baige": 7,
          "BeatAction.Duel": 8, "BeatAction.Campfire": 9, "BeatAction.Map": 10}

STATE = {"dialogues": None}


def flip(point):
    return (point[0], -point[1])


def say(id_, speaker, look, *lines):
    d = {"_type": "StoryDialogue", "id": id_, "speaker": speaker, "look": look, "lines": list(lines),
         "choices": [], "check_note": ""}
    STATE["dialogues"].append(d)
    return d


def history(dialogue, note):
    dialogue["check_note"] = CHECK + note
    return dialogue


def choice(label, next_, flag=None, xp=0, unity=0):
    return {"_type": "StoryChoice", "label": label, "next_dialogue": next_, "flag": flag or "", "xp": xp, "unity": unity}


def at(npc, x, z, facing=Name("FacingHint.South"), location=Name("LocationId.Aul")):
    return {"_type": "StoryPlacement", "npc": npc, "look": "", "position": flip((x, z)),
            "facing": FACING[facing], "location": LOCATION[location]}


def figure(look, x, z, facing=Name("FacingHint.South"), location=Name("LocationId.Aul")):
    p = at("", x, z, facing, location)
    p["look"] = look
    return p


def in_(beat, location):
    beat["location"] = LOCATION[location]
    return beat


def beat(npc, objective, dialogue, xp, checkpoint, action=Name("BeatAction.None"), *unlock):
    return {"_type": "StoryBeat", "npc": npc, "objective": objective, "dialogue": dialogue, "xp": xp,
            "checkpoint": checkpoint, "action": ACTION[action], "unlock": list(unlock), "location": 0}


def task_beat(npc, objective, dialogue, xp, checkpoint, action, task, *unlock):
    b = beat(npc, objective, dialogue, xp, checkpoint, action, *unlock)
    b["task"] = task
    return b


def job(title, hint, item_label, props, points, required=1, goal=(0, 0)):
    return {"_type": "StoryTask", "title": title, "hint": hint, "item_label": item_label, "props": list(props),
            "points": [flip(p) for p in points], "required": required, "goal": flip(goal)}


def topic(label, dialogue, entry=None):
    return {"_type": "CampfireTopic", "label": label, "dialogue": dialogue, "entry": entry or ""}


NPCS = []
HEROES = []
ENTRIES = []


def npc(id_, name, look, _radius):
    n = {"_type": "StoryNpc", "id": id_, "name": name, "look": look, "idle_line": "", "again_line": ""}
    NPCS.append(n)
    return n


def chat(npc_id, _name, _look, first, again):
    for n in NPCS:
        if n["id"] == npc_id:
            n["idle_line"], n["again_line"] = first, again


def entry(id_, category, title, look, icon, text, note, open_=False):
    e = {"_type": "EncyclopediaEntry", "id": id_, "category": category, "title": title, "text": text,
         "open_from_start": open_, "look": look or "", "icon": icon or "", "check_note": CHECK + note}
    ENTRIES.append(e)
    return e


def role(id_, name, description, era, tagline, look, chapter, _card):
    HEROES.append({"_type": "StoryHero", "id": id_, "name": name, "description": description, "era": era,
                   "tagline": tagline, "look": look, "chapter": chapter, "order": len(HEROES)})


HELPERS = {"Say": say, "History": history, "Choice": choice, "At": at, "Figure": figure, "In": in_,
           "Beat": beat, "TaskBeat": task_beat, "Job": job, "Topic": topic, "Npc": npc, "Chat": chat,
           "Entry": entry, "Role": role}


def run_body(body, env):
    """Выполняет операторы тела функции; возвращает то, что вернул return."""
    for st in statements(body):
        m = re.match(r"var (\w+) = (.*)$", st, re.S)
        if m:
            env[m.group(1)] = Parser(tokenize(m.group(2)), env).expr()
            continue
        if st.startswith("return "):
            return Parser(tokenize(st[7:]), env).expr()
        m = re.match(r"([\w.]+)\.(Add|AddRange)\((.*)\)$", st, re.S)
        if m:
            target = resolve(env, m.group(1))
            value = Parser(tokenize(m.group(3)), env).expr()
            target.extend(value if m.group(2) == "AddRange" else [value])
            continue
        m = re.match(r"(\w+)\.(\w+) = (.*)$", st, re.S)
        if m:
            env[m.group(1)][m.group(2)] = Parser(tokenize(m.group(3)), env).expr()
            continue
        name = re.match(r"[\w.]+", st).group(0)
        if name not in HELPERS:
            print("пропущено:", st[:60])
            continue
        Parser(tokenize(st), env).expr()


def resolve(env, path):
    """chapter.beats, night.campfire.topics, bi.choices — список, создаётся по требованию."""
    parts = path.split(".")
    obj = env[parts[0]]
    for key in parts[1:]:
        obj = obj.setdefault(key, [] if key in ("choices", "topics", "beats", "npcs", "allies") else {})
    return obj


def chapter_from(raw, dialogues):
    beats = []
    for b in raw["beats"]:
        if "campfire" in b:
            b["campfire_title"] = b["campfire"].get("title", "")
            b["topics"] = b["campfire"].get("topics", [])
        if "map" in b:
            m = b["map"]
            b.update(route_title=m["title"], route_goal=m["goal"], route_start=m["startLabel"],
                     route_end=m["endLabel"], route=[(x, 1 - y) for x, y in m["route"]])
        beats.append({k: v for k, v in b.items() if k not in ("campfire", "map")})
    return {
        "_type": "StoryChapter", "id": raw["id"], "hero": raw["roleId"], "title": raw["title"],
        "subtitle": raw["subtitle"], "intro": raw["intro"], "finale_title": raw["finaleTitle"],
        "finale_text": raw["finaleText"], "finale_alt_text": raw.get("finaleAltText", ""),
        "finale_alt_min_unity": raw.get("finaleAltMinUnity", 0), "ally_min_unity": raw.get("allyMinUnity", 0),
        "ally_message": raw.get("allyMessage", ""), "duel_ally_min_unity": raw.get("duelAllyMinUnity", 0),
        "beats": beats, "placements": raw.get("npcs", []), "allies": raw.get("allies", []),
        "dialogues": dialogues,
    }


# --- Запись .tres -----------------------------------------------------------------

SCRIPTS = {
    "StoryChapter": "story_chapter", "StoryBeat": "story_beat", "StoryDialogue": "story_dialogue",
    "StoryChoice": "story_choice", "StoryTask": "story_task", "CampfireTopic": "campfire_topic",
    "StoryPlacement": "story_placement", "StoryNpc": "story_npc", "StoryHero": "story_hero",
    "EncyclopediaEntry": "encyclopedia_entry", "StoryCast": "story_cast",
}
ARRAY_TYPES = {"choices": "StoryChoice", "topics": "CampfireTopic", "beats": "StoryBeat",
               "placements": "StoryPlacement", "allies": "StoryPlacement", "dialogues": "StoryDialogue",
               "npcs": "StoryNpc", "heroes": "StoryHero", "entries": "EncyclopediaEntry"}
VECTOR_FIELDS = {"position", "facing", "goal"}
PACKED_FIELDS = {"points", "route"}
STRING_ARRAYS = {"lines", "unlock", "props"}


def quote(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def num(v):
    return repr(float(v)) if isinstance(v, float) else str(v)


class Writer:
    def __init__(self, root):
        self.root = root
        self.subs = []
        self.ids = {}
        self.ext = {}

    def script_id(self, type_name):
        if type_name not in self.ext:
            self.ext[type_name] = f"{len(self.ext) + 1}_{SCRIPTS[type_name]}"
        return self.ext[type_name]

    def emit(self, obj, is_root=False):
        fields = []
        for key, value in obj.items():
            if key == "_type":
                continue
            fields.append((key, self.value(key, value)))
        sid = self.script_id(obj["_type"])
        body = [f'script = ExtResource("{sid}")'] + [f"{k} = {v}" for k, v in fields]
        if is_root:
            return body
        rid = f"{obj['_type']}_{len(self.subs) + 1}"
        self.subs.append((rid, body))
        return f'SubResource("{rid}")'

    def value(self, key, v):
        if key in ARRAY_TYPES:
            refs = [self.emit(item) for item in v]
            return f'Array[ExtResource("{self.script_id(ARRAY_TYPES[key])}")]([{", ".join(refs)}])'
        if key in STRING_ARRAYS:
            return "Array[String]([" + ", ".join(quote(s) for s in v) + "])"
        if key in PACKED_FIELDS:
            flat = [num(float(c)) for p in v for c in p]
            return "PackedVector2Array(" + ", ".join(flat) + ")"
        if key in VECTOR_FIELDS:
            return f"Vector2({num(float(v[0]))}, {num(float(v[1]))})"
        if key == "task":
            return self.emit(v)
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return num(v)
        return quote(v)

    def text(self):
        root_body = self.emit(self.root, is_root=True)
        lines = [f'[gd_resource type="Resource" script_class="{self.root["_type"]}" format=3]', ""]
        for type_name, sid in self.ext.items():
            lines.append(f'[ext_resource type="Script" path="res://scripts/story/{SCRIPTS[type_name]}.gd" id="{sid}"]')
        lines.append("")
        for rid, body in self.subs:
            lines.append(f'[sub_resource type="Resource" id="{rid}"]')
            lines.extend(body)
            lines.append("")
        lines.append("[resource]")
        lines.extend(root_body)
        return "\n".join(lines) + "\n"


def write(path, root):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(Writer(root).text())
    print("записан", os.path.relpath(path, ROOT))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--atilla", required=True)
    args = parser.parse_args()
    text = open(os.path.join(os.path.expanduser(args.atilla), SOURCE), encoding="utf-8").read()
    # Единственное выражение, которое разбор не понимает, — тождественный тернарник.
    text = text.replace("LocationId.City == LocationId.City ? FacingHint.North : FacingHint.South", "FacingHint.North")

    STATE["dialogues"] = []
    Parser(tokenize(block_after(text, "Npcs() => new()") + "}"), {}).args("}")
    run_body(block_after(text, "private static void IdleDialogues()"), {})

    files = {"Kerey": "kerey", "Abylai": "abylai", "Kabanbay": "kabanbay"}
    for fn, name in files.items():
        STATE["dialogues"] = []
        raw = run_body(block_after(text, f"private static ChapterDefinition {fn}()"), {})
        write(os.path.join(OUT, f"chapter_{name}.tres"), chapter_from(raw, STATE["dialogues"]))

    Parser(tokenize(block_after(text, "Entries() => new()") + "}"), {}).args("}")
    run_body(block_after(text, "private static void BuildRoles()"), {})
    write(os.path.join(OUT, "cast.tres"),
          {"_type": "StoryCast", "npcs": NPCS, "heroes": HEROES, "entries": ENTRIES})
    print(f"{len(NPCS)} жителей, {len(HEROES)} героя, {len(ENTRIES)} статей")


if __name__ == "__main__":
    main()
