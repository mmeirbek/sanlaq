class_name SanlaqMainBackdrop
extends Control
## Фоновое изображение степи для главного меню.

var _texture: Texture2D = preload("res://assets/ui/backgrounds/bg_main_menu.jpg")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
