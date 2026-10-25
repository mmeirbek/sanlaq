class_name DuelRules
extends RefCounted
## Правила «Жекпе-жек» (как в atilla): пошаговый бой, 140 сил у героя против
## 110 у вражеского батыра. Ходы: ШАБУЫЛ, ҚОРҒАНУ, АЙЛА, ШИПА, КӨМЕК
## (жасақтас, если бірлік хватает). Враг иногда замахивается — следующий его
## удар тяжёлый, и тогда нужно защищаться.
##
## Урон врага сильнее, чем в atilla: там бой был прогулкой — даже тот, кто только
## бил, выигрывал всегда, и замах ничего не значил. Теперь тяжёлый удар снимает
## больше половины сил: кто защищается на замахе, выигрывает почти всегда, кто
## только бьёт — примерно в половине боёв (tools/story_games_test.gd).

enum Move { ATTACK, GUARD, FEINT, REMEDY, ALLY }

const HERO_HEALTH := 140
const ENEMY_HEALTH := 110
const ATTACK_MIN := 18
const ATTACK_MAX := 28
const FEINT_DAMAGE := 35
const FEINT_CHANCE := 0.6
const FEINT_COOLDOWN := 2
const REMEDY_HEAL := 34
const REMEDIES := 1
const ALLY_DAMAGE := 40
const ENEMY_MIN := 24
const ENEMY_MAX := 34
const HEAVY_DAMAGE := 80
const HEAVY_GUARDED := 12
const WIND_UP_CHANCE := 0.4
const ALLY_BLOCK_CHANCE := 0.3

var hero := HERO_HEALTH
var enemy := ENEMY_HEALTH
var has_ally := false
var ally_ready := false
var remedies := REMEDIES
var feint_cooldown := 0
## Враг замахнулся: его следующий удар — тяжёлый.
var winding_up := false
var rng := RandomNumberGenerator.new()


func _init(with_ally := false, seed_value := -1) -> void:
	has_ally = with_ally
	ally_ready = with_ally
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func can_use(move: Move) -> bool:
	match move:
		Move.FEINT:
			return feint_cooldown <= 0
		Move.REMEDY:
			return remedies > 0
		Move.ALLY:
			return ally_ready
	return true


## Ход героя и ответ врага. Возвращает разбор для экрана:
##   hero_damage, enemy_damage — кто сколько получил;
##   feint_ok, heavy, blocked — что случилось; over, won — итог.
func play(move: Move) -> Dictionary:
	var out := {"move": move, "enemy_damage": 0, "hero_damage": 0, "feint_ok": false, "heavy": false,
		"blocked": false, "healed": 0, "over": false, "won": false}
	if not can_use(move) or is_over():
		return out
	var guarding := false
	match move:
		Move.ATTACK:
			out["enemy_damage"] = rng.randi_range(ATTACK_MIN, ATTACK_MAX)
		Move.GUARD:
			guarding = true
		Move.FEINT:
			feint_cooldown = FEINT_COOLDOWN
			if rng.randf() < FEINT_CHANCE:
				out["enemy_damage"] = FEINT_DAMAGE
				out["feint_ok"] = true
		Move.REMEDY:
			remedies -= 1
			out["healed"] = mini(REMEDY_HEAL, HERO_HEALTH - hero)
			hero += out["healed"]
		Move.ALLY:
			ally_ready = false
			out["enemy_damage"] = ALLY_DAMAGE
	enemy -= out["enemy_damage"]
	if enemy > 0:
		_enemy_turn(guarding, out)
	feint_cooldown = maxi(0, feint_cooldown - 1)
	out["over"] = is_over()
	out["won"] = is_won()
	return out


func _enemy_turn(guarding: bool, out: Dictionary) -> void:
	if winding_up:
		winding_up = false
		out["heavy"] = true
		out["hero_damage"] = HEAVY_GUARDED if guarding else HEAVY_DAMAGE
	elif rng.randf() < WIND_UP_CHANCE:
		winding_up = true
	else:
		var damage := rng.randi_range(ENEMY_MIN, ENEMY_MAX)
		if guarding:
			damage /= 2
		if has_ally and rng.randf() < ALLY_BLOCK_CHANCE:
			damage /= 2
			out["blocked"] = true
		out["hero_damage"] = damage
	hero -= out["hero_damage"]


func is_won() -> bool:
	return enemy <= 0


func is_over() -> bool:
	return enemy <= 0 or hero <= 0
