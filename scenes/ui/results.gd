extends Control

@onready var _winner_label: Label = %WinnerLabel
@onready var _sub_label: Label = %SubLabel
@onready var _replay_btn: Button = %ReplayBtn
@onready var _wardrobe_btn: Button = %WardrobeBtn
@onready var _menu_btn: Button = %MenuBtn

func _ready() -> void:
	var results := SceneRouter.get_pending_results()
	var winner: String = results.get("winner", "players")
	var career: Dictionary = results.get("career", SaveManager.career)
	var correct_answers: int = results.get("correct_answers", 0)
	var rank := _rank_name(int(career.get("wins", 0)))
	if winner == "sokyroteke":
		_winner_label.text = "СОҚЫРТЕКЕ ЖЕҢДІ!"
		_winner_label.add_theme_color_override("font_color", SanlaqDesignTokens.RED_ACCENT)
		_sub_label.text = "Соқыртеке барлық қашушыны ұстап алды!"
	else:
		_winner_label.text = "ҚАШУШЫЛАР ЖЕҢДІ!"
		_winner_label.add_theme_color_override("font_color", SanlaqDesignTokens.GREEN_ACCENT)
		_sub_label.text = "Уақыт бітті — қашушылар аман қалды!"
	_sub_label.text += "\n\nДӘРЕЖЕ: %s · БІЛІМ: +%d · ЖЕҢІС: %d · СЕРИЯ: %d" % [
		rank,
		correct_answers,
		int(career.get("wins", 0)),
		int(career.get("streak", 0)),
	]

	_replay_btn.pressed.connect(_on_replay)
	_wardrobe_btn.pressed.connect(func() -> void: SceneRouter.go_to_wardrobe())
	_menu_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())

func _on_replay() -> void:
	SceneRouter.go_to_lobby({})

func _rank_name(wins: int) -> String:
	if wins >= 12:
		return "ДАЛА ШЕБЕРІ"
	if wins >= 5:
		return "ТОЙ БАСЫ"
	return "БАСТАУШЫ"
