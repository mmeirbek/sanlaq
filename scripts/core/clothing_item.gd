class_name ClothingItem
extends Resource

enum SlotType { HEAD, TORSO, PANTS, SHOES }
## Названия слотов — ключи перевода (assets/i18n/ui_strings.csv).
const SLOT_NAMES := {
	SlotType.HEAD: "Бас киім",
	SlotType.TORSO: "Сырт киім",
	SlotType.PANTS: "Шалбар",
	SlotType.SHOES: "Аяқ киім",
}
enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: String = ""
@export var slot_type: SlotType = SlotType.HEAD
@export var name_kz: String = ""
@export var name_en: String = ""
@export_multiline var desc_kz: String = ""
@export_multiline var desc_en: String = ""
@export var color: Color = Color.WHITE
@export var rarity: Rarity = Rarity.COMMON
@export var wrong_answers_kz: Array[String] = []
@export var wrong_answers_en: Array[String] = []
@export var texture_path: String = ""
@export var icon_path: String = ""

@export_group("Свойство в игре")
## Во сколько раз короче замедление ловца (тымақ — 0,7).
@export var slow_duration_mult: float = 1.0
## Во сколько раз меньше радиус, в котором ловец видит бегуна (шапан — 0,82).
@export var visibility_mult: float = 1.0
## Множитель скорости на суше, в воде не действует (саптама етік — 1,08).
@export var dry_speed_mult: float = 1.0
## Подпись свойства в шкафу — ключ перевода. Пусто — «Сәндік зат».
@export var effect_text: String = ""

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
