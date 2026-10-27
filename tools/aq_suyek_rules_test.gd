extends "res://tools/test_case.gd"
## Автотест правил «Ақ сүйек» на карте (scripts/core/aq_suyek_match.gd) и того,
## как по ним ходят боты (scripts/ai/aq_suyek_brain.gd). Запускается в CI:
##     godot --headless --path . --script tools/aq_suyek_rules_test.gd
## При провале выходит с кодом 1 и роняет сборку.

const SEEKER := AqSuyekMatch.Role.SEEKER
const DEFENDER := AqSuyekMatch.Role.DEFENDER
const BLUE := AqSuyekMatch.Team.BLUE
const RED := AqSuyekMatch.Team.RED
const BASES: Array[Vector2] = [Vector2(-700, 0), Vector2(700, 0)]
const FIELD := Rect2(-850, -500, 1700, 1000)
const SELF_PLAY_GAMES := 100
const FRAME := 1.0 / 30.0
## Шаг симуляции партий ботов: крупнее кадра, чтобы прогон шёл секунды.
const SIM_FRAME := 0.05
const SPEED := 220.0

func _init() -> void:
	_test_setup()
	_test_seeker_picks_up()
	_test_defender_cannot_carry()
	_test_delivery_scores()
	_test_no_delivery_to_enemy_base()
	_test_steal_waits_for_immunity()
	_test_no_steal_back_right_away()
	_test_defender_stuns_and_drops()
	_test_defender_cooldown()
	_test_stunned_cannot_act()
	_test_teammates_do_not_interact()
	_test_timeout_is_a_round_without_points()
	_test_match_ends_at_two_wins()
	_test_draws_still_end_the_match()
	_test_bot_targets()
	_test_random_self_play()
	finish("AQ SUYEK RULES")

## Көк: 0 и 1 — іздеуші, 2 — қорғаушы. Қызыл: 3 и 4 — іздеуші, 5 — қорғаушы.
func _match() -> AqSuyekMatch:
	var m := AqSuyekMatch.new()
	for team in [BLUE, RED]:
		m.add_player(team, SEEKER)
		m.add_player(team, SEEKER)
		m.add_player(team, DEFENDER)
	m.bases = BASES.duplicate()
	m.start_round(Vector2.ZERO)
	return m

## Все стоят далеко друг от друга и от сүйек — ничего не происходит, пока тест
## сам не сдвинет кого-то.
func _apart() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 6:
		out.append(Vector2(-400 + i * 160, 400))
	return out

func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out

func _test_setup() -> void:
	var m := _match()
	check(m.teams.size() == 6 and m.roles.size() == 6, "в партии шесть игроков")
	check(m.teams.count(BLUE) == 3 and m.teams.count(RED) == 3, "две команды по трое")
	check(m.carrier == -1 and m.bone == Vector2.ZERO, "сүйек лежит на земле, у него нет хозяина")
	check(m.playing and m.time_left == AqSuyekMatch.ROUND_TIME, "раунд идёт, время полное")
	check(m.step(FRAME, _apart()).is_empty(), "пока никто не рядом, ничего не происходит")

func _test_seeker_picks_up() -> void:
	var m := _match()
	var pos := _apart()
	pos[1] = Vector2(10, 0)
	var events := m.step(FRAME, pos)
	check(m.carrier == 1 and _types(events).has("picked"), "іздеуші поднимает сүйек")
	pos[1] = Vector2(-200, 50)
	m.step(FRAME, pos)
	check(m.bone == pos[1], "сүйек едет вместе с несущим")

func _test_defender_cannot_carry() -> void:
	var m := _match()
	var pos := _apart()
	pos[2] = Vector2(5, 0)
	m.step(FRAME, pos)
	check(m.carrier == -1, "қорғаушы сүйек не поднимает")

func _test_delivery_scores() -> void:
	var m := _match()
	var pos := _apart()
	pos[0] = Vector2.ZERO
	m.step(FRAME, pos)
	pos[0] = BASES[BLUE] + Vector2(20, 0)
	var events := m.step(FRAME, pos)
	var types := _types(events)
	check(types.has("delivered") and types.has("round_over"), "донёс до своей көмбе — раунд окончен")
	check(m.scores == [1, 0], "очко досталось команде несущего, счёт %s" % [m.scores])
	check(not m.playing and m.round_index == 1, "раунд закрыт, счётчик раундов вырос")

func _test_no_delivery_to_enemy_base() -> void:
	var m := _match()
	var pos := _apart()
	pos[0] = Vector2.ZERO
	m.step(FRAME, pos)
	pos[0] = BASES[RED]
	m.step(FRAME, pos)
	check(m.playing and m.scores == [0, 0], "в чужую көмбе очко не засчитывается")

