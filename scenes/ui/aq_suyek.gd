extends Control
## Экран режима «Ақ сүйек». Правила живут в AqSuyekBoard, выбор хода компьютера —
## в AqSuyekBot; здесь только отрисовка поля, вопросы и передача ходов.
##
## Ход состоит из двух частей: сначала вопрос о традициях даёт шаги, потом эти
## шаги тратятся на переход по клеткам. Пока шаги есть, ходить можно только в
## соседнюю клетку — она подсвечивается.

const HUMAN := AqSuyekBoard.HUMAN
const BOT := AqSuyekBoard.BOT
## Пауза между действиями компьютера, чтобы за ним было видно, что происходит.
const BOT_THINK := 0.7
const BOT_STEP := 0.45
## Сколько держать разбор раунда перед следующим.
const ROUND_PAUSE := 1.8

## Цвета подсказок по спецификации: чем ближе сүйек, тем горячее след.
## Те же цвета, что у следов на поле (aq_suyek_art.py).
const HINT_COLORS := {
	AqSuyekBoard.Hint.FOUND: UiTokens.PARCHMENT,
	AqSuyekBoard.Hint.VERY_CLOSE: UiTokens.SEEKER,
	AqSuyekBoard.Hint.CLOSE: UiTokens.EMBER,
	AqSuyekBoard.Hint.NEAR: UiTokens.GOLD_LIGHT,
	AqSuyekBoard.Hint.FAR: UiTokens.RUNNER,
}
const HINT_NAMES := {
	AqSuyekBoard.Hint.FOUND: "Тапты!",
	AqSuyekBoard.Hint.VERY_CLOSE: "Өте жақын",
	AqSuyekBoard.Hint.CLOSE: "Жақын",
	AqSuyekBoard.Hint.NEAR: "Алыс емес",
	AqSuyekBoard.Hint.FAR: "Алыс",
}

var _board: AqSuyekBoard
var _bot: AqSuyekBot
var _questions: Array[CultureQuestion] = []
var _question_at: int = 0
var _busy: bool = false
## Снимок доигранного раунда на время разбора. Поле после найденного сүйек уже
## пересобрано под следующий раунд, поэтому рисовать по `_board` нельзя: игрок
## увидел бы чистое поле и звезду на новом, ещё не найденном сүйек. Пусто —
## значит, идёт обычный ход и поле берётся у доски.
var _frozen: Dictionary = {}
var _audio: GameAudio

@onready var _play_panel: Control = %PlayPanel
@onready var _end_panel: PanelContainer = %EndPanel
@onready var _field: AqSuyekField = %Field
@onready var _legend: HBoxContainer = %Legend
@onready var _turn_label: Label = %TurnLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _round_label: Label = %RoundLabel
@onready var _question_label: Label = %QuestionLabel
@onready var _options_box: VBoxContainer = %Options
@onready var _fact_label: Label = %FactLabel
@onready var _status_label: Label = %StatusLabel
@onready var _end_kicker: Label = %EndKicker
@onready var _winner_label: Label = %WinnerLabel
@onready var _score_final: Label = %ScoreFinal
@onready var _again_btn: Button = %AgainBtn
@onready var _menu_btn: Button = %MenuBtn

func _ready() -> void:
	_audio = GameAudio.new()
	add_child(_audio)
	_again_btn.pressed.connect(_start_game)
	_menu_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_mode_select)
	_field.cell_pressed.connect(_on_cell_pressed)
	_bot = AqSuyekBot.new()
	_build_legend()
	_start_game()

# --- Поле -------------------------------------------------------------------

## Подписи к цветам следов: «Алыс» ... «Өте жақын».
func _build_legend() -> void:
	for hint: int in [AqSuyekBoard.Hint.FAR, AqSuyekBoard.Hint.NEAR,
			AqSuyekBoard.Hint.CLOSE, AqSuyekBoard.Hint.VERY_CLOSE]:
		var label := Label.new()
		label.text = tr(HINT_NAMES[hint])
		label.theme_type_variation = "WarningLabel"
		label.add_theme_color_override("font_color", HINT_COLORS[hint])
		_legend.add_child(label)

