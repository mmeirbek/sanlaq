extends Node

const MIX_RATE := 22050.0
const STEP_DURATION := 0.72
const NOTES := [220.0, 261.63, 293.66, 329.63, 392.0, 329.63, 293.66, 261.63]
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_EXTS := ["ogg", "mp3", "wav"]
const TRACK_PATHS := [
	"res://assets/audio/music/kazahskaya_-_muzyka_(SkySound7.com).mp3",
	"res://assets/audio/menu_music.ogg",
	"res://assets/audio/menu_music.mp3",
	"res://assets/audio/menu_music.wav",
]

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _using_track: bool = false
var _time := 0.0
var _phase := 0.0
var _bass_phase := 0.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = GameSettings.get_music_volume_db()
	add_child(_player)
	_using_track = _try_start_track()
	if not _using_track:
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = MIX_RATE
		stream.buffer_length = 0.35
		_player.stream = stream
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

func _try_start_track() -> bool:
	for path in TRACK_PATHS:
		if _try_play_file(path):
			return true
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return false
	for file: String in dir.get_files():
		# Экспортированная сборка хранит файл как "трек.mp3.remap" вместо "трек.mp3" —
		# снимаем суффикс перед проверкой расширения (тот же фикс, что в asset_registry.gd).
		var base_name := file.trim_suffix(".remap")
		if base_name.get_extension().to_lower() in MUSIC_EXTS:
			if _try_play_file(MUSIC_DIR + base_name):
				return true
	return false

func _try_play_file(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var stream := load(path) as AudioStream
	if stream == null:
		return false
	if "loop" in stream:
		stream.set("loop", true)
	elif "loop_mode" in stream:
		stream.set("loop_mode", AudioStreamWAV.LOOP_FORWARD)
	_player.stream = stream
	_player.play()
	return true

func _exit_tree() -> void:
	if _player:
		_player.stop()
		_player.stream = null

func _process(_delta: float) -> void:
	_player.volume_db = GameSettings.get_music_volume_db()
	if _using_track:
		return
	if _playback == null:
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return
	for _frame in _playback.get_frames_available():
		var sample := _next_sample()
		_playback.push_frame(Vector2(sample, sample))

func _next_sample() -> float:
	var delta := 1.0 / MIX_RATE
	var step := int(_time / STEP_DURATION) % NOTES.size()
	var phase_in_step := fmod(_time, STEP_DURATION) / STEP_DURATION
	var envelope := sin(PI * phase_in_step)
	var note: float = NOTES[step]
	_phase += TAU * note * delta
	_bass_phase += TAU * (note * 0.5) * delta
	_time += delta
	var melody := sin(_phase) * 0.11 * envelope
	var harmony := sin(_phase * 0.5) * 0.035 * envelope
	var bass := sin(_bass_phase) * 0.045
	return melody + harmony + bass
