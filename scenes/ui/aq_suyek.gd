extends Control
## Экран режима «Ақ сүйек». Правила живут в AqSuyekBoard, выбор хода компьютера —
## в AqSuyekBot; здесь только отрисовка поля, вопросы и передача ходов.
##
## Ход состоит из двух частей: сначала вопрос о традициях даёт шаги, потом эти
## шаги тратятся на переход по клеткам. Пока шаги есть, ходить можно только в
## соседнюю клетку — она подсвечивается.

const HUMAN := AqSuyekBoard.HUMAN
const BOT := AqSuyekBoard.BOT
const CELL_HEIGHT := 62
## Пауза между действиями компьютера, чтобы за ним было видно, что происходит.
const BOT_THINK := 0.7
const BOT_STEP := 0.45
## Сколько держать разбор раунда перед следующим.
const ROUND_PAUSE := 1.8

## Цвета подсказок по спецификации: чем ближе сүйек, тем горячее клетка.
const HINT_COLORS := {
	AqSuyekBoard.Hint.FOUND: Color("3e7a3e"),
	AqSuyekBoard.Hint.VERY_CLOSE: Color("b53b3b"),
	AqSuyekBoard.Hint.CLOSE: Color("cf7430"),
	AqSuyekBoard.Hint.NEAR: Color("d9a93f"),
	AqSuyekBoard.Hint.FAR: Color("3f6f93"),
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
## Индекс клетки -> её узлы. Клетки живут весь экран, меняется только их вид.
var _cells: Array = []
var _busy: bool = false
## Снимок доигранного раунда на время разбора. Поле после найденного сүйек уже
## пересобрано под следующий раунд, поэтому рисовать по `_board` нельзя: игрок
## увидел бы чистое поле и звезду на новом, ещё не найденном сүйек. Пусто —
## значит, идёт обычный ход и поле берётся у доски.
var _frozen: Dictionary = {}
var _audio: GameAudio

@onready var _play_panel: Control = %PlayPanel
@onready var _end_panel: PanelContainer = %EndPanel
@onready var _grid: GridContainer = %Grid
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
@onready var _back_btn: Button = %BackBtn

func _ready() -> void:
	_audio = GameAudio.new()
	add_child(_audio)
	_again_btn.pressed.connect(_start_game)
	_menu_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_mode_select())
	_bot = AqSuyekBot.new()
	_build_cells()
	_start_game()

# --- Поле -------------------------------------------------------------------

func _build_cells() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cells.clear()
	_grid.columns = AqSuyekBoard.GRID
	# Строки сверху вниз: y = 0 — верхний ряд, там көмбе компьютера.
	for y in AqSuyekBoard.GRID:
		for x in AqSuyekBoard.GRID:
			_grid.add_child(_make_cell(Vector2i(x, y)))

func _make_cell(cell: Vector2i) -> Control:
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, CELL_HEIGHT)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)

	var mark := Label.new()
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_override("font", SanlaqDesignTokens.FONT_BOLD)
	mark.add_theme_font_size_override("font_size", 20)
	box.add_child(mark)

	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(_on_cell_pressed.bind(cell))
	host.add_child(click)

	_cells.append({"panel": panel, "mark": mark})
	return host

func _cell_index(cell: Vector2i) -> int:
	return cell.y * AqSuyekBoard.GRID + cell.x

func _refresh_board() -> void:
	for y in AqSuyekBoard.GRID:
		for x in AqSuyekBoard.GRID:
			_refresh_cell(Vector2i(x, y))
	_update_labels()

func _refresh_cell(cell: Vector2i) -> void:
	var parts: Dictionary = _cells[_cell_index(cell)]
	var panel: PanelContainer = parts["panel"]
	var mark: Label = parts["mark"]

	var positions: Array = _view_positions()
	var here_human: bool = positions[HUMAN] == cell
	var here_bot: bool = positions[BOT] == cell
	var reachable := _is_reachable(cell)
	var hint: int = _view_revealed().get(cell, -1)

	panel.add_theme_stylebox_override("panel", _cell_style(hint, reachable, here_human or here_bot))

	# В разборе раунда сүйек важнее всего — ради этого показа разбор и держится.
	# В обычном ходе важнее фигурки: игроку нужно видеть, где он стоит.
	if not _frozen.is_empty() and cell == _frozen["bone"]:
		mark.text = "★"
		mark.add_theme_color_override("font_color", SanlaqDesignTokens.GOLD_DARK)
	elif here_human:
		mark.text = "◆"
		mark.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
	elif here_bot:
		mark.text = "▲"
		mark.add_theme_color_override("font_color", Color("b53b3b"))
	else:
		mark.text = ""

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

func _cell_style(hint: int, reachable: bool, occupied: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if hint >= 0:
		# Открытая клетка красится по подсказке, но приглушённо: цвет должен
		# читаться как след, а не как активная кнопка.
		s.bg_color = Color(HINT_COLORS[hint], 0.30)
		s.border_color = HINT_COLORS[hint]
	else:
		s.bg_color = SanlaqDesignTokens.CREAM_LIGHT
		s.border_color = Color("d8c39a")
	if reachable:
		s.border_color = SanlaqDesignTokens.GOLD_DARK
		s.set_border_width_all(4)
	elif occupied:
		s.set_border_width_all(3)
	else:
		s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(4)
	return s

func _update_labels() -> void:
	if _board == null:
		return
	_score_label.text = tr("ЕСЕП %d : %d") % [_board.scores[HUMAN], _board.scores[BOT]]
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
		var btn := Button.new()
		btn.text = tr(question.options[i])
		btn.custom_minimum_size = Vector2(0, 46)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 17)
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
	_status_label.add_theme_color_override(
		"font_color",
		SanlaqDesignTokens.GREEN_ACCENT if correct else SanlaqDesignTokens.RED_ACCENT)
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
	_status_label.add_theme_color_override(
		"font_color",
		SanlaqDesignTokens.GREEN_ACCENT if finder == HUMAN else SanlaqDesignTokens.RED_ACCENT)
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
	_status_label.add_theme_color_override(
		"font_color",
		SanlaqDesignTokens.NAVY if correct else Color(0.45, 0.42, 0.38))

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
