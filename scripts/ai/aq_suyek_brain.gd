class_name AqSuyekBrain
extends RefCounted
## Куда бежать боту в «Ақ сүйек». Решение — точка на карте; дойти до неё и
## обойти камни — дело сцены. Отдельным классом без узлов, как AqSuyekMatch:
## поведение ботов проверяется тем же headless-тестом, что и правила.
##
## Бот не знает, где сүйек, пока его не увидел кто-то из команды (или пока
## команда верно не ответила на вопрос перед раундом). Несущего видят все: над
## ним белеет сүйек.

## Как далеко ночью виден ақ сүйек — столько же, сколько свет вокруг игрока.
const SIGHT := 150.0
## Как часто команда ботов верно отвечает на вопрос перед раундом.
const CORRECT_CHANCE := 0.65
## Насколько впереди несущего целиться, когда его догоняешь.
const LEAD := 60.0
## На каком расстоянии свой іздеуші прикрывает несущего.
const ESCORT_GAP := 50.0

static func answers_correctly() -> bool:
	return randf() < CORRECT_CHANCE

## Видит ли кто-то из команды сүйек прямо сейчас.
static func sees(team: int, m: AqSuyekMatch, positions: Array[Vector2]) -> bool:
	for id in m.teams.size():
		if m.teams[id] == team and positions[id].distance_to(m.bone) <= SIGHT:
			return true
	return false

## Точка, к которой бежит бот me. knows_bone — команда знает, где сүйек;
## roam — куда идти искать, если не знает.
static func target(me: int, m: AqSuyekMatch, positions: Array[Vector2], knows_bone: bool, roam: Vector2) -> Vector2:
	var here := positions[me]
	if m.is_stunned(me):
		return here
	var team := m.teams[me]
	if m.carrier == me:
		return m.bases[team]

	if m.carrier >= 0:
		var carried := positions[m.carrier]
		if m.teams[m.carrier] == team:
			# Свой несёт: қорғаушы встречает ближайшего к нему соперника, іздеуші
			# прикрывает несущего со стороны погони.
			var threat := _nearest_enemy(carried, team, m, positions, false)
			if threat < 0:
				return carried
			if m.roles[me] == AqSuyekMatch.Role.DEFENDER:
				return positions[threat]
			return carried + (positions[threat] - carried).normalized() * ESCORT_GAP
		# Чужой несёт: перехватываем на пути к его көмбе.
		var their_base := m.bases[m.teams[m.carrier]]
		var lead := minf(LEAD, carried.distance_to(their_base))
		return carried + (their_base - carried).normalized() * lead

	if not knows_bone:
		return roam
	# Сүйек на земле, и команда знает где: іздеуші бегут к нему, қорғаушы
	# встречает соперника-іздеуші, который успеет раньше.
	if m.roles[me] == AqSuyekMatch.Role.DEFENDER:
		var rival := _nearest_enemy(m.bone, team, m, positions, true)
		if rival >= 0 and positions[rival].distance_to(m.bone) < SIGHT * 2.0:
			return positions[rival]
	return m.bone

## Ближайший к точке соперник команды team, который не остановлен; только
## іздеуші, если seekers_only. -1 — таких нет.
static func _nearest_enemy(point: Vector2, team: int, m: AqSuyekMatch, positions: Array[Vector2],
		seekers_only: bool) -> int:
	var best := -1
	var best_distance := INF
	for id in m.teams.size():
		if m.teams[id] == team or m.is_stunned(id):
			continue
		if seekers_only and m.roles[id] != AqSuyekMatch.Role.SEEKER:
			continue
		var distance := positions[id].distance_to(point)
		if distance < best_distance:
			best = id
			best_distance = distance
	return best
