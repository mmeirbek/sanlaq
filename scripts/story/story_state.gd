class_name StoryState
extends RefCounted
## Ход главы «Тарих жолы» без интерфейса: шаги строго по очереди, бірлік, флаги,
## XP и открытые статьи. Всё состояние живёт в словаре сохранения, который
## передаёт владелец (StoryDirector сохраняет его через SaveManager), поэтому
## класс проверяется headless и не обращается к автолоадам.
##
## Словарь сохранения:
##   xp: int                       — XP за все главы
##   unlocked: Array[String]       — открытые статьи энциклопедии
##   heroes: {hero_id: {beat, completed, unity, flags, xp}}

const UNITY_MAX := 100

var chapter: StoryChapter
var _save: Dictionary
var _progress: Dictionary
var _dialogues := {}


func _init(story_chapter: StoryChapter, save: Dictionary) -> void:
	chapter = story_chapter
	_save = save
	_save.merge({"xp": 0, "unlocked": [], "heroes": {}})
	var heroes: Dictionary = _save["heroes"]
	if not heroes.has(chapter.hero):
		heroes[chapter.hero] = {}
	_progress = heroes[chapter.hero]
	_progress.merge({"beat": 0, "completed": false, "unity": 0, "flags": [], "xp": 0})
	for dialogue in chapter.dialogues:
		_dialogues[dialogue.id] = dialogue


# --- Шаги --------------------------------------------------------------------

func beat_index() -> int:
	return int(_progress["beat"])


func beat_count() -> int:
	return chapter.beats.size()


func is_complete() -> bool:
	return bool(_progress["completed"]) or beat_index() >= beat_count()


func current_beat() -> StoryBeat:
	return null if is_complete() else chapter.beats[beat_index()]


## Шаг ждёт в другом месте — сначала переезд.
func needs_travel(location: StoryBeat.Location) -> bool:
	var beat := current_beat()
	return beat != null and beat.location != location


## Разбор завершённого шага: сколько XP начислено и какие статьи открылись впервые.
func complete_beat() -> Dictionary:
	var beat := current_beat()
	if beat == null:
		return {"xp": 0, "unlocked": []}
	add_xp(beat.xp)
	var unlocked: Array[String] = []
	for entry_id in beat.unlock:
		if unlock_entry(entry_id):
			unlocked.append(entry_id)
	_progress["beat"] = beat_index() + 1
	if beat_index() >= beat_count():
		_progress["completed"] = true
	return {"xp": beat.xp, "unlocked": unlocked}


## Пройти главу заново: XP и открытые статьи остаются.
func restart() -> void:
	_progress.merge({"beat": 0, "completed": false, "unity": 0, "flags": [], "xp": 0}, true)


# --- Выборы, бірлік, флаги -----------------------------------------------------

func apply_choice(choice: StoryChoice) -> void:
	set_flag(choice.flag)
	add_unity(choice.unity)
	add_xp(choice.xp)


func unity() -> int:
	return int(_progress["unity"])


func add_unity(amount: int) -> void:
	_progress["unity"] = clampi(unity() + amount, 0, UNITY_MAX)


func has_flag(flag: String) -> bool:
	return not flag.is_empty() and flag in _progress["flags"]


func set_flag(flag: String) -> void:
	if not flag.is_empty() and not has_flag(flag):
		(_progress["flags"] as Array).append(flag)


# --- XP и энциклопедия ---------------------------------------------------------

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	_save["xp"] = int(_save["xp"]) + amount
	_progress["xp"] = int(_progress["xp"]) + amount


func total_xp() -> int:
	return int(_save["xp"])


## XP этой главы — хранится в сохранении, выход из игры его не обнуляет.
func chapter_xp() -> int:
	return int(_progress["xp"])


## true — статья открылась сейчас, false — уже была открыта.
func unlock_entry(entry_id: String) -> bool:
	if entry_id.is_empty() or is_unlocked(entry_id):
		return false
	(_save["unlocked"] as Array).append(entry_id)
	return true


func is_unlocked(entry_id: String) -> bool:
	return entry_id in _save["unlocked"]


## Видна ли статья в энциклопедии: открыта с начала или по ходу любой главы.
static func entry_open(save: Dictionary, entry: EncyclopediaEntry) -> bool:
	return entry.open_from_start or entry.id in save.get("unlocked", [])


# --- Диалоги и финал ------------------------------------------------------------

func dialogue(dialogue_id: String) -> StoryDialogue:
	return _dialogues.get(dialogue_id, null)


## Житель вне своего шага: полное приветствие один раз, дальше — короткая фраза.
func idle_line(npc: StoryNpc) -> String:
	var met := "MET_" + npc.id
	if has_flag(met):
		return npc.again_line if not npc.again_line.is_empty() else npc.idle_line
	set_flag(met)
	return npc.idle_line


func finale_text() -> String:
	var alt := chapter.finale_alt_min_unity > 0 and unity() >= chapter.finale_alt_min_unity
	return chapter.finale_alt_text if alt and not chapter.finale_alt_text.is_empty() else chapter.finale_text


## Союзники стоят в мире во всех местах главы, если бірлік достаточно.
func allies_joined() -> bool:
	return chapter.ally_min_unity > 0 and unity() >= chapter.ally_min_unity


func duel_has_ally() -> bool:
	return chapter.duel_ally_min_unity > 0 and unity() >= chapter.duel_ally_min_unity
