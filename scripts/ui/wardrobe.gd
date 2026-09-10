class_name WardrobeUI
extends Control

const SLOT_NAMES := {
	0: "Бас киім",
	1: "Сырт киім",
	2: "Шалбар",
	3: "Аяқ киім",
}

const SLOT_TITLES := {
	0: "Бас киім",
	1: "Сырт киім",
	2: "Шалбар",
	3: "Аяқ киім",
}

var _current_slot: ClothingItem.SlotType = ClothingItem.SlotType.HEAD
var _mannequin: Node2D
var _item_buttons: Array[Button] = []
var _tab_buttons: Array[Button] = []

@onready var _title: Label = $Title
@onready var _slot_tabs: HBoxContainer = $RightPanel/Margin/VBox/Tabs
@onready var _items_grid: GridContainer = $RightPanel/Margin/VBox/Scroll/Items
@onready var _effect_label: Label = $RightPanel/Margin/VBox/EffectPanel/EffectLabel
@onready var _info_label: RichTextLabel = $RightPanel/Margin/VBox/InfoPanel/Info
@onready var _back_btn: Button = $BackBtn
@onready var _slot_title: Label = $RightPanel/Margin/VBox/SlotTitle

func _ready() -> void:
	_title.text = "КИІМ ШКАФЫ"
	_build_tabs()
	_build_back_button()
	_build_mannequin()
	_show_slot(_current_slot)

func _build_tabs() -> void:
	for slot in ClothingItem.SlotType.values():
		var btn := Button.new()
		btn.text = SLOT_NAMES.get(slot, str(slot))
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = tr("Киім санатын ашу · Open category")
		btn.pressed.connect(_show_slot.bind(slot as ClothingItem.SlotType))
		_slot_tabs.add_child(btn)
		_tab_buttons.append(btn)

func _build_back_button() -> void:
	_back_btn.text = "← Артқа"
	_back_btn.pressed.connect(func(): SceneRouter.go_to_main_menu())

func _build_mannequin() -> void:
	var pack := load("res://scenes/entities/character_visual.tscn") as PackedScene
	_mannequin = pack.instantiate() as Node2D
	_mannequin.scale = Vector2(5, 5)
	_mannequin.position = Vector2(324, 420)
	add_child(_mannequin)
	(_mannequin as CharacterVisual).set_direction(Vector2.DOWN)
	_apply_equipped_outfit()

func _apply_equipped_outfit() -> void:
	var visual := _mannequin as CharacterVisual
	for slot in ClothingItem.SlotType.values():
		var item_id := SaveManager.get_equipped(slot as ClothingItem.SlotType)
		var item := AssetRegistry.get_clothing_by_id(item_id)
		visual.set_clothing(slot as ClothingItem.SlotType, item)

func _show_slot(slot: ClothingItem.SlotType) -> void:
	_current_slot = slot
	_slot_title.text = SLOT_TITLES.get(slot, "Киім")
	for i in _tab_buttons.size():
		_tab_buttons[i].add_theme_stylebox_override("normal", _tab_style(i == int(slot)))
		_tab_buttons[i].add_theme_stylebox_override("hover", _tab_style(i == int(slot), true))
		_tab_buttons[i].add_theme_color_override("font_color", SanlaqDesignTokens.NAVY if i == int(slot) else SanlaqDesignTokens.NAVY_LIGHT)
		_tab_buttons[i].add_theme_color_override("font_hover_color", SanlaqDesignTokens.NAVY)
	_refresh_items()

func _refresh_items() -> void:
	for b in _item_buttons:
		b.queue_free()
	_item_buttons.clear()

	var items := AssetRegistry.get_clothing(_current_slot)
	var equipped_id := SaveManager.get_equipped(_current_slot)
	_items_grid.columns = 2
	_items_grid.add_theme_constant_override("h_separation", 12)
	_items_grid.add_theme_constant_override("v_separation", 12)

	for item in items:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 146)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_TOP
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", SanlaqDesignTokens.NAVY)
		btn.add_theme_color_override("font_hover_color", SanlaqDesignTokens.NAVY)
		btn.expand_icon = true
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		btn.tooltip_text = item.get_desc_for_lang(GameSettings.get_lang_code())
		btn.text = _card_text(item)
		if not item.icon_path.is_empty():
			var ico := load(item.icon_path) as Texture2D
			if ico:
				btn.icon = ico

		var unlocked := SaveManager.is_unlocked(item.id)
		if not unlocked:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 1)
		elif item.id == equipped_id:
			btn.add_theme_stylebox_override("normal", _item_style(true))
			btn.add_theme_stylebox_override("hover", _item_style(true, true))
		else:
			btn.add_theme_stylebox_override("normal", _item_style())
			btn.add_theme_stylebox_override("hover", _item_style(false, true))
			btn.pressed.connect(_equip_item.bind(item))

		_items_grid.add_child(btn)
		_item_buttons.append(btn)

	var selected := AssetRegistry.get_clothing_by_id(equipped_id)
	if selected == null and not items.is_empty():
		selected = items[0]
	if selected:
		var lang := GameSettings.get_lang_code()
		var status := tr("[color=#a36b24](✓ жабдықталған)[/color]") if selected.id == equipped_id else ""
		_effect_label.text = tr("ҚАСИЕТІ: %s") % _effect_for(selected.id)
		_info_label.text = "[b]%s[/b]\n%s\n%s" % [
			selected.get_name_for_lang(lang),
			selected.get_desc_for_lang(lang),
			status,
		]
		_info_label.bbcode_enabled = true
	else:
		_effect_label.text = "ҚАСИЕТІ: —"
		_info_label.text = "Киімді таңдаңыз"

func _card_text(item: ClothingItem) -> String:
	var lang := GameSettings.get_lang_code()
	var name := item.get_name_for_lang(lang)
	if item.id == SaveManager.get_equipped(_current_slot):
		return "%s\n✓" % name
	if not SaveManager.is_unlocked(item.id):
		return tr("%s\n🔒 Жабық") % name
	return "%s" % name

func _effect_for(item_id: String) -> String:
	match item_id:
		"head_tymaq_01": return tr("Баяулау уақыты −30%")
		"torso_shapan_01": return tr("Соқыртекеге азырақ көрінесіз")
		"shoes_saptama_etik_01": return tr("Құрғақ жерде жылдамдық +8%")
	return tr("Сәндік зат")

func _item_style(equipped: bool = false, hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f6e8c8") if equipped else Color("fffaf0")
	sb.border_color = SanlaqDesignTokens.GOLD_DARK if equipped else Color("d8c39a")
	sb.set_border_width_all(3 if equipped else 1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)
	if hovered:
		sb.shadow_color = Color(0.04, 0.16, 0.23, 0.20)
		sb.shadow_size = 7
		sb.shadow_offset = Vector2(0, 3)
	return sb

func _tab_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SanlaqDesignTokens.GOLD if selected else Color("f8eed9")
	sb.border_color = SanlaqDesignTokens.GOLD_DARK if selected else Color("d6bf91")
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(10)
	if hovered and not selected:
		sb.bg_color = Color("f2dfb6")
	return sb

func _equip_item(item: ClothingItem) -> void:
	SaveManager.set_equipped(_current_slot, item.id)
	_apply_equipped_outfit()
	_refresh_items()
