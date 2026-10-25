extends "res://tools/test_case.gd"
## Переходы между экранами со шторкой (autoload/scene_router.gd). В headless
## шторка обычно выключена, здесь её включаем: именно с ней раньше терялись
## переходы, а уходящий экран ещё работал.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const ABOUT := "res://scenes/ui/about.tscn"
const SETTINGS := "res://scenes/ui/settings.tscn"
const MODE_SELECT := "res://scenes/ui/mode_select.tscn"


func _init() -> void:
	await process_frame
	var router := autoload("SceneRouter")
	router.animate_transitions = true

	router.go_to_main_menu()
	await _transition_done(router)
	check(_current() == MAIN_MENU, "переход со шторкой доходит до экрана, получено %s" % _current())

	router.go_to_about()
	await process_frame
	check(current_scene.process_mode == Node.PROCESS_MODE_DISABLED,
		"уходящий экран заморожен: таймеры и нажатия на нём не работают")
	router.go_to_settings()
	await _transition_done(router)
	check(_current() == SETTINGS, "запрос во время перехода не теряется — побеждает последний, получено %s" % _current())

	# Брифинг без такого режима сам уводит на выбор режима прямо из _ready —
	# посреди перехода. Раньше этот переход пропадал, и игрок оставался на пустом экране.
	router.go_to_mode_briefing("no_such_mode")
	await _transition_done(router)
	await _transition_done(router)
	check(_current() == MODE_SELECT, "переход из _ready новой сцены выполняется, получено %s" % _current())
	finish("ROUTER")


func _current() -> String:
	return current_scene.scene_file_path if current_scene else ""


## Уход, кадр смены сцены и проявление — с запасом.
func _transition_done(router: Node) -> void:
	await create_timer(router.FADE_OUT + router.FADE_IN + 0.3).timeout
