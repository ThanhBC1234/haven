class_name Brawl
extends Node2D

signal point_scored(scorer: Ball, victim: Ball, cause: String)
signal match_started
signal match_over(winner: Ball)
signal player_respawned(ball: Ball)

const BALL_SCENE := preload("res://scenes/ball.tscn")
const WIN_SCORE := 5
const FALL_MARGIN := 80.0
const FLATTEN_TIME := 0.6
const RESPAWN_INVULN := 1.5
const CEILING_Y := -16.0
const SHOVE_SPEED := 360.0
const SHOVE_LIFT := 180.0
const SHOVE_GAP := 1.0
const SPAWN_CHARS := "OP"
const BALL_LAYER := 2
const LEADER_SCALE := 1.25
const CROWN_PX := 3.0

static var _last_arena := -1

@export var arena_index := -1
@export var intro_seconds := 1.4
@export var respawn_delay := 1.2
@export var win_panel_delay := 1.0
@export var stall_timeout := 30.0
@export var stall_step := 2.0
@export var sudden_death_delay := 4.0
@export var sudden_death_speed := 35.0

@onready var camera: Camera2D = $Camera
@onready var hud: BrawlHud = $HUD/Hud

var level: Level
var arena_name := ""
var arena_rect := Rect2()
var balls: Array[Ball] = []
var scores: Array[int] = [0, 0]
var spawn_points: Array[Vector2] = []
var match_running := false
var winner: Ball = null
var events: BrawlEvents
var items: BrawlItems
var leader: Ball = null
var vs_bot := false
var bot: BrawlBot = null
var stall_active := false
var stall_spikes: Array[Spikes] = []
var sudden_death_active := false
var _sd_wait := 0.0
var _sd_y := INF
var _sd_pause := 0.0
var _sd_row: HazardRow = null
var _stall_time := 0.0
var _stall_next := 0.0
var _stall_left: Array[int] = []
var _stall_right: Array[int] = []
var _last_taunt := ""
var _crowns: Array = [null, null]
var _was_touching := false
var _shove_wait := 0


func _ready() -> void:
	var count: int = BrawlData.ARENAS.size()
	if arena_index < 0 or arena_index >= count:
		arena_index = randi() % count
		if count > 1 and arena_index == _last_arena:
			arena_index = (arena_index + 1 + randi() % (count - 1)) % count
	_last_arena = arena_index
	var data: Dictionary = BrawlData.ARENAS[arena_index]
	arena_name = data["name"]
	vs_bot = Game.brawl_vs_bot

	level = Level.new()
	add_child(level)
	move_child(level, 0)
	level.build(data["map"])
	arena_rect = Rect2(Vector2.ZERO, level.size)
	spawn_points = [level.start_position, _find_spawn(BrawlData.PLAYER2_CHAR)]

	camera.position = Vector2(level.size.x / 2.0, level.size.y - 360.0)
	camera.make_current()

	var ceiling := StaticBody2D.new()
	var ceiling_shape := CollisionShape2D.new()
	var ceiling_rect := RectangleShape2D.new()
	ceiling_rect.size = Vector2(level.size.x, 200.0)
	ceiling_shape.shape = ceiling_rect
	ceiling_shape.position = Vector2(level.size.x / 2.0, CEILING_Y - 100.0)
	ceiling.add_child(ceiling_shape)
	level.add_child(ceiling)

	for i in 2:
		var ball: Ball = BALL_SCENE.instantiate()
		ball.position = spawn_points[i]
		level.add_child(ball)
		ball.set_player(i + 1)
		ball.set_collide_with_balls(true)
		ball.hurt.connect(_on_ball_hurt.bind(ball))
		ball.stomped.connect(_on_stomped.bind(ball))
		balls.append(ball)

	events = BrawlEvents.new()
	events.name = "Events"
	add_child(events)
	items = BrawlItems.new()
	items.name = "Items"
	add_child(items)
	if vs_bot:
		bot = BrawlBot.new()
		bot.name = "Bot"
		add_child(bot)
	hud.setup(WIN_SCORE, vs_bot)
	hud.rematch_pressed.connect(func() -> void: Game.start_brawl(Game.brawl_vs_bot))
	hud.menu_pressed.connect(Game.go_to_menu)
	_start_intro()


