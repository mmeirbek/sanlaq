extends Node

enum Language { KZ, RU, EN }

var current_language: Language = Language.KZ
var audio_master_volume: float = 1.0
var audio_sfx_volume: float = 1.0
var audio_music_volume: float = 0.7
var screen_shake_enabled: bool = true
var show_player_names: bool = true

func _ready() -> void:
	_apply_saved_settings()

func get_lang_code() -> String:
	match current_language:
		Language.KZ: return "kz"
		Language.RU: return "ru"
		Language.EN: return "en"
	return "kz"

func set_language(lang: Language) -> void:
	current_language = lang
	SaveManager.set_setting("language", lang)
	_apply_language()

func cycle_language() -> void:
	match current_language:
		Language.KZ: current_language = Language.RU
		Language.RU: current_language = Language.EN
		Language.EN: current_language = Language.KZ
	SaveManager.set_setting("language", current_language)
	_apply_language()

func localize(key: String) -> String:
	return key

func _apply_saved_settings() -> void:
	var saved_lang: int = SaveManager.get_setting("language", Language.KZ)
	current_language = saved_lang as Language
	audio_master_volume = SaveManager.get_setting("master_volume", 1.0)
	audio_sfx_volume = SaveManager.get_setting("sfx_volume", 1.0)
	audio_music_volume = SaveManager.get_setting("music_volume", 0.7)

func _apply_language() -> void:
	pass
