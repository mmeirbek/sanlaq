class_name GameCamera
extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 5.0
@export var zoom_level: Vector2 = Vector2(1.0, 1.0)
@export var shake_decay: float = 0.8
@export var max_shake: float = 6.0

var _shake_strength: float = 0.0

func _ready() -> void:
	zoom = zoom_level
	if target:
		global_position = target.global_position

func _process(delta: float) -> void:
	if target:
		var target_pos := target.global_position
		global_position = global_position.lerp(target_pos, follow_speed * delta)

	if _shake_strength > 0.1:
		_shake_strength = lerpf(_shake_strength, 0.0, shake_decay * delta)
		offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	else:
		_shake_strength = 0.0
		offset = Vector2.ZERO

func set_target(t: Node2D) -> void:
	target = t

func add_shake(strength: float) -> void:
	_shake_strength += strength
	if _shake_strength > max_shake:
		_shake_strength = max_shake
