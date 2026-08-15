class_name SanlaqPanel
extends PanelContainer
## Карточка с заголовком. Содержимое добавляется в узел "Content".

@export var panel_title := ""

@onready var _title_label: Label = %TitleLabel

func _ready() -> void:
	_title_label.text = panel_title
	_title_label.visible = not panel_title.is_empty()
	if _title_label.visible:
		_title_label.add_theme_font_override("font", SanlaqDesignTokens.FONT_BOLD)
		_title_label.add_theme_font_size_override("font_size", SanlaqDesignTokens.FONT_SIZE_SUBTITLE)
