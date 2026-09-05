class_name TogyzBot
extends RefCounted
## Жадный выбор хода для тоғыз құмалақ по спецификации: без minimax, только
## перебор своих ходов на один шаг вперёд с симуляцией на копии доски.
##
## Приоритет: максимальное взятие → взять тұздық → защита (меньше всего дать
## сопернику в ответ) → случайный ход.

static func choose_move(board: GameBoard) -> int:
	var moves := board.legal_moves()
	if moves.is_empty():
		return -1

	var me := board.current_player
	var best_capture := 0
	var capture_moves: Array[int] = []
	var tuzdyk_moves: Array[int] = []
	## Для защиты: сколько соперник сможет взять лучшим ответом на наш ход.
	var risk := {}

	for move in moves:
		var sim := board.clone()
		var res: Dictionary = sim.apply_move(move)

		if not res["capture"].is_empty():
			var amount: int = res["capture"]["amount"]
			if amount > best_capture:
				best_capture = amount
				capture_moves.clear()
				capture_moves.append(move)
			elif amount == best_capture:
				capture_moves.append(move)

		if not res["tuzdyk"].is_empty():
			tuzdyk_moves.append(move)

		risk[move] = _best_reply_gain(sim, board.opponent_of(me))

	if not capture_moves.is_empty():
		return _pick_random(capture_moves)
	if not tuzdyk_moves.is_empty():
		return _pick_random(tuzdyk_moves)

	# Защита: оставляем ходы, после которых соперник забирает меньше всего.
	var lowest := -1
	var safest: Array[int] = []
	for move in moves:
		var value: int = risk.get(move, 0)
		if lowest < 0 or value < lowest:
			lowest = value
			safest.clear()
			safest.append(move)
		elif value == lowest:
			safest.append(move)
	if not safest.is_empty():
		return _pick_random(safest)
	return _pick_random(moves)

## Сколько соперник заберёт своим лучшим ответом из данной позиции.
static func _best_reply_gain(board: GameBoard, rival: int) -> int:
	if board.is_over() or board.current_player != rival:
		return 0
	var best := 0
	for reply in board.legal_moves():
		var sim := board.clone()
		var res: Dictionary = sim.apply_move(reply)
		var gain := 0
		if not res["capture"].is_empty():
			gain += int(res["capture"]["amount"])
		if not res["tuzdyk"].is_empty():
			# Тұздық дороже разового взятия: он доит наши шары всю оставшуюся партию.
			gain += 12
		if gain > best:
			best = gain
	return best

static func _pick_random(options: Array[int]) -> int:
	return options[randi() % options.size()]
