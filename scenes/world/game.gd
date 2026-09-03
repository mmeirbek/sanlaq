extends Node2D

const BOT_NAMES := ["Айгүл", "Батыр", "Дәулет", "Аружан", "Нұрлан", "Жанар"]
const YURT_REVEAL_DELAY := 5.0
const YURT_REVEAL_DURATION := 5.0

var match_mgr: MatchManager
var map: MapManager
var vision: VisionSystem
var sound_system: SoundWaveSystem
var footprint_system: FootprintSystem
var game_audio: GameAudio
var quiz_hud: QuizHUD
var game_hud: GameHUD
var camera: GameCamera

var _players: Array[Player] = []
var _bots: Array[Node] = []
var _spectating: bool = false
var _spectate_index: int = 0
var _selected_role := "sokyroteke"
var _correct_answers := 0
var _echo_time := 0.0
var _echo_uses := 1
var _event_wait := 18.0
var _fog_time := 0.0
var _prev_human_water := false
var _prev_human_yurt := false
var _yurt_time := {} # key: player_index -> seconds spent in yurt
var _yurt_reveal := {} # key: player_index -> seconds remaining of reveal

@onready var _players_container: Node2D = $Players
@onready var _systems: Node2D = $Systems
@onready var _touch_controls = $TouchControls

func _ready() -> void:
	var game_data := SceneRouter.get_pending_game_data()
	var bot_count: int = clampi(int(game_data.get("bots", 5)), 1, 7)
	_selected_role = game_data.get("role", "sokyroteke")

	match_mgr = _systems.get_node("MatchManager")
	map = $Map as MapManager
	vision = _systems.get_node("VisionSystem")
	sound_system = _systems.get_node("SoundWaveSystem")
	footprint_system = _systems.get_node("FootprintSystem")
	game_audio = GameAudio.new()
	_systems.add_child(game_audio)
	quiz_hud = $CanvasLayer/QuizHUD
	game_hud = $CanvasLayer/GameHUD
	camera = $Camera

	_spawn_human_player()

	var profiles: Array[String] = ["bot_easy", "bot_medium", "bot_hard"]
	for i in bot_count:
		var profile_id: String = profiles[min(i, profiles.size() - 1)]
		_spawn_bot(i, profile_id)
	if _selected_role == "runner":
		match_mgr.human_must_be_runner = true
	else:
		match_mgr.forced_sokyroteke = _players[0]

	match_mgr.sokyroteke_assigned.connect(_on_sokyroteke_assigned)
	match_mgr.quiz_triggered.connect(_on_quiz_triggered)
	match_mgr.round_started.connect(_on_round_started)
	match_mgr.round_ended.connect(_on_round_ended)
	match_mgr.match_ended.connect(_on_match_ended)
	match_mgr.player_caught.connect(_on_player_caught)
	match_mgr.player_eliminated.connect(_on_player_eliminated)
	match_mgr.item_unlocked.connect(_on_item_unlocked)
	match_mgr.quiz_resolved.connect(_on_quiz_resolved)

	quiz_hud.answer_submitted.connect(_on_quiz_answer)
	quiz_hud.hide_quiz()

	_wire_sound_for_players()
	_wire_catch_areas()
	_wire_spectate_buttons()
	game_hud.spectate_requested.connect(_start_spectate)
	game_hud.leave_requested.connect(func() -> void: SceneRouter.go_to_main_menu())

	match_mgr.setup_match(map, _players)
	match_mgr.start_match()
	_setup_match_features()

func _wire_sound_for_players() -> void:
	for p in _players:
		p.stepped.connect(_on_player_stepped.bind(p))
		p.runner_sprint_changed.connect(_on_runner_sprint_changed.bind(p))

func _on_player_stepped(radius: float, player: Player) -> void:
	sound_system.emit_noise(player, radius)
	if not player.is_sokyroteke and not map.is_inside_yurt(player.global_position):
		footprint_system.leave_print(player.global_position, player.velocity)
	if player == match_mgr.human_player:
		game_audio.play_footstep(player.runner_sprint_time > 0.0)

