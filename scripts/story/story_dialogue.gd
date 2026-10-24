class_name StoryDialogue
extends Resource
## Реплика NPC: несколько строк и, возможно, выбор из двух вариантов.
## check_note — что сверить историкам (см. docs/HISTORY_REVIEW.md); пусто — не
## историческое утверждение.

@export var id: String = ""
@export var speaker: String = ""
## Облик говорящего — ключ StoryLooks.
@export var look: String = ""
@export var lines: Array[String] = []
@export var choices: Array[StoryChoice] = []
@export var check_note: String = ""
