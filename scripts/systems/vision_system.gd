class_name VisionSystem
extends CanvasLayer
## Обзор Соқыртеке: всё за кругом radius вокруг ловца темнеет пиксельной
## ступенчатой шахматкой (resources/shaders/vision.gdshader). Это тот же круг,
## по которому game.gd решает, кого ловец видит, — в пикселях мира, при любом
## размере окна и зуме камеры.

const SHADER := preload("res://resources/shaders/vision.gdshader")

## Радиус ясного обзора в пикселях мира.
@export var radius: float = 100.0
@export var darkness: float = 0.95

var _target_position: Vector2 = Vector2.ZERO
var _active: bool = false

@onready var _rect: ColorRect = $ColorRect

func _ready() -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = _active
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("shade", UiTokens.OUTLINE)
	_rect.material = shader_material

func _process(_delta: float) -> void:
	if not _active:
		return
	# Мир -> координаты, в которых лежит _rect: камера, её зум и тряска.
	var world_to_screen := _rect.get_viewport().get_canvas_transform()
	var zoom := world_to_screen.get_scale().x
	var shader_material := _rect.material as ShaderMaterial
	shader_material.set_shader_parameter("center", world_to_screen * _target_position)
	shader_material.set_shader_parameter("radius", radius * zoom)
	shader_material.set_shader_parameter("pixel", UiTokens.PIXEL * zoom)
	shader_material.set_shader_parameter("darkness", darkness)

func set_active(active: bool) -> void:
	_active = active
	_rect.visible = active

## Центр круга в мире. Ставьте центр фигуры, а не точку на земле: тогда
## чужая фигура в свете ровно тогда, когда её точка в радиусе от вашей.
func set_target_position(pos: Vector2) -> void:
	_target_position = pos
