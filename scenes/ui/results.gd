extends Control
## Итог раунда Соқыртеке: кто победил (с картинкой роли — понятно без слов),
## ранг игрока и статистика, дальше — снова играть, шкаф или меню.

const WINNER_ART := {
	Roles.Winner.SOKYROTEKE: preload("res://assets/sprites/modes/role_seeker.png"),
	Roles.Winner.RUNNERS: preload("res://assets/sprites/modes/role_runner.png"),
}

func _ready() -> void:
	var results := SceneRouter.get_pending_results()
	var winner: Roles.Winner = results.get("winner", Roles.Winner.RUNNERS)
	var career: Dictionary = results.get("career", SaveManager.career)
	var correct_answers: int = results.get("correct_answers", 0)
	var wins := int(career.get("wins", 0))
	%WinnerArt.texture = WINNER_ART[winner]
	if winner == Roles.Winner.SOKYROTEKE:
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

## Esc — в главное меню, как кнопка «Бас мәзір».
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneRouter.go_to_main_menu()
