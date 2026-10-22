class_name SlotTabs
extends HBoxContainer
## Вкладки слотов одежды — иконками узнаваемых вещей (шапка, рубаха, штаны,
## сапог): понятно без слов. Шкаф и энциклопедия.

signal slot_selected(slot: ClothingItem.SlotType)

const ICONS := {
	ClothingItem.SlotType.HEAD: preload("res://assets/sprites/items/head_borik_01.png"),
	ClothingItem.SlotType.TORSO: preload("res://assets/sprites/items/torso_koylek_01.png"),
	ClothingItem.SlotType.PANTS: preload("res://assets/sprites/items/pants_shalbar_01.png"),
	ClothingItem.SlotType.SHOES: preload("res://assets/sprites/items/shoes_saptama_etik_01.png"),
}

var _cards: Dictionary = {}

## Подсказка при наведении на вкладку.
@export var hint := "":
	set(value):
		hint = value
		for card in _cards.values():
			(card as SelectableCard).tooltip_text = value


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	for slot: ClothingItem.SlotType in ICONS:
		var card := SelectableCard.new()
		card.compact = true
		card.tooltip_text = hint
		var icon := TextureRect.new()
		icon.texture = ICONS[slot]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		card.pressed.connect(_on_tab_pressed.bind(slot))
		add_child(card)
		_cards[slot] = card


func select(slot: ClothingItem.SlotType) -> void:
	for tab_slot in _cards:
		(_cards[tab_slot] as SelectableCard).selected = tab_slot == slot


func _on_tab_pressed(slot: ClothingItem.SlotType) -> void:
	select(slot)
	slot_selected.emit(slot)
