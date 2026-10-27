class_name AqSuyekMatch
extends RefCounted
## Правила «Ақ сүйек» на карте, как в документации проекта: две команды ищут
## ақ сүйек в ночной степи, нашедший несёт его в көмбе своей команды, соперники
## стараются его остановить. Спецификация — Aq_suiek_mode_spec.md.
##
## Про сцену класс не знает: позиции игроков приходят в step(), обратно уходит
## список событий, по которым экран играет звук и показывает сообщения. Тот же
## приём, что у GameBoard (тоғыз), — правила проверяются headless.
##
## Роли в команде:
##   іздеуші (SEEKER)    — поднимает сүйек, несёт его и отбирает у соперника;
##   қорғаушы (DEFENDER) — сүйек не носит, но касанием останавливает соперника
##                         на STUN_TIME; остановленный роняет сүйек.

enum Team { BLUE, RED }
enum Role { SEEKER, DEFENDER }

## Баланс собран здесь, чтобы менялся одной строкой.
## Партия — до двух очков из трёх раундов.
const ROUNDS := 3
const WINS_NEEDED := 2
const ROUND_TIME := 90.0
## Расстояния — в пикселях мира между точками игроков на земле.
const PICKUP_RADIUS := 28.0
const TAG_RADIUS := 30.0
const BASE_RADIUS := 60.0
const STUN_TIME := 2.0
const DEFENDER_COOLDOWN := 3.0
## Сразу после того как сүйек сменил хозяина, его нельзя отобрать: иначе двое,
## стоящие вплотную, перекидывали бы его каждый кадр.
const STEAL_IMMUNITY := 1.2
## Несущий бежит медленнее — у догоняющих есть шанс.
const CARRY_SPEED := 0.85

## По игроку на индекс: команда и роль. Индекс — id игрока во всех методах.
var teams: Array[int] = []
var roles: Array[int] = []
## Көмбе команд, по индексу Team.
var bases: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
## Где сүйек: на земле или у несущего (тогда совпадает с его позицией).
var bone := Vector2.ZERO
## Кто несёт сүйек; -1 — лежит на земле.
var carrier := -1
var scores: Array[int] = [0, 0]
var round_index := 0
var time_left := ROUND_TIME
## Раунд идёт: от start_round() до конца раунда.
var playing := false
var finished := false
## Победившая команда; -1 — ничья или партия ещё идёт.
var winner_team := -1

var _stun: Array[float] = []
var _cooldown: Array[float] = []
var _immunity := 0.0

func add_player(team: Team, role: Role) -> int:
	teams.append(team)
	roles.append(role)
	_stun.append(0.0)
	_cooldown.append(0.0)
	return teams.size() - 1

## Новый раунд: сүйек брошен в bone_at, время полное, никто не остановлен.
func start_round(bone_at: Vector2) -> void:
	bone = bone_at
	carrier = -1
	time_left = ROUND_TIME
	_immunity = 0.0
	for id in teams.size():
		_stun[id] = 0.0
		_cooldown[id] = 0.0
	playing = true

func is_stunned(id: int) -> bool:
	return _stun[id] > 0.0

func stun_left(id: int) -> float:
	return _stun[id]

func opponent(team: int) -> int:
	return 1 - team

## Один кадр раунда. positions — где стоит каждый игрок, по id. Возвращает
## события по порядку:
##   picked    {player, team}          — поднял сүйек с земли
##   stolen    {player, from, team}    — отобрал у несущего
##   stunned   {player, target, dropped} — қорғаушы остановил соперника
##   delivered {player, team}          — донёс до своей көмбе
##   timeout   {}                      — время раунда вышло
##   round_over {team, finished, winner} — раунд окончен; team = -1 без очков
func step(delta: float, positions: Array[Vector2]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not playing:
		return events
	for id in teams.size():
		_stun[id] = maxf(0.0, _stun[id] - delta)
		_cooldown[id] = maxf(0.0, _cooldown[id] - delta)
	_immunity = maxf(0.0, _immunity - delta)

	if carrier >= 0:
		bone = positions[carrier]
		var team := teams[carrier]
		if bone.distance_to(bases[team]) <= BASE_RADIUS:
			events.append({"type": "delivered", "player": carrier, "team": team})
			_end_round(team, events)
			return events
	else:
		var finder := _nearest_free_seeker(positions)
		if finder >= 0:
			carrier = finder
			_immunity = STEAL_IMMUNITY
			events.append({"type": "picked", "player": finder, "team": teams[finder]})

	for a in teams.size():
		for b in range(a + 1, teams.size()):
			if teams[a] == teams[b] or positions[a].distance_to(positions[b]) > TAG_RADIUS:
				continue
			_touch(a, b, events)
			_touch(b, a, events)

	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		events.append({"type": "timeout"})
		_end_round(-1, events)
	return events

## Ближайший к сүйек іздеуші, который может его поднять; -1 — никого рядом.
func _nearest_free_seeker(positions: Array[Vector2]) -> int:
	var best := -1
	var best_distance := PICKUP_RADIUS
	for id in teams.size():
		if roles[id] != Role.SEEKER or is_stunned(id):
			continue
		var distance := positions[id].distance_to(bone)
		if distance <= best_distance:
			best = id
			best_distance = distance
	return best

## actor коснулся соперника target.
func _touch(actor: int, target: int, events: Array[Dictionary]) -> void:
	if is_stunned(actor) or is_stunned(target):
		return
	if roles[actor] == Role.DEFENDER:
		if _cooldown[actor] > 0.0:
			return
		_stun[target] = STUN_TIME
		_cooldown[actor] = DEFENDER_COOLDOWN
		var dropped := target == carrier
		if dropped:
			# Сүйек остаётся там, где стоял остановленный: bone уже там.
			carrier = -1
		events.append({"type": "stunned", "player": actor, "target": target, "dropped": dropped})
	elif target == carrier and _immunity <= 0.0:
		carrier = actor
		_immunity = STEAL_IMMUNITY
		events.append({"type": "stolen", "player": actor, "from": target, "team": teams[actor]})

func _end_round(team: int, events: Array[Dictionary]) -> void:
	playing = false
	carrier = -1
	if team >= 0:
		scores[team] += 1
	round_index += 1
	if (team >= 0 and scores[team] >= WINS_NEEDED) or round_index >= ROUNDS:
		finished = true
		if scores[Team.BLUE] != scores[Team.RED]:
			winner_team = Team.BLUE if scores[Team.BLUE] > scores[Team.RED] else Team.RED
	events.append({"type": "round_over", "team": team, "finished": finished, "winner": winner_team})
