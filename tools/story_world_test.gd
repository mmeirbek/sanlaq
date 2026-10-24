extends "res://tools/test_case.gd"
## Автопилот «Тарих жолы»: проходит главу целиком через настоящий мир, как
## игрок, — подходит к цели маркера, говорит, выбирает второй вариант (бірлік),
## делает задания и скачет в бәйге, слушает костёр, едет на арбе. Асық, жекпе-жек
## и соқыр теке автопилот засчитывает сразу (их правила — в story_games_test).
## Отдельно — бәйге: проигрыш по времени, соперник сам доезжает до мәре, победа.

const WORLD := "res://scenes/story/story_world.tscn"
const MAX_STEPS := 3000


func _init() -> void:
	await process_frame
	for hero in ["ROLE_KEREY", "ROLE_KABANBAY"]:
		await _walk_chapter(hero)
	await _race_baige()
	finish("STORY WORLD")


func _walk_chapter(hero: String) -> void:
	var save_manager := autoload("SaveManager")
	save_manager.story = {"hero": hero}
	var world := await mount(WORLD)
	if world == null:
		return
	world.autopilot = true
	var state: StoryState = world.state
	var travelled := false
	var heard_campfire := false
	var built_yurt := false
	var steps := 0
	while not state.is_complete() and steps < MAX_STEPS:
		steps += 1
		await process_frame
		var overlay: Control = world.get_node("%Overlay")
		var dialogue = world.get_node("%Dialogue")
		if dialogue.is_open():
			var choices: Array = dialogue._dialogue.choices
			if dialogue._choices_box.get_child_count() > 0:
				dialogue._choose(choices.size() - 1)
			else:
				dialogue.advance()
			continue
		if overlay.get_child_count() > 0:
			var top: Control = overlay.get_child(overlay.get_child_count() - 1)
			if top.has_method("_ask"):
				heard_campfire = true
				var next_topic = null
				for topic in top.beat.topics:
					if not top._heard.has(topic.label):
						next_topic = topic
						break
				if next_topic != null and top.visible:
					top._ask(next_topic)
				elif next_topic == null:
					top._close()
			elif top.has_method("_close"):
				if top.get("route") != null and state.needs_travel(world.location):
					travelled = true
				top._close()
			continue
		var target = world.target_point()
		if world.task != null:
			var kind: String = world.task.get_script().resource_path.get_file()
			if kind == "build_task.gd":
				built_yurt = true
			# Поиск следа идёт без стрелок — автопилот знает, где след.
			if kind == "find_task.gd":
				target = StoryLayout.to_world(world.task.task.points[0])
			if target != null:
				world._player.position = target + Vector2(4, 4)
			continue
		if target == null or world.busy:
			continue
		world._player.position = target + Vector2(0, 40)
		await process_frame
		world.interact()
	check(state.is_complete(), "%s: глава пройдена автопилотом за %d шагов" % [hero, steps])
	check(state.chapter_xp() > 0 and state.unity() > 0,
		"%s: XP %d и бірлік %d набраны" % [hero, state.chapter_xp(), state.unity()])
	check(travelled, "%s: был переезд на арбе" % hero)
	check(heard_campfire, "%s: у костра выслушаны темы" % hero)
	if hero == "ROLE_KEREY":
		check(built_yurt, "Керей: киіз үй построен")
		check(state.is_unlocked("kiiz_ui") and state.is_unlocked("zhetysu"), "Керей: статьи шагов и костра открыты")
	await create_timer(1.6).timeout
	var finale: Control = world.get_node("%Overlay").get_child(world.get_node("%Overlay").get_child_count() - 1)
	check(finale.get("state") != null, "%s: показан финал главы" % hero)
	await unmount(world)


## Бәйге Абылая (шаг 5 главы, в ауле) на настоящем мире.
func _race_baige() -> void:
	var save_manager := autoload("SaveManager")
	save_manager.story = {"hero": "ROLE_ABYLAI", "heroes": {"ROLE_ABYLAI": {"beat": 4}}}
	var world := await mount(WORLD)
	if world == null:
		return
	world.autopilot = true
	for card in world.get_node("%Overlay").get_children():
		card.queue_free()
	var state: StoryState = world.state
	var beat := state.current_beat()
	check(beat.action == StoryBeat.Action.BAIGE, "Абылай: шаг 5 — бәйге")
	var spot: Vector2 = world._player.position

	# Время вышло — проигрыш, конь и скорость снимаются, мир предлагает повтор.
	world._run_action(beat)
	var race = world.task
	check(race != null and race.racing, "бәйге началась (автопилот — без отсчёта)")
	check(world._player.speed_mult > 1.0, "игрок верхом быстрее")
	race._left = 0.0
	await physics_frame
	await process_frame
	check(world.task == null and state.current_beat() == beat, "время вышло — шаг не засчитан")
	check(is_equal_approx(world._player.speed_mult, 1.0) and world._player.position == spot,
		"после бәйге игрок пеший и там, где был")
	var retry := world.get_node("%Overlay").get_child(world.get_node("%Overlay").get_child_count() - 1)
	check(retry is ConfirmDialog, "после проигрыша — предложение повторить")
	retry.queue_free()

	# Игрок стоит — соперник сам объезжает аул и берёт мәре до конца времени.
	world._run_action(beat)
	race = world.task
	await physics_frame
	var lost := [false]
	race.failed.connect(func() -> void: lost[0] = true)
	var seconds := 0.0
	while not lost[0] and seconds < race.TIME_LIMIT:
		race._move_rival(1.0 / 60.0)
		seconds += 1.0 / 60.0
	check(lost[0], "соперник доехал до мәре сам (%.0f с), не застрял у юрт" % seconds)
	check(seconds > 12.0, "соперник не мгновенный: %.0f с" % seconds)
	await process_frame
	for node in world.get_node("%Overlay").get_children():
		node.queue_free()

	# Победа: пять флажков по порядку — шаг засчитан.
	world._run_action(beat)
	race = world.task
	var taken := 0
	while world.task != null and taken < 10:
		world._player.position = world.target_point()
		await physics_frame
		await process_frame
		taken += 1
	check(state.current_beat() != beat and taken == beat.task.points.size(),
		"пять флажков по порядку — бәйге выиграна за %d" % taken)
	await unmount(world)
