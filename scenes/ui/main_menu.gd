extends Control

@onready var nickname_input: LineEdit = $MenuCard/Margin/VBox/NicknameEdit/NicknameInput
@onready var nickname_warning: Label = $MenuCard/Margin/VBox/NicknameWarning
@onready var nickname_edit_row: HBoxContainer = $MenuCard/Margin/VBox/NicknameEdit
@onready var quit_dialog: SanlaqDialog = %QuitDialog

func _ready() -> void:
	nickname_input.text = SaveManager.nickname
	quit_dialog.confirmed.connect(func() -> void: SceneRouter.quit())
	Telemetry.license_denied.connect(_on_license_denied)
	_spawn_mascot()

func _on_license_denied(reason: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = SanlaqDesignTokens.NAVY_DARK
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 4096

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position -= box.custom_minimum_size * 0.5
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", SanlaqDesignTokens.SPACING_MEDIUM)
	overlay.add_child(box)

	var title := Label.new()
	title.text = tr("СТАНЦИЯ БҰҒАТТАЛДЫ")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", SanlaqDesignTokens.GOLD)
	title.add_theme_font_size_override("font_size", SanlaqDesignTokens.FONT_SIZE_TITLE)
	box.add_child(title)

	var reason_text := tr("Бұл құрылғылар саны лимитінен асып кетті.") if reason == "device_limit" else tr("Лицензия жойылды.")
	var message := Label.new()
	message.text = "%s\n%s" % [reason_text, tr("Ұйымдастырушыға хабарласыңыз.")]
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	message.add_theme_color_override("font_color", SanlaqDesignTokens.CREAM)
	message.add_theme_font_size_override("font_size", SanlaqDesignTokens.FONT_SIZE_BODY)
	box.add_child(message)

	add_child(overlay)

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
	Telemetry.log_event("button_press", {"button": "play"})
	SceneRouter.go_to_lobby({"mode": "classic", "bots": 3})

func _on_wardrobe_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "wardrobe"})
	SceneRouter.go_to_wardrobe()

func _on_codex_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "codex"})
	SceneRouter.go_to_codex()

func _on_about_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "about"})
	SceneRouter.go_to_about()

func _on_settings_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "settings"})
	SceneRouter.go_to_settings()

func _on_quit_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "quit"})
	quit_dialog.open()