func _on_runner_sprint_changed(time_left: float, _uses_left: int, player: Player) -> void:
	if player == match_mgr.human_player and time_left >= Player.RUNNER_SPRINT_DURATION:
		game_audio.play_sprint()

func _wire_catch_areas() -> void:
	for p in _players:
		var area := p.get_node("CatchArea") as Area2D
		if area:
			area.body_entered.connect(_on_catch_area_entered.bind(p))

func _wire_spectate_buttons() -> void:
	var prev_btn := game_hud.get_node("SpectateBar/PrevBtn") as Button
	var next_btn := game_hud.get_node("SpectateBar/NextBtn") as Button
	prev_btn.pressed.connect(_cycle_spectate.bind(-1))
	next_btn.pressed.connect(_cycle_spectate.bind(1))

func _on_catch_area_entered(body: Node2D, catcher: Player) -> void:
	if not catcher.is_sokyroteke:
		return
	var target := body as Player
	if target == null:
		return
	match_mgr.on_player_touches_sokyroteke(target)

func _spawn_human_player() -> void:
	var player_scene := load("res://scenes/entities/player.tscn") as PackedScene
	var p := player_scene.instantiate() as Player
	p.player_index = 0
	p.is_bot = false
	p.global_position = map.get_safe_spawn()
	_players_container.add_child(p)
	_players.append(p)
	p.set_display_name(_player_display_name(p))

	if camera:
		camera.set_target(p)
	game_hud.player = p
	_touch_controls.player = p
	p.runner_sprint_changed.connect(func(time_left: float, uses_left: int) -> void:
		if not p.is_sokyroteke:
			game_hud.update_runner_sprint(time_left, uses_left))

func _spawn_bot(idx: int, profile_id: String = "") -> void:
	var player_scene := load("res://scenes/entities/player.tscn") as PackedScene
	var p := player_scene.instantiate() as Player
	p.player_index = idx + 1
	p.is_bot = true
	p.bot_name = BOT_NAMES[idx % BOT_NAMES.size()]
	p.global_position = map.get_safe_spawn()

	var ctrl := p.get_node("PlayerController") as PlayerController
	if ctrl:
		ctrl.enabled = false

	var profile := AssetRegistry.get_bot_profile(profile_id)
	if profile == null:
		profile = AssetRegistry.get_random_bot_profile()
	if profile == null:
		profile = BotProfile.new()
		profile.profile_id = "bot_medium"

	var bot_agent := BotAgent.new()
	bot_agent.name = "BotAgent"
	p.add_child(bot_agent)
	bot_agent.setup(profile, match_mgr, map)
	bot_agent.set_owner(p)

	_players_container.add_child(p)
	p.apply_outfit_profile(idx)
	_players.append(p)
	_bots.append(p)
	p.set_display_name(_player_display_name(p))

func _on_sokyroteke_assigned(player: Player) -> void:
	if player.is_bot:
		vision.set_active(false)
		game_hud.show_message(tr("«%s» — Соқыртеке! Қашыңыз!") % player.bot_name, 3.0)
	else:
		vision.set_active(true)
		vision.set_target_position(player.global_position)
		game_hud.show_message(tr("Сіз — Соқыртеке! Қуып ұстаңыз!"), 3.0)

func _on_quiz_triggered(catcher: Player, target: Player, item: ClothingItem) -> void:
	if catcher.is_bot:
		if target.is_bot:
			return
		var name_str := item.get_name_for_lang(GameSettings.get_lang_code())
		game_hud.show_message(tr("Сізді ұстады! Киім: %s") % name_str, 2.5)
	else:
		quiz_hud.show_quiz(item, match_mgr.mode.quiz_answer_time)

func _on_quiz_resolved(catcher: Player, target: Player, correct: bool) -> void:
	if catcher == match_mgr.human_player or target == match_mgr.human_player:
		game_audio.play_quiz_result(correct)
	if target.is_bot or catcher.is_bot == false:
		return
	if correct:
		game_hud.show_message(tr("«%s» дұрыс тапты — сіз ұсталдыныз!") % catcher.bot_name, 3.0)
	else:
		game_hud.show_message(tr("«%s» қателесті — қашып кеттіңіз!") % catcher.bot_name, 3.0)

