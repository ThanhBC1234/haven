extends Node

const MENU_SCENE := "res://scenes/menu.tscn"
const PLAY_SCENE := "res://scenes/play.tscn"
const ENDLESS_SCENE := "res://scenes/endless.tscn"
const BRAWL_SCENE := "res://scenes/brawl.tscn"
const CHAINED_SCENE := "res://scenes/chained.tscn"
const SAVE_PATH :="user://bouncing_ball.cfg"

const KEYS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"shoot": [KEY_F, KEY_J],
	"restart": [KEY_R],
	"back": [KEY_ESCAPE],
	"p1_left": [KEY_A],
	"p1_right": [KEY_D],
	"p1_jump": [KEY_W, KEY_SPACE],
	"p1_use": [KEY_S],
	"p2_left": [KEY_LEFT],
	"p2_right": [KEY_RIGHT],
	"p2_jump": [KEY_UP],
	"p2_use": [KEY_DOWN],
	"solo_left": [KEY_A, KEY_LEFT],
	"solo_right": [KEY_D, KEY_RIGHT],
	"solo_jump": [KEY_W, KEY_SPACE, KEY_UP],
	"solo_use": [KEY_S, KEY_DOWN, KEY_F, KEY_J],
	"bot1_left": [], "bot1_right": [], "bot1_jump": [], "bot1_use": [],
	"bot2_left": [], "bot2_right": [], "bot2_jump": [], "bot2_use": [],
}

var level_index := 0
var best_stars := {}
var best_score := 0
var total_stars := 0
var save_enabled := true
var brawl_vs_bot := false
var chained_index := 0
var chained_totals: Array[int] = [0, 0]
var chained_piggyback := 0
var chained_switching := false


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


func start_brawl(vs_bot := false) -> void:
	brawl_vs_bot = vs_bot
	get_tree().change_scene_to_file(BRAWL_SCENE)


func start_chained(index := 0, keep_piggyback := false) -> void:
	chained_index = index
	if index == 0:
		chained_totals[0] = 0
		chained_totals[1] = 0
		if not keep_piggyback:
			chained_piggyback = 0
	chained_switching = true
	get_tree().change_scene_to_file(CHAINED_SCENE)


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
	chained_piggyback = 0
	chained_switching = false
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
