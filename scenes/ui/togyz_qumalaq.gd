extends Control
## Экран режима «Тоғыз құмалақ». Правила живут в GameBoard, выбор хода компьютера —
## в TogyzBot; здесь только отрисовка доски, анимация раздачи и передача ходов.
##
## Раскладка: нижний ряд — лунки игрока 0 слева направо (индексы 0-8), верхний ряд —
## лунки игрока 1 справа налево (индексы 9-17). Тогда раздача против часовой стрелки
## читается как непрерывный круг. Казан каждого игрока стоит на стороне соперника,
## как в настоящей игре, и подписан именем владельца.

const HUMAN := 0
const BOT := 1
const PIT_SIZE := Vector2(104, 96)
## Вся раздача должна укладываться примерно в это время, как просит спецификация.
const SOW_TOTAL := 1.4
const SOW_STEP_MAX := 0.09
const BOT_THINK_TIME := 0.55
const RESULT_PAUSE := 0.7

var _board: GameBoard
var _vs_bot: bool = false
var _animating: bool = false
## Что показано на экране прямо сейчас — во время анимации отстаёт от _board.
var _shown_pits: Array[int] = []
var _shown_kazan: Array[int] = [0, 0]
var _pit_ui: Array = []
var _audio: GameAudio

@onready var _setup_panel: PanelContainer = %SetupPanel
@onready var _board_panel: Control = %BoardPanel
@onready var _end_panel: PanelContainer = %EndPanel
@onready var _top_row: HBoxContainer = %TopRow
@onready var _bottom_row: HBoxContainer = %BottomRow
@onready var _turn_label: Label = %TurnLabel
@onready var _status_label: Label = %StatusLabel
@onready var _left_owner: Label = %LeftOwner
@onready var _left_count: Label = %LeftCount
@onready var _right_owner: Label = %RightOwner
@onready var _right_count: Label = %RightCount
@onready var _end_kicker: Label = %EndKicker
@onready var _winner_label: Label = %WinnerLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _vs_human_btn: Button = %VsHumanBtn
@onready var _vs_bot_btn: Button = %VsBotBtn
@onready var _again_btn: Button = %AgainBtn
@onready var _menu_btn: Button = %MenuBtn
@onready var _back_btn: Button = %BackBtn

func _ready() -> void:
	_audio = GameAudio.new()
	add_child(_audio)
	_vs_human_btn.pressed.connect(_start_game.bind(false))
	_vs_bot_btn.pressed.connect(_start_game.bind(true))
	_again_btn.pressed.connect(_reset_to_setup)
	_menu_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	_show_only(_setup_panel)

func _start_game(vs_bot: bool) -> void:
	_vs_bot = vs_bot
	_board = GameBoard.new()
	_animating = false
	_shown_pits = _board.pits.duplicate()
	_shown_kazan = _board.kazan.duplicate()
	_build_board()
	# Казан игрока стоит на стороне соперника: нижний игрок — справа, верхний — слева.
	_left_owner.text = _player_name(1)
	_right_owner.text = _player_name(0)
	_status_label.text = ""
	_show_only(_board_panel)
	_refresh()
	Telemetry.log_event("togyz_start", {"vs": "bot" if vs_bot else "human"})

func _player_name(player: int) -> String:
	if _vs_bot:
		return tr("Сіз") if player == HUMAN else tr("Компьютер")
	return tr("Ойыншы %d") % (player + 1)

func _build_board() -> void:
	for row: HBoxContainer in [_top_row, _bottom_row]:
		for c in row.get_children():
			row.remove_child(c)
			c.queue_free()
	_pit_ui.clear()
	_pit_ui.resize(GameBoard.PIT_COUNT)

	for i in range(0, GameBoard.PER_SIDE):
		_bottom_row.add_child(_make_pit(i))
	# Верхний ряд рисуется справа налево, чтобы круг раздачи был непрерывным.
	for i in range(GameBoard.PIT_COUNT - 1, GameBoard.PER_SIDE - 1, -1):
		_top_row.add_child(_make_pit(i))

func _make_pit(index: int) -> Control:
	var host := Control.new()
	host.custom_minimum_size = PIT_SIZE
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _pit_style())
	host.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_override("font", SanlaqDesignTokens.FONT_BOLD)
	count.add_theme_font_size_override("font_size", 30)
	count.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
	box.add_child(count)

	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28))
	caption.text = str(index % GameBoard.PER_SIDE + 1)
	box.add_child(caption)

	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(_on_pit_pressed.bind(index))
	host.add_child(click)

	_pit_ui[index] = {"panel": panel, "count": count, "caption": caption}
	return host

