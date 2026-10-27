extends Node2D
## «Ақ сүйек» на карте (Aq_suiek_mode_spec.md): две команды по трое ищут ақ сүйек
## в ночном ауле, нашедший несёт его в свою көмбе. Правила — AqSuyekMatch, куда
## бежать ботам — AqSuyekBrain; здесь игроки, свет вокруг игрока, окна и звук.
##
## Раунд: вопрос о традициях (верно — команда видит, куда упал сүйек) → бросок
## и обратный отсчёт → игра до доставки или конца времени → итог раунда.

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const BONE := preload("res://assets/sprites/aq_suyek/bone.png")
const BASE_ART: Array[Texture2D] = [
	preload("res://assets/sprites/aq_suyek/otau_human.png"),
	preload("res://assets/sprites/aq_suyek/otau_bot.png"),
]
const TEAM_COLORS: Array[Color] = [UiTokens.RUNNER, UiTokens.SEEKER]
const TEAM_NAMES: Array[String] = ["КӨК ТОП", "ҚЫЗЫЛ ТОП"]
const BLUE := AqSuyekMatch.Team.BLUE
const RED := AqSuyekMatch.Team.RED
const SEEKER := AqSuyekMatch.Role.SEEKER
const DEFENDER := AqSuyekMatch.Role.DEFENDER
## Игрок — id 0 в Көк топ; 1–2 — его союзники, 3–5 — Қызыл топ.
const HUMAN := 0
const TEAM_SIZE := 3

## Ночь: ясно видно только вокруг своего игрока, дальше — тьма в шахматку.
const DARKNESS := 0.85
## Пока идёт отсчёт, все стоят у своих көмбе.
const HEADSTART := 3.0
const THROW_TIME := 1.0
## Сколько светится место падения, если команда верно ответила на вопрос.
const REVEAL_TIME := 4.0
const ROUND_PAUSE := 3.0
## Көмбе — у левого и правого края карты; сүйек падает не ближе этого к ним.
const BASE_INSET := 130.0
const BONE_MIN_FROM_BASE := 380.0
## Бот, который ищет, идёт к случайной точке; новая — по приходу или по времени.
const ROAM_REACHED := 40.0
const ROAM_TIMEOUT := 7.0
## Когда бот включает рывок: несущий — если соперник ближе, догоняющий — если
## до несущего уже рукой подать.
const SPRINT_DANGER := 140.0
const SPRINT_CHASE := 160.0
## Сүйек над головой несущего: виден всем и сквозь темноту.
const CARRIER_MARK_OFFSET := Vector2(0, -78)
## Отау-көмбе нарисован в левой части холста 72×72: низ середины — (22, 64),
## верх — на OTAU_TOP пикселей выше низа.
const OTAU_FOOT := Vector2(22, 64)
const OTAU_TOP := 46
const OTAU_SCALE := 2

enum Phase { SETUP, QUESTION, THROW, PLAYING, ROUND_END, OVER }

var _match: AqSuyekMatch
var _phase := Phase.SETUP
var _human_role := SEEKER
var _players: Array[Player] = []
var _bases: Array[Vector2] = []
var _knows: Array[bool] = [false, false]
var _roam: Array[Vector2] = []
var _roam_time: Array[float] = []
var _questions: Array[CultureQuestion] = []
var _question_at := 0
var _audio: GameAudio
var _pause: PauseMenu
var _panel_layer: CanvasLayer
var _panel: Control
var _carrier_mark: Sprite2D
var _reveal: PixelRing
var _role_cards: Dictionary = {}

@onready var _map: MapManager = $Map
@onready var _bone: Sprite2D = $Bone
@onready var _players_node: Node2D = $Players
@onready var _vision: VisionSystem = $VisionSystem
@onready var _glow: CanvasLayer = $Glow
@onready var _camera: GameCamera = $Camera
@onready var _hud: GameHUD = $GameHUD
@onready var _touch: TouchControls = $TouchControls


func _ready() -> void:
	_audio = GameAudio.new()
	add_child(_audio)
	_add_pause_menu()
	_hud.pause_requested.connect(_open_pause)
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 30
	add_child(_panel_layer)

	_place_bases()
	_spawn_players()
	_build_glow()
	_vision.radius = AqSuyekBrain.SIGHT
	_vision.darkness = DARKNESS
	_vision.set_active(true)
	_camera.set_target(_players[HUMAN])
	_touch.player = _players[HUMAN]
	_touch.set_sprint_mode(true)
	_hud.update_timer(AqSuyekMatch.ROUND_TIME)
	_hud.show_score(0, 0)
	_hud.update_runner_sprint(0.0, _players[HUMAN].runner_sprint_uses)
	_show_setup()


