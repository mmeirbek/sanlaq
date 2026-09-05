extends Node
## Лёгкая телеметрия для B2B-станций: часы игры, использование способностей/кнопок,
## ошибки. Пока ENDPOINT_URL пуст — всё копится только локально в user://telemetry_queue.jsonl,
## сеть не трогается. Заполните ENDPOINT_URL адресом развёрнутого Apps Script
## (см. tools/telemetry_apps_script.gs), чтобы события начали улетать на сервер.

const STATION_FILE := "user://station.json"
const QUEUE_FILE := "user://telemetry_queue.jsonl"
const FLUSH_INTERVAL := 30.0
const MAX_QUEUE_LOCAL := 500  # не даём файлу расти бесконечно на офлайн-станции

const ENDPOINT_URL := "https://script.google.com/macros/s/AKfycbzcWNnnXMXUEXwAXGq-srpvnYQ_uYJvVQ0zHVekg1aYHtAnXltyBShvnGHhA95dlM7I/exec"

signal license_denied(reason: String)

var station_id: String = ""
var venue_label: String = "unlabeled"

var _session_start_unix: int = 0
var _http: HTTPRequest
var _license_http: HTTPRequest
var _flush_timer: float = 0.0
var _flushing: bool = false

func _ready() -> void:
	_load_station()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_flush_response)
	_license_http = HTTPRequest.new()
	add_child(_license_http)
	_license_http.request_completed.connect(_on_license_response)
	_session_start_unix = Time.get_unix_time_from_system()
	log_event("session_start")
	_check_license()

## venue_label, заданный при установке станции (--venue=... / ?venue=...), одновременно
## служит лицензионным ключом: сервер сверяет его с листом "licenses" в таблице и считает
## число разных station_id, уже отметившихся под этим ключом (лист "stations").
## Если venue_label не найден в "licenses" вообще — станция считается демо/неоформленной
## и не блокируется. Блокируем только по явному ответу "ok": false — любая сетевая
## ошибка/таймаут молча игнорируется, чтобы обрыв связи не отключил оплаченную станцию.
func _check_license() -> void:
	if ENDPOINT_URL.is_empty() or venue_label.is_empty() or venue_label == "unlabeled":
		return
	var body := JSON.stringify({
		"action": "register",
		"license_key": venue_label,
		"station_id": station_id,
	})
	_license_http.request(ENDPOINT_URL, ["Content-Type: text/plain"], HTTPClient.METHOD_POST, body)

func _on_license_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary and data.get("ok", true) == false:
		var reason: String = data.get("reason", "unknown")
		log_event("license_denied", {"reason": reason})
		license_denied.emit(reason)

func _process(delta: float) -> void:
	_flush_timer -= delta
	if _flush_timer <= 0.0:
		_flush_timer = FLUSH_INTERVAL
		flush()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_log_session_end()

func log_event(event_type: String, payload: Dictionary = {}) -> void:
	_append_local({
		"ts": Time.get_datetime_string_from_system(true),
		"station_id": station_id,
		"venue": venue_label,
		"event": event_type,
		"payload": payload,
	})

func log_error(message: String, context: String = "") -> void:
	push_warning("Telemetry error [%s]: %s" % [context, message])
	log_event("error", {"message": message, "context": context})

func flush() -> void:
	if _flushing or ENDPOINT_URL.is_empty():
		return
	var rows := _read_queue()
	if rows.is_empty():
		return
	_flushing = true
	var body := JSON.stringify({"rows": rows})
	var err := _http.request(ENDPOINT_URL, ["Content-Type: text/plain"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_flushing = false

func session_seconds() -> int:
	return int(Time.get_unix_time_from_system() - _session_start_unix)

func _log_session_end() -> void:
	log_event("session_end", {"seconds_played": session_seconds()})
	flush()

func _on_flush_response(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_flushing = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_clear_queue()

func _load_station() -> void:
	if FileAccess.file_exists(STATION_FILE):
		var f := FileAccess.open(STATION_FILE, FileAccess.READ)
		var data: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if data is Dictionary:
			station_id = data.get("station_id", "")
			venue_label = data.get("venue", "unlabeled")
	if station_id.is_empty():
		station_id = _generate_id()
	var venue_from_launch := _read_venue_from_launch()
	if not venue_from_launch.is_empty():
		venue_label = venue_from_launch
	_save_station()

func _read_venue_from_launch() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--venue="):
			return arg.substr(8)
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		if typeof(query) == TYPE_STRING and (query as String).find("venue=") != -1:
			for pair in (query as String).lstrip("?").split("&"):
				var kv := pair.split("=")
				if kv.size() == 2 and kv[0] == "venue":
					return kv[1].uri_decode()
	return ""

func _save_station() -> void:
	var f := FileAccess.open(STATION_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"station_id": station_id, "venue": venue_label}))
		f.close()

func _generate_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var out := "st_"
	for i in 10:
		out += chars[randi() % chars.length()]
	return out

func _append_local(row: Dictionary) -> void:
	var lines: Array = []
	if FileAccess.file_exists(QUEUE_FILE):
		var f := FileAccess.open(QUEUE_FILE, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		if not text.is_empty():
			lines = text.split("\n", false)
	lines.append(JSON.stringify(row))
	if lines.size() > MAX_QUEUE_LOCAL:
		lines = lines.slice(lines.size() - MAX_QUEUE_LOCAL)
	var out := FileAccess.open(QUEUE_FILE, FileAccess.WRITE)
	if out:
		out.store_string("\n".join(lines))
		out.close()

func _read_queue() -> Array:
	if not FileAccess.file_exists(QUEUE_FILE):
		return []
	var f := FileAccess.open(QUEUE_FILE, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var out: Array = []
	for line in text.split("\n", false):
		var data: Variant = JSON.parse_string(line)
		if data is Dictionary:
			out.append(data)
	return out

func _clear_queue() -> void:
	var f := FileAccess.open(QUEUE_FILE, FileAccess.WRITE)
	if f:
		f.store_string("")
		f.close()
