extends Node

const MENU_SCENE := "res://scenes/menu.tscn"
const PLAY_SCENE := "res://scenes/play.tscn"
const ENDLESS_SCENE := "res://scenes/endless.tscn"
const SAVE_PATH := "user://bouncing_ball.cfg"

const KEYS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"shoot": [KEY_F, KEY_J],
	"restart": [KEY_R],
	"back": [KEY_ESCAPE],
}

var level_index := 0
var best_stars := {}
var best_score := 0
var total_stars := 0
var save_enabled := true


func _ready() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	load_progress()


func start_level(index: int) -> void:
	level_index = index
	get_tree().change_scene_to_file(PLAY_SCENE)


func start_endless() -> void:
	get_tree().change_scene_to_file(ENDLESS_SCENE)


func next_level() -> bool:
	if level_index + 1 >= LevelData.LEVELS.size():
		return false
	start_level(level_index + 1)
	return true


func record_stars(index: int, stars: int) -> void:
	best_stars[index] = maxi(stars, best_stars.get(index, 0))
	total_stars += stars
	save_progress()


func record_endless(score: int, stars: int) -> bool:
	total_stars += stars
	var new_best := score > best_score
	best_score = maxi(best_score, score)
	save_progress()
	return new_best


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func save_progress() -> void:
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "total_stars", total_stars)
	cfg.set_value("progress", "best_stars", best_stars)
	cfg.save(SAVE_PATH)


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_score = cfg.get_value("progress", "best_score", 0)
	total_stars = cfg.get_value("progress", "total_stars", 0)
	best_stars = cfg.get_value("progress", "best_stars", {})
