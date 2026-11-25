class_name BrawlItems
extends Node

signal item_picked(ball: Ball, id: String)
signal item_used(ball: Ball, id: String)
signal trap_sprung(ball: Ball)

const ITEM_IDS: Array[String] = ["gun", "banana", "swap", "spring"]
const ITEM_NAMES := {
	"gun": "GUN", "banana": "BANANA", "swap": "SWAP", "spring": "SPRING",
}
const ITEM_ICONS := {
	"gun": PixelArt.GUN, "banana": PixelArt.BANANA, "swap": PixelArt.SWAP, "spring": PixelArt.SPRING,
}
const BOX_LIFT := 28.0
const PICK_REACH := 18.0
const SPOT_BALL_GAP := 110.0
const SPOT_BOX_GAP := 200.0
const GUN_SHOTS := 3
const GUN_KNOCKBACK := 600.0
const SPRING_LAUNCH := 1250.0
const TRAP_HALF_WIDTH := 20.0
const TRAP_HEIGHT := 30.0
const GROUND_REACH := 900.0

var enabled := true
var spawn_interval := 6.0
var first_delay := 3.0
var max_boxes := 2
var gun_knockback := GUN_KNOCKBACK
var banana_seconds := 3.0
var spring_arm_seconds := 0.5
var spring_life_seconds := 12.0
var spring_launch := SPRING_LAUNCH

var held: Array = ["", ""]
var boxes: Array = []
var traps: Array = []
var brawl: Brawl

var _next_in := 0.0
var _last_id := ""
var _banana_left: Array[float] = [0.0, 0.0]
var _banana_marks: Array = [null, null]


func _ready() -> void:
	brawl = get_parent() as Brawl
	if brawl == null:
		push_error("BrawlItems must be a child of Brawl")
		return
	brawl.match_started.connect(_on_match_started)
	brawl.match_over.connect(_on_match_over)
	brawl.point_scored.connect(_on_point_scored)
	brawl.player_respawned.connect(_on_player_respawned)
	if brawl.events != null:
		brawl.events.event_started.connect(_on_event_changed)
		brawl.events.event_ended.connect(_on_event_changed)
	for ball in brawl.balls:
		ball.use_pressed.connect(use.bind(ball))
		ball.ammo_changed.connect(_on_ammo_changed.bind(ball))
	_next_in = first_delay


func _physics_process(delta: float) -> void:
	if brawl == null or not brawl.match_running:
		return
	if enabled:
		_tick_spawn(delta)
	_tick_boxes()
	_tick_traps(delta)
	_tick_banana(delta)


func _tick_spawn(delta: float) -> void:
	if boxes.size() >= max_boxes:
		return
	_next_in -= delta
	if _next_in > 0.0:
		return
	_next_in = spawn_interval
	if spawn_box() == null:
		_next_in = 1.0


func _tick_boxes() -> void:
	for box: ItemBox in boxes.duplicate():
		if not is_instance_valid(box):
			boxes.erase(box)
			continue
		if _on_stall_spike(box.position):
			_remove_box(box)
			continue
		for ball in brawl.balls:
			if ball.dead or held[brawl.balls.find(ball)] != "":
				continue
			if ball.global_position.distance_to(box.position) <= ball.radius + PICK_REACH:
				_pick(box, ball)
				break


func _pick(box: ItemBox, ball: Ball) -> void:
	var id := box.item_id
	_remove_box(box)
	give(ball, id)
	item_picked.emit(ball, id)


func spawn_box(id := "", at := Vector2.INF) -> ItemBox:
	if brawl == null or not brawl.match_running:
		return null
	if id == "":
		id = _random_id()
	if not ITEM_IDS.has(id):
		return null
	var pos := at if at.is_finite() else _find_spot()
	if not pos.is_finite():
		return null
	var box := ItemBox.new()
	box.item_id = id
	box.position = pos
	brawl.level.add_child(box)
	boxes.append(box)
	_last_id = id
	return box


