extends Control
## Выбор игрового режима. Сюда ведёт кнопка «ОЙНАУ» из главного меню. Карточка
## нажимается целиком, как и её кнопка. Каждый режим открывается через
## экран-объяснение: он рассказывает, как играть и чему учит, и уже оттуда
## уводит в саму игру. Карточки лежат в контейнере, поэтому новый режим
## добавляется одной карточкой.

## Уникальное имя карточки -> id режима (ModeBriefing) и её кнопка.
const MODES := {
	"ChaseCard": ["sokyroteke", "ChasePlayBtn"],
	"AbaiCard": ["abai_says", "AbaiPlayBtn"],
	"TogyzCard": ["togyz_qumalaq", "TogyzPlayBtn"],
	"AqSuyekCard": ["aq_suyek", "AqSuyekPlayBtn"],
}

func _ready() -> void:
	(%Header as ScreenHeader).back_pressed.connect(SceneRouter.go_to_main_menu)
	for card_name: String in MODES:
		var mode_id: String = MODES[card_name][0]
		(get_node("%" + card_name) as SelectableCard).pressed.connect(_open_mode.bind(mode_id))
		(get_node("%" + MODES[card_name][1]) as Button).pressed.connect(_open_mode.bind(mode_id))
	# «Тарих жолы» объясняет себя сам: выбор героя и заставка главы.
	(%StoryCard as SelectableCard).pressed.connect(_open_story)
	(%StoryPlayBtn as Button).pressed.connect(_open_story)

func _open_story() -> void:
	Telemetry.log_event("button_press", {"button": "mode_tarikh_zholy"})
	SceneRouter.go_to_hero_select()

func _open_mode(mode_id: String) -> void:
	Telemetry.log_event("button_press", {"button": "mode_" + mode_id})
	SceneRouter.go_to_mode_briefing(mode_id)
