extends Control

const RARITY_NAMES := {0: "Кәдімгі", 1: "Сирек", 2: "Аңыз"}
const RARITY_COLORS := {
	0: Color("7d766a"),
	1: Color("a36b24"),
	2: SanlaqDesignTokens.RED_ACCENT,
}
const SLOT_NAMES := {0: "Бас киім", 1: "Сырт киім", 2: "Шалбар", 3: "Аяқ киім"}
const LOCKED_COLOR := Color("857d70")
## Спокойная рамка обычной карточки. Редкость раньше красила рамку целиком, и
## редкие предметы выглядели как выбранные — отличить настоящий выбор было
## невозможно. Теперь редкость живёт только в подписи и в метке-точке.
const CARD_BORDER := Color("d8c39a")

## Какая карточка открыта в панели справа.
var _selected_id: String = ""
## id предмета -> части карточки, которые перекрашиваются при выборе.
var _cards: Dictionary = {}

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
	for item_id in _cards:
		_refresh_card(item_id)
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

	panel.add_theme_stylebox_override("panel", _card_style())

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
	box.add_child(name_lbl)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 12)
	status.text = "✓ ашық" if unlocked else "жабық · квизде аш"
	box.add_child(status)

	_cards[item.id] = {
		"panel": panel,
		"name": name_lbl,
		"status": status,
		"rarity": rarity_col,
		"unlocked": unlocked,
	}

	panel.add_child(box)

	var click := Button.new()
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click.pressed.connect(_select.bind(item))
	click.mouse_entered.connect(_refresh_card.bind(item.id, true))
	click.mouse_exited.connect(_refresh_card.bind(item.id, false))
	card.add_child(click)

	return card

## Выбранная карточка заливается тёмно-синим: на фоне кремовых соседей её видно
## сразу и ни с чем не спутать, в отличие от рамки, которая спорила с рамкой
## редкости.
func _card_style(selected: bool = false, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = SanlaqDesignTokens.NAVY
		style.border_color = SanlaqDesignTokens.GOLD
		style.set_border_width_all(4)
		style.shadow_color = Color(0.04, 0.16, 0.23, 0.34)
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 5)
	else:
		style.bg_color = Color("fffaf0") if hovered else SanlaqDesignTokens.CREAM_LIGHT
		style.border_color = SanlaqDesignTokens.GOLD_DARK if hovered else CARD_BORDER
		style.set_border_width_all(3 if hovered else 2)
		style.shadow_color = Color(0.04, 0.16, 0.23, 0.20 if hovered else 0.12)
		style.shadow_size = 9 if hovered else 6
		style.shadow_offset = Vector2(0, 4 if hovered else 3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	return style

## Перекрашивает карточку под её текущее состояние: и фон, и подписи, иначе на
## тёмной заливке остался бы тёмный текст.
func _refresh_card(item_id: String, hovered: bool = false) -> void:
	var parts: Dictionary = _cards.get(item_id, {})
	if parts.is_empty():
		return
	var selected := item_id == _selected_id
	var unlocked: bool = parts["unlocked"]
	(parts["panel"] as PanelContainer).add_theme_stylebox_override(
		"panel", _card_style(selected, hovered))

	var name_lbl: Label = parts["name"]
	var status: Label = parts["status"]
	if selected:
		name_lbl.add_theme_color_override("font_color", SanlaqDesignTokens.CREAM_LIGHT)
		status.add_theme_color_override("font_color", SanlaqDesignTokens.GOLD)
	elif unlocked:
		name_lbl.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
		status.add_theme_color_override("font_color", parts["rarity"])
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.42, 0.40, 0.36, 1))
		status.add_theme_color_override("font_color", Color(0.42, 0.40, 0.36, 1))

func _photo_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ead8b0")
	style.border_color = Color("a26a2e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(3)
	return style

func _select(item: ClothingItem) -> void:
	var previous := _selected_id
	_selected_id = item.id
	if previous != "" and previous != item.id:
		_refresh_card(previous)
	_refresh_card(item.id)

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
