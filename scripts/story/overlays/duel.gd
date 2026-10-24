extends Control
## «Жекпе-жек»: пошаговый бой героя с вражеским батыром на вечерней арене.
## Ход — кнопка или клавиши 1–5; правила и числа — DuelRules, тексты — как
## в atilla. Жасақтас (КӨМЕК) приходит, если бірлік хватает (StoryState).

signal won
signal lost

const ARENA := preload("res://assets/sprites/story/duel_arena.png")
const FIGHTER_SCALE := 2
## Ступни бойцов — на вытоптанном круге (строка 84 арта арены).
const FIGHTERS_Y := 104
const HERO_X := 200
const ENEMY_X := 440
const LUNGE := 120
const STEP_SECONDS := 0.35
const HEALTH_WIDTH := 300
const MOVE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

var hero_name := "Батыр"
var hero_look := "kabanbay"
var with_ally := false
var rules: DuelRules

var _arena: TextureRect
var _hero: CharacterVisual
var _enemy: CharacterVisual
var _hero_bar: TimeBar
var _enemy_bar: TimeBar
var _hero_hp: Label
var _enemy_hp: Label
var _turn: Label
var _log: Label
var _buttons := {}
var _busy := false
var _banner: Banner


func _ready() -> void:
	if rules == null:
		rules = DuelRules.new(with_ally)
	var box := StoryOverlays.frame(self, 0.92)
	StoryOverlays.label(box, tr("ЖЕКПЕ-ЖЕК"), "TitleLabel")
	var bars := HBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", ARENA.get_width() - HEALTH_WIDTH * 2)
	box.add_child(bars)
	var hero_side := _health(bars, tr(hero_name))
	_hero_bar = hero_side[0]
	_hero_hp = hero_side[1]
	var enemy_side := _health(bars, tr("Жау батыры"))
	_enemy_bar = enemy_side[0]
	_enemy_hp = enemy_side[1]

	_arena = TextureRect.new()
	_arena.texture = ARENA
	_arena.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_arena.clip_contents = true
	box.add_child(_arena)
	_hero = _fighter(hero_look, HERO_X, Vector2.RIGHT)
	_enemy = _fighter("raider", ENEMY_X, Vector2.LEFT)

	_turn = StoryOverlays.label(box, "", "WarningLabel")
	_log = StoryOverlays.label(box, tr("Жекпе-жек басталады!"), "LeadLabel", ARENA.get_width())
	_log.custom_minimum_size.y = 64
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.SPACE_S)
	box.add_child(row)
	var moves := [
		[DuelRules.Move.ATTACK, "ШАБУЫЛ", "18–28 зақым"],
		[DuelRules.Move.GUARD, "ҚОРҒАНУ", "зақым екі есе аз"],
		[DuelRules.Move.FEINT, "АЙЛА", "35 зақым, 60%"],
		[DuelRules.Move.REMEDY, "ШИПА", "+34 күш"],
	]
	if rules.has_ally:
		moves.append([DuelRules.Move.ALLY, "КӨМЕК", "40 зақым"])
	for i in moves.size():
		var move: DuelRules.Move = moves[i][0]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		row.add_child(cell)
		var button := PixelButton.new()
		button.text = tr(moves[i][1])
		button.theme_type_variation = "ButtonSecondary"
		button.custom_minimum_size.x = 148
		button.pressed.connect(choose.bind(move))
		cell.add_child(button)
		StoryOverlays.label(cell, "%d · %s" % [i + 1, tr(moves[i][2])], "CaptionLabel")
		_buttons[move] = button

	_banner = Banner.new()
	add_child(_banner)
	_refresh()


