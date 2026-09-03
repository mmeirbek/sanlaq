class_name FootprintSystem
extends Node
## Runner footstep marks the sokyroteke can spot to briefly gain speed.

const PRINT_LIFETIME := 4.5
const SIGHT_RADIUS := 160.0

var _prints: Array[Dictionary] = []

func leave_print(pos: Vector2, facing: Vector2) -> void:
	_prints.append({pos = pos, facing = facing, life = 0.0})

func _process(delta: float) -> void:
	var i: int = _prints.size() - 1
	while i >= 0:
		var pr: Dictionary = _prints[i]
		pr.life += delta
		if pr.life >= PRINT_LIFETIME:
			_prints.remove_at(i)
		i -= 1

func get_prints() -> Array:
	return _prints

func has_visible_print(from_pos: Vector2, radius: float = SIGHT_RADIUS) -> bool:
	for pr in _prints:
		if from_pos.distance_to(pr.pos) <= radius:
			return true
	return false