func _refresh_board() -> void:
	var reachable: Array[Vector2i] = []
	for direction: Vector2i in AqSuyekBoard.DIRECTIONS:
		var cell: Vector2i = _board.positions[HUMAN] + direction
		if _is_reachable(cell):
			reachable.append(cell)
	var bone: Vector2i = _frozen["bone"] if not _frozen.is_empty() else Vector2i(-1, -1)
	_field.show_state(_view_positions(), _view_revealed(), reachable, bone, AqSuyekBoard.HOMES)
	_update_labels()

## Поле, по которому рисуем: снимок доигранного раунда, если он есть, иначе доска.
func _view_positions() -> Array:
	return _frozen["positions"] if not _frozen.is_empty() else _board.positions

func _view_revealed() -> Dictionary:
	return _frozen["revealed"] if not _frozen.is_empty() else _board.revealed

## Шагнуть можно только в соседнюю клетку и только когда шаги есть.
func _is_reachable(cell: Vector2i) -> bool:
	if _busy or not _frozen.is_empty() or _board == null or _board.is_over():
		return false
	if _board.current_player != HUMAN or _board.awaiting_answer():
		return false
	var delta: Vector2i = cell - _board.positions[HUMAN]
	return _board.can_step(delta)

func _update_labels() -> void:
	if _board == null:
		return
	_score_label.text = "%d : %d" % [_board.scores[HUMAN], _board.scores[BOT]]
	# В разборе поле показывает доигранный раунд — подписи должны говорить о нём
	# же. Доска свой счётчик уже перевела, поэтому здесь он без прибавки.
	if not _frozen.is_empty():
		_round_label.text = tr("%d-РАУНД") % _board.round_index
		_turn_label.text = tr("РАУНД АЯҚТАЛДЫ")
		return
	_round_label.text = tr("%d-РАУНД") % (_board.round_index + 1)
	if _board.is_over():
		return
	if _board.current_player == HUMAN:
		var steps: int = _board.steps[HUMAN]
		_turn_label.text = tr("Кезек: Сіз") if steps == 0 else tr("Қалған қадам: %d") % steps
	else:
		_turn_label.text = tr("Кезек: Компьютер")

# --- Партия -----------------------------------------------------------------

func _start_game() -> void:
	_board = AqSuyekBoard.new()
	_questions = AssetRegistry.get_shuffled_questions()
	_question_at = 0
	_busy = false
	_frozen = {}
	_fact_label.text = ""
	_status_label.text = ""
	_end_panel.visible = false
	_play_panel.visible = true
	_refresh_board()
	Telemetry.log_event("aq_suyek_start", {})
	_begin_turn()

func _begin_turn() -> void:
	if _board.is_over():
		_show_end()
		return
	if _board.current_player == BOT:
		_bot_turn()
		return
	if _board.awaiting_answer():
		_ask_question()
	else:
		_status_label.text = tr("Көрші отауды таңдап, жүріңіз")
		_refresh_board()

# --- Вопрос -----------------------------------------------------------------

func _ask_question() -> void:
	if _questions.is_empty():
		# Без вопросов ходить было бы нечем — даём шаги молча, чтобы экран не завис.
		Telemetry.log_error("no CultureQuestion resources found", "aq_suyek")
		_board.answer(true)
		_begin_turn()
		return

	var question: CultureQuestion = _questions[_question_at % _questions.size()]
	_question_at += 1
	_question_label.text = tr(question.question)
	_fact_label.text = ""
	_status_label.text = ""

	for c in _options_box.get_children():
		_options_box.remove_child(c)
		c.queue_free()

	# Перемешиваем варианты: иначе верный всегда стоял бы первым.
	var order: Array[int] = []
	for i in question.options.size():
		order.append(i)
	order.shuffle()
	for i in order:
		var btn := PixelButton.new()
		btn.text = tr(question.options[i])
		btn.theme_type_variation = "AnswerButton"
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_answer.bind(i == question.correct, question))
		_options_box.add_child(btn)

	_refresh_board()

