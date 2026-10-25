class_name TogyzPit
extends BaseButton
## Отау на доске тоғыз құмалақ: выемка в дереве, до 12 камешков и число над
## ней. Число видно всегда; камешки с одного взгляда показывают «много или мало».
## Золотое кольцо — сюда можно ходить, светлое — сюда только что упал камень,
## ромб в красной выемке — тұздық.

const PIT := preload("res://assets/sprites/togyz/pit.png")
const PIT_TUZDYK := preload("res://assets/sprites/togyz/pit_tuzdyk.png")
const RING := preload("res://assets/sprites/togyz/pit_ring.png")
const GLOW := preload("res://assets/sprites/togyz/pit_glow.png")
const TUZDYK_MARK := preload("res://assets/sprites/togyz/tuzdyk_mark.png")
const STONE := preload("res://assets/sprites/togyz/stone.png")

## Камешки лежат сеткой 3×4, снизу вверх; больше 12 — только число.
const STONE_COLUMNS := 3
const STONE_ROWS := 4
const STONE_GAP := 2
const COUNT_HEIGHT := 28
const CAPTION_HEIGHT := 24

var count := 0:
	set(value):
		count = value
		_refresh_labels()
		queue_redraw()
var available := false:
	set(value):
		available = value
		queue_redraw()
var glowing := false:
	set(value):
		glowing = value
		queue_redraw()
var tuzdyk := false:
	set(value):
		tuzdyk = value
		_refresh_labels()
		queue_redraw()
## Подпись под лункой: номер отау 1–9.
var number := 0:
	set(value):
		number = value
		_refresh_labels()

var _count_label: Label
var _caption_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(RING.get_width(), COUNT_HEIGHT + RING.get_height() + CAPTION_HEIGHT)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_count_label = _label("HudLabel", Control.PRESET_TOP_WIDE, COUNT_HEIGHT)
	_caption_label = _label("CaptionLabel", Control.PRESET_BOTTOM_WIDE, CAPTION_HEIGHT)
	# На дереве приглушённый цвет подписи не читается (контраст 2,7) — светлее.
	_caption_label.add_theme_color_override("font_color", UiTokens.PARCHMENT_DARK)


func _label(variation: String, preset: Control.LayoutPreset, height: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(preset)
	if preset == Control.PRESET_TOP_WIDE:
		label.offset_bottom = height
	else:
		label.offset_top = -height
	return label


func _refresh_labels() -> void:
	_count_label.text = "" if tuzdyk else str(count)
	_caption_label.text = tr("тұздық") if tuzdyk else str(number)


func _draw() -> void:
	var px := float(UiTokens.PIXEL)
	var ring_at := (Vector2((size.x - RING.get_width()) / 2.0, COUNT_HEIGHT) / px).floor() * px
	var pit_at := ring_at + (RING.get_size() - PIT.get_size()) / 2.0
	if tuzdyk:
		draw_texture(PIT_TUZDYK, pit_at)
		draw_texture(TUZDYK_MARK, _centered(pit_at, PIT.get_size(), TUZDYK_MARK.get_size()))
	else:
		draw_texture(PIT, pit_at)
		_draw_stones(pit_at)
	if glowing:
		draw_texture(GLOW, ring_at)
	elif available:
		draw_texture(RING, ring_at)


func _draw_stones(pit_at: Vector2) -> void:
	var step := STONE.get_size() + Vector2(STONE_GAP, STONE_GAP)
	var grid := step * Vector2(STONE_COLUMNS, STONE_ROWS) - Vector2(STONE_GAP, STONE_GAP)
	var origin := _centered(pit_at, PIT.get_size(), grid)
	for i in mini(count, STONE_COLUMNS * STONE_ROWS):
		var column := i % STONE_COLUMNS
		@warning_ignore("integer_division")
		var row := STONE_ROWS - 1 - i / STONE_COLUMNS
		draw_texture(STONE, origin + step * Vector2(column, row))


## Левый верхний угол вещи размера inner по центру области, на сетке пикселя арта.
func _centered(at: Vector2, outer: Vector2, inner: Vector2) -> Vector2:
	var px := float(UiTokens.PIXEL)
	return at + (((outer - inner) / 2.0) / px).floor() * px
