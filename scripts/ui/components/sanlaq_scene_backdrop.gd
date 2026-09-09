class_name SanlaqSceneBackdrop
extends Control

enum Variant { LOBBY, WARDROBE, CODEX, RESULTS, SETTINGS, ABAI, TOGYZ }
@export var variant: Variant = Variant.LOBBY

const TEXTURES := {
	Variant.LOBBY: "res://assets/ui/backgrounds/bg_lobby.jpg",
	Variant.WARDROBE: "res://assets/ui/backgrounds/bg_wardrobe.jpg",
	Variant.CODEX: "res://assets/ui/backgrounds/bg_codex.jpg",
	Variant.RESULTS: "res://assets/ui/backgrounds/bg_results.jpg",
	Variant.SETTINGS: "res://assets/ui/backgrounds/bg_settings.jpg",
	Variant.ABAI: "res://assets/ui/backgrounds/bg_abai.jpg",
	Variant.TOGYZ: "res://assets/ui/backgrounds/bg_togyz.jpg",
}

var _texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture = load(TEXTURES.get(variant, TEXTURES[Variant.LOBBY])) as Texture2D
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0 or _texture == null:
		return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
