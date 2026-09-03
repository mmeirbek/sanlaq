class_name ClothingItem
extends Resource

enum SlotType { HEAD, TORSO, PANTS, SHOES }
enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: String = ""
@export var slot_type: SlotType = SlotType.HEAD
@export var name_kz: String = ""
@export var name_en: String = ""
@export_multiline var desc_kz: String = ""
@export_multiline var desc_en: String = ""
@export var color: Color = Color.WHITE
@export var rarity: Rarity = Rarity.COMMON
@export var unlock_by_default: bool = true
@export var wrong_answers_kz: Array[String] = []
@export var wrong_answers_en: Array[String] = []
@export var texture_path: String = ""
@export var icon_path: String = ""
@export var reference_photo_path: String = ""
@export var price: int = 0
@export var unlock_condition: int = 0

func get_name_for_lang(lang: String) -> String:
	match lang:
		"en": return name_en
		_: return name_kz

func get_desc_for_lang(lang: String) -> String:
	match lang:
		"en": return desc_en
		_: return desc_kz

func get_wrong_answers_for_lang(lang: String) -> Array[String]:
	if lang == "en" and not wrong_answers_en.is_empty():
		return wrong_answers_en
	return wrong_answers_kz

func get_slot_folder() -> String:
	match slot_type:
		SlotType.HEAD: return "head"
		SlotType.TORSO: return "torso"
		SlotType.PANTS: return "pants"
		SlotType.SHOES: return "shoes"
	return "unknown"
