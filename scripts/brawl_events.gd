class_name BrawlEvents
extends Node

signal event_started(id: String)
signal event_ended(id: String)

const EVENT_IDS: Array[String] = ["low_gravity", "super_bounce", "ice_floor", "reversed_keys", "swap", "hot_potato"]
const EVENT_NAMES := {
	"low_gravity": "LOW GRAVITY", "super_bounce": "SUPER BOUNCE", "ice_floor": "ICE FLOOR",
	"reversed_keys": "REVERSED KEYS", "swap": "SWAP!", "hot_potato": "HOT POTATO",
}
const EVENT_COLORS := {
	"low_gravity": Color("#b48cff"), "super_bounce": Color("#a3e05a"), "ice_floor": Color("#9fe0ff"),
	"reversed_keys": Color("#ffb020"), "swap": Color("#7fd6e0"), "hot_potato": Color("#ff6a3d"),
}
const POTATO_TOUCH_GAP := 2.0
const SWAP_RETRY_SECONDS := 0.25
const SWAP_MAX_TRIES := 10
const BOMB_OFFSET := 62.0

var enabled := true
var interval := 15.0
var first_delay := 10.0
var roulette_seconds := 2.0
var low_gravity_seconds := 10.0
var super_bounce_seconds := 10.0
var ice_floor_seconds := 10.0
var reversed_keys_seconds := 8.0
var hot_potato_seconds := 8.0
var low_gravity_scale := 0.4
var super_bounce_bounce := 0.98
var ice_friction := 0.02
var potato_pass_cooldown := 1.0

var active_event := ""
var rolling_event := ""
var last_event := ""
var time_left := 0.0
var bomb_carrier: Ball = null
var brawl: Brawl

var _next_in := 0.0
var _roll_left := 0.0
var _saved := {}
var _ice: IceOverlay = null
var _bomb: BombMarker = null
var _pass_cd := 0.0
var _swap_tries := 0
var _swap_wait := 0
var _swap_velocities: Array[Vector2] = []


func _ready() -> void:
	brawl = get_parent() as Brawl
	if brawl == null:
		push_error("BrawlEvents must be a child of Brawl")
		return
	brawl.match_started.connect(_on_match_started)
	brawl.match_over.connect(_on_match_over)
	brawl.player_respawned.connect(_on_player_respawned)
	brawl.point_scored.connect(_on_point_scored)
	brawl.double_ko.connect(_on_double_ko)
	_next_in = first_delay


func event_name(id: String) -> String:
	return EVENT_NAMES.get(id, id.to_upper())


func duration_of(id: String) -> float:
	match id:
		"low_gravity":
			return low_gravity_seconds
		"super_bounce":
			return super_bounce_seconds
		"ice_floor":
			return ice_floor_seconds
		"reversed_keys":
			return reversed_keys_seconds
		"hot_potato":
			return hot_potato_seconds
	return 0.0


func pick_event() -> String:
	var options: Array[String] = []
	for e in EVENT_IDS:
		if e != last_event and (e != "swap" or _can_swap()):
			options.append(e)
	var id: String = options[randi() % options.size()]
	last_event = id
	return id


func start_event(id: String) -> void:
	if not EVENT_IDS.has(id) or brawl == null or not brawl.match_running:
		return
	stop_event()
	_next_in = interval
	_swap_tries = 0
	_begin(id)


func stop_event() -> void:
	rolling_event = ""
	_roll_left = 0.0
	var id := active_event
	if brawl != null and brawl.hud != null:
		brawl.hud.hide_event()
	if id == "":
		return
	_revert(id)
	active_event = ""
	time_left = 0.0
	event_ended.emit(id)


func _start_roulette(id: String) -> void:
	_next_in = interval
	_swap_tries = 0
	if roulette_seconds <= 0.0:
		_begin(id)
		return
	rolling_event = id
	_roll_left = roulette_seconds
	var names: Array = []
	for e in EVENT_IDS:
		names.append(EVENT_NAMES[e])
	brawl.hud.show_event_roulette(names, EVENT_NAMES[id], roulette_seconds, EVENT_COLORS[id])


