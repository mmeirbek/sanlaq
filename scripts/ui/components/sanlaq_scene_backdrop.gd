class_name SanlaqSceneBackdrop
extends Control

enum Variant { LOBBY, WARDROBE, CODEX, RESULTS }
@export var variant: Variant = Variant.LOBBY

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	match variant:
		Variant.WARDROBE: _draw_wardrobe()
		Variant.CODEX: _draw_codex()
		Variant.RESULTS: _draw_results()
		_: _draw_lobby()

func _draw_lobby() -> void:
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("dce9cc"))
	draw_rect(Rect2(0, 0, size.x, h * 0.42), Color("8fc6dc"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, h * 0.51), Vector2(size.x * .22, h * .35), Vector2(size.x * .48, h * .50),
		Vector2(size.x * .72, h * .32), Vector2(size.x, h * .48), Vector2(size.x, h), Vector2(0, h),
	]), Color("91ad62"))
	_draw_yurt(Vector2(size.x * .13, h * .65), 0.72)
	_draw_yurt(Vector2(size.x * .87, h * .62), 0.55)
	_draw_flag(Vector2(size.x * .76, h * .26), 1.0)

func _draw_wardrobe() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("3e2a20"))
	for x in range(-80, int(size.x) + 100, 120):
		draw_rect(Rect2(x, 0, 72, size.y), Color("59372a"))
		draw_line(Vector2(x + 8, 0), Vector2(x + 8, size.y), Color(0.88, 0.65, 0.34, 0.16), 2.0)
	var ring := Vector2(size.x * .76, size.y * .42)
	for r in [230.0, 180.0, 128.0]:
		draw_arc(ring, r, 0, TAU, 36, Color(0.92, 0.72, 0.37, 0.16), 3.0, true)

func _draw_codex() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e7d2a2"))
	for y in range(70, int(size.y), 64):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.48, 0.29, 0.14, 0.09), 2.0)
	var col := Color(0.53, 0.31, 0.14, 0.16)
	for x in [80.0, size.x - 80.0]:
		draw_circle(Vector2(x, size.y * .50), 118, col, false, 5.0, true)
		draw_circle(Vector2(x, size.y * .50), 74, col, false, 3.0, true)

func _draw_results() -> void:
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("132d4b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, h * .65), Vector2(size.x * .30, h * .46), Vector2(size.x * .62, h * .66),
		Vector2(size.x, h * .42), Vector2(size.x, h), Vector2(0, h),
	]), Color("1c4a57"))
	for i in range(18):
		var x := float((i * 97) % int(size.x))
		var y := float(46 + (i * 61) % int(h * .48))
		draw_circle(Vector2(x, y), 2.0, Color("f6df9c"))
	draw_circle(Vector2(size.x * .83, h * .18), 46, Color("f5d785"))

func _draw_yurt(pos: Vector2, scale_factor: float) -> void:
	var body := Rect2(pos + Vector2(-72, -4) * scale_factor, Vector2(144, 66) * scale_factor)
	draw_rect(body, Color("f4e3bd"))
	draw_arc(pos + Vector2(0, -4) * scale_factor, 72 * scale_factor, PI, TAU, 22, Color("704329"), 3.0, true)
	draw_line(pos + Vector2(-72, -4) * scale_factor, pos + Vector2(72, -4) * scale_factor, Color("b94f38"), 6.0, true)
	draw_rect(Rect2(pos + Vector2(-16, 25) * scale_factor, Vector2(32, 37) * scale_factor), Color("704329"))

func _draw_flag(pos: Vector2, scale_factor: float) -> void:
	draw_line(pos, pos + Vector2(0, 144) * scale_factor, Color("56432e"), 4.0, true)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(2, 8) * scale_factor, pos + Vector2(72, 30) * scale_factor,
		pos + Vector2(2, 55) * scale_factor,
	]), Color("b94736"))
