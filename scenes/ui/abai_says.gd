extends Control
## «Абай айтады» — режим на запоминание тізбек (механика Simon Says) на материале
## названий национальных блюд. 2-4 игрока, pass-and-play на одном устройстве.
##
## Раунд: Абай показывает последовательность → каждый активный игрок по очереди
## повторяет её. Ошибившиеся помечаются, но доигрывают раунд до конца и вылетают
## все вместе в конце раунда (вариант А из спецификации).

enum State { SETUP, SHOWING, HANDOFF, INPUT, GAME_END }

## Сколько карточек на поле. Берутся случайно из пула слов один раз за партию,
## чтобы игроки запоминали именно этот набор.
const CARD_COUNT := 6
## Длина тізбек в первом раунде; дальше +1 за раунд.
const START_LENGTH := 2
const SHOW_ON := 0.55
const SHOW_GAP := 0.22
const TAP_FLASH := 0.18
const FEEDBACK_TIME := 0.9
## Иконка 32×32 пикселя арта уже сохранена ×2; на карточке — ещё ×2.
const ICON_SCALE := 2
const CARD_WIDTH := 208
const CROSS := preload("res://assets/ui/frames/cross.png")

var _state: State = State.SETUP
var _words: Array[GameWord] = []
var _cards: Array[SelectableCard] = []
var _sequence: Array[int] = []
var _round: int = 0
## Каждый игрок: {name: String, active: bool, failed: bool}
var _players: Array[Dictionary] = []
## Порядок хода — перемешивается один раз за партию и дальше не меняется.
var _order: Array[int] = []
var _turn_pos: int = 0
var _input_pos: int = 0
var _busy: bool = false
var _audio: GameAudio

@onready var _setup_panel: PanelContainer = %SetupPanel
@onready var _play_panel: Control = %PlayPanel
@onready var _handoff_panel: PanelContainer = %HandoffPanel
@onready var _end_panel: PanelContainer = %EndPanel
@onready var _grid: GridContainer = %CardGrid
@onready var _players_row: HBoxContainer = %PlayersRow
@onready var _round_label: Label = %RoundLabel
@onready var _status_label: Label = %StatusLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _handoff_name: Label = %HandoffName
@onready var _ready_btn: Button = %ReadyBtn
@onready var _end_kicker: Label = %EndKicker
@onready var _winner_label: Label = %WinnerLabel
@onready var _rounds_label: Label = %RoundsLabel
@onready var _again_btn: Button = %AgainBtn
@onready var _menu_btn: Button = %MenuBtn
@onready var _p2_btn: Button = %P2Btn
@onready var _p3_btn: Button = %P3Btn
@onready var _p4_btn: Button = %P4Btn

func _ready() -> void:
	_audio = GameAudio.new()
	add_child(_audio)
	_p2_btn.pressed.connect(_start_game.bind(2))
	_p3_btn.pressed.connect(_start_game.bind(3))
	_p4_btn.pressed.connect(_start_game.bind(4))
	_ready_btn.pressed.connect(_on_ready_pressed)
	_again_btn.pressed.connect(_reset_to_setup)
	_menu_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_mode_select)
	_show_only(_setup_panel)

func _start_game(player_count: int) -> void:
	_pick_words()
	if _words.is_empty():
		Telemetry.log_error("no GameWord resources found", "abai_says")
		_show_only(_play_panel)
		_set_status(tr("Сөздер табылмады"), UiTokens.DANGER)
		return

	_build_cards()
	_players.clear()
	_order.clear()
	for i in player_count:
		_players.append({"name": tr("Ойыншы %d") % (i + 1), "active": true, "failed": false})
		_order.append(i)
	_order.shuffle()
	_sequence.clear()
	_round = 0
	Telemetry.log_event("abai_start", {"players": player_count})
	_next_round()

func _pick_words() -> void:
	var pool := AssetRegistry.get_words("food")
	pool.shuffle()
	_words.clear()
	for w in pool:
		if _words.size() >= CARD_COUNT:
			break
		_words.append(w)

func _build_cards() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cards.clear()
	for i in _words.size():
		_grid.add_child(_make_card(_words[i], i))

## Карточка блюда: иконка ×2 (целый масштаб) и название. Подсветка показа и
## нажатия — выбранный вид карточки из темы.
func _make_card(word: GameWord, index: int) -> SelectableCard:
	var card := SelectableCard.new()
	card.compact = true
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_on_card_pressed.bind(index))
	_cards.append(card)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var icon := TextureRect.new()
	icon.texture = load(word.icon_path) as Texture2D if not word.icon_path.is_empty() else null
	if icon.texture != null:
		icon.custom_minimum_size = icon.texture.get_size() * ICON_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = word.get_name_for_lang(GameSettings.get_lang_code())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_lbl)
	return card

func _set_card_active(index: int, active: bool) -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards[index].selected = active

