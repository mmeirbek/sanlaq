class_name StepDiagram
extends Control
## Схема одного шага объяснения: что происходит на доске или на экране именно
## на этом шаге. Рисуется кодом, а не картинкой, по трём причинам: показывает
## точное состояние игры (какая отау выбрана, сколько в ней құмалақ), внутри нет
## ни одного слова — значит локализацию не ломает, и меняется вместе с правилами.
##
## Внутренние координаты задаются в условной сетке DESIGN и вписываются в узел
## целиком, с сохранением пропорций, — схему можно класть в ячейку любого размера.

const DESIGN := Vector2(200.0, 100.0)

## Сколько шагов умеет рисовать схема для каждого режима. Если в .tres шагов
## станет больше, modes_smoke_test это поймает: лишний шаг молча получил бы
## картинку от последнего, и рисунок разошёлся бы с текстом.
const STEPS_DRAWN := {
	"sokyroteke": 4,
	"abai_says": 4,
	"togyz_qumalaq": 4,
}

## Цвета берём из общих токенов, чтобы схема выглядела частью игры, а не вставкой.
const INK := Color(0.039, 0.169, 0.239)
const MUTED := Color(0.55, 0.5, 0.44)
const FIELD := Color(0.086, 0.216, 0.290)

@export var mode_id: String = "":
	set(value):
		mode_id = value
		queue_redraw()
@export var step: int = 0:
	set(value):
		step = value
		queue_redraw()

var _scale: float = 1.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5

	match mode_id:
		"togyz_qumalaq":
			_draw_togyz()
		"abai_says":
			_draw_abai()
		"sokyroteke":
			_draw_chase()

# --- Перевод условных координат в экранные -----------------------------------

func _p(x: float, y: float) -> Vector2:
	return _origin + Vector2(x, y) * _scale

func _s(v: float) -> float:
	return v * _scale

func _rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_p(x, y), Vector2(w, h) * _scale)

# --- Примитивы ---------------------------------------------------------------

func _panel(area: Rect2, fill: Color, border: Color, radius: float, width: float = 1.5) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(int(maxf(1.0, _s(width))))
	box.set_corner_radius_all(int(_s(radius)))
	draw_style_box(box, area)

func _text(center: Vector2, value: String, px: float, color: Color) -> void:
	var font := SanlaqDesignTokens.FONT_BOLD
	var font_size := int(maxf(6.0, _s(px)))
	var width := _s(60.0)
	draw_string(font, center + Vector2(-width * 0.5, font_size * 0.36), value,
		HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)

## Отау: скруглённая ячейка с числом. `accent` — выбранная либо ключевая для шага.
func _pit(cx: float, cy: float, value: String, accent: bool = false, tuzdyk: bool = false) -> void:
	var area := _rect(cx - 9.0, cy - 10.0, 18.0, 20.0)
	if tuzdyk:
		_panel(area, FIELD, SanlaqDesignTokens.GOLD, 5.0, 2.0)
	elif accent:
		_panel(area, SanlaqDesignTokens.GOLD_PALE, SanlaqDesignTokens.GOLD_DARK, 5.0, 2.0)
	else:
		_panel(area, SanlaqDesignTokens.CREAM_LIGHT, Color(0.80, 0.74, 0.62), 5.0, 1.0)
	_text(_p(cx, cy), value, 11.0, SanlaqDesignTokens.GOLD if tuzdyk else INK)

func _arrow(from_x: float, from_y: float, to_x: float, to_y: float, color: Color) -> void:
	var a := _p(from_x, from_y)
	var b := _p(to_x, to_y)
	draw_line(a, b, color, _s(1.8))
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var head := _s(4.0)
	draw_colored_polygon(PackedVector2Array([
		b, b - dir * head + side * head * 0.6, b - dir * head - side * head * 0.6,
	]), color)

func _check(cx: float, cy: float, color: Color) -> void:
	var w := _s(2.4)
	draw_line(_p(cx - 6.0, cy), _p(cx - 2.0, cy + 5.0), color, w)
	draw_line(_p(cx - 2.0, cy + 5.0), _p(cx + 6.0, cy - 6.0), color, w)

func _cross(cx: float, cy: float, color: Color) -> void:
	var w := _s(2.4)
	draw_line(_p(cx - 5.0, cy - 5.0), _p(cx + 5.0, cy + 5.0), color, w)
	draw_line(_p(cx + 5.0, cy - 5.0), _p(cx - 5.0, cy + 5.0), color, w)

## Фигурка игрока: голова и плечи. Достаточно, чтобы прочиталось «человек».
func _figure(cx: float, cy: float, color: Color) -> void:
	draw_circle(_p(cx, cy - 7.0), _s(4.5), color)
	_panel(_rect(cx - 6.0, cy - 1.0, 12.0, 12.0), color, color, 4.0, 1.0)

# --- Тоғыз құмалақ -----------------------------------------------------------

func _draw_togyz() -> void:
	match step:
		0:
			_togyz_sowing()
		1:
			_togyz_capture(false)
		2:
			_togyz_capture(true)
		_:
			_togyz_win()

