class_name PixelBackdrop
extends Control
## Фон экрана в пиксельном стиле. Картинка закрывает весь экран, как обои: на
## телефоне, планшете или MacBook она растягивается до краёв без искажения
## пропорций, а лишнее поровну срезается сверху-снизу или по бокам. Пиксели фона
## при этом бывают на полпикселя неровными — за вуалью этого не видно, а пустая
## рамка вокруг картинки выглядела как сломанная вёрстка.
## Сверху — вуаль, чтобы панели и текст читались на ярком закате.

enum Variant { MAIN, STEPPE }

## Грузится только нужная картинка — фоны большие.
const TEXTURES := {
	Variant.MAIN: "res://assets/sprites/backgrounds/menu_main.png",
	Variant.STEPPE: "res://assets/sprites/backgrounds/menu_steppe.png",
}

@export var variant: Variant = Variant.STEPPE:
	set(value):
		variant = value
		# Ссылку держит узел: текстура, загруженная прямо в _draw(), освободилась
		# бы после вызова, и фон не нарисовался бы.
		_texture = load(TEXTURES[variant])
		queue_redraw()
## Затемнение поверх картинки: 0 — без вуали, 1 — сплошная тьма.
@export_range(0.0, 1.0) var veil: float = 0.35:
	set(value):
		veil = value
		queue_redraw()

var _texture: Texture2D


func _ready() -> void:
	if _texture == null:
		_texture = load(TEXTURES[variant])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTokens.BURGUNDY_DARK)
	draw_texture_rect(_texture, picture_rect(_texture.get_size(), size), false)
	if veil > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.OUTLINE, veil))


## Где рисовать картинку: наименьший масштаб, при котором она закрывает экран
## целиком, по центру. Размер округляется вверх, чтобы у края не осталось щели.
static func picture_rect(picture: Vector2, area: Vector2) -> Rect2:
	var scale := maxf(area.x / picture.x, area.y / picture.y)
	var drawn := (picture * scale).ceil()
	return Rect2(((area - drawn) / 2).floor(), drawn)
