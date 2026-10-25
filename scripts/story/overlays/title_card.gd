extends Control
## Заставка главы: название, век, вступление. В первый раз — и как управлять.

signal done

var chapter: StoryChapter
var first_time := false


func _ready() -> void:
	var box := StoryOverlays.frame(self)
	StoryOverlays.label(box, tr(chapter.title).to_upper(), "TitleLabel")
	StoryOverlays.label(box, tr(chapter.subtitle), "SubtitleLabel")
	box.add_child(GemDivider.new())
	StoryOverlays.label(box, tr(chapter.intro), "LeadLabel", 720)
	if first_time:
		StoryOverlays.label(box, tr("WASD / стрелкалар — жүру · E — сөйлесу · Esc — үзіліс"), "CaptionLabel", 720)
	var go := StoryOverlays.button(box, tr("БАСТАУ"), "ButtonLarge", _close)
	go.ornate = true
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size.x = 320
	go.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	done.emit()
	queue_free()
