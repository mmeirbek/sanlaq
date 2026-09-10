extends SceneTree
## Автотест правил «Ақ сүйек». Запускается в CI:
##     godot --headless --path . --script tools/aq_suyek_rules_test.gd
## При провале выходит с кодом 1 и роняет сборку.

const SELF_PLAY_GAMES := 200
## Шаги даются только за ответы, поэтому партия обязана завершаться. Упереться
## в потолок можно лишь если ход перестал менять состояние — это баг.
const MOVE_LIMIT := 20000

var fails := 0

func _init() -> void:
	_test_initial_state()
	_test_bone_never_on_start()
	_test_hint_tiers()
	_test_no_move_without_answer()
	_test_answer_grants_steps()
	_test_steps_are_spent()
	_test_turn_passes_when_steps_run_out()
	_test_cannot_leave_the_grid()
	_test_finding_bone_wins_round()
	_test_match_ends_at_two_wins()
	_test_loser_starts_next_round()
	_test_round_end_snapshot()
	_test_bot_never_walks_off_grid()
	_test_random_self_play()

	print("[test] " + ("AQ SUYEK RULES OK" if fails == 0 else "AQ SUYEK RULES FAILED (%d)" % fails))
	quit(1 if fails > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[test] ok: ", msg)
	else:
		fails += 1
		print("[test] FAIL: ", msg)

## Доска с заранее известным местом сүйек — иначе проверять подсказки нечем.
func _board_with_bone(at: Vector2i) -> AqSuyekBoard:
	var b := AqSuyekBoard.new()
	b.bone = at
	return b

func _test_initial_state() -> void:
	var b := AqSuyekBoard.new()
	_check(b.positions.size() == 2, "оба игрока на поле")
	_check(b.positions[0] == Vector2i(0, AqSuyekBoard.GRID - 1), "игрок в своём көмбе")
	_check(b.positions[1] == Vector2i(AqSuyekBoard.GRID - 1, 0), "компьютер в своём көмбе")
	_check(b.scores == [0, 0], "счёт нулевой")
	_check(b.revealed.is_empty(), "поле нетронуто")
	_check(not b.is_over(), "партия не окончена на старте")
	_check(b.awaiting_answer(), "ход начинается с вопроса")

func _test_bone_never_on_start() -> void:
	var bad := 0
	for _i in 300:
		var b := AqSuyekBoard.new()
		if b.positions.has(b.bone):
			bad += 1
	_check(bad == 0, "сүйек никогда не прячется под игроком (нарушений: %d)" % bad)

func _test_hint_tiers() -> void:
	var b := _board_with_bone(Vector2i(2, 2))
	_check(b.hint_for(Vector2i(2, 2)) == AqSuyekBoard.Hint.FOUND, "0 клеток — нашёл")
	_check(b.hint_for(Vector2i(2, 3)) == AqSuyekBoard.Hint.VERY_CLOSE, "1 клетка — очень близко")
	_check(b.hint_for(Vector2i(2, 4)) == AqSuyekBoard.Hint.CLOSE, "2 клетки — близко")
	_check(b.hint_for(Vector2i(0, 1)) == AqSuyekBoard.Hint.NEAR, "3 клетки — недалеко")
	_check(b.hint_for(Vector2i(0, 4)) == AqSuyekBoard.Hint.NEAR, "4 клетки — недалеко")
	# От центра поля 5×5 дальше четырёх клеток не отойти, поэтому «далеко»
	# проверяем на сүйек в углу.
	var corner := _board_with_bone(Vector2i(0, 0))
	_check(corner.hint_for(Vector2i(4, 1)) == AqSuyekBoard.Hint.FAR, "5 клеток — далеко")
	_check(corner.hint_for(Vector2i(4, 4)) == AqSuyekBoard.Hint.FAR, "8 клеток — далеко")

func _test_no_move_without_answer() -> void:
	var b := AqSuyekBoard.new()
	var before: Vector2i = b.positions[0]
	_check(not b.can_step(Vector2i.UP), "без ответа ходить нельзя")
	var res: Dictionary = b.step(Vector2i.UP)
	_check(b.positions[0] == before, "и позиция не изменилась")
	_check(not res["found"], "разбор хода пустой")

func _test_answer_grants_steps() -> void:
	var b := AqSuyekBoard.new()
	_check(b.answer(true) == AqSuyekBoard.STEPS_CORRECT, "верный ответ даёт больше шагов")
	_check(not b.awaiting_answer(), "вопрос больше не нужен")
	_check(b.answer(true) == 0, "второй ответ подряд шагов не добавляет")

	var b2 := AqSuyekBoard.new()
	_check(b2.answer(false) == AqSuyekBoard.STEPS_WRONG, "неверный ответ тоже даёт ход, но короче")

func _test_steps_are_spent() -> void:
	var b := _board_with_bone(Vector2i(4, 4))
	b.answer(true)
	var res: Dictionary = b.step(Vector2i.UP)
	_check(int(res["steps_left"]) == AqSuyekBoard.STEPS_CORRECT - 1, "шаг списался")
	_check(b.revealed.has(res["to"]), "клетка открылась и запомнила подсказку")

func _test_turn_passes_when_steps_run_out() -> void:
	var b := _board_with_bone(Vector2i(4, 4))
	b.answer(false)  # ровно один шаг
	b.step(Vector2i.UP)
	_check(b.current_player == AqSuyekBoard.BOT, "шаги кончились — очередь соперника")
	_check(b.awaiting_answer(), "сопернику тоже нужен вопрос")

func _test_cannot_leave_the_grid() -> void:
	var b := _board_with_bone(Vector2i(2, 2))
	b.answer(true)
	# Игрок стоит в левом нижнем углу: влево и вниз — за поле.
	_check(not b.can_step(Vector2i.LEFT), "за левый край поля не выйти")
	_check(not b.can_step(Vector2i.DOWN), "за нижний край поля не выйти")
	_check(b.can_step(Vector2i.UP) and b.can_step(Vector2i.RIGHT), "внутрь поля ходить можно")

func _test_finding_bone_wins_round() -> void:
	# Прячем сүйек прямо над игроком, чтобы он дошёл за один шаг.
	var b := AqSuyekBoard.new()
	b.bone = b.positions[0] + Vector2i.UP
	b.answer(true)
	var res: Dictionary = b.step(Vector2i.UP)
	_check(res["found"], "дошёл до сүйек")
	_check(res["round_over"], "раунд закрылся")
	_check(b.scores[AqSuyekBoard.HUMAN] == 1, "очко ушло нашедшему")
	_check(not b.is_over(), "партия продолжается — нужна вторая победа")

func _test_match_ends_at_two_wins() -> void:
	var b := AqSuyekBoard.new()
	var res := {}
	for _round in 2:
		b.current_player = AqSuyekBoard.HUMAN
		b.bone = b.positions[AqSuyekBoard.HUMAN] + Vector2i.UP
		b.steps[AqSuyekBoard.HUMAN] = 0
		b.answer(true)
		res = b.step(Vector2i.UP)
	_check(b.scores[AqSuyekBoard.HUMAN] == AqSuyekBoard.WINS_NEEDED, "две победы набраны")
	_check(b.is_over(), "партия завершилась на второй победе")
	_check(b.winner() == AqSuyekBoard.HUMAN, "победитель определён верно")
	_check(bool(res["finished"]), "разбор хода сообщил о конце партии")

func _test_loser_starts_next_round() -> void:
	var b := AqSuyekBoard.new()
	b.bone = b.positions[AqSuyekBoard.HUMAN] + Vector2i.UP
	b.answer(true)
	b.step(Vector2i.UP)
	_check(b.current_player == AqSuyekBoard.BOT, "новый раунд начинает проигравший")
	_check(b.revealed.is_empty(), "поле в новом раунде чистое")

## Экран показывает итог раунда уже после того, как доска пересобралась под
## следующий, поэтому разбор хода обязан нести снимок доигранного поля. Без него
## экран рисовал бы новый, ещё не найденный сүйек — то есть выдавал бы ответ.
func _test_round_end_snapshot() -> void:
	var b := AqSuyekBoard.new()
	# Уводим сүйек в дальний угол: попадись он на первом же шаге, раунд закрылся
	# бы раньше времени и проверка мерила бы совсем другую ситуацию.
	b.bone = Vector2i(AqSuyekBoard.GRID - 1, AqSuyekBoard.GRID - 1)
	b.answer(true)
	b.step(Vector2i.UP)  # открываем клетку, чтобы снимку было что хранить
	b.current_player = AqSuyekBoard.HUMAN
	b.steps[AqSuyekBoard.HUMAN] = 1
	var was_at: Vector2i = b.positions[AqSuyekBoard.HUMAN]
	b.bone = was_at + Vector2i.UP
	var hidden_at: Vector2i = b.bone
	var res: Dictionary = b.step(Vector2i.UP)

	_check(res["bone"] == hidden_at, "разбор помнит, где сүйек лежал на самом деле")
	# Сравнивать с новым местом сүйек нельзя: оно случайное и раз в двадцать три
	# раза совпадёт со старым. Что доска уже пересобралась, видно по көмбе.
	_check(b.positions[AqSuyekBoard.HUMAN] == Vector2i(0, AqSuyekBoard.GRID - 1),
		"доска уже вернула обоих в көмбе под новый раунд")
	var snapshot: Array = res["final_positions"]
	_check(snapshot[AqSuyekBoard.HUMAN] == hidden_at, "снимок держит нашедшего на сүйек")
	_check(not res["final_revealed"].is_empty(), "снимок держит открытые клетки")
	_check(b.revealed.is_empty(), "а доска их уже стёрла — снимок не ссылка на неё")

func _test_bot_never_walks_off_grid() -> void:
	seed(20260910)
	var bot := AqSuyekBot.new()
	var bad := 0
	for _i in 400:
		var b := AqSuyekBoard.new()
		b.current_player = AqSuyekBoard.BOT
		b.answer(true)
		var direction := bot.choose_step(b)
		if direction == Vector2i.ZERO:
			continue
		if not b.can_step(direction):
			bad += 1
	_check(bad == 0, "компьютер не ходит за поле и без шагов (нарушений: %d)" % bad)

func _test_random_self_play() -> void:
	seed(20260910)
	var bot := AqSuyekBot.new()
	var unfinished := 0
	var stuck := 0

	for _g in SELF_PLAY_GAMES:
		var b := AqSuyekBoard.new()
		var moves := 0
		while not b.is_over() and moves < MOVE_LIMIT:
			if b.awaiting_answer():
				b.answer(bot.answers_correctly())
			var direction := bot.choose_step(b)
			if direction == Vector2i.ZERO:
				stuck += 1
				break
			b.step(direction)
			moves += 1
		if not b.is_over() and moves >= MOVE_LIMIT:
			unfinished += 1

	_check(stuck == 0, "нет позиций, из которых некуда шагнуть (%d)" % stuck)
	_check(unfinished == 0, "все %d партий завершились (не завершилось: %d)" % [SELF_PLAY_GAMES, unfinished])
