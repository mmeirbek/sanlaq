class_name WardrobeUI
extends Control
## Шкаф: игрок выбирает одежду по слотам и сразу видит её на своём персонаже,
## который медленно поворачивается, — одежду видно со всех сторон.

const SLOT_NAMES := {
	ClothingItem.SlotType.HEAD: "Бас киім",
	ClothingItem.SlotType.TORSO: "Сырт киім",
	ClothingItem.SlotType.PANTS: "Шалбар",
	ClothingItem.SlotType.SHOES: "Аяқ киім",
}
## Иконка вкладки слота — узнаваемая вещь этого слота.
const SLOT_ICONS := {
	ClothingItem.SlotType.HEAD: preload("res://assets/sprites/items/head_borik_01.png"),
	ClothingItem.SlotType.TORSO: preload("res://assets/sprites/items/torso_koylek_01.png"),
	ClothingItem.SlotType.PANTS: preload("res://assets/sprites/items/pants_shalbar_01.png"),
	ClothingItem.SlotType.SHOES: preload("res://assets/sprites/items/shoes_saptama_etik_01.png"),
}
const CHARACTER_SCENE := preload("res://scenes/entities/character_visual.tscn")
const CHECK_ICON := preload("res://assets/ui/frames/check.png")
## Персонаж на пьедестале — ×4, целым масштабом.
const MANNEQUIN_SCALE := 4
## Порядок поворота и пауза на каждой стороне, секунды.
const TURN_ORDER: Array[Vector2] = [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
const TURN_SECONDS := 1.1

var _current_slot: ClothingItem.SlotType = ClothingItem.SlotType.HEAD
var _mannequin: CharacterVisual
var _turn := 0
var _tab_cards: Dictionary = {}

@onready var _slot_tabs: HBoxContainer = %Tabs
@onready var _items_grid: GridContainer = %Items
@onready var _mannequin_slot: Control = %MannequinSlot

func _ready() -> void:
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_main_menu)
	_build_tabs()
	_build_mannequin()
	_show_slot(_current_slot)

func _build_tabs() -> void:
	for slot: ClothingItem.SlotType in SLOT_ICONS:
		var card := SelectableCard.new()
		card.compact = true
		card.tooltip_text = tr("Киім санатын ашу · Open category")
		var icon := TextureRect.new()
		icon.texture = SLOT_ICONS[slot]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		card.pressed.connect(_show_slot.bind(slot))
		_slot_tabs.add_child(card)
		_tab_cards[slot] = card

func _build_mannequin() -> void:
	_mannequin = CHARACTER_SCENE.instantiate()
	_mannequin.scale = Vector2.ONE * MANNEQUIN_SCALE
	_mannequin_slot.add_child(_mannequin)
	_mannequin_slot.resized.connect(_place_mannequin)
	_place_mannequin()
	_apply_equipped_outfit()
	var timer := Timer.new()
	timer.wait_time = TURN_SECONDS
	timer.autostart = true
	timer.timeout.connect(_turn_mannequin)
	add_child(timer)
	_turn_mannequin()

## Персонаж стоит по центру пьедестала; позиция — по пикселю арта.
func _place_mannequin() -> void:
	var step := UiTokens.PIXEL * MANNEQUIN_SCALE
	_mannequin.set_rest_position((_mannequin_slot.size / 2 / step).floor() * step)

func _turn_mannequin() -> void:
	_mannequin.set_direction(TURN_ORDER[_turn % TURN_ORDER.size()])
	_turn += 1

func _apply_equipped_outfit() -> void:
	for slot in ClothingItem.SlotType.values():
		_mannequin.set_clothing(slot, AssetRegistry.get_clothing_by_id(SaveManager.get_equipped(slot)))

func _show_slot(slot: ClothingItem.SlotType) -> void:
	_current_slot = slot
	for tab_slot in _tab_cards:
		(_tab_cards[tab_slot] as SelectableCard).selected = tab_slot == slot
	%SlotName.text = SLOT_NAMES[slot]
	_refresh_items()

func _refresh_items() -> void:
	for child in _items_grid.get_children():
		_items_grid.remove_child(child)
		child.queue_free()
	var equipped_id := SaveManager.get_equipped(_current_slot)
	var lang := GameSettings.get_lang_code()
	for item in AssetRegistry.get_clothing(_current_slot):
		var card := SelectableCard.new()
		card.compact = true
		card.selected = item.id == equipped_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = item.get_desc_for_lang(lang)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = load(item.icon_path) as Texture2D
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var name_label := Label.new()
		name_label.text = item.get_name_for_lang(lang)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		card.add_child(box)
		card.pressed.connect(_equip_item.bind(item))
		_items_grid.add_child(card)
	_show_details(AssetRegistry.get_clothing_by_id(equipped_id), equipped_id)

func _show_details(item: ClothingItem, equipped_id: String) -> void:
	if item == null:
		%EffectLabel.text = tr("ҚАСИЕТІ: —")
		%ItemName.text = tr("Киімді таңдаңыз")
		%ItemDesc.text = ""
		%Equipped.visible = false
		return
	var lang := GameSettings.get_lang_code()
	%EffectLabel.text = tr("ҚАСИЕТІ: %s") % _effect_for(item.id)
	%ItemName.text = item.get_name_for_lang(lang)
	%ItemDesc.text = item.get_desc_for_lang(lang)
	%Equipped.visible = item.id == equipped_id

func _effect_for(item_id: String) -> String:
	match item_id:
		"head_tymaq_01": return tr("Баяулау уақыты −30%")
		"torso_shapan_01": return tr("Соқыртекеге азырақ көрінесіз")
		"shoes_saptama_etik_01": return tr("Құрғақ жерде жылдамдық +8%")
	return tr("Сәндік зат")

func _equip_item(item: ClothingItem) -> void:
	SaveManager.set_equipped(_current_slot, item.id)
	_apply_equipped_outfit()
	_refresh_items()
