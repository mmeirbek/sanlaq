extends "res://tools/test_case.gd"
## Ядро «Тарих жолы» (scripts/story/story_state.gd) на настоящих главах из data/story:
## шаги по очереди, бірлік и выборы, финал и союзники, XP и статьи, сохранение.

const CHAPTERS := ["kerey", "abylai", "kabanbay"]


func _init() -> void:
	var cast := load("res://data/story/cast.tres") as StoryCast
	var entry_ids := {}
	for entry in cast.entries:
		entry_ids[entry.id] = true
	var npc_ids := {}
	for npc in cast.npcs:
		npc_ids[npc.id] = true
	for hero in cast.heroes:
		check(ResourceLoader.exists("res://data/story/chapter_%s.tres" % hero.look),
			"у героя %s есть глава" % hero.id)

	for name: String in CHAPTERS:
		var chapter := load("res://data/story/chapter_%s.tres" % name) as StoryChapter
		_check_content(chapter, entry_ids, npc_ids)
		_check_walkthrough(chapter)
	_check_choices()
	_check_save_round_trip()
	finish("STORY RULES")


## Данные главы связаны: у шага есть свой диалог и житель, статьи существуют,
## у заданий есть точки, у костра — темы, у переезда — маршрут.
func _check_content(chapter: StoryChapter, entry_ids: Dictionary, npc_ids: Dictionary) -> void:
	var state := StoryState.new(chapter, {})
	check(chapter.beats.size() >= 6, "%s: шагов %d" % [chapter.id, chapter.beats.size()])
	for beat in chapter.beats:
		var where := "%s/%s" % [chapter.id, beat.checkpoint]
		check(state.dialogue(beat.dialogue) != null, "%s: диалог %s есть" % [where, beat.dialogue])
		check(npc_ids.has(beat.npc), "%s: житель %s есть" % [where, beat.npc])
		for entry_id in beat.unlock:
			check(entry_ids.has(entry_id), "%s: статья %s есть" % [where, entry_id])
		match beat.action:
			StoryBeat.Action.COLLECT, StoryBeat.Action.BUILD, StoryBeat.Action.ESCORT, \
			StoryBeat.Action.FIND, StoryBeat.Action.BAIGE:
				check(beat.task != null and beat.task.points.size() > 0, "%s: у задания есть точки" % where)
			StoryBeat.Action.CAMPFIRE:
				check(beat.topics.size() >= 3, "%s: у костра есть темы" % where)
				for topic in beat.topics:
					check(state.dialogue(topic.dialogue) != null, "%s: тема «%s» озвучена" % [where, topic.label])
			StoryBeat.Action.MAP:
				check(beat.route.size() >= 2, "%s: у переезда есть маршрут" % where)
		var spoken := state.dialogue(beat.dialogue)
		if spoken != null:
			for choice in spoken.choices:
				check(state.dialogue(choice.next_dialogue) != null, "%s: ответ %s есть" % [where, choice.next_dialogue])
	var last := chapter.beats[chapter.beats.size() - 1]
	check(last.action == StoryBeat.Action.MAP, "%s: глава кончается переездом" % chapter.id)


## Прохождение шаг за шагом: строго по очереди, XP копится, конец — один раз.
func _check_walkthrough(chapter: StoryChapter) -> void:
	var save := {}
	var state := StoryState.new(chapter, save)
	var expected_xp := 0
	var steps := 0
	while not state.is_complete():
		check(state.current_beat() == chapter.beats[steps], "%s: шаг %d по порядку" % [chapter.id, steps])
		expected_xp += state.current_beat().xp
		state.complete_beat()
		steps += 1
	check(steps == chapter.beats.size(), "%s: пройдено %d шагов из %d" % [chapter.id, steps, chapter.beats.size()])
	check(state.chapter_xp() == expected_xp and state.total_xp() == expected_xp,
		"%s: XP главы %d, получено %d" % [chapter.id, expected_xp, state.chapter_xp()])
	check(state.complete_beat()["xp"] == 0, "%s: после конца шагов нет" % chapter.id)
	state.restart()
	check(state.beat_index() == 0 and state.total_xp() == expected_xp,
		"%s: заново — с первого шага, XP остаётся" % chapter.id)


## Выбор в диалоге: бірлік меняет финал и союзников; не выше 100 и не ниже 0.
func _check_choices() -> void:
	var kerey := load("res://data/story/chapter_kerey.tres") as StoryChapter
	var bold := StoryState.new(kerey, {})
	var listen := StoryState.new(kerey, {})
	var council := bold.dialogue("DIA_K_BI")
	check(council.choices.size() == 2, "Керей: в совете два варианта")
	bold.apply_choice(council.choices[0])
	listen.apply_choice(council.choices[1])
	check(bold.has_flag("bold") and listen.has_flag("listen"), "выбор ставит свой флаг")
	check(bold.finale_text() == kerey.finale_text, "без бірлік — обычный финал")
	check(listen.finale_text() == kerey.finale_alt_text, "бірлік 20 — другой финал")
	check(not bold.allies_joined() and listen.allies_joined(), "союзники приходят только при бірлік")
	listen.add_unity(500)
	check(listen.unity() == StoryState.UNITY_MAX, "бірлік не выше 100")
	bold.add_unity(-500)
	check(bold.unity() == 0, "бірлік не ниже 0")

	var npc := StoryNpc.new()
	npc.id = "NPC_TEST"
	npc.idle_line = "Сәлем, балам."
	npc.again_line = "Иә?"
	check(bold.idle_line(npc) == npc.idle_line and bold.idle_line(npc) == npc.again_line,
		"житель здоровается один раз, дальше — коротко")


## Сохранение переживает JSON (числа становятся float), статьи не открываются дважды.
func _check_save_round_trip() -> void:
	var kerey := load("res://data/story/chapter_kerey.tres") as StoryChapter
	var save := {}
	var state := StoryState.new(kerey, save)
	state.complete_beat()
	state.apply_choice(state.dialogue("DIA_K_BI").choices[1])
	check(state.unlock_entry("kosh") and not state.unlock_entry("kosh"), "статья открывается один раз")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(save))
	var again := StoryState.new(kerey, restored)
	check(again.beat_index() == 1, "после загрузки — тот же шаг")
	check(again.unity() == state.unity() and again.has_flag("listen"), "после загрузки — те же бірлік и флаги")
	check(again.chapter_xp() == state.chapter_xp() and again.chapter_xp() > 0,
		"XP главы не пропадает после выхода из игры (баг atilla)")
	check(again.is_unlocked("kosh"), "открытая статья помнится")
	var abylai := load("res://data/story/chapter_abylai.tres") as StoryChapter
	var other := StoryState.new(abylai, restored)
	check(other.beat_index() == 0 and other.total_xp() == again.total_xp(),
		"у каждой главы свой ход, XP общий")
