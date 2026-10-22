class_name Countdown
extends CenterContainer
## Обратный отсчёт «3, 2, 1, БАСТА!» крупными цифрами на тёмном диске — старт
## раунда или мини-игры. Кладётся на весь экран; не перехватывает ввод.

signal finished

const DISC := preload("res://assets/ui/frames/countdown_disc.png")

## Секунд на каждую цифру.
@export var step_time: float = 1.0

var _label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var disc := TextureRect.new()
	disc.texture = DISC
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(disc)
	_label = Label.new()
	_label.theme_type_variation = "TimerLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	disc.add_child(_label)


func start(from: int = 3) -> void:
	visible = true
	for number in range(from, 0, -1):
		_show(str(number), UiTokens.DISPLAY_HERO)
		await get_tree().create_timer(step_time).timeout
	# Слово шире цифры — шрифт меньше, чтобы уместиться на диске.
	_show(tr("БАСТА!"), UiTokens.DISPLAY_MEDIUM)
	await get_tree().create_timer(step_time * 0.6).timeout
	visible = false
	finished.emit()


func current_text() -> String:
	return _label.text


func _show(text: String, font_size: int) -> void:
	_label.text = text
	_label.add_theme_font_size_override("font_size", font_size)
