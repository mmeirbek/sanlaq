class_name TimeBar
extends Control
## Полоска оставшегося времени: тёмный жёлоб в контуре и заливка, которая
## убывает ступенями в два пикселя арта. Последняя треть — тревожным цветом.

## Ниже этой доли заливка красная.
const WARNING_RATIO := 1.0 / 3.0

## Доля оставшегося времени, 0..1.
var ratio := 1.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(0, UiTokens.PIXEL * 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var px := float(UiTokens.PIXEL)
	draw_rect(Rect2(Vector2.ZERO, size), UiTokens.OUTLINE)
	var groove := Rect2(Vector2(px, px), size - Vector2(px, px) * 2.0)
	draw_rect(groove, UiTokens.INK)
	var step := px * 2.0
	var width := floorf(groove.size.x * ratio / step) * step
	if width <= 0.0:
		return
	var fill := UiTokens.DANGER if ratio < WARNING_RATIO else UiTokens.EMBER
	draw_rect(Rect2(groove.position, Vector2(width, groove.size.y)), fill)
	# Блик в пиксель арта сверху — как у остальных пиксельных заливок.
	draw_rect(Rect2(groove.position, Vector2(width, px)), UiTokens.GOLD_LIGHT)