func _find_spawn(ch: String) -> Vector2:
	for r in level.rows.size():
		var c: int = level.rows[r].find(ch)
		if c != -1:
			return Vector2((c + 0.5) * Level.TILE, (r + 1) * Level.TILE - 16.0)
	push_error("Brawl: arena '%s' has no '%s' spawn" % [arena_name, ch])
	return level.size / 2.0


func _start_intro() -> void:
	for ball in balls:
		ball.dead = true
	hud.flash("READY...", intro_seconds)
	await get_tree().create_timer(intro_seconds).timeout
	if not is_inside_tree():
		return
	for ball in balls:
		ball.dead = false
	match_running = true
	_reset_stall()
	hud.flash("BOUNCE!", 0.7)
	match_started.emit()


func opponent_of(ball: Ball) -> Ball:
	return balls[1] if ball == balls[0] else balls[0]


func spawn_of(ball: Ball) -> Vector2:
	return spawn_points[balls.find(ball)]


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("back"):
		Game.go_to_menu()
		return
	if not match_running:
		return
	for ball in balls:
		if not ball.dead and not arena_rect.grow_individual(200.0, 200.0, 200.0, FALL_MARGIN).has_point(ball.global_position):
			kill(ball, "pit")
	_update_leader()
	_shove_balls()
	_update_stall(delta)


func _shove_balls() -> void:
	var a := balls[0]
	var b := balls[1]
	var offset := b.global_position - a.global_position
	var touching := not a.dead and not b.dead and offset.length() <= a.radius + b.radius + SHOVE_GAP
	if touching and not _was_touching and absf(offset.normalized().y) < 0.75:
		_shove_wait = 2
	_was_touching = touching
	if _shove_wait > 0:
		_shove_wait -= 1
		if _shove_wait == 0 and not a.dead and not b.dead:
			var dir := offset.normalized()
			a.knockback(-dir * SHOVE_SPEED + Vector2(0, -SHOVE_LIFT))
			b.knockback(dir * SHOVE_SPEED + Vector2(0, -SHOVE_LIFT))


func _on_ball_hurt(ball: Ball) -> void:
	kill(ball, "spikes")


func _on_stomped(victim: Ball, stomper: Ball) -> void:
	if not match_running or stomper.dead or victim.dead or victim.invuln > 0.0:
		return
	kill(victim, "stomp")


func kill(victim: Ball, cause: String) -> void:
	if not match_running or victim == null or victim.dead:
		return
	var scorer := opponent_of(victim)
	var si := balls.find(scorer)
	victim.dead = true
	scores[si] += 1
	hud.set_score(scorer.player_id, scores[si])
	_reset_stall()
	var over: bool = scores[si] >= WIN_SCORE
	if over:
		match_running = false
		winner = scorer
	_update_leader()
	point_scored.emit(scorer, victim, cause)
	hud.flash(_point_text(scorer, victim, cause), 1.0, BrawlHud.PLAYER_COLORS[si])
	if over:
		_end_match(scorer)
	_death_sequence(victim, cause, not over)


func player_name(ball: Ball) -> String:
	if vs_bot and ball == balls[1]:
		return "BOT"
	return "P%d" % ball.player_id


func _point_text(scorer: Ball, victim: Ball, cause: String) -> String:
	var pool: Array = BrawlData.TAUNTS.get(cause, BrawlData.TAUNTS["default"])
	var options: Array = pool.filter(func(line: String) -> bool: return line != _last_taunt)
	var line: String = options[randi() % options.size()]
	_last_taunt = line
	return line.format({"s": player_name(scorer), "v": player_name(victim)})


func _end_match(scorer: Ball) -> void:
	scorer.dead = true
	match_over.emit(scorer)
	await get_tree().create_timer(win_panel_delay).timeout
	if not is_inside_tree():
		return
	hud.show_win(scorer.player_id, scores)


