class_name MapManager
extends Node2D

@export var map_data: MapDefinition
@export var ground_color: Color = Color(0.18, 0.30, 0.13)

const YURT_SCENE := "res://scenes/world/yurt.tscn"
const GRASS_TEX := "res://assets/tiles/ground.png"
const WATER_TEX := "res://assets/tiles/water_blob.png"
const ROCK_TEX := "res://assets/tiles/rock.png"
const YURT_BLOCK_RADIUS := 105.0
const ROCK_CLEAR := 34.0

var bounds: Rect2:
	get:
		if map_data:
			return map_data.get_bounds()
		return Rect2(Vector2(-900, -550), Vector2(1800, 1100))

var yurt_positions: Array[Vector2] = []
var obstacle_positions: Array[Vector2] = []
var water_zones: Array[Dictionary] = []

func _ready() -> void:
	_build_map()

func _build_map() -> void:
	_build_ground()
	_build_water()
	_build_rocks()
	_build_yurts()
	queue_redraw()

func _build_ground() -> void:
	var ground := Sprite2D.new()
	ground.texture = load(GRASS_TEX)
	ground.centered = false
	ground.position = bounds.position
	ground.region_enabled = true
	ground.region_rect = Rect2(Vector2.ZERO, bounds.size)
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.z_index = -10
	add_child(ground)

func _build_water() -> void:
	var tex := load(WATER_TEX) as Texture2D
	var bases := [
		Vector2(-700, -380), Vector2(680, 460), Vector2(180, 470),
		Vector2(-520, 420), Vector2(-80, 300), Vector2(420, 120),
		Vector2(820, -420), Vector2(-820, 140), Vector2(40, -460),
	]
	water_zones.clear()
	for b in bases:
		var radius := randf_range(90.0, 130.0)
		var pos: Vector2 = b + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		pos = clamp_to_bounds(pos, radius)
		water_zones.append({"pos": pos, "radius": radius})
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = pos
		spr.scale = Vector2(radius / 64.0, radius / 64.0) * randf_range(0.9, 1.2)
		spr.rotation = randf_range(0, TAU)
		spr.z_index = -5
		add_child(spr)

func _build_rocks() -> void:
	var rock_tex := load(ROCK_TEX)
	obstacle_positions = [
		Vector2(-700, -100), Vector2(-300, 100), Vector2(0, -400),
		Vector2(250, 250), Vector2(600, 400), Vector2(-600, 350),
		Vector2(700, -350), Vector2(100, 350), Vector2(-400, -400),
		Vector2(350, -350), Vector2(-150, -100), Vector2(520, -50),
	]
	for pos in obstacle_positions:
		pos = clamp_to_bounds(pos, 30.0)
		var rock := StaticBody2D.new()
		rock.position = pos
		rock.rotation = randf_range(0, TAU)
		rock.collision_layer = 5
		rock.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 20.0
		col.shape = shape
		rock.add_child(col)
		var spr := Sprite2D.new()
		spr.texture = rock_tex
		spr.scale = Vector2.ONE * randf_range(2.4, 3.2)
		rock.add_child(spr)
		add_child(rock)

func _build_yurts() -> void:
	yurt_positions = [
		Vector2(-500, -250), Vector2(-150, 250), Vector2(400, -200),
		Vector2(500, 300), Vector2(-200, -350), Vector2(200, 0),
		Vector2(650, -100),
	]
	var pack := load(YURT_SCENE) as PackedScene
	for pos in yurt_positions:
		var yurt := pack.instantiate()
		yurt.position = pos
		add_child(yurt)

func get_random_spawn() -> Vector2:
	if map_data and not map_data.spawn_points.is_empty():
		return map_data.get_random_spawn()
	var margin := 100.0
	return Vector2(
		randf_range(bounds.position.x + margin, bounds.end.x - margin),
		randf_range(bounds.position.y + margin, bounds.end.y - margin)
	)

func get_safe_spawn() -> Vector2:
	var margin := 120.0
	for i in 60:
		var p: Vector2
		if map_data and not map_data.spawn_points.is_empty() and i < map_data.spawn_points.size():
			p = map_data.spawn_points[i]
		else:
			p = Vector2(
				randf_range(bounds.position.x + margin, bounds.end.x - margin),
				randf_range(bounds.position.y + margin, bounds.end.y - margin)
			)
		if _spawn_clear(p):
			return p
	return Vector2(randf_range(bounds.position.x + margin, bounds.end.x - margin),
		randf_range(bounds.position.y + margin, bounds.end.y - margin))

func _spawn_clear(pos: Vector2) -> bool:
	if not bounds.has_point(pos):
		return false
	for yurt in yurt_positions:
		if pos.distance_to(yurt) < YURT_BLOCK_RADIUS:
			return false
	for obs in obstacle_positions:
		if pos.distance_to(obs) < ROCK_CLEAR:
			return false
	return true

func is_in_bounds(pos: Vector2) -> bool:
	return bounds.has_point(pos)

func clamp_to_bounds(pos: Vector2, radius: float = 0.0) -> Vector2:
	var clamped := pos
	var r := bounds.position
	var e := bounds.end
	clamped.x = clampf(clamped.x, r.x + radius, e.x - radius)
	clamped.y = clampf(clamped.y, r.y + radius, e.y - radius)
	return clamped

func is_water(pos: Vector2) -> bool:
	for z in water_zones:
		if pos.distance_to(z["pos"]) < z["radius"]:
			return true
	return false

func is_inside_yurt(pos: Vector2) -> bool:
	for yurt in yurt_positions:
		if pos.distance_to(yurt) < 29:
			return true
	return false

func _draw() -> void:
	draw_rect(bounds, Color(0.07, 0.15, 0.05), false, 6.0)
