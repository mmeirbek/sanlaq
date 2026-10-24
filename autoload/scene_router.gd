extends Node

const SCENE_MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const SCENE_LOBBY := "res://scenes/ui/lobby.tscn"
const SCENE_WARDROBE := "res://scenes/ui/wardrobe.tscn"
const SCENE_GAME := "res://scenes/world/game.tscn"
const SCENE_RESULTS := "res://scenes/ui/results.tscn"
const SCENE_CODEX := "res://scenes/ui/codex.tscn"
const SCENE_ABOUT := "res://scenes/ui/about.tscn"
const SCENE_SETTINGS := "res://scenes/ui/settings.tscn"
const SCENE_MODE_SELECT := "res://scenes/ui/mode_select.tscn"
const SCENE_MODE_BRIEFING := "res://scenes/ui/mode_briefing.tscn"
const SCENE_ABAI_SAYS := "res://scenes/ui/abai_says.tscn"
const SCENE_TOGYZ_QUMALAQ := "res://scenes/ui/togyz_qumalaq.tscn"
const SCENE_AQ_SUYEK := "res://scenes/ui/aq_suyek.tscn"
const SCENE_HERO_SELECT := "res://scenes/story/hero_select.tscn"
const SCENE_STORY_WORLD := "res://scenes/story/story_world.tscn"

## Затемнение между экранами, как в atilla: уход и проявление, секунды.
const FADE_OUT := 0.35
const FADE_IN := 0.5

var _pending_game_data: Dictionary = {}
var _pending_results: Dictionary = {}
## Какой режим объясняет экран брифинга — id ресурса ModeBriefing.
var _pending_briefing: String = ""
## Итог мини-игры, сыгранной в другой сцене (соқыр теке), для мира сюжета.
var _pending_story_result: Dictionary = {}

## Переходы со шторкой. В автотестах и CI (headless) выключены — переход
## мгновенный; тест шторки включает их сам.
var animate_transitions := not RunContext.is_headless()

## Шторка поверх всех экранов; пока экран уходит, она глотает клики.
var _curtain: ColorRect
var _fade: Tween
## Экран уходит: он заморожен, ввод не доходит ни до него, ни до нового.
var _changing := false
## Переход, запрошенный во время другого (например, из _ready новой сцены):
## выполняется сразу после него — побеждает последний запрос.
var _queued_scene := ""

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_curtain = ColorRect.new()
	_curtain.color = Color(UiTokens.INK, 0.0)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_curtain)

func go_to_main_menu() -> void:
	_change_scene(SCENE_MAIN_MENU)

func go_to_lobby(game_data: Dictionary = {}) -> void:
	if not game_data.is_empty():
		_pending_game_data = game_data
	_change_scene(SCENE_LOBBY)

func go_to_wardrobe() -> void:
	_change_scene(SCENE_WARDROBE)

func go_to_game(game_data: Dictionary = {}) -> void:
	_pending_game_data = game_data
	_change_scene(SCENE_GAME)

func go_to_results(results: Dictionary = {}) -> void:
	set_pending_results(results)
	_change_scene(SCENE_RESULTS)

## Как set_pending_game_data: для тестов, которые поднимают экран итогов сами.
func set_pending_results(results: Dictionary) -> void:
	_pending_results = results

func go_to_codex() -> void:
	_change_scene(SCENE_CODEX)

func go_to_about() -> void:
	_change_scene(SCENE_ABOUT)

func go_to_settings() -> void:
	_change_scene(SCENE_SETTINGS)

func go_to_mode_select() -> void:
	_change_scene(SCENE_MODE_SELECT)

## Объяснение режима перед стартом. Дальше брифинг сам уводит в нужный режим.
func go_to_mode_briefing(mode_id: String) -> void:
	set_pending_briefing(mode_id)
	_change_scene(SCENE_MODE_BRIEFING)

## Отдельно от навигации: экран брифинга поднимают ещё и автотесты, которые
## добавляют сцену в дерево сами и смену сцены запускать не должны.
func set_pending_briefing(mode_id: String) -> void:
	_pending_briefing = mode_id

func get_pending_briefing() -> String:
	return _pending_briefing

func go_to_abai_says() -> void:
	_change_scene(SCENE_ABAI_SAYS)

func go_to_togyz_qumalaq() -> void:
	_change_scene(SCENE_TOGYZ_QUMALAQ)

func go_to_aq_suyek() -> void:
	_change_scene(SCENE_AQ_SUYEK)

func go_to_hero_select() -> void:
	_change_scene(SCENE_HERO_SELECT)

## Мир «Тарих жолы»; result — итог мини-игры, из которой вернулись.
func go_to_story_world(result: Dictionary = {}) -> void:
	_pending_story_result = result
	_change_scene(SCENE_STORY_WORLD)

func take_story_result() -> Dictionary:
	var result := _pending_story_result
	_pending_story_result = {}
	return result

## Как set_pending_briefing: для тестов и скриншотов, которые поднимают сцену
## игры сами.
func set_pending_game_data(game_data: Dictionary) -> void:
	_pending_game_data = game_data

func get_pending_game_data() -> Dictionary:
	var data := _pending_game_data
	_pending_game_data = {}
	return data

func peek_pending_game_data() -> Dictionary:
	return _pending_game_data

func get_pending_results() -> Dictionary:
	var data := _pending_results
	_pending_results = {}
	return data

func quit() -> void:
	Telemetry.log_event("session_end", {"seconds_played": Telemetry.session_seconds()})
	Telemetry.flush()
	get_tree().quit()

func _input(_event: InputEvent) -> void:
	# Уходящий экран заморожен, но клавиатура дошла бы до его кнопок в фокусе.
	if _changing:
		get_viewport().set_input_as_handled()

func _change_scene(to: String) -> void:
	if _changing:
		_queued_scene = to
		return
	var tree := get_tree()
	var from := tree.current_scene.scene_file_path if tree.current_scene else ""
	if from == to:
		return
	_changing = true
	if animate_transitions:
		# Уходящий экран больше ничего не делает: ни таймеров, ни записи
		# результатов матча, ни нажатий.
		if tree.current_scene:
			tree.current_scene.process_mode = Node.PROCESS_MODE_DISABLED
		_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
		await _fade_curtain(1.0, FADE_OUT)
	var err := tree.change_scene_to_file(to)
	if err != OK:
		Telemetry.log_error("change_scene_to_file failed with error %d" % err, to)
		if tree.current_scene:
			tree.current_scene.process_mode = Node.PROCESS_MODE_INHERIT
	# Новая сцена встаёт в дерево в конце кадра, её _ready может сам попросить переход.
	await tree.process_frame
	_changing = false
	var queued := _queued_scene
	_queued_scene = ""
	if not queued.is_empty() and queued != to:
		# Шторка ещё тёмная — следующий переход начинается с неё.
		_change_scene(queued)
		return
	if animate_transitions:
		_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		await _fade_curtain(0.0, FADE_IN)

## Новый переход прерывает проявление прошлого: шторка идёт от текущей прозрачности.
func _fade_curtain(alpha: float, seconds: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_curtain, "color:a", alpha, seconds)
	await _fade.finished
