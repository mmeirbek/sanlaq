class_name SanlaqMainBackdrop
extends Control
## Яркая степная сцена для главного меню: небо, горы, аул и декоративная трава.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var w := size.x
	var h := size.y
	# Небо и дальние горы.
	draw_rect(Rect2(Vector2.ZERO, size), Color("1876bd"))
	_draw_cloud(Vector2(w * 0.08, h * 0.16), 1.15)
	_draw_cloud(Vector2(w * 0.72, h * 0.13), 0.72)
	_draw_cloud(Vector2(w * 0.92, h * 0.27), 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, h * 0.43), Vector2(w * 0.17, h * 0.25), Vector2(w * 0.33, h * 0.43),
		Vector2(w * 0.48, h * 0.28), Vector2(w * 0.66, h * 0.44), Vector2(w, h * 0.30),
		Vector2(w, h * 0.60), Vector2(0, h * 0.60),
	]), Color("6c9fc4"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, h * 0.54), Vector2(w * 0.22, h * 0.40), Vector2(w * 0.42, h * 0.56),
		Vector2(w * 0.63, h * 0.42), Vector2(w, h * 0.52), Vector2(w, h * 0.72), Vector2(0, h * 0.72),
	]), Color("4c8765"))
	# Степь: два слоя, чтобы меню не было плоским.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, h * 0.56), Vector2(w * 0.22, h * 0.50), Vector2(w * 0.56, h * 0.60),
		Vector2(w, h * 0.50), Vector2(w, h), Vector2(0, h),
	]), Color("8eb24f"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, h * 0.73), Vector2(w * 0.25, h * 0.66), Vector2(w * 0.58, h * 0.76),
		Vector2(w, h * 0.64), Vector2(w, h), Vector2(0, h),
	]), Color("597e37"))
	_draw_yurt(Vector2(w * 0.70, h * 0.42), 1.15)
	_draw_yurt(Vector2(w * 0.58, h * 0.53), 0.54)
	_draw_flag(Vector2(w * 0.64, h * 0.24), 1.0)
	_draw_flag(Vector2(w * 0.78, h * 0.31), 0.68)
	_draw_grass_ornament(h)

func _draw_cloud(origin: Vector2, scale_factor: float) -> void:
	var col := Color(1, 0.97, 0.87, 0.92)
	for item in [Vector2(-42, 10), Vector2(-12, -4), Vector2(20, 4), Vector2(49, 14)]:
		draw_circle(origin + item * scale_factor, 28.0 * scale_factor, col)
	draw_rect(Rect2(origin + Vector2(-68, 12) * scale_factor, Vector2(140, 35) * scale_factor), col)

func _draw_yurt(pos: Vector2, scale_factor: float) -> void:
	var roof := Color("f8e6bf")
	var outline := Color("7a4627")
	var body := Rect2(pos + Vector2(-72, -4) * scale_factor, Vector2(144, 70) * scale_factor)
	draw_rect(body, roof)
	draw_arc(pos + Vector2(0, -4) * scale_factor, 72 * scale_factor, PI, TAU, 22, outline, 4.0 * scale_factor, true)
	draw_line(pos + Vector2(-72, -4) * scale_factor, pos + Vector2(72, -4) * scale_factor, Color("b54b38"), 7.0 * scale_factor, true)
	draw_rect(Rect2(pos + Vector2(-18, 23) * scale_factor, Vector2(36, 43) * scale_factor), Color("71401f"))
	draw_rect(body, outline, false, 3.0 * scale_factor, true)

func _draw_flag(pos: Vector2, scale_factor: float) -> void:
	draw_line(pos, pos + Vector2(0, 150) * scale_factor, Color("5b442e"), 5.0 * scale_factor, true)
	var flag := PackedVector2Array([
		pos + Vector2(3, 9) * scale_factor, pos + Vector2(78, 33) * scale_factor,
		pos + Vector2(3, 58) * scale_factor,
	])
	draw_colored_polygon(flag, Color("b94736"))
	draw_line(flag[0], flag[1], Color("eac25b"), 3.0 * scale_factor, true)

func _draw_grass_ornament(h: float) -> void:
	var col := Color(0.12, 0.28, 0.18, 0.55)
	for x in range(0, int(size.x) + 1, 34):
		draw_arc(Vector2(x, h + 8), 32, PI, TAU, 12, col, 4.0, true)
		draw_line(Vector2(x + 8, h), Vector2(x + 22, h - 24), col, 3.0, true)
