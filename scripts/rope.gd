class_name Rope
extends Node2D

signal bead_added
signal beads_dropped(count: int)

const TILE := 32.0
const ATTACH := Vector2(0.0, -4.0)
const DAMP_RAMP := 16.0
const SEGMENTS := 18
const BEAD_END := 0.03
const BEAD_GAP_PX := 15.0
const BEAD_DEADZONE := 6.0
const BEAD_SPEED_PER_PX := 0.012
const BEAD_MAX_SPEED := 1.2
const STEAL_LOCK := 2.5
const ANCHOR_MASS_SCALE := 4.0
const ANCHOR_FRICTION := 4.0
const ANCHOR_BRAKE := 14.0
const ANCHOR_AIR_GRACE := 0.9
const ANCHOR_ICON_PX := 3.0

static var _bead_tex: ImageTexture = null

@export var rest_length := 160.0
@export var max_length := 320.0
@export var stiffness := 16.0
@export var damping := 3.0
@export var hard_stiffness := 320.0
@export var hard_damping := 12.0
@export var anchor_force_scale := 0.1
@export var anchor_enabled := true
var cut := false
var beads: Array = []
var ball_a: Ball = null
var ball_b: Ball = null
var freeze_beads := false
var _tension := 0.0
var _length := 0.0
var _anchored: Array[bool] = [false, false]
var _saved_material: Array = [null, null]
var _saved_mass: Array[float] = [1.0, 1.0]
var _air: Array[float] = [0.0, 0.0]
var _jumped: Array[bool] = [false, false]
var _time := 0.0


class Bead extends RefCounted:
	var t := 0.5
	var lock := 0.0
	var pop := 0.0


func setup(a: Ball, b: Ball) -> void:
	ball_a = a
	ball_b = b
	_length = _end(a).distance_to(_end(b))
	a.launched.connect(func() -> void: _jumped[0] = true)
	b.launched.connect(func() -> void: _jumped[1] = true)


func current_length() -> float:
	return _length


func tension() -> float:
	return _tension


func is_anchored(ball: Ball) -> bool:
	return _anchored[0] if ball == ball_a else (_anchored[1] if ball == ball_b else false)


func reset() -> void:
	for i in 2:
		_exit_anchor(i)
	_tension = 0.0
	if is_instance_valid(ball_a) and is_instance_valid(ball_b):
		_length = _end(ball_a).distance_to(_end(ball_b))
	queue_redraw()


func _end(ball: Ball) -> Vector2:
	return ball.global_position + ATTACH * ball.size_factor


func point_at(t: float) -> Vector2:
	var pa := _end(ball_a)
	var pb := _end(ball_b)
	var sag := _sag(pa.distance_to(pb))
	return pa.lerp(pb, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t))


func _sag(dist: float) -> float:
	if cut or dist >= rest_length:
		return 0.0
	return minf(sqrt(3.0 * maxf(dist, 24.0) * (rest_length - dist) / 8.0), rest_length * 0.45)


func _physics_process(delta: float) -> void:
	if ball_a == null or ball_b == null:
		return
	_time += delta
	_update_anchors(delta)
	_update_beads(delta)
	_apply_force(delta)
	queue_redraw()


func _apply_force(delta: float) -> void:
	_tension = 0.0
	var pa := _end(ball_a)
	var pb := _end(ball_b)
	var offset := pb - pa
	_length = offset.length()
	if cut or ball_a.dead or ball_b.dead or _length < 1.0:
		return
	var stretch := _length - rest_length
	if stretch <= 0.0:
		return
	var dir := offset / _length
	var force := stiffness * stretch
	if _length > max_length:
		force += hard_stiffness * (_length - max_length)
	var closing := (ball_b.linear_velocity - ball_a.linear_velocity).dot(dir)
	if closing > 0.0:
		force += damping * closing * minf(1.0, stretch / DAMP_RAMP)
		if _length > max_length:
			force += hard_damping * closing
	_tension = force
	_pull(0, dir, force, delta)
	_pull(1, -dir, force, delta)


