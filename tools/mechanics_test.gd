extends "res://tools/test_case.gd"
## Механика Соқыртеке: поимка, квиз, замедление, конец раунда, бот-ловец и щит
## бегуна. Каждый сценарий идёт на свежей сцене игры.
##
## MatchManager, Player и QuizHUD здесь без аннотаций типа — см. tools/test_case.gd.

const GAME_SCENE := "res://scenes/world/game.tscn"
## Пауза перед итогами в MatchManager._end_round плюс запас.
const ROUND_END_PAUSE := 3.5
## Раскладка для проверки курса бота — одна и та же при каждом прогоне.
const BOT_COURSE_SEED := 7


func _init() -> void:
	await process_frame
	await process_frame
	await _test_correct_answer_eliminates()
	await _test_wrong_answer_slows_and_blocks_catch()
	await _test_last_catch_ends_round_once()
	await _test_next_quiz_survives_previous_result()
	await _test_quiz_checks_answer_by_button()
	await _test_quiz_answer_keys()
	await _test_bot_seeker_keeps_its_course()
	await _test_shield_wears_off_fully()
	finish("MECHANICS")


func _test_correct_answer_eliminates() -> void:
	var game := await _start_round()
	var mm = game.match_mgr
	check(mm.players.size() == 6, "в игре 6 участников, получено %d" % mm.players.size())
	_make_seeker(mm, mm.human_player)
	var runner = _runners(mm)[0]

	mm.on_player_touches_sokyroteke(runner)
	check(mm.quiz_active, "поимка открывает квиз")
	mm.submit_quiz_answer(true)
	check(runner.eliminated, "верный ответ выбивает бегуна")
	check(mm.eliminated_count == 1, "выбит 1 бегун, получено %d" % mm.eliminated_count)
	check(mm.current_state == mm.MatchState.PLAYING, "раунд продолжается, пока бегуны остались")
	await _stop(game)


func _test_wrong_answer_slows_and_blocks_catch() -> void:
	var game := await _start_round()
	var mm = game.match_mgr
	_make_seeker(mm, mm.human_player)
	var runners := _runners(mm)

	mm.on_player_touches_sokyroteke(runners[0])
	mm.submit_quiz_answer(false)
	check(mm.human_player.is_slowed(), "неверный ответ замедляет ловца")
	check(not runners[0].eliminated, "неверный ответ не выбивает бегуна")
	check(runners[0].has_shield(), "бегун после неверного ответа под щитом")

	# Другой бегун без щита и без кулдауна: мешать поимке может только замедление.
	mm.catch_cooldown = 0.0
	mm.on_player_touches_sokyroteke(runners[1])
	check(not mm.quiz_active, "замедленный ловец не может поймать")
	await _stop(game)


## Последняя поимка заканчивает раунд победой ловца, и таймер, истёкший во время
## паузы перед итогами, не переписывает исход.
func _test_last_catch_ends_round_once() -> void:
	var game := await _start_round()
	var mm = game.match_mgr
	_make_seeker(mm, mm.human_player)
	var round_winners: Array[Roles.Winner] = []
	var match_results: Array[Dictionary] = []
	mm.round_ended.connect(func(winner: Roles.Winner) -> void: round_winners.append(winner))
	mm.match_ended.connect(func(results: Dictionary) -> void: match_results.append(results))

	var runners := _runners(mm)
	for runner in runners.slice(0, -1):
		runner.eliminate()
		mm.eliminated_count += 1
	mm.on_player_touches_sokyroteke(runners[-1])
	mm.submit_quiz_answer(true)
	check(mm.current_state == mm.MatchState.ROUND_END, "после последней поимки раунд окончен")

	mm.round_timer = 0.0
	await create_timer(ROUND_END_PAUSE).timeout
	check(round_winners == [Roles.Winner.SOKYROTEKE], "раунд закончился один раз победой ловца: %s" % [round_winners])
	check(match_results.size() == 1, "итог матча отправлен один раз, получено %d" % match_results.size())
	if match_results.size() == 1:
		check(match_results[0].get("winner") == Roles.Winner.SOKYROTEKE, "в итоге матча победил ловец")
	await _stop(game)


## Результат прошлого квиза прячется через RESULT_SHOW_TIME, а следующая
## поимка возможна раньше — её квиз не должен закрыться этим таймером.
func _test_next_quiz_survives_previous_result() -> void:
	var game := await _start_round()
	var mm = game.match_mgr
	var hud = game.quiz_hud
	var item = _runners(mm)[0].get_random_clothing_item_for_quiz()

	hud.show_quiz(item, 30.0)
	hud.answer_button(0).pressed.emit()
	await create_timer(1.0).timeout
	hud.show_quiz(item, 30.0)
	await create_timer(hud.RESULT_SHOW_TIME).timeout
	check(hud.is_open(), "квиз второй поимки остаётся на экране")
	await _stop(game)


