class_name SanlaqOrnament
extends Control
## Орнаментальная полоса в казахском стиле (ромбы-«кошкар муйіз»).

@export var color: Color = SanlaqDesignTokens.GOLD
@export var accent_color: Color = SanlaqDesignTokens.GOLD_DARK
@export var motif_size := 20.0
@export var thickness := 3.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	draw_line(Vector2(0, h * 0.14), Vector2(w, h * 0.14), accent_color, thickness, true)
	draw_line(Vector2(0, h * 0.86), Vector2(w, h * 0.86), accent_color, thickness, true)
	var step := motif_size * 2.0
	var count := int(ceil(w / step))
	var total := step * count
	var start := (w - total) * 0.5 + motif_size
	for i in range(count):
		var cx := start + i * step
		if cx > w + motif_size:
			break
		_draw_diamond(cx, h * 0.5, motif_size, motif_size * 1.3, accent_color, color)
		_draw_diamond(cx, h * 0.5, motif_size * 0.42, motif_size * 0.55, color, color)

func _draw_diamond(cx: float, cy: float, rw: float, rh: float, fill: Color, line: Color) -> void:
	var p := PackedVector2Array([
		Vector2(cx, cy - rh), Vector2(cx + rw, cy),
		Vector2(cx, cy + rh), Vector2(cx - rw, cy),
	])
	draw_colored_polygon(p, fill)
	draw_polyline(PackedVector2Array([p[0], p[1], p[2], p[3], p[0]]), line, thickness, true)
