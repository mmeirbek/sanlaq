class_name StoryPlacement
extends Resource
## Человек в мире: NPC, с которым можно говорить, или просто житель (npc пусто).

@export var npc: String = ""
@export var look: String = ""
## Метры мира.
@export var position: Vector2 = Vector2.ZERO
@export var facing: Vector2 = Vector2.DOWN
@export var location: StoryBeat.Location = StoryBeat.Location.AUL