func _test_steal_waits_for_immunity() -> void:
	var m := _match()
	var pos := _apart()
	pos[0] = Vector2.ZERO
	pos[3] = Vector2(20, 0)
	# Оба у сүйек, ближе Көк — он и поднял; Қызыл стоит вплотную.
	m.step(FRAME, pos)
	check(m.carrier == 0, "поднял ближайший к сүйек")
	m.step(FRAME, pos)
	check(m.carrier == 0, "сразу после подъёма сүйек не отобрать")
	m.step(AqSuyekMatch.STEAL_IMMUNITY, pos)
	check(m.carrier == 3, "после передышки соперник-іздеуші отбирает касанием")

func _test_no_steal_back_right_away() -> void:
	var m := _match()
	var pos := _apart()
	pos[0] = Vector2.ZERO
	pos[3] = Vector2(20, 0)
	m.step(FRAME, pos)
	m.step(AqSuyekMatch.STEAL_IMMUNITY, pos)
	var stolen := m.carrier
	m.step(FRAME, pos)
	check(stolen == 3 and m.carrier == 3, "отобранное сразу не перекидывается обратно")

func _test_defender_stuns_and_drops() -> void:
	var m := _match()
	var pos := _apart()
	pos[0] = Vector2.ZERO
	m.step(FRAME, pos)
	pos[0] = Vector2(-300, 0)
	pos[5] = Vector2(-290, 0)
	var events := m.step(FRAME, pos)
	check(_types(events).has("stunned"), "қорғаушы останавливает несущего касанием")
	check(m.is_stunned(0) and m.stun_left(0) > AqSuyekMatch.STUN_TIME - 0.1, "остановлен на STUN_TIME")
	check(m.carrier == -1 and m.bone == pos[0], "остановленный уронил сүйек там, где стоял")
	m.step(AqSuyekMatch.STUN_TIME, pos)
	check(not m.is_stunned(0), "через STUN_TIME снова в игре")

func _test_defender_cooldown() -> void:
	var m := _match()
	var pos := _apart()
	pos[5] = Vector2(0, 300)
	pos[0] = Vector2(10, 300)
	m.step(FRAME, pos)
	m.step(AqSuyekMatch.STUN_TIME, pos)
	check(not m.is_stunned(0), "остановка кончилась")
	m.step(FRAME, pos)
	check(not m.is_stunned(0), "пока қорғаушы перезаряжается, второй раз не останавливает")
	m.step(AqSuyekMatch.DEFENDER_COOLDOWN, pos)
	check(m.is_stunned(0), "после перезарядки останавливает снова")

func _test_stunned_cannot_act() -> void:
	var m := _match()
	var pos := _apart()
	pos[5] = Vector2(100, 0)
	pos[1] = Vector2(110, 0)
	m.step(FRAME, pos)
	check(m.is_stunned(1), "іздеуші Көк остановлен")
	pos[1] = Vector2(5, 0)
	m.step(FRAME, pos)
	check(m.carrier == -1, "остановленный не поднимает сүйек")

func _test_teammates_do_not_interact() -> void:
	var m := _match()
	var pos := _apart()
	pos[0] = Vector2.ZERO
	m.step(FRAME, pos)
	pos[1] = Vector2(10, 0)
	pos[2] = Vector2(-10, 0)
	m.step(AqSuyekMatch.STEAL_IMMUNITY + FRAME, pos)
	check(m.carrier == 0 and not m.is_stunned(0), "свои не отбирают сүйек и не останавливают")

func _test_timeout_is_a_round_without_points() -> void:
	var m := _match()
	var events := m.step(AqSuyekMatch.ROUND_TIME + 1.0, _apart())
	check(_types(events).has("timeout") and not m.playing, "время вышло — раунд окончен")
	check(m.scores == [0, 0] and m.round_index == 1, "раунд без очков всё равно засчитан как сыгранный")

func _test_match_ends_at_two_wins() -> void:
	var m := _match()
	for i in 2:
		check(not m.finished, "партия идёт перед раундом %d" % (i + 1))
		_deliver(m, 3)
		if not m.finished:
			m.start_round(Vector2.ZERO)
	check(m.finished and m.winner_team == RED, "две победы Қызыл — партия окончена, победил Қызыл")
	check(m.round_index == 2, "третий раунд не понадобился")

func _test_draws_still_end_the_match() -> void:
	var m := _match()
	_deliver(m, 0)
	for i in 2:
		m.start_round(Vector2.ZERO)
		m.step(AqSuyekMatch.ROUND_TIME + 1.0, _apart())
	check(m.finished and m.winner_team == BLUE, "после трёх раундов побеждает команда с бо́льшим счётом")
	var even := _match()
	for i in AqSuyekMatch.ROUNDS:
		even.step(AqSuyekMatch.ROUND_TIME + 1.0, _apart())
		if not even.finished:
			even.start_round(Vector2.ZERO)
	check(even.finished and even.winner_team == -1, "ни одного очка за три раунда — ничья")

