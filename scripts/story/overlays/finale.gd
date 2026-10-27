extends Control
## Конец главы: итог по бірлік, XP главы набегает счётчиком, сколько статей
## открыто. Дальше — главное меню, другой герой или энциклопедия.

const COUNT_SECONDS := 1.6

var state: StoryState
var cast: StoryCast
var _xp: Label
var _time := 0.0


func _ready() -> void:
	var box := StoryOverlays.frame(self)
	StoryOverlays.label(box, tr(state.chapter.finale_title), "TitleLabel")
	box.add_child(GemDivider.new())
	StoryOverlays.label(box, tr(state.finale_text()), "LeadLabel", 760)
	_xp = StoryOverlays.label(box, "", "TimerLabel")
	var opened := 0
	var total := 0
	for beat in state.chapter.beats:
		for entry_id in beat.unlock:
			total += 1
			opened += 1 if state.is_unlocked(entry_id) else 0
		for topic in beat.topics:
			total += 1
			opened += 1 if state.is_unlocked(topic.entry) else 0
	StoryOverlays.label(box, tr("Энциклопедияда ашылды: %d") % opened, "SubtitleLabel")
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiTokens.SPACE_S)
	box.add_child(buttons)
	StoryOverlays.button(buttons, tr("БАСҚА БАТЫР"), "ButtonSecondary", SceneRouter.go_to_hero_select)
	StoryOverlays.button(buttons, tr("ЭНЦИКЛОПЕДИЯ"), "ButtonSecondary", SceneRouter.go_to_codex.bind(1))
	StoryOverlays.button(buttons, tr("БАС МӘЗІР"), "Button", SceneRouter.go_to_main_menu).grab_focus.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	var shown := roundi(state.chapter_xp() * minf(1.0, _time / COUNT_SECONDS))
	_xp.text = "+%d XP" % shown
