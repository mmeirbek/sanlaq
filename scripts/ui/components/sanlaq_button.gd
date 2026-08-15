class_name SanlaqButton
extends Button
## Кнопка с фиксированной высотой и аккуратным размером шрифта.

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size.y = maxf(custom_minimum_size.y, 56.0)
	add_theme_font_size_override("font_size", SanlaqDesignTokens.FONT_SIZE_SUBTITLE)