## Шаг 1: доска целиком, выбранная отау и направление раздачи.
func _togyz_sowing() -> void:
	for i in 9:
		var x := 18.0 + i * 20.5
		_pit(x, 26.0, "9")
	for i in 9:
		var x := 18.0 + i * 20.5
		# В выбранной остался один құмалақ, следующие четыре получили по одному.
		if i == 0:
			_pit(x, 68.0, "1", true)
		elif i <= 4:
			_pit(x, 68.0, "10")
		else:
			_pit(x, 68.0, "9")
	_arrow(18.0, 84.0, 97.0, 84.0, SanlaqDesignTokens.GOLD_DARK)

## Шаги 2 и 3: последний құмалақ лёг в отау соперника — взятие либо тұздық.
func _togyz_capture(tuzdyk: bool) -> void:
	for i in 3:
		var x := 40.0 + i * 24.0
		if i == 1:
			_pit(x, 30.0, "3" if tuzdyk else "4", not tuzdyk, tuzdyk)
		else:
			_pit(x, 30.0, "9")
	for i in 3:
		_pit(40.0 + i * 24.0, 78.0, "9")

	# Казан справа: туда уходит взятое.
	_panel(_rect(140.0, 34.0, 44.0, 34.0), FIELD, SanlaqDesignTokens.GOLD, 7.0, 2.0)
	_text(_p(162.0, 51.0), "+3" if tuzdyk else "+4", 15.0, SanlaqDesignTokens.GOLD)
	_arrow(76.0, 34.0, 136.0, 46.0, SanlaqDesignTokens.GOLD_DARK)

## Шаг 4: победа по счёту в казанах.
func _togyz_win() -> void:
	_panel(_rect(22.0, 26.0, 66.0, 48.0), FIELD, SanlaqDesignTokens.GOLD, 9.0, 2.5)
	_text(_p(55.0, 50.0), "82", 26.0, SanlaqDesignTokens.GOLD)
	_panel(_rect(112.0, 32.0, 60.0, 38.0), FIELD.lerp(Color.BLACK, 0.15),
		Color(0.42, 0.44, 0.42), 9.0, 1.5)
	_text(_p(142.0, 51.0), "80", 20.0, Color(0.62, 0.62, 0.58))
	_check(55.0, 16.0, SanlaqDesignTokens.GREEN_ACCENT)

# --- Абай айтады -------------------------------------------------------------

func _draw_abai() -> void:
	match step:
		0:
			_abai_sequence(true)
		1:
			_abai_sequence(false)
		2:
			_abai_growth()
		_:
			_abai_turns()

## Шаги 1 и 2: та же сетка карточек — сначала её показывает Абай, потом повторяет
## игрок. Разница в том, что подсвечено и куда указывает касание.
func _abai_sequence(showing: bool) -> void:
	var lit := 1 if showing else 4
	for i in 6:
		var col := i % 3
		var row := i / 3
		var x := 30.0 + col * 48.0
		var y := 32.0 + row * 40.0
		var area := _rect(x - 20.0, y - 17.0, 40.0, 34.0)
		if i == lit:
			_panel(area, SanlaqDesignTokens.GOLD_PALE, SanlaqDesignTokens.GOLD_DARK, 6.0, 2.5)
		else:
			_panel(area, SanlaqDesignTokens.CREAM_LIGHT, Color(0.80, 0.74, 0.62), 6.0, 1.0)
		draw_circle(_p(x, y), _s(7.0), Color(0.85, 0.78, 0.66))

	var lit_x := 30.0 + (lit % 3) * 48.0
	var lit_y := 32.0 + (lit / 3) * 40.0
	if showing:
		# Порядок показа: круги-волны от подсвеченной карточки.
		for r in [21.0, 26.0]:
			draw_arc(_p(lit_x, lit_y), _s(r), 0.0, TAU, 32,
				Color(SanlaqDesignTokens.GOLD_DARK, 0.5), _s(1.2))
	else:
		# Касание: палец игрока по той же карточке.
		draw_circle(_p(lit_x + 10.0, lit_y + 8.0), _s(5.5), SanlaqDesignTokens.GOLD_DARK)
		_check(lit_x - 26.0, lit_y, SanlaqDesignTokens.GREEN_ACCENT)

## Шаг 3: тізбек растёт на одну карточку за раунд.
func _abai_growth() -> void:
	for row in 3:
		var y := 24.0 + row * 26.0
		_text(_p(44.0, y), "%d" % (row + 1), 13.0, MUTED)
		for i in row + 2:
			var area := _rect(60.0 + i * 22.0, y - 8.0, 18.0, 16.0)
			_panel(area, SanlaqDesignTokens.GOLD_PALE, SanlaqDesignTokens.GOLD_DARK, 4.0, 1.2)

## Шаг 4: устройство переходит по кругу, ошибившийся выбывает.
func _abai_turns() -> void:
	var colors := [SanlaqDesignTokens.GOLD_DARK, MUTED, MUTED]
	for i in 3:
		var x := 46.0 + i * 54.0
		_figure(x, 46.0, colors[i])
	_arrow(62.0, 74.0, 92.0, 74.0, SanlaqDesignTokens.GOLD_DARK)
	_arrow(116.0, 74.0, 146.0, 74.0, SanlaqDesignTokens.GOLD_DARK)
	_cross(154.0, 26.0, SanlaqDesignTokens.RED_ACCENT)

