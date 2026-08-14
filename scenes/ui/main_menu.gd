extends Control

@onready var nickname_input: LineEdit = $Margin/VBox/NicknameEdit/NicknameInput
@onready var lang_btn: Button = $Margin/VBox/LangBtn

func _ready() -> void:
	nickname_input.text = SaveManager.nickname
	_update_lang_button()

func _on_nickname_changed(new_text: String) -> void:
	SaveManager.set_nickname(new_text.strip_edges())

func _on_lang_pressed() -> void:
	GameSettings.cycle_language()
	_update_lang_button()

func _on_play_pressed() -> void:
	SceneRouter.go_to_game({"mode": "classic", "bots": 3})

func _on_play_vs_bots_pressed() -> void:
	SceneRouter.go_to_game({"mode": "vs_bots", "bots": 3})

func _on_wardrobe_pressed() -> void:
	SceneRouter.go_to_wardrobe()

func _on_codex_pressed() -> void:
	SceneRouter.go_to_codex()

func _on_quit_pressed() -> void:
	SceneRouter.quit()

func _update_lang_button() -> void:
	match GameSettings.current_language:
		GameSettings.Language.KZ: lang_btn.text = "KZ  |  RU  |  EN"
		GameSettings.Language.RU: lang_btn.text = "KZ  |  RU  |  EN"
		GameSettings.Language.EN: lang_btn.text = "KZ  |  RU  |  EN"
