extends Control
## Обучение при первом запуске (этап 6.1): поверх главного меню три карточки с
## картинками — что делать в САҢЛАҚ. Закрывается кнопкой «ТҮСІНІКТІ» или Esc
## и больше не показывается: флаг onboarding_done в сохранении.
##
## Обращается к SaveManager — в тестах этот скрипт нельзя писать как тип.

signal closed

const SETTING := "onboarding_done"
## Картинка, заголовок, текст.
const CARDS := [
	["res://assets/sprites/modes/role_runner.png", "АТЫҢДЫ ЖАЗ",
		"Басты мәзірде атыңды жаз — ол ойында сенің кейіпкеріңнің үстінде тұрады."],
	["res://assets/sprites/modes/togyz_qumalaq.png", "ОЙЫН ТАҢДА",
		"Төрт ұлттық ойын бар. Әр ойын алдында қалай ойналатыны суретпен түсіндіріледі."],
	["res://assets/sprites/items/head_saukele_01.png", "КИІМ МЕН МҰРА",
		"Киім шкафында кейіпкеріңді киіндір, энциклопедияда әр киімнің тарихын оқы."],
]

var _ok_button: PixelButton


static func should_show() -> bool:
	return not bool(SaveManager.get_setting(SETTING, false))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = ConfirmDialog.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	panel.add_child(box)

	var title := Label.new()
	title.text = tr("САҢЛАҚҚА ҚОШ КЕЛДІҢ!")
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(GemDivider.new())

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", UiTokens.SPACE_S)
	box.add_child(cards)
	for i in CARDS.size():
		cards.add_child(_card(i + 1, CARDS[i][0], CARDS[i][1], CARDS[i][2]))

	_ok_button = PixelButton.new()
	_ok_button.text = tr("ТҮСІНІКТІ")
	_ok_button.theme_type_variation = "ButtonLarge"
	_ok_button.ornate = true
	_ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ok_button.custom_minimum_size.x = 320
	_ok_button.pressed.connect(close)
	box.add_child(_ok_button)
	_ok_button.grab_focus.call_deferred()


func close() -> void:
	SaveManager.set_setting(SETTING, true)
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _card(number: int, picture: String, heading: String, text: String) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	card.add_child(box)

	var art := TextureRect.new()
	art.texture = load(picture) as Texture2D
	# Персонаж и иконка (64 px) — в целом ×2, картинка режима — как есть.
	var scale := 2 if art.texture.get_height() <= 64 else 1
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, art.texture.get_height() * scale)
	box.add_child(art)
	var head := Label.new()
	head.text = "%d  %s" % [number, tr(heading)]
	head.theme_type_variation = "HeadingLabel"
	box.add_child(head)
	var body := Label.new()
	body.text = tr(text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 260
	box.add_child(body)
	return card
