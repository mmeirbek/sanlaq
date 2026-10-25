class_name AsykRules
extends RefCounted
## Правила «Асық ату» (как в atilla): 5 бросков, нужно выбить 3 асыка. Бросок —
## два нажатия: сначала направление (бегунок качается по шкале, попасть надо в
## середину), потом сила (полоса наполняется и спадает, нужен верх). С каждым
## броском бегунок быстрее.

const THROWS := 5
const NEEDED := 3
## Полуширина зелёной зоны направления на шкале -1..1.
const AIM_ZONE := 0.1
## Доля шкалы силы сверху, которая считается «сильно».
const POWER_BAND := 0.22
const AIM_SPEED := 0.95
const AIM_SPEED_PER_THROW := 0.15
const POWER_SPEED := 1.35

var thrown := 0
var hits := 0


static func aim_ok(aim: float) -> bool:
	return absf(aim) <= AIM_ZONE


static func power_ok(power: float) -> bool:
	return power >= 1.0 - POWER_BAND


func aim_speed() -> float:
	return AIM_SPEED + thrown * AIM_SPEED_PER_THROW


## Бросок: true — асык выбит.
func throw(aim: float, power: float) -> bool:
	if is_over():
		return false
	thrown += 1
	var hit := aim_ok(aim) and power_ok(power)
	if hit:
		hits += 1
	return hit


func is_won() -> bool:
	return hits >= NEEDED


## Кончено: выиграл или уже не успеть набрать нужное.
func is_over() -> bool:
	return is_won() or thrown >= THROWS or hits + (THROWS - thrown) < NEEDED


## Качание бегунка или полосы туда-обратно: value в пределах lo..hi, direction ±1.
static func swing(value: float, direction: int, speed: float, delta: float, lo: float, hi: float) -> Array:
	value += direction * speed * delta
	if value > hi:
		return [hi, -1]
	if value < lo:
		return [lo, 1]
	return [value, direction]
