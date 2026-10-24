extends Control
## Карта маршрута: точки пути загораются одна за другой, потом — «ЖОЛҒА ШЫҒУ».

signal done

const MAP := preload("res://assets/sprites/story/route_map.png")
const DOT := preload("res://assets/sprites/story/route_dot.png")
const END := preload("res://assets/sprites/story/route_end.png")
## Сколько промежуточных точек рисуется между вершинами маршрута.
const DOTS_PER_LEG := 3
const DOT_STEP := 0.12

var title := ""
var goal := ""
var start := ""
var finish := ""
var route := PackedVector2Array()
var _map: TextureRect
var _dots: Array[TextureRect] = []
var _time := 0.0
var _go: PixelButton


func _ready() -> void:
	var box := StoryOverlays.frame(self)
	StoryOverlays.label(box, tr(title).to_upper(), "TitleLabel")
	StoryOverlays.label(box, tr(goal), "SubtitleLabel")
	_map = TextureRect.new()
	_map.texture = MAP
	_map.stretch_mode = TextureRect.STRETCH_KEEP
	box.add_child(_map)
	var points := _path()
	for i in points.size():
		var dot := TextureRect.new()
		dot.texture = END if i == points.size() - 1 else DOT
		dot.position = _snap(points[i] * MAP.get_size() - (dot.texture.get_size() / 2))
		dot.visible = false
		_map.add_child(dot)
		_dots.append(dot)
	var labels := HBoxContainer.new()
	box.add_child(labels)
	StoryOverlays.label(labels, tr(start), "CaptionLabel").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StoryOverlays.label(labels, "→", "HudLabel")
	StoryOverlays.label(labels, tr(finish), "HeadingLabel").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go = StoryOverlays.button(box, tr("ЖОЛҒА ШЫҒУ"), "ButtonLarge", _close)
	_go.grab_focus.call_deferred()


## Ломаная маршрута, разбитая на частые точки.
func _path() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in route.size() - 1:
		for k in DOTS_PER_LEG:
			points.append(route[i].lerp(route[i + 1], float(k) / DOTS_PER_LEG))
	points.append(route[route.size() - 1])
	return points


func _snap(at: Vector2) -> Vector2:
	return (at / UiTokens.PIXEL).round() * UiTokens.PIXEL


func _process(delta: float) -> void:
	_time += delta
	var shown := int(_time / DOT_STEP)
	for i in _dots.size():
		_dots[i].visible = i <= shown


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	done.emit()
	queue_free()
