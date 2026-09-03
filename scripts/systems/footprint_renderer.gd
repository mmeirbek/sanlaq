extends Node2D

@onready var _footprints: FootprintSystem = $"../FootprintSystem"

func _draw() -> void:
	if _footprints == null:
		return
	for pr in _footprints.get_prints():
		var pos: Vector2 = to_local(pr.pos)
		var facing: Vector2 = pr.facing
		var life: float = pr.life
		var alpha: float = clampf(1.0 - life / FootprintSystem.PRINT_LIFETIME, 0.0, 1.0) * 0.55
		_draw_oval(pos, facing, alpha)

func _draw_oval(pos: Vector2, facing: Vector2, alpha: float) -> void:
	var angle := facing.angle() if facing.length() > 0.01 else 0.0
	var points := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var local_pt := Vector2(cos(a) * 3.5, sin(a) * 5.5).rotated(angle)
		points.append(pos + local_pt)
	draw_colored_polygon(points, Color(0.16, 0.12, 0.08, alpha))

func _process(_dt: float) -> void:
	queue_redraw()
