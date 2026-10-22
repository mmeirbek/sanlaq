extends "res://tools/test_case.gd"
## Поведение компонентов дизайн-системы (scripts/ui/components): навигация,
## выбор, таймеры показа, диалог.

const THEME := preload("res://resources/ui/ui_theme.tres")


func _init() -> void:
	await process_frame
	root.theme = THEME
	await _test_pixel_button()
	await _test_screen_header()
	await _test_selectable_card()
	await _test_toast()
	await _test_countdown()
	await _test_banner()
	await _test_confirm_dialog()
	await _test_slot_tabs()
	await _test_clothing_card()
	_test_backdrop_scaling()
	finish("COMPONENTS")


func _test_slot_tabs() -> void:
	var tabs := SlotTabs.new()
	await _add(tabs)
	var chosen: Array = []
	tabs.slot_selected.connect(func(slot: ClothingItem.SlotType) -> void: chosen.append(slot))
	check(tabs.get_child_count() == ClothingItem.SlotType.size(), "вкладка на каждый слот одежды")
	(tabs.get_child(ClothingItem.SlotType.SHOES) as SelectableCard).pressed.emit()
	check(chosen == [ClothingItem.SlotType.SHOES], "нажатие вкладки сообщает её слот")
	var selected := tabs.get_children().filter(func(card: Node) -> bool: return (card as SelectableCard).selected)
	check(selected.size() == 1 and selected[0] == tabs.get_child(ClothingItem.SlotType.SHOES),
		"выбрана ровно одна вкладка — нажатая")
	tabs.hint = "подсказка"
	check((tabs.get_child(0) as Control).tooltip_text == "подсказка", "подсказка доходит до готовых вкладок")
	await unmount(tabs)


func _test_clothing_card() -> void:
	var item := load("res://data/clothing/head_borik_01.tres") as ClothingItem
	var card := ClothingCard.create(item, "Бөрік")
	await _add(card)
	var icon := card.find_children("*", "TextureRect", true, false)
	var label := card.find_children("*", "Label", true, false)
	check(icon.size() == 1 and (icon[0] as TextureRect).texture != null, "у карточки предмета есть иконка")
	check(label.size() == 1 and (label[0] as Label).text == "Бөрік", "у карточки предмета есть название")
	check(card.theme_type_variation == "CardCompact", "карточка предмета компактная")
	await unmount(card)


func _test_pixel_button() -> void:
	var button := await _add(PixelButton.new()) as PixelButton
	check(button.get_combined_minimum_size().y >= UiTokens.TOUCH_MIN, "кнопка не ниже TOUCH_MIN")
	button.ornate = true
	var caps := button.get_children(true).filter(func(n: Node) -> bool: return n is TextureRect)
	check(caps.size() == 2, "у кнопки ornate два навершия, получено %d" % caps.size())
	button.ornate = false
	await process_frame
	caps = button.get_children(true).filter(func(n: Node) -> bool: return n is TextureRect and not n.is_queued_for_deletion())
	check(caps.is_empty(), "навершия убираются вместе с ornate")
	await unmount(button)


func _test_screen_header() -> void:
	var header := ScreenHeader.new()
	header.title = "РЕЖИМДЕР"
	await _add(header)
	var backs := [0]
	header.back_pressed.connect(func() -> void: backs[0] += 1)
	_press_action("ui_cancel")
	check(backs[0] == 1, "Esc в шапке — это «Артқа»")
	header.show_back = false
	_press_action("ui_cancel")
	check(backs[0] == 1, "без кнопки «Артқа» Esc шапка не перехватывает")
	await unmount(header)


func _test_selectable_card() -> void:
	var card := await _add(SelectableCard.new()) as SelectableCard
	card.custom_minimum_size = Vector2(200, 120)
	await process_frame
	check(card.theme_type_variation == "Card", "невыбранная карточка — Card")
	card.selected = true
	check(card.theme_type_variation == "CardSelected", "выбранная карточка — CardSelected")
	var presses := [0]
	card.pressed.connect(func() -> void: presses[0] += 1)
	_click(card.get_global_rect().get_center())
	check(presses[0] == 1, "клик по карточке шлёт pressed")
	await unmount(card)