func _death_sequence(victim: Ball, cause: String, respawn: bool) -> void:
	var idx := balls.find(victim)
	if cause == "stomp":
		victim.flatten(FLATTEN_TIME + 0.2)
		await get_tree().create_timer(FLATTEN_TIME).timeout
		if not is_inside_tree():
			return
	_pop_effect(victim.global_position, BrawlHud.PLAYER_COLORS[idx])
	victim.hide()
	victim.collision_layer = 0
	victim.teleport(spawn_points[idx])
	if not respawn:
		return
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	_respawn(victim)


func _respawn(ball: Ball) -> void:
	var base_radius := ball.radius / ball.size_factor
	ball.teleport(spawn_of(ball) + Vector2(0.0, base_radius - ball.radius))
	ball.collision_layer = BALL_LAYER
	ball.show()
	ball.invuln = RESPAWN_INVULN
	if sudden_death_active and _sd_y < ball.global_position.y + ball.radius + sudden_death_speed * (RESPAWN_INVULN + 1.0):
		_sd_y = level.size.y
		_sd_pause = RESPAWN_INVULN
		_place_hazard_row()
	ball.dead = not match_running
	player_respawned.emit(ball)


func _pop_effect(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 22
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 300.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.position = Vector2(pos.x, minf(pos.y, level.size.y - 24.0))
	level.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _leader_by_score() -> Ball:
	if not match_running or scores[0] == scores[1]:
		return null
	return balls[0] if scores[0] > scores[1] else balls[1]

func _update_leader() -> void:
	var want := _leader_by_score()
	if want == leader:
		return
	leader = want
	for i in 2:
		var ball := balls[i]
		var crowned := ball == leader
		if crowned and not is_equal_approx(ball.size_factor, LEADER_SCALE):
			ball.set_size(LEADER_SCALE)
		elif not crowned and is_equal_approx(ball.size_factor, LEADER_SCALE):
			ball.set_size(1.0)
		if crowned and _crowns[i] == null:
			var crown := CrownMarker.new()
			crown.brawl = self
			crown.ball = ball
			ball.add_child(crown)
			_crowns[i] = crown
		elif not crowned and _crowns[i] != null:
			if is_instance_valid(_crowns[i]):
				_crowns[i].queue_free()
				ball.remove_child(_crowns[i])
			_crowns[i] = null


class CrownMarker extends Node2D:
	const HEAD_TOP := 46.0
	const BOMB_LIFT := 84.0
	var ball: Ball = null
	var brawl: Brawl = null
	var _time := 0.0

	func _init() -> void:
		z_index = 10

	func _process(delta: float) -> void:
		_time += delta
		visible = not ball.dead
		var f := ball.size_factor
		var lift := 0.0
		if brawl != null and brawl.events != null and brawl.events.bomb_carrier == ball:
			lift = BOMB_LIFT
		position = Vector2(0.0, -(HEAD_TOP * f + 11.0 + lift + sin(_time * 4.0) * 2.0))

	func _draw() -> void:
		PixelArt.draw_centered(self, PixelArt.CROWN, Vector2.ZERO, Brawl.CROWN_PX)


func floor_row() -> int:
	return level.rows.size() - 3


func upcoming_stall_columns(count := 2) -> Array[int]:
	var cols: Array[int] = []
	if not stall_active:
		return cols
	for i in mini(count, _stall_left.size()):
		cols.append(_stall_left[i])
	for i in mini(count, _stall_right.size()):
		cols.append(_stall_right[i])
	return cols


func _can_spike(c: int) -> bool:
	var r := floor_row()
	return level.char_at(r + 1, c) == "#" and (level.char_at(r, c) == "." or level.char_at(r, c) in SPAWN_CHARS)


func _reset_stall() -> void:
	_stall_time = 0.0
	_stall_next = 0.0
	stall_active = false
	for s in stall_spikes:
		if is_instance_valid(s):
			s.queue_free()
	stall_spikes.clear()
	sudden_death_active = false
	_sd_wait = 0.0
	_sd_pause = 0.0
	_sd_y = INF
	if is_instance_valid(_sd_row):
		level.remove_child(_sd_row)
		_sd_row.queue_free()
	_sd_row = null
	_stall_left.clear()
	_stall_right.clear()
	var cols := level.cols
	var half := cols >> 1
	for c in range(1, half):
		if _can_spike(c):
			_stall_left.append(c)
	for c in range(cols - 2, half - 1, -1):
		if _can_spike(c):
			_stall_right.append(c)


func _update_stall(delta: float) -> void:
	_stall_time += delta
	if _stall_time < stall_timeout:
		return
	if not stall_active:
		stall_active = true
		hud.flash("NO POINTS - SPIKES!", 1.4, Color("#ffb020"))
	if sudden_death_active:
		_rise_hazard(delta)
		return
	if _stall_left.is_empty() and _stall_right.is_empty():
		_sd_wait += delta
		if _sd_wait >= sudden_death_delay:
			_start_sudden_death()
		return
	_stall_next -= delta
	if _stall_next > 0.0:
		return
	_stall_next = stall_step
	if not _stall_left.is_empty():
		_add_stall_spike(_stall_left.pop_front())
	if not _stall_right.is_empty():
		_add_stall_spike(_stall_right.pop_front())


func _add_stall_spike(c: int) -> void:
	var s: Spikes = Level.SPIKES.instantiate()
	s.position = Vector2((c + 0.5) * Level.TILE, (floor_row() + 1) * Level.TILE)
	level.add_child(s)
	stall_spikes.append(s)
	s.scale = Vector2(1.0, 0.1)
	s.create_tween().tween_property(s, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hazard_y() -> float:
	return _sd_y if sudden_death_active else INF


func _start_sudden_death() -> void:
	sudden_death_active = true
	_sd_y = level.size.y
	_sd_pause = 0.0
	_sd_row = HazardRow.new()
	_sd_row.width = level.size.x
	level.add_child(_sd_row)
	_place_hazard_row()
	hud.flash("SUDDEN DEATH!", 1.6, Color("#ff4040"))


func _place_hazard_row() -> void:
	if is_instance_valid(_sd_row):
		_sd_row.position = Vector2(0.0, _sd_y + HazardRow.SPIKE_HEIGHT)


func _rise_hazard(delta: float) -> void:
	if _sd_pause > 0.0:
		_sd_pause -= delta
	else:
		_sd_y -= sudden_death_speed * delta
	_place_hazard_row()
	var victim: Ball = null
	var deepest := 0.0
	for ball in balls:
		if ball.dead or ball.invuln > 0.0:
			continue
		var depth := ball.global_position.y + ball.radius - _sd_y
		if depth >= 0.0 and (victim == null or depth > deepest + 0.5 or (absf(depth - deepest) <= 0.5 and randf() < 0.5)):
			victim = ball
			deepest = depth
	if victim != null:
		kill(victim, "spikes")


class HazardRow extends Node2D:
	const SPIKE_WIDTH := 16.0
	const SPIKE_HEIGHT := 16.0
	const FILL_HEIGHT := 900.0
	const SPIKE_COLOR := Color("#b9c4b0")
	const EDGE_COLOR := Color("#2a3328")
	const FILL_COLOR := Color("#171c16")
	var width := 1280.0

	func _init() -> void:
		z_index = 5

	func _draw() -> void:
		draw_rect(Rect2(0.0, 0.0, width, FILL_HEIGHT), FILL_COLOR)
		for i in ceili(width / SPIKE_WIDTH):
			var x := i * SPIKE_WIDTH
			var tri := PackedVector2Array([Vector2(x, 0.0), Vector2(x + SPIKE_WIDTH / 2.0, -SPIKE_HEIGHT), Vector2(x + SPIKE_WIDTH, 0.0)])
			draw_colored_polygon(tri, SPIKE_COLOR)
			draw_polyline(tri, EDGE_COLOR, 1.5)
