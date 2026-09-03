class_name MapManager
extends Node2D

@export var map_data: MapDefinition
@export var ground_color: Color = Color(0.18, 0.30, 0.13)

const YURT_SCENE := "res://scenes/world/yurt.tscn"
const GRASS_TEX := "res://assets/tiles/ground.png"
const WATER_TEX := "res://assets/tiles/water_blob.png"
const ROCK_TEX := "res://assets/tiles/rock.png"
const ROCK_TEX_02 := "res://assets/tiles/rock_02.png"
const LOG_TEX := "res://assets/tiles/log.png"
const BUSH_TEX := "res://assets/tiles/bush.png"
const YURT_BLOCK_RADIUS := 105.0
const ROCK_CLEAR := 34.0
# yurt.png's roof (256px canvas, ~226-229px content, drawn at 0.75 scale) reads ~85px wide,
# so the old fixed 48px hide-trigger left a big gap between "visually under the roof" and "hidden".
const YURT_HIDE_RADIUS := 60.0
const ARENA_CENTER := Vector2.ZERO
const ARENA_RADIUS := 360.0

var bounds: Rect2:
	get:
		if map_data:
			return map_data.get_bounds()
		return Rect2(Vector2(-900, -550), Vector2(1800, 1100))

var yurt_positions: Array[Vector2] = []
var obstacle_positions: Array[Vector2] = []
var water_zones: Array[Dictionary] = []
var _spawn_cursor := 0

# Every placed map object (yurt/water/rock/log/bush) registers itself here as it's built,
# so later objects are nudged away from it — prevents props spawning on top of each other.
# Build order matters: _build_map() places yurts first, then water, then solid props, then
# decorative bushes last, so each category avoids everything placed before it.
var _occupied: Array[Dictionary] = []

func _ready() -> void:
	_build_map()

func _build_map() -> void:
	_build_ground()
	_build_yurts()
	_build_water()
	_build_rocks()
	_build_logs()
	_build_bushes()
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
		Vector2(-720, -390), Vector2(710, 410), Vector2(80, 475),
		Vector2(-580, 380), Vector2(-60, 465), Vector2(620, 80),
		Vector2(790, -390), Vector2(-790, 110), Vector2(100, -480),
	]
	water_zones.clear()
	for b in bases:
		var radius := randf_range(90.0, 130.0)
		var pos: Vector2 = b + Vector2(randf_range(-60, 60), randf_range(-60, 60))
		pos = _avoid_occupied(pos, radius)
		pos = clamp_to_bounds(pos, radius)
		water_zones.append({"pos": pos, "radius": radius})
		_register_occupied(pos, radius)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.position = pos
		spr.scale = Vector2(radius / 64.0, radius / 64.0) * randf_range(0.9, 1.2)
		spr.rotation = randf_range(0, TAU)
		spr.z_index = 1
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(spr)

func _register_occupied(pos: Vector2, radius: float) -> void:
	_occupied.append({"pos": pos, "radius": radius})

func _avoid_occupied(pos: Vector2, radius: float) -> Vector2:
	for entry in _occupied:
		var min_dist: float = radius + float(entry["radius"])
		var to_pos: Vector2 = pos - (entry["pos"] as Vector2)
		var dist := to_pos.length()
		if dist < min_dist:
			var dir := to_pos.normalized() if dist > 0.01 else Vector2.RIGHT
			pos = (entry["pos"] as Vector2) + dir * min_dist
	return pos

