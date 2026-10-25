extends "res://tools/test_case.gd"
## Карта-аул (scripts/systems/map_manager.gd) на многих случайных раскладках:
## - механика как до редизайна: 7 юрт, 9 прудов радиусом 90–130, 12 камней и
##   5 брёвен с коллизиями ровно заданных размеров, без поворота;
## - украшения (ковры, цветы) не ложатся на воду, юрты и препятствия;
## - пиксель-арт мира стоит на сетке пикселя арта;
## - юрта сверху: крыша сквозная только над тем, кто стоит внутри.
## На каждую раскладку — по одной проверке на правило; в сообщении — что нарушено.

const MAP_SCENE := "res://scenes/world/map_steppe_village.tscn"
const LAYOUTS := 20


func _init() -> void:
	await process_frame
	for layout in LAYOUTS:
		seed(layout)
		var map: MapManager = await mount(MAP_SCENE)
		_check_mechanics(map, layout)
		_check_decor(map, layout)
		_check_pixel_grid(map, layout)
		await unmount(map)
	await _check_roofs()
	finish("MAP")


## Как куст в Brawl Stars: под своей крышей игрок виден, остальные крыши целые.
func _check_roofs() -> void:
	var map: MapManager = await mount(MAP_SCENE)
	var count := map.yurt_positions.size()
	var opened := func() -> Array:
		return range(count).filter(func(i: int) -> bool: return map.is_roof_open(i))
	check(opened.call().is_empty(), "крыши юрт целые, пока внутри никого")
	map.update_roofs(map.yurt_positions[2] + Vector2(20, 30))
	check(opened.call() == [2], "игрок в юрте 3 — сквозная только её крыша (%s)" % [opened.call()])
	map.update_roofs(map.yurt_positions[2] + Vector2(0, MapManager.YURT_ROOF_RADIUS + 20))
	check(opened.call().is_empty(), "вышел из юрты — крыша снова целая")
	map.update_roofs(map.yurt_positions[2])
	map.update_roofs(null)
	check(opened.call().is_empty(), "игрок выбыл — все крыши целые")
	await unmount(map)


func _check_mechanics(map: MapManager, layout: int) -> void:
	check(map.yurt_positions.size() == MapManager.YURT_SPOTS.size(), "раскладка %d: все юрты на месте" % layout)
	var bad_ponds := map.water_zones.filter(func(zone: Dictionary) -> bool:
		return zone.radius < MapManager.POND_RADIUS_MIN or zone.radius > MapManager.POND_RADIUS_MAX)
	check(map.water_zones.size() == MapManager.POND_SPOTS.size() and bad_ponds.is_empty(),
		"раскладка %d: 9 прудов радиусом 90–130 (вне пределов: %s)" % [layout, bad_ponds])
	var rocks := 0
	var logs := 0
	var wrong: Array[String] = []
	for body in map.get_children().filter(func(node: Node) -> bool: return node is StaticBody2D):
		var shape: Shape2D = (body.get_child(0) as CollisionShape2D).shape
		if body.rotation != 0.0:
			wrong.append("повёрнуто %s" % body.position)
		if shape is CircleShape2D:
			rocks += 1
			if shape.radius != MapManager.ROCK_RADIUS:
				wrong.append("камень r=%s" % shape.radius)
		elif shape is RectangleShape2D:
			logs += 1
			var size: Vector2 = shape.size
			if size != MapManager.LOG_SIZE and size != Vector2(MapManager.LOG_SIZE.y, MapManager.LOG_SIZE.x):
				wrong.append("бревно %s" % size)
	check(wrong.is_empty(), "раскладка %d: коллизии заданы числами, без поворота %s" % [layout, wrong])
	check(rocks == MapManager.ROCK_SPOTS.size() and logs == MapManager.LOG_SPOTS.size()
		and map.obstacle_positions.size() == rocks + logs,
		"раскладка %d: %d камней и %d брёвен учтены для спавна" % [layout, rocks, logs])


func _check_decor(map: MapManager, layout: int) -> void:
	var blocked: Array[Dictionary] = map.water_zones.duplicate()
	for yurt in map.yurt_positions:
		blocked.append({"pos": yurt, "radius": MapManager.YURT_BLOCK_RADIUS})
	var wrong: Array[Vector2] = []
	for decor in _sprites(map, WorldLayers.DECALS):
		# Ковёр занимает больше места, чем цветок; стоит на сетке — до пикселя от своего места.
		var reach := MapManager.RUG_SPACING - UiTokens.PIXEL if decor.texture == MapManager.RUG else 0.0
		for area in blocked:
			if decor.position.distance_to(area.pos) < area.radius + reach:
				wrong.append(decor.position)
	check(wrong.is_empty(), "раскладка %d: ковры и цветы не на воде и не в юртах %s" % [layout, wrong])


## Левый верхний угол каждой картинки мира — на сетке пикселя арта.
func _check_pixel_grid(map: MapManager, layout: int) -> void:
	var px := float(UiTokens.PIXEL)
	var wrong: Array[String] = []
	for sprite: Sprite2D in map.find_children("*", "Sprite2D", true, false):
		var corner := sprite.global_position + sprite.offset
		if sprite.centered:
			corner -= sprite.texture.get_size() / 2.0
		if not is_equal_approx(fposmod(corner.x, px), 0.0) or not is_equal_approx(fposmod(corner.y, px), 0.0):
			wrong.append("%s %s" % [sprite.texture.resource_path.get_file(), corner])
	check(wrong.is_empty(), "раскладка %d: картинки мира на сетке пикселя арта %s" % [layout, wrong])


func _sprites(map: MapManager, layer: int) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for node in map.get_children():
		if node is Sprite2D and node.z_index == layer and not node.region_enabled:
			found.append(node)
	return found
