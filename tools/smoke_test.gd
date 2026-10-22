extends "res://tools/test_case.gd"
## Smoke-тест: каждая сцена из scenes/ и tools/ (витрины дизайн-системы)
## загружается, встаёт в дерево и живёт пару кадров без ошибок движка. Список
## сцен собирается обходом папок, так что новая сцена попадает в тест сама.

const SCENE_ROOTS := ["res://scenes", "res://tools"]


func _init() -> void:
	await process_frame
	await process_frame
	var scenes: PackedStringArray = []
	for scene_root in SCENE_ROOTS:
		scenes.append_array(_find_scenes(scene_root))
	for path in scenes:
		var instance := await mount(path)
		if instance == null:
			continue  # mount() уже записал провал
		await unmount(instance)
		print("[test] ok: ", path)
	finish("SMOKE")


func _find_scenes(dir_path: String) -> PackedStringArray:
	var scenes: PackedStringArray = []
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "tscn":
			scenes.append(dir_path.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		scenes.append_array(_find_scenes(dir_path.path_join(sub_dir)))
	return scenes
