class_name RankSystem
extends RefCounted
## Ойыншының жеңістеріне қарай дәрежесі — той басынан бастап дала батырына дейін.

const TIERS := [
	{"name": "БАСТАУШЫ", "wins": 0},
	{"name": "ШИРАҚ", "wins": 3},
	{"name": "ТОЙ БАСЫ", "wins": 5},
	{"name": "ДАЛА ЖІГІТІ", "wins": 8},
	{"name": "ДАЛА ШЕБЕРІ", "wins": 12},
	{"name": "БАТЫР", "wins": 20},
]

static func current_rank_name(wins: int) -> String:
	var rank_name: String = TIERS[0]["name"]
	for tier in TIERS:
		if wins >= int(tier["wins"]):
			rank_name = tier["name"]
	# static funcs have no `self`, so use TranslationServer directly instead of tr().
	return TranslationServer.translate(rank_name)

## Returns {} when the player already holds the top rank.
static func next_rank_info(wins: int) -> Dictionary:
	for tier in TIERS:
		if wins < int(tier["wins"]):
			return {"name": tier["name"], "remaining": int(tier["wins"]) - wins}
	return {}

static func progress_text(wins: int) -> String:
	var next := next_rank_info(wins)
	if next.is_empty():
		return TranslationServer.translate("ЕҢ ЖОҒАРЫ ДӘРЕЖЕГЕ ЖЕТТІҢІЗ!")
	var next_name: String = TranslationServer.translate(next["name"])
	return TranslationServer.translate("%s ДӘРЕЖЕСІНЕ ДЕЙІН: %d ЖЕҢІС") % [next_name, next["remaining"]]
