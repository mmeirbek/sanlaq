extends Control
## Выбор игрового режима. Сюда ведёт кнопка «ОЙНАУ» из главного меню. Карточки
## лежат в контейнере, поэтому новый режим добавляется одной карточкой — ширина
## пересчитается сама.

@onready var _chase_btn: Button = %ChasePlayBtn
@onready var _abai_btn: Button = %AbaiPlayBtn
@onready var _togyz_btn: Button = %TogyzPlayBtn
@onready var _aq_btn: Button = %AqSuyekPlayBtn
@onready var _back_btn: Button = %BackBtn

func _ready() -> void:
	_chase_btn.pressed.connect(_on_chase_pressed)
	_abai_btn.pressed.connect(_on_abai_pressed)
	_togyz_btn.pressed.connect(_on_togyz_pressed)
	_aq_btn.pressed.connect(_on_aq_pressed)
	_back_btn.pressed.connect(func() -> void: SceneRouter.go_to_main_menu())

## Каждый режим открывается через экран-объяснение: он рассказывает, как играть
## и чему учит, и уже оттуда уводит в саму игру.
func _on_chase_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "mode_sokyroteke"})
	SceneRouter.go_to_mode_briefing("sokyroteke")

func _on_abai_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "mode_abai_says"})
	SceneRouter.go_to_mode_briefing("abai_says")

func _on_togyz_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "mode_togyz_qumalaq"})
	SceneRouter.go_to_mode_briefing("togyz_qumalaq")

func _on_aq_pressed() -> void:
	Telemetry.log_event("button_press", {"button": "mode_aq_suyek"})
	SceneRouter.go_to_mode_briefing("aq_suyek")
