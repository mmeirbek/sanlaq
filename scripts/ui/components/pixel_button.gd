class_name PixelButton
extends Button
## Кнопка в пиксельном стиле. Вид (рамки, шрифт, цвета, «утопленное» нажатие)
## задаёт тема ui_theme.tres через theme_type_variation: Button, ButtonLarge,
## ButtonSecondary. Здесь — то, чего в теме нет: высота под палец и ромбы-
## навершия по бокам, как у главных кнопок atilla.

const CAP_LEFT := preload("res://assets/ui/frames/cap_left.png")
const CAP_RIGHT := preload("res://assets/ui/frames/cap_right.png")
## Насколько перемычка навершия заходит на рамку кнопки (3 пикселя арта —
## контур и золотое кольцо).
const CAP_OVERLAP := 3 * UiTokens.PIXEL

## Ромбы по бокам — для главных действий экрана (меню, «Ойнау»).
@export var ornate: bool = false:
	set(value):
		ornate = value
		_rebuild_caps()

var _caps: Array[TextureRect] = []


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, UiTokens.TOUCH_MIN)
	_rebuild_caps()


func _rebuild_caps() -> void:
	if not is_node_ready():
		return
	for cap in _caps:
		cap.queue_free()
	_caps.clear()
	if ornate:
		_caps.append(_add_cap(CAP_LEFT, 0.0, -CAP_LEFT.get_width() + CAP_OVERLAP))
		_caps.append(_add_cap(CAP_RIGHT, 1.0, -CAP_OVERLAP))


## Навершие висит на левом или правом краю (anchor_x = 0 или 1) по центру
## высоты; offset_x — сдвиг его левого края от этого края.
func _add_cap(texture: Texture2D, anchor_x: float, offset_x: int) -> TextureRect:
	var cap := TextureRect.new()
	cap.texture = texture
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.anchor_left = anchor_x
	cap.anchor_right = anchor_x
	cap.anchor_top = 0.5
	cap.anchor_bottom = 0.5
	cap.offset_left = offset_x
	cap.offset_right = offset_x + texture.get_width()
	cap.offset_top = -texture.get_height() / 2
	cap.offset_bottom = texture.get_height() / 2
	add_child(cap, false, Node.INTERNAL_MODE_FRONT)
	return cap
