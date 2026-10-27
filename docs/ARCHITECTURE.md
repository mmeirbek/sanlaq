# Архитектура САҢЛАҚ

Как устроен код и где что менять. Обзор режимов и запуск — в [README](../README.md).

## Принципы

1. **Контент — данные.** Одежда, слова, вопросы, объяснения режимов, баланс погони,
   боты и карта лежат в `data/*.tres`. `AssetRegistry` сканирует `data/` на старте;
   новая вещь или вопрос не требуют кода.
2. **Правила отдельно от экрана.** `GameBoard` (тоғыз) и `AqSuyekBoard` — `RefCounted`
   без ссылок на узлы. Ход возвращает словарь-разбор, по которому экран строит
   анимацию. Правила покрыты headless-тестами.
3. **Экран сам по себе.** Каждый режим — своя сцена и свой скрипт, общего состояния
   нет. Между экранами данные передаёт только `SceneRouter`.
4. **Вид — из темы.** Цвета и размеры — `UiTokens`, вид узла — `theme_type_variation`
   темы `resources/ui/ui_theme.tres`. Тему собирает `tools/build_theme.gd`.

## Автолоады (`autoload/`)

| Автолоад | Что делает |
|---|---|
| `AssetRegistry` | индексирует `data/`: `get_clothing(slot)`, `get_words()`, `get_briefing(id)`, вопросы, боты, режим, главы и герои сюжета |
| `SaveManager` | ник, экипировка, настройки, карьера, прогресс сюжета (`story`, `save_story()`) в `user://save_data.json`; в тестах не читает и не пишет |
| `GameSettings` | язык (локаль + язык данных), громкость, тряска, озвучка объяснений |
| `MusicAudio` | фоновая музыка |
| `SceneRouter` | переходы со шторкой (`go_to_*`), передача данных между экранами, замораживает уходящий экран |
| `Telemetry` | события и лицензирование станций; в тестах молчит |
| `UiSounds` | щелчок на нажатие любой кнопки (звук синтезируется) |
| `PixelScale` | округляет масштаб окна до шага 0,5, чтобы пиксель арта был целым |

`RunContext` (`scripts/core/run_context.gd`) отличает живую игру от headless-тестов
и инструментов: в них нет сохранения, телеметрии, звука и обучения.

## Экраны (`scenes/ui/`)

