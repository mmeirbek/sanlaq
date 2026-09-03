# САҢЛАҚ / Sañlaq

Казахская игра «соқыртеке» (слепой козёл) в формате конкурентной погони
с обучающими викторинами о казахской одежде. MVP: человек против ботов.

**Движок:** Godot **4.7** (stable) — см. `config/features` в `project.godot`.

---

## Что это за игра

Одна охота на раунд:
- Один из игроков становится **Соқыртеке** (ловцом). У ловца ограниченный обзор:
  бегуны вне круга света невидимы.
- Ловец догоняет и ловит: при касании открывается **квиз** — нужно узнать предмет
  одежды жертвы по картинке (10 секунд, оба игрока при этом замирают).
- **Правильный ответ** → жертва выбывает (исчезает). Поймал всех → ловец победил.
- **Неправильный** → ловец получает **5с замедления** и не может начинать поимку.
- Время (90с) вышло и кто-то выжил → выиграли бегуны.
- Если выбыл человек → экран «ВЫ ПРОИГРАЛИ» и режим **наблюдателя**
  (следишь за ботами: клик по игроку / Tab / стрелки / кнопки ◀▶).
- Вода замедляет всех. Юрты можно обходить и прятаться внутри (купол скрывает от ловца).
- Правильный ответ в квизе **разблокирует предмет одежды** в шкафу.

---

## Требования и запуск

1. Установи **Godot 4.7** (stable) — https://godotengine.org/download
2. Открой редактор → **Import** → выбери `project.godot`
3. F5 (Run Project)

Управление:
- **WASD / стрелки** — движение, **Shift** — спринт
- **Esc** — выход в меню
- В режиме наблюдателя: клик по игроку / **Tab** / **Q** / стрелки / кнопки **◀ ▶**
- На телефоне — виртуальный джойстик слева + кнопка **SPRINT**

---

## Структура проекта

```
sokyroteke/
├── project.godot          # настройки, автолоады, input map
├── autoload/              # глобальные синглтоны
│   ├── asset_registry.gd  # индексация data/*.tres (одежда, карты, режимы, боты)
│   ├── save_manager.gd    # сохранения в user://save_data.json
│   ├── game_settings.gd   # язык KZ/RU/EN, громкости
│   └── scene_router.gd    # навигация между сценами + передача данных
├── scenes/
│   ├── ui/                # main_menu, wardrobe (шкаф), lobby/results/codex (заглушки)
│   ├── world/             # game.tscn (основная сцена), map_steppe_village, yurt
│   └── entities/          # player.tscn, character_visual.tscn
├── scripts/
│   ├── core/              # ресурсы данных: ClothingItem, MapDefinition, GameModeDefinition, BotProfile
│   ├── entities/          # player.gd, player_controller.gd, character_visual.gd
│   ├── systems/           # match_manager, map_manager, vision, sound_wave, camera
│   ├── ai/                # bot_agent.gd (FSM ботов)
│   └── ui/                # game_hud, quiz_hud, wardrobe, touch_controls
├── data/                  # контент в ресурсах .tres (менять без кода!)
│   ├── clothing/          # 13 предметов одежды
│   ├── maps/              # карта steppe_village
│   ├── game_modes/        # режим classic
│   └── bots/              # bot_easy / bot_medium / bot_hard
├── assets/
│   ├── character/         # мягкий 2D-мультяшный персонаж + одежда (см. README внутри)
│   │   ├── base/          # тело (кожа/волосы/лицо)
│   │   ├── head/ torso/ pants/ shoes/   # слои одежды
│   │   ├── yurt/          # текстура юрты
│   │   └── TEMPLATE.png   # сетка 4x6 для перерисовки
│   ├── items/             # превью предметов 128x128 (квиз/шкаф)
│   ├── tiles/             # ground, water_blob, rock (Kenney CC0)
│   └── character/README.md
└── tools/
    ├── generate_character.py  # генератор всех ассетов персонажа/одежды/текстур
    ├── smoke_test.gd          # проверка загрузки сцен
    ├── mechanics_test.gd      # проверка механики поимки
    └── spawn_test.gd          # проверка безопасного спавна
```

---

## Ключевые системы (как всё связано)

- **Data-driven**: весь контент — ресурсы `.tres`. `AssetRegistry` сканирует `data/` на
  старте и собирает массивы/словари (`get_clothing(slot)`, `get_bot_profile(id)`, ...).
- **Игровой цикл** (`match_manager.gd`): FSM `SETUP → COUNTDOWN → PLAYING → QUIZ → ROUND_END → MATCH_END`.
  Единственный раунд: победить = выбыть всех бегунов до конца таймера.
