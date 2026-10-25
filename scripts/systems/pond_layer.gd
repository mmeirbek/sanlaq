class_name PondLayer
extends Node2D
## Вся вода карты: пиксельный шейдер по зонам воды (resources/shaders/pond.gdshader).
## Пиксель арта — вода, если он внутри хоть одного круга зоны, поэтому
## пересекающиеся пруды сливаются в одно озеро с общим берегом — ровно как
## их зоны замедления в MapManager.is_water.

const SHADER := preload("res://resources/shaders/pond.gdshader")
## Должно совпадать с MAX_ZONES в шейдере.
const MAX_ZONES := 16

var _zones: Array[Dictionary] = []

func _init() -> void:
	z_index = WorldLayers.WATER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("path_light", WorldColors.PATH_LIGHT)
	shader_material.set_shader_parameter("path", WorldColors.PATH)
	shader_material.set_shader_parameter("path_dark", WorldColors.PATH_DARK)
	shader_material.set_shader_parameter("water_light", WorldColors.WATER_LIGHT)
	shader_material.set_shader_parameter("water", WorldColors.WATER)
	shader_material.set_shader_parameter("water_dark", WorldColors.WATER_DARK)
	shader_material.set_shader_parameter("water_deep", WorldColors.WATER_DEEP)
	material = shader_material

## zones — те же словари {pos, radius}, что MapManager.water_zones, в
## координатах родителя этого узла (узел стоит в его начале координат).
func set_zones(zones: Array[Dictionary]) -> void:
	assert(zones.size() <= MAX_ZONES, "прудов больше, чем умеет шейдер")
	_zones = zones
	var packed := PackedVector3Array()
	packed.resize(MAX_ZONES)
	for i in zones.size():
		var at: Vector2 = zones[i]["pos"]
		packed[i] = Vector3(at.x, at.y, zones[i]["radius"])
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("zones", packed)
	shader_material.set_shader_parameter("zone_count", zones.size())
	queue_redraw()

func _draw() -> void:
	# Только квадраты вокруг прудов: шейдер считает там, где вода вообще может быть.
	for zone in _zones:
		# С запасом на берег снаружи зоны и волнистый край (SHORE и WOBBLE в шейдере).
		var reach: float = zone["radius"] + UiTokens.PIXEL * 5.0
		draw_rect(Rect2(zone["pos"] - Vector2(reach, reach), Vector2(reach, reach) * 2.0), Color.WHITE)
