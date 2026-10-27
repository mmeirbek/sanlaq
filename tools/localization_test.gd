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
