class_name ChainedEvents
extends Node

signal event_started(id: String)
signal event_ended(id: String)

const EVENT_IDS: Array[String] = ["body_swap", "one_brain", "short_leash", "bungee", "giant_tiny", "freedom", "earthquake"]
const EVENT_NAMES := {
	"body_swap": "BODY SWAP", "one_brain": "ONE BRAIN", "short_leash": "SHORT LEASH", "bungee": "BUNGEE",
	"giant_tiny": "GIANT & TINY", "freedom": "FREEDOM", "earthquake": "EARTHQUAKE",
}
const EVENT_COLORS := {
	"body_swap": Color("#7fd6e0"), "one_brain": Color("#ff9fd0"), "short_leash": Color("#ffb020"), "bungee": Color("#a3e05a"),
	"giant_tiny": Color("#b48cff"), "freedom": Color("#f7d046"), "earthquake": Color("#d9965a"),
}
const TILE := 32.0
const GROUND_LAYER := 1
const GROUND_STEP := 16.0
const GROUND_RANGE := 640.0
const EDGE_MARGIN := 10.0
const STAR_SPACING := 20.0
const STAR_FALL_SECONDS := 0.4
const WALL_MARGIN := 48.0
const SKIPPED_ABOVE := "^vT"

var enabled := true
var interval := 20.0
var first_delay := 12.0
var roulette_seconds := 2.0
var body_swap_seconds := 10.0
var one_brain_seconds := 10.0
var brain_switch_seconds := 5.0
var short_leash_seconds := 10.0
var bungee_seconds := 10.0
var giant_tiny_seconds := 10.0
var freedom_seconds := 10.0
var earthquake_seconds := 8.0
var short_leash_rest := 2.0
var short_leash_max := 3.0
var bungee_rest := 6.0
var bungee_max := 18.0
var bungee_stiffness := 5.0
var bungee_damping := 1.5
var giant_scale := 1.6
var tiny_scale := 0.6
var giant_override := 0
var glide_seconds := 1.0
var reattach_wait_max := 3.0
var quake_shake := 6.0
var quake_speed := 2.0

var active_event := ""
var rolling_event := ""
var last_event := ""
var time_left := 0.0
var brain := 0
var giant_player := 0
var reattach_pending := false
var freedom_stars: Array[Pickup] = []
var chained: Chained

var _next_in := 0.0
var _roll_left := 0.0
var _effects_on := false
var _brain_first := 1
var _markers: Array = []
var _stash: Array[float] = []
var _cut_owned := false
var _reattach_left := 0.0
var _rope_base := {}
var _rope_goal := {}
var _rope_rate := {}
var _rope_restoring := false
var _quake_v := {}
var _quake_clock := 0.0


func _ready() -> void:
	chained = get_parent() as Chained
	if chained == null:
		push_error("ChainedEvents must be a child of Chained")
		return
	enabled = chained.scene_changes_enabled and not OS.get_cmdline_user_args().has("--no-events")
	chained.level_started.connect(_on_level_started)
	chained.level_finished.connect(_on_level_finished)
	chained.players_died.connect(_on_died)
	chained.players_respawned.connect(_on_respawned)
	_next_in = first_delay


func _exit_tree() -> void:
	if chained != null:
		_undo(active_event, true)


func event_name(id: String) -> String:
	return EVENT_NAMES.get(id, id.to_upper())


func duration_of(id: String) -> float:
	match id:
		"body_swap":
			return body_swap_seconds
		"one_brain":
			return one_brain_seconds
		"short_leash":
			return short_leash_seconds
		"bungee":
			return bungee_seconds
		"giant_tiny":
			return giant_tiny_seconds
		"freedom":
			return freedom_seconds
		"earthquake":
			return earthquake_seconds
	return 0.0


func pick_event() -> String:
	var options: Array[String] = []
	for e in EVENT_IDS:
		if e != last_event:
			options.append(e)
	var id: String = options[randi() % options.size()]
	last_event = id
	return id


func start_event(id: String) -> void:
	if not EVENT_IDS.has(id) or chained == null or not chained.match_running:
		return
	stop_event()
	_next_in = interval
	_begin(id)


func stop_event() -> void:
	rolling_event = ""
	_roll_left = 0.0
	if _hud() != null:
		_hud().hide_event()
	var id := active_event
	_undo(id, true)
	if id == "":
		return
	_clear_state()
	event_ended.emit(id)


func _clear_state() -> void:
	active_event = ""
	time_left = 0.0
	brain = 0
	giant_player = 0


func stash_counts() -> Vector2i:
	var counts := Vector2i.ZERO
	for t in _stash:
		if t < 0.5:
			counts.x += 1
		else:
			counts.y += 1
	return counts