func _begin(id: String) -> void:
	rolling_event = ""
	_roll_left = 0.0
	if id == "swap" and not _can_swap():
		_swap_tries += 1
		if _swap_tries <= SWAP_MAX_TRIES:
			rolling_event = id
			_roll_left = SWAP_RETRY_SECONDS
			return
		brawl.hud.hide_event()
		id = pick_event()
	last_event = id
	if id == "swap":
		event_started.emit(id)
		brawl.hud.hide_event()
		_do_swap()
		brawl.hud.flash("SWAP!", 0.8, EVENT_COLORS[id])
		event_ended.emit(id)
		return
	active_event = id
	time_left = duration_of(id)
	_pass_cd = 0.0
	if id == "ice_floor":
		_ice_on()
	elif id == "hot_potato":
		_give_bomb()
	for ball in brawl.balls:
		_apply_to(ball, id)
	brawl.hud.show_event(EVENT_NAMES[id], time_left, EVENT_COLORS[id])
	event_started.emit(id)


func _physics_process(delta: float) -> void:
	if _swap_wait > 0:
		_swap_wait -= 1
		if _swap_wait == 0:
			for i in 2:
				if is_instance_valid(brawl.balls[i]) and not brawl.balls[i].dead:
					brawl.balls[i].linear_velocity = _swap_velocities[i]
	if brawl == null or not brawl.match_running:
		return
	_next_in = maxf(0.0, _next_in - delta)
	if rolling_event != "":
		_roll_left -= delta
		if _roll_left <= 0.0:
			_begin(rolling_event)
	elif active_event != "":
		_tick_active(delta)
	elif enabled and _next_in <= 0.0:
		_start_roulette(pick_event())


func _tick_active(delta: float) -> void:
	time_left -= delta
	if active_event == "hot_potato":
		_tick_potato(delta)
	if time_left <= 0.0 and active_event != "":
		if active_event == "hot_potato":
			if bomb_carrier != null and bomb_carrier.invuln > 0.0:
				time_left = 0.0
				return
			_explode_potato()
		else:
			stop_event()


func _apply_to(ball: Ball, id: String) -> void:
	match id:
		"low_gravity":
			_save(ball, "gravity", ball.gravity_scale)
			ball.gravity_scale = low_gravity_scale
		"super_bounce":
			_set_material(ball, "bounce", super_bounce_bounce)
		"ice_floor":
			_set_material(ball, "friction", ice_friction)
		"reversed_keys":
			_save(ball, "reverse", ball.reverse_controls)
			if not ball.reverse_controls:
				ball.reverse_controls = true


func _revert(id: String) -> void:
	for ball in _saved.keys():
		if not is_instance_valid(ball):
			continue
		var s: Dictionary = _saved[ball]
		match id:
			"low_gravity":
				if s.has("gravity"):
					ball.gravity_scale = s["gravity"]
			"super_bounce", "ice_floor":
				if s.has("material"):
					ball.physics_material_override = s["material"]
			"reversed_keys":
				if s.has("reverse") and ball.reverse_controls != s["reverse"]:
					ball.reverse_controls = s["reverse"]
	_saved.clear()
	if id == "ice_floor":
		_ice_off()
	elif id == "hot_potato":
		_remove_bomb()


func _save(ball: Ball, key: String, value: Variant) -> void:
	var s: Dictionary = _saved.get_or_add(ball, {})
	if not s.has(key):
		s[key] = value


func _set_material(ball: Ball, property: String, value: float) -> void:
	_save(ball, "material", ball.physics_material_override)
	var base: PhysicsMaterial = _saved[ball]["material"]
	var mat: PhysicsMaterial = base.duplicate() if base != null else PhysicsMaterial.new()
	if ball.physics_material_override != null and ball.physics_material_override != base:
		mat = ball.physics_material_override
	mat.set(property, value)
	ball.physics_material_override = mat


func _on_player_respawned(ball: Ball) -> void:
	if active_event != "" and active_event != "hot_potato":
		_apply_to(ball, active_event)


func _on_match_started() -> void:
	stop_event()
	_next_in = first_delay


func _on_double_ko(_cause: String) -> void:
	if active_event == "hot_potato":
		stop_event()


