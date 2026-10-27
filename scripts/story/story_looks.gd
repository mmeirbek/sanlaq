class_name StoryLooks
extends RefCounted
## Облики людей «Дала жолы» (ключи look из data/story, как в atilla): тело и
## вещи по слотам. Собираются из тех же слоёв, что персонаж Соқыртеке; сауыт и
## дулыға есть только здесь (tools/artgen/characters.py, STORY_ITEMS).

const CHARACTER_SCENE := preload("res://scenes/entities/character_visual.tscn")
const LAYERS := "res://assets/sprites/character/%s/%s.png"

## look -> [тело 0..2, голова, торс, штаны, обувь].
const LOOKS := {
	"kerey": [0, "head_borik_01", "torso_shapan_01", "pants_shalbar_01", "shoes_saptama_etik_01"],
	"abylai": [2, "head_borik_01", "torso_kamzol_01", "pants_shalbar_decorated_01", "shoes_saptama_etik_01"],
	"kabanbay": [0, "head_dulyga_01", "torso_sauyt_01", "pants_shalbar_decorated_01", "shoes_saptama_etik_01"],
	"bi": [2, "head_tymaq_01", "torso_shapan_01", "pants_shalbar_decorated_01", "shoes_masi_01"],
	"elder": [0, "head_tymaq_01", "torso_shapan_01", "pants_shalbar_01", "shoes_masi_01"],
	"woman": [1, "head_kimeshek_01", "torso_koylek_01", "pants_shalbar_01", "shoes_kebis_01"],
	"child": [0, "head_takiya_01", "torso_koylek_01", "pants_shalbar_01", "shoes_kebis_01"],
	"child_girl": [1, "head_takiya_01", "torso_kamzol_01", "pants_shalbar_decorated_01", "shoes_masi_01"],
	"resident": [2, "head_takiya_01", "torso_kamzol_01", "pants_shalbar_01", "shoes_kebis_01"],
	"envoy": [2, "head_tymaq_01", "torso_kamzol_01", "pants_shalbar_decorated_01", "shoes_saptama_etik_01"],
	"envoy2": [1, "head_borik_01", "torso_shapan_01", "pants_shalbar_decorated_01", "shoes_masi_01"],
	"warrior": [0, "head_dulyga_01", "torso_sauyt_01", "pants_shalbar_01", "shoes_saptama_etik_01"],
	"raider": [1, "head_tymaq_01", "torso_sauyt_01", "pants_shalbar_decorated_01", "shoes_saptama_etik_01"],
}
const SLOTS: Array[ClothingItem.SlotType] = [
	ClothingItem.SlotType.HEAD, ClothingItem.SlotType.TORSO, ClothingItem.SlotType.PANTS, ClothingItem.SlotType.SHOES,
]


## Персонаж в облике look (неизвестный облик — житель).
static func create(look: String) -> CharacterVisual:
	var visual: CharacterVisual = CHARACTER_SCENE.instantiate()
	dress(visual, look)
	return visual


static func dress(visual: CharacterVisual, look: String) -> void:
	var parts: Array = LOOKS.get(look, LOOKS["resident"])
	visual.set_base_variant(parts[0])
	for i in SLOTS.size():
		var item_id: String = parts[i + 1]
		var item := ClothingItem.new()
		item.id = item_id
		item.slot_type = SLOTS[i]
		item.texture_path = LAYERS % [item_id.get_slice("_", 0), item_id]
		visual.set_clothing(SLOTS[i], item)
