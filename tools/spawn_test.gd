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
			if p.global_position.distance_to(o) < 30.0:
				bad += 1
				print("[spawn] player near rock: ", p.global_position)
	print("[spawn] bad spawns:", bad)
	game.queue_free()
	quit()
