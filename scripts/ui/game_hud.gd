class_name GameHUD
extends CanvasLayer

@onready var _timer_label: Label = $TopBar/TimerLabel
@onready var _catches_label: Label = $TopBar/CatchesLabel
@onready var _round_label: Label = $TopBar/RoundLabel
@onready var _message_label: Label = $MessageLabel
@onready var _defeat_overlay: Control = $DefeatOverlay
@onready var _spectate_bar: HBoxContainer = $SpectateBar
@onready var _slow_label: Label = $SlowLabel

var player: Player

var _msg_tween: Tween

func _ready() -> void:
	_defeat_overlay.visible = false
	_spectate_bar.visible = false
	_slow_label.visible = false

func update_timer(seconds: float) -> void:
	_timer_label.text = "%.0f" % maxf(0, seconds)

func update_remaining(alive: int, total: int) -> void:
	_catches_label.text = "Қалды %d/%d" % [alive, total]

func update_round(round_num: int, total: int) -> void:
	_round_label.text = "Раунд %d/%d" % [round_num, total]

func show_message(text: String, duration: float = 2.0) -> void:
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_message_label.text = text
	_message_label.modulate.a = 1.0
	_message_label.visible = true
	_msg_tween = create_tween()
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)
	_msg_tween.tween_callback(func(): _message_label.visible = false)

func show_defeat() -> void:
	_defeat_overlay.visible = true

func hide_defeat() -> void:
	_defeat_overlay.visible = false

func show_spectate_bar() -> void:
	_spectate_bar.visible = true

func hide_spectate_bar() -> void:
	_spectate_bar.visible = false

func show_slow(seconds: float) -> void:
	_slow_label.text = "ЗАМЕДЛЕНИЕ %.0fс" % ceilf(seconds)
	_slow_label.visible = true

func update_slow(seconds: float) -> void:
	_slow_label.text = "ЗАМЕДЛЕНИЕ %.0fс" % ceilf(maxf(0, seconds))
	_slow_label.visible = true

func hide_slow() -> void:
	_slow_label.visible = false
