class_name Toast
extends PanelContainer
## Короткое сообщение на плашке HUD: «Сізді ұстады!», «Ашылды», подсказки.
## Новое сообщение заменяет текущее и заново отсчитывает время показа.
## Где стоять (обычно — сверху по центру), решает экран.

## Сколько секунд держится сообщение, если не указано иное.
@export var duration: float = 3.2

var _label: Label
var _serial := 0


func _ready() -> void:
	theme_type_variation = "HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Длинный текст растит плашку в обе стороны — она остаётся на месте.
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	visible = false
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func show_message(text: String, seconds: float = -1.0) -> void:
	_serial += 1
	var serial := _serial
	_label.text = text
	visible = true
	await get_tree().create_timer(seconds if seconds > 0.0 else duration).timeout
	if serial == _serial:
		visible = false


func current_text() -> String:
	return _label.text