Все экраны — `Control` с `ScreenHeader` (заголовок, «Артқа», Esc) и `PixelBackdrop`.
Компоненты — в `scripts/ui/components/`: `PixelButton`, `SelectableCard`,
`ClothingCard`, `EntryCard`, `SlotTabs`, `ConfirmDialog`, `PauseMenu`, `Toast`, `Banner`,
`Countdown`, `TimeBar`, `GemDivider`. Описание — в [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

- `main_menu` — ник, персонаж игрока, вход в разделы; при первом запуске —
  `welcome_overlay.gd`.
- `mode_select` → `mode_briefing` (одна сцена на все режимы, содержание из
  `ModeBriefing`) → режим.
- Настольные режимы: `abai_says`, `togyz_qumalaq` (лунка — `TogyzPit`), `aq_suyek`
  (поле — `AqSuyekField`). «Артқа» посреди партии ставит паузу.

## Соқыртеке (`scenes/world/`)

```
game.tscn
├── Map (map_steppe_village.tscn, MapManager)   камни, брёвна, юрты, пруды, забор
├── Players                                      Player × (1 человек + боты)
├── Systems                                      звуковые волны, следы, обзор, MatchManager
├── Camera
├── CanvasLayer: QuizHUD, GameHUD
├── TouchControls
└── слой паузы: PauseMenu
```

- `MatchManager` — машина состояний `SETUP → COUNTDOWN → PLAYING → QUIZ → ROUND_END →
  MATCH_END`, про интерфейс не знает. Сигналы связывает `game.gd`.
- `Player` — движение, замедление, щит, выбывание; внешний вид — `CharacterVisual`
  (5 слоёв `AnimatedSprite2D`, 4 направления). Одевает `OutfitApplier`.
- Боты — `BotAgent` (конечный автомат погони), профили сложности в `data/bots/`.
- Роли и победитель — `Roles.Role`, `Roles.Winner`.
- Мир в виде 3/4: позиция игрока — точка на земле, фигура выше (`Player.BODY_CENTER`).
  Стоящее сортируется по y, плоское и эффекты — на слоях `WorldLayers`.
  Физика — один слой «world» (`WorldLayers.PHYSICS_WORLD`).
- Обзор ловца — `vision.gdshader`; кого видно, решает `game.gd` по тому же кругу.
- Свойства одежды — поля `ClothingItem` (`slow_duration_mult`, `visibility_mult`,
  `dry_speed_mult`), игрок их перемножает.

## Тарих жолы (`scenes/story/`, `scripts/story/`)

```
hero_select.tscn         карусель трёх героев, прогресс и «БАСТАУ / ЖАЛҒАСТЫРУ / ҚАЙТА ОЙНАУ»
story_world.tscn         мир главы: земля, сортируемый по y мир, игрок, камера
├── Ui: StoryHud         глава, цель «3 / 7», XP, пауза, баннер задания, тост
├── Ui: DialogueBox      портрет, печать по буквам, выбор 1/2
├── Ui: Overlay          экраны поверх мира (StoryOverlays)
└── TouchControls        стик и кнопка «сөйлесу»
```

- **Данные.** `StoryChapter` — шаги (`StoryBeat`), диалоги, расстановка жителей,
  финал. `StoryCast` — герои, жители, статьи энциклопедии (`EncyclopediaEntry`).
  Шаг — житель, диалог, действие (`StoryBeat.Action`), XP, статьи.
- **Ядро — `StoryState`**, без узлов, поверх словаря `SaveManager.story`: шаги строго
  по очереди, бірлік 0–100, флаги выборов, XP главы, открытые статьи, финал и
  союзники. Тест — `story_rules_test`.
- **Мир — `story_world.gd`.** Место (`StoryLayout`: аул, степь, Түркістан; метр —
  40 px, y вниз, нижний край картинки — точка на земле) строится заново при переезде.
  Цель шага — `target_point()`: житель, предмет задания или арба.
- **Задания в мире** — подклассы `StoryTaskRunner` в `scripts/story/tasks/` (сбор,
  стройка, конь, след, бәйге): сигналы `finished` / `failed`, картинка на баннере.
  Соперник в бәйге ищет дорогу `AStarGrid2D` по коллизиям места.
- **Экраны поверх мира** — `StoryOverlays` (`scripts/story/overlays/`): заставка
  главы, костёр, карта маршрута, финал (сигнал `done`), асық и жекпе-жек (`won` /
  `lost`, проигрыш — `ConfirmDialog` с повтором). Правила мини-игр — `AsykRules`,
  `DuelRules` (`scripts/story/games/`), тест `story_games_test`.
- **Соқыр теке** в сюжете — обычная `game.tscn` с `{"story": true}`: итог возвращается
  через `SceneRouter.take_story_result()`.
- **Автопилот** `story_world_test` проходит все три главы через настоящий мир, как
  игрок; отдельно — порядок стройки юрты и бәйге (проигрыш, соперник, победа).

## Локализация

Ключ — казахская строка, колонки `keys,kk,en` в `assets/i18n/ui_strings.csv`. В коде —
`tr()`; `Label` переводит свой `text` сам. Названия вещей и слов хранятся в ресурсах
парами `name_kz` / `name_en`, язык берётся из `GameSettings.get_lang_code()`.
Тексты сюжета (диалоги, статьи, цели) — отдельный `assets/i18n/story_strings.csv`,
его собирает из `data/story/` скрипт `tools/story/extract_strings.py`.

## Тесты (`tools/`)

Тест наследуется от `tools/test_case.gd` (`check()`, `finish()`) и падает и при ошибке
движка в логе. Классы, которые сами обращаются к автолоадам, в тесте нельзя писать
как типы и нельзя `preload` — см. шапку `test_case.gd`. Все тесты гоняет
`tools/run_tests.sh`, его же запускает CI.