# --- Мир --------------------------------------------------------------------

func _place_bases() -> void:
	var field := _map.bounds
	_bases = [
		_clear_spot_near(Vector2(field.position.x + BASE_INSET, 0)),
		_clear_spot_near(Vector2(field.end.x - BASE_INSET, 0)),
	]

## Ближайшая к spot свободная точка на той же вертикали: көмбе не должна
## встать в пруд, в юрту или на камень.
func _clear_spot_near(spot: Vector2) -> Vector2:
	for i in 40:
		var shift := ceilf(i / 2.0) * 24.0 * (1.0 if i % 2 == 0 else -1.0)
		var point := spot + Vector2(0, shift)
		if _is_clear(point, 80.0):
			return point
	return spot

func _is_clear(point: Vector2, radius: float) -> bool:
	if not _map.bounds.grow(-40.0).has_point(point):
		return false
	for yurt in _map.yurt_positions:
		if point.distance_to(yurt) < MapManager.YURT_BLOCK_RADIUS + radius * 0.5:
			return false
	for obstacle in _map.obstacle_positions:
		if point.distance_to(obstacle) < MapManager.ROCK_CLEAR + radius:
			return false
	for zone in _map.water_zones:
		if point.distance_to(zone["pos"]) < float(zone["radius"]) + radius * 0.5:
			return false
	return true

## Куда упадёт сүйек: свободное место подальше от обеих көмбе.
func _bone_spot() -> Vector2:
	var field := _map.bounds.grow(-100.0)
	for i in 200:
		var point := Vector2(randf_range(field.position.x, field.end.x), randf_range(field.position.y, field.end.y))
		if point.distance_to(_bases[BLUE]) >= BONE_MIN_FROM_BASE and point.distance_to(_bases[RED]) >= BONE_MIN_FROM_BASE \
				and _is_clear(point, 24.0):
			return point
	return MapManager.ARENA_CENTER

func _random_field_spot() -> Vector2:
	var field := _map.bounds.grow(-80.0)
	return Vector2(randf_range(field.position.x, field.end.x), randf_range(field.position.y, field.end.y))

func _spawn_players() -> void:
	for id in TEAM_SIZE * 2:
		var team := _team_of(id)
		var p := PLAYER_SCENE.instantiate() as Player
		p.player_index = id
		p.is_bot = id != HUMAN
		if p.is_bot:
			p.bot_name = Player.bot_name_for(id - 1)
			(p.get_node("PlayerController") as PlayerController).enabled = false
		_players_node.add_child(p)
		if p.is_bot:
			p.apply_outfit_profile(id - 1)
		p.set_display_name(_display_name(id))
		p.set_name_label_visible(true)
		(p.get_node("NameLabel") as Label).add_theme_color_override("font_color", TEAM_COLORS[team])
		# Кольцо в цвете команды под ногами, над тенью и под фигурой.
		var ring := PixelRing.new(TEAM_COLORS[team], Vector2(14, 6))
		p.add_child(ring)
		p.move_child(ring, p.get_node("Shadow").get_index() + 1)
		p.stepped.connect(_on_stepped.bind(p))
		_players.append(p)
		_roam.append(Vector2.ZERO)
		_roam_time.append(0.0)
	_line_up()

func _team_of(id: int) -> int:
	return BLUE if id < TEAM_SIZE else RED

func _display_name(id: int) -> String:
	if id != HUMAN:
		return _players[id].bot_name if id < _players.size() else Player.bot_name_for(id - 1)
	return SaveManager.nickname if not SaveManager.nickname.is_empty() else tr("Сіз")

## Все — у своих көмбе, лицом к середине поля, без рывков и остановок.
func _line_up() -> void:
	for id in _players.size():
		var team := _team_of(id)
		var slot := id % TEAM_SIZE
		var inward := 1.0 if team == BLUE else -1.0
		var p := _players[id]
		p.revive()
		p.global_position = _bases[team] + Vector2(inward * 50.0, -70.0 + slot * 70.0)
		p.get_controller().set_remote_input(Vector2.ZERO, false)
		p.set_frozen(true)
		p.speed_mult = 1.0