func _on_quiz_answer(correct: bool) -> void:
	if correct and match_mgr.sokyroteke == match_mgr.human_player:
		_correct_answers += 1
	match_mgr.submit_quiz_answer(correct)

func _on_round_started() -> void:
	game_hud.update_round(1, 1)

func _on_round_ended(winner: String) -> void:
	if winner == "sokyroteke":
		game_hud.show_message(tr("СОҚЫРТЕКЕ ҰТТЫ! Барлығы ұсталды!"), 3.0)
	else:
		game_hud.show_message(tr("ҚАШУШЫЛАР ҰТТЫ! Уақыт бітті!"), 3.0)

func _on_player_caught(_catcher: Player, target: Player) -> void:
	game_audio.play_catch()
	if not target.is_bot:
		game_hud.show_message(tr("Сізді ұстады!"), 2.0)
		if GameSettings.screen_shake_enabled:
			camera.add_shake(4.0)

func _on_player_eliminated(player: Player) -> void:
	_spawn_pop(player.global_position, Color(1, 0.9, 0.4))
	if player.is_bot:
		game_hud.show_message(tr("«%s» ұсталды!") % player.bot_name, 2.5)
		if match_mgr.sokyroteke == match_mgr.human_player:
			game_hud.set_objective(tr("МАҚСАТ: %d/%d ҚАШУШЫ ҰСТАЛДЫ") % [match_mgr.eliminated_count, match_mgr.runners_total])
	else:
		game_audio.play_defeat()
		if GameSettings.screen_shake_enabled:
			camera.add_shake(6.0)
		_flash(Color(0.6, 0.05, 0.05), 0.32)
		game_hud.show_caught_choice()

func _on_item_unlocked(item: ClothingItem) -> void:
	var lang := GameSettings.get_lang_code()
	var name_str := item.get_name_for_lang(lang)
	game_hud.show_message(tr("Ашылды: %s!") % name_str, 3.0)

func _on_match_ended(results: Dictionary) -> void:
	var winner: String = results.get("winner", "players")
	var human_won := match_mgr.human_player.is_alive() and (
		(winner == "sokyroteke" and match_mgr.sokyroteke == match_mgr.human_player)
		or (winner == "players" and match_mgr.sokyroteke != match_mgr.human_player)
	)
	results["human_won"] = human_won
	results["correct_answers"] = _correct_answers
	results["career"] = SaveManager.record_match(human_won, _correct_answers)
	if winner == "sokyroteke":
		game_hud.show_message(tr("ЖЕҢІС: Соқыртеке!"), 2.0)
	else:
		game_hud.show_message(tr("ЖЕҢІС: Қашушылар!"), 2.0)
	if human_won:
		game_audio.play_victory()
	else:
		game_audio.play_defeat()
	await get_tree().create_timer(2.0).timeout
	SceneRouter.go_to_results(results)

func _setup_match_features() -> void:
	if _selected_role == "runner":
		game_hud.set_objective(tr("МАҚСАТ: УАҚЫТ АЯҚТАЛҒАНША АМАН ҚАЛ"))
		game_hud.update_runner_sprint(0.0, _players[0].runner_sprint_uses)
	else:
		game_hud.set_objective(tr("МАҚСАТ: БАРЛЫҚ ҚАШУШЫНЫ ҰСТА"))
		game_hud.update_sokyroteke_echo(0.0, _echo_uses)

