extends "res://tools/test_case.gd"
## Поимка, квиз и замедление ловца в MatchManager.

var game: Node2D
var mm: Node

func _init() -> void:
	await process_frame
	await process_frame
	var pack := load("res://scenes/world/game.tscn")
	game = pack.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame

	mm = game.match_mgr
	check(mm.players.size() == 6, "6 players spawned, got %d" % mm.players.size())

	var human = mm.human_player
	mm.sokyroteke = human
	human.set_as_sokyroteke(true)
	for p in mm.players:
		if p != human:
			p.set_as_sokyroteke(false)
	mm.current_state = mm.MatchState.PLAYING
	mm.runners_total = mm.players.size() - 1
	mm.eliminated_count = 0

	var target = null
	for p in mm.players:
		if p != human and not p.eliminated:
			target = p
			break
	mm._trigger_quiz(target)
	await process_frame
	mm.submit_quiz_answer(true)
	await process_frame
	check(target.eliminated, "target eliminated after correct answer")
	check(mm.eliminated_count == 1, "eliminated_count==1, got %d" % mm.eliminated_count)

	var target2 = null
	for p in mm.players:
		if p != human and not p.eliminated:
			target2 = p
			break
	mm._last_target = target2
	mm._trigger_quiz(target2)
	await process_frame
	mm.submit_quiz_answer(false)
	await process_frame
	check(human.is_slowed(), "sokyroteke slowed after wrong answer")
	check(not target2.eliminated, "runner NOT eliminated on wrong answer")
	check(mm.eliminated_count == 1, "eliminated_count still 1, got %d" % mm.eliminated_count)

	var before: int = mm.eliminated_count
	mm.on_player_touches_sokyroteke(target2)
	await process_frame
	await process_frame
	check(mm.eliminated_count == before, "catch blocked while sokyroteke slowed")

	game.queue_free()
	finish("MECHANICS")
