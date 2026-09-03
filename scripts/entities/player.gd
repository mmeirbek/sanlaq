class_name Player
extends CharacterBody2D

@export var player_index: int = 0
@export var is_sokyroteke: bool = false
@export var is_bot: bool = false

signal stepped(sound_radius: float)
signal runner_sprint_changed(time_left: float, uses_left: int)

const RUNNER_SPRINT_DURATION := 3.0
const RUNNER_SPRINT_USES := 1

var current_speed: float = 0.0
var max_speed: float = 220.0
var bot_name: String = ""
var eliminated: bool = false
var frozen: bool = false
var slow_timer: float = 0.0
var _in_water: bool = false
var _mode: GameModeDefinition
var _controller: PlayerController
var _visual: CharacterVisual
var _name_label: Label
var _shield_timer: float = 0.0
var _noise_timer: float = 0.0
var _noise_random: float = 0.0
var _equipped_items: Dictionary = {}
var runner_sprint_time := 0.0
var runner_sprint_uses := RUNNER_SPRINT_USES
var bot_speed_mult: float = 1.0
var _footprint_boost: bool = false

const FOOTPRINT_BOOST_MULT := 1.1
const RUNNER_SPRINT_MULT := 1.55
const SAPTAMA_ETIK_MULT := 1.08

const OUTFIT_PROFILES := [
	["head_tymaq_01", "torso_shapan_01", "pants_shalbar_01", "shoes_saptama_etik_01"],
	["head_takiya_01", "torso_koylek_01", "pants_shalbar_01", "shoes_masi_01"],
	["head_saukele_01", "torso_kamzol_01", "pants_shalbar_decorated_01", "shoes_kebis_01"],
	["head_kimeshek_01", "torso_shapan_01", "pants_shalbar_decorated_01", "shoes_saptama_etik_01"],
	["head_borik_01", "torso_kamzol_01", "pants_shalbar_01", "shoes_masi_01"],
	["head_tymaq_01", "torso_koylek_01", "pants_shalbar_decorated_01", "shoes_kebis_01"],
	["head_takiya_01", "torso_shapan_01", "pants_shalbar_01", "shoes_saptama_etik_01"],
]

func _ready() -> void:
	_controller = $PlayerController
	_visual = $CharacterVisual
	_name_label = $NameLabel
	_mode = AssetRegistry.get_default_mode()
	if _mode == null:
		_mode = GameModeDefinition.new()

	_noise_random = randf_range(0.0, 1.5)
	_visual.set_base_variant(player_index)
	_setup_clothing()

func _setup_clothing() -> void:
	for slot in ClothingItem.SlotType.values():
		var item_id := SaveManager.get_equipped(slot as ClothingItem.SlotType)
		var item := AssetRegistry.get_clothing_by_id(item_id)
		_set_outfit_item(slot as ClothingItem.SlotType, item)

func apply_random_outfit() -> void:
	for slot in ClothingItem.SlotType.values():
		var items := AssetRegistry.get_clothing(slot as ClothingItem.SlotType)
		var item: ClothingItem = null
		if not items.is_empty():
			item = items[randi() % items.size()]
		_set_outfit_item(slot as ClothingItem.SlotType, item)

func apply_outfit_profile(profile_index: int) -> void:
	var profile := get_outfit_profile(profile_index)
	for slot in ClothingItem.SlotType.values():
		var item_id: String = profile[int(slot)]
		var item := AssetRegistry.get_clothing_by_id(item_id)
		if item:
			_set_outfit_item(slot as ClothingItem.SlotType, item)
		else:
			apply_random_outfit()
			return

static func get_outfit_profile(profile_index: int) -> Array:
	return OUTFIT_PROFILES[posmod(profile_index, OUTFIT_PROFILES.size())]

func _set_outfit_item(slot: ClothingItem.SlotType, item: ClothingItem) -> void:
	_equipped_items[slot] = item
	_visual.set_clothing(slot, item)

func revive() -> void:
	eliminated = false
	frozen = false
	_controller.enabled = not is_bot
	visible = true
	modulate = Color.WHITE
	set_deferred("collision_layer", 5)
	set_deferred("collision_mask", 5)
	slow_timer = 0.0
	_shield_timer = 0.0
	_in_water = false
	runner_sprint_time = 0.0
	runner_sprint_uses = RUNNER_SPRINT_USES
	runner_sprint_changed.emit(runner_sprint_time, runner_sprint_uses)
	velocity = Vector2.ZERO

func eliminate() -> void:
	if eliminated:
		return
	eliminated = true
	frozen = false
	_controller.enabled = false
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 0.2, 0.2, 1), 0.25)
	tw.parallel().tween_property(self, "scale", Vector2(1.25, 1.25), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): visible = false)

func set_frozen(f: bool) -> void:
	frozen = f
	if f:
		velocity = Vector2.ZERO

