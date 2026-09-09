class_name ModeBriefing
extends Resource
## Объяснение режима, которое показывается перед началом игры: как играется и
## каким навыкам учит. Как и весь остальной контент проекта — обычный `.tres`
## в `data/briefings/`, код менять не нужно.
##
## Локализация по общему правилу проекта: строки хранятся по-казахски, и они же
## являются ключами в `assets/i18n/ui_strings.csv`. `tr()` отдаёт казахский при
## локали kk и английский при en.
##
## Озвучка: имя аудиофайла строки собирается из `id` и её порядкового номера —
## `assets/audio/voice/<kk|en>/<id>_01.wav`. Нумерация сквозная: сначала строки
## `how_to_play`, затем `skills`. Если файла нет, `Narration` проговорит строку
## системным синтезатором речи, а если и его нет — экран просто подсветит её
## молча. Подробности — в `assets/audio/voice/README.md`.

## Идентификатор режима: он же ключ маршрутизации и префикс имён аудиофайлов.
@export var id: String = ""
## Надпись-категория над названием, например «ТАҚТА ОЙЫНЫ».
@export var kicker: String = ""
## Название режима.
@export var title: String = ""
## Как играется — по одному шагу на строку.
@export var how_to_play: Array[String] = []
## Каким навыкам учит — по одному навыку на строку.
@export var skills: Array[String] = []
## Вариант фона (`SanlaqSceneBackdrop.Variant`), чтобы брифинг стоял на фоне
## своего режима, а не на общем.
@export var backdrop: int = 0

## Все озвучиваемые строки подряд, в порядке показа и нумерации файлов.
func spoken_lines() -> Array[String]:
	var out: Array[String] = []
	out.append_array(how_to_play)
	out.append_array(skills)
	return out

## Имя аудиофайла строки без расширения: "togyz_qumalaq_03".
func voice_id(line_index: int) -> String:
	return "%s_%02d" % [id, line_index + 1]
