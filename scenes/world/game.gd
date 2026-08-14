extends Node2D

const BOT_NAMES := ["Айгүл", "Батыр", "Дәулет", "Аружан", "Нұрлан", "Жанар"]

var match_mgr: MatchManager
var map: MapManager
var vision: VisionSystem
var sound_system: SoundWaveSystem
var quiz_hud: QuizHUD
var game_hud: GameHUD
var camera: GameCamera

var _players: Array[Player] = []
var _bots: Array[Node] = []
var _spectating: bool = false
var _spectate_index: int = 0

@onready var _players_container: Node2D = $Players
@onready var _systems: Node2D = $Systems
@onready var _touch_controls = $TouchControls

func _ready() -> void:
	var game_data := SceneRouter.get_pending_game_data()
	var bot_count: int = game_data.get("bots", 5)

	match_mgr = _systems.get_node("MatchManager")
	map = $Map as MapManager
	vision = _systems.get_node("VisionSystem")
	sound_system = _systems.get_node("SoundWaveSystem")
	quiz_hud = $CanvasLayer/QuizHUD
	game_hud = $CanvasLayer/GameHUD
	camera = $Camera

	_spawn_human_player()

	var profiles: Array[String] = ["bot_easy", "bot_medium", "bot_hard"]
	for i in bot_count:
		var profile_id: String = profiles[min(i, profiles.size() - 1)]
		_spawn_bot(i, profile_id)

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

	match_mgr.setup_match(map, _players)
	match_mgr.start_match()

func _wire_sound_for_players() -> void:
	for p in _players:
		p.stepped.connect(func(radius: float):
			sound_system.emit_noise(p, radius)
		)

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

	if camera:
		camera.set_target(p)
	game_hud.player = p
	_touch_controls.player = p

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
	p.apply_random_outfit()
	_players.append(p)
	_bots.append(p)

func _on_sokyroteke_assigned(player: Player) -> void:
	if player.is_bot:
		vision.set_active(false)
		game_hud.show_message("«%s» — Соқыртеке! Қашыңыз!" % player.bot_name, 3.0)
	else:
		vision.set_active(true)
		vision.set_target_position(player.global_position)
		game_hud.show_message("Сіз — Соқыртеке! Қуып ұстаңыз!", 3.0)

func _on_quiz_triggered(catcher: Player, target: Player, item: ClothingItem) -> void:
	if catcher.is_bot:
		if target.is_bot:
			return
		var name_str := item.get_name_for_lang(GameSettings.get_lang_code())
		game_hud.show_message("Сізді ұстады! Киім: %s" % name_str, 2.5)
	else:
		quiz_hud.show_quiz(item, match_mgr.mode.quiz_answer_time)

func _on_quiz_resolved(catcher: Player, target: Player, correct: bool) -> void:
	if target.is_bot or catcher.is_bot == false:
		return
	if correct:
		game_hud.show_message("«%s» угадал — вы выбыли!" % catcher.bot_name, 3.0)
	else:
		game_hud.show_message("«%s» ошибся — вы убежали!" % catcher.bot_name, 3.0)

func _on_quiz_answer(correct: bool) -> void:
	match_mgr.submit_quiz_answer(correct)

func _on_round_started() -> void:
	game_hud.update_round(1, 1)

func _on_round_ended(winner: String) -> void:
	if winner == "sokyroteke":
		game_hud.show_message("СОҚЫРТЕКЕ ҰТТЫ! Барлығы ұсталды!", 3.0)
	else:
		game_hud.show_message("ҚАШҚЫНДАР ҰТТЫ! Уақыт бітті!", 3.0)

func _on_player_caught(_catcher: Player, target: Player) -> void:
	if not target.is_bot:
		game_hud.show_message("Сізді ұстады!", 2.0)

func _on_player_eliminated(player: Player) -> void:
	_spawn_pop(player.global_position, Color(1, 0.9, 0.4))
	if player.is_bot:
		game_hud.show_message("«%s» пойман!" % player.bot_name, 2.5)
	else:
		_start_spectate()

func _on_item_unlocked(item: ClothingItem) -> void:
	var lang := GameSettings.get_lang_code()
	var name_str := item.get_name_for_lang(lang)
	game_hud.show_message("Ашылды: %s!" % name_str, 3.0)

func _on_match_ended(results: Dictionary) -> void:
	var winner: String = results.get("winner", "players")
	if winner == "sokyroteke":
		game_hud.show_message("ПОБЕДА: Соқыртеке!", 5.0)
	else:
		game_hud.show_message("ПОБЕДА: Қашқындар!", 5.0)
	await get_tree().create_timer(5.0).timeout
	SceneRouter.go_to_main_menu()

func _start_spectate() -> void:
	_spectating = true
	_spectate_index = 0
	game_hud.show_defeat()
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

func _process(_delta: float) -> void:
	if match_mgr and match_mgr.sokyroteke:
		if match_mgr.sokyroteke == match_mgr.human_player:
			vision.set_target_position(match_mgr.sokyroteke.global_position)
			var center := match_mgr.sokyroteke.global_position
			var light := vision.radius
			for p in _players:
				if p == match_mgr.sokyroteke:
					p.visible = true
				else:
					p.visible = p.is_alive() and center.distance_to(p.global_position) <= light
		else:
			for p in _players:
				p.visible = p.is_alive()
		game_hud.update_timer(match_mgr.round_timer)

		var alive_runners := 0
		for p in _players:
			if p.is_alive() and p != match_mgr.sokyroteke:
				alive_runners += 1
		game_hud.update_remaining(alive_runners, match_mgr.runners_total)

	for p in _players:
		if not p.is_alive():
			continue
		p.global_position = map.clamp_to_bounds(p.global_position, 20.0)
		p.set_water_override(map.is_water(p.global_position))

	if match_mgr and match_mgr.human_player:
		var human := match_mgr.human_player
		if human.is_sokyroteke and human.is_slowed():
			game_hud.update_slow(human.slow_timer)
		elif not human.is_slowed():
			game_hud.hide_slow()

	if Input.is_action_just_pressed("ui_cancel"):
		SceneRouter.go_to_main_menu()