## Верность ответа решает номер нажатой кнопки. Раньше сравнивался текст
## кнопки с названием вещи: неверный вариант с тем же текстом засчитывался.
func _test_quiz_checks_answer_by_button() -> void:
	var game := await _start_round()
	var hud = game.quiz_hud
	var item = _runners(game.match_mgr)[0].get_random_clothing_item_for_quiz().duplicate()
	var correct_name: String = item.get_name_for_lang(autoload("GameSettings").get_lang_code())
	# Данные с ошибкой: среди неверных вариантов — само верное название.
	var wrongs: Array[String] = [correct_name, "Жоқ нұсқа", "Тағы жоқ нұсқа"]
	item.wrong_answers_kz = wrongs
	item.wrong_answers_en = wrongs
	var answers: Array[bool] = []
	hud.answer_submitted.connect(func(correct: bool) -> void: answers.append(correct))

	# Варианты перемешиваются — смотрим несколько раздач.
	for _deal in 8:
		hud.show_quiz(item, 30.0)
		var labels: Array[String] = []
		for i in 3:
			labels.append(hud.answer_button(i).text.substr(3))
		check(labels.count(correct_name) == 1, "верное название на одной кнопке: %s" % [labels])
	var wrong_index: int = (hud.correct_index() + 1) % 3
	hud.answer_button(wrong_index).pressed.emit()
	check(answers == [false], "неверная кнопка — неверный ответ, получено %s" % [answers])

	hud.show_quiz(item, 30.0)
	answers.clear()
	hud.answer_button(hud.correct_index()).pressed.emit()
	check(answers == [true], "верная кнопка — верный ответ, получено %s" % [answers])
	await _stop(game)


## Ответ клавишей: 1–3 верхнего ряда по физическому месту (на казахской
## раскладке там буквы) и 1–3 цифрового блока.
func _test_quiz_answer_keys() -> void:
	var game := await _start_round()
	var hud = game.quiz_hud
	var item = _runners(game.match_mgr)[0].get_random_clothing_item_for_quiz()
	var answers: Array[bool] = []
	hud.answer_submitted.connect(func(correct: bool) -> void: answers.append(correct))

	# Клавиша верного ответа в верхнем ряду; символ на ней — не цифра.
	hud.show_quiz(item, 30.0)
	var top_row := InputEventKey.new()
	top_row.physical_keycode = [KEY_1, KEY_2, KEY_3][hud.correct_index()]
	top_row.keycode = KEY_UNKNOWN
	top_row.pressed = true
	root.push_input(top_row)
	check(answers == [true], "клавиша верного ответа в верхнем ряду, получено %s" % [answers])

	# Клавиша неверного ответа на цифровом блоке.
	hud.show_quiz(item, 30.0)
	answers.clear()
	var keypad := InputEventKey.new()
	keypad.keycode = [KEY_KP_1, KEY_KP_2, KEY_KP_3][(hud.correct_index() + 1) % 3]
	keypad.pressed = true
	root.push_input(keypad)
	check(answers == [false], "клавиша неверного ответа на цифровом блоке, получено %s" % [answers])
	await _stop(game)


## Без цели бот-ловец обходит карту, а не дёргается на месте: раньше он каждый
## кадр выбирал новую случайную точку. Скорость персонажа сглаживается, поэтому
## смотрим на ввод бота — по нему же разворачивается спрайт.
func _test_bot_seeker_keeps_its_course() -> void:
	# Раскладка карты и места игроков случайны: у камня бот честно огибает
	# препятствие и поворачивает. Проверяем один и тот же раунд.
	seed(BOT_COURSE_SEED)
	var game := await _start_round()
	var mm = game.match_mgr
	var seeker = _runners(mm).filter(func(p) -> bool: return p.is_bot)[0]
	_make_seeker(mm, seeker)
	# Бегуны под щитом боту неинтересны — остаётся только обход.
	for runner in _runners(mm):
		runner.apply_shield(60.0)

	var controller: PlayerController = seeker.get_node("PlayerController")
	var sharp_turns := 0
	var frames := 40
	var previous := Vector2.ZERO
	for _i in frames:
		await physics_frame
		var heading := controller.get_direction().normalized()
		if previous != Vector2.ZERO and heading != Vector2.ZERO and absf(previous.angle_to(heading)) > 0.5:
			sharp_turns += 1
		previous = heading
	check(sharp_turns <= frames / 10,
		"бот-ловец держит курс (резких поворотов %d из %d кадров)" % [sharp_turns, frames])
	await _stop(game)


func _test_shield_wears_off_fully() -> void:
	var game := await _start_round()
	var mm = game.match_mgr
	var runner = _runners(mm)[0]
	runner.apply_shield(0.2)
	await create_timer(0.5).timeout
	check(not runner.has_shield(), "щит закончился")
	check(is_equal_approx(runner.modulate.a, 1.0),
		"после щита бегун снова непрозрачный, альфа %.2f" % runner.modulate.a)
	await _stop(game)


func _start_round() -> Node:
	var game := await mount(GAME_SCENE)
	await process_frame
	return game


## Назначает ловца и сразу запускает раунд, минуя обратный отсчёт.
func _make_seeker(mm, seeker) -> void:
	mm.sokyroteke = seeker
	for player in mm.players:
		player.set_as_sokyroteke(player == seeker)
		player.set_frozen(false)
	mm.runners_total = mm.players.size() - 1
	mm.eliminated_count = 0
	mm.current_state = mm.MatchState.PLAYING


func _runners(mm) -> Array:
	var runners := []
	for player in mm.players:
		if player != mm.sokyroteke and not player.eliminated:
			runners.append(player)
	return runners


func _stop(game: Node) -> void:
	await unmount(game)
	# Конец матча уводит на экран результатов — убираем его, чтобы следующий
	# сценарий начинался с чистого дерева.
	if current_scene:
		current_scene.queue_free()
		await process_frame
