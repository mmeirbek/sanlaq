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

var _state: State = State.SETUP
var _words: Array[GameWord] = []
var _card_panels: Array[PanelContainer] = []
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
@onready var _back_btn: Button = %BackBtn
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
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_mode_select())
	_show_only(_setup_panel)

func _start_game(player_count: int) -> void:
	_pick_words()
	if _words.is_empty():
		Telemetry.log_error("no GameWord resources found", "abai_says")
		_show_only(_play_panel)
		_status_label.text = tr("Сөздер табылмады")
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
	_card_panels.clear()
	for i in _words.size():
		_grid.add_child(_make_card(_words[i], i))

## Карточка собрана как в codex.gd: обычный Control-хост, внутри оформленная
## панель с содержимым и поверх неё прозрачная кнопка на всю площадь — так
## контейнер не спорит с раскладкой кликабельного слоя.
func _make_card(word: GameWord, index: int) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(190, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _card_style())
	card.add_child(panel)
	_card_panels.append(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 112)
	frame.add_theme_stylebox_override("panel", _photo_style())
	box.add_child(frame)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(0, 104)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not word.icon_path.is_empty():
		tex.texture = load(word.icon_path) as Texture2D
	frame.add_child(tex)

	var name_lbl := Label.new()
	name_lbl.text = word.get_name_for_lang(GameSettings.get_lang_code())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
	box.add_child(name_lbl)

	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(_on_card_pressed.bind(index))
	card.add_child(click)

	return card

func _card_style(active: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SanlaqDesignTokens.GOLD_PALE if active else SanlaqDesignTokens.CREAM_LIGHT
	s.border_color = SanlaqDesignTokens.GOLD_DARK if active else SanlaqDesignTokens.GOLD
	s.set_border_width_all(5 if active else 2)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(8)
	s.shadow_color = Color(0.04, 0.16, 0.23, 0.18)
	s.shadow_size = 9 if active else 5
	s.shadow_offset = Vector2(0, 3)
	return s

func _photo_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("ead8b0")
	s.border_color = Color("a26a2e")
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(3)
	return s

func _set_card_active(index: int, active: bool) -> void:
	if index < 0 or index >= _card_panels.size():
		return
	_card_panels[index].add_theme_stylebox_override("panel", _card_style(active))

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
	_status_label.text = tr("Абай көрсетіп жатыр — есте сақтаңыз")
	_status_label.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
	_progress_label.text = ""

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
	_show_only(_handoff_panel)

func _on_ready_pressed() -> void:
	if _state != State.HANDOFF:
		return
	_state = State.INPUT
	_show_only(_play_panel)
	_status_label.text = tr("%s — қайталаңыз") % _players[_order[_turn_pos]]["name"]
	_status_label.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
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
	_status_label.text = tr("Дұрыс!") if correct else tr("Қате!")
	_status_label.add_theme_color_override(
		"font_color",
		SanlaqDesignTokens.GREEN_ACCENT if correct else SanlaqDesignTokens.RED_ACCENT
	)
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
