extends Control
## Вечер у костра: ақсақал рассказывает. Каждая тема — разговор и статья
## энциклопедии. Когда выслушаны все темы, можно идти дальше.

signal done

const FIRE := [
	preload("res://assets/sprites/story/campfire_0.png"),
	preload("res://assets/sprites/story/campfire_1.png"),
]
const FIRE_SCALE := 4

var story: Node
var beat: StoryBeat
var _heard := {}
var _buttons: Array[PixelButton] = []
var _continue: PixelButton
var _fire: TextureRect
var _time := 0.0


func _ready() -> void:
	var box := StoryOverlays.frame(self, 0.92)
	StoryOverlays.label(box, tr(beat.campfire_title).to_upper(), "TitleLabel")
	_fire = TextureRect.new()
	_fire.texture = FIRE[0]
	_fire.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fire.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fire.custom_minimum_size = FIRE[0].get_size() * FIRE_SCALE / 2
	box.add_child(_fire)
	StoryOverlays.label(box, tr("Ақсақалдан не сұрайсың?"), "SubtitleLabel")
	for topic in beat.topics:
		var b := StoryOverlays.button(box, tr(topic.label), "AnswerButton", _ask.bind(topic))
		_buttons.append(b)
	_continue = StoryOverlays.button(box, tr("ЖАЛҒАСТЫРУ"), "ButtonLarge", _close)
	_continue.visible = false
	_buttons[0].grab_focus.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	_fire.texture = FIRE[int(_time * 5.0) % 2]


func _ask(topic: CampfireTopic) -> void:
	visible = false
	story.speak(story.state.dialogue(topic.dialogue), _heard_topic.bind(topic))


func _heard_topic(topic: CampfireTopic) -> void:
	visible = true
	# Разговор отпустил мир — пока костёр открыт, держим его.
	story.busy = true
	if not _heard.has(topic.label):
		_heard[topic.label] = true
		if story.state.unlock_entry(topic.entry):
			story.get_node("%Hud").toast(tr("ЭНЦИКЛОПЕДИЯ: %s") % tr(story._entry_title(topic.entry)))
		SaveManager.save_story()
	for i in beat.topics.size():
		_buttons[i].disabled = _heard.has(beat.topics[i].label)
	_continue.visible = _heard.size() >= beat.topics.size()
	if _continue.visible:
		_continue.grab_focus()


func _close() -> void:
	done.emit()
	queue_free()
