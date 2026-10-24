extends SceneTree
## Снимает PNG с каждого экрана и с самой игры — чтобы глазами проверить
## раскладку и читаемость и сравнить «до/после» редизайна. ui_audit.gd ловит
## перекрытия контролов, но не видит, например, тёмный заголовок на тёмном фоне.
##
##     godot --path . --script tools/screenshot_screens.gd
##     godot --path . --script tools/screenshot_screens.gd -- --size=1560x720 --out=C:/shots/phone
##
##   --size  размер окна, по умолчанию 1280x720. 1560x720 — телефон 19.5:9,
##           960x720 — планшет 4:3.
##   --out   папка для PNG, по умолчанию tools/preview/screens/.
##   --only  снять только эти кадры, через запятую: --only=main_menu,ui_gallery
##
## Запускать НЕ в headless: без рендера картинки будут пустыми. Сами PNG не
## коммитятся (см. .gitignore) — это расходный материал для ревью.

const DEFAULT_OUT_DIR := "res://tools/preview/screens/"
const DEFAULT_SIZE := Vector2i(1280, 720)

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
	"results": "res://scenes/ui/results.tscn",
	"ui_gallery": "res://tools/ui_gallery.tscn",
	"ui_gallery_overlays": "res://tools/ui_gallery_overlays.tscn",
}
## Брифинг общий для всех режимов, поэтому снимается по разу на каждый.
const BRIEFINGS := ["sokyroteke", "abai_says", "togyz_qumalaq", "aq_suyek"]
## Соқыртеке снимается из двух запусков. За ловца — секунда от старта
## (обратный отсчёт), разгар раунда и квиз; за бегуна — разгар раунда, где без
## тумана ловца виден весь аул. Числа — секунды от старта.
const GAME_SCENE := "res://scenes/world/game.tscn"
const GAME_RUNS := {
	Roles.Role.SOKYROTEKE: {"game_countdown": 1.0, "game_playing": 6.0, "game_quiz": 6.5},
	Roles.Role.RUNNER: {"game_runner": 6.0},
}

var _out_dir := ""
## Пусто — снимать всё.
var _only: PackedStringArray = []


func _init() -> void:
	var args := _parse_user_args()
	_out_dir = ProjectSettings.globalize_path(args.get("out", DEFAULT_OUT_DIR))
	if args.has("only"):
		_only = args.only.split(",")
	# Автолоады добавляются в дерево не сразу — ждём, иначе их не найти.
	# Окно к этому моменту тоже уже создано и развёрнуто по настройкам проекта.
	await process_frame
	await process_frame
	# Без фиксированного размера снимок зависел бы от монитора.
	root.mode = Window.MODE_WINDOWED
	root.size = _parse_size(args.get("size", ""))
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out_dir)

	for name in SCENES:
		await _shoot(name, SCENES[name])
	for mode_id in BRIEFINGS:
		root.get_node("/root/SceneRouter").set_pending_briefing(mode_id)
		await _shoot("briefing_" + mode_id, "res://scenes/ui/mode_briefing.tscn")
	for role in GAME_RUNS:
		await _shoot_game(role, GAME_RUNS[role])

	print("\nготово: ", _out_dir)
	quit()


func _shoot(name: String, scene_path: String) -> void:
	if not _wanted(name):
		return
	var instance := _mount(scene_path)
	if instance == null:
		return
	# Даём раскладке и шрифтам устояться, иначе попадёт кадр до вёрстки.
	for _i in 12:
		await process_frame
	_capture(name)
	await _unmount(instance)


func _shoot_game(role: Roles.Role, shots: Dictionary) -> void:
	if not shots.keys().any(_wanted):
		return
	root.get_node("/root/SceneRouter").set_pending_game_data({"role": role})
	var game := _mount(GAME_SCENE)
	if game == null:
		return
	var elapsed := 0.0
	for name in shots:
		var at: float = shots[name]
		await create_timer(at - elapsed).timeout
		elapsed = at
		if name == "game_quiz":
			await _open_quiz(game)
		if _wanted(name):
			_capture(name)
	await _unmount(game)


## Квиз как после поимки первого бегуна.
func _open_quiz(game: Node) -> void:
	var runner = game.match_mgr.players.filter(func(p) -> bool: return p != game.match_mgr.sokyroteke)[0]
	game.quiz_hud.show_quiz(runner.get_random_clothing_item_for_quiz(), 10.0)
	for _i in 6:
		await process_frame


func _mount(scene_path: String) -> Node:
	var pack := load(scene_path) as PackedScene
	if pack == null:
		print("не загрузилась сцена: ", scene_path)
		return null
	var instance := pack.instantiate()
	root.add_child(instance)
	return instance


func _unmount(instance: Node) -> void:
	root.remove_child(instance)
	instance.queue_free()
	await process_frame


func _capture(name: String) -> void:
	root.get_texture().get_image().save_png(_out_dir.path_join(name + ".png"))
	print("снято: ", name)


func _wanted(name: String) -> bool:
	return _only.is_empty() or name in _only


## Аргументы после «--» в виде --ключ=значение.
func _parse_user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			args[pair[0]] = pair[1]
	return args


func _parse_size(text: String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return DEFAULT_SIZE
