class_name SoundWaveSystem
extends Node

signal noise_emitted(source: Node2D, radius: float)

var _waves: Array[Dictionary] = []

func emit_noise(source: Node2D, radius: float) -> void:
	_waves.append({
		pos = source.global_position,
		radius = 0.0,
		max_radius = radius,
		life = 0.0,
		max_life = 0.6,
	})
	noise_emitted.emit(source, radius)

func _process(delta: float) -> void:
	var i: int = _waves.size() - 1
	while i >= 0:
		var w: Dictionary = _waves[i]
		w.life += delta
		var t := clampf(w.life / w.max_life, 0.0, 1.0)
		w.radius = lerpf(0.0, w.max_radius, t)
		if w.life >= w.max_life:
			_waves.remove_at(i)
		i -= 1

func is_visible_to(observer: Node2D) -> bool:
	return true

func get_waves() -> Array:
	return _waves
