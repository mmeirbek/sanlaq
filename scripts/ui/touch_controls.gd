class_name TouchControls
extends CanvasLayer
## Сенсорное управление: пиксельный стик слева и кнопка способности справа —
## рывок у бегуна (держать), «үн тыңдау» у ловца (нажать). Есть только на
## сенсорных экранах. Раскладка не заходит в вырезы и скругления экрана.

## Ловец нажал кнопку способности.
signal echo_pressed

const THEME := preload("res://resources/ui/ui_theme.tres")
const BASE := preload("res://assets/ui/hud/joystick_base.png")
const KNOB := preload("res://assets/ui/hud/joystick_knob.png")
const SPRINT_ICON := preload("res://assets/ui/hud/sprint.png")
const ECHO_ICON := preload("res://assets/ui/hud/echo.png")
## Насколько далеко ручка уходит от центра стика, px.
const KNOB_TRAVEL := 56.0
const EDGE_MARGIN := 32.0
const ACTION_SIZE := Vector2(112, 112)

var player: Player
var _joy_active := false
var _joy_vec := Vector2.ZERO
var _sprint_held := false
## Кнопка способности — рывок (true) или «үн тыңдау» (false).
var _sprint_mode := true

var _joy_base: TextureRect
var _knob: TextureRect
var _action: PixelButton

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		visible = false
		set_process(false)
		return
	var root := Control.new()
	root.theme = THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_joy_base = TextureRect.new()
	_joy_base.texture = BASE
	_joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_base.gui_input.connect(_on_joy_input)
	root.add_child(_joy_base)
	_knob = TextureRect.new()
	_knob.texture = KNOB
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(_knob)
	_place_knob(Vector2.ZERO)

	_action = PixelButton.new()
	_action.custom_minimum_size = ACTION_SIZE
	_action.focus_mode = Control.FOCUS_NONE
	_action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.icon = SPRINT_ICON if _sprint_mode else ECHO_ICON
	_action.button_down.connect(_on_action_down)
	_action.button_up.connect(func() -> void: _sprint_held = false)
	root.add_child(_action)

	# Экраны бывают любой формы (растяжение canvas_items/expand), и телефон
	# можно повернуть — раскладываем от реального размера при каждом изменении.
	get_viewport().size_changed.connect(_layout_controls)
	_layout_controls()

## Бегун держит кнопку для рывка, ловец нажимает для «үн тыңдау».
func set_sprint_mode(sprint: bool) -> void:
	_sprint_mode = sprint
	if _action:
		_action.icon = SPRINT_ICON if sprint else ECHO_ICON

func _layout_controls() -> void:
	var safe := _safe_rect()
	_joy_base.size = BASE.get_size()
	_joy_base.position = Vector2(safe.position.x + EDGE_MARGIN, safe.end.y - _joy_base.size.y - EDGE_MARGIN)
	_action.size = ACTION_SIZE
	_action.position = safe.end - ACTION_SIZE - Vector2(EDGE_MARGIN, EDGE_MARGIN)

## Безопасная зона экрана в координатах интерфейса.
func _safe_rect() -> Rect2:
	var visible_rect := get_viewport().get_visible_rect()
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_area := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or safe_area.size.x <= 0.0:
		return visible_rect
	var to_ui := visible_rect.size / window_size
	safe_area.position -= Vector2(DisplayServer.window_get_position())
	var safe := Rect2(safe_area.position * to_ui, safe_area.size * to_ui).intersection(visible_rect)
	return safe if safe.has_area() else visible_rect

func _on_action_down() -> void:
	if _sprint_mode:
		_sprint_held = true
	else:
		echo_pressed.emit()

func _on_joy_input(event: InputEvent) -> void:
	var center := _joy_base.size / 2.0
	if event is InputEventScreenTouch:
		_joy_active = event.pressed
		_joy_vec = ((event.position - center) / KNOB_TRAVEL).limit_length(1.0) if event.pressed else Vector2.ZERO
	elif event is InputEventScreenDrag:
		_joy_vec = ((event.position - center) / KNOB_TRAVEL).limit_length(1.0)
	_place_knob(_joy_vec if _joy_active else Vector2.ZERO)

## Ручка на сетке пикселя арта, смещение — доля KNOB_TRAVEL.
func _place_knob(offset: Vector2) -> void:
	var px := float(UiTokens.PIXEL)
	var at := _joy_base.size / 2.0 + offset * KNOB_TRAVEL - KNOB.get_size() / 2.0
	_knob.position = (at / px).round() * px

func _process(_delta: float) -> void:
	if player == null or player.eliminated:
		return
	# Рывок — модификатор: он не забирает управление, иначе нажатие при ходьбе
	# с клавиатуры заменило бы движение нулём.
	var controller := player.get_controller()
	controller.set_touch_sprint_active(_sprint_held)
	controller.touch_override = _joy_active
	if _joy_active:
		controller.set_remote_input(_joy_vec, _sprint_held)
