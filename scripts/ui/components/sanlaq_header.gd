class_name SanlaqHeader
extends PanelContainer
## Шапка экрана: заголовок, подзаголовок и золотая черта на собственной подложке.
##
## Подложка нужна потому, что фоны экранов — контрастные фотографии, и тёмный
## текст по ним не читается. Она решает это, не трогая ни фон, ни сам текст:
## приглушение фона убивает картинку, а обводка по глифам держит читаемость, но
## выглядит наклейкой и спорит с остальной вёрсткой.
##
## Панель сжимается по содержимому, поэтому длина строки и язык на раскладку не
## влияют — при переключении на английский шапка просто станет уже или шире.

## Надпись-категория над заголовком. Пустая — строка не показывается.
@export var kicker: String = "":
	set(value):
		kicker = value
		_apply()
@export var title: String = "":
	set(value):
		title = value
		_apply()
@export var subtitle: String = "":
	set(value):
		subtitle = value
		_apply()

@onready var _kicker_label: Label = $Margin/VBox/Kicker
@onready var _title_label: Label = $Margin/VBox/Title
@onready var _subtitle_label: Label = $Margin/VBox/Subtitle

func _ready() -> void:
	# Сеттеры отрабатывают на загрузке сцены, когда детей ещё нет, поэтому
	# значения проставляем ещё раз, когда узлы уже на месте.
	_apply()

func _apply() -> void:
	if _title_label == null:
		return
	_kicker_label.text = kicker
	_kicker_label.visible = not kicker.is_empty()
	_title_label.text = title
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
