class_name MatchManager
extends Node

enum MatchState { SETUP, COUNTDOWN, PLAYING, QUIZ, ROUND_END, MATCH_END }

signal match_state_changed(new_state: MatchState)
signal round_started
signal sokyroteke_assigned(player: Player)
signal player_caught(catcher: Player, caught: Player)
signal player_eliminated(player: Player)
signal quiz_triggered(catcher: Player, target: Player, item: ClothingItem)
signal quiz_resolved(catcher: Player, target: Player, correct: bool)
signal item_unlocked(item: ClothingItem)
signal round_ended(winner: String)
signal match_ended(results: Dictionary)

var current_state: MatchState = MatchState.SETUP
var mode: GameModeDefinition
var map: MapManager

var players: Array[Player] = []
var human_player: Player
var sokyroteke: Player
var forced_sokyroteke: Player
var human_must_be_runner := false

var current_round: int = 0
var round_timer: float = 0.0
var headstart_timer: float = 0.0
var quiz_active: bool = false

var runners_total: int = 0
var eliminated_count: int = 0
var catch_cooldown: float = 0.0
var _last_quiz_item: ClothingItem
var _last_target: Player
var _last_winner: String = "players"

func _ready() -> void:
	mode = AssetRegistry.get_default_mode()
	if mode == null:
		mode = GameModeDefinition.new()

func setup_match(_map: MapManager, _players: Array[Player]) -> void:
	map = _map
	players = _players
	for p in players:
		p.global_position = map.get_safe_spawn()
		if not p.is_bot:
			human_player = p

func start_match() -> void:
	current_round = 1
	_start_new_round()

func _start_new_round() -> void:
	_select_sokyroteke()
	eliminated_count = 0
	runners_total = 0
	for p in players:
		p.set_as_sokyroteke(p == sokyroteke)
		p.revive()
		if p != sokyroteke:
			runners_total += 1

	headstart_timer = mode.headstart_secs
	round_timer = mode.round_base_time + mode.time_per_runner * maxi(0, runners_total - 1)

	current_state = MatchState.COUNTDOWN
	match_state_changed.emit(current_state)
	round_started.emit()

func _select_sokyroteke() -> void:
	if forced_sokyroteke and forced_sokyroteke.is_alive():
		sokyroteke = forced_sokyroteke
		sokyroteke_assigned.emit(sokyroteke)
		return
	var candidates: Array[Player] = []
	for p in players:
		if human_must_be_runner and p == human_player:
			continue
		if p != sokyroteke or sokyroteke == null:
			candidates.append(p)
	if candidates.is_empty():
		candidates = players
	var chosen := candidates[randi() % candidates.size()]
	var old := sokyroteke
	sokyroteke = chosen
	if old and old != chosen:
		old.set_as_sokyroteke(false)
	chosen.set_as_sokyroteke(true)
	sokyroteke_assigned.emit(chosen)

func _process(delta: float) -> void:
	if catch_cooldown > 0:
		catch_cooldown -= delta

	if current_state == MatchState.COUNTDOWN:
		headstart_timer -= delta
		if headstart_timer <= 0:
			current_state = MatchState.PLAYING
			match_state_changed.emit(current_state)
		return

	if current_state == MatchState.PLAYING:
		round_timer -= delta
		if round_timer <= 0:
			_end_round(false)
		return

	if current_state == MatchState.QUIZ:
		if quiz_active:
			return
		current_state = MatchState.PLAYING
		match_state_changed.emit(current_state)

func on_player_touches_sokyroteke(player: Player) -> void:
	if current_state != MatchState.PLAYING:
		return
	if quiz_active:
		return
	if catch_cooldown > 0:
		return
	if player == sokyroteke:
		return
	if player.eliminated:
		return
	if player.has_shield():
		return
	if sokyroteke.is_slowed():
		return

	player_caught.emit(sokyroteke, player)
	_trigger_quiz(player)

func on_catch_area_entered(area: Area2D) -> void:
	var body := area.get_parent() as Player
	if body == null or body == sokyroteke:
		return
	on_player_touches_sokyroteke(body)

func _trigger_quiz(target: Player) -> void:
	var item := target.get_random_clothing_item_for_quiz()
	if item == null:
		return
	_last_quiz_item = item
	_last_target = target

	quiz_active = true
	current_state = MatchState.QUIZ
	match_state_changed.emit(current_state)
	quiz_triggered.emit(sokyroteke, target, item)

	sokyroteke.set_frozen(true)
	target.set_frozen(true)

	if sokyroteke.is_bot:
		var chance := _bot_correct_chance()
		await get_tree().create_timer(1.0).timeout
		submit_quiz_answer(randf() < chance)

func _bot_correct_chance() -> float:
	var base_chance := 0.65
	var agent := sokyroteke.get_node_or_null("BotAgent") as BotAgent
	if agent and agent.bot_profile:
		match agent.bot_profile.difficulty:
			BotProfile.Difficulty.EASY: base_chance = 0.55
			BotProfile.Difficulty.MEDIUM: base_chance = 0.7
			BotProfile.Difficulty.HARD: base_chance = 0.9
	var extra_players := maxi(0, players.size() - 2)
	return maxf(0.35, base_chance - float(extra_players) * 0.02)

func submit_quiz_answer(correct: bool) -> void:
	quiz_active = false
	catch_cooldown = 1.0

	sokyroteke.set_frozen(false)
	if _last_target:
		_last_target.set_frozen(false)
		quiz_resolved.emit(sokyroteke, _last_target, correct)

	if correct:
		if _last_target:
			_last_target.eliminate()
			eliminated_count += 1
			player_eliminated.emit(_last_target)
		if _last_quiz_item and not SaveManager.is_unlocked(_last_quiz_item.id):
			SaveManager.unlock_item(_last_quiz_item.id)
			item_unlocked.emit(_last_quiz_item)
		if eliminated_count >= runners_total:
			_end_round(true)
	else:
		sokyroteke.apply_slow(mode.slow_duration)
		if _last_target:
			_last_target.apply_shield(mode.shield_duration)
			catch_cooldown = maxf(catch_cooldown, mode.shield_duration)

	current_state = MatchState.PLAYING
	match_state_changed.emit(current_state)

func _end_round(sokyroteke_won: bool) -> void:
	current_state = MatchState.ROUND_END
	match_state_changed.emit(current_state)

	var winner := "sokyroteke" if sokyroteke_won else "players"
	_last_winner = winner
	round_ended.emit(winner)
	await get_tree().create_timer(3.0).timeout
	_end_match()

func _end_match() -> void:
	current_state = MatchState.MATCH_END
	match_state_changed.emit(current_state)
	match_ended.emit({"winner": _last_winner})

func _T(key: String) -> String:
	return GameSettings.localize(key)