func _pull(i: int, dir: Vector2, force: float, delta: float) -> void:
	var ball: Ball = ball_a if i == 0 else ball_b
	var factor := anchor_force_scale if _anchored[i] else 1.0
	var m: float = _saved_mass[i] if _anchored[i] else ball.mass
	ball.knockback(dir * (force * factor * delta / maxf(m, 0.01)))


func _update_anchors(delta: float) -> void:
	for i in 2:
		var ball: Ball = ball_a if i == 0 else ball_b
		if ball.on_ground:
			_air[i] = 0.0
		else:
			_air[i] += delta
			_jumped[i] = false
		var holding := anchor_enabled and not cut and ball.is_use_held()
		var want := holding and not _jumped[i] and (ball.on_ground or (_anchored[i] and _air[i] < ANCHOR_AIR_GRACE))
		if want and not _anchored[i]:
			_enter_anchor(i, ball)
		elif not want and _anchored[i]:
			_exit_anchor(i)
		if _anchored[i]:
			ball.knockback(Vector2(-ball.linear_velocity.x * minf(1.0, ANCHOR_BRAKE * delta), 0.0))


func _enter_anchor(i: int, ball: Ball) -> void:
	_anchored[i] = true
	_saved_material[i] = ball.physics_material_override
	_saved_mass[i] = ball.mass
	var mat := PhysicsMaterial.new()
	mat.friction = ANCHOR_FRICTION
	mat.bounce = 0.0
	ball.physics_material_override = mat
	ball.mass = _saved_mass[i] * ANCHOR_MASS_SCALE


func _exit_anchor(i: int) -> void:
	if not _anchored[i]:
		return
	_anchored[i] = false
	var ball: Ball = ball_a if i == 0 else ball_b
	if is_instance_valid(ball):
		ball.physics_material_override = _saved_material[i]
		ball.mass = _saved_mass[i]
	_saved_material[i] = null


func _exit_tree() -> void:
	reset()


func add_bead(t := 0.5) -> Bead:
	var bead := Bead.new()
	bead.t = clampf(t, BEAD_END, 1.0 - BEAD_END)
	bead.pop = 0.35
	beads.append(bead)
	_separate()
	bead_added.emit()
	return bead


func remove_bead(bead: Bead) -> void:
	beads.erase(bead)


func bead_counts() -> Vector2i:
	var counts := Vector2i.ZERO
	for bead in beads:
		if absf(bead.t - 0.5) < 0.001:
			continue
		if bead.t < 0.5:
			counts.x += 1
		else:
			counts.y += 1
	return counts


func steal_bead(thief: Ball, victim: Ball) -> bool:
	if beads.is_empty() or thief == victim:
		return false
	var victim_is_a := victim == ball_a
	var pick: Bead = null
	for bead in beads:
		if pick == null or (bead.t < pick.t if victim_is_a else bead.t > pick.t):
			pick = bead
	pick.t = (1.0 - BEAD_END) if victim_is_a else BEAD_END
	pick.lock = STEAL_LOCK
	pick.pop = 0.35
	_separate()
	return true


func drop_beads(player: int) -> int:
	var side: Array = []
	for bead in beads:
		if player == 1 and bead.t < 0.5 - 0.001:
			side.append(bead)
		elif player == 2 and bead.t > 0.5 + 0.001:
			side.append(bead)
	side.sort_custom(func(x: Bead, y: Bead) -> bool: return x.t < y.t if player == 1 else x.t > y.t)
	var count := ceili(side.size() / 2.0)
	for i in count:
		beads.erase(side[i])
	if count > 0:
		beads_dropped.emit(count)
	return count


func _spacing() -> float:
	var by_length := BEAD_GAP_PX / maxf(_length, 48.0)
	return minf(by_length, (1.0 - 2.0 * BEAD_END) * 0.98 / maxf(beads.size(), 1.0))


