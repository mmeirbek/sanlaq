class_name StoryBeat
extends Resource
## Шаг главы: подойти к NPC, выслушать диалог и, если есть, выполнить действие.
## Шаги идут строго по очереди (StoryState).

enum Action { NONE, COLLECT, BUILD, ESCORT, FIND, SOKYR_TEKE, ASYK, BAIGE, DUEL, CAMPFIRE, MAP }
enum Location { AUL, STEPPE, CITY }

@export var npc: String = ""
## Цель на HUD.
@export var objective: String = ""
@export var dialogue: String = ""
@export var xp: int = 0
## Имя контрольной точки — для сохранения и отладки.
@export var checkpoint: String = ""
@export var action: Action = Action.NONE
## Статьи энциклопедии, которые открывает шаг.
@export var unlock: Array[String] = []
## Где ждёт шаг; если игрок в другом месте, сначала — переезд.
@export var location: Location = Location.AUL
@export var task: StoryTask
@export_group("Костёр")
@export var campfire_title: String = ""
@export var topics: Array[CampfireTopic] = []
@export_group("Карта маршрута")
@export var route_title: String = ""
@export var route_goal: String = ""
@export var route_start: String = ""
@export var route_end: String = ""
## Точки маршрута в долях карты 0..1.
@export var route: PackedVector2Array = PackedVector2Array()
