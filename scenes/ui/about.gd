extends Control
## «Об игре»: правила и смысл Соқыртеке в четырёх карточках с картинками.

func _ready() -> void:
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_main_menu)
