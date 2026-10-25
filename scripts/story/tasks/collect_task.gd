extends StoryTaskRunner
## «Отын жинау»: пройти по разбросанным вязанкам и собрать нужное число.

const PICKUP_METERS := 1.9

var _items: Array[Node2D] = []
var _glows: Dictionary = {}
var _taken := 0


func setup() -> void:
	for i in task.points.size():
		var item := spawn(task.props[mini(i, task.props.size() - 1)], task.points[i])
		_items.append(item)
		_glows[item] = glow_under(item.position)


func status() -> String:
	return "%s: %d/%d" % [tr(task.item_label), _taken, task.required]


func target_point() -> Variant:
	var best: Variant = null
	for item in _items:
		if best == null or item.position.distance_to(player.position) < (best as Vector2).distance_to(player.position):
			best = item.position
	return best


func tick(_delta: float) -> void:
	for item in _items.duplicate():
		if flat_distance(item.position, player.position) > PICKUP_METERS:
			continue
		_items.erase(item)
		(_glows[item] as Node).queue_free()
		item.queue_free()
		_taken += 1
		celebrate(item.position, "+1  %d/%d" % [_taken, task.required])
		report()
		if _taken >= task.required:
			finish()
			return
