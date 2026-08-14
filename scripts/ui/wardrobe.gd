class_name WardrobeUI
extends Control

const SLOT_NAMES := {
	0: "Бас / Голова",
	1: "Дене / Торс",
	2: "Шалбар / Штаны",
	3: "Аяқ киім / Обувь",
}

var _current_slot: ClothingItem.SlotType = ClothingItem.SlotType.HEAD
var _mannequin: Node2D
var _item_buttons: Array[Button] = []

@onready var _title: Label = $Title
@onready var _slot_tabs: HBoxContainer = $RightPanel/Margin/VBox/Tabs
@onready var _items_grid: GridContainer = $RightPanel/Margin/VBox/Scroll/Items
@onready var _info_label: RichTextLabel = $RightPanel/Margin/VBox/Info
@onready var _back_btn: Button = $RightPanel/Margin/VBox/BackBtn

func _ready() -> void:
	_title.text = "ШКАФ — киім таңдау"
	_build_tabs()
	_build_back_button()
	_build_mannequin()
	_show_slot(_current_slot)

func _build_tabs() -> void:
	for slot in ClothingItem.SlotType.values():
		var btn := Button.new()
		btn.text = SLOT_NAMES.get(slot, str(slot))
		btn.custom_minimum_size = Vector2(120, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_show_slot.bind(slot as ClothingItem.SlotType))
		_slot_tabs.add_child(btn)

func _build_back_button() -> void:
	_back_btn.text = "← Меню"
	_back_btn.pressed.connect(func(): SceneRouter.go_to_main_menu())

func _build_mannequin() -> void:
	var pack := load("res://scenes/entities/character_visual.tscn") as PackedScene
	_mannequin = pack.instantiate() as Node2D
	_mannequin.scale = Vector2(3, 3)
	_mannequin.position = Vector2(340, 420)
	add_child(_mannequin)
	_apply_equipped_outfit()

func _apply_equipped_outfit() -> void:
	var visual := _mannequin as CharacterVisual
	for slot in ClothingItem.SlotType.values():
		var item_id := SaveManager.get_equipped(slot as ClothingItem.SlotType)
		var item := AssetRegistry.get_clothing_by_id(item_id)
		visual.set_clothing(slot as ClothingItem.SlotType, item)

func _show_slot(slot: ClothingItem.SlotType) -> void:
	_current_slot = slot
	_refresh_items()

func _refresh_items() -> void:
	for b in _item_buttons:
		b.queue_free()
	_item_buttons.clear()

	var items := AssetRegistry.get_clothing(_current_slot)
	var equipped_id := SaveManager.get_equipped(_current_slot)

	for item in items:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = item.get_name_for_lang(GameSettings.get_lang_code())
		if item.id == equipped_id:
			btn.text += "  ✓"
		if not item.icon_path.is_empty():
			var ico := load(item.icon_path) as Texture2D
			if ico:
				btn.icon = ico
				btn.expand_icon = true

		var unlocked := SaveManager.is_unlocked(item.id)
		btn.disabled = not unlocked
		if not unlocked:
			btn.modulate = Color(0.5, 0.5, 0.5, 1)
		else:
			btn.pressed.connect(_equip_item.bind(item))

		_items_grid.add_child(btn)
		_item_buttons.append(btn)

	var selected := AssetRegistry.get_clothing_by_id(equipped_id)
	if selected:
		var lang := GameSettings.get_lang_code()
		_info_label.text = "[b]%s[/b]\n%s" % [selected.get_name_for_lang(lang), selected.get_desc_for_lang(lang)]
		_info_label.bbcode_enabled = true
	else:
		_info_label.text = "Предмет не выбран"

func _equip_item(item: ClothingItem) -> void:
	SaveManager.set_equipped(_current_slot, item.id)
	_apply_equipped_outfit()
	_refresh_items()
