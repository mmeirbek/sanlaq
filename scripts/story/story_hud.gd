class_name StoryHud
extends Control
## HUD «Дала жолы»: слева сверху — глава, цель и шаг «3 / 7», справа — XP и
## пауза, под ними — баннер задания, ниже — тост. На телефоне кнопку «сөйлесу»
## даёт TouchControls.

signal pause_requested

var _chapter: Label
var _objective: Label
var _progress: Label
var _xp: Label
var _task_panel: PanelContainer
var _task_picture: TextureRect
var _task_title: Label
var _task_hint: Label
var _task_status: Label
var _toast: Toast


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var plate := PanelContainer.new()
	plate.theme_type_variation = "HudPanel"
	plate.position = Vector2(UiTokens.SPACE_S, UiTokens.SPACE_S)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	plate.add_child(column)
	_chapter = _label(column, "CaptionLabel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_S)
	column.add_child(row)
	_objective = _label(row, "HudLabel")
	_progress = _label(row, "HeadingLabel")

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", UiTokens.SPACE_S)
	add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, UiTokens.SPACE_S)
	var xp_plate := PanelContainer.new()
	xp_plate.theme_type_variation = "HudPanel"
	right.add_child(xp_plate)
	_xp = _label(xp_plate, "HudLabel")
	var pause := PixelButton.new()
	pause.text = "II"
	pause.theme_type_variation = "ButtonSecondary"
	pause.focus_mode = Control.FOCUS_NONE
	pause.custom_minimum_size = Vector2(UiTokens.TOUCH_MIN, UiTokens.TOUCH_MIN)
	pause.pressed.connect(pause_requested.emit)
	right.add_child(pause)
	# Раскладка справа зависит от ширины текста XP — пересчитываем.
	right.resized.connect(func() -> void:
		right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, UiTokens.SPACE_S))

	_task_panel = PanelContainer.new()
	_task_panel.visible = false
	_task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_task_panel)
	_task_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_task_panel.position.y = 104
	var task_row := HBoxContainer.new()
	task_row.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_task_panel.add_child(task_row)
	_task_picture = TextureRect.new()
	_task_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	task_row.add_child(_task_picture)
	var task_box := VBoxContainer.new()
	task_box.add_theme_constant_override("separation", 0)
	task_row.add_child(task_box)
	_task_title = _label(task_box, "HeadingLabel")
	_task_hint = _label(task_box, "CaptionLabel")
	_task_status = _label(task_box, "HudLabel")
	for label in [_task_title, _task_hint, _task_status]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_toast = Toast.new()
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 272


func set_chapter(title: String) -> void:
	_chapter.text = tr(title)


func set_objective(text: String, step: int, total: int) -> void:
	_objective.text = text
	_progress.text = "%d / %d" % [mini(step + 1, total), total]
	_progress.visible = step < total


func set_xp(xp: int) -> void:
	_xp.text = "XP %d" % xp


## picture — что искать или нести, в своём размере (не больше иконки 64×64).
func show_task(title: String, hint: String, picture: Texture2D = null) -> void:
	_task_picture.texture = picture
	_task_picture.visible = picture != null
	_task_title.text = tr(title)
	_task_hint.text = tr(hint)
	_task_status.text = ""
	_task_panel.visible = true
	_recenter_task()


func set_task_status(text: String) -> void:
	_task_status.text = text
	_recenter_task()


func hide_task() -> void:
	_task_panel.visible = false


func toast(text: String, seconds := 2.5) -> void:
	_toast.show_message(text, seconds)


func _recenter_task() -> void:
	_task_panel.reset_size()
	_task_panel.position.x = (size.x - _task_panel.size.x) / 2


func _label(parent: Control, variation: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
