class_name StoryChoice
extends Resource
## Вариант ответа в диалоге. Флаг меняет дальнейший текст, бірлік — финал главы.

@export var label: String = ""
## Диалог-ответ, который звучит после выбора.
@export var next_dialogue: String = ""
@export var flag: String = ""
@export var xp: int = 0
@export var unity: int = 0
