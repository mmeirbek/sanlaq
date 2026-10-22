extends "res://tools/test_case.gd"
## Единый стиль (docs/REDESIGN_PLAN.md, «Единый стиль»), проверяемый автоматически:
## - пиксель-арт только из общей палитры assets/palette/sanlaq.gpl, альфа 0 или 255;
## - цвета интерфейса UiTokens — часть этой палитры;
## - картинка лежит на сетке пикселя арта (UiTokens.PIXEL): каждый пиксель арта —
##   ровный квадрат, без сглаживания и дробного масштаба;
## - каждый theme_type_variation, упомянутый в коде, есть в теме.

const THEME := preload("res://resources/ui/ui_theme.tres")
const PALETTE_PATH := "res://assets/palette/sanlaq.gpl"
## Папки с пиксель-артом, который обязан следовать правилам (с подпапками).
const PIXEL_ART_DIRS := ["res://assets/ui/frames", "res://assets/sprites"]
const CODE_DIRS := ["res://scenes", "res://scripts", "res://tools"]


func _init() -> void:
	var palette := _palette()
	check(palette.size() > 10, "палитра sanlaq.gpl прочитана, цветов: %d" % palette.size())
	_check_tokens_in_palette(palette)
	for dir_path in PIXEL_ART_DIRS:
		for path in _files(dir_path, ["png"]):
			_check_pixel_art(path, palette)
	_check_theme_variations()
	finish("STYLE")


## Цвета палитры GIMP (.gpl) как {0xRRGGBB: имя}.
func _palette() -> Dictionary:
	var colors := {}
	var row := RegEx.create_from_string("^\\s*(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\w+)\\s*$")
	for line in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var found := row.search(line)
		if found:
			var rgb := (found.get_string(1).to_int() << 16) | (found.get_string(2).to_int() << 8) | found.get_string(3).to_int()
			colors[rgb] = found.get_string(4)
	return colors


func _check_tokens_in_palette(palette: Dictionary) -> void:
	var constants: Dictionary = UiTokens.new().get_script().get_script_constant_map()
	for token: String in constants:
		if constants[token] is Color:
			check(palette.has(constants[token].to_rgba32() >> 8), "UiTokens.%s есть в палитре" % token)


func _check_pixel_art(path: String, palette: Dictionary) -> void:
	var name := path.get_file()
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		check(false, "картинка читается: %s" % path)
		return
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	if width % UiTokens.PIXEL != 0 or height % UiTokens.PIXEL != 0:
		check(false, "%s: размер %dx%d кратен пикселю арта" % [name, width, height])
		return
	# Сжали до пикселей арта и растянули обратно: на сетке картинка совпадёт.
	var art := image.duplicate() as Image
	art.resize(width / UiTokens.PIXEL, height / UiTokens.PIXEL, Image.INTERPOLATE_NEAREST)
	var back := art.duplicate() as Image
	back.resize(width, height, Image.INTERPOLATE_NEAREST)
	check(back.get_data() == image.get_data(), "%s: лежит на сетке пикселя арта" % name)

	var off_palette := {}
	var soft_alpha := 0
	var data := art.get_data()
	for i in range(0, data.size(), 4):
		var alpha := data[i + 3]
		if alpha == 0:
			continue
		if alpha != 255:
			soft_alpha += 1
		var rgb := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
		if not palette.has(rgb):
			off_palette["%06x" % rgb] = true
	check(off_palette.is_empty(), "%s: только цвета палитры%s" % [name, "" if off_palette.is_empty() else " (лишние: %s)" % ", ".join(off_palette.keys().slice(0, 5))])
	check(soft_alpha == 0, "%s: без полупрозрачных пикселей (найдено %d)" % [name, soft_alpha])


func _check_theme_variations() -> void:
	# В .tscn вариант записан как &"Имя", в коде — как "Имя".
	var pattern := RegEx.create_from_string("theme_type_variation\\s*=\\s*&?\"(\\w+)\"")
	var used := {}
	for dir_path in CODE_DIRS:
		for path in _files(dir_path, ["gd", "tscn"]):
			for found in pattern.search_all(FileAccess.get_file_as_string(path)):
				used[found.get_string(1)] = path
	for variation: String in used:
		var known := THEME.get_type_variation_base(variation) != &"" or ClassDB.class_exists(variation)
		# Старая тема живёт до конца этапа 3; её варианты проверяем, только если
		# экран уже на новой теме — поэтому смотрим лишь варианты новой темы.
		if not known and _legacy_variation(variation):
			continue
		check(known, "вариант темы «%s» существует (%s)" % [variation, used[variation].get_file()])


## Варианты старой темы sanlaq_theme.tres — уйдут вместе с ней в этапе 3.
func _legacy_variation(variation: String) -> bool:
	return load("res://resources/ui/sanlaq_theme.tres").get_type_variation_base(variation) != &""


func _files(dir_path: String, extensions: Array) -> PackedStringArray:
	var found: PackedStringArray = []
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() in extensions:
			found.append(dir_path.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		found.append_array(_files(dir_path.path_join(sub_dir), extensions))
	return found
