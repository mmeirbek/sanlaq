extends "res://tools/test_case.gd"
## Поведение экранов меню: лобби (число ботов, роль, что уходит в игру), шкаф
## (надеть вещь) и итоги раунда без полных данных.


func _init() -> void:
	await process_frame
	await _test_lobby()
	await _test_wardrobe()
	await _test_results_without_data()
	finish("MENU_SCREENS")


func _test_lobby() -> void:
	var router := autoload("SceneRouter")
	router.set_pending_game_data({})
	var lobby := await mount("res://scenes/ui/lobby.tscn")
	var random_card: SelectableCard = lobby.get_node("%RandomCard")
	check(random_card.selected and not (lobby.get_node("%SokyrotekeCard") as SelectableCard).selected
		and not (lobby.get_node("%RunnerCard") as SelectableCard).selected,
		"по умолчанию роль — по жребию, как в документации")
	var players: HBoxContainer = lobby.get_node("%PlayersRow")
	for _i in 10:
		(lobby.get_node("%PlusBtn") as Button).pressed.emit()
	await process_frame
	check(players.get_child_count() == 8, "ботов не больше 7: 8 портретов, получено %d" % players.get_child_count())
	for _i in 10:
		(lobby.get_node("%MinusBtn") as Button).pressed.emit()
	await process_frame
	check(players.get_child_count() == 2, "ботов не меньше 1: 2 портрета, получено %d" % players.get_child_count())
	var runner: SelectableCard = lobby.get_node("%RunnerCard")
	runner.pressed.emit()
	check(runner.selected and not (lobby.get_node("%SokyrotekeCard") as SelectableCard).selected
		and not random_card.selected, "выбрана одна роль — бегун")
	(lobby.get_node("%StartBtn") as Button).pressed.emit()
	var sent: Dictionary = router.peek_pending_game_data()
	check(sent.get("bots") == 1 and sent.get("role") == Roles.Role.RUNNER, "в игру уходят роль и число ботов: %s" % sent)
	await process_frame
	await process_frame
	if current_scene:
		current_scene.queue_free()
	await unmount(lobby)
	_test_role_draw()


## Жребий: из четырёх участников ловцом выпадает каждый — игрок примерно в
## четверти партий. В 400 бросках выйти за 50…150 почти невозможно (±5,7σ).
func _test_role_draw() -> void:
	var seekers := 0
	for _i in 400:
		if Roles.draw(4) == Roles.Role.SOKYROTEKE:
			seekers += 1
	check(seekers > 50 and seekers < 150, "игрок ловец примерно в 1 из 4 партий: %d из 400" % seekers)


func _test_wardrobe() -> void:
	var save := autoload("SaveManager")
	var wardrobe := await mount("res://scenes/ui/wardrobe.tscn")
	var items: GridContainer = wardrobe.get_node("%Items")
	var slot := ClothingItem.SlotType.HEAD
	var before: String = save.get_equipped(slot)
	var other: ClothingCard = null
	for card: ClothingCard in items.get_children():
		if card.item.id != before:
			other = card
	check(other != null, "в шкафу есть другая шапка")
	if other:
		var id := other.item.id
		other.pressed.emit()
		await process_frame
		check(save.get_equipped(slot) == id, "нажатие надевает вещь: %s" % id)
		var selected := items.get_children().filter(func(card: ClothingCard) -> bool: return card.selected)
		check(selected.size() == 1 and (selected[0] as ClothingCard).item.id == id, "выбрана ровно надетая вещь")
		save.set_equipped(slot, before)
	await unmount(wardrobe)


func _test_results_without_data() -> void:
	var router := autoload("SceneRouter")
	for results in [{}, {"winner": Roles.Winner.SOKYROTEKE}]:
		router.set_pending_results(results)
		var screen := await mount("res://scenes/ui/results.tscn")
		check(not (screen.get_node("%WinnerLabel") as Label).text.is_empty()
			and not (screen.get_node("%Stats") as Label).text.is_empty(),
			"итоги показываются и без полных данных: %s" % results)
		await unmount(screen)
