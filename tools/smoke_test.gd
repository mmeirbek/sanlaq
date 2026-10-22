extends "res://tools/test_case.gd"
## Smoke-тест: каждая сцена из scenes/ загружается, встаёт в дерево и живёт
## пару кадров без ошибок движка. Список сцен собирается обходом папки, так что
## новая сцена попадает в тест автоматически.

const SCENES_ROOT := "res://scenes"


func _init() -> void:
	await process_frame
	await process_frame
	for path in _find_scenes(SCENES_ROOT):
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
