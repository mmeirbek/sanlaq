extends "res://tools/test_case.gd"
## Автопилот «Тарих жолы»: проходит главу целиком через настоящий мир, как
## игрок, — подходит к цели маркера, говорит, выбирает второй вариант (бірлік),
## делает задания, слушает костёр, едет на арбе. Мини-игры автопилот засчитывает
## сразу (их правила проверяют свои тесты).

const WORLD := "res://scenes/story/story_world.tscn"
const MAX_STEPS := 3000


func _init() -> void:
	await process_frame
	for hero in ["ROLE_KEREY"]:
		await _walk_chapter(hero)
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
			if world.task.get_script().resource_path.ends_with("build_task.gd"):
				built_yurt = true
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
