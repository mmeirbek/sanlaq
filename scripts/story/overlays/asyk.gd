extends Control
## «Асық ату»: пять асыков на линии в кругу, у игрока пять бросков сақой.
## Бросок — два нажатия (E, пробел, клик): направление, потом сила. Правила —
## AsykRules. Пауза работает: всё считается от обычного delta (в atilla — нет).

signal won
signal lost

const FIELD := preload("res://assets/sprites/story/asyk_field.png")
const ASYK := preload("res://assets/sprites/story/asyk.png")
const SAKA := preload("res://assets/sprites/story/saka.png")
## Площадка и фишки нарисованы ×2; на экране — ×1.5, то есть 3 px на пиксель арта.
const SCALE := 1.5
const ART := 3
const BAR_WIDTH := 480.0
const FLY_SECONDS := 0.55

enum Phase { READY, AIM, POWER, FLYING, DONE }

var rules := AsykRules.new()
var _phase := Phase.READY
var _aim := 0.0
var _aim_dir := 1
var _power := 0.0
var _power_dir := 1
var _locked_aim := 0.0
var _field: TextureRect
var _pieces: Array[TextureRect] = []
var _saka: TextureRect
var _aim_marker: ColorRect
var _power_fill: ColorRect
var _stage: Label
var _tally: Label
var _countdown: Countdown
var _banner: Banner


func _ready() -> void:
	var box := StoryOverlays.frame(self, 0.92)
	StoryOverlays.label(box, tr("АСЫҚ АТУ"), "TitleLabel")
	StoryOverlays.label(box, tr("Екі рет бас: алдымен бағытты, сосын күшті дәл тап."), "SubtitleLabel")
	_tally = StoryOverlays.label(box, "", "HudLabel")
	_field = TextureRect.new()
	_field.texture = FIELD
	_field.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_field.custom_minimum_size = FIELD.get_size() * SCALE
	_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_field)
	for i in 5:
		var piece := _sprite(ASYK)
		piece.position = _home(i)
		_pieces.append(piece)
	_saka = _sprite(SAKA)
	_saka.position = _saka_home()

	_aim_marker = _bar(box, tr("БАҒЫТ"), true)
	_power_fill = _bar(box, tr("КҮШ"), false)
	_stage = StoryOverlays.label(box, "", "WarningLabel")
	_countdown = Countdown.new()
	add_child(_countdown)
	_countdown.finished.connect(func() -> void: _set_phase(Phase.AIM))
	_banner = Banner.new()
	add_child(_banner)
	_refresh()
	_countdown.start(3)


