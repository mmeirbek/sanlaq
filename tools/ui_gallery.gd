extends Control
## Витрина дизайн-системы: все варианты темы resources/ui/ui_theme.tres на
## одном экране — для ревью стиля командой. Снимок:
##     godot --path . --script tools/screenshot_screens.gd  (кадр ui_gallery)

const SAMPLE_TEXT := ("Соқыртеке қашқындарды ұстайды да, олардың киімін дұрыс атауы керек. "
	+ "Бөрік, тымақ, сәукеле, шапан, қамзол.")


func _ready() -> void:
	var background := ColorRect.new()
	background.color = UiTokens.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, UiTokens.SPACE_M)
	columns.add_theme_constant_override("separation", UiTokens.SPACE_M)
	add_child(columns)
	columns.add_child(_text_and_buttons())
	columns.add_child(_panels_and_cards())
	columns.add_child(_hud_and_inputs())


func _text_and_buttons() -> Control:
	var box := _column(PanelContainer.new())
	_add(box, _label("SAÑLAQ", "TitleLabel"))
	_add(box, _label("ОЙЫН РЕЖИМДЕРІ", "HeadingLabel"))
	_add(box, _label(SAMPLE_TEXT, "", true))
	_add(box, _label("Ескерту: мәтін Handjet қарпімен жазылады", "CaptionLabel", true))
	_add(box, GemDivider.new())
	var play := _button("ОЙНАУ", "ButtonLarge")
	play.ornate = true
	_add(box, play)
	_add(box, _button("КИІМ ШКАФЫ", ""))
	_add(box, _button("АРТҚА", "ButtonSecondary"))
	var disabled := _button("ЖАБЫҚ", "")
	disabled.disabled = true
	_add(box, disabled)
	return box.get_parent()


func _panels_and_cards() -> Control:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", UiTokens.SPACE_S)

	var parchment := PanelContainer.new()
	parchment.theme_type_variation = "ParchmentPanel"
	var text := VBoxContainer.new()
	text.add_child(_label("ОЙЫН ЕРЕЖЕСІ", "InkHeadingLabel"))
	text.add_child(_label(SAMPLE_TEXT, "InkLabel", true))
	parchment.add_child(text)
	outer.add_child(parchment)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", UiTokens.SPACE_S)
	for item in ["БӨРІК", "ТЫМАҚ", "ТАҚИЯ"]:
		var card := SelectableCard.new()
		card.selected = item == "ТАҚИЯ"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_box := VBoxContainer.new()
		card_box.add_child(_label(item, "HeadingLabel"))
		card_box.add_child(_label("Таңдалған" if card.selected else "Бас киім", "CaptionLabel"))
		card.add_child(card_box)
		cards.add_child(card)
	outer.add_child(cards)
	return outer


func _hud_and_inputs() -> Control:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", UiTokens.SPACE_S)

	var hud := PanelContainer.new()
	hud.theme_type_variation = "HudPanel"
	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", UiTokens.SPACE_M)
	hud_row.add_child(_label("ҚАЛДЫ 4/5", "HudLabel"))
	hud_row.add_child(_label("117", "TimerLabel"))
	hud.add_child(hud_row)
	outer.add_child(hud)

	var form := _column(PanelContainer.new())
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Ойыншы аты"
	_add(form, name_edit)
	var slider := HSlider.new()
	slider.value = 70
	_add(form, slider)
	for checked in [true, false]:
		var toggle := CheckButton.new()
		toggle.text = "Музыка" if checked else "Дыбыс әсерлері"
		toggle.button_pressed = checked
		_add(form, toggle)
	outer.add_child(form.get_parent())
	return outer


## Панель с вертикальной колонкой внутри; возвращает колонку.
func _column(panel: PanelContainer) -> VBoxContainer:
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	panel.add_child(box)
	return box


func _add(box: VBoxContainer, node: Control) -> void:
	box.add_child(node)


func _label(text: String, variation: String, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 200
	return label


func _button(text: String, variation: String) -> PixelButton:
	var button := PixelButton.new()
	button.text = text
	button.theme_type_variation = variation
	return button
