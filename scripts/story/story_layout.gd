class_name StoryLayout
extends RefCounted
## Места «Тарих жолы»: аул, степь, Түркістан. Расстановка взята из atilla
## (AulPrototypeBuilder) — метры, y вниз. Всё стоящее — Sprite2D, нижний край
## картинки — точка на земле, чтобы сортировка по y шла по ногам.

const METER := 40.0
const WORLD_TEXTURES := "res://assets/sprites/world/%s.png"
const STORY_TEXTURES := "res://assets/sprites/story/%s.png"
## Полуразмер места в метрах: дальше — забор и тёмная степь.
const HALF_SIZE := {
	StoryBeat.Location.AUL: Vector2(23, 22),
	StoryBeat.Location.STEPPE: Vector2(24, 23),
	StoryBeat.Location.CITY: Vector2(18, 18),
}
## Где появляется игрок и где стоит арба для переезда.
const SPAWN := {
	StoryBeat.Location.AUL: Vector2(0, 0),
	StoryBeat.Location.STEPPE: Vector2(0, -16),
	StoryBeat.Location.CITY: Vector2(0, 13),
}
const CART := {
	StoryBeat.Location.AUL: Vector2(2.8, 18.5),
	StoryBeat.Location.STEPPE: Vector2(2.8, -20.5),
	StoryBeat.Location.CITY: Vector2(6.2, 5.6),
}
const NAMES := {
	StoryBeat.Location.AUL: "Ауыл",
	StoryBeat.Location.STEPPE: "Дала",
	StoryBeat.Location.CITY: "Түркістан",
}

## Юрта в atilla задана центром, а картинка стоит передним краем стены.
const YURT_FRONT := 2.6
## [картинка, x, y, радиус коллизии в метрах (0 — проходимо), отразить]
const AUL := [
	["yurt", -12, -9, 2.4, false], ["yurt", 12, -10, 2.4, false], ["yurt", -13, 9, 2.4, false],
	["yurt", 13, 10, 2.4, false],
	["campfire_0", -3.6, 1.6, 0.6, false], ["well", 4.6, 6.4, 0.7, false], ["cart", -7.4, -8.6, 0.9, false],
	["rock_0", -7, 5, 0.5, false], ["rock_1", 7, -4, 0.5, false], ["rock_0", -18, -2, 0.5, false],
	["rock_1", 17, -2, 0.5, false],
	["log_h", -8.5, -10, 0.6, false], ["log_h", 16.2, 9.5, 0.6, false],
	["horse_bay_0", 10.6, 3.4, 0.8, false], ["horse_grey_0", 12.4, 4.8, 0.8, false],
	["horse_grey_0", -10.8, -6.4, 0.8, true],
	["camel", -10.4, 5.2, 0.9, false], ["camel", -12.6, 6.4, 0.9, true],
	["hay", 14.5, -4.4, 0.5, false], ["hay", 15.8, -3.2, 0.5, false], ["hay", 16.4, -5.4, 0.5, false],
	["sandyq", -9.4, -11.4, 0, false], ["tandyr", -5.8, 3.6, 0.4, false], ["hay", 9.4, -9.2, 0.5, false],
	["firewood", -1.9, 3.2, 0, false], ["sandyq", 13.6, 6.6, 0, false], ["hay", -13.8, -3.2, 0.5, false],
	["fence_h", -9, -14, 0, false], ["fence_h", -6, -14, 0, false], ["fence_h", 6, -14, 0, false],
	["fence_h", 9, -14, 0, false],
]
const STEPPE := [
	["yurt", -6.5, -10.5, 2.4, false], ["campfire_0", -4.2, 4.4, 0.6, false],
	["rock_0", -11, -4, 0.5, false], ["rock_1", 9, 3, 0.5, false], ["rock_0", -6, 14, 0.5, false],
	["rock_1", 13, -12, 0.5, false], ["rock_0", -17, 3, 0.5, false],
	["horse_grey_0", 8.5, -9.5, 0.8, false], ["horse_bay_0", 10.2, -8.2, 0.8, true], ["camel", 14, 6, 0.9, false],
	["hay", -8.2, -11.6, 0.5, false], ["firewood", -5.6, 5.8, 0, false], ["sandyq", -4.8, -9.4, 0, false],
]
## Рощи — кусты кучкой; без коллизии, чтобы не запирать проходы.
const GROVES := {
	StoryBeat.Location.AUL: [[-17, -13], [17, -14], [-18, 14], [18, 15], [-5, -18], [7, 19], [-15.5, -1.5], [15.5, 0.5]],
	StoryBeat.Location.STEPPE: [[-20, -12], [19, -6], [-16, 12], [15, 16], [-8, -20]],
	StoryBeat.Location.CITY: [],
}
const PROPS := {
	StoryBeat.Location.AUL: AUL,
	StoryBeat.Location.STEPPE: STEPPE,
	StoryBeat.Location.CITY: [],
}


