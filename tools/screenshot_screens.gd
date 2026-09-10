extends SceneTree
## Снимает по PNG с каждого экрана в tools/preview/screens/ — чтобы глазами
## проверить раскладку и читаемость. ui_audit.gd ловит перекрытия контролов, но
## не видит, например, тёмный заголовок на тёмном фоне.
##
##     godot --path . --resolution 1280x720 --script tools/screenshot_screens.gd
##
## Запускать НЕ в headless: без рендера картинки будут пустыми. Сами PNG не
## коммитятся (см. .gitignore) — это расходный материал для ревью.

const OUT_DIR := "res://tools/preview/screens/"

## Экраны без особых условий.
const SCENES := {
	"main_menu": "res://scenes/ui/main_menu.tscn",
	"mode_select": "res://scenes/ui/mode_select.tscn",
	"abai_says": "res://scenes/ui/abai_says.tscn",
	"togyz_qumalaq": "res://scenes/ui/togyz_qumalaq.tscn",
	"aq_suyek": "res://scenes/ui/aq_suyek.tscn",
	"lobby": "res://scenes/ui/lobby.tscn",
	"wardrobe": "res://scenes/ui/wardrobe.tscn",
	"codex": "res://scenes/ui/codex.tscn",
	"settings": "res://scenes/ui/settings.tscn",
	"about": "res://scenes/ui/about.tscn",
}
## Брифинг общий для всех режимов, поэтому снимается по разу на каждый.
const BRIEFINGS := ["sokyroteke", "abai_says", "togyz_qumalaq", "aq_suyek"]

func _init() -> void:
	# Автолоады добавляются в дерево не сразу — ждём, иначе их не найти.
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	for name in SCENES:
		await _shoot(name, SCENES[name])
	for mode_id in BRIEFINGS:
		root.get_node("/root/SceneRouter").set_pending_briefing(mode_id)
		await _shoot("briefing_" + mode_id, "res://scenes/ui/mode_briefing.tscn")

	print("\nготово: ", ProjectSettings.globalize_path(OUT_DIR))
	quit()

func _shoot(name: String, scene_path: String) -> void:
	var pack := load(scene_path) as PackedScene
	if pack == null:
		print("не загрузилась сцена: ", scene_path)
		return
	var inst := pack.instantiate()
	root.add_child(inst)
	# Даём раскладке и шрифтам устояться, иначе попадёт кадр до вёрстки.
	for _i in 12:
		await process_frame
	var path := ProjectSettings.globalize_path(OUT_DIR + name + ".png")
	root.get_texture().get_image().save_png(path)
	print("снято: ", name)
	root.remove_child(inst)
	inst.queue_free()
	await process_frame
