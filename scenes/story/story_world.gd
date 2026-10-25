extends Node2D
## «Тарих жолы»: мир главы выбранного героя. Шаги идут по очереди (StoryState):
## дойти до жителя — разговор — действие (задание, мини-игра, костёр, карта).
## Маркер над целью и шевроны на земле ведут к тому, что нужно сделать сейчас.
## Если шаг ждёт в другом месте — цель арба, на ней переезжают.

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const MARKER := preload("res://assets/sprites/story/marker.png")
const CHEVRON := preload("res://assets/sprites/story/chevron.png")
const TALK_ICON := preload("res://assets/sprites/story/icon_talk.png")
const DEFAULT_HERO := "ROLE_KEREY"
## Шевроны на земле: сколько, через сколько и с какого расстояния от игрока.
const CHEVRONS := 3
const CHEVRON_STEP := 52.0
const CHEVRON_START := 72.0
const CART_RADIUS := 2.8 * StoryLayout.METER
const FINALE_DELAY := 1.2

var state: StoryState
var location := StoryBeat.Location.AUL
var hero: StoryHero
## Кто сейчас говорит, играет мини-игру или делает задание — к другим жителям
## не подойти.
var busy := false
## Задание в мире (сбор, стройка...) идёт: ходить можно, говорить — нет.
var task: StoryTaskRunner
## Автопилот (tools/story_world_test.gd): асық, жекпе-жек и соқыр теке
## засчитываются сразу, как клавиша ведущего в atilla; бәйге — без отсчёта.
var autopilot := false

var _cast: StoryCast
var _npcs := {}
var _people: Array[StoryPerson] = []
var _player: Player
var _cart: Node2D
var _marker: Sprite2D
var _chevrons: Array[Sprite2D] = []
var _prompt: Label
var _time := 0.0

@onready var _ground: Node2D = $Ground
@onready var _world: Node2D = $World
@onready var _camera: GameCamera = $Camera
@onready var _hud: StoryHud = %Hud
@onready var _dialogue: DialogueBox = %Dialogue
@onready var _overlay: Control = %Overlay
@onready var _touch: TouchControls = $TouchControls


func _ready() -> void:
	_cast = AssetRegistry.get_story_cast()
	for npc in _cast.npcs:
		_npcs[npc.id] = npc
	var hero_id: String = SaveManager.story.get("hero", DEFAULT_HERO)
	for candidate in _cast.heroes:
		if candidate.id == hero_id:
			hero = candidate
	state = StoryState.new(AssetRegistry.get_story_chapter(hero.chapter), SaveManager.story)
	_hud.set_chapter(state.chapter.title)
	_hud.pause_requested.connect(_open_pause)
	_dialogue.chose.connect(_on_choice)
	_touch.set_tap_action(TALK_ICON)
	_touch.action_tapped.connect(interact)
	_build_pause()

	var beat := state.current_beat()
	location = beat.location if beat != null else StoryBeat.Location.AUL
	_build_location()
	_refresh()

	var result := SceneRouter.take_story_result()
	if state.is_complete():
		_show_finale()
	elif result.has("won"):
		_resume_after_minigame(bool(result["won"]))
	else:
		_show_title_card()


# --- Место -------------------------------------------------------------------

func _build_location() -> void:
	for node in _ground.get_children() + _world.get_children():
		node.queue_free()
	_people.clear()
	StoryLayout.build_ground(_ground, location)
	StoryLayout.build_props(_world, location)
	_cart = _find_cart()
	for placement in state.chapter.placements:
		if placement.location == location:
			_add_person(placement)
	# Союзники стоят в каждом месте главы — в atilla они пропадали после переезда.
	if state.allies_joined():
		for placement in state.chapter.allies:
			_add_person(placement)

	_player = PLAYER_SCENE.instantiate()
	_player.position = StoryLayout.to_world(StoryLayout.SPAWN[location])
	_world.add_child(_player)
	StoryLooks.dress(_player.get_node("CharacterVisual"), hero.look)
	_player.set_name_label_visible(false)
	_camera.set_target(_player)
	_camera.global_position = _player.position
	_touch.player = _player
	var half: Vector2 = StoryLayout.HALF_SIZE[location] * StoryLayout.METER
	_camera.limit_left = int(-half.x - 160)
	_camera.limit_right = int(half.x + 160)
	_camera.limit_top = int(-half.y - 160)
	_camera.limit_bottom = int(half.y + 160)

	_marker = Sprite2D.new()
	_marker.texture = MARKER
	_marker.z_index = WorldLayers.EFFECTS
	_world.get_parent().add_child.call_deferred(_marker)
	for i in CHEVRONS:
		var chevron := Sprite2D.new()
		chevron.texture = CHEVRON
		chevron.z_index = WorldLayers.FOOTPRINTS
		_world.get_parent().add_child.call_deferred(chevron)
		_chevrons.append(chevron)
	_prompt = Label.new()
	_prompt.theme_type_variation = "NameTagLabel"
	_prompt.z_index = WorldLayers.EFFECTS
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world.get_parent().add_child.call_deferred(_prompt)


