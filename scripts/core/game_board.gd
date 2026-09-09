class_name GameBoard
extends RefCounted
## Движок правил тоғыз құмалақ. Про экран не знает ничего: apply_move() возвращает
## разбор хода, по которому UI уже строит анимацию. Один и тот же движок используют
## и игра вдвоём на одном устройстве, и игра против компьютера — меняется только
## слой, который решает, чей сейчас ход.
##
## Индексация: 0-8 — лунки игрока 0, 9-17 — лунки игрока 1. Раздача идёт против
## часовой стрелки, то есть просто по возрастанию индекса с переходом через 17 → 0.

const PER_SIDE := 9
const PIT_COUNT := 18
const START_BALLS := 9
const TOTAL_BALLS := PIT_COUNT * START_BALLS  # 162
## Больше половины всех шаров — этого достаточно для победы.
const WIN_SCORE := 82

var pits: Array[int] = []
var kazan: Array[int] = [0, 0]
## -1 — обычная лунка, иначе номер игрока, которому принадлежит тұздық.
var tuzdyk_owner: Array[int] = []
var current_player: int = 0
var finished: bool = false
## -1 — ничья либо партия ещё идёт.
var winner_player: int = -1

func _init() -> void:
	reset()

func reset() -> void:
	pits.clear()
	tuzdyk_owner.clear()
	for i in PIT_COUNT:
		pits.append(START_BALLS)
		tuzdyk_owner.append(-1)
	kazan[0] = 0
	kazan[1] = 0
	current_player = 0
	finished = false
	winner_player = -1

func side_of(index: int) -> int:
	return index / PER_SIDE

## Номер лунки на своей стороне, 1..9. Девятая — маңдай, тұздық ею быть не может.
func local_number(index: int) -> int:
	return index % PER_SIDE + 1

func opponent_of(player: int) -> int:
	return 1 - player

func has_tuzdyk(player: int) -> bool:
	return tuzdyk_owner.has(player)

func is_over() -> bool:
	return finished

func winner() -> int:
	return winner_player

## Инвариант для тестов: шары не должны появляться и исчезать.
func total_balls() -> int:
	var sum := kazan[0] + kazan[1]
	for v in pits:
		sum += v
	return sum

func is_legal_move(index: int) -> bool:
	if finished:
		return false
	if index < 0 or index >= PIT_COUNT:
		return false
	if side_of(index) != current_player:
		return false
	return pits[index] > 0

func legal_moves(player: int = -1) -> Array[int]:
	var who := current_player if player < 0 else player
	var out: Array[int] = []
	for i in range(who * PER_SIDE, who * PER_SIDE + PER_SIDE):
		if pits[i] > 0:
			out.append(i)
	return out

func clone() -> GameBoard:
	var copy := GameBoard.new()
	copy.pits = pits.duplicate()
	copy.kazan = kazan.duplicate()
	copy.tuzdyk_owner = tuzdyk_owner.duplicate()
	copy.current_player = current_player
	copy.finished = finished
	copy.winner_player = winner_player
	return copy

## Делает ход и возвращает его разбор:
##   from     — из какой лунки взяли
##   player   — кто ходил
##   steps    — куда лёг каждый шар по порядку; to_kazan = -1, если остался в лунке,
##              иначе номер игрока, в чей казан он ушёл (шар, упавший в тұздық)
##   capture  — {index, amount}, если взяли чётную лунку соперника
##   tuzdyk   — {index, owner}, если этим ходом взяли тұздық
##   atsyrau  — {player, amount}, если следующему игроку нечем ходить
##   finished / winner — состояние партии после хода
func apply_move(index: int) -> Dictionary:
	var result := {
		"from": index,
		"player": current_player,
		"steps": [],
		"capture": {},
		"tuzdyk": {},
		"atsyrau": {},
		"finished": false,
		"winner": -1,
	}
	if not is_legal_move(index):
		return result

	var mover := current_player
	var count := 0
	if pits[index] == 1:
		# Лунка с единственным шаром: он перекладывается в следующую лунку.
		pits[index] = 0
		count = 1
	else:
		count = pits[index] - 1
		pits[index] = 1

	var idx := index
	for _k in count:
		idx = (idx + 1) % PIT_COUNT
		var owner: int = tuzdyk_owner[idx]
		if owner != -1:
			# Тұздық шары не копит — упавший сразу уходит в казан владельца.
			kazan[owner] += 1
			result["steps"].append({"index": idx, "to_kazan": owner})
		else:
			pits[idx] += 1
			result["steps"].append({"index": idx, "to_kazan": -1})

	var last := idx
	# Взятие и тұздық считаются только если последний шар лёг в обычную лунку
	# на стороне соперника. Три — нечётное, поэтому с чётным взятием не спорит.
	if tuzdyk_owner[last] == -1 and side_of(last) != mover:
		if pits[last] == 3 and _can_take_tuzdyk(last, mover):
			tuzdyk_owner[last] = mover
			kazan[mover] += pits[last]
			pits[last] = 0
			result["tuzdyk"] = {"index": last, "owner": mover}
		elif pits[last] % 2 == 0:
			result["capture"] = {"index": last, "amount": pits[last]}
			kazan[mover] += pits[last]
			pits[last] = 0

	_finish_turn(mover, result)
	return result

func _can_take_tuzdyk(index: int, mover: int) -> bool:
	if side_of(index) == mover:
		return false
	if local_number(index) == PER_SIDE:
		return false
	if has_tuzdyk(mover):
		return false
	# Правило зеркальности: нельзя брать лунку с тем же номером, что тұздық соперника.
	var rival := opponent_of(mover)
	for i in PIT_COUNT:
		if tuzdyk_owner[i] == rival and local_number(i) == local_number(index):
			return false
	return true

func _finish_turn(mover: int, result: Dictionary) -> void:
	# Проверяем оба казана, а не только казан ходившего: соперник может добрать
	# до 82 на чужом ходу, если раздача прошла через его тұздық.
	if kazan[mover] >= WIN_SCORE or kazan[opponent_of(mover)] >= WIN_SCORE:
		_end_game(result)
		return

	current_player = opponent_of(mover)
	if legal_moves(current_player).is_empty():
		# Атсырау: ходить нечем — соперник забирает все оставшиеся на доске шары.
		var sweeper := opponent_of(current_player)
		var swept := 0
		for i in PIT_COUNT:
			swept += pits[i]
			pits[i] = 0
		kazan[sweeper] += swept
		result["atsyrau"] = {"player": current_player, "amount": swept}
		_end_game(result)

func _end_game(result: Dictionary) -> void:
	finished = true
	if kazan[0] > kazan[1]:
		winner_player = 0
	elif kazan[1] > kazan[0]:
		winner_player = 1
	else:
		winner_player = -1
	result["finished"] = true
	result["winner"] = winner_player
