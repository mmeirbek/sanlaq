extends Control

const CHARACTER_VISUAL := "res://scenes/entities/character_visual.tscn"
const AVATAR_SIZE := Vector2(104, 96)

var _game_data: Dictionary = {}
var _bots_count: int = 3
var _selected_role := "sokyroteke"

@onready var _mode_label: Label = %ModeLabel
@onready var _bots_label: Label = %BotsLabel
@onready var _start_btn: Button = %StartBtn
@onready var _back_btn: Button = %BackBtn
@onready var _players_row: HBoxContainer = $Panel/Margin/VBox/PlayersRow
@onready var _minus_btn: Button = $Panel/Margin/VBox/BotStep/MinusBtn
@onready var _plus_btn: Button = $Panel/Margin/VBox/BotStep/PlusBtn
@onready var _sokyroteke_btn: Button = $Panel/Margin/VBox/RoleStep/SokyrotekeBtn
@onready var _runner_btn: Button = $Panel/Margin/VBox/RoleStep/RunnerBtn

func _ready() -> void:
	_game_data = SceneRouter.peek_pending_game_data()
	var mode: String = _game_data.get("mode", "classic")
	_bots_count = clampi(int(_game_data.get("bots", 3)), 1, 7)
	_selected_role = _game_data.get("role", "sokyroteke")
	if _selected_role != "runner":
		_selected_role = "sokyroteke"
	_mode_label.text = "Ойын түрі: %s" % _mode_name(mode)
	_refresh_bots_label()
	_refresh_role_buttons()
	_build_players()
	_minus_btn.pressed.connect(_on_minus)
	_plus_btn.pressed.connect(_on_plus)
	_sokyroteke_btn.pressed.connect(_set_role.bind("sokyroteke"))
	_runner_btn.pressed.connect(_set_role.bind("runner"))
	_start_btn.pressed.connect(_on_start)
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())

func _mode_name(mode: String) -> String:
	match mode:
		"vs_bots": return "Боттарға қарсы"
		_: return "Классикалық"

func _refresh_bots_label() -> void:
	_bots_label.text = "Боттар: %d" % _bots_count

func _set_role(role: String) -> void:
	_selected_role = role
	_refresh_role_buttons()

func _refresh_role_buttons() -> void:
	_sokyroteke_btn.modulate = Color("f4c768") if _selected_role == "sokyroteke" else Color.WHITE
	_runner_btn.modulate = Color("f4c768") if _selected_role == "runner" else Color.WHITE

func _on_minus() -> void:
	_bots_count = maxi(1, _bots_count - 1)
	_refresh_bots_label()
	_build_players()

func _on_plus() -> void:
	_bots_count = mini(7, _bots_count + 1)
	_refresh_bots_label()
	_build_players()

func _build_players() -> void:
	for c in _players_row.get_children():
		_players_row.remove_child(c)
		c.queue_free()

	var compact := _bots_count >= 5
	var avatar_size := Vector2(64, 82) if compact else AVATAR_SIZE
	_players_row.add_theme_constant_override("separation", 8 if compact else 20)
	_add_avatar(SaveManager.nickname + "  ·  Ойыншы", false, 0, avatar_size)
	for i in range(1, _bots_count + 1):
		_add_avatar("Қарсылас %d" % i, true, i - 1, avatar_size)

func _add_avatar(player_name: String, is_bot: bool, outfit_index: int = 0, avatar_size: Vector2 = AVATAR_SIZE) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := Label.new()
	name_label.text = player_name
	name_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11 if avatar_size.x < AVATAR_SIZE.x else 14)
	name_label.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
	box.add_child(name_label)

	var stage := Control.new()
	stage.custom_minimum_size = avatar_size
	stage.clip_contents = true
	box.add_child(stage)

	var visual: CharacterVisual = (load(CHARACTER_VISUAL) as PackedScene).instantiate()
	var visual_scale := 1.05 if avatar_size.x < AVATAR_SIZE.x else 1.5
	visual.scale = Vector2(visual_scale, visual_scale)
	visual.position = avatar_size * 0.5
	visual.set_direction(Vector2.DOWN)
	stage.add_child(visual)
	if is_bot:
		visual.set_base_variant(outfit_index + 1)
		_apply_bot_outfit(visual, outfit_index)
	else:
		for slot in ClothingItem.SlotType.values():
			var item_id := SaveManager.get_equipped(slot as ClothingItem.SlotType)
			var item := AssetRegistry.get_clothing_by_id(item_id)
			visual.set_clothing(slot as ClothingItem.SlotType, item)

	_players_row.add_child(box)

func _apply_bot_outfit(visual: CharacterVisual, outfit_index: int) -> void:
	var outfit := Player.get_outfit_profile(outfit_index)
	for slot in ClothingItem.SlotType.values():
		var item_id: String = outfit[int(slot)]
		var item := AssetRegistry.get_clothing_by_id(item_id)
		if item == null:
			var alternatives := AssetRegistry.get_clothing(slot as ClothingItem.SlotType)
			if not alternatives.is_empty():
				item = alternatives[0]
		visual.set_clothing(slot as ClothingItem.SlotType, item)

func _on_start() -> void:
	_game_data["bots"] = _bots_count
	_game_data["role"] = _selected_role
	SceneRouter.go_to_game(_game_data)