func apply_slow(duration: float) -> void:
	var adjusted_duration := duration * (0.7 if _wears("head_tymaq_01") else 1.0)
	slow_timer = maxf(slow_timer, adjusted_duration)
	modulate = Color(0.5, 0.6, 1.0, 1.0)

func is_slowed() -> bool:
	return slow_timer > 0

func set_water_override(in_water: bool) -> void:
	_in_water = in_water

func _physics_process(delta: float) -> void:
	if eliminated:
		return

	if frozen:
		velocity = Vector2.ZERO
		_visual.set_moving(false)
		current_speed = 0.0
		return

	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			modulate = Color.WHITE

	if _shield_timer > 0:
		_shield_timer -= delta
		modulate.a = 0.4 + sin(_shield_timer * 10.0) * 0.2

	var direction := _controller.get_direction()
	var sprint_requested := _controller.is_sprinting()
	if not is_sokyroteke:
		if runner_sprint_time > 0.0:
			runner_sprint_time = maxf(0.0, runner_sprint_time - delta)
			if runner_sprint_time == 0.0:
				runner_sprint_changed.emit(runner_sprint_time, runner_sprint_uses)
		elif sprint_requested and runner_sprint_uses > 0:
			runner_sprint_uses -= 1
			runner_sprint_time = RUNNER_SPRINT_DURATION
			runner_sprint_changed.emit(runner_sprint_time, runner_sprint_uses)
	var sprint := runner_sprint_time > 0.0

	var player_speed := _mode.player_base_speed
	if is_sokyroteke:
		player_speed *= _mode.sokyroteke_speed_mult
		if _footprint_boost:
			player_speed *= FOOTPRINT_BOOST_MULT
	elif sprint:
		player_speed *= RUNNER_SPRINT_MULT
	if _wears("shoes_saptama_etik_01") and not _in_water:
		player_speed *= SAPTAMA_ETIK_MULT
	if is_bot:
		player_speed *= bot_speed_mult

	if slow_timer > 0:
		player_speed *= _mode.slow_speed_mult
	if _in_water:
		player_speed *= _mode.water_speed_mult

	if direction.length() < 0.05:
		velocity = velocity.move_toward(Vector2.ZERO, player_speed * delta * 4)
		current_speed = velocity.length()
	else:
		velocity = velocity.move_toward(direction * player_speed, player_speed * delta * 8)
		current_speed = velocity.length()

	move_and_slide()
	_visual.set_direction(direction)
	_visual.set_moving(current_speed > 15.0)
	_update_footsteps(delta)

func _update_footsteps(delta: float) -> void:
	if current_speed <= 8.0:
		_noise_timer = 0.0
		return
	_noise_timer -= delta
	if _noise_timer > 0.0:
		return
	var interval := 0.38 if current_speed > 250.0 else (0.52 if current_speed > 150.0 else 0.72)
	_noise_timer = interval + randf_range(-0.05, 0.05)
	_emit_noise()

func _emit_noise() -> void:
	var radius := 30.0
	if current_speed > 150:
		radius = 120.0
	elif current_speed > 50:
		radius = 70.0
	elif current_speed > 8:
		radius = 40.0
	stepped.emit(radius)

func set_display_name(name_text: String) -> void:
	_name_label.text = name_text

func set_name_label_visible(v: bool) -> void:
	_name_label.visible = v

func set_bot_speed_mult(m: float) -> void:
	bot_speed_mult = m

func set_footprint_boost(active: bool) -> void:
	_footprint_boost = active

func apply_shield(duration: float) -> void:
	_shield_timer = duration

func has_shield() -> bool:
	return _shield_timer > 0

func is_alive() -> bool:
	return not eliminated

func get_random_clothing_item_for_quiz() -> ClothingItem:
	var slots := ClothingItem.SlotType.values()
	var slot_index := randi() % slots.size()
	var slot := slots[slot_index] as ClothingItem.SlotType
	var item: ClothingItem = _equipped_items.get(slot, null)
	if item == null:
		var all_in_slot := AssetRegistry.get_clothing(slots[slot_index] as ClothingItem.SlotType)
		if not all_in_slot.is_empty():
			item = all_in_slot[randi() % all_in_slot.size()]
	return item

func get_visibility_multiplier() -> float:
	return 0.82 if _wears("torso_shapan_01") else 1.0

func _wears(item_id: String) -> bool:
	for item in _equipped_items.values():
		if item and item.id == item_id:
			return true
	return false

func set_as_sokyroteke(active: bool) -> void:
	is_sokyroteke = active

func apply_center_text(_text: String) -> void:
	pass

func get_random_clothing_color(slot_type: ClothingItem.SlotType) -> Color:
	var eq_id := SaveManager.get_equipped(slot_type)
	var item := AssetRegistry.get_clothing_by_id(eq_id)
	if item:
		return item.color
	return Color.WHITE
