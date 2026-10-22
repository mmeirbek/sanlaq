extends "res://tools/test_case.gd"
## Автотест экранов режимов «Абай айтады» и «Тоғыз құмалақ». Запускается в CI:
##     godot --headless --path . --script tools/modes_smoke_test.gd
## При провале выходит с кодом 1 и роняет сборку (см. tools/test_case.gd).
##
## Правила тоғыз проверяет togyz_rules_test.gd; здесь проверяется другое — что
## сцены поднимаются, все %-узлы на месте, кнопки подключены и полный цикл
## партии проходит по состояниям, ничего не роняя.

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	await _test_mode_select()
	await _test_briefings()
	await _test_abai()
	await _test_togyz()
	finish("MODES")

## Каждый режим должен стоять на своём фоне, а не на дефолтном фоне лобби.
func _check_backdrop(node: Node, expected: SanlaqSceneBackdrop.Variant, label: String) -> void:
	var bg := node.get_node_or_null("Background") as SanlaqSceneBackdrop
	if bg == null:
		check(false, "%s: узел Background на месте" % label)
		return
	check(bg.variant == expected, "%s: свой вариант фона, получен %d" % [label, bg.variant])
	var path: String = SanlaqSceneBackdrop.TEXTURES.get(bg.variant, "")
	check(ResourceLoader.exists(path), "%s: файл фона на месте (%s)" % [label, path])
	check(bg.get("_texture") != null, "%s: текстура фона загрузилась" % label)

func _connected(node: Node, unique_name: String) -> bool:
	var btn := node.get_node_or_null(unique_name) as Button
	return btn != null and not btn.pressed.get_connections().is_empty()

# --- Экран выбора режима -----------------------------------------------------

func _test_mode_select() -> void:
	var n := await mount("res://scenes/ui/mode_select.tscn")
	if n == null:
		return
	for btn_name in ["%ChasePlayBtn", "%AbaiPlayBtn", "%TogyzPlayBtn", "%AqSuyekPlayBtn"]:
		check(_connected(n, btn_name), "выбор режима: %s подключена" % btn_name)
	var header := n.get_node_or_null("%Header") as ScreenHeader
	check(header != null and not header.back_pressed.get_connections().is_empty(),
		"выбор режима: «Артқа» подключена")
	await unmount(n)

# --- Экраны-объяснения перед режимами ---------------------------------------

func _test_briefings() -> void:
	for mode_id in ["sokyroteke", "abai_says", "togyz_qumalaq"]:
		await _test_briefing(mode_id)
	await _test_narration_advances()

## Главное в озвучке — что она сама двигается по строкам. Проверяем на одной
## короткой строке, чтобы тест не ждал полминуты.
func _test_narration_advances() -> void:
	var settings := autoload("GameSettings")
	var was_enabled: bool = settings.briefing_voice_enabled
	settings.set_briefing_voice_enabled(true)

	autoload("SceneRouter").set_pending_briefing("togyz_qumalaq")
	var n := await mount("res://scenes/ui/mode_briefing.tscn")
	if n == null:
		settings.set_briefing_voice_enabled(was_enabled)
		return
	var last := int(n.get("_spoken").size()) - 2
	n.call("_speak_line", last)
	check(int(n.get("_current_line")) == last, "озвучка: встали на предпоследнюю строку")

	# Опрашиваем, а не ждём фиксированное время: под настоящим звуком строка
	# длится секунды, под пустым аудиодрайвером CI — доли секунды, и в обоих
	# случаях цепочка обязана пройти через следующую строку.
	var seen := {}
	for _tick in 120:
		seen[int(n.get("_current_line"))] = true
		if seen.has(-1):
			break
		await create_timer(0.1).timeout
	check(seen.has(last + 1),
		"озвучка: сама перешла на следующую строку (%d)" % (last + 1))
	check(seen.has(-1), "озвучка: дошла до конца списка и остановилась")
	await unmount(n)
	settings.set_briefing_voice_enabled(was_enabled)

