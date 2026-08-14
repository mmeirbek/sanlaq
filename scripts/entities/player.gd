class_name Player
extends CharacterBody2D

@export var player_index: int = 0
@export var is_sokyroteke: bool = false
@export var is_bot: bool = false

signal caught(target: Player)
signal stepped(sound_radius: float)

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
var _shield_timer: float = 0.0
var _noise_timer: float = 0.0
var _noise_random: float = 0.0

func _ready() -> void:
	_controller = $PlayerController
	_visual = $CharacterVisual
	_mode = AssetRegistry.get_default_mode()
	if _mode == null:
		_mode = GameModeDefinition.new()

	_noise_random = randf_range(0.0, 1.5)
	_setup_clothing()

func _setup_clothing() -> void:
	for slot in ClothingItem.SlotType.values():
		var item_id := SaveManager.get_equipped(slot as ClothingItem.SlotType)
		var item := AssetRegistry.get_clothing_by_id(item_id)
		_visual.set_clothing(slot as ClothingItem.SlotType, item)

func apply_random_outfit() -> void:
	for slot in ClothingItem.SlotType.values():
		var items := AssetRegistry.get_clothing(slot as ClothingItem.SlotType)
		var item: ClothingItem = null
		if not items.is_empty():
			item = items[randi() % items.size()]
		_visual.set_clothing(slot as ClothingItem.SlotType, item)

func revive() -> void:
	eliminated = false
	frozen = false
	_controller.enabled = not is_bot
	visible = true
	modulate = Color.WHITE
	set_deferred("collision_layer", 5)
	set_deferred("collision_mask", 5)
	slow_timer = 0.0
	_in_water = false
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
	slow_timer = maxf(slow_timer, duration)
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

	_noise_timer -= delta
	if _noise_timer <= 0:
		var interval := _mode.standing_noise_interval
		if current_speed > 150:
			interval = 0.6
		elif current_speed > 50:
			interval = 2.0
		elif current_speed > 8:
			interval = 3.5
		_noise_timer = interval + randf_range(-0.3, 0.3)
		_emit_noise()

	var direction := _controller.get_direction()
	var sprint := _controller.is_sprinting()

	var player_speed := _mode.player_base_speed
	if is_sokyroteke:
		player_speed *= _mode.sokyroteke_speed_mult
	elif sprint:
		player_speed *= 1.2

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

func _emit_noise() -> void:
	var radius := 30.0
	if current_speed > 150:
		radius = 120.0
	elif current_speed > 50:
		radius = 70.0
	elif current_speed > 8:
		radius = 40.0
	stepped.emit(radius)

func apply_shield(duration: float) -> void:
	_shield_timer = duration

func has_shield() -> bool:
	return _shield_timer > 0

func catch_player(target: Player) -> void:
	if target.has_shield() or not target.is_alive():
		return
	caught.emit(target)

func is_alive() -> bool:
	return not eliminated

func get_random_clothing_item_for_quiz() -> ClothingItem:
	var slots := ClothingItem.SlotType.values()
	var slot_index := randi() % slots.size()
	var eq_id := SaveManager.get_equipped(slots[slot_index] as ClothingItem.SlotType)
	var item := AssetRegistry.get_clothing_by_id(eq_id)
	if item == null:
		var all_in_slot := AssetRegistry.get_clothing(slots[slot_index] as ClothingItem.SlotType)
		if not all_in_slot.is_empty():
			item = all_in_slot[randi() % all_in_slot.size()]
	return item

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
