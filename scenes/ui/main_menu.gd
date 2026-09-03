extends Control

@onready var nickname_input: LineEdit = $MenuCard/Margin/VBox/NicknameEdit/NicknameInput
@onready var nickname_warning: Label = $MenuCard/Margin/VBox/NicknameWarning
@onready var nickname_edit_row: HBoxContainer = $MenuCard/Margin/VBox/NicknameEdit
@onready var quit_dialog: SanlaqDialog = %QuitDialog

func _ready() -> void:
	nickname_input.text = SaveManager.nickname
	quit_dialog.confirmed.connect(func() -> void: SceneRouter.quit())
	_spawn_mascot()

func _require_nickname() -> bool:
	var name_text := nickname_input.text.strip_edges()
	if name_text.is_empty():
		nickname_warning.visible = true
		nickname_input.grab_focus()
		_shake_nickname_field()
		return false
	SaveManager.set_nickname(name_text)
	nickname_warning.visible = false
	return true

func _shake_nickname_field() -> void:
	var start_x := nickname_edit_row.position.x
	var tw := create_tween()
	for i in 4:
		var dir := 1 if i % 2 == 0 else -1
		tw.tween_property(nickname_edit_row, "position:x", start_x + 8 * dir, 0.05)
	tw.tween_property(nickname_edit_row, "position:x", start_x, 0.05)

func _spawn_mascot() -> void:
	var visual := _make_hero_character(Vector2(946, 390), 4.4, Vector2.LEFT)
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
	if not _require_nickname():
		return
	SceneRouter.go_to_lobby({"mode": "classic", "bots": 3})

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
