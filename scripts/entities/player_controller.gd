class_name PlayerController
extends Node

@export var enabled: bool = true
@export var input_provider_id: int = 0

signal input_changed(direction: Vector2, sprint: bool)

var _direction: Vector2 = Vector2.ZERO
var _sprinting: bool = false
var touch_override: bool = false

func _ready() -> void:
	set_process(enabled)

func _process(_delta: float) -> void:
	if not enabled:
		return
	if touch_override:
		return

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	var sprint := Input.is_action_pressed("sprint")

	if dir.length() > 1.0:
		dir = dir.normalized()

	if dir != _direction or sprint != _sprinting:
		_direction = dir
		_sprinting = sprint
		input_changed.emit(dir, sprint)

func get_direction() -> Vector2:
	return _direction

func is_sprinting() -> bool:
	return _sprinting

func set_remote_input(dir: Vector2, sprint: bool) -> void:
	if _direction != dir or _sprinting != sprint:
		_direction = dir
		_sprinting = sprint
		input_changed.emit(dir, sprint)
