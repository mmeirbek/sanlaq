extends Node
## Ровный пиксель на любом экране (этап 6.3). Экран свёрстан под 1280×720, пиксель
## арта — 2 пикселя экрана. Окно масштабирует картинку на min(ширина/1280,
## высота/720) — на телефоне и планшете это дробь (×1,6), и пиксели арта выходят
## то 3, то 4 пикселя шириной. Здесь масштаб округляется вниз до шага 0,5: пиксель
## арта = 2 × масштаб = целое число пикселей экрана. Лишнее место достаётся
## раскладке (aspect = expand), как и раньше.
##
## Окно меньше 1280×720 масштабируется как прежде, дробно: при шаге 0,5 текст
## ужался бы вдвое, а читаемость важнее ровных пикселей.

const BASE := Vector2(1280, 720)
const STEP := 0.5


func _ready() -> void:
	get_tree().root.size_changed.connect(apply)
	apply()


func apply() -> void:
	var window := get_tree().root
	window.content_scale_size = content_size_for(window.size)


## Базовый размер экрана для окна такого размера: при нём окно масштабирует
## картинку ровно на целое число шагов STEP.
static func content_size_for(window_size: Vector2i) -> Vector2i:
	var fit := minf(window_size.x / BASE.x, window_size.y / BASE.y)
	if fit < 1.0:
		return Vector2i(BASE)
	var scale := floorf(fit / STEP) * STEP
	return Vector2i(floori(window_size.x / scale), floori(window_size.y / scale))