func _separate() -> void:
	var n := beads.size()
	if n < 2:
		return
	beads.sort_custom(func(x: Bead, y: Bead) -> bool: return x.t < y.t)
	var s := _spacing()
	for _pass in 8:
		var moved := false
		for i in range(1, n):
			var gap: float = beads[i].t - beads[i - 1].t
			if gap < s - 0.0001:
				var push := (s - gap) * 0.5
				beads[i - 1].t -= push
				beads[i].t += push
				moved = true
		if not moved:
			break
	beads[0].t = maxf(beads[0].t, BEAD_END)
	for i in range(1, n):
		beads[i].t = maxf(beads[i].t, beads[i - 1].t + s)
	beads[n - 1].t = minf(beads[n - 1].t, 1.0 - BEAD_END)
	for i in range(n - 2, -1, -1):
		beads[i].t = minf(beads[i].t, beads[i + 1].t - s)


func _update_beads(delta: float) -> void:
	for bead in beads:
		bead.lock = maxf(0.0, bead.lock - delta)
		bead.pop = maxf(0.0, bead.pop - delta)
	if beads.is_empty() or freeze_beads or cut or ball_a.dead or ball_b.dead:
		return
	var dy := ball_b.global_position.y - ball_a.global_position.y
	if absf(dy) < BEAD_DEADZONE:
		_separate()
		return
	var speed := clampf(dy * BEAD_SPEED_PER_PX, -BEAD_MAX_SPEED, BEAD_MAX_SPEED)
	var s := _spacing()
	beads.sort_custom(func(x: Bead, y: Bead) -> bool: return x.t < y.t)
	var n := beads.size()
	if speed > 0.0:
		for i in range(n - 1, -1, -1):
			var bead: Bead = beads[i]
			var limit: float = (1.0 - BEAD_END) if i == n - 1 else beads[i + 1].t - s
			if bead.lock <= 0.0:
				bead.t = maxf(bead.t, minf(bead.t + speed * delta, limit))
	else:
		for i in n:
			var bead: Bead = beads[i]
			var limit: float = BEAD_END if i == 0 else beads[i - 1].t + s
			if bead.lock <= 0.0:
				bead.t = minf(bead.t, maxf(bead.t + speed * delta, limit))


static func bead_texture() -> ImageTexture:
	if _bead_tex != null:
		return _bead_tex
	var pattern: Array = Hud.STAR
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for y in 9:
		for x in 9:
			var on := _star_on(pattern, x - 1, y - 1)
			if on:
				img.set_pixel(x, y, Color("#ffe27a") if y <= 3 else Color("#f7d046"))
			elif _star_on(pattern, x - 2, y - 1) or _star_on(pattern, x, y - 1) or _star_on(pattern, x - 1, y - 2) or _star_on(pattern, x - 1, y):
				img.set_pixel(x, y, Color("#6b4b0a"))
	_bead_tex = ImageTexture.create_from_image(img)
	return _bead_tex


static func _star_on(pattern: Array, x: int, y: int) -> bool:
	return y >= 0 and y < pattern.size() and x >= 0 and x < String(pattern[y]).length() and pattern[y][x] == "1"


func _draw() -> void:
	if cut or ball_a == null or ball_b == null:
		return
	var pts := PackedVector2Array()
	for i in SEGMENTS + 1:
		pts.append(to_local(point_at(float(i) / SEGMENTS)).snapped(Vector2(2.0, 2.0)))
	var taut := clampf(_tension / 2400.0, 0.0, 1.0)
	draw_polyline(pts, Color("#2e1f0e"), 8.0)
	draw_polyline(pts, Color("#c9a45c").lerp(Color("#e8455a"), taut), 4.0)
	var tex := bead_texture()
	for bead: Bead in beads:
		var center := to_local(point_at(bead.t)).snapped(Vector2(2.0, 2.0))
		var grow: float = 1.0 + bead.pop * 2.0
		var size_px: Vector2 = Vector2(18.0, 18.0) * grow
		draw_texture_rect(tex, Rect2(center - size_px / 2.0, size_px), false)
	for i in 2:
		if _anchored[i]:
			var ball: Ball = ball_a if i == 0 else ball_b
			var bob := sin(_time * 6.0) * 2.0
			PixelArt.draw_centered(self, PixelArt.ANCHOR, to_local(ball.global_position) + Vector2(0.0, -72.0 * ball.size_factor + bob).snapped(Vector2(2.0, 2.0)), ANCHOR_ICON_PX)
