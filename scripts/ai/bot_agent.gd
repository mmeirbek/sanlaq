class_name BotAgent
extends Node

enum BotState { WANDER, FLEE, HIDE, IDLE }

@export var bot_profile: BotProfile

@onready var _player: Player = get_parent()

var _current_state: BotState = BotState.WANDER
var _target_pos: Vector2 = Vector2.ZERO
var _reaction_timer: float = 0.0
var _wander_timer: float = 0.0
var _noise_timer: float = 0.0

var _match_mgr: MatchManager
var _map: MapManager

func _ready() -> void:
	_reaction_timer = randf_range(0.0, bot_profile.reaction_delay)
	_wander_timer = randf_range(0.5, 2.0)
	_noise_timer = randf_range(0.0, 3.0)
	_pick_new_wander_target()

func setup(profile: BotProfile, mgr: MatchManager, map_mgr: MapManager) -> void:
	bot_profile = profile
	_match_mgr = mgr
	_map = map_mgr

func _physics_process(delta: float) -> void:
	if _match_mgr == null or _map == null:
		return
	if _player.eliminated:
		_player._controller.set_remote_input(Vector2.ZERO, false)
		return

	var sokyroteke := _match_mgr.sokyroteke
	var dir := Vector2.ZERO
	var sprint := false

	if _player == sokyroteke:
		_process_sokyroteke(delta)
		return

	var dist_to_s := 99999.0
	if sokyroteke:
		dist_to_s = _player.global_position.distance_to(sokyroteke.global_position)

	if dist_to_s < bot_profile.fear_distance:
		_current_state = BotState.FLEE
	else:
		_current_state = BotState.WANDER

	match _current_state:
		BotState.FLEE:
			dir = _flee_from(sokyroteke, dist_to_s, delta)
			sprint = bot_profile.can_sprint and dist_to_s < bot_profile.fear_distance * 0.6
		BotState.WANDER:
			dir = _wander(delta)
		_:
			dir = Vector2.ZERO

	dir = _avoid_obstacles(dir)

	if dir.length() > 1.0:
		dir = dir.normalized()

	_player._controller.set_remote_input(dir, sprint)

	_noise_timer -= delta
	if _noise_timer <= 0:
		_noise_timer = randf_range(1.5, 4.0)
		if _player.current_speed > 5:
			_noise_timer *= 0.5

func _flee_from(target: Player, dist: float, _delta: float) -> Vector2:
	var away := _player.global_position - target.global_position
	if away.length() > 0:
		away = away.normalized()
	else:
		away = Vector2.RIGHT
	return away

func _wander(delta: float) -> Vector2:
	_wander_timer -= delta
	if _wander_timer <= 0:
		_pick_new_wander_target()
		_wander_timer = randf_range(1.0, 3.0)

	var to_target := _target_pos - _player.global_position
	if to_target.length() < 20:
		_pick_new_wander_target()
	return to_target.normalized()

func _pick_new_wander_target() -> void:
	var b := _map.bounds
	_target_pos = Vector2(
		randf_range(b.position.x + 80, b.end.x - 80),
		randf_range(b.position.y + 80, b.end.y - 80)
	)

func _process_sokyroteke(_delta: float) -> void:
	for p in _match_mgr.players:
		if p == _player or not p.is_alive():
			continue
		if _map.is_inside_yurt(p.global_position):
			continue
		if p.has_shield():
			continue
		var to_p := p.global_position - _player.global_position
		# Shapan reduces the range at which any seeker (including a bot) notices a runner.
		var detection_range := 200.0 * p.get_visibility_multiplier()
		if to_p.length() < detection_range:
			_player._controller.set_remote_input(to_p.normalized() * 0.8, true)
			return

	var dir := (_map.get_random_spawn() - _player.global_position).normalized()
	_player._controller.set_remote_input(dir, false)

func _avoid_obstacles(dir: Vector2) -> Vector2:
	if dir.length() < 0.1:
		return dir
	for obs in _map.obstacle_positions:
		var to_obs := obs - _player.global_position
		var dist := to_obs.length()
		if dist < 60.0:
			var away := -to_obs.normalized()
			dir = dir * 0.5 + away * 0.5
	for yurt in _map.yurt_positions:
		var to_yurt := yurt - _player.global_position
		var dist := to_yurt.length()
		if dist < 70.0:
			continue
		if dist < 125.0:
			var away := -to_yurt.normalized()
			dir = dir * 0.6 + away * 0.4
	return dir
