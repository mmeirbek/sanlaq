class_name MapManager
extends Node2D
## Аул для Соқыртеке: поле за забором, арена в центре, юрты, пруды, камни,
## брёвна и кусты. Картинки — пиксельные спрайты из tools/artgen/world_art.py,
## без поворота и дробного масштаба; воду рисует PondLayer. Коллизии заданы
## числами ниже и совпадают с нарисованным.
##
## Порядок постройки важен: каждый следующий объект отодвигается от всех,
## поставленных раньше (_occupied), поэтому сначала арена с коврами и юрты,
## потом вода, потом твёрдые препятствия, в конце декор.

@export var map_data: MapDefinition

const YURT_SCENE := preload("res://scenes/world/yurt.tscn")
const GRASS := preload("res://assets/sprites/world/grass.png")
const WILD_GRASS := preload("res://assets/sprites/world/grass_wild.png")
const FENCE_ALONG_X := preload("res://assets/sprites/world/fence_h.png")
const FENCE_ALONG_Y := preload("res://assets/sprites/world/fence_v.png")
const ARENA := preload("res://assets/sprites/world/arena.png")
const RUG := preload("res://assets/sprites/world/rug.png")
const ROCKS: Array[Texture2D] = [
	preload("res://assets/sprites/world/rock_0.png"),
	preload("res://assets/sprites/world/rock_1.png"),
]
const LOG_ALONG_X := preload("res://assets/sprites/world/log_h.png")
const LOG_ALONG_Y := preload("res://assets/sprites/world/log_v.png")
const BUSH := preload("res://assets/sprites/world/bush.png")
const GROUND_DECOR: Array[Texture2D] = [
	preload("res://assets/sprites/world/flowers_0.png"),
	preload("res://assets/sprites/world/flowers_1.png"),
	preload("res://assets/sprites/world/flowers_2.png"),
	preload("res://assets/sprites/world/tuft.png"),
]

## Слой коллизий препятствий — тот же, что у игроков.
const OBSTACLE_LAYER := 5
const ROCK_RADIUS := 18.0
## Бревно вдоль x; бревно вдоль y — тот же прямоугольник, повёрнутый на 90°.
const LOG_SIZE := Vector2(56, 28)
## Куст рисуется так, чтобы он стоял на своей точке, а не висел над ней.
const BUSH_OFFSET := Vector2(0, -16)
const YURT_BLOCK_RADIUS := 105.0
## Ближе этого к центру юрты игрок под крышей и спрятан.
const YURT_HIDE_RADIUS := 60.0
## Ближе этого к камню или бревну никто не появляется.
const ROCK_CLEAR := 34.0
const ARENA_CENTER := Vector2.ZERO
const ARENA_RADIUS := 360.0
## Сколько степи видно за забором — с запасом на широкий экран.
const WILD_MARGIN := 1280.0
const DECOR_COUNT := 70

const YURT_SPOTS: Array[Vector2] = [
	Vector2(-590, -300), Vector2(-570, 305), Vector2(525, -280),
	Vector2(555, 280), Vector2(-155, -425), Vector2(165, 425),
	Vector2(740, -30),
]
## Пруды встают в пределах ±POND_JITTER от этих точек; радиус зоны — от
## POND_RADIUS_MIN до POND_RADIUS_MAX.
const POND_SPOTS: Array[Vector2] = [
	Vector2(-720, -390), Vector2(710, 410), Vector2(80, 475),
	Vector2(-580, 380), Vector2(-60, 465), Vector2(620, 80),
	Vector2(790, -390), Vector2(-790, 110), Vector2(100, -480),
]
const POND_JITTER := 60.0
const POND_RADIUS_MIN := 90.0
const POND_RADIUS_MAX := 130.0
const ROCK_SPOTS: Array[Vector2] = [
	Vector2(-730, -90), Vector2(-490, 110), Vector2(-45, -470),
	Vector2(430, 305), Vector2(690, 355), Vector2(-650, 340),
	Vector2(720, -305), Vector2(120, 430), Vector2(-440, -400),
	Vector2(390, -390), Vector2(-320, -290), Vector2(540, -70),
]
const LOG_SPOTS: Array[Vector2] = [
	Vector2(-260, -460), Vector2(280, 460), Vector2(-680, 440),
	Vector2(650, -420), Vector2(30, -480),
]
const BUSH_SPOTS: Array[Vector2] = [
	Vector2(-540, -260), Vector2(-520, 340), Vector2(480, -240),
	Vector2(500, 320), Vector2(-200, -330), Vector2(220, 340),
	Vector2(680, 20), Vector2(-680, -60),
]
const RUG_SPOTS: Array[Vector2] = [
	Vector2(-740, -467), Vector2(735, -467), Vector2(-740, 468), Vector2(735, 468),
]
## Свободное место вокруг объекта при расстановке (радиус).
const ROCK_CLEARANCE := 30.0
const LOG_CLEARANCE := 40.0
const BUSH_CLEARANCE := 30.0
const RUG_CLEARANCE := 100.0
const DECOR_CLEARANCE := 16.0
## Сколько раз чередовать «отодвинуть от соседей» и «вернуть в границы».
const CLAIM_PASSES := 3

