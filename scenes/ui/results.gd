extends Control
## Итог раунда Соқыртеке: кто победил (с картинкой роли — понятно без слов),
## ранг игрока и статистика, дальше — снова играть, шкаф или меню.

const WINNER_ART := {
	"sokyroteke": preload("res://assets/sprites/modes/role_seeker.png"),
	"players": preload("res://assets/sprites/modes/role_runner.png"),
}

func _ready() -> void:
	var results := SceneRouter.get_pending_results()
	var winner: String = results.get("winner", "players")
	var career: Dictionary = results.get("career", SaveManager.career)
	var correct_answers: int = results.get("correct_answers", 0)
	var wins := int(career.get("wins", 0))
	%WinnerArt.texture = WINNER_ART.get(winner, WINNER_ART["players"])
	if winner == "sokyroteke":
		%WinnerLabel.text = tr("СОҚЫРТЕКЕ ЖЕҢДІ!")
		%SubLabel.text = tr("Соқыртеке барлық қашушыны ұстап алды!")
	else:
		%WinnerLabel.text = tr("ҚАШУШЫЛАР ЖЕҢДІ!")
		%SubLabel.text = tr("Уақыт бітті — қашушылар аман қалды!")
	%Stats.text = tr("ДӘРЕЖЕ: %s · БІЛІМ: +%d · ЖЕҢІС: %d · СЕРИЯ: %d\n%s") % [
		RankSystem.current_rank_name(wins),
		correct_answers,
		wins,
		int(career.get("streak", 0)),
		RankSystem.progress_text(wins),
	]
	%ReplayBtn.pressed.connect(func() -> void: SceneRouter.go_to_lobby({}))
	%WardrobeBtn.pressed.connect(SceneRouter.go_to_wardrobe)
	%MenuBtn.pressed.connect(SceneRouter.go_to_main_menu)
