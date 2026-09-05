class_name CharacterVisual
extends Node2D

const BASE_SHEETS := [
	"res://assets/character/base/base.png",
	"res://assets/character/base/base_02.png",
	"res://assets/character/base/base_03.png",
]
const SHEET_W := 6
const FRAME_PX := 64
const DIRS := ["down", "up", "left", "right"]

var _current_dir: String = "down"
var _moving: bool = false
var _anim_timer: float = 0.0
var _layers: Array[AnimatedSprite2D] = []
var _base_variant := 0
var _pose_time := 0.0
var _rest_position := Vector2.ZERO
var _pending_clothing: Dictionary = {}

@onready var _base: AnimatedSprite2D = $Base
@onready var _head: AnimatedSprite2D = $Head
@onready var _torso: AnimatedSprite2D = $Torso
@onready var _pants: AnimatedSprite2D = $Pants
@onready var _shoes: AnimatedSprite2D = $Shoes

func _ready() -> void:
	_rest_position = position
	_layers = [_base, _shoes, _pants, _torso, _head]
	_apply_base_variant()
	# Callers sometimes build this node off-tree (e.g. inside a not-yet-added container)
	# and call set_clothing() before @onready vars like _head/_torso resolve — those calls
	# got queued below instead of silently no-op'ing, so flush them now that layers exist.
	for slot in _pending_clothing:
		_apply_clothing(slot, _pending_clothing[slot])
	_pending_clothing.clear()
	_apply_animation()

func set_base_variant(variant: int) -> void:
	_base_variant = posmod(variant, BASE_SHEETS.size())
	if is_node_ready():
		_apply_base_variant()

func _apply_base_variant() -> void:
	var base_tex := load(BASE_SHEETS[_base_variant]) as Texture2D
	if base_tex:
		_base.sprite_frames = _build_frames(base_tex)
	else:
		Telemetry.log_error("base sheet failed to load: %s" % BASE_SHEETS[_base_variant], "character_visual")

func set_clothing(slot: ClothingItem.SlotType, item: ClothingItem) -> void:
	if not is_node_ready():
		_pending_clothing[slot] = item
		return
	_apply_clothing(slot, item)

func _apply_clothing(slot: ClothingItem.SlotType, item: ClothingItem) -> void:
	var layer := _layer_for(slot)
	if layer == null:
		return
	if item and not item.texture_path.is_empty():
		var sheet := load(item.texture_path) as Texture2D
		if sheet:
			layer.sprite_frames = _build_frames(sheet)
			layer.visible = true
			layer.frame = 0
			_apply_animation()
			return
		Telemetry.log_error("clothing sheet failed to load: %s" % item.texture_path, "character_visual")
	layer.sprite_frames = null
	layer.visible = false

func set_direction(v: Vector2) -> void:
	if v.length_squared() < 0.01:
		return
	var dir: String
	if absf(v.x) > absf(v.y):
		dir = "left" if v.x < 0 else "right"
	else:
		dir = "up" if v.y < 0 else "down"
	if dir != _current_dir:
		_current_dir = dir
		_anim_timer = 0.0
		_apply_animation()

func set_moving(m: bool) -> void:
	if m != _moving:
		_moving = m
		_anim_timer = 0.0
		_apply_animation()

func _layer_for(slot: ClothingItem.SlotType) -> AnimatedSprite2D:
	match slot:
		ClothingItem.SlotType.HEAD: return _head
		ClothingItem.SlotType.TORSO: return _torso
		ClothingItem.SlotType.PANTS: return _pants
		ClothingItem.SlotType.SHOES: return _shoes
	return null

func _apply_animation() -> void:
	var anim := "%s_%s" % [_current_dir, "walk" if _moving else "idle"]
	for l in _layers:
		if l.sprite_frames and l.sprite_frames.has_animation(anim):
			l.animation = anim
			l.frame = 0

func _process(delta: float) -> void:
	var speed := 9.0 if _moving else 3.0
	var fcount := 4 if _moving else 2
	_anim_timer += delta
	_pose_time += delta
	var f := int(_anim_timer * speed) % fcount
	for l in _layers:
		if l.sprite_frames:
			l.frame = f
	# Общий пиксельный ритм оживляет все слои одновременно: одежда не «съезжает» с тела.
	var bounce := sin(_pose_time * (11.0 if _moving else 3.0))
	position = _rest_position + Vector2(0, round(bounce * (1.0 if _moving else 0.5)))

func _build_frames(sheet: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for di in DIRS.size():
		for anim in ["idle", "walk"]:
			var name := "%s_%s" % [DIRS[di], anim]
			sf.add_animation(name)
			sf.set_animation_speed(name, 3.0 if anim == "idle" else 9.0)
			sf.set_animation_loop(name, true)
			var cols: Array[int] = []
			cols.assign([0, 1] if anim == "idle" else [2, 3, 4, 5])
			for c in cols:
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(c * FRAME_PX, di * FRAME_PX, FRAME_PX, FRAME_PX)
				sf.add_frame(name, at)
	return sf
