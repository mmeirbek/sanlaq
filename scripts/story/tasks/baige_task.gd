extends StoryTaskRunner
## «Бәйге» прямо в ауле: игрок верхом, пять флажков по кругу аула — брать по
## порядку, последний — мәре. Соперник на сером коне скачет те же флажки и
## объезжает юрты и камни (в atilla шёл сквозь них). Кто первый взял пятый
## флажок — тот и выиграл; за 75 секунд не успел — тоже проигрыш.
##
## Дорогу сопернику ищет AStarGrid2D по сетке в метр: клетки, где круг всадника
## задел бы коллизию мира, закрыты. Простой объезд «свернуть, если прямо
## занято» застревал в щели между конём у коновязи и юртой.

const RIDE_SPEED_MULT := 1.8
## Скорость соперника в метрах в секунду: чуть медленнее игрока верхом
## (5,5 м/с × 1,8 ≈ 9,9), но он не петляет. Отстающий соперник чуть
## прибавляет, вырвавшийся — сбавляет, чтобы гонка шла вплотную.
const RIVAL_SPEED := 7.6
const RIVAL_CATCH_UP := 1.08
const RIVAL_EASE := 0.92
const MARK_METERS := 3.4
const RIVAL_MARK_METERS := 2.0
const RIVAL_RADIUS_METERS := 0.5
## Запас вокруг препятствий при поиске пути.
const PATH_CLEARANCE_METERS := 0.8
const WAYPOINT_METERS := 0.6
const TIME_LIMIT := 75.0
## Всадник сидит выше: фигура поднята над конём.
const SADDLE_LIFT := Vector2(0, -28)
const RIVAL_OFFSET_METERS := Vector2(2.6, 0)
const GALLOP_FPS := 12.0

var racing := false
var _mark := 0
var _rival_mark := 0
var _left := TIME_LIMIT
var _time := 0.0
var _return_position := Vector2.ZERO
var _flags: Array[Node2D] = []
var _rings: Array[Sprite2D] = []
var _horse: Sprite2D
var _rival: CharacterBody2D
var _rival_horse: Sprite2D
var _rival_rider: CharacterVisual
var _bay: Array[Texture2D] = []
var _grey: Array[Texture2D] = []
var _grid: AStarGrid2D
var _path := PackedVector2Array()
var _waypoint := 0


func picture_name() -> String:
	return "flag_gold"


func setup() -> void:
	_bay = [StoryLayout.texture("horse_bay_0"), StoryLayout.texture("horse_bay_1")]
	_grey = [StoryLayout.texture("horse_grey_0"), StoryLayout.texture("horse_grey_1")]
	for i in task.points.size():
		var flag := spawn("flag_red" if i < task.points.size() - 1 else "flag_gold", task.points[i])
		_flags.append(flag)
		_rings.append(glow_under(flag.position))

	_return_position = player.position
	var start := StoryLayout.to_world(task.goal)
	player.position = start
	player.speed_mult = RIDE_SPEED_MULT
	player.set_frozen(true)
	_horse = _mount(player, _bay[0])
	_rider(player).set_rest_position(Player.BODY_CENTER + SADDLE_LIFT)

	_rival = CharacterBody2D.new()
	_rival.collision_layer = 0
	_rival.collision_mask = WorldLayers.PHYSICS_WORLD
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RIVAL_RADIUS_METERS * StoryLayout.METER
	shape.shape = circle
	_rival.add_child(shape)
	_rival.position = start + StoryLayout.to_world(RIVAL_OFFSET_METERS)
	world.add_child(_rival)
	_spawned.append(_rival)
	_rival_horse = _mount(_rival, _grey[0])
	_rival_rider = StoryLooks.create("warrior")
	_rival.add_child(_rival_rider)
	_rival_rider.set_rest_position(Player.BODY_CENTER + SADDLE_LIFT)

	if story.get("autopilot"):
		start_race()
	else:
		var countdown := Countdown.new()
		story.get_node("%Overlay").add_child(countdown)
		_spawned.append(countdown)
		countdown.finished.connect(start_race)
		countdown.start(3)


## Конь под всадником: позади фигуры, копыта на точке земли.
func _mount(rider: Node2D, texture: Texture2D) -> Sprite2D:
	var horse := Sprite2D.new()
	horse.texture = texture
	horse.centered = false
	horse.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height() + 8)
	horse.show_behind_parent = true
	rider.add_child(horse)
	return horse


func _rider(body: Node2D) -> CharacterVisual:
	return body.get_node("CharacterVisual") as CharacterVisual


func start_race() -> void:
	if _done:
		return
	racing = true
	player.set_frozen(false)
	report()


func cleanup() -> void:
	racing = false
	if is_instance_valid(_horse):
		_horse.queue_free()
	player.speed_mult = 1.0
	_rider(player).set_rest_position(Player.BODY_CENTER)
	player.position = _return_position
	player.set_frozen(false)


func target_point() -> Variant:
	if not racing or _mark >= task.points.size():
		return null
	return StoryLayout.to_world(task.points[_mark])


