class_name PixelBackdrop
extends Control
## Фон экрана в пиксельном стиле. Картинка рисуется в целом масштабе и по
## центру: на широком телефоне или планшете не тянется на дробный коэффициент
## (пиксели стали бы неровными), а встаёт в тёмное поле с золотой каймой по краю.
## Сверху — вуаль, чтобы панели и текст читались на ярком закате.

enum Variant { MAIN, STEPPE }

const TEXTURES := {
	Variant.MAIN: preload("res://assets/sprites/backgrounds/menu_main.png"),
	Variant.STEPPE: preload("res://assets/sprites/backgrounds/menu_steppe.png"),
}

@export var variant: Variant = Variant.STEPPE:
	set(value):
		variant = value
		queue_redraw()
## Затемнение поверх картинки: 0 — без вуали, 1 — сплошная тьма.
@export_range(0.0, 1.0) var veil: float = 0.35:
	set(value):
		veil = value
		queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTokens.BURGUNDY_DARK)
	var texture: Texture2D = TEXTURES[variant]
	var image_rect := picture_rect(texture.get_size(), size)
	draw_texture_rect(texture, image_rect, false)
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