func _test_toast() -> void:
	var toast := await _add(Toast.new()) as Toast
	toast.show_message("бірінші", 0.2)
	toast.show_message("екінші", 0.6)
	await create_timer(0.35).timeout
	check(toast.visible and toast.current_text() == "екінші",
		"новое сообщение заменяет старое, и старый таймер его не прячет")
	await create_timer(0.4).timeout
	check(not toast.visible, "тост прячется по своему таймеру")
	await unmount(toast)


func _test_countdown() -> void:
	var countdown := Countdown.new()
	countdown.step_time = 0.1
	await _add(countdown)
	var seen: Array[String] = []
	var finished := [false]
	countdown.finished.connect(func() -> void: finished[0] = true)
	countdown.start(3)
	for _i in 8:
		if countdown.current_text() not in seen:
			seen.append(countdown.current_text())
		await create_timer(0.05).timeout
	await create_timer(0.2).timeout
	check(seen.slice(0, 3) == ["3", "2", "1"], "отсчёт идёт 3, 2, 1: %s" % [seen])
	check(finished[0] and not countdown.visible, "после «БАСТА!» отсчёт закончился и спрятан")
	await unmount(countdown)


func _test_banner() -> void:
	var banner := await _add(Banner.new()) as Banner
	var finished := [0]
	banner.finished.connect(func() -> void: finished[0] += 1)
	banner.show_banner("ЖЕҢІС!", "", 0.1)
	check(banner.visible, "баннер показан")
	# Второй показ до конца первого: первый не должен спрятать баннер раньше времени.
	await create_timer(0.2).timeout
	banner.show_banner("ЖЕҢІЛДІҢ", "", 0.4)
	await create_timer(0.3).timeout
	check(banner.visible, "новый показ не обрывается таймером прошлого")
	await create_timer(0.8).timeout
	check(not banner.visible and finished[0] == 1, "баннер свернулся один раз, получено %d" % finished[0])
	await unmount(banner)


func _test_confirm_dialog() -> void:
	var dialog := ConfirmDialog.new()
	dialog.dialog_title = "ШЫҒУ"
	await _add(dialog)
	var outcome := [""]
	dialog.confirmed.connect(func() -> void: outcome[0] = "confirmed")
	dialog.cancelled.connect(func() -> void: outcome[0] = "cancelled")
	dialog.open()
	check(dialog.visible, "диалог открыт")
	_press_action("ui_cancel")
	check(outcome[0] == "cancelled" and not dialog.visible, "Esc в диалоге — это «Жоқ»")
	dialog.open()
	_press_action("ui_accept")
	check(outcome[0] == "cancelled", "Enter по умолчанию жмёт безопасное «Жоқ», а не «Иә»")
	await unmount(dialog)


## Фон встаёт в целом масштабе по центру на любом экране.
func _test_backdrop_scaling() -> void:
	var picture := Vector2(1280, 720)
	var cases := {
		"16:9": [Vector2(1280, 720), Rect2(0, 0, 1280, 720)],
		"телефон 19.5:9": [Vector2(1560, 720), Rect2(140, 0, 1280, 720)],
		"планшет 4:3": [Vector2(1280, 960), Rect2(0, 120, 1280, 720)],
		"2K": [Vector2(2560, 1440), Rect2(0, 0, 2560, 1440)],
	}
	for screen: String in cases:
		var got := PixelBackdrop.picture_rect(picture, cases[screen][0])
		check(got == cases[screen][1], "фон на экране %s: %s" % [screen, got])


func _add(node: Control) -> Control:
	root.add_child(node)
	await process_frame
	return node


func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventAction
	release.pressed = false
	root.push_input(release)


## Клик в координатах вьюпорта. В headless окно 64×64, и растяжка canvas_items
## пересчитывает оконные координаты — поэтому in_local_coords = true.
func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		root.push_input(event, true)