func _health(parent: Control, caption: String) -> Array:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = HEALTH_WIDTH
	column.add_theme_constant_override("separation", 0)
	parent.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var name_label := StoryOverlays.label(top, caption, "HeadingLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var hp := StoryOverlays.label(top, "", "HudLabel")
	var bar := TimeBar.new()
	column.add_child(bar)
	return [bar, hp]


func _fighter(look: String, x: int, facing: Vector2) -> CharacterVisual:
	var visual := StoryLooks.create(look)
	visual.scale = Vector2.ONE * FIGHTER_SCALE
	_arena.add_child(visual)
	visual.set_rest_position(Vector2(x, FIGHTERS_Y))
	visual.set_direction(facing)
	return visual


func _refresh() -> void:
	_hero_bar.ratio = float(rules.hero) / DuelRules.HERO_HEALTH
	_enemy_bar.ratio = float(rules.enemy) / DuelRules.ENEMY_HEALTH
	_hero_hp.text = "%d / %d" % [maxi(0, rules.hero), DuelRules.HERO_HEALTH]
	_enemy_hp.text = "%d / %d" % [maxi(0, rules.enemy), DuelRules.ENEMY_HEALTH]
	var feint: PixelButton = _buttons[DuelRules.Move.FEINT]
	feint.text = tr("АЙЛА") if rules.feint_cooldown <= 0 else "%s (%d)" % [tr("АЙЛА"), rules.feint_cooldown]
	var remedy: PixelButton = _buttons[DuelRules.Move.REMEDY]
	remedy.text = tr("ШИПА") if rules.remedies > 0 else "%s (0)" % tr("ШИПА")
	for move: DuelRules.Move in _buttons:
		(_buttons[move] as PixelButton).disabled = _busy or rules.is_over() or not rules.can_use(move)
	if rules.is_over():
		_turn.text = ""
	elif _busy:
		_turn.text = tr("ЖАУДЫҢ КЕЗЕГІ")
	else:
		_turn.text = tr("САҚ БОЛ! ҚОРҒАН!") if rules.winding_up else tr("СЕНІҢ КЕЗЕГІҢ")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index := MOVE_KEYS.find(key.physical_keycode)
	var moves := _buttons.keys()
	if index >= 0 and index < moves.size():
		get_viewport().set_input_as_handled()
		choose(moves[index])


## Ход героя (его же делает автопилот), затем ответ врага — с паузами,
## чтобы удары читались.
func choose(move: DuelRules.Move) -> void:
	if _busy or not rules.can_use(move) or rules.is_over():
		return
	_busy = true
	var out := rules.play(move)
	_refresh()
	_hero_bar.ratio = float(rules.hero + int(out["hero_damage"])) / DuelRules.HERO_HEALTH
	_hero_hp.text = "%d / %d" % [rules.hero + int(out["hero_damage"]), DuelRules.HERO_HEALTH]
	_log.text = _hero_line(out)
	if int(out["enemy_damage"]) > 0:
		await _lunge(_hero, 1)
		_hit(_enemy)
	elif move == DuelRules.Move.GUARD:
		_popup(_hero, tr("ҚОРҒАН"), UiTokens.CREAM)
	elif move == DuelRules.Move.FEINT:
		_popup(_enemy, tr("ЖАЛТАРДЫ"), UiTokens.CREAM)
	elif move == DuelRules.Move.REMEDY:
		_popup(_hero, "+%d" % int(out["healed"]), UiTokens.SUCCESS)
	if bool(out["feint_ok"]):
		_popup(_enemy, tr("АЙЛА ӨТТІ!"), UiTokens.GOLD_LIGHT)
	elif move == DuelRules.Move.ALLY:
		_popup(_enemy, tr("ЖАСАҚ!"), UiTokens.GOLD_LIGHT)
	await get_tree().create_timer(STEP_SECONDS * 2, false).timeout
	var enemy_line := _enemy_line(out)
	if not enemy_line.is_empty():
		_log.text += "\n" + enemy_line
	if int(out["hero_damage"]) > 0:
		await _lunge(_enemy, -1)
		_hit(_hero)
		if bool(out["heavy"]) and move == DuelRules.Move.GUARD:
			_popup(_hero, tr("ТОСТЫҢ!"), UiTokens.CREAM)
	_busy = false
	_refresh()
	if rules.is_over():
		_finish()


func _hero_line(out: Dictionary) -> String:
	match out["move"]:
		DuelRules.Move.ATTACK:
			return tr("Соққың дәл тиді: %d зақым.") % int(out["enemy_damage"])
		DuelRules.Move.GUARD:
			return tr("Қалқанды көтердің. Келесі соққы әлсіз тиеді.")
		DuelRules.Move.FEINT:
			return tr("Айла-шарғың өтті! 35 зақым.") if out["feint_ok"] else tr("Жау айлаңды аңғарып қалды.")
		DuelRules.Move.REMEDY:
			return tr("Жарақатыңды таңып, күш жинадың: +%d.") % int(out["healed"])
		DuelRules.Move.ALLY:
			return tr("Жасақтас жауды дәл тапты: 40 зақым!")
	return ""


func _enemy_line(out: Dictionary) -> String:
	var damage := int(out["hero_damage"])
	if bool(out["heavy"]):
		if out["move"] == DuelRules.Move.GUARD:
			return tr("Ауыр соққыны қалқанмен тостың: %d зақым.") % damage
		return tr("Ауыр соққы тиді: %d зақым!") % damage
	if rules.winding_up:
		return tr("Жау найзасын көтерді — ауыр соққыға дайындалуда!")
	if damage > 0:
		if bool(out["blocked"]):
			return tr("Жасақтас қалқанымен бөгеді: %d зақым.") % damage
		return tr("Жаудың соққысы: %d зақым.") % damage
	return ""


## Выпад к сопернику и обратно; direction — куда (+1 вправо).
func _lunge(fighter: CharacterVisual, direction: int) -> void:
	var home := fighter.position
	var tween := create_tween()
	tween.tween_method(func(x: float) -> void:
		fighter.set_rest_position(Vector2(roundf(x / UiTokens.PIXEL) * UiTokens.PIXEL, home.y)),
		home.x, home.x + direction * LUNGE, STEP_SECONDS * 0.5)
	tween.tween_method(func(x: float) -> void:
		fighter.set_rest_position(Vector2(roundf(x / UiTokens.PIXEL) * UiTokens.PIXEL, home.y)),
		home.x + direction * LUNGE, home.x, STEP_SECONDS * 0.5)
	await tween.finished


func _hit(fighter: CharacterVisual) -> void:
	PixelBurst.spawn(_arena, fighter.position + Vector2(0, -24), StoryTaskRunner.BURST_COLORS, 10,
		Vector2(40, 120), Vector2(0, 200), 0.4)
	var tween := create_tween()
	tween.tween_property(fighter, "modulate", Color(UiTokens.DANGER, 1.0), 0.06)
	tween.tween_property(fighter, "modulate", Color.WHITE, 0.2)


func _popup(fighter: CharacterVisual, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "HeadingLabel"
	label.add_theme_color_override("font_color", color)
	_arena.add_child(label)
	label.position = fighter.position + Vector2(-label.get_combined_minimum_size().x / 2, -88)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 24, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tween.tween_callback(label.queue_free)


func _finish() -> void:
	var victory := rules.is_won()
	_log.text = tr("Жау батыры жеңілді!") if victory else tr("Жекпе-жекте жеңілдің.")
	_banner.show_banner(tr("ЖЕҢІС!") if victory else tr("ЖЕҢІЛДІҢ"),
		tr("Жасақтың рухы көтерілді!") if victory else tr("Тыныс алып, қайта шық."), 1.6)
	await get_tree().create_timer(2.4, false).timeout
	if victory:
		won.emit()
	else:
		lost.emit()
	queue_free()