- **Связи через сигналы**: `match_manager` не знает про UI — всё через `game.gd`,
  который соединяет `quiz_hud`, `game_hud`, `vision`, камеру, звук.
- **Персонаж** (`character_visual.gd`): 5 синхронных `AnimatedSprite2D`-слоёв
  (тело, обувь, штаны, торс, голова), 4 направления × idle/walk. Экипировка =
  смена текстуры слоя из `texture_path` предмета.
- **Сохранения**: `SaveManager` хранит ник, разблокированные предметы, экипировку,
  настройки. Экипировка из `SaveManager.get_equipped()` применяется на игрока.

---

## Как добавить одежду (быстро)

1. В `tools/generate_character.py` добавь строку в `ITEMS`:
   ```python
   "head_borik_02": {"slot": "head", "color": (70, 90, 140), "hat": "cap"},
   ```
2. `python3 tools/generate_character.py` — сгенерирует лист и превью.
3. Создай `data/clothing/<id>.tres` (скопируй любой существующий, замени id/имена/цвет/пути).
4. Открой проект — предмет появится в шкафу, квизе и у ботов.

Вручную: нарисуй лист 384×256 по `assets/character/TEMPLATE.png`, превью 128×128,
укажи пути в `.tres`. Подробнее — `assets/character/README.md` и пример `.tres` ниже.

```gdscript
id = "head_borik_02"
slot_type = 0          # 0=голова,1=торс,2=штаны,3=обувь
name_kz/ru/en = ...
color = Color(0.27, 0.35, 0.55, 1)
rarity = 1             # 0=common,1=rare,2=legendary
unlock_by_default = true   # false → открывается правильным ответом
wrong_answers_kz/ru = Array[String](["Тақия","Сәукеле"])  # минимум 2
texture_path = "res://assets/character/head/head_borik_02.png"
icon_path    = "res://assets/items/head_borik_02.png"
```

---

## Как расширять

- **Новая карта**: создай `MapDefinition` в `data/maps/` + сцену карты на базе
  `map_manager.gd`; укажи спавн-поинты, границы, цвет.
- **Новый режим**: `GameModeDefinition` в `data/game_modes/`
  (таймер, число поимок, множители, длительность квиза, замедление).
- **Новый бот**: `BotProfile` в `data/bots/` (скорость, страх, реакция, шанс угадать).
- **Баланс на лету**: все настройки режима — в `data/game_modes/mode_classic.tres`.
- **Локализация**: `localization/strings.csv` существует, но
  `GameSettings.localize()` пока возвращает ключ — подключи TranslationServer при желании.

## Тесты

Запуск headless (без окна):
```
godot --headless --path . --script res://tools/smoke_test.gd
godot --headless --path . --script res://tools/mechanics_test.gd
godot --headless --path . --script res://tools/spawn_test.gd
```

---

## Сборка (экспорт)

1. **Editor → Manage Export Templates → Download** (нужна версия 4.7).
2. **Project → Export → Add Preset**.

| Платформа | Как |
|-----------|-----|
| Windows / Linux / macOS | добавить пресет, экспорт в `.exe` / `.x86_64` / `.app` |
| Web | пресет Web → `index.html` + `.wasm` → залить на itch.io или хостинг (ссылка играется в браузере) |
| Android | Android SDK → пресет Android → `.apk` на телефон / `.aab` в Play Console |
| iOS | только на Mac + Xcode + Apple Developer ($99/год) |

---

## Совместная работа

- Репозиторий **приватный** (GitHub). Добавляй коллег через Settings → Collaborators.
- Ветка `main` — рабочая. Правки через отдельные ветки + Pull Request.
- Не коммить: `.godot/`, `export/`, `build/`, `*.uid`, `*.import` (уже в `.gitignore`,
  Годот пересоздаёт их при открытии).
- Обновления ассетов — только через `tools/generate_character.py` или ручную замену PNG
  (с сохранением формата листа 384×256).

## Статус (MVP)

- ✅ Геймплей: погоня, квиз (10с + заморозка), выбывание, замедление, победа по таймеру
- ✅ Персонаж: 4 направления, анимации, слои одежды, лица
- ✅ Карта: трава, вода (замедляет), камни (коллизия), юрты (вход/выход, прятки)
- ✅ Шкаф, разблокировка предметов, рандомная одежда ботов
- ✅ Спектатор, мобильный джойстик
- 🔶 Заглушки: lobby / results / codex
- 🔶 Нет звуков, локализация не подключена к TranslationServer
