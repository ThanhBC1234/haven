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
const GOAL_DELAY := 0.9
const GOAL_SECONDS := 2.4
const PLAYER2_CHAR := "P"
const MIN_ZOOM := 0.75
const ZOOM_NEAR := 160.0
const ZOOM_FAR := 320.0
const ZOOM_DEADBAND := 0.04
const RESTART_HOLD_SECONDS := 0.6
const FIT_MIN_ZOOM := 0.45
const FIT_MARGIN := Vector2(110.0, 150.0)
const VIEW_MARGIN := Vector2(70.0, 90.0)
const QUIT_CONFIRM_SECONDS := 2.0
const SCATTER_RANGE := 320.0
const SCATTER_CLEAR := 88.0
const SCATTER_MAX_DROP := 120.0
const SCATTER_OFFSETS := [64.0, -64.0, 96.0, -96.0, 128.0, -128.0, 160.0, -160.0, 192.0, -192.0, 224.0, -224.0]
const CAUSE_TEXT := {"pit": "SPLASH!", "hurt": "OUCH!", "restart": "RESTART!"}

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
var piggyback: ChainedPiggyback
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
var _quit_armed := 0.0
var _restart_hold := 0.0
var _restart_locked := false
var _zoom_goal := 1.0


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
	camera.limit_top = mini(-64, int(level.size.y - 720.0 / FIT_MIN_ZOOM))
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

	piggyback = ChainedPiggyback.new()
	piggyback.name = "Piggyback"
	add_child(piggyback)
	piggyback.setup(self)

	level.star_collected_by.connect(_on_star)
	level.heart_collected.connect(_on_heart)
	level.checkpoint_reached.connect(_on_checkpoint)
	level.finished.connect(_on_finished)

	hud.setup(level_name, LIVES)
	_sync_hearts()
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
	var penalty := piggyback != null and piggyback.is_queued()
	if penalty:
		hud.clear_message()
	else:
		hud.flash("GO!", 0.7, Color("#f7d046"))
		if Game.chained_index == 0:
			var goal := create_tween()
			goal.tween_interval(GOAL_DELAY)
			goal.tween_callback(_flash_goal)
	level_started.emit()


func _flash_goal() -> void:
	if match_running and not _busy and not finished and not piggyback.piggyback_active and events.active_event == "":
		hud.flash("STARS SLIDE TO THE LOWER PLAYER!", GOAL_SECONDS)


func counts() -> Vector2i:
	return rope.bead_counts() + events.stash_counts()


func winner_of(result: Vector2i) -> int:
	return ChainedHud.winner_of(result)


func has_next_level() -> bool:
	return Game.chained_index + 1 < ChainedData.LEVELS.size()


func _physics_process(delta: float) -> void:
	if _quit_armed > 0.0:
		_quit_armed = maxf(0.0, _quit_armed - delta)
		if _quit_armed <= 0.0:
			hud.hide_quit_prompt()
	if Input.is_action_just_pressed("back"):
		if _quit_armed > 0.0:
			Game.go_to_menu()
			return
		_quit_armed = QUIT_CONFIRM_SECONDS
		hud.show_quit_prompt(QUIT_CONFIRM_SECONDS)
	_tick_restart_hold(delta)
	if not _busy:
		_update_camera(delta)
	if not match_running or _busy:
		return
	for ball in balls:
		if ball.global_position.y > level.size.y + FALL_MARGIN:
			kill_both("pit", ball)
			return
	var c := counts()
	hud.set_counts(c.x, c.y)


func _tick_restart_hold(delta: float) -> void:
	var pressed := Input.is_action_pressed("restart")
	if not pressed:
		_restart_locked = false
	elif not match_running or _busy:
		_restart_locked = true
	if pressed and not _restart_locked:
		_restart_hold += delta
		if _restart_hold >= RESTART_HOLD_SECONDS:
			_restart_hold = 0.0
			_restart_locked = true
			hud.set_restart_hold(0.0)
			kill_both("restart")
			return
	else:
		_restart_hold = 0.0
	hud.set_restart_hold(_restart_hold / RESTART_HOLD_SECONDS)


func _update_camera(delta: float, snap := false) -> void:
	var a := balls[0].global_position
	var b := balls[1].global_position
	var target := (a + b) / 2.0 + Vector2(0.0, -40.0)
	var fit := _fit_zoom(a, b)
	var raw_zoom := zoom_for_separation(a.distance_to(b))
	if snap or absf(raw_zoom - _zoom_goal) > ZOOM_DEADBAND or raw_zoom >= 1.0 or raw_zoom <= MIN_ZOOM:
		_zoom_goal = raw_zoom
	var want_zoom := minf(_zoom_goal, fit)
	if snap:
		camera.global_position = target
		_zoom = want_zoom
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-6.0 * delta))
		_zoom = lerpf(_zoom, want_zoom, 1.0 - exp(-3.0 * delta))
		_zoom = minf(_zoom, fit)
	camera.zoom = Vector2(_zoom, _zoom)
	_keep_in_view(a, b)


