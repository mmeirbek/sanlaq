extends Node2D

@onready var stickman: Node2D = get_parent()

var _skin: Color
var _colors: Dictionary

func _ready() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	var body: StickmanBody = stickman as StickmanBody
	if body == null:
		return
	_skin = body.skin_color
	_colors = body._clothing_colors.duplicate()
	queue_redraw()

func _draw() -> void:
	var body_root: Node2D = stickman
	if body_root == null or _skin.a == 0:
		return

	var bp: Node2D = body_root.get_node_or_null("BodyPivot") as Node2D
	if bp == null:
		return

	var bp_pos: Vector2 = to_local(bp.global_position)
	var arm_l: Vector2 = to_local((bp.get_node("LeftArm") as Node2D).global_position)
	var arm_r: Vector2 = to_local((bp.get_node("RightArm") as Node2D).global_position)
	var leg_l: Vector2 = to_local((bp.get_node("LeftLeg") as Node2D).global_position)
	var leg_r: Vector2 = to_local((bp.get_node("RightLeg") as Node2D).global_position)

	var c_head: Color = _colors.get(ClothingItem.SlotType.HEAD, Color.TRANSPARENT)
	var c_torso: Color = _colors.get(ClothingItem.SlotType.TORSO, Color.TRANSPARENT)
	var c_pants: Color = _colors.get(ClothingItem.SlotType.PANTS, Color.TRANSPARENT)
	var c_shoes: Color = _colors.get(ClothingItem.SlotType.SHOES, Color.TRANSPARENT)

	if c_shoes.a > 0:
		_draw_foot(leg_l + Vector2(0, 18), c_shoes)
		_draw_foot(leg_r + Vector2(0, 18), c_shoes)

	if c_pants.a > 0:
		_draw_leg(leg_l, c_pants)
		_draw_leg(leg_r, c_pants)

	_draw_leg(leg_l, _skin)
	_draw_leg(leg_r, _skin)

	_draw_arm(arm_l, _skin)
	_draw_arm(arm_r, _skin)

	if c_torso.a > 0:
		_draw_torso(bp_pos, c_torso, 9)

	_draw_torso(bp_pos, _skin, 7)
	_draw_head(bp_pos, _skin, c_head)

func _draw_head(pos: Vector2, skin: Color, cloth: Color) -> void:
	var r := 10.0
	draw_circle(pos + Vector2(0, -18), r, skin)
	if cloth.a > 0:
		draw_circle(pos + Vector2(0, -18), r + 1, cloth)

func _draw_torso(pos: Vector2, col: Color, w: int) -> void:
	var hw := float(w)
	var pts := PackedVector2Array([
		pos + Vector2(-hw, -13), pos + Vector2(hw, -13),
		pos + Vector2(hw - 1, 0), pos + Vector2(-(hw - 1), 0),
	])
	draw_colored_polygon(pts, col)

func _draw_arm(pos: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-2, 0), pos + Vector2(2, 0),
		pos + Vector2(1.5, 15), pos + Vector2(-1.5, 15),
	])
	draw_colored_polygon(pts, col)

func _draw_leg(pos: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-2.5, 0), pos + Vector2(2.5, 0),
		pos + Vector2(2, 18), pos + Vector2(-2, 18),
	])
	draw_colored_polygon(pts, col)

func _draw_foot(pos: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-4.5, 0), pos + Vector2(4.5, 0),
		pos + Vector2(5, 6), pos + Vector2(-5, 6),
	])
	draw_colored_polygon(pts, col)
