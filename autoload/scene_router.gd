extends Node

const SCENE_MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const SCENE_LOBBY := "res://scenes/ui/lobby.tscn"
const SCENE_WARDROBE := "res://scenes/ui/wardrobe.tscn"
const SCENE_GAME := "res://scenes/world/game.tscn"
const SCENE_RESULTS := "res://scenes/ui/results.tscn"
const SCENE_CODEX := "res://scenes/ui/codex.tscn"

var _pending_game_data: Dictionary = {}

signal scene_changed(from: String, to: String)

func go_to_main_menu() -> void:
	_change_scene(SCENE_MAIN_MENU)

func go_to_lobby() -> void:
	_change_scene(SCENE_LOBBY)

func go_to_wardrobe() -> void:
	_change_scene(SCENE_WARDROBE)

func go_to_game(game_data: Dictionary = {}) -> void:
	_pending_game_data = game_data
	_change_scene(SCENE_GAME)

func go_to_results() -> void:
	_change_scene(SCENE_RESULTS)

func go_to_codex() -> void:
	_change_scene(SCENE_CODEX)

func get_pending_game_data() -> Dictionary:
	var data := _pending_game_data
	_pending_game_data = {}
	return data

func quit() -> void:
	get_tree().quit()

func _change_scene(to: String) -> void:
	var from := ""
	if get_tree().current_scene:
		from = get_tree().current_scene.scene_file_path
	if from == to:
		return
	get_tree().change_scene_to_file(to)
	scene_changed.emit(from, to)
