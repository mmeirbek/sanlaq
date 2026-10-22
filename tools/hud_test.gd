extends "res://tools/test_case.gd"
## HUD раунда Соқыртеке (scenes/world/game_hud.tscn): таймер, значки бегунов,
## баннер роли, окно «Ұсталдыңыз» и итог раунда.

const HUD_SCENE := "res://scenes/world/game_hud.tscn"


func _init() -> void:
	await process_frame
	var hud: GameHUD = await mount(HUD_SCENE)
	_test_timer(hud)
	_test_runner_icons(hud)
	_test_role(hud)
	await _test_caught_choice_keeps_watching(hud)
	_test_result_closes_caught_choice(hud)
	await unmount(hud)
	finish("HUD")


func _test_timer(hud: GameHUD) -> void:
	var timer: Label = hud.get_node("%Timer")
	hud.update_timer(65.2)
	check(timer.text == "1:06", "таймер в минутах и секундах, получено %s" % timer.text)
	check(not timer.has_theme_color_override("font_color"), "до конца больше 10 с — обычный цвет")
	hud.update_timer(9.5)
	check(timer.text == "0:10", "секунды округляются вверх, получено %s" % timer.text)
	check(timer.get_theme_color("font_color") == UiTokens.DANGER, "последние 10 с — тревожный цвет")
	hud.update_timer(-3.0)
	check(timer.text == "0:00", "после конца времени — 0:00, получено %s" % timer.text)


func _test_runner_icons(hud: GameHUD) -> void:
	var runners: HBoxContainer = hud.get_node("%Runners")
	hud.update_remaining(3, 5)
	check(runners.get_child_count() == 5, "значок на каждого бегуна, получено %d" % runners.get_child_count())
	var caught := runners.get_children().filter(
		func(icon: TextureRect) -> bool: return icon.texture == GameHUD.CAUGHT_ICON)
	check(caught.size() == 2, "пойманные — значком с крестом, получено %d" % caught.size())
	hud.update_remaining(0, 5)
	check(runners.get_child_count() == 5, "после поимок значков столько же")


func _test_role(hud: GameHUD) -> void:
	hud.show_role("СІЗ ҚАШУШЫСЫЗ!", "«Айгүл» — Соқыртеке!", "МАҚСАТ", 3.0)
	check((hud.get_node("%Banner") as Control).visible, "роль показана баннером")
	check((hud.get_node("%Objective") as Label).text == "МАҚСАТ", "цель раунда — на плашке")


## Пробел или Enter в окне «Ұсталдыңыз» не должны выкидывать в меню: в фокусе
## «БАҚЫЛАУ». Раньше фокус был на «БАС МӘЗІРГЕ».
func _test_caught_choice_keeps_watching(hud: GameHUD) -> void:
	var outcome: Array[String] = []
	hud.spectate_requested.connect(func() -> void: outcome.append("watch"))
	hud.leave_requested.connect(func() -> void: outcome.append("leave"))
	hud.show_caught_choice()
	await process_frame
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		root.push_input(key)
		await process_frame
	check(outcome == ["watch"], "пробел в окне «Ұсталдыңыз» — наблюдение, получено %s" % [outcome])


func _test_result_closes_caught_choice(hud: GameHUD) -> void:
	var dialog: Control = hud.get_node("%CaughtChoice")
	hud.show_caught_choice()
	hud.show_result("ҚАШУШЫЛАР ЖЕҢДІ!")
	check(not dialog.visible, "итог раунда закрывает окно «Ұсталдыңыз»")
	check((hud.get_node("%Banner") as Control).visible, "итог показан баннером")
