extends SceneTree

func _init() -> void:
	await process_frame
	await process_frame

	var wardrobe_path := "res://scenes/ui/wardrobe.tscn"
	var game_path := "res://scenes/world/game.tscn"

	var err := await _try_load(wardrobe_path)
	if err != OK:
		print("[test] WARDROBE FAILED: ", err)
	else:
		print("[test] wardrobe OK")

	err = await _try_load(game_path)
	if err != OK:
		print("[test] GAME FAILED: ", err)
	else:
		print("[test] game OK")

	quit()

func _try_load(path: String) -> Error:
	var pack := load(path) as PackedScene
	if pack == null:
		return ERR_CANT_OPEN
	var inst := pack.instantiate()
	if inst == null:
		return ERR_CANT_CREATE
	root.add_child(inst)
	await process_frame
	await process_frame
	inst.queue_free()
	return OK
