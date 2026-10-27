extends "res://tools/test_case.gd"
## На английском на экранах не остаётся казахского текста (этап 6.4). Экраны,
## пауза и обучение открываются в локали en; любой видимый текст с кириллицей —
## строка без перевода в assets/i18n/ui_strings.csv.

const SCREENS := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/mode_select.tscn",
	"res://scenes/ui/lobby.tscn",
	"res://scenes/ui/wardrobe.tscn",
	"res://scenes/ui/codex.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/about.tscn",
	"res://scenes/ui/results.tscn",
	"res://scenes/ui/abai_says.tscn",
	"res://scenes/ui/togyz_qumalaq.tscn",
	"res://scenes/ui/aq_suyek.tscn",
	"res://scenes/story/hero_select.tscn",
]
## Подписи, которые нарочно на двух языках.
const BILINGUAL := ["ENG / АҒЫЛ", "ҚАЗ / KAZ"]

var _cyrillic := RegEx.create_from_string("[\\x{0400}-\\x{04FF}]")


func _init() -> void:
	await process_frame
	# Язык меняется как в настройках: локаль и язык данных (одежда, слова).
	var settings := autoload("GameSettings")
	var was_language: int = settings.current_language
	settings.set_language(settings.Language.EN)
	for path: String in SCREENS:
		var n := await mount(path)
		if n == null:
			continue
		_check_texts(n, path.get_file())
		await unmount(n)

	var host := Control.new()
	root.add_child(host)
	var pause: Control = load("res://scripts/ui/components/pause_menu.gd").new()
	host.add_child(pause)
	await process_frame
	pause.call("open")
	pause.call("_toggle_settings")
	_check_texts(pause, "пауза")
	pause.call("resume")
	var welcome: Control = load("res://scripts/ui/welcome_overlay.gd").new()
	host.add_child(welcome)
	await process_frame
	_check_texts(welcome, "обучение")
	host.queue_free()
	await _check_story()

	settings.set_language(was_language)
	finish("LOCALIZATION")


func _check_texts(node: Node, where: String) -> void:
	var untranslated: PackedStringArray = []
	for control: Control in node.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree():
			continue
		var text := ""
		if control is Label:
			text = (control as Label).text
		elif control is Button:
			text = (control as Button).text
		elif control is LineEdit:
			text = (control as LineEdit).placeholder_text
		text = control.atr(text)
		if text in BILINGUAL or _cyrillic.search(text) == null:
			continue
		untranslated.append(text.substr(0, 50))
	for text in untranslated:
		print("[test]    .. без перевода (%s): %s" % [where, text])
	check(untranslated.is_empty(), "%s: на английском нет казахского текста (%d)" % [where, untranslated.size()])


## «Дала жолы»: заставка главы, HUD и разговор, мини-игры, костёр, финал,
## раздел «Тарих» энциклопедии (тексты сюжета — в story_strings.csv).
func _check_story() -> void:
	var save_manager := autoload("SaveManager")
	var codex := await mount("res://scenes/ui/codex.tscn")
	codex.call("show_section", 1)
	_check_texts(codex, "энциклопедия · тарих")
	await unmount(codex)

	save_manager.story = {"hero": "ROLE_ABYLAI"}
	var world := await mount("res://scenes/story/story_world.tscn")
	var overlay: Control = world.get_node("%Overlay")
	_check_texts(overlay, "заставка главы")
	for card in overlay.get_children():
		card.call("_close")
	await process_frame
	var state: StoryState = world.state
	world.speak(state.dialogue(state.current_beat().dialogue), Callable())
	var dialogue = world.get_node("%Dialogue")
	dialogue._typed = 9999.0
	await process_frame
	_check_texts(world, "мир · HUD и разговор")
	for game in [StoryOverlays.asyk(), StoryOverlays.duel(world.hero, true)]:
		overlay.add_child(game)
		await process_frame
		_check_texts(game, game.get_script().resource_path.get_file())
		game.queue_free()
	var fire := StoryOverlays.campfire(world, state.chapter.beats[state.chapter.beats.size() - 2])
	overlay.add_child(fire)
	await process_frame
	_check_texts(fire, "костёр")
	fire.queue_free()
	var finale := StoryOverlays.finale(state, _story_cast())
	overlay.add_child(finale)
	await process_frame
	_check_texts(finale, "финал")
	await unmount(world)


func _story_cast() -> StoryCast:
	return autoload("AssetRegistry").call("get_story_cast")
