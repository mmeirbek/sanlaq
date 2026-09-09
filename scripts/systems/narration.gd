class_name Narration
extends Node
## Голосовое сопровождение: проговаривает строки брифинга одну за другой и
## сообщает сигналом, когда строка закончилась, — по нему экран двигает подсветку.
##
## Источник звука выбирается по тому же принципу, что и в game_audio.gd:
##   1. записанный файл `assets/audio/voice/<kk|en>/<voice_id>.<ogg|mp3|wav>`;
##   2. если файла нет — системный синтезатор речи (DisplayServer TTS);
##   3. если и голоса нужного языка нет — тишина, но строка всё равно держится
##      на экране столько, сколько её читали бы вслух.
## Поэтому экран работает одинаково и с озвучкой, и без неё.

signal line_finished

const VOICE_DIR := "res://assets/audio/voice/"
const EXTS := ["ogg", "mp3", "wav"]
## Примерная скорость чтения вслух, символов в секунду. По ней держится строка,
## когда звука нет, и по ней же считается страховочный таймаут.
const CHARS_PER_SECOND := 13.0
const MIN_LINE_SECONDS := 1.6
const MAX_LINE_SECONDS := 20.0

var _player: AudioStreamPlayer
## Страховка: если источник не сообщил об окончании (файл оборвался, синтезатор
## не прислал колбэк), строка всё равно не подвиснет.
var _guard: Timer
var _tts_available: bool = false
var _tts_utterance: int = 0
var _speaking: bool = false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_source_finished)

	_guard = Timer.new()
	_guard.one_shot = true
	add_child(_guard)
	_guard.timeout.connect(_on_source_finished)

	_setup_tts()

func _setup_tts() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	DisplayServer.tts_set_utterance_callback(
		DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_ended)
	DisplayServer.tts_set_utterance_callback(
		DisplayServer.TTS_UTTERANCE_CANCELED, _on_tts_ended)
	_tts_available = true

## Проговорить строку. `voice_id` — имя записанного файла без расширения,
## `text` — уже переведённый текст для синтезатора и для оценки длительности.
func speak(voice_id: String, text: String) -> void:
	stop()
	_speaking = true
	var seconds := _estimate_seconds(text)

	var stream := _load_voice_file(voice_id)
	if stream != null:
		_player.stream = stream
		_player.volume_db = GameSettings.get_sfx_volume_db()
		_player.play()
		_guard.start(maxf(stream.get_length(), MIN_LINE_SECONDS) + 1.0)
		return

	if _speak_with_tts(text):
		# Синтезатор говорит медленнее или быстрее оценки, поэтому страховка
		# щедрая: она нужна только на случай потерянного колбэка.
		_guard.start(seconds * 2.0 + 2.0)
		return

	_guard.start(seconds)

func stop() -> void:
	_speaking = false
	if _guard != null:
		_guard.stop()
	if _player != null and _player.playing:
		_player.stop()
	if _tts_available:
		DisplayServer.tts_stop()

## Есть ли для текущего языка хоть какой-то голос — записанный или системный.
## Экран по этому флагу решает, показывать ли кнопку повтора озвучки.
func has_voice(voice_ids: PackedStringArray) -> bool:
	for voice_id in voice_ids:
		if _load_voice_file(voice_id) != null:
			return true
	return not _pick_tts_voice().is_empty()

func _load_voice_file(voice_id: String) -> AudioStream:
	if voice_id.is_empty():
		return null
	for ext in EXTS:
		var path := "%s%s/%s.%s" % [VOICE_DIR, lang_code(), voice_id, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

func _speak_with_tts(text: String) -> bool:
	if not _tts_available or text.is_empty():
		return false
	var voice := _pick_tts_voice()
	if voice.is_empty():
		return false
	_tts_utterance += 1
	DisplayServer.tts_speak(text, voice, 50, 1.0, 1.0, _tts_utterance)
	return true

## Голос строго того же языка: казахскую строку английским голосом читать хуже,
## чем не читать вовсе.
func _pick_tts_voice() -> String:
	if not _tts_available:
		return ""
	var voices := DisplayServer.tts_get_voices_for_language(lang_code())
	return "" if voices.is_empty() else voices[0]

## Код языка для папки с озвучкой и для выбора голоса — тот же, что у локали
## TranslationServer ("kk"/"en"), а не "kz" из GameSettings.get_lang_code().
func lang_code() -> String:
	return "en" if GameSettings.current_language == GameSettings.Language.EN else "kk"

func _estimate_seconds(text: String) -> float:
	return clampf(text.length() / CHARS_PER_SECOND, MIN_LINE_SECONDS, MAX_LINE_SECONDS)

func _on_tts_ended(utterance_id: int) -> void:
	if utterance_id == _tts_utterance:
		_on_source_finished()

func _on_source_finished() -> void:
	if not _speaking:
		return
	_speaking = false
	_guard.stop()
	line_finished.emit()
