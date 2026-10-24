extends StoryTaskRunner
## «Киіз үй тігу»: отнести части на площадку строго по порядку — кереге, уық,
## шаңырақ, киіз. Юрта растёт по стадиям; войлок появляется только на последнем
## шаге (в atilla он лежал уже на шаңырақ).

const PICKUP_METERS := 1.9
const DELIVER_METERS := 4.8
const PART_NAMES := ["Кереге", "Уық", "Шаңырақ", "Киіз"]
const STAGES := ["yurt_stage_1", "yurt_stage_2", "yurt_stage_3", "yurt"]

var _parts: Array[Node2D] = []
var _carried: Node2D
var _placed := 0
var _site: Node2D
var _site_sprite: Sprite2D
var _glow: Sprite2D
var _time := 0.0


func setup() -> void:
	_site = spawn("yurt_stage_0", task.goal + Vector2(0, StoryLayout.YURT_FRONT))
	_site_sprite = _site.get_child(0)
	for i in task.points.size():
		_parts.append(spawn(task.props[i], task.points[i]))
	_mark_next()


func status() -> String:
	var carried := tr(PART_NAMES[_placed]) if _carried != null else "—"
	return tr("Қолыңда: %s      Тұрғызылды: %d/%d") % [carried, _placed, _parts.size()]


func target_point() -> Variant:
	if _carried != null:
		return StoryLayout.to_world(task.goal)
	return _parts[_placed].position if _placed < _parts.size() else null


func _mark_next() -> void:
	if _glow != null:
		_glow.queue_free()
		_glow = null
	if _carried == null and _placed < _parts.size():
		_glow = glow_under(_parts[_placed].position)


func tick(delta: float) -> void:
	_time += delta
	if _carried == null:
		for i in _parts.size():
			var part := _parts[i]
			if part == null or flat_distance(part.position, player.position) > PICKUP_METERS:
				continue
			if i != _placed:
				# Порядок и есть урок: сказать, что ставится первым, а не молчать.
				story.get_node("%Hud").toast(tr("АЛДЫМЕН: %s") % tr(PART_NAMES[_placed]).to_upper(), 1.2)
				continue
			_carried = part
			celebrate(part.position, tr(PART_NAMES[i]).to_upper())
			_mark_next()
			report()
			break
		return
	var bob := roundf(absf(sin(_time * 8.0)) * 2.0) * UiTokens.PIXEL
	_carried.position = player.position + Vector2(0, -72 - bob)
	_carried.z_index = WorldLayers.EFFECTS
	if flat_distance(player.position, StoryLayout.to_world(task.goal)) < DELIVER_METERS:
		_parts[_placed] = null
		_carried.queue_free()
		_carried = null
		_site_sprite.texture = StoryLayout.texture(STAGES[_placed])
		_placed += 1
		var done := _placed >= _parts.size()
		celebrate(_site.position, tr("КИІЗ ҮЙ ДАЙЫН!") if done else "%d/%d" % [_placed, _parts.size()])
		report()
		if done:
			# Готовая юрта остаётся стоять: убираем её из списка на удаление.
			_spawned.erase(_site)
			StoryLayout.add_collider(_site, 2.4, StoryLayout.YURT_FRONT)
			finish()
			return
		_mark_next()
