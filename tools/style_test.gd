extends "res://tools/test_case.gd"
## Единый стиль (docs/REDESIGN_PLAN.md, «Единый стиль»), проверяемый автоматически:
## - пиксель-арт только из палитры UiTokens, альфа только 0 или 255;
## - размер кратен пикселю арта (UiTokens.PIXEL);
## - каждый theme_type_variation, упомянутый в коде, есть в теме.

const THEME := preload("res://resources/ui/ui_theme.tres")
## Папки с пиксель-артом, который обязан следовать правилам. Этап 2 добавит
## сюда весь арт игры.
const PIXEL_ART_DIRS := ["res://assets/ui/frames"]
const CODE_DIRS := ["res://scenes", "res://scripts", "res://tools"]


func _init() -> void:
	var palette := _palette()
	check(palette.size() > 10, "палитра UiTokens прочитана, цветов: %d" % palette.size())
	for dir_path in PIXEL_ART_DIRS:
		for file in DirAccess.get_files_at(dir_path):
			if file.get_extension() == "png":
				_check_pixel_art(dir_path.path_join(file), palette)
	_check_theme_variations()
	finish("STYLE")


## Все цвета-константы UiTokens как "rrggbb".
func _palette() -> Dictionary:
	var colors := {}
	var constants: Dictionary = UiTokens.new().get_script().get_script_constant_map()
	for value in constants.values():
		if value is Color:
			colors[value.to_html(false)] = true
	return colors


func _check_pixel_art(path: String, palette: Dictionary) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		check(false, "картинка читается: %s" % path)
		return
	image.convert(Image.FORMAT_RGBA8)
	var off_palette := {}
	var soft_alpha := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var alpha := roundi(pixel.a * 255)
			if alpha == 0:
				continue
			if alpha != 255:
				soft_alpha += 1
			var html := pixel.to_html(false)
			if not palette.has(html):
				off_palette[html] = true
	var name := path.get_file()
	check(off_palette.is_empty(), "%s: только цвета палитры%s" % [name, "" if off_palette.is_empty() else " (лишние: %s)" % ", ".join(off_palette.keys().slice(0, 5))])
	check(soft_alpha == 0, "%s: без полупрозрачных пикселей (найдено %d)" % [name, soft_alpha])
	check(image.get_width() % UiTokens.PIXEL == 0 and image.get_height() % UiTokens.PIXEL == 0,
		"%s: размер %dx%d кратен пикселю арта" % [name, image.get_width(), image.get_height()])


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
