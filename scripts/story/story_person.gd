class_name StoryPerson
extends Node2D
## Человек в мире «Дала жолы»: житель, с которым можно говорить (npc_id), или
## просто фигура. Стоит на месте и дышит; к игроку поворачивается, когда тот рядом.

const SHADOW := preload("res://assets/sprites/world/shadow.png")
## Насколько близко подойти, чтобы заговорить, в пикселях мира.
const TALK_RADIUS := 2.3 * StoryLayout.METER

var npc_id := ""
var display_name := ""
var _visual: CharacterVisual
var _facing := Vector2.DOWN


static func create(placement_look: String, npc: String, name_text: String, facing: Vector2) -> StoryPerson:
	var person := StoryPerson.new()
	person.npc_id = npc
	person.display_name = name_text
	person._facing = facing
	person._visual = StoryLooks.create(placement_look)
	return person


func _ready() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW
	shadow.position = Vector2(0, 8)
	shadow.z_as_relative = false
	shadow.z_index = WorldLayers.SHADOWS
	add_child(shadow)
	add_child(_visual)
	_visual.set_rest_position(Player.BODY_CENTER)
	_visual.set_direction(_facing)
	var body := StaticBody2D.new()
	body.collision_layer = WorldLayers.PHYSICS_WORLD
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	body.add_child(shape)
	add_child(body)


## Повернуться к тому, кто подошёл; отошёл — обратно, как стоял.
func look_at_point(point: Vector2, near: bool) -> void:
	var to := point - global_position
	var direction := _facing
	if near and to.length() > 1.0:
		direction = Vector2(signf(to.x), 0) if absf(to.x) > absf(to.y) else Vector2(0, signf(to.y))
	_visual.set_direction(direction)


func can_talk() -> bool:
	return not npc_id.is_empty()