func _fit_zoom(a: Vector2, b: Vector2) -> float:
	var view := get_viewport_rect().size
	var fit_x := (view.x - 2.0 * FIT_MARGIN.x) / maxf(absf(a.x - b.x), 1.0)
	var fit_y := (view.y - 2.0 * FIT_MARGIN.y) / maxf(absf(a.y - b.y), 1.0)
	return clampf(minf(fit_x, fit_y), FIT_MIN_ZOOM, 1.0)


func _keep_in_view(a: Vector2, b: Vector2) -> void:
	var half := get_viewport_rect().size / (2.0 * _zoom)
	var margin := VIEW_MARGIN / _zoom
	var lo := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) - half + margin
	var hi := Vector2(minf(a.x, b.x), minf(a.y, b.y)) + half - margin
	var pos := camera.global_position
	pos.x = clampf(pos.x, lo.x, hi.x) if lo.x <= hi.x else (a.x + b.x) / 2.0
	pos.y = clampf(pos.y, lo.y, hi.y) if lo.y <= hi.y else (a.y + b.y) / 2.0
	camera.global_position = pos


func zoom_for_separation(dist: float) -> float:
	var f := clampf((dist - ZOOM_NEAR) / (ZOOM_FAR - ZOOM_NEAR), 0.0, 1.0)
	return lerpf(1.0, MIN_ZOOM, f)


func _on_star(by: Ball) -> void:
	if events.on_star(by):
		return
	rope.add_bead(0.5)


func _on_heart() -> void:
	if lives >= LIVES:
		return
	lives = mini(LIVES, lives + 1)
	_sync_hearts()
	hud.set_lives(lives)
	hud.flash("+1 LIFE!", 0.9, Color("#ff6b81"))


func _sync_hearts() -> void:
	for node in level.get_children():
		if node is Pickup and node.kind == "heart" and not node.is_queued_for_deletion():
			node.set_deferred("monitoring", lives < LIVES)


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
	_sync_hearts()
	for ball in balls:
		ball.dead = true
	players_died.emit(cause)
	_death_sequence.call_deferred(cause, culprit)


func _death_sequence(cause: String, culprit: Ball) -> void:
	var dropped := 0
	if culprit != null:
		dropped = rope.drop_beads(culprit.player_id)
	rope.release_pins()
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
	_respawn(dropped, culprit.player_id if culprit != null else 1)


func _respawn(dropped: int, owner_id := 1) -> void:
	level.reset_crates()
	for ball in balls:
		ball.teleport(respawn_points[ball.player_id - 1])
		ball.collision_layer = BALL_LAYER
		ball.show()
		ball.invuln = RESPAWN_INVULN
		ball.dead = false
	rope.reset()
	rope.show()
	_scatter_stars(dropped, owner_id)
	_update_camera(0.0, true)
	_busy = false
	players_respawned.emit()


func _scatter_stars(count: int, owner_id := 1) -> void:
	var placed := 0
	var owner_spot := respawn_points[clampi(owner_id, 1, 2) - 1] + Vector2(0.0, ChainedPlacement.STAR_LIFT)
	for tier in 4:
		var tier_spots: Array[Vector2] = []
		for off: float in SCATTER_OFFSETS:
			if placed >= count:
				return
			var from := Vector2(respawn_position.x + off, respawn_position.y - 32.0)
			var spot := ChainedPlacement.find(self, from, tier_spots, owner_spot, {"range": SCATTER_RANGE, "max_drop": SCATTER_MAX_DROP, "avoid_points": respawn_points, "avoid_radius": SCATTER_CLEAR})
			tier_spots.append(spot["ground"])
			var origin: Vector2 = spot["ground"]
			var lift := 40.0 * tier if spot["ok"] else 0.0
			while lift > 0.0 and not ChainedPlacement.star_clear(self, origin + Vector2(0.0, -lift)):
				lift -= 40.0
			var star: Pickup = Level.PICKUP.instantiate()
			star.kind = "star"
			star.position = origin + Vector2(0.0, -lift)
			level.add_child(star)
			dropped_stars.append(star)
			placed += 1


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
		Game.chained_piggyback = piggyback.start_penalty
		Game.start_chained(Game.chained_index, true)


func _on_retry() -> void:
	Game.chained_totals[0] = _base_totals[0]
	Game.chained_totals[1] = _base_totals[1]
	if not has_next_level():
		Game.chained_piggyback = piggyback.start_penalty
	Game.start_chained(Game.chained_index, true)


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
	if has_next_level():
		piggyback.record_result(result)
	hud.show_result(result, Game.chained_totals, has_next_level())


func _reopen_finish() -> void:
	for node in level.get_children():
		if node is Pickup and node.kind == "finish":
			node.used = false
