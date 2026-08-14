class_name StickmanBody
extends Node2D

signal footstep_emitted(is_left: bool)

var skin_color: Color = Color(0.95, 0.84, 0.68):
	set(v):
		skin_color = v
		if _draw_node: _draw_node.queue_redraw()

var _clothing_colors: Dictionary = {}
var _current_speed: float = 0.0
var _facing_direction: Vector2 = Vector2.DOWN

@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _draw_node: Node2D = $DrawNode
@onready var _bp: Node2D = $BodyPivot
@onready var _arm_l: Node2D = $BodyPivot/LeftArm
@onready var _arm_r: Node2D = $BodyPivot/RightArm
@onready var _leg_l: Node2D = $BodyPivot/LeftLeg
@onready var _leg_r: Node2D = $BodyPivot/RightLeg

@onready var _layer_head: Sprite2D = $HeadPivot/HeadLayer
@onready var _layer_torso: Sprite2D = $BodyPivot/TorsoLayer
@onready var _layer_pants: Sprite2D = $BodyPivot/HipsPivot/PantsLayer
@onready var _layer_shoe_l: Sprite2D = $BodyPivot/LeftLeg/ShoeLayer
@onready var _layer_shoe_r: Sprite2D = $BodyPivot/RightLeg/ShoeLayer

func _ready() -> void:
	_create_animations()
	_anim_player.play("idle")

func set_clothing(slot_type: ClothingItem.SlotType, color: Color, texture: Texture2D = null) -> void:
	if texture:
		_clothing_colors.erase(slot_type)
		_apply_sprite(slot_type, texture)
	else:
		_clothing_colors[slot_type] = color
		_apply_sprite(slot_type, null)
	if _draw_node: _draw_node.queue_redraw()

func clear_clothing(slot_type: ClothingItem.SlotType) -> void:
	_clothing_colors.erase(slot_type)
	_apply_sprite(slot_type, null)
	if _draw_node: _draw_node.queue_redraw()

func apply_outfit(outfit: Dictionary) -> void:
	for key in outfit:
		var entry: Dictionary = outfit[key]
		var col: Color = entry.get("color", Color.WHITE)
		var tex: Texture2D = entry.get("texture", null)
		set_clothing(key as ClothingItem.SlotType, col, tex)

func get_clothing_colors() -> Dictionary:
	return _clothing_colors

func _apply_sprite(slot_type: ClothingItem.SlotType, texture: Texture2D) -> void:
	var sprite: Sprite2D
	match slot_type:
		ClothingItem.SlotType.HEAD: sprite = _layer_head
		ClothingItem.SlotType.TORSO: sprite = _layer_torso
		ClothingItem.SlotType.PANTS: sprite = _layer_pants
		ClothingItem.SlotType.SHOES: sprite = _layer_shoe_l
		_: return
	if sprite == null:
		return
	sprite.texture = texture
	sprite.visible = texture != null
	if slot_type == ClothingItem.SlotType.SHOES:
		_layer_shoe_r.texture = texture
		_layer_shoe_r.visible = texture != null

func set_movement_state(speed: float, direction: Vector2) -> void:
	_current_speed = speed
	if direction.length() > 0.01:
		_facing_direction = direction.normalized()

	if speed < 10.0:
		if _anim_player.current_animation != "idle":
			_anim_player.play("idle")
	else:
		var tgt_anim: String = "walk" if speed < 180.0 else "run"
		if _anim_player.current_animation != tgt_anim:
			_anim_player.play(tgt_anim)
		_anim_player.speed_scale = clampf(speed / 120.0, 0.5, 2.0)

	rotation = lerp_angle(rotation, _facing_direction.angle() + PI / 2, 0.15)

func _create_animations() -> void:
	var lib := AnimationLibrary.new()

	var idle := Animation.new()
	lib.add_animation("idle", idle)

	lib.add_animation("walk", _make_walk_anim(0.5, 20.0, 18.0, 1.0))
	lib.add_animation("run", _make_walk_anim(0.32, 28.0, 28.0, 2.0))

	_anim_player.add_animation_library("", lib)

func _make_walk_anim(length: float, leg_angle: float, arm_angle: float, bob: float) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	a.step = 0.05

	_add_track(a, "BodyPivot:position:y", Animation.TYPE_VALUE,
		[0.0, length / 4, length / 2, length * 3 / 4, length],
		[0.0, bob, 0.0, -bob, 0.0])

	_add_track(a, "BodyPivot/LeftLeg:rotation_degrees", Animation.TYPE_VALUE,
		[0.0, length / 2, length],
		[-leg_angle, leg_angle, -leg_angle])

	_add_track(a, "BodyPivot/RightLeg:rotation_degrees", Animation.TYPE_VALUE,
		[0.0, length / 2, length],
		[leg_angle, -leg_angle, leg_angle])

	_add_track(a, "BodyPivot/LeftArm:rotation_degrees", Animation.TYPE_VALUE,
		[0.0, length / 2, length],
		[arm_angle, -arm_angle, arm_angle])

	_add_track(a, "BodyPivot/RightArm:rotation_degrees", Animation.TYPE_VALUE,
		[0.0, length / 2, length],
		[-arm_angle, arm_angle, -arm_angle])

	_add_method_track(a, ".", "_emit_left_footstep", 0.0)
	_add_method_track(a, ".", "_emit_right_footstep", length / 2)

	return a

func _add_track(anim: Animation, path: String, type: int, times: Array, vals: Array) -> void:
	var idx: int = anim.add_track(type)
	anim.track_set_path(idx, path)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	anim.track_set_imported(idx, false)
	anim.track_set_enabled(idx, true)

	for k in range(times.size()):
		var t: float = times[k]
		var v: float = vals[k]
		anim.track_insert_key(idx, t, v)

func _add_method_track(anim: Animation, path: String, method: String, at_time: float) -> void:
	var idx: int = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(idx, path)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_NEAREST)
	anim.track_set_imported(idx, false)
	anim.track_set_enabled(idx, true)

	anim.track_insert_key(idx, at_time, {"method": method, "args": []})

func _emit_left_footstep() -> void:
	footstep_emitted.emit(true)

func _emit_right_footstep() -> void:
	footstep_emitted.emit(false)
