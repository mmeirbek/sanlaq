class_name AqSuyekField
extends Control
## Ночное поле «Ақ сүйек»: торкөз клеток травы. В клетке слоями лежат след-
## подсказка, отау-көмбе в углах, кольцо доступного шага, сүйек (только в
## разборе раунда) и фигурки игроков. Что показывать, решает экран через
## show_state(); поле лишь рисует и сообщает, в какую клетку нажали.

signal cell_pressed(cell: Vector2i)

const CELL := preload("res://assets/sprites/aq_suyek/cell.png")
const REACH := preload("res://assets/sprites/aq_suyek/reach.png")
const BONE := preload("res://assets/sprites/aq_suyek/bone.png")
const OTAU := [
	preload("res://assets/sprites/aq_suyek/otau_human.png"),
	preload("res://assets/sprites/aq_suyek/otau_bot.png"),
]
const TOKENS := [
	preload("res://assets/sprites/aq_suyek/token_human.png"),
	preload("res://assets/sprites/aq_suyek/token_bot.png"),
]
## По порядку AqSuyekBoard.Hint.
const HINTS := [
	preload("res://assets/sprites/aq_suyek/hint_found.png"),
	preload("res://assets/sprites/aq_suyek/hint_very_close.png"),
	preload("res://assets/sprites/aq_suyek/hint_close.png"),
	preload("res://assets/sprites/aq_suyek/hint_near.png"),
	preload("res://assets/sprites/aq_suyek/hint_far.png"),
]
## Зазор между клетками — пиксели арта, как и всё поле.
const GAP := 2 * UiTokens.PIXEL
## В клетке-көмбе отау стоит слева, фигурка сдвигается вправо.
const HOME_SHIFT := Vector2(8 * UiTokens.PIXEL, 0)

var _positions: Array = []
var _revealed: Dictionary = {}
var _reachable: Array[Vector2i] = []
## Vector2i(-1, -1) — сүйек не показываем.
var _bone := Vector2i(-1, -1)
var _homes: Array[Vector2i] = []


func _init() -> void:
	var side := AqSuyekBoard.GRID * CELL.get_width() + (AqSuyekBoard.GRID - 1) * GAP
	custom_minimum_size = Vector2(side, side)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## homes — көмбе каждого игрока: там стоит отау.
func show_state(positions: Array, revealed: Dictionary, reachable: Array[Vector2i],
		bone: Vector2i, homes: Array[Vector2i]) -> void:
	_positions = positions
	_revealed = revealed
	_reachable = reachable
	_bone = bone
	_homes = homes
	queue_redraw()


func cell_at(local: Vector2) -> Vector2i:
	var step := CELL.get_width() + GAP
	var cell := Vector2i(floori((local.x - _origin().x) / step), floori((local.y - _origin().y) / step))
	var inside := Vector2(local - _origin() - Vector2(cell) * step)
	if cell.x < 0 or cell.y < 0 or cell.x >= AqSuyekBoard.GRID or cell.y >= AqSuyekBoard.GRID:
		return Vector2i(-1, -1)
	# Нажатие в зазор между клетками не считается.
	if inside.x >= CELL.get_width() or inside.y >= CELL.get_height():
		return Vector2i(-1, -1)
	return cell


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
		var cell := cell_at(mouse.position)
		if cell.x >= 0:
			accept_event()
			cell_pressed.emit(cell)


## Поле по центру, на сетке пикселя арта.
func _origin() -> Vector2:
	var px := float(UiTokens.PIXEL)
	return ((size - custom_minimum_size) / 2.0 / px).floor() * px


func _corner(cell: Vector2i) -> Vector2:
	return _origin() + Vector2(cell) * (CELL.get_width() + GAP)


func _draw() -> void:
	for y in AqSuyekBoard.GRID:
		for x in AqSuyekBoard.GRID:
			var cell := Vector2i(x, y)
			var at := _corner(cell)
			draw_texture(CELL, at)
			if _revealed.has(cell):
				draw_texture(HINTS[_revealed[cell]], at)
			var home := _homes.find(cell)
			if home >= 0:
				draw_texture(OTAU[home], at)
			if cell in _reachable:
				draw_texture(REACH, at)
	if _bone.x >= 0:
		var at := _corner(_bone) + ((CELL.get_size() - BONE.get_size()) / 2.0 / UiTokens.PIXEL).floor() * UiTokens.PIXEL
		draw_texture(BONE, at)
	# Фигурки — последними: игрок должен видеть, где стоит. В разборе раунда
	# сүйек важнее, поэтому фигурка на его клетке не рисуется.
	for player in _positions.size():
		var cell: Vector2i = _positions[player]
		if cell != _bone:
			draw_texture(TOKENS[player], _corner(cell) + (HOME_SHIFT if cell in _homes else Vector2.ZERO))
