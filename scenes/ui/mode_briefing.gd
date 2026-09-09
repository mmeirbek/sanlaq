extends Control
## Экран-объяснение, который показывается перед каждым режимом: как играется и
## каким навыкам учит. Общий для всех режимов — содержание берётся из ресурса
## `ModeBriefing` в `data/briefings/` по id, который передал экран выбора.
##
## Текст локализуется обычным `tr()`: строки в ресурсе хранятся по-казахски и
## они же являются ключами в `assets/i18n/ui_strings.csv`.
##
## Озвучка идёт строка за строкой, подсвечивая ту, которую читают. Если голоса
## нет вовсе, подсветка всё равно проходит по строкам в темпе чтения — экран
## одинаково работает и со звуком, и без него.

## Куда вести после брифинга.
const ROUTES := {
	"sokyroteke": "chase",
	"abai_says": "abai",
	"togyz_qumalaq": "togyz",
}

var _briefing: ModeBriefing
var _narration: Narration
var _line_labels: Array[Label] = []
var _spoken: Array[String] = []
var _current_line: int = -1
var _playing: bool = false

@onready var _background: SanlaqSceneBackdrop = $Background
@onready var _kicker: Label = %Kicker
@onready var _title: Label = %Title
@onready var _steps_box: VBoxContainer = %StepsBox
@onready var _skills_box: VBoxContainer = %SkillsBox
@onready var _voice_btn: Button = %VoiceBtn
@onready var _start_btn: Button = %StartBtn
@onready var _back_btn: Button = %BackBtn

func _ready() -> void:
	_narration = Narration.new()
	add_child(_narration)
	_narration.line_finished.connect(_on_line_finished)

	_start_btn.pressed.connect(_on_start_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_voice_btn.pressed.connect(_on_voice_pressed)

	_briefing = AssetRegistry.get_briefing(SceneRouter.get_pending_briefing())
	if _briefing == null:
		# Без ресурса объяснять нечего — не запираем игрока на пустом экране.
		Telemetry.log_error("no ModeBriefing resource", "mode_briefing")
		SceneRouter.go_to_mode_select()
		return

	_background.set_variant(_briefing.backdrop as SanlaqSceneBackdrop.Variant)
	_kicker.text = tr(_briefing.kicker)
	_title.text = tr(_briefing.title)
	_build_lines()
	Telemetry.log_event("briefing_open", {"mode": _briefing.id})
	_start_narration()

func _build_lines() -> void:
	for box: VBoxContainer in [_steps_box, _skills_box]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_line_labels.clear()
	_spoken = _briefing.spoken_lines()

	for i in _briefing.how_to_play.size():
		_steps_box.add_child(_make_line(str(i + 1), _briefing.how_to_play[i], _line_labels.size()))
	for i in _briefing.skills.size():
		_skills_box.add_child(_make_line("•", _briefing.skills[i], _line_labels.size()))

	# Кнопка озвучки нужна, только если голос вообще есть.
	var ids := PackedStringArray()
	for i in _spoken.size():
		ids.append(_briefing.voice_id(i))
	_voice_btn.visible = _narration.has_voice(ids)

## Строка объяснения: номер (или буллет) слева, текст справа. По клику озвучка
## перескакивает на эту строку — так можно переслушать любой пункт.
func _make_line(marker: String, source: String, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var num := Label.new()
	num.custom_minimum_size = Vector2(26, 0)
	num.text = marker
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# По верхнему краю: иначе у многострочного пункта номер уезжает на середину.
	num.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	num.size_flags_vertical = Control.SIZE_FILL
	num.add_theme_font_override("font", SanlaqDesignTokens.FONT_BOLD)
	num.add_theme_font_size_override("font_size", 18)
	num.add_theme_color_override("font_color", SanlaqDesignTokens.GOLD_DARK)
	row.add_child(num)

	var text := Label.new()
	text.text = tr(source)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 17)
	text.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
	row.add_child(text)
	_line_labels.append(text)

	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(_speak_line.bind(index))

	var host := MarginContainer.new()
	host.add_child(row)
	host.add_child(click)
	return host

func _set_line_active(index: int, active: bool) -> void:
	if index < 0 or index >= _line_labels.size():
		return
	var label := _line_labels[index]
	label.add_theme_color_override(
		"font_color",
		SanlaqDesignTokens.GOLD_DARK if active else SanlaqDesignTokens.NAVY)

func _start_narration() -> void:
	if _spoken.is_empty():
		return
	_playing = true
	_speak_line(0)

func _speak_line(index: int) -> void:
	_set_line_active(_current_line, false)
	if index < 0 or index >= _spoken.size():
		_current_line = -1
		_playing = false
		_update_voice_btn()
		return
	_playing = true
	_current_line = index
	_set_line_active(index, true)
	_update_voice_btn()
	_narration.speak(_briefing.voice_id(index), tr(_spoken[index]))

func _on_line_finished() -> void:
	if not _playing:
		return
	_speak_line(_current_line + 1)

func _stop_narration() -> void:
	_narration.stop()
	_set_line_active(_current_line, false)
	_current_line = -1
	_playing = false
	_update_voice_btn()

func _update_voice_btn() -> void:
	_voice_btn.text = tr("Дыбысты тоқтату") if _playing else tr("Дыбыстық сүйемелдеу")

func _on_voice_pressed() -> void:
	if _playing:
		_stop_narration()
	else:
		_start_narration()

func _on_start_pressed() -> void:
	_stop_narration()
	Telemetry.log_event("briefing_start", {"mode": _briefing.id})
	match ROUTES.get(_briefing.id, ""):
		"chase":
			SceneRouter.go_to_lobby({"mode": "classic", "bots": 3})
		"abai":
			SceneRouter.go_to_abai_says()
		"togyz":
			SceneRouter.go_to_togyz_qumalaq()
		_:
			Telemetry.log_error("unknown briefing route for %s" % _briefing.id, "mode_briefing")
			SceneRouter.go_to_mode_select()

func _on_back_pressed() -> void:
	_stop_narration()
	SceneRouter.go_to_mode_select()

func _exit_tree() -> void:
	if _narration != null:
		_narration.stop()
