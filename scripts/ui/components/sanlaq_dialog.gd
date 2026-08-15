class_name SanlaqDialog
extends Control
## Модальное окно подтверждения: затемнение + карточка с заголовком,
## сообщением и кнопками «Да / Отмена». Сигналы confirmed / cancelled.

signal confirmed
signal cancelled

@export var dialog_title := ""
@export var dialog_message := ""
@export var confirm_text := "Иә"
@export var cancel_text := "Жоқ"

@onready var _title_label: Label = %TitleLabel
@onready var _message_label: Label = %MessageLabel
@onready var _confirm_btn: Button = %ConfirmBtn
@onready var _cancel_btn: Button = %CancelBtn

func _ready() -> void:
	_title_label.text = dialog_title
	_message_label.text = dialog_message
	_confirm_btn.text = confirm_text
	_cancel_btn.text = cancel_text
	_title_label.visible = not dialog_title.is_empty()
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)
	visible = false

func open() -> void:
	visible = true

func close() -> void:
	visible = false

func _on_confirm() -> void:
	visible = false
	confirmed.emit()

func _on_cancel() -> void:
	visible = false
	cancelled.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
