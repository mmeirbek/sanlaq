extends SceneTree

const SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/lobby.tscn",
	"res://scenes/ui/wardrobe.tscn",
	"res://scenes/ui/codex.tscn",
	"res://scenes/ui/results.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/components/sanlaq_ornament.tscn",
	"res://scenes/ui/components/sanlaq_panel.tscn",
	"res://scenes/ui/components/sanlaq_button.tscn",
	"res://scenes/ui/components/sanlaq_label.tscn",
	"res://scenes/ui/components/sanlaq_divider.tscn",
	"res://scenes/world/game.tscn",
]

func _init() -> void:
	await process_frame
	await process_frame
	var failed := 0
	for path in SCENES:
		var err := await _try_load(path)
		if err != OK:
			failed += 1
			print("[test] FAILED ", path, " -> ", err)
		else:
			print("[test] OK ", path)
	if failed == 0:
		print("[test] ALL PASSED")
	else:
		print("[test] FAILURES: ", failed)
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
	await process_frame
	return OK