## Над темнотой: көмбе обеих команд, кольца зон доставки, сүйек над несущим
## и свечение места падения.
func _build_glow() -> void:
	for team in [BLUE, RED]:
		var zone := PixelRing.new(TEAM_COLORS[team], Vector2.ONE * AqSuyekMatch.BASE_RADIUS)
		zone.position = _bases[team]
		_glow.add_child(zone)
		var otau := Sprite2D.new()
		otau.texture = BASE_ART[team]
		otau.centered = false
		otau.scale = Vector2.ONE * OTAU_SCALE
		otau.position = _bases[team] - OTAU_FOOT * OTAU_SCALE
		_glow.add_child(otau)
	var mine := Label.new()
	mine.text = tr("СІЗДІҢ КӨМБЕҢІЗ")
	mine.theme_type_variation = "CaptionLabel"
	mine.add_theme_color_override("font_color", TEAM_COLORS[BLUE])
	mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mine.custom_minimum_size = Vector2(240, 0)
	# Над отау: под ним стоит команда со своими подписями.
	mine.position = _bases[BLUE] + Vector2(-120, -OTAU_TOP * OTAU_SCALE - 30)
	_glow.add_child(mine)

	_carrier_mark = Sprite2D.new()
	_carrier_mark.texture = BONE
	_carrier_mark.visible = false
	_glow.add_child(_carrier_mark)
	_reveal = PixelRing.new(UiTokens.GOLD_LIGHT, Vector2(30, 16))
	_reveal.visible = false
	_glow.add_child(_reveal)


# --- Партия -----------------------------------------------------------------

func _start_match() -> void:
	_match = AqSuyekMatch.new()
	# В каждой команде два іздеуші и один қорғаушы; игрок берёт выбранную роль.
	var blue_roles: Array[int] = [_human_role, SEEKER, DEFENDER if _human_role == SEEKER else SEEKER]
	var red_roles: Array[int] = [SEEKER, SEEKER, DEFENDER]
	for role in blue_roles:
		_match.add_player(BLUE, role)
	for role in red_roles:
		_match.add_player(RED, role)
	_match.bases = _bases.duplicate()
	_questions = AssetRegistry.get_shuffled_questions()
	_question_at = 0
	_hud.show_score(0, 0)
	Telemetry.log_event("aq_suyek_start", {"role": "seeker" if _human_role == SEEKER else "defender"})
	_next_round()

func _next_round() -> void:
	_phase = Phase.QUESTION
	_line_up()
	_bone.visible = false
	_carrier_mark.visible = false
	_reveal.visible = false
	_hud.update_timer(AqSuyekMatch.ROUND_TIME)
	_ask_question()

func _throw() -> void:
	_close_panel()
	_phase = Phase.THROW
	var spot := _bone_spot()
	_match.start_round(spot)
	_bone.global_position = spot
	if _knows[BLUE]:
		# Команда видит бросок: сүйек летит над темнотой и место падения светится.
		var flying := Sprite2D.new()
		flying.texture = BONE
		flying.position = MapManager.ARENA_CENTER
		_glow.add_child(flying)
		var fly := func(t: float) -> void:
			flying.position = MapManager.ARENA_CENTER.lerp(spot, t) + Vector2(0, -160.0 * sin(PI * t))
		var tween := flying.create_tween()
		tween.tween_method(fly, 0.0, 1.0, THROW_TIME)
		tween.tween_callback(flying.queue_free)
		tween.tween_callback(_show_reveal.bind(spot))
	else:
		_bone.visible = true
		_hud.show_message(tr("Сүйек қараңғыға лақтырылды"), 2.5)
	var seeker := _human_role == SEEKER
	_hud.show_role(
		tr("СІЗ ІЗДЕУШІСІЗ!") if seeker else tr("СІЗ ҚОРҒАУШЫСЫЗ!"),
		tr("Сүйекті тауып, көмбеңізге жеткізіңіз") if seeker else tr("Қарсыласты ұстап, тоқтатыңыз"),
		tr("МАҚСАТ: СҮЙЕКТІ КӨМБЕГЕ ЖЕТКІЗ") if seeker else tr("МАҚСАТ: ҚАРСЫЛАСТЫ ТОҚТАТ"),
		HEADSTART)
	_hud.start_countdown(HEADSTART)
	await get_tree().create_timer(HEADSTART, false).timeout
	if not is_inside_tree() or _phase != Phase.THROW:
		return
	_phase = Phase.PLAYING
	for p in _players:
		p.set_frozen(false)