func _test_briefing(mode_id: String) -> void:
	var brief: ModeBriefing = autoload("AssetRegistry").get_briefing(mode_id)
	check(brief != null, "брифинг: ресурс режима %s найден" % mode_id)
	if brief == null:
		return
	check(not brief.how_to_play.is_empty(), "%s: есть шаги «как играется»" % mode_id)
	check(not brief.skills.is_empty(), "%s: есть пункты «чему учит»" % mode_id)

	# Обе локали должны давать текст, и английская — отличаться от казахской,
	# иначе перевода на самом деле нет и tr() вернул ключ.
	var untranslated: Array[String] = []
	var lines := brief.spoken_lines()
	lines.append(brief.title)
	lines.append(brief.kicker)
	TranslationServer.set_locale("en")
	for line in lines:
		if tr(line) == line:
			untranslated.append(line)
	TranslationServer.set_locale("kk")
	check(untranslated.is_empty(),
		"%s: все строки переведены на английский (без перевода: %d)" % [mode_id, untranslated.size()])
	for line in untranslated:
		print("[test]    .. нет перевода: ", line.substr(0, 60))

	# Озвучка: файл на каждую строку, на обоих языках.
	var missing_voice := 0
	for lang in ["kk", "en"]:
		for i in brief.spoken_lines().size():
			var path := "res://assets/audio/voice/%s/%s.wav" % [lang, brief.voice_id(i)]
			if not ResourceLoader.exists(path):
				missing_voice += 1
				print("[test]    .. нет озвучки: ", path)
	check(missing_voice == 0, "%s: озвучены все строки на kk и en (нет: %d)" % [mode_id, missing_voice])

	var settings := autoload("GameSettings")
	var was_enabled: bool = settings.briefing_voice_enabled
	settings.set_briefing_voice_enabled(false)

	autoload("SceneRouter").set_pending_briefing(mode_id)
	var n := await mount("res://scenes/ui/mode_briefing.tscn")
	if n == null:
		settings.set_briefing_voice_enabled(was_enabled)
		return
	_check_backdrop(n, brief.backdrop as SanlaqSceneBackdrop.Variant, mode_id + " (брифинг)")
	check((n.get_node("%Header") as SanlaqHeader).title == brief.title,
		"%s: заголовок брифинга подставлен" % mode_id)
	var steps: VBoxContainer = n.get_node("%StepsBox")
	var skills: VBoxContainer = n.get_node("%SkillsBox")
	check(steps.get_child_count() == brief.how_to_play.size(),
		"%s: показаны все шаги, получено %d" % [mode_id, steps.get_child_count()])

	# У каждого шага своя схема, и схема умеет нарисовать ровно столько шагов,
	# сколько их в ресурсе — иначе лишний шаг получил бы чужую картинку.
	var drawn: int = StepDiagram.STEPS_DRAWN.get(mode_id, 0)
	check(drawn == brief.how_to_play.size(),
		"%s: схема покрывает все шаги (умеет %d, шагов %d)" % [mode_id, drawn, brief.how_to_play.size()])
	var diagrams := 0
	for row in steps.get_children():
		for node in row.get_children():
			for leaf in node.get_children():
				if leaf is StepDiagram:
					diagrams += 1
					check((leaf as StepDiagram).mode_id == mode_id,
						"%s: схема знает свой режим" % mode_id)
	check(diagrams == brief.how_to_play.size(),
		"%s: схема стоит у каждого шага, найдено %d" % [mode_id, diagrams])
	check(skills.get_child_count() == brief.skills.size(),
		"%s: показаны все навыки, получено %d" % [mode_id, skills.get_child_count()])
	check(_connected(n, "%StartBtn"), "%s: кнопка «ОЙНАУ» подключена" % mode_id)
	check(_connected(n, "%BackBtn"), "%s: кнопка «Артқа» подключена" % mode_id)
	check((n.get_node("%VoiceBtn") as Button).visible,
		"%s: кнопка озвучки показана — голос найден" % mode_id)

	# Файл озвучки должен не просто лежать на диске, а грузиться как аудиопоток.
	var first_voice := load("res://assets/audio/voice/kk/%s.wav" % brief.voice_id(0))
	check(first_voice is AudioStream, "%s: файл озвучки грузится как аудиопоток" % mode_id)

	var voice_btn := n.get_node("%VoiceBtn") as CheckButton
	# По умолчанию экран молчит, и переключатель это показывает.
	check(not bool(n.get("_playing")), "%s: по умолчанию озвучка молчит" % mode_id)
	check(not voice_btn.button_pressed, "%s: переключатель озвучки выключен" % mode_id)
	# И клик по строке тоже молчит, пока озвучка выключена.
	n.call("_on_line_pressed", 2)
	check(not bool(n.get("_playing")), "%s: клик по строке молчит при выключенной озвучке" % mode_id)

	# Включаем: читает и запоминается для всех режимов.
	voice_btn.button_pressed = true
	check(bool(n.get("_playing")), "%s: включённая озвучка начинает читать" % mode_id)
	check(settings.briefing_voice_enabled, "%s: выбор сохранён в настройках" % mode_id)
	n.call("_on_line_pressed", 2)
	check(int(n.get("_current_line")) == 2, "%s: клик по строке переводит озвучку на неё" % mode_id)

	# Выключаем: замолкает и снова запоминается.
	voice_btn.button_pressed = false
	check(not bool(n.get("_playing")), "%s: выключённая озвучка замолкает" % mode_id)
	check(not settings.briefing_voice_enabled, "%s: выключение тоже сохранено" % mode_id)

	await unmount(n)
	# Тест не должен менять настройки игрока.
	settings.set_briefing_voice_enabled(was_enabled)

# --- Абай айтады -------------------------------------------------------------

