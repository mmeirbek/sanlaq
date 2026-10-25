class_name StoryHero
extends Resource
## Герой, которого выбирают в начале: у каждого своя глава.

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var era: String = ""
@export var tagline: String = ""
@export var look: String = ""
@export var chapter: String = ""
## Порядок в карусели.
@export var order: int = 0
