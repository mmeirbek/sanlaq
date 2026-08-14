class_name MapDefinition
extends Resource

@export var map_id: String = ""
@export var display_name_kz: String = ""
@export var display_name_ru: String = ""

var scene_path: String:
	set(v): _scene_path = v
	get:
		if _scene_path.is_empty():
			return "res://scenes/world/map_%s.tscn" % map_id
		return _scene_path

var _scene_path: String = ""

@export var spawn_points: Array[Vector2] = []
@export var bounds_min: Vector2 = Vector2(-800, -500)
@export var bounds_max: Vector2 = Vector2(800, 500)
@export var ambient_color: Color = Color(0.15, 0.3, 0.1)

func get_bounds() -> Rect2:
	return Rect2(bounds_min, bounds_max - bounds_min)

func get_random_spawn() -> Vector2:
	if spawn_points.is_empty():
		var b := get_bounds()
		return Vector2(
			randf_range(b.position.x, b.end.x),
			randf_range(b.position.y, b.end.y)
		)
	return spawn_points[randi() % spawn_points.size()]
