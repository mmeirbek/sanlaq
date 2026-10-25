class_name SelectableCard
extends PanelContainer
## Карточка, которую можно выбрать: режим игры, предмет одежды, статья.
## Содержимое (иконка, подписи) кладёт экран дочерними узлами; карточка
## отвечает за вид (Card / CardHover / CardSelected из темы) и за нажатие
## мышью, пальцем и с клавиатуры.

signal pressed

@export var selected: bool = false:
	set(value):
		selected = value
		_refresh()
## Узкие отступы — для плотных списков (роли, предметы шкафа).
@export var compact: bool = false:
	set(value):
		compact = value
		_refresh()

var _hovered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_refresh()


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	var clicked := mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed
	if clicked or event.is_action_pressed("ui_accept"):
		accept_event()
		pressed.emit()


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh()


func _refresh() -> void:
	var base := "CardCompact" if compact else "Card"
	if selected:
		theme_type_variation = base + "Selected"
	elif _hovered:
		theme_type_variation = base + "Hover"
	else:
		theme_type_variation = base
