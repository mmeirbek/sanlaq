extends Control

@onready var nickname_input: LineEdit = $Margin/VBox/NicknameEdit/NicknameInput
@onready var quit_dialog: SanlaqDialog = %QuitDialog

func _ready() -> void:
	nickname_input.text = SaveManager.nickname
	quit_dialog.confirmed.connect(func() -> void: SceneRouter.quit())
	_spawn_mascot()

func _spawn_mascot() -> void:
	var visual := _make_hero_character(Vector2(946, 390), 4.4, Vector2.LEFT)
	visual.set_chaser(true)
	for slot in ClothingItem.SlotType.values():
		var item := AssetRegistry.get_clothing_by_id(SaveManager.get_equipped(slot))
		visual.set_clothing(slot, item)

func _make_hero_character(at: Vector2, size_scale: float, direction: Vector2) -> CharacterVisual:
	var visual: CharacterVisual = (load("res://scenes/entities/character_visual.tscn") as PackedScene).instantiate()
	visual.scale = Vector2(size_scale, size_scale)
	visual.position = at
	visual.set_direction(direction)
	add_child(visual)
	return visual

func _on_nickname_changed(new_text: String) -> void:
	SaveManager.set_nickname(new_text.strip_edges())

func _on_play_pressed() -> void:
	SceneRouter.go_to_lobby({"mode": "classic", "bots": 3})

func _on_play_vs_bots_pressed() -> void:
	SceneRouter.go_to_lobby({"mode": "vs_bots", "bots": 3})

func _on_wardrobe_pressed() -> void:
	SceneRouter.go_to_wardrobe()

func _on_codex_pressed() -> void:
	SceneRouter.go_to_codex()

func _on_about_pressed() -> void:
	SceneRouter.go_to_about()

func _on_settings_pressed() -> void:
	SceneRouter.go_to_settings()

func _on_quit_pressed() -> void:
	quit_dialog.open()
