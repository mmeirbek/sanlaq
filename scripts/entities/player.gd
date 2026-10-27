class_name Player
extends CharacterBody2D

@export var player_index: int = 0
@export var is_sokyroteke: bool = false
@export var is_bot: bool = false

signal stepped(sound_radius: float)
signal runner_sprint_changed(time_left: float, uses_left: int)

## Позиция игрока — точка на земле под ногами: по ней работают коллизии и
## сортировка по глубине. Фигура нарисована выше, её центр — здесь.
const BODY_CENTER := Vector2(0, -24)
## Улитка над головой замедленного — та же иконка, что в HUD.
const SLOW_ICON := preload("res://assets/ui/hud/slow.png")
const SLOW_MARK_POSITION := Vector2(0, -72)
## Мигание целыми кадрами вместо полупрозрачности: пиксель-арт не бывает
## прозрачным наполовину. Раз в столько секунд фигура пропадает и появляется.
const BLINK_STEP := 0.1
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
var _slow_mark: Sprite2D
var _name_label: Label
var _shield_timer: float = 0.0
var _shadow: Sprite2D
var _wade: Sprite2D
var _noise_timer: float = 0.0
var _noise_random: float = 0.0
var _equipped_items: Dictionary = {}
var runner_sprint_time := 0.0
var runner_sprint_uses := RUNNER_SPRINT_USES
var bot_speed_mult: float = 1.0
## Множитель извне: в «Дала жолы» игрок на коне в бәйге.
var speed_mult: float = 1.0
var _footprint_boost: bool = false

const FOOTPRINT_BOOST_MULT := 1.1
const RUNNER_SPRINT_MULT := 1.55

## Имена ботов по порядку — одни и те же в лобби и в игре.
const BOT_NAMES := ["Айгүл", "Батыр", "Дәулет", "Аружан", "Нұрлан", "Жанар"]

func _ready() -> void:
	_controller = $PlayerController
	_visual = $CharacterVisual
	_visual.set_rest_position(BODY_CENTER)
	_name_label = $NameLabel
	_shadow = $Shadow
	_slow_mark = Sprite2D.new()
	_slow_mark.texture = SLOW_ICON
	_slow_mark.position = SLOW_MARK_POSITION
	_slow_mark.visible = false
	add_child(_slow_mark)
	_wade = $Wade
	# Тень лежит на земле под всеми стоящими объектами (см. WorldLayers).
	_shadow.z_as_relative = false
	_shadow.z_index = WorldLayers.SHADOWS
	_mode = AssetRegistry.get_default_mode()
	if _mode == null:
		_mode = GameModeDefinition.new()

	_noise_random = randf_range(0.0, 1.5)
	_visual.set_base_variant(player_index)
	_setup_clothing()

func _setup_clothing() -> void:
	_wear(OutfitApplier.player_outfit())

## Образ бота с этим номером — тот же, что у его портрета в лобби.
func apply_outfit_profile(profile_index: int) -> void:
	_wear(OutfitApplier.bot_outfit(profile_index))

func _wear(outfit: Dictionary) -> void:
	for slot: ClothingItem.SlotType in outfit:
		_set_outfit_item(slot, outfit[slot])

## Имя бота на языке игры: на английском — латиницей (Айгүл -> Aigul).
static func bot_name_for(bot_index: int) -> String:
	return TranslationServer.translate(BOT_NAMES[posmod(bot_index, BOT_NAMES.size())])

func _set_outfit_item(slot: ClothingItem.SlotType, item: ClothingItem) -> void:
	_equipped_items[slot] = item
	_visual.set_clothing(slot, item)

func revive() -> void:
	eliminated = false
	frozen = false
	_controller.enabled = not is_bot
	visible = true
	_visual.visible = true
	_slow_mark.visible = false
	set_deferred("collision_layer", WorldLayers.PHYSICS_WORLD)
	set_deferred("collision_mask", WorldLayers.PHYSICS_WORLD)
	slow_timer = 0.0
	_shield_timer = 0.0
	set_water_override(false)
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
	_slow_mark.visible = false
	# Пойманный мигает и исчезает; вспышку поимки рисует игра (PixelBurst).
	var tw := create_tween()
	for i in 6:
		tw.tween_callback(func() -> void: _visual.visible = i % 2 == 1)
		tw.tween_interval(BLINK_STEP)
	tw.tween_callback(func() -> void: visible = false)

func set_frozen(f: bool) -> void:
	frozen = f
	if f:
		velocity = Vector2.ZERO

func apply_slow(duration: float) -> void:
	var adjusted_duration := duration * _clothing_product("slow_duration_mult")
	slow_timer = maxf(slow_timer, adjusted_duration)
	_slow_mark.visible = slow_timer > 0

func is_slowed() -> bool:
	return slow_timer > 0

func get_controller() -> PlayerController:
	return _controller

func set_water_override(in_water: bool) -> void:
	_in_water = in_water
	# В воде вместо тени — вода поверх ног: видно, что игрок бредёт и замедлен.
	_shadow.visible = not in_water
	_wade.visible = in_water

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
			_slow_mark.visible = false

	if _shield_timer > 0:
		_shield_timer -= delta
		_visual.visible = _shield_timer <= 0 or int(_shield_timer / BLINK_STEP) % 2 == 0

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
	player_speed *= get_clothing_speed_mult() * speed_mult
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

func get_clothing_speed_mult() -> float:
	return 1.0 if _in_water else _clothing_product("dry_speed_mult")

func get_visibility_multiplier() -> float:
	return _clothing_product("visibility_mult")

## Свойства одежды берутся из полей ClothingItem и перемножаются.
func _clothing_product(property: StringName) -> float:
	var product := 1.0
	for item: ClothingItem in _equipped_items.values():
		if item:
			product *= float(item.get(property))
	return product

func set_as_sokyroteke(active: bool) -> void:
	is_sokyroteke = active
