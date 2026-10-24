extends Control
## Энциклопедия казахской одежды: коллекция по слотам и описание выбранной вещи
## с иллюстрацией — крупная иконка и персонаж, на котором эта вещь надета.

const RARITY_NAMES := {
	ClothingItem.Rarity.COMMON: "Кәдімгі",
	ClothingItem.Rarity.RARE: "Сирек",
	ClothingItem.Rarity.LEGENDARY: "Аңыз",
}
const CHARACTER_SCENE := preload("res://scenes/entities/character_visual.tscn")
## Персонаж в иллюстрации — ×3, целым масштабом.
const MANNEQUIN_SCALE := 3

var _current_slot: ClothingItem.SlotType = ClothingItem.SlotType.HEAD
var _mannequin: CharacterVisual

@onready var _tabs: SlotTabs = %Tabs
@onready var _grid: GridContainer = %Grid
@onready var _mannequin_slot: Control = %MannequinSlot

func _ready() -> void:
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_main_menu)
	_tabs.slot_selected.connect(_show_slot)
	_build_mannequin()
	_show_slot(_current_slot)

func _build_mannequin() -> void:
	_mannequin = CHARACTER_SCENE.instantiate()
	_mannequin.scale = Vector2.ONE * MANNEQUIN_SCALE
	_mannequin.set_direction(Vector2.DOWN)
	_mannequin_slot.add_child(_mannequin)
	var step := UiTokens.PIXEL * MANNEQUIN_SCALE
	_mannequin.set_rest_position((_mannequin_slot.custom_minimum_size / 2 / step).floor() * step)

func _show_slot(slot: ClothingItem.SlotType) -> void:
	_current_slot = slot
	_tabs.select(slot)
	%SlotName.text = ClothingItem.SLOT_NAMES[slot]
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var lang := GameSettings.get_lang_code()
	var items := AssetRegistry.get_clothing(slot)
	for item in items:
		var card := ClothingCard.create(item, item.get_name_for_lang(lang))
		card.pressed.connect(_select.bind(item))
		_grid.add_child(card)
	if not items.is_empty():
		_select(items[0])

func _select(item: ClothingItem) -> void:
	for card in _grid.get_children():
		(card as ClothingCard).selected = (card as ClothingCard).item.id == item.id
	var lang := GameSettings.get_lang_code()
	%Icon.texture = load(item.icon_path) as Texture2D
	%NameLabel.text = item.get_name_for_lang(lang)
	%MetaLabel.text = "%s · %s" % [tr(ClothingItem.SLOT_NAMES[item.slot_type]), tr(RARITY_NAMES[item.rarity])]
	%DescLabel.text = item.get_desc_for_lang(lang)
	_dress_mannequin(item)

## Персонаж в стартовом образе, но с выбранной вещью — так её видно на человеке.
func _dress_mannequin(item: ClothingItem) -> void:
	OutfitApplier.dress(_mannequin, OutfitApplier.starter_outfit_with(item))
