class_name StoryNpc
extends Resource
## Житель, с которым можно говорить. Вне своего шага он говорит idle-реплику один
## раз, потом — короткую again.

@export var id: String = ""
@export var name: String = ""
@export var look: String = ""
@export var idle_line: String = ""
@export var again_line: String = ""
