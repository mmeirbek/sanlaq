extends SceneTree

func _init() -> void:
	await process_frame
	await process_frame
	var pack = load("res://scenes/world/game.tscn")
	var game = pack.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	var mm = game.match_mgr
	var map = game.map
	var bad := 0
	for p in mm.players:
		for y in map.yurt_positions:
			if p.global_position.distance_to(y) < 100.0:
				bad += 1
				print("[spawn] player inside/near yurt: ", p.global_position, " yurt ", y)
		for o in map.obstacle_positions:
			# obstacle_positions holds both rocks and logs — use the same clearance
			# the live spawn logic (_spawn_clear) checks against, not an ad hoc number.
			if p.global_position.distance_to(o) < MapManager.ROCK_CLEAR:
				bad += 1
				print("[spawn] player near obstacle (rock or log): ", p.global_position)
	print("[spawn] bad spawns:", bad)
	game.queue_free()
	quit()
