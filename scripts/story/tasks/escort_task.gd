extends StoryTaskRunner
## «Атты жетелеу»: конь идёт за игроком, пока тот рядом, и встаёт, если отстал.
## Конь — тело с коллизией и обходит камни и юрты (в atilla он шёл сквозь них).

const LEAD_REACH_METERS := 10.0
const KEEP_DISTANCE_METERS := 2.4
const DONE_METERS := 3.6
const SPEED_METERS := 3.4

var _horse: CharacterBody2D
var _horse_sprite: Sprite2D
var _frames: Array[Texture2D] = []
var _time := 0.0


func setup() -> void:
	spawn("post", task.goal)
	_frames = [StoryLayout.texture("horse_bay_0"), StoryLayout.texture("horse_bay_1")]
	_horse = CharacterBody2D.new()
	_horse.collision_layer = 0
	_horse.collision_mask = WorldLayers.PHYSICS_WORLD
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16
	shape.shape = circle
	_horse.add_child(shape)
	_horse_sprite = Sprite2D.new()
	_horse_sprite.texture = _frames[0]
	_horse_sprite.centered = false
	var size := _frames[0].get_size()
	_horse_sprite.offset = Vector2(-size.x / 2, -size.y)
	_horse.add_child(_horse_sprite)
	_horse.position = StoryLayout.to_world(task.points[0])
	world.add_child(_horse)
	_spawned.append(_horse)


func status() -> String:
	if flat_distance(_horse.position, player.position) >= LEAD_REACH_METERS:
		return tr("Атқа қайта бар!")
	var left := ceili(flat_distance(_horse.position, StoryLayout.to_world(task.goal)))
	return tr("Бағанаға дейін: %d қадам") % left


func target_point() -> Variant:
	var lost := flat_distance(_horse.position, player.position) >= LEAD_REACH_METERS
	return _horse.position if lost else StoryLayout.to_world(task.goal)


func tick(delta: float) -> void:
	_time += delta
	var to_player := flat_distance(_horse.position, player.position)
	var walking := to_player < LEAD_REACH_METERS and to_player > KEEP_DISTANCE_METERS
	_horse.velocity = (player.position - _horse.position).normalized() * SPEED_METERS * StoryLayout.METER if walking \
		else Vector2.ZERO
	_horse.move_and_slide()
	if walking and absf(_horse.velocity.x) > 1.0:
		_horse_sprite.flip_h = _horse.velocity.x > 0
	_horse_sprite.texture = _frames[int(_time * 6.0) % 2] if walking else _frames[0]
	report()
	if flat_distance(_horse.position, StoryLayout.to_world(task.goal)) < DONE_METERS:
		celebrate(_horse.position, tr("АТ БАЙЛАНДЫ!"))
		finish()