var bounds: Rect2:
	get:
		if map_data:
			return map_data.get_bounds()
		return Rect2(Vector2(-900, -550), Vector2(1800, 1100))

var yurt_positions: Array[Vector2] = []
var obstacle_positions: Array[Vector2] = []
var water_zones: Array[Dictionary] = []
var _spawn_cursor := 0
## Занятые места: {pos, radius}. Новые объекты отодвигаются от них.
var _occupied: Array[Dictionary] = []

func _ready() -> void:
	_build_ground()
	_build_arena()
	_build_yurts()
	_build_water()
	_build_rocks()
	_build_logs()
	_build_bushes()
	_build_decor()

func _build_ground() -> void:
	_add_tiled(WILD_GRASS, bounds.grow(WILD_MARGIN), WorldLayers.WILD_GRASS)
	_add_tiled(GRASS, bounds, WorldLayers.GROUND)
	# Забор стоит снаружи поля: игрок к нему не подходит, поэтому он плоский.
	var rail_h := float(FENCE_ALONG_X.get_height())
	var post_w := float(FENCE_ALONG_Y.get_width())
	var outer_x := bounds.position.x - post_w
	var outer_w := bounds.size.x + post_w * 2.0
	_add_tiled(FENCE_ALONG_X, Rect2(outer_x, bounds.position.y - rail_h, outer_w, rail_h), WorldLayers.DECALS)
	_add_tiled(FENCE_ALONG_Y, Rect2(outer_x, bounds.position.y - rail_h * 0.5, post_w, bounds.size.y + rail_h * 0.5), WorldLayers.DECALS)
	_add_tiled(FENCE_ALONG_Y, Rect2(bounds.end.x, bounds.position.y - rail_h * 0.5, post_w, bounds.size.y + rail_h * 0.5), WorldLayers.DECALS)
	_add_tiled(FENCE_ALONG_X, Rect2(outer_x, bounds.end.y, outer_w, rail_h), WorldLayers.DECALS)

func _build_arena() -> void:
	# Арена и ковры остаются открытыми: пруды и препятствия на них не встают.
	_add_sprite(ARENA, ARENA_CENTER, WorldLayers.ARENA)
	_register_occupied(ARENA_CENTER, ARENA_RADIUS)
	for spot in RUG_SPOTS:
		_add_sprite(RUG, spot, WorldLayers.DECALS)
		_register_occupied(spot, RUG_CLEARANCE)

func _build_yurts() -> void:
	yurt_positions.clear()
	for spot in YURT_SPOTS:
		var yurt := YURT_SCENE.instantiate() as Node2D
		yurt.position = spot
		add_child(yurt)
		yurt_positions.append(spot)
		_register_occupied(spot, YURT_BLOCK_RADIUS)

func _build_water() -> void:
	water_zones.clear()
	for spot in POND_SPOTS:
		var radius := randf_range(POND_RADIUS_MIN, POND_RADIUS_MAX)
		var jitter := Vector2(randf_range(-POND_JITTER, POND_JITTER), randf_range(-POND_JITTER, POND_JITTER))
		water_zones.append({"pos": _claim_spot(spot + jitter, radius), "radius": radius})
	var ponds := PondLayer.new()
	add_child(ponds)
	ponds.set_zones(water_zones)

