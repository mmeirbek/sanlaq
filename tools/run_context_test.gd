extends "res://tools/test_case.gd"
## Инструменты из tools/ запускаются как `godot --script ...` — и тесты, и
## скриншоты в окне. Такой запуск не трогает сохранение игрока и не шлёт
## телеметрию: раньше скриншоты читали настоящий профиль и слали события на сервер.


func _init() -> void:
	await process_frame
	check(RunContext.is_tool_script(), "запуск через --script распознан как инструмент")
	check(RunContext.is_automated(), "инструмент — запуск без живого игрока")
	check(not autoload("Telemetry").get("_enabled"), "телеметрия выключена")
	finish("RUN_CONTEXT")
