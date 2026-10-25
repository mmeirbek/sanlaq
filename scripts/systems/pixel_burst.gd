class_name PixelBurst
extends Node2D
## Разлёт квадратиков в пиксель арта: вспышка при поимке, брызги у пруда,
## пыль у входа в юрту. Квадратики стоят на сетке мира и не просвечивают —
## к концу жизни они не бледнеют, а пропадают по одному.

## Какая доля жизни частицы остаётся до того, как она начинает пропадать.
const VANISH_FROM := 0.6

var _particles: Array[Dictionary] = []
var _lifetime := 0.6
var _age := 0.0
var _gravity := Vector2.ZERO


## Создаёт разлёт в точке at (координаты parent) и сама удаляется после.
## speed_range — наименьшая и наибольшая начальная скорость (x, y) в пикселях
## мира в секунду; направление у каждой частицы случайное.
static func spawn(parent: Node, at: Vector2, colors: Array[Color], amount: int,
		speed_range: Vector2, gravity: Vector2, lifetime: float) -> PixelBurst:
	var burst := PixelBurst.new()
	burst.position = at
	burst.z_index = WorldLayers.EFFECTS
	burst._lifetime = lifetime
	burst._gravity = gravity
	for i in amount:
		burst._particles.append({
			"at": Vector2.ZERO,
			"velocity": Vector2.from_angle(randf() * TAU) * randf_range(speed_range.x, speed_range.y),
			"color": colors[i % colors.size()],
			# Крупные и мелкие вперемешку: 1 или 2 пикселя арта.
			"size": UiTokens.PIXEL * (1 + i % 2),
			"vanish": randf_range(VANISH_FROM, 1.0),
		})
	parent.add_child(burst)
	return burst


func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	for particle in _particles:
		particle["velocity"] += _gravity * delta
		particle["at"] += particle["velocity"] * delta
	queue_redraw()


func _draw() -> void:
	var life := _age / _lifetime
	var px := float(UiTokens.PIXEL)
	# Сетка мира, а не узла: квадратики не «плывут» между пикселями арта.
	var grid_offset := global_position - (global_position / px).floor() * px
	for particle in _particles:
		if life >= particle["vanish"]:
			continue
		var at: Vector2 = ((particle["at"] + grid_offset) / px).floor() * px - grid_offset
		var size: float = particle["size"]
		draw_rect(Rect2(at, Vector2(size, size)), particle["color"])
