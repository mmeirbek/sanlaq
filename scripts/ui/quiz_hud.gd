class_name QuizHUD
extends CanvasLayer

signal answer_submitted(correct: bool)

var _current_item: ClothingItem
var _current_options: Array[String] = []
var _timer: float = 0.0
var _max_time: float = 4.0
var _active: bool = false

@onready var panel: Control = $Panel
@onready var item_label: Label = $Panel/ItemLabel
@onready var timer_label: Label = $Panel/TimerLabel
@onready var item_icon: TextureRect = $Panel/ItemIcon
@onready var btn_a: Button = $Panel/Buttons/A
@onready var btn_b: Button = $Panel/Buttons/B
@onready var btn_c: Button = $Panel/Buttons/C

func _ready() -> void:
	panel.visible = false
	btn_a.pressed.connect(_on_answer.bind(0))
	btn_b.pressed.connect(_on_answer.bind(1))
	btn_c.pressed.connect(_on_answer.bind(2))

func show_quiz(item: ClothingItem, answer_time: float) -> void:
	_current_item = item
	_max_time = answer_time
	_timer = answer_time
	_active = true
	panel.visible = true

	var lang := GameSettings.get_lang_code()
	var slot_name := _slot_name(item.slot_type)
	item_label.text = tr("Бұл қандай %s?") % slot_name + "\n \n \n  ?"

	_current_options = _build_options(item)
	btn_a.text = _current_options[0]
	btn_b.text = _current_options[1]
	btn_c.text = _current_options[2]
	item_icon.visible = false
	if not item.icon_path.is_empty():
		var tex := load(item.icon_path) as Texture2D
		if tex:
			item_icon.texture = tex
			item_icon.visible = true

func hide_quiz() -> void:
	_active = false
	panel.visible = false

func show_result(correct: bool, item: ClothingItem) -> void:
	var lang := GameSettings.get_lang_code()
	var name := item.get_name_for_lang(lang)

	if correct:
		item_label.text = tr("Дұрыс!  ✓\n%s") % name
	else:
		item_label.text = tr("Қате!  ✗\nБұл: %s") % name

	btn_a.text = ""
	btn_b.text = ""
	btn_c.text = ""

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	timer_label.text = "%.1f" % maxf(0.0, _timer)
	if _timer <= 0:
		_active = false
		answer_submitted.emit(false)
		hide_quiz()

func _on_answer(index: int) -> void:
	if not _active or _current_item == null:
		return
	_active = false
	var lang := GameSettings.get_lang_code()
	var correct_name := _current_item.get_name_for_lang(lang)
	var correct := _current_options[index] == correct_name
	answer_submitted.emit(correct)
	show_result(correct, _current_item)
	await get_tree().create_timer(2.0).timeout
	hide_quiz()

func _build_options(item: ClothingItem) -> Array[String]:
	var lang := GameSettings.get_lang_code()
	var correct := item.get_name_for_lang(lang)
	var wrongs: Array[String]

	wrongs = item.get_wrong_answers_for_lang(lang).duplicate()

	while wrongs.size() > 2:
		wrongs.remove_at(randi() % wrongs.size())

	var options: Array[String] = [correct]
	for w in wrongs.slice(0, 2):
		options.append(w)
	options.shuffle()
	return options

func _slot_name(slot: ClothingItem.SlotType) -> String:
	match slot:
		ClothingItem.SlotType.HEAD: return tr("бас киім")
		ClothingItem.SlotType.TORSO: return tr("сырт киім")
		ClothingItem.SlotType.PANTS: return tr("шалбар")
		ClothingItem.SlotType.SHOES: return tr("аяқ киім")
	return "?"