func _show_reveal(spot: Vector2) -> void:
	_bone.visible = true
	_reveal.position = spot
	_reveal.visible = true
	_hud.show_message(tr("Сүйек осында түсті!"), 2.0)
	var tween := _reveal.create_tween()
	for i in int(REVEAL_TIME / 0.5):
		tween.tween_callback(func() -> void: _reveal.visible = i % 2 == 0)
		tween.tween_interval(0.5)
	tween.tween_callback(func() -> void: _reveal.visible = false)

func _physics_process(delta: float) -> void:
	if _phase != Phase.PLAYING:
		return
	var positions := _positions()
	for event in _match.step(delta, positions):
		_on_event(event)
	if _phase != Phase.PLAYING:
		return
	for id in _players.size():
		_players[id].set_frozen(_match.is_stunned(id))
		_players[id].speed_mult = AqSuyekMatch.CARRY_SPEED if _match.carrier == id else 1.0
	_steer_bots(delta, positions)

func _positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in _players:
		out.append(p.global_position)
	return out

func _steer_bots(delta: float, positions: Array[Vector2]) -> void:
	for team in [BLUE, RED]:
		if not _knows[team]:
			_knows[team] = _match.carrier >= 0 or AqSuyekBrain.sees(team, _match, positions)
	for id in range(1, _players.size()):
		_roam_time[id] -= delta
		if positions[id].distance_to(_roam[id]) < ROAM_REACHED or _roam_time[id] <= 0.0:
			_roam[id] = _random_field_spot()
			_roam_time[id] = ROAM_TIMEOUT
		var target := AqSuyekBrain.target(id, _match, positions, _knows[_match.teams[id]], _roam[id])
		var to_target := target - positions[id]
		var direction := Vector2.ZERO
		if to_target.length() > 6.0:
			direction = BotAgent.steer_around(_map, positions[id], to_target.normalized()).normalized()
		_players[id].get_controller().set_remote_input(direction, _wants_sprint(id, positions))

func _wants_sprint(id: int, positions: Array[Vector2]) -> bool:
	var carrier := _match.carrier
	if carrier < 0:
		return false
	if carrier == id:
		for other in _players.size():
			if _match.teams[other] != _match.teams[id] and positions[other].distance_to(positions[id]) < SPRINT_DANGER:
				return true
		return false
	return _match.teams[carrier] != _match.teams[id] and positions[carrier].distance_to(positions[id]) < SPRINT_CHASE

func _on_event(event: Dictionary) -> void:
	match event["type"]:
		"picked", "stolen":
			var id: int = event["player"]
			if event["type"] == "stolen":
				_audio.play_catch()
			else:
				_audio.play_card_tone(3)
			if id == HUMAN:
				_hud.show_message(tr("Сүйек сізде! Көмбеге жүгіріңіз!"), 2.5)
			elif event["type"] == "picked":
				_hud.show_message(tr("«%s» сүйекті тапты!") % _display_name(id), 2.5)
			else:
				_hud.show_message(tr("«%s» сүйекті тартып алды!") % _display_name(id), 2.5)
		"stunned":
			var actor: int = event["player"]
			var target: int = event["target"]
			_players[target].apply_shield(AqSuyekMatch.STUN_TIME)
			_audio.play_catch()
			if target == HUMAN:
				_hud.show_message(tr("Сізді тоқтатты!"), 2.0)
				if GameSettings.screen_shake_enabled:
					_camera.add_shake(4.0)
			elif bool(event["dropped"]):
				_hud.show_message(tr("Сүйек жерге түсті!"), 2.0)
			elif actor == HUMAN:
				_hud.show_message(tr("«%s» тоқтатылды!") % _display_name(target), 2.0)
		"round_over":
			_finish_round(event)