func _on_match_over(_winner: Ball) -> void:
	stop_event()


func _on_point_scored(_scorer: Ball, victim: Ball, cause: String) -> void:
	if active_event == "hot_potato" and victim == bomb_carrier and cause != "bomb":
		stop_event()


func swap_players() -> bool:
	return _do_swap()


func _can_swap() -> bool:
	return brawl != null and brawl.balls.size() == 2 and not brawl.balls[0].dead and not brawl.balls[1].dead


func _do_swap() -> bool:
	var a := brawl.balls[0]
	var b := brawl.balls[1]
	if a.dead or b.dead:
		return false
	var pos_a := a.global_position
	var pos_b := b.global_position
	_swap_velocities = [b.linear_velocity, a.linear_velocity]
	_burst(pos_a, BrawlHud.PLAYER_COLORS[0], 14, 80.0, 220.0, 0.45)
	_burst(pos_b, BrawlHud.PLAYER_COLORS[1], 14, 80.0, 220.0, 0.45)
	a.teleport(pos_b + Vector2(0.0, b.radius - a.radius))
	b.teleport(pos_a + Vector2(0.0, a.radius - b.radius))
	_swap_wait = 2
	return true


func _give_bomb() -> void:
	var options: Array[Ball] = []
	for ball in brawl.balls:
		if not ball.dead and ball.invuln <= 0.0:
			options.append(ball)
	if options.is_empty():
		for ball in brawl.balls:
			if not ball.dead:
				options.append(ball)
	if options.is_empty():
		options.append_array(brawl.balls)
	_set_carrier(options[randi() % options.size()])
	_bomb.fuse_left = time_left
	_bomb.fuse_total = time_left
	brawl.hud.flash("%s HAS THE BOMB!" % brawl.player_name(bomb_carrier), 1.0, BrawlHud.PLAYER_COLORS[brawl.balls.find(bomb_carrier)])


func _set_carrier(ball: Ball) -> void:
	var fuse := time_left
	var total := hot_potato_seconds
	if _bomb != null:
		fuse = _bomb.fuse_left
		total = _bomb.fuse_total
		_bomb.queue_free()
	bomb_carrier = ball
	_bomb = BombMarker.new()
	_bomb.fuse_left = fuse
	_bomb.fuse_total = total
	_bomb.position = Vector2(0, -(ball.radius + BOMB_OFFSET))
	ball.add_child(_bomb)


func _tick_potato(delta: float) -> void:
	_pass_cd = maxf(0.0, _pass_cd - delta)
	if _bomb != null:
		_bomb.fuse_left = maxf(0.0, time_left)
	var other := brawl.opponent_of(bomb_carrier)
	if _pass_cd > 0.0 or bomb_carrier.dead or other.dead or other.invuln > 0.0:
		return
	var gap := bomb_carrier.global_position.distance_to(other.global_position) - bomb_carrier.radius - other.radius
	if gap <= POTATO_TOUCH_GAP:
		_pass_cd = potato_pass_cooldown
		_set_carrier(other)
		_bomb.fuse_left = maxf(0.0, time_left)
		_burst(other.global_position, EVENT_COLORS["hot_potato"], 10, 80.0, 200.0, 0.4)
		brawl.hud.flash("%s HAS THE BOMB!" % brawl.player_name(other), 0.8, BrawlHud.PLAYER_COLORS[brawl.balls.find(other)])


func _explode_potato() -> void:
	var carrier := bomb_carrier
	var pos := carrier.global_position
	_burst(pos, Color("#ffb020"), 70, 160.0, 520.0, 0.9)
	_burst(pos, Color("#f7d046"), 40, 100.0, 380.0, 0.7)
	var ring := Ring.new()
	ring.position = Vector2(pos.x, minf(pos.y, brawl.level.size.y - 24.0))
	brawl.level.add_child(ring)
	brawl.kill(carrier, "bomb")
	stop_event()


func _remove_bomb() -> void:
	if _bomb != null and is_instance_valid(_bomb):
		_bomb.queue_free()
	_bomb = null
	bomb_carrier = null


