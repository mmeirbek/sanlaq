class_name SanlaqBackdrop
extends Control
## Ненавязчивый фон для всех экранов меню: степное небо, солнце и орнаментальные дуги.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return

	# Основной тёплый фон и лёгкий горизонт степи.
	draw_rect(Rect2(Vector2.ZERO, size), SanlaqDesignTokens.CREAM)
	var horizon := size.y * 0.72
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, horizon), Vector2(size.x * 0.22, horizon - 30),
		Vector2(size.x * 0.55, horizon + 12), Vector2(size.x, horizon - 24),
		Vector2(size.x, size.y), Vector2(0, size.y),
	]), Color("e7d4a7"))

	# Солнце и сияние остаются достаточно бледными, чтобы не мешать тексту.
	var sun := Vector2(size.x * 0.82, size.y * 0.20)
	for radius in [150.0, 105.0, 66.0]:
		var alpha := 0.035 if radius > 100.0 else 0.08
		draw_circle(sun, radius, Color(0.92, 0.66, 0.22, alpha))
	draw_circle(sun, 38.0, Color("f2ca68"))

	# Орнаментальные дуги связывают экраны с декоративными полосами сверху и снизу.
	var arc_color := Color(0.06, 0.23, 0.32, 0.055)
	draw_arc(Vector2(size.x * 0.06, size.y * 0.88), 210.0, -1.35, 0.15, 48, arc_color, 3.0, true)
	draw_arc(Vector2(size.x * 0.06, size.y * 0.88), 166.0, -1.35, 0.15, 48, arc_color, 3.0, true)
