class_name SanlaqDivider
extends HSeparator
## Тонкий золотой разделитель.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := StyleBoxLine.new()
	line.color = SanlaqDesignTokens.GOLD_DARK
	line.thickness = 2
	add_theme_stylebox_override("separator", line)
