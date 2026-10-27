extends "res://tools/test_case.gd"
## Свойства одежды в игре: тымақ сокращает замедление на 30%, шапан делает
## бегуна менее заметным (×0,82), саптама етік ускоряет на суше на 8%, в воде — нет.
## Остальные вещи — сәндік, без эффекта.


func _init() -> void:
	await process_frame
	var registry := autoload("AssetRegistry")
	var player = await mount("res://scenes/entities/player.tscn")
	if player == null:
		finish("CLOTHING EFFECTS")
		return

	player.call("_set_outfit_item", ClothingItem.SlotType.HEAD, registry.get_clothing_by_id("head_borik_01"))
	player.call("_set_outfit_item", ClothingItem.SlotType.TORSO, registry.get_clothing_by_id("torso_koylek_01"))
	player.call("_set_outfit_item", ClothingItem.SlotType.SHOES, registry.get_clothing_by_id("shoes_kebis_01"))
	player.slow_timer = 0.0
	player.apply_slow(10.0)
	check(is_equal_approx(player.slow_timer, 10.0), "без тымақ замедление полное, получено %.2f" % player.slow_timer)
	check(is_equal_approx(player.get_visibility_multiplier(), 1.0), "без шапан заметность обычная")
	check(is_equal_approx(player.get_clothing_speed_mult(), 1.0), "без саптама етік скорость обычная")

	player.call("_set_outfit_item", ClothingItem.SlotType.HEAD, registry.get_clothing_by_id("head_tymaq_01"))
	player.call("_set_outfit_item", ClothingItem.SlotType.TORSO, registry.get_clothing_by_id("torso_shapan_01"))
	player.call("_set_outfit_item", ClothingItem.SlotType.SHOES, registry.get_clothing_by_id("shoes_saptama_etik_01"))
	player.slow_timer = 0.0
	player.apply_slow(10.0)
	check(is_equal_approx(player.slow_timer, 7.0), "тымақ: замедление 7 с из 10, получено %.2f" % player.slow_timer)
	check(is_equal_approx(player.get_visibility_multiplier(), 0.82), "шапан: заметность ×0,82")
	check(is_equal_approx(player.get_clothing_speed_mult(), 1.08), "саптама етік: скорость на суше ×1,08")
	player.set_water_override(true)
	check(is_equal_approx(player.get_clothing_speed_mult(), 1.0), "саптама етік: в воде без ускорения")
	await unmount(player)
	finish("CLOTHING EFFECTS")
