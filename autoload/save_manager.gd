extends Node

const SAVE_PATH := "user://save_data.json"

var nickname: String = ""
var unlocked_clothing: Array[String] = []
var equipped: Dictionary = {}
var cloth_pool: Array[String] = []
var settings: Dictionary = {}

func _ready() -> void:
	_load_from_disk()

func get_equipped(slot_type: ClothingItem.SlotType) -> String:
	return equipped.get(slot_type, "")

func set_equipped(slot_type: ClothingItem.SlotType, item_id: String) -> void:
	equipped[slot_type] = item_id
	_save_to_disk()

func is_unlocked(item_id: String) -> bool:
	return item_id in unlocked_clothing

func is_equipped(item_id: String) -> bool:
	for slot in equipped.values():
		if slot == item_id:
			return true
	return false

func unlock_item(item_id: String) -> void:
	if not is_unlocked(item_id):
		unlocked_clothing.append(item_id)
		_save_to_disk()

func get_random_pool_item(slot_type: ClothingItem.SlotType) -> ClothingItem:
	var items := AssetRegistry.get_clothing(slot_type)
	if items.is_empty():
		return null
	var unlocked: Array[ClothingItem] = []
	for item in items:
		if is_unlocked(item.id):
			unlocked.append(item)
	if unlocked.is_empty():
		for item in items:
			if item.unlock_by_default:
				unlocked.append(item)
		if unlocked.is_empty():
			return null
	return unlocked[randi() % unlocked.size()]

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
	var data := {
		nickname = nickname,
		unlocked_clothing = unlocked_clothing,
		equipped = _dict_to_string_keys(equipped),
		cloth_pool = cloth_pool,
		settings = settings,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_unlock_defaults()
		_equip_defaults()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning("SaveManager: corrupted save, resetting")
		_unlock_defaults()
		_equip_defaults()
		return

	var data: Variant = json.get_data()
	if not data is Dictionary:
		_unlock_defaults()
		_equip_defaults()
		return

	nickname = data.get("nickname", "")
	unlocked_clothing = _array_string(data.get("unlocked_clothing"))
	equipped = _dict_int_keys(data.get("equipped", {}))
	cloth_pool = _array_string(data.get("cloth_pool", []))
	settings = data.get("settings", {})

	if unlocked_clothing.is_empty():
		_unlock_defaults()
	if equipped.is_empty():
		_equip_defaults()

func _unlock_defaults() -> void:
	for item in AssetRegistry.clothing_items:
		if item.unlock_by_default:
			if not is_unlocked(item.id):
				unlocked_clothing.append(item.id)

func _equip_defaults() -> void:
	if equipped.is_empty():
		for item in AssetRegistry.clothing_items:
			if item.unlock_by_default and not equipped.has(item.slot_type):
				set_equipped(item.slot_type, item.id)

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

func reset_all() -> void:
	unlocked_clothing.clear()
	equipped.clear()
	cloth_pool.clear()
	nickname = ""
	settings.clear()
	_unlock_defaults()
	_equip_defaults()
	_save_to_disk()
