class_name Chained
extends Node2D

signal level_started
signal level_finished(counts: Vector2i)
signal players_died(cause: String)
signal players_respawned
signal restart_requested

const BALL_SCENE := preload("res://scenes/ball.tscn")
const LIVES := 5
const FALL_MARGIN := 160.0
const RESPAWN_INVULN := 1.5
const RESPAWN_SPREAD := 24.0
const BALL_LAYER := 2
const PLAYER2_CHAR := "P"
const MIN_ZOOM := 0.75
const SCATTER_OFFSETS := [64.0, -64.0, 96.0, -96.0, 128.0, -128.0, 160.0, -160.0, 192.0, -192.0, 224.0, -224.0]
const CAUSE_TEXT := {"pit": "SPLASH!", "hurt": "OUCH!"}

@export var intro_seconds := 1.6
@export var respawn_delay := 1.0
@export var restart_delay := 1.6
@export var finish_panel_delay := 0.8
@export var scene_changes_enabled := true

@onready var camera: Camera2D = $Camera
@onready var hud: ChainedHud = $HUD/Hud

var level: Level
var level_name := ""
var balls: Array[Ball] = []
var rope: Rope
var events: ChainedEvents
var lives := LIVES
var spawn_points: Array[Vector2] = []
var respawn_position := Vector2.ZERO
var respawn_points: Array[Vector2] = []
var match_running := false
var dropped_stars: Array[Pickup] = []
var finished := false
var _busy := false
var _base_totals: Array[int] = [0, 0]
var _zoom := 1.0


func _ready() -> void:
	var data: Dictionary = ChainedData.LEVELS[Game.chained_index]
	level_name = data["name"]
	_base_totals = [Game.chained_totals[0], Game.chained_totals[1]]

	level = Level.new()
	add_child(level)
	move_child(level, 0)
	level.build(data["map"])
	spawn_points = [level.start_position, _find_spawn(PLAYER2_CHAR)]
	respawn_points = spawn_points.duplicate()
	respawn_position = (spawn_points[0] + spawn_points[1]) / 2.0

	camera.limit_left = 0
	camera.limit_right = int(level.size.x)
	camera.limit_bottom = int(level.size.y) + 96
	camera.limit_top = mini(-64, int(level.size.y - 720.0 / MIN_ZOOM))
	camera.position_smoothing_enabled = false

	var bounds := StaticBody2D.new()
	for wall_x in [16.0, level.size.x - 16.0]:
		var wall := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 2000)
		wall.shape = rect
		wall.position = Vector2(wall_x, -1000)
		bounds.add_child(wall)
	level.add_child(bounds)

	for i in 2:
		var ball: Ball = BALL_SCENE.instantiate()
		ball.position = spawn_points[i]
		level.add_child(ball)
		ball.set_player(i + 1)
		ball.set_collide_with_balls(true)
		ball.hurt.connect(_on_ball_hurt.bind(ball))
		ball.stomped.connect(_on_stomped.bind(ball))
		balls.append(ball)

	rope = Rope.new()
	rope.name = "Rope"
	level.add_child(rope)
	level.move_child(rope, balls[0].get_index())
	rope.setup(balls[0], balls[1])

	level.star_collected_by.connect(_on_star)
	level.heart_collected.connect(_on_heart)
	level.checkpoint_reached.connect(_on_checkpoint)
	level.finished.connect(_on_finished)

	hud.setup(level_name, LIVES)
	hud.next_pressed.connect(func() -> void: Game.start_chained(Game.chained_index + 1))
	hud.retry_pressed.connect(_on_retry)
	hud.menu_pressed.connect(Game.go_to_menu)
	events = ChainedEvents.new()
	events.name = "Events"
	add_child(events)
	_update_camera(0.0, true)
	_start_intro()


func _find_spawn(ch: String) -> Vector2:
	for r in level.rows.size():
		var c: int = level.rows[r].find(ch)
		if c != -1:
			return Vector2((c + 0.5) * Level.TILE, (r + 1) * Level.TILE - 16.0)
	push_error("Chained: level '%s' has no '%s' spawn" % [level_name, ch])
	return level.start_position + Vector2(64.0, 0.0)


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
	hud.flash("GO!", 0.7, Color("#f7d046"))
	level_started.emit()


func counts() -> Vector2i:
	return rope.bead_counts() + events.stash_counts()


func winner_of(result: Vector2i) -> int:
	return ChainedHud.winner_of(result)


func has_next_level() -> bool:
	return Game.chained_index + 1 < ChainedData.LEVELS.size()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("back"):
		Game.go_to_menu()
		return
	_update_camera(delta)
	if not match_running or _busy:
		return
	for ball in balls:
		if ball.global_position.y > level.size.y + FALL_MARGIN:
			kill_both("pit", ball)
			return
	var c := counts()
	hud.set_counts(c.x, c.y)


func _update_camera(delta: float, snap := false) -> void:
	var a := balls[0].global_position
	var b := balls[1].global_position
	var target := (a + b) / 2.0 + Vector2(0.0, -40.0)
	var want_zoom := zoom_for_separation(a.distance_to(b))
	if snap:
		camera.global_position = target
		_zoom = want_zoom
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-6.0 * delta))
		_zoom = lerpf(_zoom, want_zoom, 1.0 - exp(-3.0 * delta))
	camera.zoom = Vector2(_zoom, _zoom)