func _add_person(placement: StoryPlacement) -> void:
	var npc: StoryNpc = _npcs.get(placement.npc, null)
	var look := npc.look if npc != null else placement.look
	var person := StoryPerson.create(look, placement.npc, npc.name if npc != null else "", placement.facing)
	person.position = StoryLayout.to_world(placement.position)
	_world.add_child(person)
	_people.append(person)


func _find_cart() -> Node2D:
	var target := StoryLayout.to_world(StoryLayout.CART[location])
	for node in _world.get_children():
		if node is Node2D and node.position == target:
			return node
	return null


# --- Цель, маркер, подсказка ----------------------------------------------------

## Куда идти сейчас: к жителю шага, к арбе, к цели задания. Нет цели — null.
func target_point() -> Variant:
	if task != null:
		return task.target_point()
	var beat := state.current_beat()
	if beat == null or busy:
		return null
	if state.needs_travel(location):
		return _cart.position if _cart != null else null
	var person := person_for(beat.npc)
	return person.position if person != null else null


func person_for(npc_id: String) -> StoryPerson:
	for person in _people:
		if person.npc_id == npc_id:
			return person
	return null


func _process(delta: float) -> void:
	_time += delta
	if _player == null or not is_instance_valid(_marker):
		return
	var target: Variant = target_point()
	_marker.visible = target != null
	if target != null:
		var bob := roundf(absf(sin(_time * 3.0)) * 4.0) * UiTokens.PIXEL
		_marker.position = (target as Vector2) + Vector2(0, -96 - bob)
	_place_chevrons(target)
	_update_prompt()
	for person in _people:
		person.look_at_point(_player.position, person.position.distance_to(_player.position) < StoryPerson.TALK_RADIUS)


## Шевроны от игрока к цели; повёрнуты на четверть оборота — пиксель-арт не
## поворачивают на произвольный угол.
func _place_chevrons(target: Variant) -> void:
	var show := target != null and _player.position.distance_to(target) > CHEVRON_START + CHEVRON_STEP * CHEVRONS
	for i in _chevrons.size():
		var chevron := _chevrons[i]
		chevron.visible = show
		if not show:
			continue
		var direction: Vector2 = (target - _player.position).normalized()
		var at := _player.position + direction * (CHEVRON_START + CHEVRON_STEP * i)
		chevron.position = (at / UiTokens.PIXEL).round() * UiTokens.PIXEL
		var quarter := roundi(direction.angle() / (PI / 2.0))
		chevron.rotation = quarter * PI / 2.0 + PI / 2.0
		# Бегущая волна: шевроны загораются по очереди от игрока к цели.
		chevron.visible = int(_time * 4.0) % (CHEVRONS + 1) >= i


## «E · Би» над тем, с кем можно заговорить сейчас.
func _update_prompt() -> void:
	var near := nearest_talkable()
	_prompt.visible = near != null and not busy and not _dialogue.is_open()
	if not _prompt.visible:
		return
	if near == _cart:
		_prompt.text = tr("E · ЖОЛҒА ШЫҒУ")
	else:
		_prompt.text = "E · " + tr((near as StoryPerson).display_name)
	_prompt.reset_size()
	_prompt.position = (near as Node2D).position + Vector2(-_prompt.size.x / 2, -132)


## Ближайший житель в пределах разговора или арба, если пора ехать.
func nearest_talkable() -> Node2D:
	if _player == null:
		return null
	if _cart != null and state.needs_travel(location) and _player.position.distance_to(_cart.position) < CART_RADIUS:
		return _cart
	var best: StoryPerson = null
	var best_distance := StoryPerson.TALK_RADIUS
	for person in _people:
		var distance := person.position.distance_to(_player.position)
		if person.can_talk() and distance < best_distance:
			best = person
			best_distance = distance
	return best


