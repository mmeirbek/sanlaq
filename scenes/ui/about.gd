extends Control

@onready var _back_btn: Button = $BackBtn

func _ready() -> void:
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())
