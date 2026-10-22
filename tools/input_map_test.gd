extends "res://tools/test_case.gd"
## Раскладка клавиш из project.godot.


func _init() -> void:
	# Enter подтверждает выбор; Escape — это ui_cancel, а не «подтвердить».
	_check_keys("ui_accept", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], [KEY_ESCAPE])
	_check_keys("ui_cancel", [KEY_ESCAPE], [])
	_check_keys("move_up", [KEY_W, KEY_UP], [])
	_check_keys("move_down", [KEY_S, KEY_DOWN], [])
	_check_keys("move_left", [KEY_A, KEY_LEFT], [])
	_check_keys("move_right", [KEY_D, KEY_RIGHT], [])
	_check_keys("sprint", [KEY_SHIFT], [])
	finish("INPUT MAP")


func _check_keys(action: StringName, required: Array[Key], forbidden: Array[Key]) -> void:
	var bound: Array[Key] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			bound.append(event.physical_keycode)
	for key in required:
		check(key in bound, "%s: назначена %s" % [action, OS.get_keycode_string(key)])
	for key in forbidden:
		check(not key in bound, "%s: не назначена %s" % [action, OS.get_keycode_string(key)])