func status() -> String:
	return tr("%s ОРЫН   ·   Белгі: %d / %d   ·   %d с") % [
		tr("1-ШІ") if _ahead() else tr("2-ШІ"), _mark, task.points.size(), ceili(_left)]


## Впереди ли игрок: больше флажков или тот же, но ближе к следующему.
func _ahead() -> bool:
	if _mark != _rival_mark:
		return _mark > _rival_mark
	if _mark >= task.points.size():
		return true
	var next := StoryLayout.to_world(task.points[_mark])
	return player.position.distance_to(next) <= _rival.position.distance_to(next)


func tick(delta: float) -> void:
	_time += delta
	_animate(delta)
	if not racing:
		return
	_left = maxf(0.0, _left - delta)
	if flat_distance(player.position, StoryLayout.to_world(task.points[_mark])) < MARK_METERS:
		_take_mark()
		if _mark >= task.points.size():
			celebrate(player.position, tr("Мәреге бірінші жеттің!"))
			finish()
			return
	_move_rival(delta)
	if _done:
		return
	if _left <= 0.0:
		_lose(tr("Уақыт бітті."))
		return
	report()


func _take_mark() -> void:
	var flag := _flags[_mark]
	PixelBurst.spawn(world.get_parent(), flag.position + Vector2(0, -40), BURST_COLORS, 14,
		Vector2(40, 120), Vector2(0, 260), 0.6)
	story.get_node("%Hud").toast("%d / %d" % [_mark + 1, task.points.size()], 1.0)
	flag.visible = false
	_rings[_mark].visible = false
	_mark += 1


func _move_rival(delta: float) -> void:
	if _rival_mark >= task.points.size():
		return
	if _grid == null:
		_build_grid()
	if _path.is_empty():
		_plan(task.points[_rival_mark])
	var target := _path[mini(_waypoint, _path.size() - 1)]
	var speed := RIVAL_SPEED * (RIVAL_EASE if _rival_mark > _mark else RIVAL_CATCH_UP)
	var step := (target - _rival.position).limit_length(speed * StoryLayout.METER * delta)
	_rival.move_and_collide(step)
	if absf(step.x) > 0.1:
		_rival_horse.flip_h = step.x > 0
		_rival_rider.set_direction(Vector2.RIGHT if step.x > 0 else Vector2.LEFT)
	if flat_distance(_rival.position, target) < WAYPOINT_METERS and _waypoint < _path.size() - 1:
		_waypoint += 1
	if flat_distance(_rival.position, StoryLayout.to_world(task.points[_rival_mark])) < RIVAL_MARK_METERS:
		_rival_mark += 1
		_path.clear()
		if _rival_mark >= task.points.size():
			_lose(tr("Қарсылас озып кетті."))


## Сетка аула в метр: закрыто всё, где всадник задел бы коллизию.
func _build_grid() -> void:
	var half: Vector2i = Vector2i(StoryLayout.HALF_SIZE[StoryBeat.Location.AUL])
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(-half, half * 2 + Vector2i.ONE)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	var probe := CircleShape2D.new()
	probe.radius = PATH_CLEARANCE_METERS * StoryLayout.METER
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = WorldLayers.PHYSICS_WORLD
	var space := _rival.get_world_2d().direct_space_state
	for x in range(_grid.region.position.x, _grid.region.end.x):
		for y in range(_grid.region.position.y, _grid.region.end.y):
			query.transform = Transform2D(0.0, StoryLayout.to_world(Vector2(x, y)))
			if not space.intersect_shape(query, 1).is_empty():
				_grid.set_point_solid(Vector2i(x, y))


func _plan(mark: Vector2) -> void:
	var from := Vector2i((_rival.position / StoryLayout.METER).round())
	var to := Vector2i(mark.round())
	from = from.clamp(_grid.region.position, _grid.region.end - Vector2i.ONE)
	# Соперник мог прижаться к препятствию — свою клетку считаем свободной.
	_grid.set_point_solid(from, false)
	_path.clear()
	for cell in _grid.get_id_path(from, to, true):
		_path.append(StoryLayout.to_world(Vector2(cell)))
	_path.append(StoryLayout.to_world(mark))
	_waypoint = 0


func _lose(why: String) -> void:
	story.get_node("%Hud").toast(why, 2.0)
	fail()


## Галоп: кадры коня, пока он движется; маяк — у следующего флажка.
func _animate(_delta: float) -> void:
	var player_moving: bool = racing and player.current_speed > 15.0
	_horse.texture = _bay[int(_time * GALLOP_FPS) % 2] if player_moving else _bay[0]
	if absf(player.velocity.x) > 1.0:
		_horse.flip_h = player.velocity.x > 0
	_rival_horse.texture = _grey[int(_time * GALLOP_FPS + 1) % 2] if racing else _grey[0]
	_rival_rider.set_moving(false)
	# Светится только следующий флажок и мигает целыми кадрами.
	for i in _rings.size():
		_rings[i].visible = i == _mark and int(_time * 3.0) % 3 != 0