func on_star(by: Ball) -> bool:
	if not _cut_owned or by == null:
		return false
	_stash.append(Rope.BEAD_END if by.player_id == 1 else 1.0 - Rope.BEAD_END)
	return true


func _start_roulette(id: String) -> void:
	_next_in = interval
	if roulette_seconds <= 0.0:
		_begin(id)
		return
	rolling_event = id
	_roll_left = roulette_seconds
	var names: Array = []
	for e in EVENT_IDS:
		names.append(EVENT_NAMES[e])
	_hud().show_event_roulette(names, EVENT_NAMES[id], roulette_seconds, EVENT_COLORS[id])


func _begin(id: String) -> void:
	rolling_event = ""
	_roll_left = 0.0
	last_event = id
	active_event = id
	time_left = duration_of(id)
	if id == "giant_tiny":
		giant_player = giant_override if giant_override == 1 or giant_override == 2 else 1 + randi() % 2
	elif id == "one_brain":
		_brain_first = 1 + randi() % 2
	if not _players_dead():
		_apply(id)
	_hud().show_event(_banner_text(id), time_left, EVENT_COLORS[id])
	event_started.emit(id)


func _banner_text(id: String) -> String:
	if id == "one_brain":
		return "%s: P%d" % [EVENT_NAMES[id], _current_brain()]
	return EVENT_NAMES[id]


func _physics_process(delta: float) -> void:
	_rope_step(delta)
	_tick_reattach(delta)
	if chained == null or not chained.match_running:
		return
	_next_in = maxf(0.0, _next_in - delta)
	if rolling_event != "":
		_roll_left -= delta
		if _roll_left <= 0.0:
			_begin(rolling_event)
	elif active_event != "":
		_tick_active(delta)
	elif enabled and _next_in <= 0.0 and not reattach_pending and not _players_dead():
		_start_roulette(pick_event())


func _tick_active(delta: float) -> void:
	time_left -= delta
	if _effects_on:
		if active_event == "one_brain":
			_tick_brain()
		elif active_event == "earthquake":
			_tick_quake(delta)
	if time_left <= 0.0:
		var id := active_event
		_undo(id, false)
		_clear_state()
		_hud().hide_event()
		event_ended.emit(id)


func _players_dead() -> bool:
	return chained.balls[0].dead or chained.balls[1].dead


func _hud() -> ChainedHud:
	return chained.hud if chained != null and is_instance_valid(chained.hud) else null


func _apply(id: String) -> void:
	_effects_on = true
	match id:
		"body_swap":
			_set_keys(["p2_", "p1_"], [2, 1])
		"one_brain":
			brain = _current_brain()
			_set_keys(["p%d_" % brain, "p%d_" % brain], [brain, brain])
		"short_leash":
			_rope_to({"rest": short_leash_rest * TILE, "max": short_leash_max * TILE}, false)
		"bungee":
			_rope_to({"rest": bungee_rest * TILE, "max": bungee_max * TILE, "stiff": bungee_stiffness, "damp": bungee_damping}, false)
		"giant_tiny":
			for i in 2:
				_resize(chained.balls[i], giant_scale if i + 1 == giant_player else tiny_scale, false)
		"freedom":
			_freedom_cut()
		"earthquake":
			_quake_v.clear()
			_quake_clock = 0.0


func _undo(id: String, instant: bool) -> void:
	if _effects_on:
		_effects_on = false
		match id:
			"body_swap", "one_brain":
				_set_keys(["p1_", "p2_"], [])
			"short_leash", "bungee":
				if not instant and not _rope_base.is_empty():
					_rope_to(_rope_base, true)
			"giant_tiny":
				for ball in chained.balls:
					_resize(ball, 1.0, true)
			"freedom":
				if not instant and _cut_owned:
					reattach_pending = true
					_reattach_left = reattach_wait_max
			"earthquake":
				_quake_v.clear()
				if is_instance_valid(chained.camera):
					chained.camera.offset = Vector2.ZERO
	if instant:
		_rope_instant_restore()
		if _cut_owned and is_instance_valid(chained.rope):
			_reattach(true)


func _current_brain() -> int:
	var elapsed := duration_of("one_brain") - time_left
	return _brain_first if elapsed < brain_switch_seconds else 3 - _brain_first


func _tick_brain() -> void:
	var now := _current_brain()
	if now == brain:
		return
	brain = now
	_set_keys(["p%d_" % brain, "p%d_" % brain], [brain, brain])
	_hud().update_event(_banner_text("one_brain"), EVENT_COLORS["one_brain"])
	_hud().flash("P%d IS THE BRAIN!" % brain, 0.9, ChainedHud.PLAYER_COLORS[brain - 1])


