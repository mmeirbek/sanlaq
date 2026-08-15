extends CanvasLayer

const RADIUS := 90.0

var player: Player
var _joy_active: bool = false
var _joy_vec: Vector2 = Vector2.ZERO
var _sprint_active: bool = false

var _joy_base: Control
var _knob: Control
var _sprint_btn: Button

func _ready() -> void:
	_joy_base = Control.new()
	_joy_base.custom_minimum_size = Vector2(RADIUS * 2, RADIUS * 2)
	_joy_base.size = Vector2(RADIUS * 2, RADIUS * 2)
	_joy_base.position = Vector2(40, 720 - RADIUS * 2 - 40)
	_joy_base.gui_input.connect(_on_joy_input)
	_joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_base.draw.connect(func(): _draw_circle(_joy_base, Color(1, 1, 1, 0.15)))
	add_child(_joy_base)

	_knob = Control.new()
	_knob.custom_minimum_size = Vector2(70, 70)
	_knob.size = Vector2(70, 70)
	_knob.position = Vector2(RADIUS - 35, RADIUS - 35)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.draw.connect(func(): _draw_circle(_knob, Color(1, 1, 1, 0.45)))
	_joy_base.add_child(_knob)

	_sprint_btn = Button.new()
	_sprint_btn.text = "SPRINT"
	_sprint_btn.custom_minimum_size = Vector2(140, 90)
	_sprint_btn.position = Vector2(1280 - 180, 720 - 130)
	_sprint_btn.focus_mode = Control.FOCUS_NONE
	_sprint_btn.button_down.connect(func(): _sprint_active = true)
	_sprint_btn.button_up.connect(func(): _sprint_active = false)
	add_child(_sprint_btn)

func _draw_circle(c: Control, col: Color) -> void:
	var r := c.size / 2.0
	c.draw_circle(r, minf(c.size.x, c.size.y) * 0.5, col)

func _on_joy_input(event: InputEvent) -> void:
	var center := _joy_base.size / 2.0
	if event is InputEventScreenTouch:
		if event.pressed:
			_joy_active = true
			_joy_vec = ((event.position - center) / RADIUS).limit_length(1.0)
		else:
			_joy_active = false
			_joy_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		_joy_vec = ((event.position - center) / RADIUS).limit_length(1.0)

	if _joy_active:
		_knob.position = center + _joy_vec * RADIUS - _knob.size / 2.0
	else:
		_knob.position = center - _knob.size / 2.0

func _process(_delta: float) -> void:
	if player == null or player.eliminated:
		return
	# Sprint is an ability modifier. It cannot take over the controller, otherwise
	# pressing it while using WASD/arrow keys replaces movement with Vector2.ZERO.
	player._controller.set_touch_sprint_active(_sprint_active)
	player._controller.touch_override = _joy_active
	if _joy_active:
		player._controller.set_remote_input(_joy_vec, _sprint_active)
