extends Control
## Выбор героя «Дала жолы»: три карты — Керей, Абылай, Қабанбай. На карте —
## герой, век, девиз, прогресс главы и кнопка: БАСТАУ, ЖАЛҒАСТЫРУ или ҚАЙТА ОЙНАУ.

const PORTRAIT_SCALE := 3

@onready var _cards: HBoxContainer = %Cards


func _ready() -> void:
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_mode_select)
	var cast := AssetRegistry.get_story_cast()
	var heroes := cast.heroes.duplicate()
	heroes.sort_custom(func(a: StoryHero, b: StoryHero) -> bool: return a.order < b.order)
	var first: PixelButton = null
	for hero: StoryHero in heroes:
		var button := _card(hero)
		if first == null:
			first = button
	first.grab_focus.call_deferred()


func _card(hero: StoryHero) -> PixelButton:
	var chapter := AssetRegistry.get_story_chapter(hero.chapter)
	var state := StoryState.new(chapter, SaveManager.story.duplicate(true))
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTokens.SPACE_XS)
	card.add_child(box)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 64 * PORTRAIT_SCALE)
	box.add_child(stage)
	var visual := StoryLooks.create(hero.look)
	visual.scale = Vector2.ONE * PORTRAIT_SCALE
	stage.add_child(visual)
	stage.resized.connect(func() -> void:
		var step := UiTokens.PIXEL * PORTRAIT_SCALE
		visual.set_rest_position((Vector2(stage.size.x / 2, stage.size.y / 2 + 8) / step).floor() * step))

	StoryOverlays.label(box, tr(hero.era), "CaptionLabel")
	StoryOverlays.label(box, tr(hero.name).to_upper(), "HeadingLabel")
	StoryOverlays.label(box, tr(hero.tagline), "WarningLabel")
	var description := StoryOverlays.label(box, tr(hero.description), "", 280)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var progress := StoryOverlays.label(box, tr(chapter.title), "CaptionLabel")
	var bar := TimeBar.new()
	bar.ratio = float(state.beat_index()) / state.beat_count() if not state.is_complete() else 1.0
	box.add_child(bar)
	if state.is_complete():
		progress.text += "  ·  " + tr("АЯҚТАЛДЫ")

	var text := "БАСТАУ"
	if state.is_complete():
		text = "ҚАЙТА ОЙНАУ"
	elif state.beat_index() > 0:
		text = "ЖАЛҒАСТЫРУ"
	return StoryOverlays.button(box, tr(text), "Button", _start.bind(hero, state.is_complete()))


func _start(hero: StoryHero, restart: bool) -> void:
	SaveManager.story["hero"] = hero.id
	if restart:
		StoryState.new(AssetRegistry.get_story_chapter(hero.chapter), SaveManager.story).restart()
	SaveManager.save_story()
	Telemetry.log_event("story_start", {"hero": hero.id, "restart": restart})
	SceneRouter.go_to_story_world()
