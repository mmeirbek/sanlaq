extends Control

const RARITY_NAMES := {0: "Кәдімгі", 1: "Сирек", 2: "Аңыз"}
const RARITY_COLORS := {
	0: Color("b9b0a0"),
	1: SanlaqDesignTokens.GOLD,
	2: SanlaqDesignTokens.RED_ACCENT,
}
const SLOT_NAMES := {0: "Бас киім", 1: "Сырт киім", 2: "Шалбар", 3: "Аяқ киім"}
const LOCKED_COLOR := Color("b9b0a0")

@onready var _grid: GridContainer = $Scroll/Grid
@onready var _detail_icon: TextureRect = $DetailPanel/Margin/VBox/Icon
@onready var _detail_name: Label = $DetailPanel/Margin/VBox/NameLabel
@onready var _detail_meta: Label = $DetailPanel/Margin/VBox/MetaLabel
@onready var _detail_desc: Label = $DetailPanel/Margin/VBox/DescLabel
@onready var _photo_credit: Label = $DetailPanel/Margin/VBox/PhotoCredit
@onready var _back_btn: Button = $BackBtn

func _ready() -> void:
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
	_build_grid()

func _build_grid() -> void:
	var first_item: ClothingItem = null
	var first_unlocked: ClothingItem = null
	for item in AssetRegistry.clothing_items:
		_grid.add_child(_make_card(item))
		if first_item == null:
			first_item = item
		if first_unlocked == null and SaveManager.is_unlocked(item.id):
			first_unlocked = item
	if first_unlocked:
		_select(first_unlocked)
	elif first_item:
		_select(first_item)

func _make_card(item: ClothingItem) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(160, 204)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = item.get_name_for_lang(GameSettings.get_lang_code())

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(panel)

	var unlocked := SaveManager.is_unlocked(item.id)
	var rarity_col: Color = RARITY_COLORS.get(item.rarity, LOCKED_COLOR)
	if not unlocked:
		rarity_col = LOCKED_COLOR

	panel.add_theme_stylebox_override("panel", _card_style(rarity_col))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	# Every card owns a clear photo area. The image comes from this exact item's
	# reference_photo_path; only a missing file falls back to the small item icon.
	var photo_frame := PanelContainer.new()
	photo_frame.custom_minimum_size = Vector2(136, 104)
	photo_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	photo_frame.add_theme_stylebox_override("panel", _photo_style())

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(136, 104)
	tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.texture = _photo_for(item)
	if tex.texture == null and not item.icon_path.is_empty():
		tex.texture = load(item.icon_path) as Texture2D
	if not unlocked:
		tex.modulate = Color(0.32, 0.32, 0.32, 0.85)
	photo_frame.add_child(tex)
	box.add_child(photo_frame)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.text = item.get_name_for_lang(GameSettings.get_lang_code()) if unlocked else "???"
	if not unlocked:
		name_lbl.add_theme_color_override("font_color", Color(0.55, 0.53, 0.5, 1))
	box.add_child(name_lbl)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 12)
	if unlocked:
		status.text = "✓ ашық"
		status.add_theme_color_override("font_color", rarity_col)
	else:
		status.text = "жабық · квизде аш"
		status.add_theme_color_override("font_color", Color(0.55, 0.53, 0.5, 1))
	box.add_child(status)

	panel.add_child(box)

	var click := Button.new()
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.pressed.connect(_select.bind(item))
	click.mouse_entered.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", _card_style(rarity_col, true)))
	click.mouse_exited.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", _card_style(rarity_col)))
	card.add_child(click)

	return card

func _card_style(border_col: Color, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fffaf0") if hovered else SanlaqDesignTokens.CREAM_LIGHT
	style.border_color = border_col
	style.set_border_width_all(3 if hovered else 2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	style.shadow_color = Color(0.04, 0.16, 0.23, 0.20 if hovered else 0.12)
	style.shadow_size = 9 if hovered else 6
	style.shadow_offset = Vector2(0, 4 if hovered else 3)
	return style

func _photo_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ead8b0")
	style.border_color = Color("a26a2e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(3)
	return style

func _select(item: ClothingItem) -> void:
	var lang := GameSettings.get_lang_code()
	var unlocked := SaveManager.is_unlocked(item.id)

	_detail_icon.texture = _photo_for(item)
	if _detail_icon.texture == null and not item.icon_path.is_empty():
		_detail_icon.texture = load(item.icon_path) as Texture2D
	elif _detail_icon.texture == null:
		_detail_icon.texture = null
	_photo_credit.text = "Дереккөз: Wikimedia Commons · лицензиясы CREDITS.md файлында"

	if unlocked:
		_detail_name.text = item.get_name_for_lang(lang)
		_detail_meta.text = "%s · %s" % [
			tr(SLOT_NAMES.get(item.slot_type, "?")),
			tr(RARITY_NAMES.get(item.rarity, "?")),
		]
		_detail_desc.text = item.get_desc_for_lang(lang)
	else:
		_detail_name.text = "???"
		_detail_meta.text = "Жабық киім"
		_detail_desc.text = "Бұл киім әлі ашылған жоқ. Дұрыс жауап беріп, квизде ашыңыз."

func _photo_for(item: ClothingItem) -> Texture2D:
	var path: String = item.reference_photo_path
	return load(path) as Texture2D if not path.is_empty() else null
