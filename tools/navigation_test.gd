extends "res://tools/test_case.gd"
## Esc работает на каждом экране, а посреди партии ставит паузу (этап 6.2).
## Экраны открываются настоящим SceneRouter, Esc приходит настоящим событием.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const MODE_SELECT := "res://scenes/ui/mode_select.tscn"
## Экран -> куда ведёт Esc. Пусто — «куда угодно, лишь бы ушёл с экрана».
const BACK_TARGETS := {
	"go_to_mode_select": MAIN_MENU,
	"go_to_settings": "",
	"go_to_about": "",
	"go_to_codex": "",
	"go_to_wardrobe": "",
	"go_to_lobby": "",
	"go_to_results": MAIN_MENU,
	"go_to_abai_says": MODE_SELECT,
	"go_to_togyz_qumalaq": MODE_SELECT,
}

var _router: Node


func _init() -> void:
	await process_frame
	_router = autoload("SceneRouter")

	for method: String in BACK_TARGETS:
		await _go(method)
		var screen := _current()
		await _escape()
		var expected: String = BACK_TARGETS[method]
		if expected.is_empty():
			check(_current() != screen, "%s: Esc уводит с экрана" % method)
		else:
			check(_current() == expected, "%s: Esc ведёт на %s, получено %s" % [method, expected.get_file(), _current()])

	await _go("go_to_main_menu")
	await _escape()
	var quit_dialog := current_scene.get_node("%QuitDialog") as Control
	check(_current() == MAIN_MENU and quit_dialog.visible, "главное меню: Esc спрашивает о выходе")
	await _escape()
	check(not quit_dialog.visible, "главное меню: второй Esc закрывает вопрос")

	await _pause_round_trip("go_to_togyz_qumalaq", func() -> void:
		(current_scene.get_node("%VsBotBtn") as Button).pressed.emit())
	await _pause_round_trip("go_to_abai_says", func() -> void:
		(current_scene.get_node("%P2Btn") as Button).pressed.emit())
	await _pause_round_trip("go_to_aq_suyek", func() -> void: pass)
	await _pause_round_trip("go_to_game", func() -> void: pass)
	finish("NAVIGATION")


## Посреди партии Esc ставит паузу, второй Esc снимает её, игра не уходит.
func _pause_round_trip(method: String, start: Callable) -> void:
	await _go(method)
	start.call()
	await process_frame
	var screen := _current()
	await _escape()
	var pause := _find_pause(current_scene)
	check(pause != null and pause.visible and paused, "%s: Esc посреди партии ставит паузу" % method)
	check(_current() == screen, "%s: из партии Esc не уводит" % method)
	await _escape()
	check(pause != null and not pause.visible and not paused, "%s: второй Esc снимает паузу" % method)


func _find_pause(node: Node) -> Control:
	for child in node.find_children("*", "Control", true, false):
		# Не preload: класс паузы обращается к автолоадам (см. шапку test_case.gd).
		var script := child.get_script() as Script
		if script != null and script.resource_path == "res://scripts/ui/components/pause_menu.gd":
			return child
	return null


func _go(method: String) -> void:
	_router.call(method)
	await create_timer(0.3).timeout


func _escape() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	root.push_input(event)
	var release := InputEventAction.new()
	release.action = &"ui_cancel"
	root.push_input(release)
	await create_timer(0.3).timeout


func _current() -> String:
	return current_scene.scene_file_path if current_scene else ""
