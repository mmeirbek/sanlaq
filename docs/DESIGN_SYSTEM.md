# Дизайн-система САҢЛАҚ

Пиксельный стиль по образцу atilla: бордо, золото, кремовый.
Правила стиля — в [REDESIGN_PLAN.md](REDESIGN_PLAN.md), раздел «Единый стиль».
Часть правил проверяет `tools/style_test.gd`.

## Из чего состоит

| Что | Где | Правится |
|---|---|---|
| Цвета, шрифты, размеры, отступы | `scripts/ui/ui_tokens.gd` (`UiTokens`) | руками |
| Пиксельные рамки и иконки интерфейса | `assets/ui/frames/*.png` + `frames.json` | генератором `tools/artgen/` |
| Иконки HUD и сенсорного стика | `assets/ui/hud/*.png` | генератором `tools/artgen/hud_icons.py` |
| Цвета мира, которые рисует код (вода, следы, брызги) | `scripts/systems/world_colors.gd` (`WorldColors`) | руками, только из палитры |
| Тема Godot | `resources/ui/ui_theme.tres`, `resources/ui/fonts/` | генератором `tools/build_theme.gd` |
| Компоненты | `scripts/ui/components/` | руками |
| Витрины | `tools/ui_gallery.tscn`, `tools/ui_gallery_overlays.tscn` | руками |

Шрифты: **PressStart2P** для заголовков, кнопок и цифр (размеры кратны 8) и **Handjet**
для текста. Оба поддерживают казахский алфавит, оба под лицензией OFL (`assets/fonts/*-OFL.txt`).

## Как подключить на экране

Пока идёт этап 3, новая тема ставится на корневой узел экрана:
`theme = res://resources/ui/ui_theme.tres`. Когда все экраны переедут, она станет темой
проекта, а старая `sanlaq_theme.tres` будет удалена.

Вид задаётся через `theme_type_variation`, без ручных `theme_override_*`:

| Узел | Варианты |
|---|---|
| `Button` / `PixelButton` | по умолчанию — бордовая кнопка; `ButtonLarge` — главное действие; `ButtonSecondary` — «Артқа», «Жоқ» |
| `Label` | по умолчанию — текст на тёмном; `TitleLabel`, `HeadingLabel`, `SubtitleLabel` (на фоне), `WarningLabel`, `CaptionLabel`, `HudLabel`, `TimerLabel`, `HudTimerLabel` (таймер на плашке HUD); на пергаменте — `InkLabel`, `InkHeadingLabel` |
| `PanelContainer` | по умолчанию — бордовая панель; `ParchmentPanel` — длинный текст; `HudPanel`; `InsetPanel`; `Card`, `CardHover`, `CardSelected`; компактные `CardCompact*` |

## Компоненты

| Компонент | Зачем |
|---|---|
| `PixelButton` | Кнопка высотой не меньше 64 px. С `ornate = true` по бокам появляются ромбы-навершия, как в atilla |
| `ScreenHeader` | «← Артқа», заголовок, подзаголовок, черта с ромбом. Esc = «Артқа», сигнал `back_pressed` |
| `SelectableCard` | Выбираемая карточка (режим, одежда, статья): `selected`, сигнал `pressed` |
| `GemDivider` | Золотая черта с ромбом |
| `Toast` | Короткое сообщение: `show_message(text, seconds)` |
| `Banner` | Полоса через экран: `show_banner(title, subtitle, hold)` |
| `Countdown` | «3, 2, 1, БАСТА!»: `start(3)`, сигнал `finished` |
| `ConfirmDialog` | «Иә / Жоқ» с затемнением: `open()`, сигналы `confirmed` / `cancelled`; подписи кнопок меняются |
| `TimeBar` | Полоска оставшегося времени: `ratio` от 0 до 1, последняя треть — красная |

Компоненты не обращаются к автолоадам: они шлют сигналы, а что делать дальше, решает
экран. Их поведение проверяет `tools/components_test.gd`.

## Подводные камни

- **В шрифтах нет ✓ и ✗.** Используйте иконки `assets/ui/frames/check.png` и
  `cross.png`.
- **Масштаб только целый.** Не растягивайте пиксельные картинки на дробный коэффициент
  и не уменьшайте их с размытием.
- **Пиксель-арт не бывает полупрозрачным.** Затемнения и виньетки делаются цветом с
  альфой, как в `ConfirmDialog`, а не картинкой. Тени и «полупрозрачность» в мире —
  шахматкой из непрозрачных пикселей (тень под ногами, край обзора ловца), эффекты
  не бледнеют, а пропадают по пикселю (`PixelBurst`, звуковые волны, следы).
- **Код рисует на сетке мира.** Всё, что рисуется в `_draw()` или шейдером, округляется
  до `UiTokens.PIXEL` в координатах мира, иначе пиксели «плывут» при движении камеры.

## Как поменять стиль

```bash
# 1. Поправить цвета/размеры в scripts/ui/ui_tokens.gd или рисунок рамок в tools/artgen/ui_frames.py
python tools/artgen/build.py                                       # рамки и иконки
godot --headless --import --path .                                 # импорт новых PNG
godot --headless --path . --script res://tools/build_theme.gd      # тема
tools/run_tests.sh                                                 # в т.ч. style_test
godot --path . --script res://tools/screenshot_screens.gd -- --only=ui_gallery,ui_gallery_overlays
```
