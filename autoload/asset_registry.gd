extends Node

var clothing_items: Array[ClothingItem] = []
var clothing_by_id: Dictionary = {}
var clothing_by_slot: Dictionary = {}
var maps: Array[MapDefinition] = []
var maps_by_id: Dictionary = {}
var game_modes: Array[GameModeDefinition] = []
var bot_profiles: Array[BotProfile] = []

func _ready() -> void:
	_scan_data_folder("clothing")
	_scan_data_folder("maps")
	_scan_data_folder("game_modes")
	_scan_data_folder("bots")

func _scan_data_folder(subfolder: String) -> void:
	var dir := DirAccess.open("res://data/%s" % subfolder)
	if dir == null:
		push_warning("AssetRegistry: cannot open data/%s" % subfolder)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := "res://data/%s/%s" % [subfolder, file_name]
			var res := load(full_path) as Resource
			if res == null:
				push_warning("AssetRegistry: failed to load %s" % full_path)
			else:
				_register_resource(res, subfolder)
		file_name = dir.get_next()
	dir.list_dir_end()

func _register_resource(res: Resource, subfolder: String) -> void:
	match subfolder:
		"clothing":
			if res is ClothingItem:
				clothing_items.append(res)
				clothing_by_id[res.id] = res
				if not clothing_by_slot.has(res.slot_type):
					clothing_by_slot[res.slot_type] = []
				clothing_by_slot[res.slot_type].append(res)
		"maps":
			if res is MapDefinition:
				maps.append(res)
				maps_by_id[res.map_id] = res
		"game_modes":
			if res is GameModeDefinition:
				game_modes.append(res)
		"bots":
			if res is BotProfile:
				bot_profiles.append(res)

func get_clothing(slot_type: ClothingItem.SlotType) -> Array[ClothingItem]:
	var out: Array[ClothingItem] = []
	var items: Array = clothing_by_slot.get(slot_type, [])
	for it in items:
		out.append(it)
	return out

func get_clothing_by_id(item_id: String) -> ClothingItem:
	return clothing_by_id.get(item_id, null)

func get_map(map_id: String) -> MapDefinition:
	return maps_by_id.get(map_id, null)

func get_default_mode() -> GameModeDefinition:
	if game_modes.is_empty():
		return null
	return game_modes[0]

func get_bot_profile(id: String) -> BotProfile:
	for bp in bot_profiles:
		if bp.profile_id == id:
			return bp
	return null

func get_random_bot_profile() -> BotProfile:
	if bot_profiles.is_empty():
		return null
	return bot_profiles[randi() % bot_profiles.size()]
