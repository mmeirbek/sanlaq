class_name EncyclopediaEntry
extends Resource
## Статья энциклопедии «Тарих жолы». Открыта сразу или открывается по ходу сюжета.

@export var id: String = ""
## ТҰЛҒАЛАР, ОҚИҒАЛАР, ЖЕР-СУ, МӘДЕНИЕТ.
@export var category: String = ""
@export var title: String = ""
@export_multiline var text: String = ""
@export var open_from_start: bool = false
## Картинка: облик человека или иконка предмета.
@export var look: String = ""
@export var icon: String = ""
@export var check_note: String = ""