## Полоса игроков в порядке хода: ходящий — золотой карточкой, ошибившийся в
## этом раунде — с крестиком, выбывший — приглушённым именем.
func _update_players() -> void:
	for chip in _players_row.get_children():
		_players_row.remove_child(chip)
		chip.queue_free()
	var current := -1
	if _state == State.HANDOFF or _state == State.INPUT:
		current = _order[_turn_pos]
	for i in _order:
		var p: Dictionary = _players[i]
		var chip := PanelContainer.new()
		chip.theme_type_variation = "CardCompactSelected" if i == current else "CardCompact"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiTokens.SPACE_XS)
		chip.add_child(row)
		var name_lbl := Label.new()
		name_lbl.text = p["name"]
		name_lbl.theme_type_variation = "HudLabel" if p["active"] else "CaptionLabel"
		if i == current:
			name_lbl.add_theme_color_override("font_color", UiTokens.GOLD_LIGHT)
		row.add_child(name_lbl)
		if p["active"] and p["failed"]:
			var cross := TextureRect.new()
			cross.texture = CROSS
			cross.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(cross)
		_players_row.add_child(chip)

func _set_status(text: String, color: Color = UiTokens.CREAM) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)

func _next_round() -> void:
	_round += 1
	for p in _players:
		p["failed"] = false
	# Тізбек наращивается, а не генерируется заново: раунд N = N + 1 элементов.
	var target := START_LENGTH + _round - 1
	while _sequence.size() < target:
		_sequence.append(randi() % _words.size())
	_show_sequence()

func _show_sequence() -> void:
	_state = State.SHOWING
	_busy = true
	_show_only(_play_panel)
	_round_label.text = tr("%d-РАУНД") % _round
	_set_status(tr("Абай көрсетіп жатыр — есте сақтаңыз"))
	_progress_label.text = ""
	_update_players()

	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	for idx in _sequence:
		_set_card_active(idx, true)
		_audio.play_word(_words[idx].sound_path, idx)
		await get_tree().create_timer(SHOW_ON).timeout
		if not is_inside_tree():
			return
		_set_card_active(idx, false)
		await get_tree().create_timer(SHOW_GAP).timeout
		if not is_inside_tree():
			return

	_busy = false
	_begin_turn(0)

func _begin_turn(pos: int) -> void:
	_turn_pos = pos
	while _turn_pos < _order.size() and not _players[_order[_turn_pos]]["active"]:
		_turn_pos += 1
	if _turn_pos >= _order.size():
		_evaluate_round()
		return
	_state = State.HANDOFF
	_input_pos = 0
	_handoff_name.text = _players[_order[_turn_pos]]["name"]
	_update_players()
	_show_only(_handoff_panel)

func _on_ready_pressed() -> void:
	if _state != State.HANDOFF:
		return
	_state = State.INPUT
	_show_only(_play_panel)
	_set_status(tr("%s — қайталаңыз") % _players[_order[_turn_pos]]["name"])
	_update_players()
	_update_progress()

func _on_card_pressed(index: int) -> void:
	if _state != State.INPUT or _busy:
		return
	_audio.play_word(_words[index].sound_path, index)
	_flash_card(index)
	if index == _sequence[_input_pos]:
		_input_pos += 1
		_update_progress()
		if _input_pos >= _sequence.size():
			_finish_turn(true)
	else:
		_finish_turn(false)

func _flash_card(index: int) -> void:
	_set_card_active(index, true)
	var timer := get_tree().create_timer(TAP_FLASH)
	timer.timeout.connect(func() -> void:
		if is_inside_tree():
			_set_card_active(index, false))

func _finish_turn(correct: bool) -> void:
	_busy = true
	if not correct:
		_players[_order[_turn_pos]]["failed"] = true
	if correct:
		_set_status(tr("Дұрыс!"), UiTokens.SUCCESS)
	else:
		_set_status(tr("Қате!"), UiTokens.DANGER)
		_update_players()
	await get_tree().create_timer(FEEDBACK_TIME).timeout
	if not is_inside_tree():
		return
	_busy = false
	_begin_turn(_turn_pos + 1)

func _evaluate_round() -> void:
	var entered: Array[int] = []
	var survivors: Array[int] = []
	for i in _players.size():
		if _players[i]["active"]:
			entered.append(i)
			if not _players[i]["failed"]:
				survivors.append(i)

	Telemetry.log_event("abai_round", {"round": _round, "survivors": survivors.size()})

	if survivors.size() == 1:
		_end_game(survivors)
		return
	# Все оставшиеся ошиблись в одном раунде — победителями считаются все, кто в
	# этот раунд вошёл (ничья), потому что последний успешный раунд они прошли.
	if survivors.is_empty():
		_end_game(entered)
		return

	for i in _players.size():
		_players[i]["active"] = i in survivors
	_next_round()

func _end_game(winners: Array) -> void:
	_state = State.GAME_END
	var names := PackedStringArray()
	for i in winners:
		names.append(_players[i]["name"])
	_end_kicker.text = tr("ЖЕҢІМПАЗ") if names.size() == 1 else tr("ТЕҢ ТҮСТІ")
	_winner_label.text = " · ".join(names) if not names.is_empty() else "—"
	_rounds_label.text = tr("Жеткен раунд: %d") % _round
	Telemetry.log_event("abai_end", {"rounds": _round, "winners": names.size()})
	_show_only(_end_panel)

func _reset_to_setup() -> void:
	_state = State.SETUP
	_busy = false
	_sequence.clear()
	_players.clear()
	_order.clear()
	_round = 0
	_show_only(_setup_panel)

func _update_progress() -> void:
	_progress_label.text = "%d / %d" % [_input_pos, _sequence.size()]

func _show_only(panel: Control) -> void:
	for p: Control in [_setup_panel, _play_panel, _handoff_panel, _end_panel]:
		p.visible = p == panel