func _build_rocks() -> void:
	obstacle_positions.clear()
	for spot in ROCK_SPOTS:
		var shape := CircleShape2D.new()
		shape.radius = ROCK_RADIUS
		obstacle_positions.append(_add_obstacle(spot, ROCK_CLEARANCE, ROCKS.pick_random(), shape))

func _build_logs() -> void:
	for spot in LOG_SPOTS:
		var along_x := randf() < 0.5
		var shape := RectangleShape2D.new()
		shape.size = LOG_SIZE if along_x else Vector2(LOG_SIZE.y, LOG_SIZE.x)
		var texture := LOG_ALONG_X if along_x else LOG_ALONG_Y
		obstacle_positions.append(_add_obstacle(spot, LOG_CLEARANCE, texture, shape))

func _build_bushes() -> void:
	# Кусты — декор без коллизий, но стоят в сортировке: за кустом прячутся ноги.
	for spot in BUSH_SPOTS:
		var bush := _add_sprite(BUSH, _claim_spot(spot, BUSH_CLEARANCE), WorldLayers.SORTED)
		bush.offset = BUSH_OFFSET

func _build_decor() -> void:
	# Цветы и пучки травы: плоские, только на свободной траве.
	var placed := 0
	for _attempt in DECOR_COUNT * 4:
		if placed == DECOR_COUNT:
			return
		var pos := Vector2(
			randf_range(bounds.position.x + DECOR_CLEARANCE, bounds.end.x - DECOR_CLEARANCE),
			randf_range(bounds.position.y + DECOR_CLEARANCE, bounds.end.y - DECOR_CLEARANCE))
		if _is_occupied(pos, DECOR_CLEARANCE):
			continue
		_add_sprite(GROUND_DECOR.pick_random(), pos, WorldLayers.DECALS)
		placed += 1

## Твёрдое препятствие: StaticBody2D с явной формой и спрайтом по её центру.
## Возвращает итоговую позицию — после того как её отодвинули от соседей.
func _add_obstacle(spot: Vector2, clearance: float, texture: Texture2D, shape: Shape2D) -> Vector2:
	var pos := _claim_spot(spot, clearance)
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	body.add_child(sprite)
	add_child(body)
	return pos

func _add_sprite(texture: Texture2D, pos: Vector2, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	sprite.z_index = layer
	add_child(sprite)
	return sprite

## Плитка, повторяющаяся на весь rect. Узор привязан к миру, а не к краю rect.
func _add_tiled(texture: Texture2D, rect: Rect2, layer: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = rect.position
	sprite.region_enabled = true
	sprite.region_rect = rect
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.z_index = layer
	add_child(sprite)

## Отодвигает точку от занятых мест и края карты, ставит на сетку пикселя
## арта и занимает её. Край карты может вдавить точку обратно в соседа —
## тогда объекты накладываются: пруды сливаются в озеро, а не уезжают далеко
## от своих мест.
func _claim_spot(spot: Vector2, radius: float) -> Vector2:
	var pos := spot
	for _pass in CLAIM_PASSES:
		pos = clamp_to_bounds(_avoid_occupied(pos, radius), radius)
	pos = (pos / UiTokens.PIXEL).round() * UiTokens.PIXEL
	_register_occupied(pos, radius)
	return pos

func _register_occupied(pos: Vector2, radius: float) -> void:
	_occupied.append({"pos": pos, "radius": radius})

func _is_occupied(pos: Vector2, radius: float) -> bool:
	for entry in _occupied:
		if pos.distance_to(entry["pos"]) < radius + float(entry["radius"]):
			return true
	return false

func _avoid_occupied(pos: Vector2, radius: float) -> Vector2:
	# Один проход может вытолкнуть точку из одного пересечения прямо в соседнее
	# (ближе к концу постройки занято уже много мест) — повторяем, пока точка
	# не перестанет двигаться.
	for _pass in 8:
		var moved := false
		for entry in _occupied:
			var min_dist: float = radius + float(entry["radius"])
			var to_pos: Vector2 = pos - (entry["pos"] as Vector2)
			var dist := to_pos.length()
			if dist < min_dist:
				var dir := to_pos.normalized() if dist > 0.01 else Vector2.RIGHT
				pos = (entry["pos"] as Vector2) + dir * min_dist
				moved = true
		if not moved:
			break
	return pos

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
