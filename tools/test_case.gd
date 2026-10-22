extends SceneTree
## Основа для headless-тестов tools/*_test.gd. Тест наследуется от неё:
##
##     extends "res://tools/test_case.gd"
##
##     func _init() -> void:
##         check(1 + 1 == 2, "арифметика работает")
##         finish("ARITHMETIC")
##
## Запуск: godot --headless --path . --script res://tools/<имя>_test.gd
##
## Кроме явных check() тест проваливается, если во время прогона движок или
## скрипт записал ошибку (push_error, SCRIPT ERROR, «Node not found» и т.п.):
## такие ошибки не роняют сцену, поэтому без перехвата их легко не заметить.
## Предупреждения не считаются. При провале процесс выходит с кодом 1 — CI
## видит упавший тест.


## Копит ошибки движка. Логгер могут вызывать из разных потоков, поэтому
## запись идёт под мьютексом.
class EngineErrorLog extends Logger:
	var _mutex := Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var message := rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("%s:%d %s" % [file, line, message])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var errors := _errors.duplicate()
		_mutex.unlock()
		return errors


var _fails := 0
var _engine_errors := _start_error_log()


func check(condition: bool, message: String) -> void:
	if condition:
		print("[test] ok: ", message)
	else:
		_fails += 1
		print("[test] FAIL: ", message)


## Печатает итог и завершает процесс с кодом 1 при любом провале.
func finish(suite: String) -> void:
	var errors := _engine_errors.take()
	for error in errors:
		print("[test] ENGINE ERROR: ", error)
	var failed := _fails + errors.size()
	if failed == 0:
		print("[test] %s OK" % suite)
	else:
		print("[test] %s FAILED (проверок: %d, ошибок движка: %d)" % [suite, _fails, errors.size()])
	quit(1 if failed > 0 else 0)


## Автолоады недоступны по имени в скрипте, запущенном через --script: он
## компилируется раньше, чем они регистрируются как глобальные идентификаторы.
## Внутри сцен они работают как обычно, а здесь берём их из дерева.
func autoload(singleton: String) -> Node:
	return root.get_node_or_null("/root/" + singleton)


## Инстанцирует сцену в корень и даёт ей пару кадров на _ready и раскладку.
func mount(path: String) -> Node:
	var pack := load(path) as PackedScene
	if pack == null:
		check(false, "сцена загружается: " + path)
		return null
	var instance := pack.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance


func unmount(instance: Node) -> void:
	root.remove_child(instance)
	instance.queue_free()
	await process_frame


func _start_error_log() -> EngineErrorLog:
	var log := EngineErrorLog.new()
	OS.add_logger(log)
	return log
