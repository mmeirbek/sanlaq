extends Node2D
## Звуковые волны шагов: кольца из квадратиков в пиксель арта. Волна не
## бледнеет, а редеет — к концу жизни квадратики пропадают через один.

@onready var _sound_system: SoundWaveSystem = $"../SoundWaveSystem"

func _ready() -> void:
	z_index = WorldLayers.EFFECTS

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _sound_system == null:
		return
	for wave in _sound_system.get_waves():
		var life := clampf(wave.life / wave.max_life, 0.0, 1.0)
		# Сначала каждый квадратик, затем каждый второй, затем каждый третий.
		var keep_every := 1 + int(life * 3.0)
		_draw_ring(to_local(wave.pos), wave.radius, keep_every)

func _draw_ring(center: Vector2, radius: float, keep_every: int) -> void:
	var px := float(UiTokens.PIXEL)
	var dots := maxi(8, int(TAU * radius / (px * 2.0)))
	for i in range(0, dots, keep_every):
		var at := center + Vector2.from_angle(TAU * i / dots) * radius
		draw_rect(Rect2((at / px).floor() * px, Vector2(px, px)), UiTokens.CREAM)
