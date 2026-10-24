class_name OutfitApplier
extends RefCounted
## Образы персонажей в одном месте: образ игрока из сохранения, готовые образы
## ботов и одевание CharacterVisual. Раньше этот код жил в четырёх копиях
## (главное меню, лобби, шкаф, игрок), и у ботов в лобби и в игре могли
## оказаться разные запасные вещи.
##
## Обращается к AssetRegistry и SaveManager — в тестах класс нельзя писать как тип.

## Образы ботов: id вещей по порядку слотов ClothingItem.SlotType.
const BOT_OUTFITS := [
	["head_tymaq_01", "torso_shapan_01", "pants_shalbar_01", "shoes_saptama_etik_01"],
	["head_takiya_01", "torso_koylek_01", "pants_shalbar_01", "shoes_masi_01"],
	["head_saukele_01", "torso_kamzol_01", "pants_shalbar_decorated_01", "shoes_kebis_01"],
	["head_kimeshek_01", "torso_shapan_01", "pants_shalbar_decorated_01", "shoes_saptama_etik_01"],
	["head_borik_01", "torso_kamzol_01", "pants_shalbar_01", "shoes_masi_01"],
	["head_tymaq_01", "torso_koylek_01", "pants_shalbar_decorated_01", "shoes_kebis_01"],
	["head_takiya_01", "torso_shapan_01", "pants_shalbar_01", "shoes_saptama_etik_01"],
]


## Слот -> вещь: что надето на игроке.
static func player_outfit() -> Dictionary:
	var outfit := {}
	for slot: ClothingItem.SlotType in ClothingItem.SlotType.values():
		outfit[slot] = _item_or_first(SaveManager.get_equipped(slot), slot)
	return outfit


## Слот -> вещь: образ бота с этим номером.
static func bot_outfit(index: int) -> Dictionary:
	var ids: Array = BOT_OUTFITS[posmod(index, BOT_OUTFITS.size())]
	var outfit := {}
	for slot: ClothingItem.SlotType in ClothingItem.SlotType.values():
		outfit[slot] = _item_or_first(ids[slot], slot)
	return outfit


## Стартовый образ с одной заменённой вещью — так энциклопедия показывает вещь
## на человеке.
static func starter_outfit_with(item: ClothingItem) -> Dictionary:
	var outfit := {}
	for slot: ClothingItem.SlotType in ClothingItem.SlotType.values():
		outfit[slot] = item if slot == item.slot_type else _item_or_first(SaveManager.STARTER_OUTFIT[slot], slot)
	return outfit


static func dress(visual: CharacterVisual, outfit: Dictionary) -> void:
	for slot: ClothingItem.SlotType in outfit:
		visual.set_clothing(slot, outfit[slot])


## Вещь по id, а если её нет в data/clothing — первая вещь слота.
static func _item_or_first(item_id: String, slot: ClothingItem.SlotType) -> ClothingItem:
	var item := AssetRegistry.get_clothing_by_id(item_id)
	if item == null:
		var items := AssetRegistry.get_clothing(slot)
		item = items[0] if not items.is_empty() else null
	return item
