extends SceneTree
## Автотест правил тоғыз құмалақ. Запускается в CI:
##     godot --headless --path . --script tools/togyz_rules_test.gd
## При провале выходит с кодом 1 и роняет сборку — в отличие от остальных
## tools/*_test.gd, которые всегда выходят нулём.

const SELF_PLAY_GAMES := 300
## Шары уходят с доски только в казаны, поэтому партия обязана завершаться.
## Упереться в потолок можно лишь если ход перестал менять состояние — это баг.
const MOVE_LIMIT := 20000

var fails := 0

func _init() -> void:
	_test_initial_state()
	_test_basic_sow()
	_test_single_ball_moves_on()
	_test_capture_even_on_rival_side()
	_test_no_capture_on_own_side()
	_test_tuzdyk_on_exactly_three()
	_test_no_tuzdyk_on_ninth_pit()
	_test_only_one_tuzdyk_per_player()
	_test_tuzdyk_mirror_rule()
	_test_ball_into_tuzdyk_goes_to_owner()
	_test_atsyrau_sweeps_the_rest()
	_test_win_at_82()
	_test_win_at_82_for_the_other_player()
	_test_random_self_play()

	print("[test] " + ("TOGYZ RULES OK" if fails == 0 else "TOGYZ RULES FAILED (%d)" % fails))
	quit(1 if fails > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[test] ok: ", msg)
	else:
		fails += 1
		print("[test] FAIL: ", msg)

func _zeros() -> Array:
	var a := []
	for i in GameBoard.PIT_COUNT:
		a.append(0)
	return a

## Собирает доску с нужной раскладкой: {индекс лунки: сколько шаров}.
func _board(layout: Dictionary, kazan0: int = 0, kazan1: int = 0, current: int = 0) -> GameBoard:
	var b := GameBoard.new()
	var cells := _zeros()
	for i in layout:
		cells[i] = layout[i]
	for i in GameBoard.PIT_COUNT:
		b.pits[i] = cells[i]
	b.kazan[0] = kazan0
	b.kazan[1] = kazan1
	b.current_player = current
	return b

func _test_initial_state() -> void:
	var b := GameBoard.new()
	var all_nine := true
	for v in b.pits:
		if v != GameBoard.START_BALLS:
			all_nine = false
	_check(b.pits.size() == 18, "18 лунок")
	_check(all_nine, "в каждой лунке по 9 шаров")
	_check(b.total_balls() == 162, "всего 162 шара, получено %d" % b.total_balls())
	_check(b.kazan[0] == 0 and b.kazan[1] == 0, "казаны пусты")
	_check(not b.is_over(), "партия не окончена на старте")

func _test_basic_sow() -> void:
	var b := GameBoard.new()
	b.apply_move(0)
	_check(b.pits[0] == 1, "в исходной лунке остался 1 шар, получено %d" % b.pits[0])
	var sown_ok := true
	for i in range(1, 9):
		if b.pits[i] != 10:
			sown_ok = false
	_check(sown_ok, "8 шаров разложены по своим лункам 2..9")
	_check(b.pits[9] == 9, "сторона соперника не тронута")
	_check(b.kazan[0] == 0, "своя сторона взятия не даёт")
	_check(b.total_balls() == 162, "шары сохранились после хода")

func _test_single_ball_moves_on() -> void:
	var b = _board({0: 1, 1: 9, 10: 4})
	b.apply_move(0)
	_check(b.pits[0] == 0, "лунка с одним шаром опустела, получено %d" % b.pits[0])
	_check(b.pits[1] == 10, "шар переехал в следующую лунку, там %d" % b.pits[1])

func _test_capture_even_on_rival_side() -> void:
	var b = _board({8: 2, 9: 1, 10: 5})
	b.apply_move(8)
	_check(b.kazan[0] == 2, "взяли чётную лунку соперника, в казане %d" % b.kazan[0])
	_check(b.pits[9] == 0, "взятая лунка опустела, там %d" % b.pits[9])
	_check(b.pits[8] == 1, "в исходной лунке остался 1 шар")

func _test_no_capture_on_own_side() -> void:
	var b = _board({0: 2, 1: 1, 10: 3})
	b.apply_move(0)
	_check(b.kazan[0] == 0, "на своей стороне взятия нет, в казане %d" % b.kazan[0])
	_check(b.pits[1] == 2, "чётная своя лунка осталась на месте, там %d" % b.pits[1])

func _test_tuzdyk_on_exactly_three() -> void:
	# Из лунки 8 с двумя шарами последний ложится в лунку 9 — первую у соперника.
	var b = _board({8: 2, 9: 2, 10: 4})
	b.apply_move(8)
	_check(b.tuzdyk_owner[9] == 0, "тұздық взят при ровно 3 шарах")
	_check(b.kazan[0] == 3, "три шара ушли в казан, там %d" % b.kazan[0])
	_check(b.pits[9] == 0, "лунка тұздық опустела")

func _test_no_tuzdyk_on_ninth_pit() -> void:
	# Из лунки 8 с 10 шарами последний ложится ровно в индекс 17 — это 9-я лунка соперника.
	var b = _board({8: 10, 17: 2})
	b.apply_move(8)
	_check(b.tuzdyk_owner[17] == -1, "на 9-й лунке (маңдай) тұздық не берётся")
	_check(b.pits[17] == 3, "шары остались в лунке, там %d" % b.pits[17])
	_check(b.kazan[0] == 0, "и взятия тоже нет — 3 нечётное")

func _test_only_one_tuzdyk_per_player() -> void:
	var b = _board({8: 2, 9: 2, 11: 4})
	b.tuzdyk_owner[10] = 0
	b.apply_move(8)
	_check(b.tuzdyk_owner[9] == -1, "второй тұздық одному игроку не даётся")
	_check(b.kazan[0] == 0, "и шары в казан не уходят, там %d" % b.kazan[0])

func _test_tuzdyk_mirror_rule() -> void:
	# У соперника тұздық в лунке с номером 3 (индекс 2). Игрок 0 пытается взять
	# тұздық в лунке соперника с тем же номером 3 (индекс 11) — зеркальность запрещает.
	var b = _board({0: 12, 11: 2})
	b.tuzdyk_owner[2] = 1
	b.apply_move(0)
	_check(b.tuzdyk_owner[11] == -1, "зеркальный тұздық запрещён")
	_check(b.pits[11] == 3, "лунка осталась с 3 шарами, там %d" % b.pits[11])
	_check(b.kazan[1] == 1, "шар, упавший в чужой тұздық, ушёл его владельцу")

func _test_ball_into_tuzdyk_goes_to_owner() -> void:
	var b = _board({3: 4, 12: 3})
	b.tuzdyk_owner[5] = 1
	b.apply_move(3)
	_check(b.kazan[1] == 1, "шар из тұздық ушёл владельцу, у него %d" % b.kazan[1])
	_check(b.pits[5] == 0, "в лунке тұздық шары не копятся, там %d" % b.pits[5])
	_check(b.pits[4] == 1 and b.pits[6] == 1, "соседние лунки получили по шару")

func _test_atsyrau_sweeps_the_rest() -> void:
	var b = _board({0: 2, 1: 5})
	var res: Dictionary = b.apply_move(0)
	_check(not res["atsyrau"].is_empty(), "атсырау зафиксирован в разборе хода")
	_check(b.is_over(), "партия завершилась по атсырау")
	_check(b.kazan[0] == 7, "соперник забрал остаток доски, в казане %d" % b.kazan[0])
	_check(b.winner() == 0, "победил тот, кому достался остаток")
	var board_empty := true
	for v in b.pits:
		if v != 0:
			board_empty = false
	_check(board_empty, "доска пуста после сбора остатка")

func _test_win_at_82() -> void:
	var b = _board({8: 2, 9: 1, 10: 5}, 80, 0)
	b.apply_move(8)
	_check(b.kazan[0] == 82, "набрано 82, в казане %d" % b.kazan[0])
	_check(b.is_over(), "партия завершается при 82+")
	_check(b.winner() == 0, "победитель определён верно")

## Соперник может добрать до 82 не своим ходом: шар, упавший в его тұздық во время
## чужой раздачи, уходит ему в казан. Партия обязана остановиться сразу же.
func _test_win_at_82_for_the_other_player() -> void:
	var b = _board({0: 3, 5: 1, 9: 5}, 0, 81)
	b.tuzdyk_owner[2] = 1
	b.apply_move(0)
	_check(b.kazan[1] == 82, "соперник добрал 82 через свой тұздық, у него %d" % b.kazan[1])
	_check(b.is_over(), "партия остановилась, хотя 82 набрал не ходивший")
	_check(b.winner() == 1, "победителем признан набравший 82, получено %d" % b.winner())

func _test_random_self_play() -> void:
	seed(20260905)
	var invariant_broken := 0
	var stuck := 0
	var unfinished := 0
	var balls_grew := 0

	for _g in SELF_PLAY_GAMES:
		var b := GameBoard.new()
		var on_board := 162
		var moves_made := 0
		while not b.is_over() and moves_made < MOVE_LIMIT:
			var moves: Array = b.legal_moves()
			if moves.is_empty():
				stuck += 1
				break
			b.apply_move(moves[randi() % moves.size()])
			moves_made += 1
			if b.total_balls() != 162:
				invariant_broken += 1
				break
			var now_on_board := b.total_balls() - b.kazan[0] - b.kazan[1]
			if now_on_board > on_board:
				balls_grew += 1
				break
			on_board = now_on_board
		if not b.is_over() and moves_made >= MOVE_LIMIT:
			unfinished += 1

	_check(invariant_broken == 0, "сумма лунок и казанов всегда 162 (нарушений: %d)" % invariant_broken)
	_check(stuck == 0, "нет зависших позиций без ходов при незавершённой партии (%d)" % stuck)
	_check(balls_grew == 0, "шары на доске не появляются из ниоткуда (%d)" % balls_grew)
	_check(unfinished == 0, "все %d случайных партий завершились (не завершилось: %d)" % [SELF_PLAY_GAMES, unfinished])
