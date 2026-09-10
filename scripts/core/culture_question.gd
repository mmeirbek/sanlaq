class_name CultureQuestion
extends Resource
## Вопрос о казахских традициях для режима «Ақ сүйек». Верный ответ даёт больше
## шагов, поэтому знание прямо переводится в продвижение по полю.
##
## Локализация по общему правилу проекта: строки хранятся по-казахски и они же
## служат ключами в `assets/i18n/ui_strings.csv`.

@export var id: String = ""
## Сам вопрос.
@export var question: String = ""
## Варианты ответа. Порядок в ресурсе фиксированный, экран перемешивает их сам,
## чтобы верный не оказывался всегда на одном месте.
@export var options: Array[String] = []
## Номер верного варианта в `options`.
@export var correct: int = 0
## Короткий факт, который показывается после ответа — ради него режим и затеян.
@export var fact: String = ""

func correct_option() -> String:
	return options[correct] if correct >= 0 and correct < options.size() else ""