func _on_answer(correct: bool, question: CultureQuestion) -> void:
	if _busy or _board.current_player != HUMAN:
		return
	for c in _options_box.get_children():
		(c as Button).disabled = true

	var gained := _board.answer(correct)
	_fact_label.text = tr(question.fact)
	_status_label.text = tr("Дұрыс! %d қадам") % gained if correct else tr("Қате. %d қадам") % gained
	_status_label.add_theme_color_override("font_color", UiTokens.SUCCESS if correct else UiTokens.DANGER)
	_audio.play_quiz_result(correct)

	for c in _options_box.get_children():
		c.queue_free()
	_refresh_board()

# --- Ходы -------------------------------------------------------------------

func _on_cell_pressed(cell: Vector2i) -> void:
	if not _is_reachable(cell):
		return
	_perform_step(cell - _board.positions[HUMAN])

func _perform_step(direction: Vector2i) -> void:
	var res: Dictionary = _board.step(direction)
	_report_step(res)
	_refresh_board()

	if bool(res["round_over"]):
		await _finish_round(res)
		return
	if _board.current_player == BOT:
		_begin_turn()
	elif _board.awaiting_answer():
		_begin_turn()

func _report_step(res: Dictionary) -> void:
	var hint: int = res["hint"]
	_status_label.text = tr(HINT_NAMES.get(hint, ""))
	_status_label.add_theme_color_override("font_color", HINT_COLORS[hint])
	_audio.play_card_tone(4 - hint)

func _finish_round(res: Dictionary) -> void:
	_busy = true
	_frozen = {
		"bone": res["bone"],
		"positions": res["final_positions"],
		"revealed": res["final_revealed"],
	}
	var finder: int = res["player"]
	_status_label.text = tr("Сіз сүйекті таптыңыз!") if finder == HUMAN else tr("Компьютер сүйекті тапты")
	_status_label.add_theme_color_override("font_color", UiTokens.SUCCESS if finder == HUMAN else UiTokens.DANGER)
	_audio.play_catch()
	_refresh_board()

	await get_tree().create_timer(ROUND_PAUSE).timeout
	if not is_inside_tree():
		return
	_busy = false
	_frozen = {}
	if bool(res["finished"]):
		_show_end()
		return
	_question_label.text = "—"
	_refresh_board()
	_begin_turn()

# --- Компьютер --------------------------------------------------------------

func _bot_turn() -> void:
	_busy = true
	_refresh_board()
	await get_tree().create_timer(BOT_THINK).timeout
	if not is_inside_tree():
		return

	var correct := _bot.answers_correctly()
	_board.answer(correct)
	_status_label.text = tr("Компьютер жауап берді") if correct else tr("Компьютер қателесті")
	_status_label.add_theme_color_override("font_color", UiTokens.CREAM if correct else UiTokens.MUTED)

	while _board.current_player == BOT and not _board.is_over() and not _board.awaiting_answer():
		await get_tree().create_timer(BOT_STEP).timeout
		if not is_inside_tree():
			return
		var direction := _bot.choose_step(_board)
		if direction == Vector2i.ZERO:
			break
		var res: Dictionary = _board.step(direction)
		_refresh_board()
		if bool(res["round_over"]):
			_busy = false
			await _finish_round(res)
			return

	_busy = false
	_begin_turn()

# --- Итоги ------------------------------------------------------------------

func _show_end() -> void:
	var winner := _board.winner()
	if winner < 0:
		_end_kicker.text = tr("ТЕҢ ТҮСТІ")
		_winner_label.text = tr("Тең ойын")
	else:
		_end_kicker.text = tr("ЖЕҢІМПАЗ")
		_winner_label.text = tr("Сіз") if winner == HUMAN else tr("Компьютер")
	_score_final.text = "%d : %d" % [_board.scores[HUMAN], _board.scores[BOT]]
	if winner == HUMAN:
		_audio.play_victory()
	elif winner == BOT:
		_audio.play_defeat()
	Telemetry.log_event("aq_suyek_end", {
		"winner": winner,
		"score_human": _board.scores[HUMAN],
		"score_bot": _board.scores[BOT],
	})
	_end_panel.visible = true