## Игрок id поднимает сүйек в центре и относит в свою көмбе.
func _deliver(m: AqSuyekMatch, id: int) -> void:
	var pos := _apart()
	pos[id] = m.bone
	m.step(FRAME, pos)
	pos[id] = m.bases[m.teams[id]]
	m.step(FRAME, pos)

func _test_bot_targets() -> void:
	var m := _match()
	var pos := _apart()
	var roam := Vector2(123, -45)
	check(AqSuyekBrain.target(1, m, pos, false, roam) == roam, "сүйек не видно — бот ищет")
	check(AqSuyekBrain.target(1, m, pos, true, roam) == m.bone, "сүйек видно — іздеуші бежит к нему")
	pos[0] = Vector2.ZERO
	m.step(FRAME, pos)
	check(AqSuyekBrain.target(0, m, pos, true, roam) == BASES[BLUE], "несущий бежит к своей көмбе")
	var chase := AqSuyekBrain.target(4, m, pos, true, roam)
	check(chase.distance_to(pos[0]) <= AqSuyekBrain.LEAD + 0.1 and chase.x < pos[0].x,
		"соперник догоняет несущего с упреждением к его көмбе: %s" % chase)
	pos[3] = Vector2(-60, 0)
	check(AqSuyekBrain.target(2, m, pos, true, roam) == pos[3],
		"қорғаушы встречает соперника, ближайшего к своему несущему")
	var cover := AqSuyekBrain.target(1, m, pos, true, roam)
	check(cover.x < 0.0 and cover.distance_to(pos[0]) <= AqSuyekBrain.ESCORT_GAP + 0.1,
		"свой іздеуші прикрывает несущего со стороны погони: %s" % cover)
	var tackle := pos.duplicate()
	tackle[5] = pos[0] + Vector2(10, 0)
	m.step(FRAME, tackle)
	check(m.is_stunned(0) and AqSuyekBrain.target(0, m, tackle, true, roam) == tackle[0],
		"остановленный бот стоит на месте")

## Партии ботов друг против друга по тем же правилам: все шестеро — боты,
## бегут к точкам из AqSuyekBrain. Каждая партия обязана закончиться, а счёт —
## сходиться с числом донесённых сүйек.
func _test_random_self_play() -> void:
	var unfinished := 0
	var score_mismatch := 0
	var bad_carrier := 0
	var delivered_total := 0
	for game in SELF_PLAY_GAMES:
		var m := _match()
		m.start_round(_random_spot())
		var pos := _spawn_positions()
		var knows := [false, false]
		var roam := _roam_points()
		var delivered := 0
		var frames := 0
		# Три раунда по 90 секунд — потолок; дальше партия считается зависшей.
		while not m.finished and frames * SIM_FRAME < AqSuyekMatch.ROUND_TIME * (AqSuyekMatch.ROUNDS + 1):
			frames += 1
			for id in 6:
				var team: int = m.teams[id]
				if not knows[team]:
					knows[team] = m.carrier >= 0 or AqSuyekBrain.sees(team, m, pos)
				if pos[id].distance_to(roam[id]) < 30.0:
					roam[id] = _random_spot()
				var target := AqSuyekBrain.target(id, m, pos, knows[team], roam[id])
				var speed := SPEED * (AqSuyekMatch.CARRY_SPEED if m.carrier == id else 1.0)
				if not m.is_stunned(id):
					pos[id] = pos[id].move_toward(target, speed * SIM_FRAME).clamp(FIELD.position, FIELD.end)
			for e in m.step(SIM_FRAME, pos):
				if e["type"] == "delivered":
					delivered += 1
				if e["type"] == "round_over" and not m.finished:
					m.start_round(_random_spot())
					pos = _spawn_positions()
					knows = [false, false]
			if m.carrier >= 0 and m.roles[m.carrier] != SEEKER:
				bad_carrier += 1
		if not m.finished:
			unfinished += 1
		if delivered != m.scores[0] + m.scores[1]:
			score_mismatch += 1
		delivered_total += delivered
	check(unfinished == 0, "все %d партий ботов закончились (не закончилось: %d)" % [SELF_PLAY_GAMES, unfinished])
	check(score_mismatch == 0, "счёт всегда равен числу донесённых сүйек (расхождений: %d)" % score_mismatch)
	check(bad_carrier == 0, "сүйек носят только іздеуші (нарушений: %d)" % bad_carrier)
	check(delivered_total > SELF_PLAY_GAMES,
		"боты действительно доносят сүйек: %d раз за %d партий" % [delivered_total, SELF_PLAY_GAMES])

func _spawn_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for team in [BLUE, RED]:
		for k in 3:
			out.append(BASES[team] + Vector2(0, -60 + k * 60))
	return out

func _roam_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 6:
		out.append(_random_spot())
	return out

func _random_spot() -> Vector2:
	return Vector2(randf_range(-450, 450), randf_range(-400, 400))