func _set_keys(prefixes: Array, drivers: Array) -> void:
	for i in 2:
		var ball := chained.balls[i]
		if is_instance_valid(ball) and ball.action_prefix != prefixes[i]:
			ball.action_prefix = prefixes[i]
	_clear_markers()
	for i in drivers.size():
		var ball := chained.balls[i]
		if not is_instance_valid(ball):
			continue
		var marker := KeyMarker.new()
		marker.text = "P%d" % drivers[i]
		marker.color = ChainedHud.PLAYER_COLORS[drivers[i] - 1]
		ball.add_child(marker)
		_markers.append(marker)


func _clear_markers() -> void:
	for marker in _markers:
		if is_instance_valid(marker):
			if marker.get_parent() != null:
				marker.get_parent().remove_child(marker)
			marker.queue_free()
	_markers.clear()


func _rope_to(goal: Dictionary, restoring: bool) -> void:
	var rope := chained.rope
	if _rope_base.is_empty():
		_rope_base = {"rest": rope.rest_length, "max": rope.max_length, "stiff": rope.stiffness, "damp": rope.damping}
	_rope_goal = goal.duplicate()
	_rope_rate.clear()
	for key in _rope_goal:
		_rope_rate[key] = maxf(absf(_rope_goal[key] - _rope_get(key)) / maxf(glide_seconds, 0.05), 0.001)
	_rope_restoring = restoring


func _rope_step(delta: float) -> void:
	if _rope_goal.is_empty() or not is_instance_valid(chained.rope):
		return
	var done := true
	for key in _rope_goal:
		var next := move_toward(_rope_get(key), _rope_goal[key], _rope_rate[key] * delta)
		_rope_set(key, next)
		if next != _rope_goal[key]:
			done = false
	if done:
		_rope_goal = {}
		if _rope_restoring:
			_rope_base = {}
			_rope_restoring = false


func _rope_instant_restore() -> void:
	if not _rope_base.is_empty() and is_instance_valid(chained.rope):
		for key in _rope_base:
			_rope_set(key, _rope_base[key])
	_rope_base = {}
	_rope_goal = {}
	_rope_rate.clear()
	_rope_restoring = false


func _rope_get(key: String) -> float:
	var rope := chained.rope
	match key:
		"rest":
			return rope.rest_length
		"max":
			return rope.max_length
		"stiff":
			return rope.stiffness
	return rope.damping


func _rope_set(key: String, value: float) -> void:
	var rope := chained.rope
	match key:
		"rest":
			rope.rest_length = value
		"max":
			rope.max_length = value
		"stiff":
			rope.stiffness = value
		"damp":
			rope.damping = value


func _resize(ball: Ball, factor: float, force: bool) -> bool:
	if not is_instance_valid(ball) or not is_instance_valid(chained.rope):
		return false
	if chained.rope.is_anchored(ball):
		chained.rope.reset()
	var new_radius := ball.radius / ball.size_factor * factor
	var grow := new_radius - ball.radius
	if grow > 0.5:
		var pos := _pos(ball)
		var spot = _free_spot(pos, new_radius, grow)
		if spot == null and not force:
			return false
		if spot != null and spot != pos:
			var velocity := ball.linear_velocity
			var pending: bool = ball._teleport_to != null
			ball.teleport(spot)
			if not ball.dead and not pending:
				ball.knockback(velocity)
	ball.set_size(factor)
	return true