func _sprite(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = texture.get_size() * SCALE
	_field.add_child(rect)
	return rect


## Где стоит асык i на линии круга (координаты площадки).
func _home(i: int) -> Vector2:
	return Vector2(60 + i * 20, 44) * ART - ASYK.get_size() * SCALE / 2


func _saka_home() -> Vector2:
	return Vector2(100, 84) * ART - SAKA.get_size() * SCALE / 2


## Асык, в который летит сақа: ближайший к направлению из ещё стоящих.
func _target(aim: float) -> TextureRect:
	var want := (aim + 1.0) * 2.0
	var best: TextureRect = null
	for i in _pieces.size():
		if _pieces[i].visible and (best == null or absf(i - want) < absf(_pieces.find(best) - want)):
			best = _pieces[i]
	return best


## Полоса: для направления — зелёная зона посередине и бегунок, для силы —
## заливка слева и зелёная зона справа. Возвращает бегунок или заливку.
func _bar(parent: Control, caption: String, centered_zone: bool) -> ColorRect:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var title := StoryOverlays.label(row, caption, "HeadingLabel")
	title.custom_minimum_size.x = 120
	var track := PanelContainer.new()
	track.theme_type_variation = "InsetPanel"
	row.add_child(track)
	var area := Control.new()
	area.custom_minimum_size = Vector2(BAR_WIDTH, 24)
	track.add_child(area)
	var zone := ColorRect.new()
	zone.color = UiTokens.SUCCESS
	if centered_zone:
		zone.size = Vector2(BAR_WIDTH * AsykRules.AIM_ZONE, 24)
		zone.position = Vector2((BAR_WIDTH - zone.size.x) / 2, 0)
	else:
		zone.size = Vector2(BAR_WIDTH * AsykRules.POWER_BAND, 24)
		zone.position = Vector2(BAR_WIDTH - zone.size.x, 0)
	area.add_child(zone)
	var thing := ColorRect.new()
	thing.color = UiTokens.CREAM if centered_zone else UiTokens.GOLD
	thing.size = Vector2(8, 24) if centered_zone else Vector2(0, 12)
	thing.position.y = 0 if centered_zone else 6
	area.add_child(thing)
	return thing


func _set_phase(phase: Phase) -> void:
	_phase = phase
	match phase:
		Phase.AIM:
			_stage.text = tr("1 · БАҒЫТТЫ ТАҢДА — E / БОС ОРЫН")
		Phase.POWER:
			_stage.text = tr("2 · КҮШТІ ТАҢДА — E / БОС ОРЫН")
		_:
			_stage.text = ""


func _refresh() -> void:
	_tally.text = tr("Атыс: %d   ·   Ұтыс: %d / %d") % [AsykRules.THROWS - rules.thrown, rules.hits, AsykRules.NEEDED]


func _process(delta: float) -> void:
	match _phase:
		Phase.AIM:
			var swing := AsykRules.swing(_aim, _aim_dir, rules.aim_speed(), delta, -1.0, 1.0)
			_aim = swing[0]
			_aim_dir = swing[1]
			var x := (_aim + 1.0) / 2.0 * (BAR_WIDTH - 8)
			_aim_marker.position.x = roundf(x / UiTokens.PIXEL) * UiTokens.PIXEL
			_aim_marker.color = UiTokens.SUCCESS if AsykRules.aim_ok(_aim) else UiTokens.CREAM
		Phase.POWER:
			var swing := AsykRules.swing(_power, _power_dir, AsykRules.POWER_SPEED, delta, 0.0, 1.0)
			_power = swing[0]
			_power_dir = swing[1]
			_power_fill.size.x = roundf(_power * BAR_WIDTH / UiTokens.PIXEL) * UiTokens.PIXEL
			_power_fill.color = UiTokens.SUCCESS if AsykRules.power_ok(_power) else UiTokens.GOLD


func _unhandled_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	var pressed := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
		or (mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	if _phase == Phase.AIM:
		get_viewport().set_input_as_handled()
		_locked_aim = _aim
		_set_phase(Phase.POWER)
	elif _phase == Phase.POWER:
		get_viewport().set_input_as_handled()
		throw(_locked_aim, _power)


## Бросок с данными направлением и силой (его же вызывает автопилот).
func throw(aim: float, power: float) -> void:
	_set_phase(Phase.FLYING)
	var hit := rules.throw(aim, power)
	var piece := _target(aim)
	var landing := piece.position + Vector2(0, 12 if hit else -72 + power * 36)
	if not hit:
		landing.x += aim * 180
	var tween := create_tween()
	tween.tween_property(_saka, "position", (landing / ART).round() * ART, FLY_SECONDS)
	if hit:
		tween.tween_callback(func() -> void:
			PixelBurst.spawn(_field, piece.position + piece.size / 2, StoryTaskRunner.BURST_COLORS, 12,
				Vector2(40, 120), Vector2(0, 200), 0.5))
		tween.tween_property(piece, "position:y", -96.0, 0.4)
		tween.tween_callback(func() -> void: piece.visible = false)
	tween.tween_interval(0.4)
	tween.tween_callback(_after_throw)


func _after_throw() -> void:
	_refresh()
	_saka.position = _saka_home()
	if not rules.is_over():
		_aim = 0.0
		_power = 0.0
		_power_fill.size.x = 0
		_set_phase(Phase.AIM)
		return
	_set_phase(Phase.DONE)
	_banner.show_banner(tr("ЖЕҢІС!") if rules.is_won() else tr("АСЫҚТАР ШЕҢБЕРДЕ ҚАЛДЫ"), "", 1.2)
	await get_tree().create_timer(2.0, false).timeout
	if rules.is_won():
		won.emit()
	else:
		lost.emit()
	queue_free()
