class_name BotAgent
extends Node

enum BotState { WANDER, FLEE, HIDE }

const MEMORY_DURATION := 2.5    # bot-as-sokyroteke keeps checking a runner's last known spot instead of instantly forgetting
const HIDE_TRIGGER_RADIUS := 260.0  # only worth ducking into a yurt that's reasonably close by
const HIDE_DURATION := 3.5      # shorter than the game's 5s yurt-reveal delay, on purpose
const HIDE_REACHED_DIST := 24.0
const ARENA_CENTER_APPROX := Vector2.ZERO

@export var bot_profile: BotProfile

@onready var _player: Player = get_parent()

var _current_state: BotState = BotState.WANDER
var _target_pos: Vector2 = Vector2.ZERO
var _reaction_timer: float = 0.0
var _wander_timer: float = 0.0
var _noise_timer: float = 0.0
var _pause_timer: float = 0.0

var _hide_target: Vector2 = Vector2.ZERO
var _hide_timer: float = 0.0
var _flee_hide_rolled: bool = false

var _last_seen_pos: Vector2 = Vector2.ZERO
var _last_seen_timer: float = 0.0

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
	if _player == sokyroteke:
		_process_sokyroteke(delta)
		return

	var dist_to_s := 99999.0
	if sokyroteke:
		dist_to_s = _player.global_position.distance_to(sokyroteke.global_position)

	var was_fleeing := _current_state == BotState.FLEE
	if _current_state != BotState.HIDE:
		_current_state = BotState.FLEE if dist_to_s < bot_profile.fear_distance else BotState.WANDER
	if not was_fleeing and _current_state == BotState.FLEE:
		_flee_hide_rolled = false  # fresh flee episode — allow a new hide roll

	var dir := Vector2.ZERO
	var sprint := false

	match _current_state:
		BotState.HIDE:
			dir = _process_hide(delta)
		BotState.FLEE:
			dir = _flee_from(sokyroteke)
			sprint = bot_profile.can_sprint and dist_to_s < bot_profile.fear_distance * 0.6
			_player.set_bot_speed_mult(1.0)
			_maybe_start_hiding()
		_:
			dir = _wander(delta)
			_player.set_bot_speed_mult(bot_profile.wander_speed_mult)

	if _current_state != BotState.HIDE:
		dir = _avoid_obstacles(dir)
		dir = _avoid_other_bots(dir)

	if dir.length() > 1.0:
		dir = dir.normalized()

	_player._controller.set_remote_input(dir, sprint)

	_noise_timer -= delta
	if _noise_timer <= 0:
		_noise_timer = randf_range(1.5, 4.0)
		if _player.current_speed > 5:
			_noise_timer *= 0.5

func _flee_from(target: Player) -> Vector2:
	var away := _player.global_position - target.global_position
	away = away.normalized() if away.length() > 0 else Vector2.RIGHT
	# Steer away from map edges too — otherwise "run away from the sokyroteke" can walk a
	# bot straight into a corner where there's nowhere left to go.
	var b := _map.bounds
	var edge_dist: float = minf(
		minf(_player.global_position.x - b.position.x, b.end.x - _player.global_position.x),
		minf(_player.global_position.y - b.position.y, b.end.y - _player.global_position.y)
	)
	if edge_dist < 180.0:
		var to_center := ARENA_CENTER_APPROX - _player.global_position
		if to_center.length() > 1.0:
			var center_pull := clampf(1.0 - edge_dist / 180.0, 0.0, 0.6)
			away = (away * (1.0 - center_pull) + to_center.normalized() * center_pull).normalized()
	return away

func _maybe_start_hiding() -> void:
	if _flee_hide_rolled or not bot_profile.use_hiding_spots or bot_profile.hide_tendency <= 0.0:
		return
	_flee_hide_rolled = true
	if randf() > bot_profile.hide_tendency:
		return
	var nearest := Vector2.INF
	var nearest_dist := HIDE_TRIGGER_RADIUS
	for yurt in _map.yurt_positions:
		var d := _player.global_position.distance_to(yurt)
		if d < nearest_dist:
			nearest_dist = d
			nearest = yurt
	if nearest == Vector2.INF:
		return
	_current_state = BotState.HIDE
	_hide_target = nearest
	_hide_timer = HIDE_DURATION

