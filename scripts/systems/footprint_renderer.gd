extends Node2D
## Следы бегунов: пара отпечатков в пиксель арта поперёк направления шага.
## След не бледнеет, а стирается: последнюю треть жизни виден один отпечаток.

## Отпечатки — пара квадратиков в 2×3 пикселя арта, на расстоянии шага.
const PRINT_SIZE := Vector2(2, 3)
const FEET_APART := 3.0

@onready var _footprints: FootprintSystem = $"../FootprintSystem"

func _ready() -> void:
	z_index = WorldLayers.FOOTPRINTS

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _footprints == null:
		return
	var px := float(UiTokens.PIXEL)
	for footprint in _footprints.get_prints():
		var pos: Vector2 = to_local(footprint.pos)
		var facing: Vector2 = footprint.facing
		var life: float = footprint.life / FootprintSystem.PRINT_LIFETIME
		var across := facing.orthogonal().normalized() if facing.length() > 0.01 else Vector2.RIGHT
		var feet := [pos + across * FEET_APART * px, pos - across * FEET_APART * px]
		if life > 2.0 / 3.0:
			feet.resize(1)
		for foot: Vector2 in feet:
			var corner := ((foot - PRINT_SIZE * px / 2.0) / px).floor() * px
			draw_rect(Rect2(corner, PRINT_SIZE * px), WorldColors.GRASS_DEEP)
