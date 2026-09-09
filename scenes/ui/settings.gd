extends Control

@onready var _music_toggle: CheckButton = %MusicToggle
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_toggle: CheckButton = %SfxToggle
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _shake_toggle: CheckButton = %ShakeToggle
@onready var _names_toggle: CheckButton = %NamesToggle
@onready var _rank: Label = %Rank
@onready var _stats: Label = %Stats
@onready var _back_btn: Button = %BackBtn
@onready var _lang_btn: Button = %LanguageBtn

func _ready() -> void:
	_music_toggle.button_pressed = GameSettings.audio_music_enabled
	_music_slider.value = GameSettings.audio_music_volume * 100.0
	_sfx_toggle.button_pressed = GameSettings.audio_sfx_enabled
	_sfx_slider.value = GameSettings.audio_sfx_volume * 100.0
	_shake_toggle.button_pressed = GameSettings.screen_shake_enabled
	_names_toggle.button_pressed = GameSettings.show_player_names
	_music_toggle.toggled.connect(_on_music_enabled)
	_sfx_toggle.toggled.connect(_on_sfx_enabled)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_shake_toggle.toggled.connect(GameSettings.set_screen_shake_enabled)
	_names_toggle.toggled.connect(GameSettings.set_show_player_names)
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	_lang_btn.pressed.connect(_on_language_pressed)
	_refresh()

func _on_music_enabled(enabled: bool) -> void:
	GameSettings.set_music_enabled(enabled)
	_refresh()

func _on_sfx_enabled(enabled: bool) -> void:
	GameSettings.set_sfx_enabled(enabled)
	_refresh()

func _on_language_pressed() -> void:
	GameSettings.cycle_language()
	_refresh()

func _on_music_volume_changed(value: float) -> void:
	GameSettings.set_music_volume(value / 100.0)
	_refresh()

func _on_sfx_volume_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value / 100.0)
	_refresh()

func _refresh() -> void:
	# Ползунок выключенного канала гасим: полная золотая заливка под выключенным
	# тумблером читается как «звук есть».
	_set_slider_dimmed(_music_slider, _music_value, not GameSettings.audio_music_enabled)
	_set_slider_dimmed(_sfx_slider, _sfx_value, not GameSettings.audio_sfx_enabled)
	_lang_btn.text = "ENG / АҒЫЛ" if GameSettings.current_language == GameSettings.Language.KZ else "ҚАЗ / KAZ"
	_music_value.text = "%d%%" % roundi(GameSettings.audio_music_volume * 100.0)
	_sfx_value.text = "%d%%" % roundi(GameSettings.audio_sfx_volume * 100.0)
	var career: Dictionary = SaveManager.career
	var wins := int(career.get("wins", 0))
	_rank.text = RankSystem.current_rank_name(wins)
	_stats.text = tr("БІЛІМ ҰПАЙЫ: %d\nЖЕҢІС: %d\nҚАЗІРГІ СЕРИЯ: %d\nҮЗДІК СЕРИЯ: %d\n%s") % [
		int(career.get("knowledge", 0)), wins, int(career.get("streak", 0)), int(career.get("best_streak", 0)),
		RankSystem.progress_text(wins),
	]

func _set_slider_dimmed(slider: HSlider, value_label: Label, dimmed: bool) -> void:
	var alpha := 0.4 if dimmed else 1.0
	slider.modulate = Color(1, 1, 1, alpha)
	value_label.modulate = Color(1, 1, 1, alpha)
