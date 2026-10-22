extends Control
## Экран режима «Тоғыз құмалақ». Правила живут в GameBoard, выбор хода компьютера —
## в TogyzBot; здесь только отрисовка доски, анимация раздачи и передача ходов.
## Лунку рисует TogyzPit: камешки, число, кольцо доступного хода, тұздық.
##
## Раскладка: нижний ряд — лунки игрока 0 слева направо (индексы 0-8), верхний ряд —
## лунки игрока 1 справа налево (индексы 9-17). Тогда раздача против часовой стрелки
## читается как непрерывный круг. Казан каждого игрока стоит на стороне соперника,
## как в настоящей игре, и подписан именем владельца.

const HUMAN := 0
const BOT := 1
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
## Индекс отау -> его TogyzPit.
var _pits: Array[TogyzPit] = []
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

func _ready() -> void:
	_audio = GameAudio.new()
	add_child(_audio)
	_vs_human_btn.pressed.connect(_start_game.bind(false))
	_vs_bot_btn.pressed.connect(_start_game.bind(true))
	_again_btn.pressed.connect(_reset_to_setup)
	_menu_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_mode_select)
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
		for pit in row.get_children():
			row.remove_child(pit)
			pit.queue_free()
	_pits.clear()
	_pits.resize(GameBoard.PIT_COUNT)
	for i in range(0, GameBoard.PER_SIDE):
		_bottom_row.add_child(_make_pit(i))
	# Верхний ряд рисуется справа налево, чтобы круг раздачи был непрерывным.
	for i in range(GameBoard.PIT_COUNT - 1, GameBoard.PER_SIDE - 1, -1):
		_top_row.add_child(_make_pit(i))

func _make_pit(index: int) -> TogyzPit:
	var pit := TogyzPit.new()
	pit.number = index % GameBoard.PER_SIDE + 1
	pit.pressed.connect(_on_pit_pressed.bind(index))
	_pits[index] = pit
	return pit

func _refresh() -> void:
	# Кольцо доступного хода — только у того, кто ходит сам, и не во время раздачи.
	var mover_is_human := not (_vs_bot and _board.current_player == BOT)
	var show_moves := not _animating and mover_is_human and not _board.is_over()
	for i in GameBoard.PIT_COUNT:
		var pit := _pits[i]
		pit.tuzdyk = _board.tuzdyk_owner[i] >= 0
		pit.count = _shown_pits[i]
		pit.available = show_moves and _board.is_legal_move(i)
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
		# Кольца доступных ходов — для следующего игрока.
		_refresh()

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
		_glow(step["index"], step_time)
		_audio.play_card_tone(i)
		await get_tree().create_timer(step_time).timeout
		if not is_inside_tree():
			return

## Вспышка лунки, куда только что упал камень.
func _glow(index: int, duration: float) -> void:
	var pit := _pits[index]
	pit.glowing = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(pit):
		pit.glowing = false

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
