class_name StoryOverlays
extends RefCounted
## Экраны поверх мира «Тарих жолы»: заставка главы, костёр, карта маршрута,
## финал. Каждый — Control с сигналом done (финал уводит с экрана сам).

const OVERLAYS := "res://scripts/story/overlays/%s.gd"


static func title_card(chapter: StoryChapter, first_time: bool) -> Control:
	var card: Control = load(OVERLAYS % "title_card").new()
	card.set("chapter", chapter)
	card.set("first_time", first_time)
	return card


## story — мир сюжета: костёр зовёт его разговор и открывает статьи.
static func campfire(story: Node, beat: StoryBeat) -> Control:
	var fire: Control = load(OVERLAYS % "campfire").new()
	fire.set("story", story)
	fire.set("beat", beat)
	return fire


static func route_map(title: String, goal: String, start: String, finish: String,
		route: PackedVector2Array) -> Control:
	var map: Control = load(OVERLAYS % "route_map").new()
	map.set("title", title)
	map.set("goal", goal)
	map.set("start", start)
	map.set("finish", finish)
	map.set("route", route)
	return map


static func finale(state: StoryState, cast: StoryCast) -> Control:
	var screen: Control = load(OVERLAYS % "finale").new()
	screen.set("state", state)
	screen.set("cast", cast)
	return screen


## Общая основа: затемнение на весь экран и панель по центру.
static func frame(overlay: Control, dim_alpha := 0.85) -> VBoxContainer:
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTokens.OUTLINE, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.SPACE_S)
	panel.add_child(box)
	return box


static func label(parent: Control, text: String, variation: String, width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		l.custom_minimum_size.x = width
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


static func button(parent: Control, text: String, variation: String, action: Callable) -> PixelButton:
	var b := PixelButton.new()
	b.text = text
	b.theme_type_variation = variation
	b.pressed.connect(action)
	parent.add_child(b)
	return b
