extends SceneTree
## Автотест экранов режимов «Абай айтады» и «Тоғыз құмалақ». Запускается в CI:
##     godot --headless --path . --script tools/modes_smoke_test.gd
## При провале выходит с кодом 1 и роняет сборку — как и togyz_rules_test.gd.
##
## Правила тоғыз проверяет togyz_rules_test.gd; здесь проверяется другое — что
## сцены поднимаются, все %-узлы на месте, кнопки подключены и полный цикл
## партии проходит по состояниям, ничего не роняя.

var fails := 0

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	await _test_mode_select()
	await _test_abai()
	await _test_togyz()
	print("[test] " + ("MODES OK" if fails == 0 else "MODES FAILED (%d)" % fails))
	quit(1 if fails > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[test] ok: ", msg)
	else:
		fails += 1
		print("[test] FAIL: ", msg)

func _mount(path: String) -> Node:
	var pack := load(path) as PackedScene
	if pack == null:
		_check(false, "сцена загружается: " + path)
		return null
	var inst := pack.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	return inst

func _drop(inst: Node) -> void:
	root.remove_child(inst)
	inst.queue_free()
	await process_frame

## Каждый режим должен стоять на своём фоне, а не на дефолтном фоне лобби.
func _check_backdrop(node: Node, expected: SanlaqSceneBackdrop.Variant, label: String) -> void:
	var bg := node.get_node_or_null("Background") as SanlaqSceneBackdrop
	if bg == null:
		_check(false, "%s: узел Background на месте" % label)
		return
	_check(bg.variant == expected, "%s: свой вариант фона, получен %d" % [label, bg.variant])
	var path: String = SanlaqSceneBackdrop.TEXTURES.get(bg.variant, "")
	_check(ResourceLoader.exists(path), "%s: файл фона на месте (%s)" % [label, path])
	_check(bg.get("_texture") != null, "%s: текстура фона загрузилась" % label)

func _connected(node: Node, unique_name: String) -> bool:
	var btn := node.get_node_or_null(unique_name) as Button
	return btn != null and not btn.pressed.get_connections().is_empty()

# --- Экран выбора режима -----------------------------------------------------

func _test_mode_select() -> void:
	var n := await _mount("res://scenes/ui/mode_select.tscn")
	if n == null:
		return
	for btn_name in ["%ChasePlayBtn", "%AbaiPlayBtn", "%TogyzPlayBtn", "%BackBtn"]:
		_check(_connected(n, btn_name), "выбор режима: %s подключена" % btn_name)
	await _drop(n)

# --- Абай айтады -------------------------------------------------------------

func _test_abai() -> void:
	var n := await _mount("res://scenes/ui/abai_says.tscn")
	if n == null:
		return
	_check_backdrop(n, SanlaqSceneBackdrop.Variant.ABAI, "абай")
	_check((n.get_node("%SetupPanel") as Control).visible, "абай: экран выбора числа игроков виден")
	_check(_connected(n, "%BackBtn"), "абай: кнопка «Артқа» подключена")

	(n.get_node("%P2Btn") as Button).pressed.emit()
	await process_frame
	var words: Array = n.get("_words")
	_check(words.size() == 6, "абай: набрано 6 карточек, получено %d" % words.size())
	_check((n.get_node("%CardGrid") as GridContainer).get_child_count() == 6, "абай: 6 карточек в сетке")

	# Показ тізбек: стартовая пауза 0.6 + 2 элемента по (SHOW_ON + SHOW_GAP).
	await create_timer(2.6).timeout
	var seq: Array = n.get("_sequence")
	_check(seq.size() == 2, "абай: длина тізбек в 1-м раунде = 2, получено %d" % seq.size())
	_check((n.get_node("%HandoffPanel") as Control).visible, "абай: после показа — экран передачи устройства")

	# Первый по очереди повторяет верно.
	(n.get_node("%ReadyBtn") as Button).pressed.emit()
	await process_frame
	for step in seq:
		n.call("_on_card_pressed", step)
		await process_frame
	await create_timer(1.2).timeout
	_check((n.get_node("%HandoffPanel") as Control).visible, "абай: ход перешёл ко второму игроку")

	# Второй ошибается на первом же элементе — остаётся один выживший, партия кончается.
	(n.get_node("%ReadyBtn") as Button).pressed.emit()
	await process_frame
	n.call("_on_card_pressed", (int(seq[0]) + 1) % words.size())
	await create_timer(1.2).timeout
	_check((n.get_node("%EndPanel") as Control).visible, "абай: экран итогов показан после вылета второго")
	var winner: String = (n.get_node("%WinnerLabel") as Label).text
	_check(winner != "" and winner != "—", "абай: победитель подписан («%s»)" % winner)

	(n.get_node("%AgainBtn") as Button).pressed.emit()
	await process_frame
	_check((n.get_node("%SetupPanel") as Control).visible, "абай: «ещё раз» вернул к выбору числа игроков")
	await _drop(n)

# --- Тоғыз құмалақ -----------------------------------------------------------

func _test_togyz() -> void:
	var n := await _mount("res://scenes/ui/togyz_qumalaq.tscn")
	if n == null:
		return
	_check_backdrop(n, SanlaqSceneBackdrop.Variant.TOGYZ, "тоғыз")
	_check((n.get_node("%SetupPanel") as Control).visible, "тоғыз: экран выбора соперника виден")
	_check(_connected(n, "%BackBtn"), "тоғыз: кнопка «Артқа» подключена")
	_check(_connected(n, "%VsHumanBtn"), "тоғыз: кнопка игры вдвоём подключена")

	(n.get_node("%VsBotBtn") as Button).pressed.emit()
	await process_frame
	_check((n.get_node("%BoardPanel") as Control).visible, "тоғыз: доска показана")
	_check((n.get_node("%BottomRow") as HBoxContainer).get_child_count() == GameBoard.PER_SIDE,
		"тоғыз: 9 отау в нижнем ряду")
	_check((n.get_node("%TopRow") as HBoxContainer).get_child_count() == GameBoard.PER_SIDE,
		"тоғыз: 9 отау в верхнем ряду")
	_check((n.get_node("%RightOwner") as Label).text != "", "тоғыз: казан подписан именем владельца")

	# Прогоняем несколько пар ходов «человек → бот» через реальный обработчик клика.
	var human_moves := 0
	for _turn in 6:
		var board: GameBoard = n.get("_board")
		if board == null or board.is_over():
			break
		if board.current_player == 0 and not bool(n.get("_animating")):
			n.call("_on_pit_pressed", board.legal_moves()[0])
			human_moves += 1
		await create_timer(2.6).timeout

	var board2: GameBoard = n.get("_board")
	_check(board2 != null, "тоғыз: доска жива после серии ходов")
	if board2 != null:
		_check(human_moves > 0, "тоғыз: ходы человека проходят через клик по отау")
		_check(board2.total_balls() == GameBoard.TOTAL_BALLS,
			"тоғыз: на доске и в казанах 162 құмалақ, получено %d" % board2.total_balls())
		_check(board2.kazan[0] + board2.kazan[1] > 0, "тоғыз: казаны наполняются по ходу партии")
		print("[test] .. счёт после прогона: %d : %d" % [board2.kazan[0], board2.kazan[1]])
	_check((n.get_node("%TurnLabel") as Label).text != "", "тоғыз: индикатор хода заполнен")
	await _drop(n)
