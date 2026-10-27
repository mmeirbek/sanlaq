class_name StoryTask
extends Resource
## Работа в мире: что собрать, что построить, куда отвести, что найти.
## Координаты — в метрах мира (как в atilla); в пиксели их переводит StoryWorld.

@export var title: String = ""
@export var hint: String = ""
@export var item_label: String = ""
## Какие предметы лежат в точках, по порядку.
@export var props: Array[String] = []
@export var points: PackedVector2Array = PackedVector2Array()
## Сколько нужно собрать (сбор) или сколько частей (стройка).
@export var required: int = 1
## Площадка стройки, коновязь, финиш бәйге.
@export var goal: Vector2 = Vector2.ZERO
