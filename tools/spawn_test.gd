extends "res://tools/test_case.gd"
## Никто не появляется внутри юрты или вплотную к камню/бревну.

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
	finish("SPAWN")
