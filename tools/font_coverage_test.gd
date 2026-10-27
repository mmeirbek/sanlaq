extends "res://tools/test_case.gd"
## Каждый символ строк интерфейса есть в шрифтах темы — иначе на экране вместо
## буквы окажется пустое место или «тофу».
##
## - Handjet (основной текст) обязан покрыть всё: строки CSV на обоих языках,
##   тексты в сценах и литералы tr() в коде.
## - PressStart2P (заголовки, кнопки, цифры) — тексты узлов, которые в сценах
##   рисуются им, вместе с их переводами из CSV.
##
## Строки, которые код собирает на лету, проверяются через CSV: всё видимое
## идёт через tr() и потому лежит там.

const CSV_PATH := "res://assets/i18n/ui_strings.csv"
const CODE_DIRS := ["res://scenes", "res://scripts"]
const BODY := preload("res://assets/fonts/Handjet-Variable.ttf")
const DISPLAY := preload("res://assets/fonts/PressStart2P-Regular.ttf")
## Варианты темы, которые рисуются PressStart2P (tools/build_theme.gd).
const DISPLAY_VARIATIONS := [
	"TitleLabel", "HeadingLabel", "HudLabel", "TimerLabel", "HudTimerLabel", "InkHeadingLabel",
	"Button", "ButtonSecondary", "ButtonLarge",
]

## Ключ CSV -> [kk, en].
var _translations := {}


func _init() -> void:
	_load_csv()
	var body_text := {}
	var display_text := {}
	for key: String in _translations:
		body_text[key] = CSV_PATH
		for value: String in _translations[key]:
			body_text[value] = CSV_PATH
	for dir_path in CODE_DIRS:
		for path in _files(dir_path, "tscn"):
			_scan_scene(path, body_text, display_text)
		for path in _files(dir_path, "gd"):
			for found in RegEx.create_from_string("\\btr\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)").search_all(
					FileAccess.get_file_as_string(path)):
				body_text[found.get_string(1)] = path

	_check_font(BODY, "Handjet", body_text)
	_check_font(DISPLAY, "PressStart2P", display_text)
	finish("FONT COVERAGE")


func _load_csv() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			_translations[row[0]] = [row[1], row[2]]


## Тексты узлов сцены. Узел, который рисуется PressStart2P (по варианту темы или
## потому что это кнопка без варианта), отдаёт текст и его переводы в display.
func _scan_scene(path: String, body_text: Dictionary, display_text: Dictionary) -> void:
	var text_re := RegEx.create_from_string("^(text|title|subtitle) = \"((?:[^\"\\\\]|\\\\.)*)\"$")
	var variation_re := RegEx.create_from_string("^theme_type_variation = &\"(\\w+)\"$")
	var node_re := RegEx.create_from_string("^\\[node name=\"[^\"]*\" type=\"(\\w+)\"")
	var node_type := ""
	var variation := ""
	var texts: Array[String] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("["):
			_add_node_texts(path, node_type, variation, texts, body_text, display_text)
			var node := node_re.search(line)
			node_type = node.get_string(1) if node else ""
			variation = ""
			texts = []
			continue
		var text := text_re.search(line)
		if text:
			var value := text.get_string(2).c_unescape()
			# ScreenHeader: заголовок — PressStart2P, подзаголовок — Handjet.
			if text.get_string(1) == "title":
				display_text[value] = path
			texts.append(value)
		var found := variation_re.search(line)
		if found:
			variation = found.get_string(1)
	_add_node_texts(path, node_type, variation, texts, body_text, display_text)


func _add_node_texts(path: String, node_type: String, variation: String, texts: Array[String],
		body_text: Dictionary, display_text: Dictionary) -> void:
	var display: bool = variation in DISPLAY_VARIATIONS or (variation.is_empty() and node_type == "Button")
	for text in texts:
		body_text[text] = path
		if display:
			display_text[text] = path
			for value: String in _translations.get(text, []):
				display_text[value] = path


func _check_font(font: FontFile, font_name: String, strings: Dictionary) -> void:
	var missing := {}
	for text: String in strings:
		for i in text.length():
			var code := text.unicode_at(i)
			if code <= 32 or missing.has(code):
				continue
			if not font.has_char(code):
				missing[code] = "%s (%s)" % [text.substr(0, 40), strings[text].get_file()]
	for code: int in missing:
		print("[test]    .. нет в %s: «%s» U+%04X — %s" % [font_name, String.chr(code), code, missing[code]])
	check(missing.is_empty(), "%s покрывает все символы интерфейса (нет: %d)" % [font_name, missing.size()])


func _files(dir_path: String, extension: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == extension:
			found.append(dir_path.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		found.append_array(_files(dir_path.path_join(sub_dir), extension))
	return found
