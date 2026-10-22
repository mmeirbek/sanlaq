class_name GemDivider
extends Control
## Золотая черта с ромбом посередине — разделитель под заголовками, как в
## титрах глав atilla.

const GEM := preload("res://assets/ui/frames/divider_gem.png")


func _ready() -> void:
	custom_minimum_size.y = GEM.get_height()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var middle := float(GEM.get_height() / 2 - UiTokens.PIXEL / 2)
	# Черта в пиксель арта толщиной, под ней тень — как у рамок.
	draw_rect(Rect2(0, middle, size.x, UiTokens.PIXEL), UiTokens.GOLD)
	draw_rect(Rect2(0, middle + UiTokens.PIXEL, size.x, UiTokens.PIXEL), UiTokens.OUTLINE)
	var gem_x := floorf((size.x - GEM.get_width()) / 2 / UiTokens.PIXEL) * UiTokens.PIXEL
	draw_texture(GEM, Vector2(gem_x, 0))