func _test_abai() -> void:
	var n := await mount("res://scenes/ui/abai_says.tscn")
	if n == null:
		return
	_check_backdrop(n, SanlaqSceneBackdrop.Variant.ABAI, "абай")
	check((n.get_node("%SetupPanel") as Control).visible, "абай: экран выбора числа игроков виден")
	check(_connected(n, "%BackBtn"), "абай: кнопка «Артқа» подключена")

	(n.get_node("%P2Btn") as Button).pressed.emit()
	await process_frame
	var words: Array = n.get("_words")
	check(words.size() == 6, "абай: набрано 6 карточек, получено %d" % words.size())
	check((n.get_node("%CardGrid") as GridContainer).get_child_count() == 6, "абай: 6 карточек в сетке")

	# Показ тізбек: стартовая пауза 0.6 + 2 элемента по (SHOW_ON + SHOW_GAP).
	await create_timer(2.6).timeout
	var seq: Array = n.get("_sequence")
	check(seq.size() == 2, "абай: длина тізбек в 1-м раунде = 2, получено %d" % seq.size())
	check((n.get_node("%HandoffPanel") as Control).visible, "абай: после показа — экран передачи устройства")

	# Первый по очереди повторяет верно.
	(n.get_node("%ReadyBtn") as Button).pressed.emit()
	await process_frame
	for step in seq:
		n.call("_on_card_pressed", step)
		await process_frame
	await create_timer(1.2).timeout
	check((n.get_node("%HandoffPanel") as Control).visible, "абай: ход перешёл ко второму игроку")

	# Второй ошибается на первом же элементе — остаётся один выживший, партия кончается.
	(n.get_node("%ReadyBtn") as Button).pressed.emit()
	await process_frame
	n.call("_on_card_pressed", (int(seq[0]) + 1) % words.size())
	await create_timer(1.2).timeout
	check((n.get_node("%EndPanel") as Control).visible, "абай: экран итогов показан после вылета второго")
	var winner: String = (n.get_node("%WinnerLabel") as Label).text
	check(winner != "" and winner != "—", "абай: победитель подписан («%s»)" % winner)

	(n.get_node("%AgainBtn") as Button).pressed.emit()
	await process_frame
	check((n.get_node("%SetupPanel") as Control).visible, "абай: «ещё раз» вернул к выбору числа игроков")
	await unmount(n)

# --- Тоғыз құмалақ -----------------------------------------------------------

func _test_togyz() -> void:
	var n := await mount("res://scenes/ui/togyz_qumalaq.tscn")
	if n == null:
		return
	check(n.get_node_or_null("Background") is PixelBackdrop, "тоғыз: пиксельный фон на месте")
	check((n.get_node("%SetupPanel") as Control).visible, "тоғыз: экран выбора соперника виден")
	check((n.get_node("%Header") as ScreenHeader).back_pressed.get_connections().size() > 0,
		"тоғыз: «Артқа» подключена")
	check(_connected(n, "%VsHumanBtn"), "тоғыз: кнопка игры вдвоём подключена")

	(n.get_node("%VsBotBtn") as Button).pressed.emit()
	await process_frame
	check((n.get_node("%BoardPanel") as Control).visible, "тоғыз: доска показана")
	check((n.get_node("%BottomRow") as HBoxContainer).get_child_count() == GameBoard.PER_SIDE,
		"тоғыз: 9 отау в нижнем ряду")
	check((n.get_node("%TopRow") as HBoxContainer).get_child_count() == GameBoard.PER_SIDE,
		"тоғыз: 9 отау в верхнем ряду")
	check((n.get_node("%RightOwner") as Label).text != "", "тоғыз: казан подписан именем владельца")

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
	check(board2 != null, "тоғыз: доска жива после серии ходов")
	if board2 != null:
		check(human_moves > 0, "тоғыз: ходы человека проходят через клик по отау")
		check(board2.total_balls() == GameBoard.TOTAL_BALLS,
			"тоғыз: на доске и в казанах 162 құмалақ, получено %d" % board2.total_balls())
		check(board2.kazan[0] + board2.kazan[1] > 0, "тоғыз: казаны наполняются по ходу партии")
		print("[test] .. счёт после прогона: %d : %d" % [board2.kazan[0], board2.kazan[1]])
	check((n.get_node("%TurnLabel") as Label).text != "", "тоғыз: индикатор хода заполнен")
	var rings := (n.get_node("%BottomRow") as HBoxContainer).get_children().filter(
		func(pit: TogyzPit) -> bool: return pit.available)
	var board3: GameBoard = n.get("_board")
	if board3 != null and not board3.is_over() and board3.current_player == 0 and not bool(n.get("_animating")):
		check(rings.size() == board3.legal_moves().size(),
			"тоғыз: кольцом отмечены ровно доступные ходы, %d из %d" % [rings.size(), board3.legal_moves().size()])
	await unmount(n)
