extends SceneTree
## Собирает тему интерфейса resources/ui/ui_theme.tres из UiTokens и пиксельных
## рамок assets/ui/frames/ (их рисует tools/artgen). Тему руками не правим —
## меняем токены или рамки и пересобираем:
##
##     python tools/artgen/build.py
##     godot --headless --import --path .
##     godot --headless --path . --script res://tools/build_theme.gd
##
## Варианты типов (theme_type_variation) — справочник для экранов:
##   Button: (по умолчанию — бордовая), ButtonSecondary, ButtonLarge
##   Label: (по умолчанию — текст на тёмном), TitleLabel, HeadingLabel,
##          CaptionLabel, WarningLabel, InkLabel, InkHeadingLabel, HudLabel, TimerLabel
##   PanelContainer: (по умолчанию — бордовая панель), ParchmentPanel,
##          HudPanel, Card, CardHover, CardSelected, InsetPanel

const THEME_PATH := "res://resources/ui/ui_theme.tres"
const FONTS_DIR := "res://resources/ui/fonts/"
const FRAMES_DIR := "res://assets/ui/frames/"

var _margins: Dictionary = {}


func _init() -> void:
	_margins = JSON.parse_string(FileAccess.get_file_as_string(FRAMES_DIR + "frames.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FONTS_DIR))
	var fonts := {
		"body": _save(_body_font(UiTokens.BODY_WEIGHT), FONTS_DIR + "body.tres"),
		"body_bold": _save(_body_font(UiTokens.BODY_WEIGHT_BOLD), FONTS_DIR + "body_bold.tres"),
		"display": UiTokens.FONT_DISPLAY,
	}
	var theme := Theme.new()
	theme.default_font = fonts.body
	theme.default_font_size = UiTokens.BODY
	_buttons(theme, fonts)
	_labels(theme, fonts)
	_panels(theme)
	_inputs(theme, fonts)
	# Шаг между элементами контейнеров по умолчанию — экраны его не переопределяют.
	for box in ["VBoxContainer", "HBoxContainer", "GridContainer"]:
		theme.set_constant("separation", box, UiTokens.SPACE_XS)
	theme.set_constant("h_separation", "GridContainer", UiTokens.SPACE_S)
	theme.set_constant("v_separation", "GridContainer", UiTokens.SPACE_S)
	_save(theme, THEME_PATH)
	print("тема собрана: ", THEME_PATH)
	quit()


# --- Кнопки ----------------------------------------------------------------

func _buttons(theme: Theme, fonts: Dictionary) -> void:
	_button_type(theme, "Button", "button", fonts.display, UiTokens.DISPLAY_SMALL)
	_variation(theme, "ButtonSecondary", "Button")
	_button_type(theme, "ButtonSecondary", "button_secondary", fonts.display, UiTokens.DISPLAY_SMALL)
	# Крупная — главные действия экрана (ОЙНАУ, БАСТАУ).
	_variation(theme, "ButtonLarge", "Button")
	theme.set_font_size("font_size", "ButtonLarge", UiTokens.DISPLAY_MEDIUM)


func _button_type(theme: Theme, type: String, frame: String, font: Font, size: int) -> void:
	var normal := _frame(frame + "_normal", Vector2(UiTokens.SPACE_M, UiTokens.SPACE_XS))
	var hover := _frame(frame + "_hover", Vector2(UiTokens.SPACE_M, UiTokens.SPACE_XS))
	# Нажатая кнопка «утоплена»: подпись сдвигается на пиксель арта вниз.
	var pressed := _frame(frame + "_pressed", Vector2(UiTokens.SPACE_M, UiTokens.SPACE_XS), UiTokens.PIXEL)
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, _frame("button_disabled", Vector2(UiTokens.SPACE_M, UiTokens.SPACE_XS)))
	theme.set_stylebox("focus", type, _frame("button_focus"))
	theme.set_font("font", type, font)
	theme.set_font_size("font_size", type, size)
	theme.set_color("font_color", type, UiTokens.CREAM)
	theme.set_color("font_hover_color", type, UiTokens.GOLD_LIGHT)
	theme.set_color("font_pressed_color", type, UiTokens.GOLD)
	theme.set_color("font_hover_pressed_color", type, UiTokens.GOLD)
	theme.set_color("font_focus_color", type, UiTokens.CREAM)
	theme.set_color("font_disabled_color", type, UiTokens.MUTED)
	theme.set_color("icon_normal_color", type, Color.WHITE)
	theme.set_color("icon_disabled_color", type, UiTokens.MUTED)
	theme.set_color("font_outline_color", type, UiTokens.OUTLINE)
	theme.set_constant("outline_size", type, 0)
	theme.set_constant("h_separation", type, UiTokens.SPACE_S)


# --- Текст -----------------------------------------------------------------

func _labels(theme: Theme, fonts: Dictionary) -> void:
	theme.set_font("font", "Label", fonts.body)
	theme.set_font_size("font_size", "Label", UiTokens.BODY)
	theme.set_color("font_color", "Label", UiTokens.CREAM)
	theme.set_constant("line_spacing", "Label", UiTokens.PIXEL)

	# Пиксельный шрифт с тенью в один пиксель арта — читается на любом фоне.
	_display_label(theme, "TitleLabel", fonts.display, UiTokens.DISPLAY_LARGE, UiTokens.GOLD_LIGHT)
	_display_label(theme, "HeadingLabel", fonts.display, UiTokens.DISPLAY_SMALL, UiTokens.GOLD)
	_display_label(theme, "HudLabel", fonts.display, UiTokens.DISPLAY_SMALL, UiTokens.CREAM)
	_display_label(theme, "TimerLabel", fonts.display, UiTokens.DISPLAY_HERO, UiTokens.GOLD_LIGHT)

	_variation(theme, "CaptionLabel", "Label")
	theme.set_font_size("font_size", "CaptionLabel", UiTokens.BODY_SMALL)
	theme.set_color("font_color", "CaptionLabel", UiTokens.MUTED)

	# Предупреждение («сначала введите имя»): жирнее и тёплым цветом.
	_variation(theme, "WarningLabel", "Label")
	theme.set_font("font", "WarningLabel", fonts.body_bold)
	theme.set_color("font_color", "WarningLabel", UiTokens.EMBER)

	# Для пергаментных панелей: тёмный текст на светлом.
	_variation(theme, "InkLabel", "Label")
	theme.set_color("font_color", "InkLabel", UiTokens.INK)
	_variation(theme, "InkHeadingLabel", "Label")
	theme.set_font("font", "InkHeadingLabel", fonts.display)
	theme.set_font_size("font_size", "InkHeadingLabel", UiTokens.DISPLAY_SMALL)
	theme.set_color("font_color", "InkHeadingLabel", UiTokens.BURGUNDY)

	theme.set_font("normal_font", "RichTextLabel", fonts.body)
	theme.set_font("bold_font", "RichTextLabel", fonts.body_bold)
	theme.set_font_size("normal_font_size", "RichTextLabel", UiTokens.BODY)
	theme.set_font_size("bold_font_size", "RichTextLabel", UiTokens.BODY)
	theme.set_color("default_color", "RichTextLabel", UiTokens.CREAM)


func _display_label(theme: Theme, type: String, font: Font, size: int, color: Color) -> void:
	_variation(theme, type, "Label")
	theme.set_font("font", type, font)
	theme.set_font_size("font_size", type, size)
	theme.set_color("font_color", type, color)
	theme.set_color("font_shadow_color", type, UiTokens.OUTLINE)
	theme.set_constant("shadow_offset_x", type, UiTokens.PIXEL)
	theme.set_constant("shadow_offset_y", type, UiTokens.PIXEL)
	theme.set_constant("line_spacing", type, UiTokens.PIXEL * 4)


# --- Панели ----------------------------------------------------------------

func _panels(theme: Theme) -> void:
	var padding := Vector2(UiTokens.SPACE_M, UiTokens.SPACE_M)
	theme.set_stylebox("panel", "PanelContainer", _frame("panel_burgundy", padding))
	theme.set_stylebox("panel", "Panel", _frame("panel_burgundy"))
	var variations := {
		"ParchmentPanel": "panel_parchment",
		"HudPanel": "panel_hud",
		"Card": "card",
		"CardHover": "card_hover",
		"CardSelected": "card_selected",
		"InsetPanel": "inset",
	}
	for type: String in variations:
		_variation(theme, type, "PanelContainer")
		var small := type == "HudPanel" or type == "InsetPanel"
		theme.set_stylebox("panel", type, _frame(variations[type], Vector2(UiTokens.SPACE_S, UiTokens.SPACE_XS) if small else padding))

	var line := StyleBoxLine.new()
	line.color = UiTokens.GOLD_DARK
	line.thickness = UiTokens.PIXEL
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", UiTokens.SPACE_S)

	theme.set_stylebox("panel", "TooltipPanel", _frame("panel_hud", Vector2(UiTokens.SPACE_S, UiTokens.SPACE_XS)))
	theme.set_font_size("font_size", "TooltipLabel", UiTokens.BODY_SMALL)
	theme.set_color("font_color", "TooltipLabel", UiTokens.CREAM)


# --- Поля ввода, слайдеры, переключатели, прокрутка -------------------------

func _inputs(theme: Theme, fonts: Dictionary) -> void:
	var field := _frame("inset", Vector2(UiTokens.SPACE_S, UiTokens.SPACE_XS))
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _frame("button_focus"))
	theme.set_font("font", "LineEdit", fonts.body)
	theme.set_color("font_color", "LineEdit", UiTokens.CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", UiTokens.MUTED)
	theme.set_color("caret_color", "LineEdit", UiTokens.GOLD_LIGHT)
	theme.set_color("selection_color", "LineEdit", UiTokens.BURGUNDY_LIGHT)

	theme.set_stylebox("slider", "HSlider", _frame("inset", Vector2.ZERO))
	theme.set_stylebox("grabber_area", "HSlider", _frame("slider_fill", Vector2.ZERO))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _frame("slider_fill", Vector2.ZERO))
	theme.set_icon("grabber", "HSlider", _texture("grabber"))
	theme.set_icon("grabber_highlight", "HSlider", _texture("grabber_highlight"))
	theme.set_icon("grabber_disabled", "HSlider", _texture("grabber"))
	theme.set_constant("center_grabber", "HSlider", 1)

	theme.set_icon("checked", "CheckButton", _texture("toggle_on"))
	theme.set_icon("unchecked", "CheckButton", _texture("toggle_off"))
	theme.set_icon("checked_disabled", "CheckButton", _texture("toggle_on"))
	theme.set_icon("unchecked_disabled", "CheckButton", _texture("toggle_off"))
	theme.set_icon("checked_mirrored", "CheckButton", _texture("toggle_on"))
	theme.set_icon("unchecked_mirrored", "CheckButton", _texture("toggle_off"))
	# Пустой фон с отступами: строка с переключателем не ниже TOUCH_MIN — по
	# ней легко попасть пальцем.
	var toggle_row := StyleBoxEmpty.new()
	var toggle_height := _texture("toggle_on").get_height()
	toggle_row.content_margin_top = (UiTokens.TOUCH_MIN - toggle_height) / 2
	toggle_row.content_margin_bottom = (UiTokens.TOUCH_MIN - toggle_height) / 2
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", toggle_row)
	theme.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	theme.set_font("font", "CheckButton", fonts.body)
	theme.set_font_size("font_size", "CheckButton", UiTokens.BODY)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "CheckButton", UiTokens.CREAM)
	theme.set_color("font_disabled_color", "CheckButton", UiTokens.MUTED)

	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, _frame("inset", Vector2.ZERO))
		theme.set_stylebox("grabber", bar, _frame("slider_fill", Vector2.ZERO))
		theme.set_stylebox("grabber_highlight", bar, _frame("slider_fill", Vector2.ZERO))
		theme.set_stylebox("grabber_pressed", bar, _frame("slider_fill", Vector2.ZERO))


# --- Помощники -------------------------------------------------------------

## 9-slice из пиксельной рамки. padding — отступ содержимого от внутреннего края
## рамки; shift_down сдвигает содержимое вниз (нажатая кнопка).
func _frame(name: String, padding: Vector2 = Vector2.ZERO, shift_down: int = 0) -> StyleBoxTexture:
	var margin: int = _margins[name].margin
	var box := StyleBoxTexture.new()
	box.texture = _texture(name)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = margin + padding.x
	box.content_margin_right = margin + padding.x
	box.content_margin_top = margin + padding.y + shift_down
	box.content_margin_bottom = margin + padding.y - shift_down
	return box


func _texture(name: String) -> Texture2D:
	return load(FRAMES_DIR + name + ".png") as Texture2D


func _body_font(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = UiTokens.FONT_BODY
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _variation(theme: Theme, type: String, base: String) -> void:
	theme.set_type_variation(type, base)


func _save(resource: Resource, path: String) -> Resource:
	var err := ResourceSaver.save(resource, path)
	assert(err == OK, "не удалось сохранить %s: %d" % [path, err])
	resource.take_over_path(path)
	return resource