func give(ball: Ball, id: String) -> void:
	var i := brawl.balls.find(ball) if brawl != null else -1
	if i < 0 or not ITEM_IDS.has(id) or not brawl.match_running:
		return
	_drop_gun(ball)
	held[i] = id
	if id == "gun":
		ball.add_ammo(GUN_SHOTS)
		ball.bullet_knockback = gun_knockback
	_refresh_hud(i)


func use(ball: Ball) -> void:
	var i := brawl.balls.find(ball) if brawl != null else -1
	if i < 0 or not brawl.match_running or ball.dead:
		return
	var id: String = held[i]
	var used := false
	match id:
		"gun":
			used = _use_gun(ball, i)
		"banana":
			used = _use_banana(ball, i)
		"swap":
			used = _use_swap(ball, i)
		"spring":
			used = _use_spring(ball, i)
	if used:
		item_used.emit(ball, id)


func _use_gun(ball: Ball, i: int) -> bool:
	var before := ball.ammo
	ball.shoot()
	if ball.ammo >= before:
		return false
	if ball.ammo <= 0:
		_clear_hand(i)
	else:
		_refresh_hud(i)
	return true


func _use_banana(ball: Ball, i: int) -> bool:
	var target := brawl.opponent_of(ball)
	if target.dead:
		return false
	_clear_hand(i)
	_start_banana(target)
	brawl.hud.flash("BANANA! %s IS DIZZY!" % brawl.player_name(target), 1.0, BrawlHud.PLAYER_COLORS[i])
	return true


func _use_swap(ball: Ball, i: int) -> bool:
	if brawl.opponent_of(ball).dead or brawl.events == null:
		return false
	if not brawl.events.swap_players():
		return false
	_clear_hand(i)
	brawl.hud.flash("%s SWAPPED PLACES!" % brawl.player_name(ball), 0.8, BrawlHud.PLAYER_COLORS[i])
	return true


func _use_spring(ball: Ball, i: int) -> bool:
	var feet := _ground_below(ball)
	if not feet.is_finite():
		return false
	_clear_hand(i)
	var trap := SpringTrap.new()
	trap.position = feet
	trap.owner_ball = ball
	brawl.level.add_child(trap)
	traps.append(trap)
	return true


func _start_banana(victim: Ball) -> void:
	var j := brawl.balls.find(victim)
	_banana_left[j] = banana_seconds
	if _banana_marks[j] == null or not is_instance_valid(_banana_marks[j]):
		var mark := BananaMark.new()
		mark.ball = victim
		victim.add_child(mark)
		_banana_marks[j] = mark
	_banana_marks[j].time_left = banana_seconds
	_sync_reverse(victim)


func _end_banana(ball: Ball) -> void:
	var j := brawl.balls.find(ball)
	_banana_left[j] = 0.0
	if _banana_marks[j] != null:
		if is_instance_valid(_banana_marks[j]):
			ball.remove_child(_banana_marks[j])
			_banana_marks[j].queue_free()
		_banana_marks[j] = null
	_sync_reverse(ball)


func _tick_banana(delta: float) -> void:
	for j in 2:
		if _banana_left[j] <= 0.0:
			continue
		_banana_left[j] -= delta
		if _banana_marks[j] != null and is_instance_valid(_banana_marks[j]):
			_banana_marks[j].time_left = _banana_left[j]
		if _banana_left[j] <= 0.0:
			_end_banana(brawl.balls[j])


func _sync_reverse(ball: Ball) -> void:
	var j := brawl.balls.find(ball)
	var banana: bool = _banana_left[j] > 0.0
	var event: bool = brawl.events != null and brawl.events.active_event == "reversed_keys"
	var want := banana or event
	if ball.reverse_controls != want:
		ball.reverse_controls = want


func _on_event_changed(_id: String) -> void:
	for ball in brawl.balls:
		_sync_reverse(ball)


func _on_match_started() -> void:
	_clear_all()
	_next_in = first_delay


