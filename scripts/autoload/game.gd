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
var endless_stars := 0
var save_enabled := true
var sfx_muted := false
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
	_recount_stars()
	save_progress()


func record_endless(score: int, stars: int) -> bool:
	endless_stars += maxi(0, stars)
	_recount_stars()
	var new_best := score > best_score
	best_score = maxi(best_score, score)
	save_progress()
	return new_best


func story_stars() -> int:
	var n := 0
	for i in best_stars:
		n += int(best_stars[i])
	return n


static func story_star_total() -> int:
	var n := 0
	for i in LevelData.LEVELS.size():
		n += star_cap(i)
	return n


static func star_cap(index: int) -> int:
	return String(LevelData.LEVELS[index]["map"]).count("*")


func _recount_stars() -> void:
	total_stars = story_stars() + endless_stars


func go_to_menu() -> void:
	chained_piggyback = 0
	chained_switching = false
	get_tree().change_scene_to_file(MENU_SCENE)


func save_progress(path := SAVE_PATH) -> void:
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "total_stars", total_stars)
	cfg.set_value("progress", "endless_stars", endless_stars)
	cfg.set_value("progress", "best_stars", best_stars)
	cfg.set_value("settings", "sfx_muted", sfx_muted)
	cfg.save(path)


func load_progress(path := SAVE_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var muted = cfg.get_value("settings", "sfx_muted", false)
	sfx_muted = typeof(muted) == TYPE_BOOL and muted
	var score = cfg.get_value("progress", "best_score", 0)
	if typeof(score) == TYPE_INT and score >= 0:
		best_score = score
	var stars = cfg.get_value("progress", "best_stars", {})
	best_stars = {}
	if typeof(stars) == TYPE_DICTIONARY:
		for k in stars:
			var v = stars[k]
			if typeof(k) == TYPE_INT and typeof(v) == TYPE_INT and k >= 0 and k < LevelData.LEVELS.size() and v >= 0:
				best_stars[k] = mini(v, star_cap(k))
	var endless = cfg.get_value("progress", "endless_stars", -1)
	if typeof(endless) == TYPE_INT and endless >= 0:
		endless_stars = endless
	else:
		var legacy = cfg.get_value("progress", "total_stars", 0)
		endless_stars = 0
		if typeof(legacy) == TYPE_INT and best_score > 0:
			endless_stars = maxi(0, legacy - story_stars())
	_recount_stars()
