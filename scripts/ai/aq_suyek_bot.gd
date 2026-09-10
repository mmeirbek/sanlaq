class_name AqSuyekBot
extends RefCounted
## Выбор хода компьютера в «Ақ сүйек». Отдельным классом — как просит
## спецификация, чтобы следующим этапом навесить уровни сложности, не трогая
## ни правила, ни экран.
##
## Компьютер не знает, где сүйек: он видит ровно то же, что и игрок, — открытые
## клетки с их подсказками. Логика по спецификации: держаться ближе всего к
## самой «горячей» из уже известных клеток и заходить в неизведанное.

## Как часто компьютер отвечает на вопрос верно. Не 100%, иначе ребёнку
## нечего ловить: соперник должен ошибаться так же, как он сам.
const CORRECT_CHANCE := 0.65

func answers_correctly() -> bool:
	return randf() < CORRECT_CHANCE

## Куда шагнуть. Возвращает направление или Vector2i.ZERO, если ходить некуда.
func choose_step(board: AqSuyekBoard) -> Vector2i:
	var here: Vector2i = board.positions[board.current_player]
	var options: Array[Vector2i] = []
	for direction in AqSuyekBoard.DIRECTIONS:
		if board.can_step(direction):
			options.append(direction)
	if options.is_empty():
		return Vector2i.ZERO

	var target := _hottest_known(board)

	# Оцениваем каждый ход: сначала неизведанные клетки, среди них — те, что
	# ближе к самой горячей известной.
	var best_score := -INF
	var best: Array[Vector2i] = []
	for direction in options:
		var cell: Vector2i = here + direction
		var score := 0.0
		if not board.revealed.has(cell):
			score += 10.0
		else:
			# В уже открытую клетку идём только если больше некуда, и тем
			# охотнее, чем она горячее.
			score += 4.0 - float(board.revealed[cell])
		if target != Vector2i(-1, -1):
			score -= float(absi(cell.x - target.x) + absi(cell.y - target.y))
		if score > best_score:
			best_score = score
			best.clear()
			best.append(direction)
		elif is_equal_approx(score, best_score):
			best.append(direction)

	return best[randi() % best.size()]

## Самая «горячая» из открытых клеток. (-1, -1), если поле ещё нетронуто.
func _hottest_known(board: AqSuyekBoard) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_hint := 99
	for cell in board.revealed:
		var hint: int = board.revealed[cell]
		if hint < best_hint:
			best_hint = hint
			best = cell
	return best
