class_name ConfirmDialog
extends Control
## Модальное окно подтверждения: затемнение и панель с заголовком, текстом и
## кнопками «Иә / Жоқ». Esc — это «Жоқ». API тот же, что у SanlaqDialog,
## чтобы экраны переходили на него без переделок.

signal confirmed
signal cancelled

## Затемнение под окном: контурный цвет, приглушённый до 75%.
const DIM := Color(UiTokens.OUTLINE, 0.75)

@export var dialog_title := ""
@export var dialog_message := ""
@export var confirm_text := "Иә"
@export var cancel_text := "Жоқ"

var _title_label: Label
var _message_label: Label
var _confirm_button: PixelButton
var _cancel_button: PixelButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.theme_type_variation = "HeadingLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)
	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.custom_minimum_size.x = 480
	box.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiTokens.SPACE_M)
	box.add_child(buttons)
	_cancel_button = PixelButton.new()
	_cancel_button.theme_type_variation = "ButtonSecondary"
	_cancel_button.pressed.connect(_close.bind(cancelled))
	buttons.add_child(_cancel_button)
	_confirm_button = PixelButton.new()
	_confirm_button.pressed.connect(_close.bind(confirmed))
	buttons.add_child(_confirm_button)


func open() -> void:
	_title_label.text = dialog_title
	_title_label.visible = not dialog_title.is_empty()
	_message_label.text = dialog_message
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	visible = true
	# Фокус на безопасном варианте: случайный Enter не подтвердит выход.
	_cancel_button.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(cancelled)


func _close(outcome: Signal) -> void:
	visible = false
	outcome.emit()
