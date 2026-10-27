extends "res://tools/test_case.gd"
## Игроки появляются в точках спавна карты (на арене), и никто — внутри юрты
## или вплотную к камню/бревну.

## Ближе этого к центру юрты игрок оказывается внутри её стен.
const YURT_CLEARANCE := 100.0


func _init() -> void:
	await process_frame
	await process_frame
	var game := await mount("res://scenes/world/game.tscn")
	await process_frame
	var map: MapManager = game.map
	for player in game.match_mgr.players:
		var at: Vector2 = player.global_position
		for yurt in map.yurt_positions:
			check(at.distance_to(yurt) >= YURT_CLEARANCE,
				"спавн %s не внутри юрты %s" % [at, yurt])
		# obstacle_positions — и камни, и брёвна; зазор тот же, что проверяет
		# сам спавн (MapManager._spawn_clear).
		for obstacle in map.obstacle_positions:
			check(at.distance_to(obstacle) >= MapManager.ROCK_CLEAR,
				"спавн %s не вплотную к препятствию %s" % [at, obstacle])
	await unmount(game)
	await _test_spawn_points_used()
	finish("SPAWN")


## Данные карты (точки спавна, границы) приходят из ресурса в сцене карты.
## Раньше свойство map_data стояло в сцене до script и терялось: игроки
## появлялись в случайных точках по всей карте, иногда в пруду.
func _test_spawn_points_used() -> void:
	var map: MapManager = await mount("res://scenes/world/map_steppe_village.tscn")
	check(map.map_data != null, "данные карты загружены из сцены")
	if map.map_data:
		for i in map.map_data.spawn_points.size():
			var at := map.get_safe_spawn()
			check(at in map.map_data.spawn_points, "спавн %s — одна из точек спавна карты" % at)
	await unmount(map)
