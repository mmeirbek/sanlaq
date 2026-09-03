class_name GameAudio
extends Node

const MIX_RATE := 22050.0
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_EXTS := ["ogg", "mp3", "wav"]
const ZONE_PULSE := {"yurt": 0.45, "splash": 0.35}

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _streams: Dictionary = {}
var _zone_looping: Dictionary = {}
var _zone_players: Dictionary = {}
var _zone_pulse: Dictionary = {}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = GameSettings.get_sfx_volume_db()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.35
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	var db := GameSettings.get_sfx_volume_db()
	_player.volume_db = db
	for pl in _pool:
		pl.volume_db = db
	for cue in _zone_looping.keys():
		if not bool(_zone_looping[cue]):
			continue
		var zone_pl: AudioStreamPlayer = _zone_players.get(cue, null)
		if zone_pl != null and zone_pl.playing:
			zone_pl.volume_db = db
			continue
		_zone_pulse[cue] = float(_zone_pulse.get(cue, 0.0)) - _delta
		if float(_zone_pulse[cue]) <= 0.0:
			_zone_pulse[cue] = float(ZONE_PULSE.get(cue, 0.4))
			_pulse_zone_cue(cue)
	if _playback == null:
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return
	for _frame in _playback.get_frames_available():
		var sample := _next_sample()
		_playback.push_frame(Vector2(sample, sample))

func start_zone_loop(cue: String) -> void:
	if bool(_zone_looping.get(cue, false)):
		return
	_zone_looping[cue] = true
	_zone_pulse[cue] = 0.0
	var stream := _get_stream(cue)
	if stream != null:
		_enable_loop(stream)
		var zone_pl := _zone_players.get(cue) as AudioStreamPlayer
		if zone_pl == null:
			zone_pl = AudioStreamPlayer.new()
			_zone_players[cue] = zone_pl
			add_child(zone_pl)
		zone_pl.stream = stream
		zone_pl.volume_db = GameSettings.get_sfx_volume_db()
		zone_pl.play()
	else:
		_pulse_zone_cue(cue)

func stop_zone_loop(cue: String) -> void:
	if not bool(_zone_looping.get(cue, false)):
		return
	_zone_looping[cue] = false
	var zone_pl := _zone_players.get(cue) as AudioStreamPlayer
	if zone_pl:
		zone_pl.stop()

func stop_all_zone_loops() -> void:
	for cue in _zone_looping.keys():
		stop_zone_loop(cue)

func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		stream.loop_offset = 0.0
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

func _pulse_zone_cue(cue: String) -> void:
	match cue:
		"yurt":
			_queue_voice(130.0, 0.18, 0.22, true)
			_queue_voice(262.0, 0.30, 0.08, false)
		"splash":
			_queue_voice(180.0, 0.22, 0.30, true)
			_queue_voice(90.0, 0.34, 0.18, true)

# Проигрывает файл из assets/audio/sfx/<cue>.<ext>, если он есть.
# Возвращает true, если файл найден и проигран (синтезатор не задействуется).
func _play_named(cue: String) -> bool:
	var stream := _get_stream(cue)
	if stream == null:
		return false
	var pl := _acquire_player()
	pl.stream = stream
	pl.volume_db = GameSettings.get_sfx_volume_db()
	pl.play()
	return true

func _get_stream(cue: String) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	var candidates := [cue]
	match cue:
		"step":
			candidates.append("steps")
		"step_sprint":
			candidates.append("steps_sprint")
	var stream: AudioStream = null
	for candid: String in candidates:
		for ext: String in SFX_EXTS:
			var path: String = SFX_DIR + candid + "." + ext
			if ResourceLoader.exists(path):
				var loaded := load(path) as AudioStream
				if loaded:
					stream = loaded
					break
		if stream != null:
			break
	_streams[cue] = stream
	return stream

func _acquire_player() -> AudioStreamPlayer:
	var pl: AudioStreamPlayer
	if _pool_index < _pool.size():
		pl = _pool[_pool_index]
	else:
		pl = AudioStreamPlayer.new()
		_pool.append(pl)
		add_child(pl)
	_pool_index = (_pool_index + 1) % maxi(_pool.size(), 1)
	if pl.playing:
		pl.stop()
	return pl

func play_footstep(sprinting: bool) -> void:
	if _play_named("step_sprint" if sprinting else "step"):
		return
	_queue_voice(138.0 if sprinting else 92.0, 0.075 if sprinting else 0.06, 0.30 if sprinting else 0.20, true)

func play_sprint() -> void:
	if _play_named("sprint"):
		return
	_queue_voice(220.0, 0.24, 0.28, false)

func play_catch() -> void:
	if _play_named("catch"):
		return
	_queue_voice(105.0, 0.20, 0.42, false)
	_queue_voice(180.0, 0.11, 0.20, true)

func play_quiz_result(correct: bool) -> void:
	if _play_named("quiz_correct" if correct else "quiz_wrong"):
		return
	_queue_voice(440.0 if correct else 150.0, 0.22, 0.30, false)

func play_echo() -> void:
	if _play_named("echo"):
		return
	_queue_voice(330.0, 0.34, 0.24, false)
	_queue_voice(495.0, 0.20, 0.14, false)

func play_fog() -> void:
	if _play_named("fog"):
		return
	_queue_voice(74.0, 0.42, 0.18, true)

func play_yurt_enter() -> void:
	if _play_named("yurt"):
		return
	_queue_voice(130.0, 0.18, 0.22, true)
	_queue_voice(262.0, 0.30, 0.08, false)

func play_splash() -> void:
	if _play_named("splash"):
		return
	_queue_voice(180.0, 0.22, 0.30, true)
	_queue_voice(90.0, 0.34, 0.18, true)

func play_defeat() -> void:
	if _play_named("defeat"):
		return
	_queue_voice(196.0, 0.20, 0.22, false)
	_queue_voice(147.0, 0.34, 0.20, false)
	_queue_voice(110.0, 0.48, 0.18, false)

func play_victory() -> void:
	if _play_named("victory"):
		return
	_queue_voice(262.0, 0.20, 0.20, false)
	_queue_voice(330.0, 0.20, 0.20, false)
	_queue_voice(392.0, 0.34, 0.20, false)

func _queue_voice(pitch: float, duration: float, gain: float, noise: bool) -> void:
	_voices.append({
		"age": 0.0,
		"duration": duration,
		"phase": 0.0,
		"pitch": pitch,
		"gain": gain,
		"noise": noise,
	})

func _next_sample() -> float:
	var mixed := 0.0
	var delta := 1.0 / MIX_RATE
	for i in range(_voices.size() - 1, -1, -1):
		var voice := _voices[i]
		var age: float = voice["age"]
		var duration: float = voice["duration"]
		if age >= duration:
			_voices.remove_at(i)
			continue
		var envelope := pow(1.0 - age / duration, 1.8)
		var phase: float = voice["phase"] + TAU * float(voice["pitch"]) * delta
		voice["phase"] = phase
		voice["age"] = age + delta
		_voices[i] = voice
		var wave := sin(phase)
		if bool(voice["noise"]):
			wave = wave * 0.25 + randf_range(-1.0, 1.0) * 0.75
		mixed += wave * float(voice["gain"]) * envelope
	return clampf(mixed, -0.85, 0.85)
