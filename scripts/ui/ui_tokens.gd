class_name UiTokens
## Дизайн-токены пиксельного стиля САҢЛАҚ (по образцу atilla).
##
## Единственный источник цветов, шрифтов и размеров интерфейса:
## - тему resources/ui/ui_theme.tres собирает из них tools/build_theme.gd;
## - генератор пиксель-арта tools/artgen читает отсюда палитру — строки вида
##   const ИМЯ := Color("rrggbb"). Меняя цвет, перегенерируйте арт и тему.
##
## Правила стиля — docs/REDESIGN_PLAN.md, раздел «Единый стиль».

# --- Палитра ---------------------------------------------------------------

## Самый тёмный цвет: контур спрайтов и рамок.
const OUTLINE := Color("261612")
## «Чернила»: фон HUD и тёмных плашек, текст на светлом.
const INK := Color("2b1a14")
const INK_SOFT := Color("3a2419")

## Бордо — основная заливка панелей и кнопок.
const BURGUNDY := Color("6d1d17")
const BURGUNDY_DARK := Color("471310")
const BURGUNDY_LIGHT := Color("8b2e24")

## Золото — рамки, заголовки, акценты. Светлое — блик, тёмное — тень рамки.
const GOLD := Color("d99a55")
const GOLD_LIGHT := Color("f6cc7a")
const GOLD_DARK := Color("965c2a")
## Тёплая подсветка: таймер, выбранное.
const EMBER := Color("e7a55b")

## Текст и светлые панели.
const CREAM := Color("f7e6d1")
const PARCHMENT := Color("f7f1e3")
const PARCHMENT_DARK := Color("e2cfae")
## Второстепенный текст и неактивные элементы.
const MUTED := Color("b89b7e")

## Смысловые цвета. Роли всегда показываются цветом И иконкой — не только цветом.
const SEEKER := Color("c4452f")
const RUNNER := Color("4f7fc2")
const SUCCESS := Color("7aa04a")
const DANGER := Color("c4452f")

# --- Пиксельная сетка ------------------------------------------------------

## Один пиксель арта в пикселях базового разрешения 1280×720. Весь арт
## интерфейса и мира рисуется на этой сетке; масштаб только целый.
const PIXEL := 2

# --- Шрифты ----------------------------------------------------------------

## Пиксельный шрифт: заголовки, кнопки, цифры. Его глифы стоят на сетке 8 px,
## поэтому размеры кратны 8: при 16 px один пиксель глифа = один пиксель арта.
const FONT_DISPLAY := preload("res://assets/fonts/PressStart2P-Regular.ttf")
## Читаемый пиксельный шрифт для длинного текста (вариации веса — в теме).
const FONT_BODY := preload("res://assets/fonts/Handjet-Variable.ttf")

const DISPLAY_SMALL := 16
const DISPLAY_MEDIUM := 24
const DISPLAY_LARGE := 32
const DISPLAY_HERO := 48

const BODY_SMALL := 20
const BODY := 24
const BODY_LARGE := 30

## Насыщенность Handjet (ось wght, 100–900).
const BODY_WEIGHT := 500
const BODY_WEIGHT_BOLD := 700

# --- Отступы и размеры -----------------------------------------------------

## Шаг отступов — 4 пикселя арта.
const SPACE_XS := 8
const SPACE_S := 16
const SPACE_M := 24
const SPACE_L := 32
const SPACE_XL := 48

## Минимальная высота любой нажимаемой кнопки — удобно пальцем на телефоне.
const TOUCH_MIN := 64