func _on_match_over(_winner: Ball) -> void:
	_clear_all()


func _on_point_scored(_scorer: Ball, victim: Ball, _cause: String) -> void:
	_clear_player(victim)


func _on_player_respawned(ball: Ball) -> void:
	_clear_player(ball)


func _on_ammo_changed(ammo: int, ball: Ball) -> void:
	var i := brawl.balls.find(ball)
	if i >= 0 and held[i] == "gun":
		brawl.hud.set_item(ball.player_id, "gun", ammo)


func _clear_all() -> void:
	for box in boxes.duplicate():
		_remove_box(box, false)
	for trap in traps.duplicate():
		_remove_trap(trap, false)
	for ball in brawl.balls:
		_clear_player(ball)


func _clear_player(ball: Ball) -> void:
	var i := brawl.balls.find(ball)
	_clear_hand(i)
	_end_banana(ball)


func _clear_hand(i: int) -> void:
	if held[i] == "gun":
		_drop_gun(brawl.balls[i])
	held[i] = ""
	_refresh_hud(i)


func _drop_gun(ball: Ball) -> void:
	if ball.bullet_knockback > 0.0 or held[brawl.balls.find(ball)] == "gun":
		ball.ammo = 0
		ball.bullet_knockback = 0.0


func _refresh_hud(i: int) -> void:
	var ball := brawl.balls[i]
	brawl.hud.set_item(ball.player_id, held[i], ball.ammo if held[i] == "gun" else 0)


func is_valid_spot(pos: Vector2) -> bool:
	var level := brawl.level
	var floor_y := pos.y + BOX_LIFT
	var r := roundi(floor_y / Level.TILE)
	if absf(floor_y - r * Level.TILE) > 1.0:
		return false
	var c := floori(pos.x / Level.TILE)
	if level.char_at(r, c) != "#":
		return false
	if level.char_at(r - 1, c) != "." or level.char_at(r - 2, c) != ".":
		return false
	for dc in [-1, 0, 1]:
		var ch := level.char_at(r - 1, c + dc)
		if ch == "^" or ch == "T":
			return false
	return not _on_stall_spike(Vector2(pos.x, floor_y))


func _find_spot() -> Vector2:
	var level := brawl.level
	var spots: Array[Vector2] = []
	for r in range(2, level.rows.size()):
		for c in range(1, level.cols - 1):
			var pos := Vector2((c + 0.5) * Level.TILE, r * Level.TILE - BOX_LIFT)
			if not is_valid_spot(pos):
				continue
			var far := true
			for ball in brawl.balls:
				far = far and ball.global_position.distance_to(pos) >= SPOT_BALL_GAP
			for box in boxes:
				far = far and box.position.distance_to(pos) >= SPOT_BOX_GAP
			if far:
				spots.append(pos)
	if spots.is_empty():
		return Vector2.INF
	return spots[randi() % spots.size()]


func _random_id() -> String:
	var options: Array[String] = []
	for id in ITEM_IDS:
		if id != _last_id:
			options.append(id)
	return options[randi() % options.size()]


func _on_stall_spike(pos: Vector2) -> bool:
	for s in brawl.stall_spikes:
		if is_instance_valid(s) and absf(s.position.x - pos.x) < 36.0 and absf(s.position.y - pos.y) < 40.0:
			return true
	return false


func _remove_box(box: ItemBox, fx := true) -> void:
	boxes.erase(box)
	if not is_instance_valid(box):
		return
	if fx:
		_burst(box.position, Color("#f7d046"), 12, 60.0, 200.0, 0.4)
	box.get_parent().remove_child(box)
	box.queue_free()


func _ground_below(ball: Ball) -> Vector2:
	var from := ball.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, GROUND_REACH), 1)
	var hit := brawl.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2.INF
	return hit["position"]


