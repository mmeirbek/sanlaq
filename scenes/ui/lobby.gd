extends Control
## Подготовка к Соқыртеке: роль игрока, число ботов (1–7) и портреты всех
## участников в их одежде.

const CHARACTER_SCENE := preload("res://scenes/entities/character_visual.tscn")
const MIN_BOTS := 1
const MAX_BOTS := 7
## Сколько участников помещается крупно (×2); больше — портреты в натуральную
## величину. Масштаб всегда целый, чтобы пиксели оставались ровными.
const LARGE_PORTRAITS_UP_TO := 4
## Кадр персонажа в пикселях при масштабе 1 (контракт character_visual.gd).
const FRAME_SIZE := 64

var _game_data: Dictionary = {}
var _bots_count: int = 3
var _selected_role := Roles.Role.SOKYROTEKE

@onready var _mode_label: Label = %ModeLabel
@onready var _bots_label: Label = %BotsLabel
@onready var _players_row: HBoxContainer = %PlayersRow
@onready var _sokyroteke_card: SelectableCard = %SokyrotekeCard
@onready var _runner_card: SelectableCard = %RunnerCard

func _ready() -> void:
	_game_data = SceneRouter.peek_pending_game_data()
	var mode: String = _game_data.get("mode", "classic")
	_bots_count = clampi(int(_game_data.get("bots", 3)), MIN_BOTS, MAX_BOTS)
	_selected_role = _game_data.get("role", Roles.Role.SOKYROTEKE)
	_mode_label.text = tr("Ойын түрі: %s") % _mode_name(mode)
	_refresh_bots_label()
	_refresh_role_cards()
	_build_players()
	%MinusBtn.pressed.connect(_change_bots.bind(-1))
	%PlusBtn.pressed.connect(_change_bots.bind(1))
	_sokyroteke_card.pressed.connect(_set_role.bind(Roles.Role.SOKYROTEKE))
	_runner_card.pressed.connect(_set_role.bind(Roles.Role.RUNNER))
	%StartBtn.pressed.connect(_on_start)
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_main_menu)

func _mode_name(mode: String) -> String:
	match mode:
		"vs_bots": return tr("Боттарға қарсы")
		_: return tr("Классикалық")

func _refresh_bots_label() -> void:
	_bots_label.text = tr("Боттар: %d") % _bots_count

func _set_role(role: Roles.Role) -> void:
	_selected_role = role
	_refresh_role_cards()

func _refresh_role_cards() -> void:
	_sokyroteke_card.selected = _selected_role == Roles.Role.SOKYROTEKE
	_runner_card.selected = _selected_role == Roles.Role.RUNNER

func _change_bots(delta: int) -> void:
	_bots_count = clampi(_bots_count + delta, MIN_BOTS, MAX_BOTS)
	_refresh_bots_label()
	_build_players()

func _build_players() -> void:
	for child in _players_row.get_children():
		_players_row.remove_child(child)
		child.queue_free()
	var portrait_scale := 2 if _bots_count + 1 <= LARGE_PORTRAITS_UP_TO else 1
	_add_portrait(SaveManager.nickname, -1, portrait_scale)
	# Те же имена, что у ботов в игре, — короткие, помещаются под портретом.
	for i in _bots_count:
		_add_portrait(Player.bot_name_for(i), i, portrait_scale)

## Портрет участника: персонаж в одежде и подпись. outfit_index < 0 — сам игрок
## в своей экипировке, иначе — набор одежды бота.
func _add_portrait(player_name: String, outfit_index: int, portrait_scale: int) -> void:
	var box := VBoxContainer.new()
	var slot_size := Vector2.ONE * FRAME_SIZE * portrait_scale
	var stage := Control.new()
	stage.custom_minimum_size = slot_size
	box.add_child(stage)

	var visual: CharacterVisual = CHARACTER_SCENE.instantiate()
	visual.scale = Vector2.ONE * portrait_scale
	visual.set_rest_position(slot_size / 2)
	visual.set_direction(Vector2.DOWN)
	stage.add_child(visual)
	if outfit_index < 0:
		OutfitApplier.dress(visual, OutfitApplier.player_outfit())
	else:
		visual.set_base_variant(outfit_index + 1)
		OutfitApplier.dress(visual, OutfitApplier.bot_outfit(outfit_index))

	var name_label := Label.new()
	name_label.text = player_name
	name_label.theme_type_variation = "CaptionLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.x = slot_size.x
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if outfit_index < 0:
		# Свой портрет — первый и с золотым именем, чтобы найти себя среди ботов.
		name_label.add_theme_color_override("font_color", UiTokens.GOLD_LIGHT)
	box.add_child(name_label)
	_players_row.add_child(box)

func _on_start() -> void:
	_game_data["bots"] = _bots_count
	_game_data["role"] = _selected_role
	SceneRouter.go_to_game(_game_data)