func _update_match_features(delta: float) -> void:
	if match_mgr.current_state != MatchManager.MatchState.PLAYING:
		return
	if _selected_role == "sokyroteke":
		if _echo_time > 0.0:
			_echo_time = maxf(0.0, _echo_time - delta)
			game_hud.update_sokyroteke_echo(_echo_time, _echo_uses)
		_event_wait -= delta
		if _fog_time > 0.0:
			_fog_time = maxf(0.0, _fog_time - delta)
		elif _event_wait <= 0.0:
			_fog_time = 6.0
			_event_wait = 22.0
			game_audio.play_fog()
			game_hud.show_message(tr("ТҰМАН ТҮСТІ: КӨРІНІС АЗАЙДЫ"), 2.0)
		vision.radius = 65.0 if _fog_time > 0.0 else (180.0 if _echo_time > 0.0 else 100.0)
	else:
		game_hud.set_objective(tr("МАҚСАТ: %.0f СЕКУНД АМАН ҚАЛ") % maxf(0.0, match_mgr.round_timer))
		game_hud.update_runner_sprint(_players[0].runner_sprint_time, _players[0].runner_sprint_uses)

func _activate_echo() -> void:
	if _selected_role != "sokyroteke" or _echo_uses <= 0 or _echo_time > 0.0:
		return
	_echo_uses -= 1
	_echo_time = 3.0
	game_audio.play_echo()
	game_hud.show_message(tr("ҮН ТЫҢДАУ ІСКЕ ҚОСЫЛДЫ"), 1.5)

func _start_spectate() -> void:
	_spectating = true
	_spectate_index = 0
	game_hud.hide_defeat()
	game_hud.show_spectate_bar()
	_cycle_spectate(0)

func _spectate_targets() -> Array[Player]:
	var out: Array[Player] = []
	for p in _players:
		if p.is_alive():
			out.append(p)
	return out

func _cycle_spectate(dir: int) -> void:
	var targets := _spectate_targets()
	if targets.is_empty():
		return
	_spectate_index = posmod(_spectate_index + dir, targets.size())
	camera.set_target(targets[_spectate_index])

func _unhandled_input(event: InputEvent) -> void:
	if not _spectating and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_activate_echo()
		return
	if not _spectating:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB, KEY_RIGHT: _cycle_spectate(1)
			KEY_Q, KEY_LEFT: _cycle_spectate(-1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_spectate_target(event.global_position)

func _pick_spectate_target(screen_pos: Vector2) -> void:
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var best: Player = null
	var best_d := 70.0
	for p in _players:
		if not p.is_alive():
			continue
		var d := p.global_position.distance_to(world)
		if d < best_d:
			best_d = d
			best = p
	if best:
		camera.set_target(best)

func _player_display_name(p: Player) -> String:
	return SaveManager.nickname if p.is_bot == false else p.bot_name

func _spawn_pop(pos: Vector2, col: Color) -> void:
	var parts := CPUParticles2D.new()
	parts.position = pos
	parts.amount = 18
	parts.lifetime = 0.6
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.direction = Vector2.UP
	parts.spread = 180.0
	parts.gravity = Vector2(0, 200)
	parts.initial_velocity_min = 80.0
	parts.initial_velocity_max = 200.0
	parts.scale_amount_min = 2.0
	parts.scale_amount_max = 4.0
	parts.color = col
	_players_container.add_child(parts)
	parts.emitting = true
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(parts.queue_free)

func _spawn_zone_puff(pos: Vector2, col: Color, amount := 14) -> void:
	var parts := CPUParticles2D.new()
	parts.position = pos
	parts.amount = amount
	parts.lifetime = 0.9
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.direction = Vector2(0, -1)
	parts.spread = 120.0
	parts.gravity = Vector2(0, -60)
	parts.initial_velocity_min = 40.0
	parts.initial_velocity_max = 120.0
	parts.scale_amount_min = 1.6
	parts.scale_amount_max = 3.2
	parts.color = col
	_players_container.add_child(parts)
	parts.emitting = true
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(parts.queue_free)

func _flash(col: Color, strength: float) -> void:
	var rect := ColorRect.new()
	rect.color = col
	rect.color.a = strength
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer: CanvasLayer = $CanvasLayer
	layer.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.35)
	tw.tween_callback(rect.queue_free)