static func to_world(meters: Vector2) -> Vector2:
	return (meters * METER / UiTokens.PIXEL).round() * UiTokens.PIXEL


static func texture(name: String) -> Texture2D:
	var path := STORY_TEXTURES % name
	if not ResourceLoader.exists(path):
		path = WORLD_TEXTURES % name
	return load(path) as Texture2D


## Земля: трава (в степи — дикая) на весь участок и дорога через центр.
static func build_ground(parent: Node2D, location: StoryBeat.Location) -> void:
	var half: Vector2 = HALF_SIZE[location] * METER
	var outside := Sprite2D.new()
	outside.texture = texture("grass_wild")
	outside.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	outside.region_enabled = true
	outside.region_rect = Rect2(-half * 2, half * 4)
	outside.z_index = WorldLayers.WILD_GRASS
	parent.add_child(outside)
	var ground := Sprite2D.new()
	ground.texture = texture("grass_wild" if location == StoryBeat.Location.STEPPE else "grass")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(-half, half * 2)
	ground.z_index = WorldLayers.GROUND
	parent.add_child(ground)


## Всё стоящее — в сортируемый по y контейнер, коллизии — там же.
static func build_props(world: Node2D, location: StoryBeat.Location) -> void:
	for prop: Array in PROPS[location]:
		var front := YURT_FRONT if prop[0] == "yurt" else 0.0
		var body := place(world, prop[0], Vector2(prop[1], prop[2] + front), prop[4])
		if prop[3] > 0:
			add_collider(body, prop[3], front)
	for grove: Array in GROVES[location]:
		for offset in [Vector2(0, 0), Vector2(1.2, 0.6), Vector2(-1, 0.9)]:
			place(world, "bush", Vector2(grove[0], grove[1]) + offset, false)
	_fence(world, location)
	place(world, "cart", CART[location], false)


## Картинка нижним краем на точке земли.
static func place(world: Node2D, name: String, meters: Vector2, flip: bool) -> Node2D:
	var holder := Node2D.new()
	holder.position = to_world(meters)
	var sprite := Sprite2D.new()
	sprite.texture = texture(name)
	sprite.centered = false
	var size := sprite.texture.get_size()
	sprite.offset = (Vector2(-size.x / 2, -size.y) / UiTokens.PIXEL).floor() * UiTokens.PIXEL
	sprite.flip_h = flip
	holder.add_child(sprite)
	world.add_child(holder)
	return holder


## Круг коллизии; back_m — насколько центр предмета дальше его нижнего края.
static func add_collider(holder: Node2D, radius_m: float, back_m := 0.0) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = WorldLayers.PHYSICS_WORLD
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius_m * METER
	shape.shape = circle
	shape.position = Vector2(0, -back_m * METER - circle.radius * 0.5)
	body.add_child(shape)
	holder.add_child(body)


## Забор по краю участка и невидимые стены, чтобы не уйти в тёмную степь.
static func _fence(world: Node2D, location: StoryBeat.Location) -> void:
	var half: Vector2 = HALF_SIZE[location] * METER
	var walls := StaticBody2D.new()
	walls.collision_layer = WorldLayers.PHYSICS_WORLD
	for side in [Rect2(-half.x, -half.y - 40, half.x * 2, 40), Rect2(-half.x, half.y, half.x * 2, 40),
			Rect2(-half.x - 40, -half.y, 40, half.y * 2), Rect2(half.x, -half.y, 40, half.y * 2)]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = side.size
		shape.shape = rect
		shape.position = side.get_center()
		walls.add_child(shape)
	world.add_child(walls)
	var post_w := texture("fence_h").get_width()
	var x := -half.x
	while x < half.x:
		for y in [-half.y, half.y]:
			var piece := Sprite2D.new()
			piece.texture = texture("fence_h")
			piece.centered = false
			piece.position = Vector2(x, y - piece.texture.get_height())
			piece.z_index = WorldLayers.DECALS
			world.get_parent().add_child(piece)
		x += post_w