# --- Соқыртеке ---------------------------------------------------------------

func _draw_chase() -> void:
	match step:
		0:
			_chase_vision()
		1:
			_chase_catch()
		2:
			_chase_answer()
		_:
			_chase_field()

## Шаг 1: круг света. Внутри видно, снаружи — нет.
func _chase_vision() -> void:
	_panel(_rect(0.0, 0.0, 200.0, 100.0), FIELD, FIELD, 8.0, 1.0)
	draw_circle(_p(70.0, 50.0), _s(38.0), Color(0.918, 0.761, 0.357, 0.18))
	draw_arc(_p(70.0, 50.0), _s(38.0), 0.0, TAU, 48,
		Color(SanlaqDesignTokens.GOLD, 0.55), _s(1.2))
	_figure(70.0, 50.0, SanlaqDesignTokens.GOLD)
	_figure(100.0, 60.0, SanlaqDesignTokens.CREAM_LIGHT)
	# За кругом света бегуны только угадываются.
	_figure(150.0, 34.0, Color(0.30, 0.40, 0.46))
	_figure(172.0, 70.0, Color(0.30, 0.40, 0.46))

## Шаг 2: поймал — узнай одежду по картинке.
func _chase_catch() -> void:
	_panel(_rect(0.0, 0.0, 200.0, 100.0), FIELD, FIELD, 8.0, 1.0)
	_figure(30.0, 52.0, SanlaqDesignTokens.GOLD)
	_figure(58.0, 52.0, SanlaqDesignTokens.CREAM_LIGHT)
	_text(_p(44.0, 24.0), "!", 18.0, SanlaqDesignTokens.GOLD)

	_panel(_rect(90.0, 16.0, 96.0, 68.0), SanlaqDesignTokens.CREAM_LIGHT,
		SanlaqDesignTokens.GOLD, 7.0, 1.5)
	_panel(_rect(98.0, 24.0, 28.0, 28.0), Color(0.85, 0.78, 0.66), Color(0.64, 0.42, 0.14), 4.0, 1.0)
	for i in 3:
		var y := 26.0 + i * 17.0
		var chosen := i == 1
		_panel(_rect(132.0, y, 46.0, 12.0),
			SanlaqDesignTokens.GOLD_PALE if chosen else Color(0.90, 0.86, 0.78),
			SanlaqDesignTokens.GOLD_DARK if chosen else Color(0.80, 0.74, 0.62), 3.0, 1.0)

## Шаг 3: цена ответа — выбывание соперника либо своё замедление.
func _chase_answer() -> void:
	_panel(_rect(0.0, 0.0, 200.0, 100.0), FIELD, FIELD, 8.0, 1.0)
	_panel(_rect(6.0, 20.0, 86.0, 60.0), Color(0.90, 0.95, 0.88),
		SanlaqDesignTokens.GREEN_ACCENT, 8.0, 1.5)
	_check(38.0, 44.0, SanlaqDesignTokens.GREEN_ACCENT)
	_figure(64.0, 52.0, Color(SanlaqDesignTokens.GREEN_ACCENT, 0.35))

	_panel(_rect(108.0, 20.0, 86.0, 60.0), Color(0.98, 0.90, 0.88),
		SanlaqDesignTokens.RED_ACCENT, 8.0, 1.5)
	_cross(134.0, 44.0, SanlaqDesignTokens.RED_ACCENT)
	draw_arc(_p(164.0, 50.0), _s(16.0), -PI * 0.5, PI * 0.9, 28,
		SanlaqDesignTokens.RED_ACCENT, _s(2.0))
	_text(_p(164.0, 50.0), "5", 16.0, SanlaqDesignTokens.RED_ACCENT)

## Шаг 4: что есть на карте и сколько времени.
func _chase_field() -> void:
	_panel(_rect(0.0, 0.0, 200.0, 100.0), FIELD, FIELD, 8.0, 1.0)
	# Вода.
	_panel(_rect(12.0, 54.0, 54.0, 32.0), Color(0.25, 0.52, 0.62), Color(0.35, 0.66, 0.76), 12.0, 1.5)
	# Киіз үй: купол и основание.
	draw_colored_polygon(PackedVector2Array([
		_p(96.0, 30.0), _p(122.0, 56.0), _p(70.0, 56.0),
	]), Color(0.90, 0.86, 0.78))
	_panel(_rect(74.0, 56.0, 44.0, 24.0), Color(0.82, 0.76, 0.66), Color(0.64, 0.42, 0.14), 4.0, 1.0)
	# Таймер.
	draw_arc(_p(160.0, 50.0), _s(24.0), -PI * 0.5, PI * 1.1, 40, SanlaqDesignTokens.GOLD, _s(2.4))
	_text(_p(160.0, 50.0), "90", 18.0, SanlaqDesignTokens.GOLD)