func _free_spot(pos: Vector2, radius: float, grow: float):
	if not chained.is_inside_tree():
		return pos
	var shape := CircleShape2D.new()
	shape.radius = maxf(radius - 2.0, 1.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = GROUND_LAYER
	var space := chained.get_world_2d().direct_space_state
	for dy in [-grow, 0.0, -2.0 * grow, -3.0 * grow]:
		query.transform = Transform2D(0.0, pos + Vector2(0.0, dy))
		if space.intersect_shape(query, 1).is_empty():
			return pos + Vector2(0.0, dy)
	return null


func _pos(ball: Ball) -> Vector2:
	if ball._teleport_to != null:
		return ball._teleport_to
	return ball.global_position


func _freedom_cut() -> void:
	var rope := chained.rope
	var end_a := _pos(chained.balls[0]) + Rope.ATTACH * chained.balls[0].size_factor
	var end_b := _pos(chained.balls[1]) + Rope.ATTACH * chained.balls[1].size_factor
	var placed: Array[Vector2] = []
	var beads: Array = rope.beads.duplicate()
	for bead in beads:
		var from := end_a.lerp(end_b, bead.t)
		var spot = _landing_spot(from, placed)
		if spot == null:
			spot = chained.respawn_position + Vector2(0.0, 16.0)
		placed.append(spot)
		_drop_star(from, spot)
	rope.beads.clear()
	rope.cut = true
	_cut_owned = true


func _drop_star(from: Vector2, to: Vector2) -> void:
	var star: Pickup = Level.PICKUP.instantiate()
	star.kind = "star"
	star.position = Vector2(to.x, minf(from.y, to.y))
	chained.level.add_child(star)
	freedom_stars.append(star)
	if star.position.y < to.y:
		star.create_tween().tween_property(star, "position", to, STAR_FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		star.position = to


func _landing_spot(from: Vector2, placed: Array[Vector2]):
	var steps := int(GROUND_RANGE / GROUND_STEP)
	for k in steps + 1:
		for side in [1, -1]:
			if k == 0 and side == -1:
				continue
			var spot = _ground_at(from.x + side * k * GROUND_STEP, from.y - 8.0)
			if spot == null:
				continue
			var crowded := false
			for p in placed:
				if p.distance_to(spot) < STAR_SPACING:
					crowded = true
					break
			if not crowded:
				return spot
	return null


func _ground_at(x: float, y: float):
	var level := chained.level
	if x < WALL_MARGIN or x > level.size.x - WALL_MARGIN:
		return null
	var space := chained.get_world_2d().direct_space_state
	var point := Vector2.ZERO
	for dx in [0.0, -EDGE_MARGIN, EDGE_MARGIN]:
		var query := PhysicsRayQueryParameters2D.create(Vector2(x + dx, y), Vector2(x + dx, level.size.y + 64.0), GROUND_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return null
		if dx == 0.0:
			point = hit["position"]
		elif absf(hit["position"].y - point.y) > TILE * 0.75:
			return null
	var above := level.char_at(int(point.y / TILE) - 1, int(point.x / TILE))
	if SKIPPED_ABOVE.contains(above):
		return null
	return point


func _over_pit(ball: Ball) -> bool:
	if ball.on_ground:
		return false
	var from := ball.global_position
	var query := PhysicsRayQueryParameters2D.create(from, Vector2(from.x, chained.level.size.y + 64.0), GROUND_LAYER)
	return chained.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _tick_reattach(delta: float) -> void:
	if not reattach_pending:
		return
	_reattach_left -= delta
	if _reattach_left > 0.0 and (_over_pit(chained.balls[0]) or _over_pit(chained.balls[1])):
		return
	_reattach(false)


func _reattach(instant: bool) -> void:
	var rope := chained.rope
	var apart := rope.current_length()
	reattach_pending = false
	_cut_owned = false
	for t in _stash:
		rope.add_bead(t)
	_stash.clear()
	rope.cut = false
	if not instant and apart > rope.max_length - 0.5:
		if _rope_base.is_empty():
			_rope_base = {"rest": rope.rest_length, "max": rope.max_length, "stiff": rope.stiffness, "damp": rope.damping}
		var goal := _rope_base.duplicate()
		rope.rest_length = maxf(rope.rest_length, apart)
		rope.max_length = maxf(rope.max_length, apart + 16.0)
		_rope_to(goal, true)


func _tick_quake(delta: float) -> void:
	var rope := chained.rope
	_quake_clock -= delta
	var renew := _quake_clock <= 0.0
	if renew:
		_quake_clock = randf_range(0.15, 0.3)
	for bead in rope.beads:
		if renew or not _quake_v.has(bead):
			_quake_v[bead] = randf_range(-1.0, 1.0) * quake_speed
		bead.t = clampf(bead.t + _quake_v[bead] * delta, Rope.BEAD_END, 1.0 - Rope.BEAD_END)
		bead.lock = maxf(bead.lock, 0.1)
	if rope.beads.size() >= 2:
		rope._separate()
	chained.camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * quake_shake


func _on_level_started() -> void:
	stop_event()
	_next_in = first_delay


func _on_level_finished(_counts: Vector2i) -> void:
	stop_event()


func _on_died(_cause: String) -> void:
	if rolling_event != "":
		rolling_event = ""
		_roll_left = 0.0
		_next_in = maxf(_next_in, 4.0)
		if _hud() != null:
			_hud().hide_event()
	_undo(active_event, true)


func _on_respawned() -> void:
	if active_event != "" and not _effects_on:
		_apply(active_event)


class KeyMarker extends Node2D:
	const HEAD := 46.0
	const LIFT := 44.0
	var text := "P1"
	var color := Color.WHITE
	var _time := 0.0
	var _font: Font = null

	func _init() -> void:
		z_index = 20
		_font = UiTheme.main_font()

	func _process(delta: float) -> void:
		_time += delta
		var ball := get_parent() as Ball
		if ball != null:
			position = Vector2(0.0, -(HEAD * ball.size_factor + LIFT) + sin(_time * 5.0) * 2.0).snapped(Vector2(2.0, 2.0))
		queue_redraw()

	func _draw() -> void:
		var box := Rect2(Vector2(-22.0, -14.0), Vector2(44.0, 28.0))
		draw_rect(box.grow(2.0), color)
		draw_rect(box, Color("#0b1118"))
		draw_string(_font, Vector2(box.position.x, box.position.y + 22.0), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 22, color)
