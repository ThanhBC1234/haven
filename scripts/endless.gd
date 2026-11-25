extends Node2D

const BALL_SCENE := preload("res://scenes/ball.tscn")
const LIVES := 3
const AHEAD := 2400.0
const BEHIND := 1600.0
const METER := 32.0
const STAR_POINTS := 25
const SEGMENTS_PER_MULT := 4
const MAX_MULT := 5
const FALL_MARGIN := 160.0
const RESPAWN_DELAY := 0.8
const DIFFICULTY_STEPS := [[0, 1], [3, 2], [7, 3]]
const BOSS_EVERY := 8
const BOSS_POINTS := 500

@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD/Hud

var chunks: Array[Level] = []
var ball: Ball
var lives := LIVES
var stars := 0
var score := 0.0
var multiplier := 1
var segments_passed := 0
var _end_x := 0.0
var _best_x := 0.0
var _next_goal := 0.0
var _goals: Array[float] = []
var _last_name := ""
var _built := 0
var boss_arenas_built := 0
var _rng := RandomNumberGenerator.new()
var _busy := false
var _over := false


func _ready() -> void:
	_rng.randomize()
	_add_chunk(SegmentData.START, "Start")
	ball = BALL_SCENE.instantiate()
	ball.position = chunks[0].start_position
	ball.z_index = 5
	add_child(ball)
	ball.hurt.connect(_on_ball_hurt)
	_best_x = ball.global_position.x
	_fill_ahead()

	var height := chunks[0].size.y
	camera.limit_left = 0
	camera.limit_top = mini(-64, int(height) - 720)
	camera.limit_bottom = int(height)
	camera.global_position = ball.global_position
	camera.reset_smoothing()

	hud.setup_endless(LIVES)
	hud.watch_ball(ball)
	hud.set_score(0, 1)
	hud.retry_pressed.connect(Game.start_endless)
	hud.menu_pressed.connect(Game.go_to_menu)


func _add_chunk(map: String, seg_name: String) -> void:
	var lv := Level.new()
	lv.name = "Chunk_%d" % chunks.size()
	lv.position.x = _end_x
	add_child(lv)
	lv.build(map)
	lv.set_meta("seg_name", seg_name)
	lv.star_collected.connect(_on_star)
	lv.heart_collected.connect(_on_heart)
	lv.boss_defeated.connect(_on_boss_defeated)
	hud.watch_level(lv)
	chunks.append(lv)
	_end_x += lv.size.x
	_goals.append(_end_x)


func _pick_segment() -> Dictionary:
	var max_diff := 1
	for step in DIFFICULTY_STEPS:
		if segments_passed >= step[0]:
			max_diff = step[1]
	var pool := SegmentData.SEGMENTS.filter(func(s): return s["difficulty"] <= max_diff and s["name"] != _last_name)
	if pool.is_empty():
		pool = SegmentData.SEGMENTS
	return pool[_rng.randi() % pool.size()]


func _fill_ahead() -> void:
	while _end_x < ball.global_position.x + AHEAD:
		_built += 1
		if _built % BOSS_EVERY == 0:
			_add_chunk(SegmentData.BOSS_ARENA, "Boss Arena")
			boss_arenas_built += 1
			continue
		var seg := _pick_segment()
		_add_chunk(seg["map"], seg["name"])
		_last_name = seg["name"]
	while chunks.size() > 2 and chunks[0].position.x + chunks[0].size.x < ball.global_position.x - BEHIND:
		chunks.pop_front().queue_free()


func _physics_process(_delta: float) -> void:
	if _over:
		if Input.is_action_just_pressed("back"):
			Game.go_to_menu()
		return
	if not ball.dead:
		camera.global_position = ball.global_position + Vector2(ball.linear_velocity.x * 0.25 + 160, -40)
		var x := ball.global_position.x
		if x > _best_x:
			score += (x - _best_x) / METER * multiplier
			_best_x = x
		while not _goals.is_empty() and x > _goals[0] + 2.0 * METER:
			_goals.pop_front()
			segments_passed += 1
			var m := mini(MAX_MULT, 1 + floori(segments_passed / float(SEGMENTS_PER_MULT)))
			if m > multiplier:
				multiplier = m
				hud.flash("x%d MULTIPLIER!" % multiplier)
		hud.set_score(int(score), multiplier)
		_fill_ahead()
		if ball.global_position.y > chunks[0].size.y + FALL_MARGIN:
			_on_ball_hurt()
	if Input.is_action_just_pressed("restart") and not _busy:
		_on_ball_hurt()
	if Input.is_action_just_pressed("back"):
		Game.go_to_menu()


func _on_star() -> void:
	stars += 1
	score += STAR_POINTS * multiplier
	hud.set_stars(stars)


func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)
	hud.set_lives(lives)


func _on_boss_defeated(_boss: Node) -> void:
	score += BOSS_POINTS * multiplier


func _on_ball_hurt() -> void:
	if _busy or _over:
		return
	_busy = true
	lives -= 1
	hud.set_lives(lives)
	var respawn := _respawn_point(ball.global_position.x)
	ball.dead = true
	ball.hide()
	ball.teleport(respawn)
	if lives <= 0:
		_game_over()
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	ball.teleport(respawn)
	camera.global_position = respawn
	ball.dead = false
	ball.invuln = 1.5
	ball.show()
	_busy = false


func _respawn_point(x: float) -> Vector2:
	for lv in chunks:
		if x < lv.position.x + lv.size.x:
			return lv.position + lv.start_position
	return chunks[-1].position + chunks[-1].start_position


func _game_over() -> void:
	_over = true
	var new_best := Game.record_endless(int(score), stars)
	hud.show_game_over(int(score), Game.best_score, new_best, stars, Game.total_stars)
