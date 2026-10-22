extends Node

const SAVE_PATH := "user://save_data.json"
## Образ нового игрока. Если такого предмета нет в data/clothing, слот получает
## первый предмет из реестра.
const STARTER_OUTFIT := {
	ClothingItem.SlotType.HEAD: "head_borik_01",
	ClothingItem.SlotType.TORSO: "torso_kamzol_01",
	ClothingItem.SlotType.PANTS: "pants_shalbar_01",
	ClothingItem.SlotType.SHOES: "shoes_kebis_01",
}

var nickname: String = ""
var equipped: Dictionary = {}
var cloth_pool: Array[String] = []
var settings: Dictionary = {}
var career: Dictionary = {"wins": 0, "streak": 0, "best_streak": 0, "knowledge": 0}

func _ready() -> void:
	# Тесты и инструменты идут на чистом профиле и не портят сохранение игрока.
	if not RunContext.is_automated():
		_load_from_disk()
	_ensure_equipped_outfit()

func get_equipped(slot_type: ClothingItem.SlotType) -> String:
	return equipped.get(slot_type, "")

func set_equipped(slot_type: ClothingItem.SlotType, item_id: String) -> void:
	equipped[slot_type] = item_id
	_save_to_disk()

func is_equipped(item_id: String) -> bool:
	for slot in equipped.values():
		if slot == item_id:
			return true
	return false

func get_random_pool_item(slot_type: ClothingItem.SlotType) -> ClothingItem:
	var items := AssetRegistry.get_clothing(slot_type)
	if items.is_empty():
		return null
	return items[randi() % items.size()]

func equip_random_outfit() -> void:
	for slot in [ClothingItem.SlotType.HEAD, ClothingItem.SlotType.TORSO, ClothingItem.SlotType.PANTS, ClothingItem.SlotType.SHOES]:
		var item := get_random_pool_item(slot)
		if item:
			set_equipped(slot, item.id)

func get_setting(key: String, default: Variant = null) -> Variant:
	return settings.get(key, default)

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_save_to_disk()

func _save_to_disk() -> void:
	if RunContext.is_automated():
		return
	var data := {
		nickname = nickname,
		equipped = _dict_to_string_keys(equipped),
		cloth_pool = cloth_pool,
		settings = settings,
		career = career,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning("SaveManager: corrupted save, resetting")
		return

	var data: Variant = json.get_data()
	if not data is Dictionary:
		return

	nickname = data.get("nickname", "")
	equipped = _dict_int_keys(data.get("equipped", {}))
	cloth_pool = _array_string(data.get("cloth_pool", []))
	settings = data.get("settings", {})
	career = data.get("career", career)

## Заполняет пустые слоты и слоты с удалёнными предметами стартовым образом.
func _ensure_equipped_outfit() -> void:
	var changed := false
	for slot in ClothingItem.SlotType.values():
		var equipped_id: String = equipped.get(slot, "")
		if AssetRegistry.get_clothing_by_id(equipped_id) != null:
			continue
		var starter: String = STARTER_OUTFIT.get(slot, "")
		if AssetRegistry.get_clothing_by_id(starter) != null:
			equipped[slot] = starter
			changed = true
			continue
		var items := AssetRegistry.get_clothing(slot as ClothingItem.SlotType)
		if not items.is_empty():
			equipped[slot] = items[0].id
			changed = true
	if changed:
		_save_to_disk()

func _array_string(arr) -> Array[String]:
	var out: Array[String] = []
	if arr is Array:
		for e in arr:
			if e is String:
				out.append(e)
	return out

func _dict_int_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = d[k]
	return out

func _dict_to_string_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out

func commit() -> void:
	_save_to_disk()

func set_nickname(value: String) -> void:
	nickname = value
	_save_to_disk()

func record_match(won: bool, correct_answers: int) -> Dictionary:
	career["knowledge"] = int(career.get("knowledge", 0)) + correct_answers
	if won:
		career["wins"] = int(career.get("wins", 0)) + 1
		career["streak"] = int(career.get("streak", 0)) + 1
		career["best_streak"] = maxi(int(career.get("best_streak", 0)), int(career["streak"]))
	else:
		career["streak"] = 0
	_save_to_disk()
	return career.duplicate()

func reset_all() -> void:
	equipped.clear()
	cloth_pool.clear()
	nickname = ""
	settings.clear()
	career = {"wins": 0, "streak": 0, "best_streak": 0, "knowledge": 0}
	_ensure_equipped_outfit()
	_save_to_disk()
