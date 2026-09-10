class_name AqSuyekBoard
extends RefCounted
## Движок правил «Ақ сүйек». Про экран не знает ничего: step() возвращает разбор
## хода, по которому UI уже строит анимацию. Тот же приём, что и в GameBoard у
## тоғыз, — благодаря ему правила проверяются headless, без единой сцены.
##
## Поле — торкөз GRID×GRID. Сүйек спрятан в одной клетке. Игрок и компьютер
## стоят в противоположных углах, в своих көмбе.
##
## Двигаться просто так нельзя: шаги зарабатываются ответом на вопрос о
## традициях. Верный ответ даёт больше шагов, поэтому знание прямо переводится
## в продвижение по полю. Кончились шаги — очередь переходит к сопернику.

## Баланс собран здесь, чтобы менялся одной строкой.
const GRID := 5
## Партия до двух побед из трёх раундов.
const ROUNDS := 3
const WINS_NEEDED := 2
const STEPS_CORRECT := 3
const STEPS_WRONG := 1

const HUMAN := 0
const BOT := 1

## Насколько холодно. Точное число не показываем: игрок должен догадываться, а
## не вычислять — иначе теряется сам смысл поиска.
enum Hint { FOUND, VERY_CLOSE, CLOSE, NEAR, FAR }

const DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Где спрятан сүйек. Игроку не показывается до конца раунда.
var bone: Vector2i
## Где сейчас стоит каждый из двоих.
var positions: Array[Vector2i] = []
## Сколько шагов осталось у каждого. Ноль — пора отвечать на вопрос.
var steps: Array[int] = [0, 0]
## Клетка -> подсказка, которую про неё уже узнали. Общая на двоих: поле одно.
var revealed: Dictionary = {}
var scores: Array[int] = [0, 0]
var round_index: int = 0
var current_player: int = HUMAN
var finished: bool = false
## -1 — партия ещё идёт.
var winner_player: int = -1

func _init() -> void:
	reset()

func reset() -> void:
	scores = [0, 0]
	round_index = 0
	finished = false
	winner_player = -1
	start_round()

## Новый раунд: сүйек прячется заново, оба возвращаются в свои көмбе.
func start_round() -> void:
	positions = [Vector2i(0, GRID - 1), Vector2i(GRID - 1, 0)]
	steps = [0, 0]
	revealed = {}
	current_player = HUMAN
	bone = _hide_bone()

## Прячем не в стартовых клетках: иначе раунд кончался бы, не начавшись.
func _hide_bone() -> Vector2i:
	var free: Array[Vector2i] = []
	for x in GRID:
		for y in GRID:
			var cell := Vector2i(x, y)
			if not positions.has(cell):
				free.append(cell)
	return free[randi() % free.size()]

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID and cell.y < GRID

func opponent_of(player: int) -> int:
	return 1 - player

func is_over() -> bool:
	return finished

func winner() -> int:
	return winner_player

## Шагов не осталось — значит, ход начинается с вопроса.
func awaiting_answer() -> bool:
	return not finished and steps[current_player] == 0

func hint_for(cell: Vector2i) -> Hint:
	var distance := absi(cell.x - bone.x) + absi(cell.y - bone.y)
	if distance == 0:
		return Hint.FOUND
	if distance == 1:
		return Hint.VERY_CLOSE
	if distance == 2:
		return Hint.CLOSE
	if distance <= 4:
		return Hint.NEAR
	return Hint.FAR

## Ответ на вопрос. Возвращает, сколько шагов начислено.
func answer(correct: bool) -> int:
	if finished or steps[current_player] > 0:
		return 0
	var gained := STEPS_CORRECT if correct else STEPS_WRONG
	steps[current_player] = gained
	return gained

func can_step(direction: Vector2i) -> bool:
	if finished or steps[current_player] <= 0:
		return false
	if not DIRECTIONS.has(direction):
		return false
	return in_bounds(positions[current_player] + direction)

## Шаг в соседнюю клетку. Возвращает разбор хода:
##   player     — кто шёл
##   to         — куда встал
##   hint       — что узнал про эту клетку
##   found      — нашёл ли сүйек
##   steps_left — сколько шагов осталось до конца хода
##   round_over — закончился ли раунд, и bone — где сүйек на самом деле лежал
##   final_positions / final_revealed — снимок поля на момент конца раунда:
##                  сразу после него поле уже пересобрано под следующий
##   finished / winner — состояние партии после хода
func step(direction: Vector2i) -> Dictionary:
	var result := {
		"player": current_player,
		"to": positions[current_player],
		"hint": Hint.FAR,
		"found": false,
		"steps_left": 0,
		"round_over": false,
		"bone": bone,
		"finished": false,
		"winner": -1,
	}
	if not can_step(direction):
		return result

	var mover := current_player
	var landed: Vector2i = positions[mover] + direction
	positions[mover] = landed
	steps[mover] -= 1

	var hint := hint_for(landed)
	revealed[landed] = hint
	result["to"] = landed
	result["hint"] = hint
	result["steps_left"] = steps[mover]

	if hint == Hint.FOUND:
		result["found"] = true
		_finish_round(mover, result)
		return result

	# Шаги кончились — очередь соперника.
	if steps[mover] == 0:
		current_player = opponent_of(mover)
	return result

func _finish_round(winner_of_round: int, result: Dictionary) -> void:
	scores[winner_of_round] += 1
	result["round_over"] = true
	result["bone"] = bone
	# Снимок доигранного раунда: ниже поле сбрасывается под следующий, а экрану
	# ещё нужно показать, где сүйек лежал и кто где стоял. Без снимка он
	# показал бы уже новый, ещё не найденный сүйек — то есть выдал бы ответ.
	result["final_positions"] = positions.duplicate()
	result["final_revealed"] = revealed.duplicate()
	round_index += 1

	if scores[winner_of_round] >= WINS_NEEDED or round_index >= ROUNDS:
		finished = true
		if scores[HUMAN] > scores[BOT]:
			winner_player = HUMAN
		elif scores[BOT] > scores[HUMAN]:
			winner_player = BOT
		else:
			winner_player = -1
		result["finished"] = true
		result["winner"] = winner_player
		return

	start_round()
	# Раунд начинает проигравший — так отставший получает ход первым.
	current_player = opponent_of(winner_of_round)
