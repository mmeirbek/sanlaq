class_name DialogueBox
extends Control
## Окно разговора внизу экрана: портрет говорящего с язычком имени, текст
## печатается по буквам с «блипом». E, пробел, Enter или клик — дальше (или
## допечатать строку сразу). После последней строки — выбор из двух вариантов,
## клавиши 1 и 2. Окно растёт вверх по содержимому: длинная реплика и оба
## варианта всегда на экране.

signal finished
signal chose(choice: StoryChoice)

const CHARS_PER_SECOND := 45.0
const PORTRAIT_SCALE := 3
const PORTRAIT_SIZE := Vector2(144, 144)
const BLIP_EVERY := 3
## Высота окна без выбора — чтобы оно не прыгало от строки к строке.
const MIN_HEIGHT := 200.0

var _dialogue: StoryDialogue
var _line := 0
var _typed := 0.0
var _portrait_slot: Control
var _portrait: CharacterVisual
var _name_label: Label
var _text: Label
var _hint: Label
var _choices_box: VBoxContainer
var _choices_prompt: Label
var _panel: PanelContainer
var _blip: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	# Низ окна прибит к низу экрана, верх уходит вверх, сколько нужно тексту и
	# вариантам ответа (раньше высота была постоянной и выбор уезжал за экран).
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size.y = MIN_HEIGHT
	_panel.offset_left = UiTokens.SPACE_L
	_panel.offset_right = -UiTokens.SPACE_L
	_panel.offset_top = -UiTokens.SPACE_S
	_panel.offset_bottom = -UiTokens.SPACE_S
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_M)
	_panel.add_child(row)

	var frame := PanelContainer.new()
	frame.theme_type_variation = "InsetPanel"
	row.add_child(frame)
	_portrait_slot = Control.new()
	_portrait_slot.custom_minimum_size = PORTRAIT_SIZE
	_portrait_slot.clip_contents = true
	frame.add_child(_portrait_slot)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name_label = Label.new()
	_name_label.theme_type_variation = "HeadingLabel"
	column.add_child(_name_label)
	_text = Label.new()
	_text.theme_type_variation = "LeadLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text)
	_choices_prompt = Label.new()
	_choices_prompt.theme_type_variation = "WarningLabel"
	_choices_prompt.text = tr("ТАҢДА · 1 НЕМЕСЕ 2")
	_choices_prompt.visible = false
	column.add_child(_choices_prompt)
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	column.add_child(_choices_box)
	_hint = Label.new()
	_hint.theme_type_variation = "WarningLabel"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.text = tr("E · ӘРІ ҚАРАЙ")
	column.add_child(_hint)

	_blip = AudioStreamPlayer.new()
	_blip.stream = _blip_stream()
	add_child(_blip)


func show_dialogue(dialogue: StoryDialogue) -> void:
	_dialogue = dialogue
	_line = 0
	_name_label.text = tr(dialogue.speaker)
	if _portrait != null:
		_portrait.queue_free()
	_portrait = StoryLooks.create(dialogue.look)
	_portrait.scale = Vector2.ONE * PORTRAIT_SCALE
	# Видны голова и плечи: лицо (строка 10 клетки 32×32) — в середине рамки.
	_portrait.set_rest_position(Vector2(PORTRAIT_SIZE.x / 2, PORTRAIT_SIZE.y / 2 + 6 * UiTokens.PIXEL * PORTRAIT_SCALE))
	_portrait_slot.add_child(_portrait)
	visible = true
	_show_line()


func is_open() -> bool:
	return visible


func _show_line() -> void:
	_clear_choices()
	_text.text = tr(_dialogue.lines[_line]) if _line < _dialogue.lines.size() else ""
	_text.visible_characters = 0
	_typed = 0.0
	_hint.visible = false


func _process(delta: float) -> void:
	if not visible or _text.visible_characters < 0:
		return
	var before := _text.visible_characters
	_typed += delta * CHARS_PER_SECOND
	_text.visible_characters = mini(int(_typed), _text.get_total_character_count())
	if _text.visible_characters / BLIP_EVERY != before / BLIP_EVERY and not RunContext.is_headless():
		_blip.volume_db = GameSettings.get_sfx_volume_db()
		_blip.play()
	if _text.visible_characters >= _text.get_total_character_count():
		_text.visible_characters = -1
		_line_done()


func _line_done() -> void:
	var last := _line >= _dialogue.lines.size() - 1
	if last and not _dialogue.choices.is_empty():
		for i in _dialogue.choices.size():
			var button := PixelButton.new()
			button.theme_type_variation = "AnswerButton"
			button.text = "%d · %s" % [i + 1, tr(_dialogue.choices[i].label)]
			button.pressed.connect(_choose.bind(i))
			_choices_box.add_child(button)
		_choices_prompt.visible = true
		return
	_hint.visible = true


func advance() -> void:
	if not visible:
		return
	if _text.visible_characters >= 0:
		_typed = _text.get_total_character_count()
		return
	if _choices_box.get_child_count() > 0:
		return
	_line += 1
	if _line < _dialogue.lines.size():
		_show_line()
		return
	visible = false
	finished.emit()


func _choose(index: int) -> void:
	if index >= _dialogue.choices.size():
		return
	_clear_choices()
	visible = false
	chose.emit(_dialogue.choices[index])


## Убрать кнопки сразу (а не в конце кадра), чтобы окно тут же стало ниже.
func _clear_choices() -> void:
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()
	_choices_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()
	elif event is InputEventKey and event.pressed and not event.echo and _choices_box.get_child_count() > 0:
		var key := (event as InputEventKey).physical_keycode
		if key in [KEY_1, KEY_KP_1, KEY_2, KEY_KP_2]:
			get_viewport().set_input_as_handled()
			_choose(0 if key in [KEY_1, KEY_KP_1] else 1)


func _on_panel_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		advance()


## Короткий тихий меандр — голос «печатающего» текста.
static func _blip_stream() -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * 0.03)
	var data := PackedByteArray()
	data.resize(frames)
	for i in frames:
		var phase := fmod(i * 520.0 / rate, 1.0)
		var envelope := 1.0 - float(i) / frames
		data[i] = int((0.2 if phase < 0.5 else -0.2) * envelope * 127.0) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
