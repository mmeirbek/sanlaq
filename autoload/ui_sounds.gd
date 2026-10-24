extends Node
## Звук интерфейса: короткий 8-битный щелчок на нажатие любой кнопки. Звук
## синтезируется при запуске — файла нет. Кнопки подхватываются сами, когда
## появляются в дереве, экранам ничего делать не нужно. Громкость — общая
## громкость эффектов из настроек.

const MIX_RATE := 22050
const CLICK_SECONDS := 0.045
const CLICK_HZ := 660.0

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RunContext.is_headless():
		return
	_player = AudioStreamPlayer.new()
	_player.stream = _click_stream()
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_click)


func _click() -> void:
	_player.volume_db = GameSettings.get_sfx_volume_db()
	_player.play()


## Меандр с быстрым затуханием — щелчок в духе пиксельного стиля.
static func _click_stream() -> AudioStreamWAV:
	var frames := int(MIX_RATE * CLICK_SECONDS)
	var data := PackedByteArray()
	data.resize(frames)
	for i in frames:
		var phase := fmod(i * CLICK_HZ / MIX_RATE, 1.0)
		var envelope := 1.0 - float(i) / frames
		var sample := (0.35 if phase < 0.5 else -0.35) * envelope * envelope
		data[i] = int(sample * 127.0) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
