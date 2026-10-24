class_name PauseMenu
extends Control
## Пауза: затемнение и панель «ЖАЛҒАСТЫРУ / БАПТАУЛАР / БАС МӘЗІР». Пока она
## открыта, дерево сцены стоит (get_tree().paused), сама пауза работает всегда.
## Esc — продолжить. «БАПТАУЛАР» раскрывает звук прямо здесь, не уходя из игры.
## «БАС МӘЗІР» спрашивает подтверждение: незаконченная партия пропадёт.
##
## Обращается к GameSettings — в тестах этот класс нельзя писать как тип.

signal resumed
signal main_menu_requested

var _panel: PanelContainer
var _resume_button: PixelButton
var _settings_box: VBoxContainer
var _confirm: ConfirmDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = ConfirmDialog.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 440
	box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	_panel.add_child(box)

	var title := Label.new()
	title.text = tr("ҮЗІЛІС")
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(GemDivider.new())

	_resume_button = _button(box, "ЖАЛҒАСТЫРУ", "ButtonLarge", resume)
	_button(box, "БАПТАУЛАР", "ButtonSecondary", _toggle_settings)
	_settings_box = VBoxContainer.new()
	_settings_box.visible = false
	box.add_child(_settings_box)
	_audio_row("Музыканы қосу", GameSettings.audio_music_enabled, GameSettings.audio_music_volume,
		GameSettings.set_music_enabled, GameSettings.set_music_volume)
	_audio_row("Әсерлерді қосу", GameSettings.audio_sfx_enabled, GameSettings.audio_sfx_volume,
		GameSettings.set_sfx_enabled, GameSettings.set_sfx_volume)
	_button(box, "БАС МӘЗІР", "ButtonSecondary", _ask_main_menu)

	_confirm = ConfirmDialog.new()
	_confirm.dialog_title = tr("БАС МӘЗІР")
	_confirm.dialog_message = tr("Ойын тоқтатылады. Бас мәзірге шығасыз ба?")
	_confirm.confirm_text = tr("Иә")
	_confirm.cancel_text = tr("Жоқ")
	_confirm.confirmed.connect(_leave)
	add_child(_confirm)


func open() -> void:
	if visible:
		return
	visible = true
	_settings_box.visible = false
	get_tree().paused = true
	_resume_button.grab_focus()


func resume() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	resumed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	# Пока открыто подтверждение, Esc закрывает его, а не паузу.
	if visible and not _confirm.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()


func _exit_tree() -> void:
	# Экран могли закрыть прямо из паузы — дерево не должно остаться стоять.
	if visible and is_inside_tree():
		get_tree().paused = false


func _button(parent: Control, text: String, variation: String, action: Callable) -> PixelButton:
	var button := PixelButton.new()
	button.text = tr(text)
	button.theme_type_variation = variation
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _audio_row(caption: String, enabled: bool, volume: float, set_enabled: Callable,
		set_volume: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = tr(caption)
	toggle.button_pressed = enabled
	toggle.toggled.connect(set_enabled)
	_settings_box.add_child(toggle)
	var slider := HSlider.new()
	slider.max_value = 100.0
	slider.value = volume * 100.0
	slider.value_changed.connect(func(value: float) -> void: set_volume.call(value / 100.0))
	_settings_box.add_child(slider)


func _toggle_settings() -> void:
	_settings_box.visible = not _settings_box.visible


func _ask_main_menu() -> void:
	_confirm.open()


func _leave() -> void:
	visible = false
	get_tree().paused = false
	main_menu_requested.emit()