func _ice_on() -> void:
	_ice_off()
	_ice = IceOverlay.new()
	_ice.setup(brawl.level)
	brawl.level.add_child(_ice)
	brawl.level.move_child(_ice, 0)


func _ice_off() -> void:
	if _ice != null and is_instance_valid(_ice):
		_ice.get_parent().remove_child(_ice)
		_ice.queue_free()
	_ice = null


func _burst(pos: Vector2, color: Color, amount: int, vmin: float, vmax: float, lifetime: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = color
	p.position = Vector2(pos.x, minf(pos.y, brawl.level.size.y - 24.0))
	brawl.level.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)


class BombMarker extends Node2D:
	const PX := 7.0
	var fuse_left := 8.0
	var fuse_total := 8.0
	var lit := false
	var _phase := 0.0
	var _font: Font = null

	func _init() -> void:
		z_index = 20
		_font = UiTheme.main_font()

	func _process(delta: float) -> void:
		var urgency := 1.0 - clampf(fuse_left / maxf(fuse_total, 0.01), 0.0, 1.0)
		_phase += (2.0 + 14.0 * urgency * urgency) * delta
		lit = fmod(_phase, 1.0) < 0.5
		queue_redraw()

	func _draw() -> void:
		var tint := Color(3.0, 0.9, 0.8) if lit else Color.WHITE
		PixelArt.draw_centered(self, PixelArt.BOMB, Vector2.ZERO, PX, tint)
		var digit := str(ceili(fuse_left))
		var col := Color("#ffd23a") if fuse_left <= 3.0 else Color.WHITE
		var at := Vector2(-25.0, PX * 1.5 + 9.0)
		draw_string_outline(_font, at, digit, HORIZONTAL_ALIGNMENT_CENTER, 50.0, UiTheme.FONT_MEDIUM, 6, Color.BLACK)
		draw_string(_font, at, digit, HORIZONTAL_ALIGNMENT_CENTER, 50.0, UiTheme.FONT_MEDIUM, col)


class IceOverlay extends Node2D:
	const TILE := 32.0
	var _tiles: Array[Rect2] = []
	var _tops: Array[Rect2] = []
	var _sparkles: Array[Vector2] = []
	var _area := Rect2()
	var _time := 0.0

	func setup(level: Level) -> void:
		_area = Rect2(Vector2.ZERO, level.size)
		for r in level.rows.size():
			for c in level.cols:
				if level.char_at(r, c) != "#":
					continue
				var cell := Rect2(Vector2(c, r) * TILE, Vector2(TILE, TILE))
				_tiles.append(cell)
				if level.char_at(r - 1, c) != "#":
					_tops.append(Rect2(cell.position, Vector2(TILE, 4.0)))
					if (c * 7 + r * 3) % 3 == 0:
						_sparkles.append(cell.position + Vector2(8.0 + (c * 11) % 16, -6.0))
		modulate.a = 0.0
		z_index = 0

	func _ready() -> void:
		create_tween().tween_property(self, "modulate:a", 1.0, 0.3)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(_area, Color(0.55, 0.8, 1.0, 0.07))
		for t in _tiles:
			draw_rect(t, Color(0.6, 0.88, 1.0, 0.45))
		for t in _tops:
			draw_rect(t, Color(0.92, 0.99, 1.0, 0.95))
		for i in _sparkles.size():
			if sin(_time * 4.0 + i * 1.7) > 0.2:
				var p := _sparkles[i]
				draw_rect(Rect2(p + Vector2(-1, -5), Vector2(2, 10)), Color.WHITE)
				draw_rect(Rect2(p + Vector2(-5, -1), Vector2(10, 2)), Color.WHITE)


class Ring extends Node2D:
	var radius := 10.0

	func _ready() -> void:
		z_index = 15
		var tw := create_tween().set_parallel(true)
		tw.tween_method(_set_radius, 10.0, 190.0, 0.45)
		tw.tween_property(self, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(queue_free)

	func _set_radius(r: float) -> void:
		radius = r
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color("#ffb020"), 8.0)
		draw_arc(Vector2.ZERO, radius - 6.0, 0.0, TAU, 48, Color("#fff2a0"), 3.0)