func _finish_round(event: Dictionary) -> void:
	_phase = Phase.ROUND_END
	for p in _players:
		p.set_frozen(true)
		p.speed_mult = 1.0
		p.get_controller().set_remote_input(Vector2.ZERO, false)
	_hud.show_score(_match.scores[BLUE], _match.scores[RED])
	_hud.update_timer(_match.time_left)
	var team: int = event["team"]
	if team < 0:
		_hud.show_result(tr("УАҚЫТ БІТТІ"))
		_hud.show_message(tr("Ешкім ұпай алмады"), 2.5)
	else:
		_hud.show_result(tr("%s ҰПАЙ АЛДЫ!") % tr(TEAM_NAMES[team]))
		_audio.play_quiz_result(team == BLUE)
	await get_tree().create_timer(ROUND_PAUSE, false).timeout
	if not is_inside_tree():
		return
	if bool(event["finished"]):
		_show_end()
	else:
		_next_round()

func _on_stepped(_radius: float, p: Player) -> void:
	if p != _players[HUMAN]:
		return
	if _map.is_water(p.global_position):
		_audio.play_splash()
	else:
		_audio.play_footstep(p.runner_sprint_time > 0.0)

func _process(_delta: float) -> void:
	var human := _players[HUMAN]
	_vision.set_target_position(human.global_position + Player.BODY_CENTER)
	_map.update_roofs(human.global_position)
	for p in _players:
		p.global_position = _map.clamp_to_bounds(p.global_position, 20.0)
		p.set_water_override(_map.is_water(p.global_position))
	if _match == null:
		return
	var carried := _phase == Phase.PLAYING and _match.carrier >= 0
	_carrier_mark.visible = carried
	if carried:
		_bone.visible = false
		_carrier_mark.global_position = _players[_match.carrier].global_position + CARRIER_MARK_OFFSET
	elif _phase == Phase.PLAYING:
		_bone.visible = true
		_bone.global_position = _match.bone
	if _phase == Phase.PLAYING:
		_hud.update_timer(_match.time_left)
		_hud.update_runner_sprint(human.runner_sprint_time, human.runner_sprint_uses)


# --- Окна -------------------------------------------------------------------

