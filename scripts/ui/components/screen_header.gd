class_name ScreenHeader
extends VBoxContainer
## Шапка экрана: «Артқа» слева, заголовок с подзаголовком, черта с ромбом.
## Esc (ui_cancel) действует как «Артқа». Куда возвращаться, решает экран —
## по сигналу back_pressed.

signal back_pressed

@export var title: String = "":
	set(value):
		title = value
		_apply()
@export var subtitle: String = "":
	set(value):
		subtitle = value
		_apply()
## Без кнопки — для экранов верхнего уровня.
@export var show_back: bool = true:
	set(value):
		show_back = value
		_apply()

var _title_label: Label
var _subtitle_label: Label
var _back_button: PixelButton


func _ready() -> void:
	add_theme_constant_override("separation", UiTokens.SPACE_XS)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_M)
	add_child(row)

	_back_button = PixelButton.new()
	_back_button.text = "← Артқа"
	_back_button.theme_type_variation = "ButtonSecondary"
	_back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(back_pressed.emit)
	row.add_child(_back_button)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(titles)
	_title_label = Label.new()
	_title_label.theme_type_variation = "TitleLabel"
	titles.add_child(_title_label)
	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = "CaptionLabel"
	titles.add_child(_subtitle_label)

	add_child(GemDivider.new())
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if show_back and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


func _apply() -> void:
	if not is_node_ready():
		return
	_title_label.text = title
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
	_back_button.visible = show_back
