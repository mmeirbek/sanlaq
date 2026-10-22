class_name GameHUD
extends CanvasLayer
## HUD раунда Соқыртеке (scenes/world/game_hud.tscn). Сверху одна плашка:
## время, бегуны значками (пойманные — серые с крестом), способность и цель
## раунда. Сообщения — тостом под плашкой, роль в начале и итог — баннером,
## старт — обратным отсчётом.

signal spectate_requested
signal leave_requested
## Кнопки «предыдущий / следующий игрок» в режиме наблюдения: -1 или +1.
signal spectate_cycled(step: int)

const RUNNER_ICON := preload("res://assets/ui/hud/runner.png")
const CAUGHT_ICON := preload("res://assets/ui/hud/runner_caught.png")
const SPRINT_ICON := preload("res://assets/ui/hud/sprint.png")
const ECHO_ICON := preload("res://assets/ui/hud/echo.png")
## Последние секунды раунда таймер горит тревожным цветом.
const TIMER_WARNING_SECONDS := 10
## Баннер роли висит, пока идёт обратный отсчёт старта; в сцене он поднят
## над центром (center_y), чтобы не закрывать цифры отсчёта.
const ROLE_BANNER_SECONDS := 2.5
const RESULT_BANNER_SECONDS := 1.5
## Способность израсходована: значок и подпись приглушены, но непрозрачны.
const SPENT := Color(0.55, 0.55, 0.55)

@onready var _timer: Label = %Timer
@onready var _runners: HBoxContainer = %Runners
@onready var _ability_icon: TextureRect = %AbilityIcon
@onready var _ability: Label = %Ability
@onready var _objective: Label = %Objective
@onready var _slow_chip: Control = %SlowChip
@onready var _slow: Label = %Slow
@onready var _toast: Toast = %Toast
@onready var _banner: Banner = %Banner
@onready var _countdown: Countdown = %Countdown
@onready var _spectate_bar: Control = %SpectateBar
@onready var _spectate_target: Label = %TargetName
@onready var _caught_choice: ConfirmDialog = %CaughtChoice

## Что уже показано — чтобы не пересобирать плашку каждый кадр.
var _shown_seconds := -1
var _shown_runners := Vector2i(-1, -1)

func _ready() -> void:
	_slow_chip.visible = false
	_spectate_bar.visible = false
	_caught_choice.confirmed.connect(spectate_requested.emit)
	_caught_choice.cancelled.connect(leave_requested.emit)
	%PrevBtn.pressed.connect(func() -> void: spectate_cycled.emit(-1))
	%NextBtn.pressed.connect(func() -> void: spectate_cycled.emit(1))

func update_timer(seconds: float) -> void:
	var whole := ceili(maxf(0.0, seconds))
	if whole == _shown_seconds:
		return
	_shown_seconds = whole
	_timer.text = "%d:%02d" % [whole / 60, whole % 60]
	if whole <= TIMER_WARNING_SECONDS:
		_timer.add_theme_color_override("font_color", UiTokens.DANGER)
	else:
		_timer.remove_theme_color_override("font_color")

func update_remaining(alive: int, total: int) -> void:
	if Vector2i(alive, total) == _shown_runners:
		return
	_shown_runners = Vector2i(alive, total)
	for icon in _runners.get_children():
		icon.free()
	for i in total:
		var icon := TextureRect.new()
		icon.texture = RUNNER_ICON if i < alive else CAUGHT_ICON
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_runners.add_child(icon)

## Роль игрока в начале раунда: баннер и цель на плашке.
func show_role(title: String, objective: String) -> void:
	_objective.text = objective
	_banner.show_banner(title, objective, ROLE_BANNER_SECONDS)

func start_countdown(seconds: float) -> void:
	_countdown.step_time = seconds / 3.0
	_countdown.start(3)

func show_result(title: String) -> void:
	_banner.show_banner(title, "", RESULT_BANNER_SECONDS)

func show_message(text: String, duration: float = 2.0) -> void:
	_toast.show_message(text, duration)

func show_caught_choice() -> void:
	_caught_choice.open()

func show_spectate_bar() -> void:
	_spectate_bar.visible = true

func set_spectate_target(display_name: String) -> void:
	_spectate_target.text = display_name

func update_slow(seconds: float) -> void:
	_slow.text = tr("БАЯУЛАУ %.0fс") % ceilf(maxf(0.0, seconds))
	_slow_chip.visible = true

func hide_slow() -> void:
	_slow_chip.visible = false

func update_runner_sprint(time_left: float, uses_left: int) -> void:
	_ability_icon.texture = SPRINT_ICON
	if time_left > 0.0:
		_ability.text = tr("ЖҮГІРУ %.1fс") % time_left
	elif _is_touch():
		_ability.text = "× %d" % uses_left
	else:
		_ability.text = tr("SHIFT · ЖҮГІРУ × %d") % uses_left
	_dim_ability(time_left <= 0.0 and uses_left == 0)

func update_sokyroteke_echo(time_left: float, uses_left: int) -> void:
	_ability_icon.texture = ECHO_ICON
	if time_left > 0.0:
		_ability.text = tr("ҮН ТЫҢДАУ %.1fс") % time_left
	elif _is_touch():
		_ability.text = "× %d" % uses_left
	else:
		_ability.text = tr("E · ҮН ТЫҢДАУ × %d") % uses_left
	_dim_ability(time_left <= 0.0 and uses_left == 0)

func _dim_ability(spent: bool) -> void:
	var tint := SPENT if spent else Color.WHITE
	_ability_icon.modulate = tint
	_ability.modulate = tint

## На телефоне клавиш нет — подсказку «SHIFT / E» заменяет кнопка на экране.
func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()
