class_name VisionSystem
extends CanvasLayer

@export var radius: float = 100.0
@export var darkness: float = 0.95

var _target_position: Vector2 = Vector2.ZERO
var _active: bool = false

@onready var _rect: ColorRect = $ColorRect

func _ready() -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, darkness)
	_rect.visible = _active
	_rect.material = ShaderMaterial.new()
	_rect.material.shader = _get_shader()

func _process(_delta: float) -> void:
	if not _active:
		return
	var mat := _rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("center", _world_to_uv(_target_position))
		mat.set_shader_parameter("radius", radius / 800.0)
		mat.set_shader_parameter("darkness", darkness)

func set_active(active: bool) -> void:
	_active = active
	_rect.visible = active

func set_target_position(pos: Vector2) -> void:
	_target_position = pos

func _world_to_uv(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2(0.5, 0.5)
	var cam := viewport.get_camera_2d()
	if cam == null:
		return Vector2(0.5, 0.5)
	var screen_pos := cam.get_screen_center_position()
	var screen_size := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1280.0),
		ProjectSettings.get_setting("display/window/size/viewport_height", 720.0))
	var uv := (world_pos - cam.global_position) / (screen_size * 0.5 / cam.zoom) * 0.5 + Vector2(0.5, 0.5)
	return uv

func _get_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.15;
uniform float darkness = 0.95;

void fragment() {
	vec2 uv = UV;
	float dist = length(uv - center);
	float alpha = smoothstep(radius - 0.02, radius + 0.02, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha * darkness);
}
"""
	return shader
