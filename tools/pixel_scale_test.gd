extends "res://tools/test_case.gd"
## Масштаб окна округляется до шага 0,5, чтобы пиксель арта был целым числом
## пикселей экрана (autoload/pixel_scale.gd, этап 6.3).

const PIXEL_SCALE := preload("res://autoload/pixel_scale.gd")


func _init() -> void:
	# Окно -> масштаб, на который окно растянет экран.
	var cases := {
		Vector2i(1280, 720): 1.0,
		Vector2i(1920, 1080): 1.5,
		Vector2i(2560, 1440): 2.0,
		Vector2i(1560, 720): 1.0,
		Vector2i(2400, 1080): 1.5,   # телефон 20:9
		Vector2i(2048, 1536): 1.5,   # планшет 4:3, было 1,6
		Vector2i(2732, 2048): 2.0,   # большой планшет, было 2,13
		Vector2i(1366, 768): 1.0,
	}
	for window: Vector2i in cases:
		var content: Vector2i = PIXEL_SCALE.content_size_for(window)
		var scale := minf(float(window.x) / content.x, float(window.y) / content.y)
		var art_pixel := scale * UiTokens.PIXEL
		check(is_equal_approx(scale, cases[window]),
			"%s: масштаб %.2f, получено %.4f" % [window, cases[window], scale])
		check(is_equal_approx(art_pixel, roundf(art_pixel)),
			"%s: пиксель арта — целое число пикселей экрана (%.3f)" % [window, art_pixel])
		check(content.x >= 1280 and content.y >= 720, "%s: экран не меньше 1280×720 (%s)" % [window, content])
	# Окно меньше базового — масштаб прежний, дробный: читаемость важнее.
	check(PIXEL_SCALE.content_size_for(Vector2i(960, 720)) == Vector2i(1280, 720),
		"маленькое окно масштабируется как раньше")
	finish("PIXEL SCALE")