func _show_setup() -> void:
	_phase = Phase.SETUP
	var box := _open_panel("SetupPanel")
	_label(tr("ДАЙЫНДЫҚ"), "CaptionLabel", box)
	_label(tr("АҚ СҮЙЕК"), "TitleLabel", box)
	_label(tr("Көк топ — сіз және екі бот. Қызыл топ — үш бот."), "", box)
	_label(tr("РОЛЬДІ ТАҢДА"), "HeadingLabel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_S)
	box.add_child(row)
	_role_cards = {}
	_role_cards[SEEKER] = _role_card(row, tr("ІЗДЕУШІ"),
		tr("Сүйекті тауып, өз көмбеңе жеткіз. Қарсыластан тартып алуға болады."), SEEKER)
	_role_cards[DEFENDER] = _role_card(row, tr("ҚОРҒАУШЫ"),
		tr("Сүйекті алып жүрмейді, бірақ қарсыласты ұстап, 2 секундқа тоқтатады."), DEFENDER)
	_select_role(_human_role)
	var start := _button(tr("БАСТАУ"), "ButtonLarge", box, _start_match)
	start.name = "StartBtn"
	start.ornate = true
	_button(tr("← Артқа"), "ButtonSecondary", box, SceneRouter.go_to_mode_select)

func _role_card(parent: Control, title: String, text: String, role: int) -> SelectableCard:
	var card := SelectableCard.new()
	card.name = "SeekerCard" if role == SEEKER else "DefenderCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(_select_role.bind(role))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	_label(title, "HeadingLabel", box).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(text, "", box).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card

func _select_role(role: int) -> void:
	_human_role = role
	for key: int in _role_cards:
		(_role_cards[key] as SelectableCard).selected = key == role

func _ask_question() -> void:
	if _questions.is_empty():
		# Без вопросов раунд всё равно должен начаться — сүйек просто падает в темноту.
		Telemetry.log_error("no CultureQuestion resources found", "aq_suyek")
		_knows = [false, AqSuyekBrain.answers_correctly()]
		_throw()
		return
	var question: CultureQuestion = _questions[_question_at % _questions.size()]
	_question_at += 1
	var box := _open_panel("QuestionPanel")
	_label(tr("%d-РАУНД") % (_match.round_index + 1), "CaptionLabel", box)
	_label(tr(question.question), "HeadingLabel", box)
	var options := VBoxContainer.new()
	options.name = "Options"
	box.add_child(options)
	var order: Array[int] = []
	for i in question.options.size():
		order.append(i)
	order.shuffle()
	for i in order:
		var answer := _button(tr(question.options[i]), "AnswerButton", options, Callable())
		answer.pressed.connect(_on_answer.bind(i == question.correct, question, box, options))

func _on_answer(correct: bool, question: CultureQuestion, box: VBoxContainer, options: VBoxContainer) -> void:
	if _phase != Phase.QUESTION or options.is_queued_for_deletion():
		return
	options.queue_free()
	_knows = [correct, AqSuyekBrain.answers_correctly()]
	_audio.play_quiz_result(correct)
	var verdict := _label(tr("Дұрыс! Тобыңыз сүйектің қайда түскенін көреді.") if correct
		else tr("Қате. Сүйек қараңғыға түседі — іздеуге тура келеді."), "HeadingLabel", box)
	verdict.add_theme_color_override("font_color", UiTokens.SUCCESS if correct else UiTokens.DANGER)
	_label(tr(question.fact), "", box)
	var throw := _button(tr("ЛАҚТЫР!"), "ButtonLarge", box, _throw)
	throw.name = "ThrowBtn"
	throw.ornate = true

func _show_end() -> void:
	_phase = Phase.OVER
	var winner := _match.winner_team
	var box := _open_panel("EndPanel")
	_label(tr("ЖЕҢІМПАЗ") if winner >= 0 else tr("ТЕҢ ТҮСТІ"), "CaptionLabel", box)
	var title := _label(tr(TEAM_NAMES[winner]) if winner >= 0 else tr("Тең ойын"), "TitleLabel", box)
	if winner >= 0:
		title.add_theme_color_override("font_color", TEAM_COLORS[winner])
		_label(tr("Сіздің тобыңыз жеңді!") if winner == BLUE else tr("Бұл жолы қарсылас мықты болды."), "", box)
	_label("%d : %d" % [_match.scores[BLUE], _match.scores[RED]], "TitleLabel", box)
	_button(tr("ҚАЙТА ОЙНАУ"), "ButtonLarge", box, _show_setup).name = "AgainBtn"
	_button(tr("БАС МӘЗІР"), "ButtonSecondary", box, SceneRouter.go_to_main_menu).name = "MenuBtn"
	if winner == BLUE:
		_audio.play_victory()
	elif winner == RED:
		_audio.play_defeat()
	Telemetry.log_event("aq_suyek_end", {
		"winner": winner,
		"score_blue": _match.scores[BLUE],
		"score_red": _match.scores[RED],
	})

## Окно по центру экрана поверх мира. Прежнее окно закрывается; плашка HUD
## прячется, пока окно открыто, — иначе окно наезжало бы на таймер.
func _open_panel(panel_name: String) -> VBoxContainer:
	_close_panel()
	_hud.visible = false
	_panel = Control.new()
	_panel.name = panel_name
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_layer.add_child(_panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	card.add_child(box)
	return box

func _close_panel() -> void:
	_hud.visible = true
	if _panel != null:
		_panel.queue_free()
		_panel = null

func _label(text: String, variation: String, parent: Control) -> Label:
	var label := Label.new()
	label.text = text
	if not variation.is_empty():
		label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _button(text: String, variation: String, parent: Control, on_pressed: Callable) -> PixelButton:
	var button := PixelButton.new()
	button.text = text
	button.theme_type_variation = variation
	button.focus_mode = Control.FOCUS_NONE
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


# --- Пауза ------------------------------------------------------------------

func _add_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause = PauseMenu.new()
	_pause.main_menu_requested.connect(SceneRouter.go_to_main_menu)
	layer.add_child(_pause)

func _open_pause() -> void:
	_pause.open()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()


## Пиксельное кольцо: точки по эллипсу, привязанные к сетке пикселя арта, — без
## прозрачности и сглаживания, как остальной арт.
class PixelRing extends Node2D:
	var color: Color
	var radii: Vector2

	func _init(ring_color: Color, ring_radii: Vector2) -> void:
		color = ring_color
		radii = ring_radii

	func _draw() -> void:
		var px := float(UiTokens.PIXEL)
		var steps := maxi(12, int(TAU * maxf(radii.x, radii.y) / px))
		for i in steps:
			var angle := TAU * i / steps
			var point := (Vector2(cos(angle) * radii.x, sin(angle) * radii.y) / px).floor() * px
			draw_rect(Rect2(point, Vector2(px, px)), color)
