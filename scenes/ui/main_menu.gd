extends Control
## Главное меню: логотип, кнопки разделов и карточка игрока (имя, его персонаж
## в выбранной одежде, краткое правило). Играть можно только с введённым именем.

## Персонаж в карточке — в целом масштабе, чтобы пиксели оставались ровными.
const MASCOT_SCALE := 3
const CHARACTER_SCENE := preload("res://scenes/entities/character_visual.tscn")

@onready var nickname_input: LineEdit = %NicknameInput
@onready var nickname_warning: Label = %NicknameWarning
@onready var quit_dialog: ConfirmDialog = %QuitDialog
@onready var _mascot_slot: Control = %MascotSlot

var _mascot: CharacterVisual

func _ready() -> void:
	nickname_input.text = SaveManager.nickname
	%Version.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	quit_dialog.confirmed.connect(func() -> void: SceneRouter.quit())
	Telemetry.license_denied.connect(_on_license_denied)
	_spawn_mascot()

func _on_license_denied(reason: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = UiTokens.INK
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 4096

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 560
	center.add_child(box)

	var title := Label.new()
	title.text = tr("СТАНЦИЯ БҰҒАТТАЛДЫ")
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var reason_text := tr("Бұл құрылғылар саны лимитінен асып кетті.") if reason == "device_limit" else tr("Лицензия жойылды.")
	var message := Label.new()
	message.text = "%s\n%s" % [reason_text, tr("Ұйымдастырушыға хабарласыңыз.")]
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
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

## Поле имени коротко трясётся — шагом в пиксели арта.
func _shake_nickname_field() -> void:
	var start_x := nickname_input.position.x
	var shake := UiTokens.PIXEL * 4
	var tw := create_tween()
	for i in 4:
		tw.tween_property(nickname_input, "position:x", start_x + shake * (1 if i % 2 == 0 else -1), 0.05)
	tw.tween_property(nickname_input, "position:x", start_x, 0.05)

func _spawn_mascot() -> void:
	_mascot = CHARACTER_SCENE.instantiate()
	_mascot.scale = Vector2.ONE * MASCOT_SCALE
	_mascot.set_direction(Vector2.DOWN)
	_mascot_slot.add_child(_mascot)
	for slot in ClothingItem.SlotType.values():
		_mascot.set_clothing(slot, AssetRegistry.get_clothing_by_id(SaveManager.get_equipped(slot)))
	_mascot_slot.resized.connect(_place_mascot)
	_place_mascot()

## Персонаж стоит по центру слота; позиция округляется до пикселя арта.
func _place_mascot() -> void:
	var step := UiTokens.PIXEL * MASCOT_SCALE
	var center := (_mascot_slot.size / 2 / step).floor() * step
	_mascot.set_rest_position(center)

func _on_nickname_changed(new_text: String) -> void:
	SaveManager.set_nickname(new_text.strip_edges())

func _on_play_pressed() -> void:
	if not _require_nickname():
		return
	Telemetry.log_event("button_press", {"button": "play"})
	SceneRouter.go_to_mode_select()

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
