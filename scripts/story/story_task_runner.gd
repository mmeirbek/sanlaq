class_name StoryTaskRunner
extends Node2D
## Работа в мире: игрок ходит по месту и делает её сам, разговоры в это время
## закрыты. Баннер задания на HUD показывает заголовок, подсказку и ход работы.
## Подклассы — в scripts/story/tasks/.

signal finished

const SCRIPTS := {
	StoryBeat.Action.COLLECT: "res://scripts/story/tasks/collect_task.gd",
	StoryBeat.Action.BUILD: "res://scripts/story/tasks/build_task.gd",
	StoryBeat.Action.ESCORT: "res://scripts/story/tasks/escort_task.gd",
	StoryBeat.Action.FIND: "res://scripts/story/tasks/find_task.gd",
}
const GLOW := preload("res://assets/sprites/story/glow.png")
const BURST_COLORS: Array[Color] = [UiTokens.GOLD_LIGHT, UiTokens.GOLD, UiTokens.CREAM]

var task: StoryTask
## Мир сюжета (scenes/story/story_world.gd): HUD, тосты.
var story: Node
var player: Node2D
## Сортируемый по y контейнер мира: туда ставятся предметы задания.
var world: Node2D
var _spawned: Array[Node] = []
var _done := false


static func create(action: StoryBeat.Action, story_task: StoryTask) -> StoryTaskRunner:
	var runner: StoryTaskRunner = load(SCRIPTS[action]).new()
	runner.task = story_task
	return runner


func begin(story_world: Node, walker: Node2D, container: Node2D) -> void:
	story = story_world
	player = walker
	world = container
	story.get_node("%Hud").show_task(task.title, task.hint)
	setup()
	report()


## Куда показывать маркер и шевроны; null — никуда.
func target_point() -> Variant:
	return null


func setup() -> void:
	pass


func status() -> String:
	return ""


func report() -> void:
	story.get_node("%Hud").set_task_status(status())


func _process(delta: float) -> void:
	if _done or player == null:
		return
	tick(delta)


func tick(_delta: float) -> void:
	pass


func finish() -> void:
	if _done:
		return
	_done = true
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	finished.emit()
	queue_free()


## Предмет задания в мире: картинка нижним краем на точке, метры -> пиксели.
func spawn(name: String, meters: Vector2) -> Node2D:
	var holder := StoryLayout.place(world, name, meters, false)
	_spawned.append(holder)
	return holder


## Пятно света на земле под тем, что нужно поднять.
func glow_under(at: Vector2) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = GLOW
	glow.position = at
	glow.z_index = WorldLayers.DECALS
	world.get_parent().add_child(glow)
	_spawned.append(glow)
	return glow


func celebrate(at: Vector2, text: String) -> void:
	PixelBurst.spawn(world.get_parent(), at + Vector2(0, -32), BURST_COLORS, 14, Vector2(40, 120), Vector2(0, 260), 0.6)
	story.get_node("%Hud").toast(text, 1.5)


func flat_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / StoryLayout.METER
