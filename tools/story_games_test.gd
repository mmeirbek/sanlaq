extends "res://tools/test_case.gd"
## Правила мини-игр «Тарих жолы»: асық ату и жекпе-жек (scripts/story/games).


func _init() -> void:
	_check_asyk()
	_check_duel_moves()
	_check_duel_balance()
	finish("STORY GAMES")


func _check_asyk() -> void:
	check(AsykRules.aim_ok(0.0) and AsykRules.aim_ok(0.1) and not AsykRules.aim_ok(0.11), "асық: зона направления ±0,1")
	check(AsykRules.power_ok(1.0) and AsykRules.power_ok(0.78) and not AsykRules.power_ok(0.7), "асық: сила — верхние 22%")
	var rules := AsykRules.new()
	var speed := rules.aim_speed()
	check(rules.throw(0.0, 1.0), "асық: центр и полная сила — попадание")
	check(rules.aim_speed() > speed, "асық: с каждым броском бегунок быстрее")
	check(not rules.throw(0.5, 1.0) and not rules.throw(0.0, 0.3), "асық: мимо направления или слабо — промах")
	check(not rules.is_over(), "асық: после 1 из 3 за 3 броска ещё можно выиграть")
	rules.throw(0.9, 0.0)
	check(rules.is_over() and not rules.is_won(), "асық: 1 попадание и 1 бросок — уже не набрать 3")
	var winner := AsykRules.new()
	for i in 3:
		winner.throw(0.05, 0.9)
	check(winner.is_won() and winner.is_over() and winner.thrown == 3, "асық: 3 попадания — победа досрочно")
	var bounced: Array = AsykRules.swing(0.99, 1, 1.0, 0.1, -1.0, 1.0)
	check(bounced[0] == 1.0 and bounced[1] == -1, "асық: бегунок отскакивает от края")


func _check_duel_moves() -> void:
	var duel := DuelRules.new(false, 1)
	check(duel.hero == 140 and duel.enemy == 110, "жекпе-жек: 140 против 110")
	check(not duel.can_use(DuelRules.Move.ALLY), "жекпе-жек: без бірлік жасақтас не помогает")
	var attack := duel.play(DuelRules.Move.ATTACK)
	check(attack["enemy_damage"] >= 18 and attack["enemy_damage"] <= 28,
		"жекпе-жек: удар 18–28, получено %d" % attack["enemy_damage"])
	duel.hero = 100
	var heal := duel.play(DuelRules.Move.REMEDY)
	check(heal["healed"] == 34 and not duel.can_use(DuelRules.Move.REMEDY), "жекпе-жек: шипа +34 один раз")
	duel.feint_cooldown = 0
	duel.play(DuelRules.Move.FEINT)
	check(not duel.can_use(DuelRules.Move.FEINT), "жекпе-жек: после айлы — ход перерыва")
	duel.play(DuelRules.Move.GUARD)
	check(duel.can_use(DuelRules.Move.FEINT), "жекпе-жек: через ход айла снова доступна")

	# Замах врага: тяжёлый удар 34, в защите — 16.
	var heavy := DuelRules.new(false, 2)
	heavy.winding_up = true
	var open_hit := heavy.play(DuelRules.Move.ATTACK)
	heavy.winding_up = true
	var guarded := heavy.play(DuelRules.Move.GUARD)
	check(open_hit["heavy"] and open_hit["hero_damage"] == DuelRules.HEAVY_DAMAGE, "жекпе-жек: тяжёлый удар")
	check(guarded["heavy"] and guarded["hero_damage"] == DuelRules.HEAVY_GUARDED, "жекпе-жек: в защите — малая доля")

	var with_ally := DuelRules.new(true, 3)
	var ally := with_ally.play(DuelRules.Move.ALLY)
	check(ally["enemy_damage"] == 40 and not with_ally.can_use(DuelRules.Move.ALLY),
		"жекпе-жек: жасақтас бьёт 40 один раз")
	var finisher := DuelRules.new(false, 4)
	finisher.enemy = 10
	var last := finisher.play(DuelRules.Move.ATTACK)
	check(last["won"] and last["hero_damage"] == 0, "жекпе-жек: поверженный враг не отвечает")


## Новичок, который читает замах, выигрывает почти всегда; кто только бьёт — нет.
func _check_duel_balance() -> void:
	var careful := 0
	var reckless := 0
	for seed_value in 400:
		var duel := DuelRules.new(false, seed_value)
		while not duel.is_over():
			var move := DuelRules.Move.ATTACK
			if duel.winding_up:
				move = DuelRules.Move.GUARD
			elif duel.hero < 50 and duel.can_use(DuelRules.Move.REMEDY):
				move = DuelRules.Move.REMEDY
			duel.play(move)
		careful += 1 if duel.is_won() else 0
		var brute := DuelRules.new(false, seed_value)
		while not brute.is_over():
			brute.play(DuelRules.Move.ATTACK)
		reckless += 1 if brute.is_won() else 0
	check(careful > 380, "жекпе-жек: кто читает замах, выигрывает %d из 400" % careful)
	check(reckless > 120 and reckless < 300,
		"жекпе-жек: кто только бьёт, выигрывает %d из 400 — шанс есть, но не всегда" % reckless)