# --- Разговоры и шаги ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()


func interact() -> void:
	if busy or task != null or _dialogue.is_open():
		return
	var near := nearest_talkable()
	if near == null:
		return
	if near == _cart:
		travel()
		return
	var person := near as StoryPerson
	var beat := state.current_beat()
	if beat != null and person.npc_id == beat.npc and not state.needs_travel(location):
		speak(state.dialogue(beat.dialogue), _run_action.bind(beat))
		return
	var npc: StoryNpc = _npcs.get(person.npc_id, null)
	if npc == null:
		return
	var idle := StoryDialogue.new()
	idle.speaker = npc.name
	idle.look = npc.look
	idle.lines = [state.idle_line(npc)]
	SaveManager.save_story()
	speak(idle, Callable())


var _after_dialogue := Callable()


func speak(dialogue: StoryDialogue, done: Callable) -> void:
	if dialogue == null:
		if done.is_valid():
			done.call()
		return
	busy = true
	_after_dialogue = done
	_player.set_frozen(true)
	if not _dialogue.finished.is_connected(_on_dialogue_finished):
		_dialogue.finished.connect(_on_dialogue_finished)
	_dialogue.show_dialogue(dialogue)


func _on_choice(choice: StoryChoice) -> void:
	state.apply_choice(choice)
	SaveManager.save_story()
	_refresh()
	var reply := state.dialogue(choice.next_dialogue)
	if reply == null:
		_on_dialogue_finished()
		return
	_dialogue.show_dialogue(reply)


func _on_dialogue_finished() -> void:
	busy = false
	_player.set_frozen(false)
	var done := _after_dialogue
	_after_dialogue = Callable()
	if done.is_valid():
		done.call()


func _run_action(beat: StoryBeat) -> void:
	if autopilot and beat.action in [StoryBeat.Action.SOKYR_TEKE, StoryBeat.Action.ASYK, StoryBeat.Action.DUEL]:
		complete_beat()
		return
	match beat.action:
		StoryBeat.Action.COLLECT, StoryBeat.Action.BUILD, StoryBeat.Action.ESCORT, StoryBeat.Action.FIND, \
		StoryBeat.Action.BAIGE:
			task = StoryTaskRunner.create(beat.action, beat.task)
			task.finished.connect(_on_task_finished.bind(beat))
			task.failed.connect(_on_task_failed.bind(beat))
			_world.get_parent().add_child(task)
			task.begin(self, _player, _world)
		StoryBeat.Action.SOKYR_TEKE:
			SaveManager.save_story()
			SceneRouter.go_to_game({"role": Roles.Role.SOKYROTEKE, "bots": 3, "story": true})
		StoryBeat.Action.ASYK:
			_open_overlay(StoryOverlays.asyk(), beat)
		StoryBeat.Action.DUEL:
			_open_overlay(StoryOverlays.duel(hero, state.duel_has_ally()), beat)
		StoryBeat.Action.CAMPFIRE:
			_open_overlay(StoryOverlays.campfire(self, beat), beat)
		StoryBeat.Action.MAP:
			_open_overlay(StoryOverlays.route_map(beat.route_title, beat.route_goal, beat.route_start,
				beat.route_end, beat.route), beat)
		_:
			complete_beat()


func _on_task_finished(_beat: StoryBeat) -> void:
	task = null
	_hud.hide_task()
	complete_beat()


func _on_task_failed(beat: StoryBeat) -> void:
	task = null
	_hud.hide_task()
	_offer_retry(beat)


## Оверлей на весь экран (костёр, карта, мини-игра): мир стоит, пока он открыт.
func _open_overlay(overlay: Control, beat: StoryBeat) -> void:
	busy = true
	_player.set_frozen(true)
	_hud.visible = false
	_overlay.add_child(overlay)
	overlay.tree_exited.connect(func() -> void:
		busy = false
		_player.set_frozen(false)
		_hud.visible = true)
	if overlay.has_signal("won"):
		overlay.connect("won", complete_beat)
	if overlay.has_signal("lost"):
		overlay.connect("lost", _offer_retry.bind(beat))
	if overlay.has_signal("done"):
		overlay.connect("done", complete_beat)


