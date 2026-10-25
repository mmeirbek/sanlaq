class_name PixelBackdrop
extends Control
## Фон экрана в пиксельном стиле. Картинка рисуется в целом масштабе экрана
## 1280×720 и по центру: на широком телефоне или планшете она не тянется на
## дробный коэффициент, а встаёт в тёмное поле с золотой каймой по краю. Само окно
## масштабирует экран целиком — целый ли этот масштаб, решает настройка проекта
## (этап 6.3).
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
	var image_rect := picture_rect(_texture.get_size(), size)
	draw_texture_rect(_texture, image_rect, false)
	if image_rect.size.x < size.x or image_rect.size.y < size.y:
		draw_rect(image_rect.grow(UiTokens.PIXEL), UiTokens.GOLD_DARK, false, UiTokens.PIXEL)
	if veil > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.OUTLINE, veil))


## Где рисовать картинку: самый крупный целый масштаб, при котором она целиком
## помещается, по центру. Если картинка больше экрана — масштаб 1 и обрезка
## по центру.
static func picture_rect(picture: Vector2, area: Vector2) -> Rect2:
	var scale := maxi(1, floori(minf(area.x / picture.x, area.y / picture.y)))
	var drawn := picture * scale
	return Rect2(((area - drawn) / 2).floor(), drawn)