## Places a decorative or solid prop, keeping it clear of yurts, other props, and map bounds.
## collision_base is measured at sprite scale 1.0 and is scaled together with the sprite's
## randomized scale, so the collision shape always tracks what's actually drawn:
## a float gives a CircleShape2D radius, a Vector2 gives a RectangleShape2D size (rotates
## together with the body, which suits elongated props like logs far better than a circle).
## Returns the final (possibly nudged) position so callers can track it for spawn-clearance.
func _spawn_prop(pos: Vector2, textures: Array, clear_margin: float, scale_range: Vector2, solid: bool, collision_base = 0.0, z_index: int = 0) -> Vector2:
	pos = _avoid_occupied(pos, clear_margin)
	pos = clamp_to_bounds(pos, clear_margin)
	_register_occupied(pos, clear_margin)

	var s := randf_range(scale_range.x, scale_range.y)
	var spr := Sprite2D.new()
	spr.texture = textures[randi() % textures.size()]
	spr.scale = Vector2.ONE * s
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	if solid:
		var body := StaticBody2D.new()
		body.position = pos
		body.rotation = randf_range(0, TAU)
		body.collision_layer = 5
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		if collision_base is Vector2:
			var rect_shape := RectangleShape2D.new()
			rect_shape.size = collision_base * s
			col.shape = rect_shape
		else:
			var circle_shape := CircleShape2D.new()
			circle_shape.radius = float(collision_base) * s
			col.shape = circle_shape
		body.add_child(col)
		body.add_child(spr)
		add_child(body)
	else:
		spr.position = pos
		spr.z_index = z_index
		add_child(spr)
	return pos

func _build_rocks() -> void:
	var rock_textures := [load(ROCK_TEX), load(ROCK_TEX_02)]
	var rock_positions := [
		Vector2(-730, -90), Vector2(-490, 110), Vector2(-45, -470),
		Vector2(430, 305), Vector2(690, 355), Vector2(-650, 340),
		Vector2(720, -305), Vector2(120, 430), Vector2(-440, -400),
		Vector2(390, -390), Vector2(-320, -290), Vector2(540, -70),
	]
	obstacle_positions = []
	# rock.png/rock_02.png content fills ~53-55px of the 64px canvas (~25px radius at scale 1.0).
	for pos in rock_positions:
		obstacle_positions.append(_spawn_prop(pos, rock_textures, 30.0, Vector2(0.6, 0.8), true, 25.0))

func _build_logs() -> void:
	var log_textures := [load(LOG_TEX)]
	var log_positions: Array[Vector2] = [
		Vector2(-260, -460), Vector2(280, 460), Vector2(-680, 440),
		Vector2(650, -420), Vector2(30, -480),
	]
	# log.png content is an elongated ~56x39 shape (wide, not round) at scale 1.0 — a rotated
	# rectangle tracks that silhouette far better than a circle, and rotates with the sprite.
	for pos in log_positions:
		obstacle_positions.append(_spawn_prop(pos, log_textures, 40.0, Vector2(0.9, 1.15), true, Vector2(50.0, 30.0)))

func _build_bushes() -> void:
	var bush_textures := [load(BUSH_TEX)]
	var bush_positions := [
		Vector2(-540, -260), Vector2(-520, 340), Vector2(480, -240),
		Vector2(500, 320), Vector2(-200, -330), Vector2(220, 340),
		Vector2(680, 20), Vector2(-680, -60),
	]
	for pos in bush_positions:
		_spawn_prop(pos, bush_textures, 30.0, Vector2(0.9, 1.2), false, 0.0, 2)

func _build_yurts() -> void:
	yurt_positions = [
		Vector2(-590, -300), Vector2(-570, 305), Vector2(525, -280),
		Vector2(555, 280), Vector2(-155, -425), Vector2(165, 425),
		Vector2(740, -30),
	]
	var pack := load(YURT_SCENE) as PackedScene
	for pos in yurt_positions:
		var yurt := pack.instantiate()
		yurt.position = pos
		add_child(yurt)
		_register_occupied(pos, YURT_BLOCK_RADIUS)

func get_random_spawn() -> Vector2:
	if map_data and not map_data.spawn_points.is_empty():
		return map_data.get_random_spawn()
	var margin := 100.0
	return Vector2(
		randf_range(bounds.position.x + margin, bounds.end.x - margin),
		randf_range(bounds.position.y + margin, bounds.end.y - margin)
	)