func _tick_traps(delta: float) -> void:
	for trap: SpringTrap in traps.duplicate():
		if not is_instance_valid(trap):
			traps.erase(trap)
			continue
		trap.age += delta
		trap.armed = trap.age >= spring_arm_seconds
		trap.life_left = spring_life_seconds - trap.age
		if trap.life_left <= 0.0:
			_remove_trap(trap)
			continue
		if not trap.armed:
			continue
		for ball in brawl.balls:
			if ball.dead or not _trap_touches(trap, ball):
				continue
			ball.bounce_up(spring_launch)
			_burst(trap.position + Vector2(0.0, -16.0), Color("#e8455a"), 14, 80.0, 260.0, 0.45)
			_remove_trap(trap, false)
			trap_sprung.emit(ball)
			break


func _trap_touches(trap: SpringTrap, ball: Ball) -> bool:
	var area := Rect2(trap.position + Vector2(-TRAP_HALF_WIDTH, -TRAP_HEIGHT), Vector2(TRAP_HALF_WIDTH * 2.0, TRAP_HEIGHT))
	var c := ball.global_position
	var nearest := Vector2(clampf(c.x, area.position.x, area.end.x), clampf(c.y, area.position.y, area.end.y))
	return c.distance_to(nearest) <= ball.radius


func _remove_trap(trap: SpringTrap, fx := true) -> void:
	traps.erase(trap)
	if not is_instance_valid(trap):
		return
	if fx:
		_burst(trap.position + Vector2(0.0, -12.0), Color("#b8c0c8"), 8, 40.0, 120.0, 0.35)
	trap.get_parent().remove_child(trap)
	trap.queue_free()


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
	p.scale_amount_max = 6.0
	p.color = color
	p.position = pos
	brawl.level.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)


class ItemBox extends Node2D:
	const PX := 4.0
	var item_id := ""
	var _time := 0.0

	func _ready() -> void:
		z_index = 5
		scale = Vector2.ZERO
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_time * 3.0) * 3.0
		draw_rect(Rect2(Vector2(-17.0, BrawlItems.BOX_LIFT - 2.0), Vector2(34.0, 4.0)), Color(0, 0, 0, 0.35))
		draw_circle(Vector2(0.0, bob), 31.0, Color(1.0, 0.85, 0.3, 0.16 + 0.1 * sin(_time * 5.0)))
		PixelArt.draw_centered(self, PixelArt.ITEM_BOX, Vector2(0.0, bob), PX)


class SpringTrap extends Node2D:
	const PX := 4.0
	var armed := false
	var age := 0.0
	var life_left := 12.0
	var owner_ball: Ball = null
	var _time := 0.0

	func _init() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var tint := Color.WHITE
		var lift := 0.0
		if not armed:
			tint = Color(0.8, 0.9, 1.0, 0.4 + 0.25 * sin(_time * 22.0))
		else:
			lift = absf(sin(_time * 9.0)) * 3.0
			if life_left < 3.0 and int(_time * 8.0) % 2 == 0:
				tint = Color(1, 1, 1, 0.35)
		PixelArt.draw(self, PixelArt.SPRING, Vector2(-20.0, -32.0 - lift), PX, tint)
		if armed:
			var y := -44.0 - lift - 3.0 * sin(_time * 6.0)
			draw_polyline(PackedVector2Array([Vector2(-8, y), Vector2(0, y - 8), Vector2(8, y)]), Color("#fff2a0"), 3.0)


class BananaMark extends Node2D:
	var ball: Ball = null
	var time_left := 3.0
	var _time := 0.0

	func _init() -> void:
		z_index = 12

	func _process(delta: float) -> void:
		_time += delta
		visible = not ball.dead
		position = Vector2(0.0, -36.0 * ball.size_factor)
		queue_redraw()

	func _draw() -> void:
		if time_left < 0.9 and int(_time * 10.0) % 2 == 0:
			return
		var f := ball.size_factor
		for k in 3:
			var a := _time * 6.0 + k * TAU / 3.0
			PixelArt.draw_centered(self, PixelArt.BANANA, Vector2(cos(a) * 38.0 * f, sin(a) * 10.0 * f), 3.0)