func _process_hide(delta: float) -> Vector2:
	_hide_timer -= delta
	if _hide_timer <= 0.0:
		_current_state = BotState.WANDER
		_pick_new_wander_target()
		return Vector2.ZERO
	if _player.global_position.distance_to(_hide_target) < HIDE_REACHED_DIST:
		# Tucked in under the roof — hold still rather than pacing around inside.
		_player.set_bot_speed_mult(0.0)
		return Vector2.ZERO
	_player.set_bot_speed_mult(1.0)
	return (_hide_target - _player.global_position).normalized()

func _wander(delta: float) -> Vector2:
	if _pause_timer > 0.0:
		_pause_timer -= delta
		return Vector2.ZERO
	_wander_timer -= delta
	if _wander_timer <= 0:
		_pick_new_wander_target()
		_wander_timer = randf_range(1.0, 3.0)
		if randf() < 0.2:
			_pause_timer = randf_range(0.4, 1.1)  # the occasional pause reads as "looking around" instead of a robotic beeline

	var to_target := _target_pos - _player.global_position
	if to_target.length() < 20:
		_pick_new_wander_target()
	return to_target.normalized()

func _pick_new_wander_target() -> void:
	var b := _map.bounds
	# Bias toward a nearby point most of the time so wandering reads as strolling around
	# rather than a robotic beeline clear across the map; occasionally roam further.
	if randf() < 0.75:
		var reach := randf_range(150.0, 420.0)
		var angle := randf_range(0.0, TAU)
		var candidate := _player.global_position + Vector2(cos(angle), sin(angle)) * reach
		candidate.x = clampf(candidate.x, b.position.x + 80, b.end.x - 80)
		candidate.y = clampf(candidate.y, b.position.y + 80, b.end.y - 80)
		_target_pos = candidate
	else:
		_target_pos = Vector2(
			randf_range(b.position.x + 80, b.end.x - 80),
			randf_range(b.position.y + 80, b.end.y - 80)
		)

const SOKYROTEKE_BOT_SPEED_MULT := 0.92  # чуть баяулатады — тек бот соқыртекеге, ойыншыға тимейді

func _process_sokyroteke(delta: float) -> void:
	_player.set_bot_speed_mult(SOKYROTEKE_BOT_SPEED_MULT)
	if _last_seen_timer > 0.0:
		_last_seen_timer -= delta

	var dir := Vector2.ZERO
	var sprint := false

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
			_last_seen_pos = p.global_position
			_last_seen_timer = MEMORY_DURATION
			dir = to_p.normalized()
			sprint = true
			_player._controller.set_remote_input(_avoid_obstacles(dir), sprint)
			return

	if _last_seen_timer > 0.0:
		# Keep checking the spot a runner was last seen for a few seconds instead of
		# instantly forgetting and picking a fresh random point the moment they duck away.
		var to_last := _last_seen_pos - _player.global_position
		if to_last.length() > 16.0:
			dir = to_last.normalized()
			_player._controller.set_remote_input(_avoid_obstacles(dir), true)
			return

	dir = (_map.get_random_spawn() - _player.global_position).normalized()
	# A blind beeline toward the target can wedge the seeker against a rock/yurt with
	# nothing to route around it — this is what made it look "stuck in one place".
	_player._controller.set_remote_input(_avoid_obstacles(dir), false)

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

func _avoid_other_bots(dir: Vector2) -> Vector2:
	if dir.length() < 0.1:
		return dir
	# Wandering/fleeing bots have no personal space otherwise and end up clumped
	# together in a corner or doorway, which reads as "stuck to each other".
	for p in _match_mgr.players:
		if p == _player or not p.is_alive():
			continue
		var to_p := p.global_position - _player.global_position
		var dist := to_p.length()
		if dist > 0.01 and dist < 46.0:
			var away := -to_p.normalized()
			dir = dir * 0.5 + away * 0.5
	return dir