func get_safe_spawn() -> Vector2:
	# Карта может открываться отдельно от ресурса в редакторе: тогда всё равно
	# начинаем на арене, а не в случайной точке пустой степи.
	if map_data == null and _spawn_cursor == 0:
		_spawn_cursor += 1
		return ARENA_CENTER
	var margin := 120.0
	for i in 60:
		var p: Vector2
		if map_data and not map_data.spawn_points.is_empty() and i < map_data.spawn_points.size():
			p = map_data.spawn_points[_spawn_cursor % map_data.spawn_points.size()]
			_spawn_cursor += 1
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
		if pos.distance_to(yurt) < YURT_HIDE_RADIUS:
			return true
	return false

func _draw() -> void:
	# Пиксельная арена в центре: круглый той-алаң с национальным орнаментом.
	draw_rect(bounds, Color("4c6c38"), false, 10.0, false)
	draw_circle(ARENA_CENTER + Vector2(12, 16), ARENA_RADIUS + 24, Color(0.10, 0.18, 0.10, 0.24), false)
	draw_circle(ARENA_CENTER, ARENA_RADIUS + 16, Color("77502e"), false)
	draw_circle(ARENA_CENTER, ARENA_RADIUS + 8, Color("d8ae61"), false)
	draw_circle(ARENA_CENTER, ARENA_RADIUS, Color("a97342"), false)
	draw_circle(ARENA_CENTER, ARENA_RADIUS - 16, Color("e2bd78"), false)
	draw_circle(ARENA_CENTER, ARENA_RADIUS - 34, Color("cf9e5d"), false)
	draw_circle(ARENA_CENTER, ARENA_RADIUS - 44, Color("e8c984"), false)

	_draw_arena_motifs()
	_draw_corner_props()

func _draw_arena_motifs() -> void:
	# Восьмиугольники намеренно рисуются без сглаживания — это держит 2D pixel-art характер.
	for radius in [ARENA_RADIUS - 24.0, ARENA_RADIUS - 52.0]:
		_draw_pixel_ring(radius, Color("896039"), 3.0)

	for i in range(16):
		var a := TAU * float(i) / 16.0
		var pos := ARENA_CENTER + Vector2(cos(a), sin(a)) * (ARENA_RADIUS - 38.0)
		_draw_diamond(pos, 12.0, Color("805430"), Color("f2d58c"))

	_draw_diamond(ARENA_CENTER, 112.0, Color("a46b39"), Color("edcf85"))
	_draw_diamond(ARENA_CENTER, 76.0, Color("edcf85"), Color("8b5b34"))
	_draw_diamond(ARENA_CENTER, 37.0, Color("81502f"), Color("f4d78e"))
	for i in range(4):
		var pos := ARENA_CENTER + Vector2(0, -150).rotated(TAU * i / 4.0)
		_draw_diamond(pos, 24.0, Color("9b6336"), Color("e7c479"))

func _draw_pixel_ring(radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var a := TAU * float(i) / 32.0
		points.append(ARENA_CENTER + Vector2(round(cos(a) * radius / 4.0) * 4.0, round(sin(a) * radius / 4.0) * 4.0))
	draw_polyline(points, color, width, false)

func _draw_diamond(center: Vector2, radius: float, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	])
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), outline, 3.0, false)

func _draw_corner_props() -> void:
	# Коврики и флажки по краям создают ощущение аула и хорошо читаются сверху.
	var rugs := [
		Rect2(-825, -505, 170, 76), Rect2(650, -505, 170, 76),
		Rect2(-825, 430, 170, 76), Rect2(650, 430, 170, 76),
	]
	for rug in rugs:
		draw_rect(rug, Color("8c3e32"), true)
		draw_rect(rug.grow(-7), Color("d19d4b"), false, 4.0, false)
		_draw_diamond(rug.get_center(), 16.0, Color("e1bd70"), Color("67352d"))
