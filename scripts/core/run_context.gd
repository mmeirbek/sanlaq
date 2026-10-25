class_name RunContext
## Как запущена игра.
##
## Без живого игрока игра запускается автотестами, CI (headless) и
## инструментами из tools/ — например, скриншотами, которые открывают окно.
## Такой запуск не трогает сохранение игрока и не шлёт телеметрию. Иначе прогон
## тестов портил бы профиль разработчика, а каждый прогон CI или скриншотов
## выглядел бы на сервере как новая станция.


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Автотест, CI или инструмент — живого игрока нет.
static func is_automated() -> bool:
	return is_headless() or is_tool_script()


## Инструменты запускаются как `godot --script res://tools/...`, в том числе в окне.
static func is_tool_script() -> bool:
	var args := OS.get_cmdline_args()
	return "--script" in args or "-s" in args