func _process(_delta: float) -> void:
	if match_mgr:
		_update_match_features(_delta)
	if match_mgr and match_mgr.sokyroteke:
		var human_is_sokyroteke := match_mgr.sokyroteke == match_mgr.human_player
		var fp_radius := FootprintSystem.SIGHT_RADIUS
		if human_is_sokyroteke and _fog_time > 0.0:
			fp_radius = 65.0
		match_mgr.sokyroteke.set_footprint_boost(footprint_system.has_visible_print(match_mgr.sokyroteke.global_position, fp_radius))
		if human_is_sokyroteke:
			vision.set_target_position(match_mgr.sokyroteke.global_position)
			var center := match_mgr.sokyroteke.global_position
			var light := vision.radius
			for p in _players:
				if p == match_mgr.sokyroteke:
					p.visible = true
				else:
					var revealed: bool = float(_yurt_reveal.get(p.player_index, 0.0)) > 0.0
					p.visible = p.is_alive() and (revealed or (not map.is_inside_yurt(p.global_position) and center.distance_to(p.global_position) <= light * p.get_visibility_multiplier()))
				# Соқыртеке не должен читать ники — иначе бегунов можно узнать без квиза по одежде.
				p.set_name_label_visible(false)
		else:
			for p in _players:
				p.visible = p.is_alive()
				p.set_name_label_visible(p.visible)
		game_hud.update_timer(match_mgr.round_timer)

		var alive_runners := 0
		for p in _players:
			if p.is_alive() and p != match_mgr.sokyroteke:
				alive_runners += 1
		game_hud.update_remaining(alive_runners, match_mgr.runners_total)

	for p in _players:
		if not p.is_alive():
			_yurt_time.erase(p.player_index)
			_yurt_reveal.erase(p.player_index)
			continue
		p.global_position = map.clamp_to_bounds(p.global_position, 20.0)
		p.set_water_override(map.is_water(p.global_position))
		var in_yurt := map.is_inside_yurt(p.global_position)
		if in_yurt:
			var spent := float(_yurt_time.get(p.player_index, 0.0)) + _delta
			_yurt_time[p.player_index] = spent
			var remaining := float(_yurt_reveal.get(p.player_index, 0.0))
			if remaining <= 0.0 and spent >= YURT_REVEAL_DELAY and p != match_mgr.sokyroteke:
				_yurt_reveal[p.player_index] = YURT_REVEAL_DURATION
				if match_mgr.sokyroteke == match_mgr.human_player:
					game_hud.show_message(tr("«%s» юртада ұзақ — орны ашылды!") % _player_display_name(p), 2.5)
		else:
			_yurt_time[p.player_index] = 0.0
		var reveal := float(_yurt_reveal.get(p.player_index, 0.0))
		if reveal > 0.0:
			reveal -= _delta
			if reveal <= 0.0:
				reveal = 0.0
			_yurt_reveal[p.player_index] = reveal

	if match_mgr and match_mgr.human_player:
		var human := match_mgr.human_player
		if human.is_alive():
			var in_water := map.is_water(human.global_position)
			var in_yurt := map.is_inside_yurt(human.global_position)
			if in_water and not _prev_human_water:
				_spawn_zone_puff(human.global_position, Color(0.35, 0.6, 0.9, 0.7), 20)
				game_audio.start_zone_loop("splash")
			if not in_water and _prev_human_water:
				game_audio.stop_zone_loop("splash")
			if in_yurt and not _prev_human_yurt:
				_spawn_zone_puff(human.global_position, Color(0.8, 0.62, 0.4, 0.85), 16)
				game_audio.start_zone_loop("yurt")
			if not in_yurt and _prev_human_yurt:
				game_audio.stop_zone_loop("yurt")
			_prev_human_water = in_water
			_prev_human_yurt = in_yurt
		else:
			game_audio.stop_all_zone_loops()
			_prev_human_water = false
			_prev_human_yurt = false
		if human.is_sokyroteke and human.is_slowed():
			game_hud.update_slow(human.slow_timer)
		elif not human.is_slowed():
			game_hud.hide_slow()

	if Input.is_action_just_pressed("ui_cancel"):
		SceneRouter.go_to_main_menu()
