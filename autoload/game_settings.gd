extends Node

enum Language { KZ, EN }

var current_language: Language = Language.KZ
var audio_sfx_volume: float = 1.0
var audio_music_volume: float = 0.7
var audio_sfx_enabled: bool = true
var audio_music_enabled: bool = true
var screen_shake_enabled: bool = true
var show_player_names: bool = true

func _ready() -> void:
	_apply_saved_settings()

func get_lang_code() -> String:
	match current_language:
		Language.KZ: return "kz"
		Language.EN: return "en"
	return "kz"

func set_language(lang: Language) -> void:
	current_language = lang
	SaveManager.set_setting("language", lang)
	_apply_language()

func cycle_language() -> void:
	match current_language:
		Language.KZ: current_language = Language.EN
		Language.EN: current_language = Language.KZ
	SaveManager.set_setting("language", current_language)
	_apply_language()

func localize(key: String) -> String:
	return key

func _apply_saved_settings() -> void:
	var saved_lang: int = SaveManager.get_setting("language", Language.KZ)
	current_language = saved_lang as Language
	audio_sfx_volume = SaveManager.get_setting("sfx_volume", 1.0)
	audio_music_volume = SaveManager.get_setting("music_volume", 0.7)
	audio_sfx_enabled = SaveManager.get_setting("sfx_enabled", true)
	audio_music_enabled = SaveManager.get_setting("music_enabled", true)
	screen_shake_enabled = SaveManager.get_setting("screen_shake_enabled", true)
	show_player_names = SaveManager.get_setting("show_player_names", true)

func set_sfx_enabled(enabled: bool) -> void:
	audio_sfx_enabled = enabled
	SaveManager.set_setting("sfx_enabled", enabled)

func set_music_enabled(enabled: bool) -> void:
	audio_music_enabled = enabled
	SaveManager.set_setting("music_enabled", enabled)

func set_sfx_volume(volume: float) -> void:
	audio_sfx_volume = clampf(volume, 0.0, 1.0)
	SaveManager.set_setting("sfx_volume", audio_sfx_volume)

func set_music_volume(volume: float) -> void:
	audio_music_volume = clampf(volume, 0.0, 1.0)
	SaveManager.set_setting("music_volume", audio_music_volume)

func set_screen_shake_enabled(enabled: bool) -> void:
	screen_shake_enabled = enabled
	SaveManager.set_setting("screen_shake_enabled", enabled)

func set_show_player_names(enabled: bool) -> void:
	show_player_names = enabled
	SaveManager.set_setting("show_player_names", enabled)

func get_sfx_volume_db() -> float:
	if not audio_sfx_enabled or audio_sfx_volume <= 0.001:
		return -80.0
	return linear_to_db(audio_sfx_volume) - 8.0

func get_music_volume_db() -> float:
	if not audio_music_enabled or audio_music_volume <= 0.001:
		return -80.0
	return linear_to_db(audio_music_volume) - 18.0

func _apply_language() -> void:
	pass