func _pit_style(active: bool = false, tuzdyk_of: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if tuzdyk_of >= 0:
		s.bg_color = SanlaqDesignTokens.NAVY_LIGHT
		s.border_color = SanlaqDesignTokens.GOLD
	elif active:
		s.bg_color = SanlaqDesignTokens.GOLD_PALE
		s.border_color = SanlaqDesignTokens.GOLD_DARK
	else:
		s.bg_color = SanlaqDesignTokens.CREAM_LIGHT
		s.border_color = SanlaqDesignTokens.GOLD
	s.set_border_width_all(4 if active or tuzdyk_of >= 0 else 2)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(4)
	return s

func _refresh() -> void:
	for i in GameBoard.PIT_COUNT:
		var ui: Dictionary = _pit_ui[i]
		var owner: int = _board.tuzdyk_owner[i]
		var count: Label = ui["count"]
		var caption: Label = ui["caption"]
		if owner >= 0:
			# Буква, а не «★»: гарантированно есть в шрифте проекта.
			count.text = "Т"
			count.add_theme_color_override("font_color", SanlaqDesignTokens.GOLD)
			caption.text = _player_name(owner)
			caption.add_theme_color_override("font_color", SanlaqDesignTokens.GOLD_PALE)
		else:
			count.text = str(_shown_pits[i])
			count.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
			caption.text = str(i % GameBoard.PER_SIDE + 1)
			caption.add_theme_color_override("font_color", Color(0.45, 0.38, 0.28))
		ui["panel"].add_theme_stylebox_override("panel", _pit_style(false, owner))

	_left_count.text = str(_shown_kazan[1])
	_right_count.text = str(_shown_kazan[0])
	_update_turn_label()

func _update_turn_label() -> void:
	if _board == null or _board.is_over():
		return
	if _vs_bot and _board.current_player == BOT and _animating:
		_turn_label.text = tr("Компьютер ойлап жатыр…")
	else:
		_turn_label.text = tr("Кезек: %s") % _player_name(_board.current_player)

func _on_pit_pressed(index: int) -> void:
	if _animating or _board == null or _board.is_over():
		return
	if _vs_bot and _board.current_player == BOT:
		return
	if not _board.is_legal_move(index):
		_status_label.text = tr("Бұл отаудан жүре алмайсыз")
		return
	_perform_move(index)

func _perform_move(index: int) -> void:
	_animating = true
	_status_label.text = ""
	var before_pits := _board.pits.duplicate()
	var before_kazan := _board.kazan.duplicate()
	var res: Dictionary = _board.apply_move(index)

	await _animate_sow(res, before_pits, before_kazan)
	if not is_inside_tree():
		return

	_shown_pits = _board.pits.duplicate()
	_shown_kazan = _board.kazan.duplicate()
	_refresh()
	_report(res)

	if not res["capture"].is_empty() or not res["tuzdyk"].is_empty():
		await get_tree().create_timer(RESULT_PAUSE).timeout
		if not is_inside_tree():
			return

	_animating = false

	if _board.is_over():
		_show_end()
	elif _vs_bot and _board.current_player == BOT:
		_bot_turn()
	else:
		_update_turn_label()

func _animate_sow(res: Dictionary, before_pits: Array[int], before_kazan: Array[int]) -> void:
	_shown_pits = before_pits.duplicate()
	_shown_kazan = before_kazan.duplicate()
	# Шары из выбранной лунки забраны: остался один либо ноль (правило одного шара).
	_shown_pits[res["from"]] = 1 if int(before_pits[res["from"]]) > 1 else 0
	_refresh()

	var steps: Array = res["steps"]
	if steps.is_empty():
		return
	var step_time: float = minf(SOW_STEP_MAX, SOW_TOTAL / float(steps.size()))
	for i in steps.size():
		var step: Dictionary = steps[i]
		var to_kazan: int = step["to_kazan"]
		if to_kazan >= 0:
			_shown_kazan[to_kazan] += 1
		else:
			_shown_pits[step["index"]] += 1
		_refresh()
		_highlight(step["index"], step_time)
		_audio.play_card_tone(i)
		await get_tree().create_timer(step_time).timeout
		if not is_inside_tree():
			return

func _highlight(index: int, duration: float) -> void:
	if _board.tuzdyk_owner[index] >= 0:
		return
	var ui: Dictionary = _pit_ui[index]
	var panel: PanelContainer = ui["panel"]
	panel.add_theme_stylebox_override("panel", _pit_style(true))
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_inside_tree() and is_instance_valid(panel) and _board != null:
			panel.add_theme_stylebox_override("panel", _pit_style(false, _board.tuzdyk_owner[index])))

func _report(res: Dictionary) -> void:
	var mover: int = res["player"]
	var lines: Array[String] = []
	if not res["tuzdyk"].is_empty():
		lines.append(tr("%s тұздық алды!") % _player_name(mover))
		_audio.play_echo()
	if not res["capture"].is_empty():
		lines.append(tr("%s %d құмалақ ұтып алды") % [_player_name(mover), int(res["capture"]["amount"])])
		_audio.play_catch()
	if not res["atsyrau"].is_empty():
		lines.append(tr("Атсырау: қалған құмалақтар қазанға түсті"))
	_status_label.text = " · ".join(PackedStringArray(lines))

func _bot_turn() -> void:
	_animating = true
	_update_turn_label()
	await get_tree().create_timer(BOT_THINK_TIME).timeout
	if not is_inside_tree():
		return
	var move := TogyzBot.choose_move(_board)
	_animating = false
	if move < 0:
		return
	_perform_move(move)

func _show_end() -> void:
	var winner := _board.winner()
	if winner < 0:
		_end_kicker.text = tr("ТЕҢ ТҮСТІ")
		_winner_label.text = tr("Тең ойын")
	else:
		_end_kicker.text = tr("ЖЕҢІМПАЗ")
		_winner_label.text = _player_name(winner)
	_score_label.text = "%s %d : %d %s" % [
		_player_name(0), _board.kazan[0], _board.kazan[1], _player_name(1)
	]
	if _vs_bot:
		if winner == HUMAN:
			_audio.play_victory()
		elif winner == BOT:
			_audio.play_defeat()
	Telemetry.log_event("togyz_end", {
		"vs": "bot" if _vs_bot else "human",
		"winner": winner,
		"score_0": _board.kazan[0],
		"score_1": _board.kazan[1],
	})
	_show_only(_end_panel)

func _reset_to_setup() -> void:
	_animating = false
	_board = null
	_status_label.text = ""
	_show_only(_setup_panel)

func _show_only(panel: Control) -> void:
	for p: Control in [_setup_panel, _board_panel, _end_panel]:
		p.visible = p == panel
