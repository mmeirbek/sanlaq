extends Node2D

@onready var _sound_system: SoundWaveSystem = $"../SoundWaveSystem"

func _draw() -> void:
	if _sound_system == null:
		return
	for wave in _sound_system.get_waves():
		var pos: Vector2 = to_local(wave.pos)
		var r: float = wave.radius
		var life: float = wave.life
		var max_life: float = wave.max_life
		var alpha: float = 1.0 - clampf(life / max_life, 0.0, 1.0)
		var color: Color = Color(1.0, 1.0, 1.0, alpha * 0.5)
		draw_arc(pos, r, 0, TAU, 32, color, 2.0)

func _process(_dt: float) -> void:
	queue_redraw()
