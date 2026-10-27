class_name Banner
extends Control
## Полоса через весь экран с крупной надписью: роль в начале раунда, «ЖЕҢІС!»,
## итог мини-игры. Раскрывается по высоте ступенями в пиксель арта, держится
## и сворачивается. Кладётся на весь экран поверх игры.

signal finished

const REVEAL_TIME := 0.25

## Где по высоте экрана середина полосы: 0.5 — по центру. Выше центра —
## если в центре уже что-то есть (например, обратный отсчёт).
@export_range(0.0, 1.0) var center_y := 0.5

var _clip: Control
var _strip: PanelContainer
var _title: Label
var _subtitle: Label
## Новый показ отменяет отложенное скрытие прошлого.
var _serial := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.anchor_right = 1.0
	_clip.anchor_top = center_y
	_clip.anchor_bottom = center_y
	add_child(_clip)

	_strip = PanelContainer.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_strip)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_child(lines)
	_title = Label.new()
	_title.theme_type_variation = "TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_subtitle)


func show_banner(title: String, subtitle: String = "", hold_seconds: float = 2.0) -> void:
	_serial += 1
	var serial := _serial
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	# Боковые края рамки уводим за экран — видна только полоса.
	var height := _strip.get_combined_minimum_size().y
	var edge := UiTokens.SPACE_L
	_strip.anchor_right = 1.0
	_strip.anchor_top = 0.5
	_strip.anchor_bottom = 0.5
	_strip.offset_left = -edge
	_strip.offset_right = edge
	_strip.offset_top = -height / 2
	_strip.offset_bottom = height / 2
	visible = true

	await _animate_height(0.0, height)
	await get_tree().create_timer(hold_seconds, false).timeout
	if serial != _serial:
		return
	await _animate_height(height, 0.0)
	if serial != _serial:
		return
	visible = false
	finished.emit()


func _animate_height(from: float, to: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_clip_height, from, to, REVEAL_TIME)
	await tween.finished


## Высота окна полосы, округлённая до двух пикселей арта, — без размытых
## промежуточных кадров.
func _set_clip_height(height: float) -> void:
	var step := UiTokens.PIXEL * 2
	var half := roundf(height / 2 / step) * step
	_clip.offset_top = -half
	_clip.offset_bottom = half
