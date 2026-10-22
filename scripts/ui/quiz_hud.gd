class_name QuizHUD
extends CanvasLayer
## Квиз при поимке (scenes/world/quiz_hud.tscn): крупная иконка вещи, вопрос
## «Бұл қандай …?», полоса времени и три ответа — мышью, пальцем или клавишами
## 1–3. Ответ проверяется по номеру кнопки, а не по её тексту.

signal answer_submitted(correct: bool)

## Сколько секунд после ответа виден результат «Дұрыс!/Қате!».
const RESULT_SHOW_TIME := 2.0
const ANSWER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]
const CHECK_ICON := preload("res://assets/ui/frames/check.png")
const CROSS_ICON := preload("res://assets/ui/frames/cross.png")

## Растёт с каждым новым квизом. Отложенное скрытие результата прошлого квиза
## сверяет номер, чтобы не закрыть квиз, открытый следующей поимкой.
var _quiz_serial := 0
var _current_item: ClothingItem
var _correct_index := -1
var _answer_time := 1.0
var _time_left := 0.0
var _active := false

@onready var _root: Control = $Root
@onready var _icon: TextureRect = %ItemIcon
@onready var _question: Label = %Question
@onready var _time_bar: TimeBar = %TimeBar
@onready var _answers: Array[Button] = [%Answer1, %Answer2, %Answer3]

func _ready() -> void:
	_root.visible = false
	for i in _answers.size():
		_answers[i].pressed.connect(_on_answer.bind(i))

func show_quiz(item: ClothingItem, answer_time: float) -> void:
	_quiz_serial += 1
	_current_item = item
	_answer_time = answer_time
	_time_left = answer_time
	_active = true
	_root.visible = true
	_icon.texture = load(item.icon_path) if not item.icon_path.is_empty() else null
	_question.text = tr("Бұл қандай %s?") % _slot_name(item.slot_type)
	_question.remove_theme_color_override("font_color")
	_time_bar.ratio = 1.0
	var options := _build_options(item)
	for i in _answers.size():
		var button := _answers[i]
		button.visible = i < options.size()
		button.text = "%d. %s" % [i + 1, options[i]] if button.visible else ""
		button.icon = null
		button.disabled = false

func hide_quiz() -> void:
	_active = false
	_root.visible = false

func is_open() -> bool:
	return _root.visible

## Кнопка ответа номер index (с нуля) — для тестов и подсказок.
func answer_button(index: int) -> Button:
	return _answers[index]

func correct_index() -> int:
	return _correct_index

func _process(delta: float) -> void:
	if not _active:
		return
	_time_left -= delta
	_time_bar.ratio = _time_left / _answer_time
	if _time_left <= 0.0:
		_active = false
		answer_submitted.emit(false)
		hide_quiz()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var index := ANSWER_KEYS.find(event.keycode)
	if index != -1 and _answers[index].visible:
		get_viewport().set_input_as_handled()
		_on_answer(index)

func _on_answer(index: int) -> void:
	if not _active or _current_item == null:
		return
	_active = false
	var correct := index == _correct_index
	answer_submitted.emit(correct)
	_show_result(index, correct)
	var serial := _quiz_serial
	await get_tree().create_timer(RESULT_SHOW_TIME).timeout
	if serial == _quiz_serial:
		hide_quiz()

## Верный ответ отмечен галочкой, выбранный неверный — крестиком; остальные
## гаснут. Цвет дублируется значком — понятно и без различения цветов.
func _show_result(chosen: int, correct: bool) -> void:
	var name := _current_item.get_name_for_lang(GameSettings.get_lang_code())
	if correct:
		_question.text = tr("Дұрыс!")
	else:
		_question.text = "%s %s" % [tr("Қате!"), tr("Бұл: %s") % name]
	_question.add_theme_color_override("font_color", UiTokens.SUCCESS if correct else UiTokens.DANGER)
	for i in _answers.size():
		_answers[i].disabled = i != _correct_index
	_answers[_correct_index].icon = CHECK_ICON
	if not correct:
		_answers[chosen].icon = CROSS_ICON

## Верное название и до двух неверных, в случайном порядке. Неверные,
## совпадающие с верным, отбрасываются — иначе две кнопки читались бы одинаково.
func _build_options(item: ClothingItem) -> Array[String]:
	var lang := GameSettings.get_lang_code()
	var correct := item.get_name_for_lang(lang)
	var wrongs: Array[String] = []
	for wrong in item.get_wrong_answers_for_lang(lang):
		if wrong != correct and wrong not in wrongs:
			wrongs.append(wrong)
	wrongs.shuffle()
	var options: Array[String] = [correct]
	options.append_array(wrongs.slice(0, _answers.size() - 1))
	options.shuffle()
	_correct_index = options.find(correct)
	return options

func _slot_name(slot: ClothingItem.SlotType) -> String:
	match slot:
		ClothingItem.SlotType.HEAD: return tr("бас киім")
		ClothingItem.SlotType.TORSO: return tr("сырт киім")
		ClothingItem.SlotType.PANTS: return tr("шалбар")
		ClothingItem.SlotType.SHOES: return tr("аяқ киім")
	return "?"