func zoom_for_separation(dist: float) -> float:
	var f := clampf(inverse_lerp(rope.rest_length, rope.max_length, dist), 0.0, 1.0)
	return lerpf(1.0, MIN_ZOOM, f)


func _on_star(by: Ball) -> void:
	if events.on_star(by):
		return
	rope.add_bead(0.5)


func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)
	hud.set_lives(lives)
	hud.flash("+1 LIFE!", 0.9, Color("#ff6b81"))


func _on_checkpoint(pos: Vector2) -> void:
	respawn_position = pos
	respawn_points = [pos + Vector2(-RESPAWN_SPREAD, 0.0), pos + Vector2(RESPAWN_SPREAD, 0.0)]
	hud.flash("CHECKPOINT!", 1.0)


func _on_stomped(victim: Ball, stomper: Ball) -> void:
	if not match_running or _busy or stomper.dead or victim.dead or victim.invuln > 0.0:
		return
	if rope.steal_bead(stomper, victim):
		hud.flash("P%d STEALS A STAR!" % stomper.player_id, 1.0, ChainedHud.PLAYER_COLORS[stomper.player_id - 1])


func _on_ball_hurt(ball: Ball) -> void:
	kill_both.call_deferred("hurt", ball)


func kill_both(cause: String, culprit: Ball = null) -> void:
	if not match_running or _busy:
		return
	_busy = true
	lives -= 1
	hud.set_lives(maxi(lives, 0))
	for ball in balls:
		ball.dead = true
	players_died.emit(cause)
	_death_sequence.call_deferred(cause, culprit)


func _death_sequence(cause: String, culprit: Ball) -> void:
	var dropped := 0
	if culprit != null:
		dropped = rope.drop_beads(culprit.player_id)
	for ball in balls:
		_pop_effect(ball.global_position, ChainedHud.PLAYER_COLORS[ball.player_id - 1])
		ball.hide()
		ball.collision_layer = 0
		ball.teleport(respawn_points[ball.player_id - 1])
	rope.reset()
	rope.hide()
	var text: String = CAUSE_TEXT.get(cause, "OOPS!")
	if dropped > 0:
		text += "\nP%d DROPPED %d STAR%s!" % [culprit.player_id, dropped, "" if dropped == 1 else "S"]
	if lives <= 0:
		hud.flash("Out of lives! Restarting...", restart_delay + 0.5, Color("#ff5d5d"))
		await get_tree().create_timer(restart_delay).timeout
		if not is_inside_tree():
			return
		restart_level()
		return
	hud.flash(text, respawn_delay + 0.4, Color("#ff9a5d"))
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	_respawn(dropped)


func _respawn(dropped: int) -> void:
	level.reset_crates()
	for ball in balls:
		ball.teleport(respawn_points[ball.player_id - 1])
		ball.collision_layer = BALL_LAYER
		ball.show()
		ball.invuln = RESPAWN_INVULN
		ball.dead = false
	rope.reset()
	rope.show()
	_scatter_stars(dropped)
	_update_camera(0.0, true)
	_busy = false
	players_respawned.emit()


func _scatter_stars(count: int) -> void:
	var placed := 0
	for tier in 4:
		for off: float in SCATTER_OFFSETS:
			if placed >= count:
				return
			var ground = _ground_point(respawn_position.x + off)
			if ground == null:
				continue
			var star: Pickup = Level.PICKUP.instantiate()
			star.kind = "star"
			star.position = ground + Vector2(0.0, -40.0 * tier)
			level.add_child(star)
			dropped_stars.append(star)
			placed += 1


func _ground_point(x: float):
	var from := Vector2(x, respawn_position.y - 48.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 120.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var point: Vector2 = hit["position"]
	var tile_c := int(point.x / Level.TILE)
	var tile_r := int(point.y / Level.TILE) - 1
	var above := level.char_at(tile_r, tile_c)
	if above == "^" or above == "v" or above == "T":
		return null
	return point


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


func restart_level() -> void:
	restart_requested.emit()
	if scene_changes_enabled:
		Game.start_chained(Game.chained_index)


func _on_retry() -> void:
	Game.chained_totals[0] = _base_totals[0]
	Game.chained_totals[1] = _base_totals[1]
	Game.start_chained(Game.chained_index)


func _on_finished() -> void:
	if not match_running or _busy or balls[0].dead or balls[1].dead:
		_reopen_finish()
		return
	match_running = false
	finished = true
	events.stop_event()
	rope.freeze_beads = true
	var result := rope.bead_counts()
	Game.chained_totals[0] = _base_totals[0] + result.x
	Game.chained_totals[1] = _base_totals[1] + result.y
	hud.set_counts(result.x, result.y)
	for ball in balls:
		ball.dead = true
	level_finished.emit(result)
	hud.flash("FINISH!", finish_panel_delay, Color("#f7d046"))
	await get_tree().create_timer(finish_panel_delay).timeout
	if not is_inside_tree():
		return
	hud.show_result(result, Game.chained_totals, has_next_level())


func _reopen_finish() -> void:
	for node in level.get_children():
		if node is Pickup and node.kind == "finish":
			node.used = false