func complete_beat() -> void:
	var result := state.complete_beat()
	SaveManager.save_story()
	var parts: PackedStringArray = []
	if int(result["xp"]) > 0:
		parts.append("+%d XP" % int(result["xp"]))
	for entry_id: String in result["unlocked"]:
		parts.append(tr("ЭНЦИКЛОПЕДИЯ: %s") % tr(_entry_title(entry_id)))
	if not parts.is_empty():
		_hud.toast("   ·   ".join(parts))
	_refresh()
	if state.is_complete():
		await get_tree().create_timer(FINALE_DELAY, false).timeout
		if is_inside_tree():
			_show_finale()


func _entry_title(entry_id: String) -> String:
	for entry in _cast.entries:
		if entry.id == entry_id:
			return entry.title
	return entry_id


## Вернулись из соқыр теке: победа закрывает шаг, поражение — повтор.
func _resume_after_minigame(won: bool) -> void:
	var beat := state.current_beat()
	if beat == null or beat.action != StoryBeat.Action.SOKYR_TEKE:
		return
	if won:
		complete_beat()
	else:
		_offer_retry(beat)


func _offer_retry(beat: StoryBeat) -> void:
	var dialog := ConfirmDialog.new()
	dialog.dialog_title = tr("ТАҒЫ БІР РЕТ?")
	dialog.dialog_message = tr("Бұл жолы болмады. Қайталайсың ба, әлде кейінірек пе?")
	dialog.confirm_text = tr("ҚАЙТАЛАУ")
	dialog.cancel_text = tr("КЕЙІНІРЕК")
	dialog.focus_confirm = true
	_overlay.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_run_action(beat))
	dialog.cancelled.connect(dialog.queue_free)
	dialog.open()


func _refresh() -> void:
	var beat := state.current_beat()
	var objective := tr("Тарау аяқталды")
	if beat != null:
		objective = tr("Жолға шық: %s") % tr(StoryLayout.NAMES[beat.location]) if state.needs_travel(location) \
			else tr(beat.objective)
	_hud.set_objective(objective, state.beat_index(), state.beat_count())
	_hud.set_xp(state.total_xp())


# --- Переезд -------------------------------------------------------------------------

## Где место на карте — по маршруту главы: аул в начале пути, степь посреди,
## город в конце. В atilla аул всегда стоял у Сарыарқи, даже в главе о Сырдарье.
func map_point(where: StoryBeat.Location) -> Vector2:
	var route := state.chapter.beats[state.chapter.beats.size() - 1].route
	match where:
		StoryBeat.Location.AUL:
			return route[0]
		StoryBeat.Location.STEPPE:
			return route[route.size() / 2]
		_:
			return route[route.size() - 1]

func travel() -> void:
	var beat := state.current_beat()
	if beat == null or not state.needs_travel(location):
		return
	var here := map_point(location)
	var there := map_point(beat.location)
	var route: PackedVector2Array = [here, (here + there) / 2.0 + Vector2(0.02, 0), there]
	var map := StoryOverlays.route_map(tr("ЖОЛҒА ШЫҒУ"), tr(StoryLayout.NAMES[beat.location]),
		StoryLayout.NAMES[location], StoryLayout.NAMES[beat.location], route)
	busy = true
	_player.set_frozen(true)
	_hud.visible = false
	_overlay.add_child(map)
	map.connect("done", func() -> void:
		location = beat.location
		_build_location()
		busy = false
		_hud.visible = true
		_refresh()
		_hud.toast(tr(StoryLayout.NAMES[location])))


# --- Заставка, финал, пауза ------------------------------------------------------

func _show_title_card() -> void:
	busy = true
	_player.set_frozen(true)
	_hud.visible = false
	var card := StoryOverlays.title_card(state.chapter, state.beat_index() == 0)
	_overlay.add_child(card)
	card.connect("done", func() -> void:
		busy = false
		_player.set_frozen(false)
		_hud.visible = true)


func _show_finale() -> void:
	busy = true
	if _player != null:
		_player.set_frozen(true)
	_hud.visible = false
	var finale := StoryOverlays.finale(state, _cast)
	_overlay.add_child(finale)


var _pause: PauseMenu


func _build_pause() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause = PauseMenu.new()
	_pause.main_menu_requested.connect(SceneRouter.go_to_main_menu)
	layer.add_child(_pause)


func _open_pause() -> void:
	_pause.open()
