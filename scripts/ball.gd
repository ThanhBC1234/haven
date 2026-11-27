class_name Ball
extends RigidBody2D

signal hurt
signal launched
signal landed(impact_speed: float)
signal shield_changed(on: bool)
signal ammo_changed(ammo: int)
signal shot
signal boost_changed(seconds_left: float)
signal use_pressed
signal stomped(victim: Ball)

const BULLET_SCENE := preload("res://scenes/objects/player_bullet.tscn")
const JUMP_BOOST_TEXTURE := preload("res://assets/items/jump_boost.png")
const BALL_LAYER := 2
const SWAP_RB_CODE := "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR.rgb = COLOR.bgr;\n}\n"

static var _swap_rb_shader: Shader = null

@export var radius := 15.0

@export_group("Nghiêng và nhảy")
@export var charge_time := 0.7
@export var min_tilt_deg := 12.0
@export var max_tilt_deg := 42.0
@export var min_speed := 300.0
@export var max_speed := 950.0
@export var coyote_time := 0.12
@export var release_buffer := 0.15
@export var straight_jump := 0.5

@export_group("Lắc lư")
@export var wobble_stiffness := 120.0
@export var wobble_damping := 6.0

@export_group("Súng và khiên")
@export var shoot_cooldown := 0.18
@export var max_ammo := 99
@export var invuln_after_hit := 1.2

@export_group("Jump boost")
@export var boost_duration := 10.0
@export var boost_power := 1.25

@export var show_placeholder := false

@export_group("Hai người chơi")
@export var stomp_speed := 300.0
@export var stomp_bounce := 260.0
@export var stomp_cooldown := 0.4

var action_prefix := "":
	set(value):
		action_prefix = value
		charge_dir = 0
		charge = 0.0
var reverse_controls := false:
	set(value):
		reverse_controls = value
		charge_dir = 0
		charge = 0.0
var player_id := 0
var size_factor := 1.0
var bullet_knockback := 0.0

var on_ground := false
var dead := false
var charge := 0.0
var charge_dir := 0
var tilt := 0.0
var _tilt_vel := 0.0
var _coyote := 0.0
var _jump_request := {}
var _was_on_ground := false
var _last_vy := 0.0
var _teleport_to = null
var _bounce := 0.0
var ammo := 0
var has_shield := false
var invuln := 0.0
var facing := 1
var _shoot_timer := 0.0
var boost_time := 0.0
var _time := 0.0
var _kick := Vector2.ZERO
var _stomp_cd := 0.0
var _touching_balls := {}
var _base_radius := 15.0
var _base_shape_radius := 15.0
var _base_mass := 1.0
var _shape_copied := false
var jump_locked := false
var carried := false
var _carry_layer := 0
var _carry_mask := 0
var _hop_pos := Vector2.ZERO
var _hop_vel := Vector2.ZERO
var _hop_pending := false


func _ready() -> void:
	add_to_group("ball")
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	_base_radius = radius
	_base_mass = mass
	var shape_node := get_node_or_null("Shape") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		_base_shape_radius = shape_node.shape.radius


func _physics_process(delta: float) -> void:
	if not dead and not carried:
		_read_input(delta)
	if not _jump_request.is_empty():
		_jump_request["time"] -= delta
		if _jump_request["time"] <= 0.0:
			_jump_request = {}
	_coyote = maxf(0.0, _coyote - delta)
	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_stomp_cd = maxf(0.0, _stomp_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	if boost_time > 0.0:
		boost_time = maxf(0.0, boost_time - delta)
		boost_changed.emit(boost_time)
	_time += delta
	if charge_dir != 0:
		facing = charge_dir
	elif absf(linear_velocity.x) > 40.0:
		facing = 1 if linear_velocity.x > 0.0 else -1
	if not dead and action_prefix.is_empty() and Input.is_action_just_pressed("shoot"):
		shoot()
	elif not dead and not action_prefix.is_empty() and Input.is_action_just_pressed(action_prefix + "use"):
		use_pressed.emit()
	modulate.a = (0.35 if int(_time * 14.0) % 2 == 0 else 1.0) if invuln > 0.0 else 1.0
	_update_wobble(delta)
	queue_redraw()


func shoot() -> void:
	if ammo <= 0 or _shoot_timer > 0.0 or dead:
		return
	_shoot_timer = shoot_cooldown
	ammo -= 1
	ammo_changed.emit(ammo)
	var dir := Vector2(facing, 0)
	if charge_dir != 0:
		dir = jump_velocity(charge_dir, maxf(charge, 0.3)).normalized()
	var b: Node2D = BULLET_SCENE.instantiate()
	b.direction = dir
	b.shooter = self
	b.knockback = bullet_knockback
	b.position = global_position + Vector2(0, -2) + dir * 22.0
	get_parent().add_child(b)
	shot.emit()


func add_ammo(n: int) -> void:
	ammo = mini(max_ammo, ammo + n)
	ammo_changed.emit(ammo)


func give_jump_boost() -> void:
	boost_time = boost_duration
	boost_changed.emit(boost_time)


func give_shield() -> void:
	has_shield = true
	shield_changed.emit(true)


func _read_input(delta: float) -> void:
	var left := Input.is_action_pressed(_action("left"))
	var right := Input.is_action_pressed(_action("right"))
	if reverse_controls:
		var tmp := left
		left = right
		right = tmp
	if not jump_locked and Input.is_action_just_pressed(_action("jump")):
		jump_with_charge()
		return
	if charge_dir == 0:
		if left and not right:
			charge_dir = -1
		elif right and not left:
			charge_dir = 1
		charge = 0.0
	if charge_dir != 0:
		var holding := left if charge_dir < 0 else right
		if holding:
			charge = minf(1.0, charge + delta / charge_time)
		else:
			charge_dir = 0
			charge = 0.0


func jump_with_charge() -> void:
	if charge_dir != 0:
		jump(charge_dir, charge)
	else:
		jump(0, straight_jump)
	charge_dir = 0
	charge = 0.0


func _action(action: String) -> String:
	return action_prefix + action


func is_use_held() -> bool:
	if dead or carried or action_prefix.is_empty():
		return false
	return Input.is_action_pressed(_action("use"))


func set_player(id: int) -> void:
	if id != 1 and id != 2:
		push_error("Ball.set_player: id must be 1 or 2, got %d" % id)
		return
	player_id = id
	action_prefix = "p%d_" % id
	var sprite := get_node_or_null("Sprite") as Node2D
	if sprite != null:
		if id == 2:
			if _swap_rb_shader == null:
				_swap_rb_shader = Shader.new()
				_swap_rb_shader.code = SWAP_RB_CODE
			var mat := ShaderMaterial.new()
			mat.shader = _swap_rb_shader
			sprite.material = mat
		else:
			sprite.material = null
		for part in sprite.get_children():
			if part is CanvasItem:
				part.use_parent_material = (id == 2)
	queue_redraw()


func set_collide_with_balls(on: bool) -> void:
	set_collision_mask_value(BALL_LAYER, on)


func set_size(factor: float) -> void:
	factor = maxf(factor, 0.1)
	size_factor = factor
	_apply_shape_size.call_deferred()
	radius = _base_radius * factor
	mass = _base_mass * factor * factor
	var sprite := get_node_or_null("Sprite")
	if sprite != null and sprite.has_method("set_size_factor"):
		sprite.set_size_factor(factor)
	queue_redraw()


func _apply_shape_size() -> void:
	var shape_node := get_node_or_null("Shape") as CollisionShape2D
	if shape_node == null or not shape_node.shape is CircleShape2D:
		return
	if not _shape_copied:
		shape_node.shape = shape_node.shape.duplicate()
		_shape_copied = true
	shape_node.shape.radius = _base_shape_radius * size_factor


func flatten(seconds: float) -> void:
	var sprite := get_node_or_null("Sprite")
	if sprite != null and sprite.has_method("flatten"):
		sprite.flatten(seconds)


func knockback(velocity: Vector2) -> void:
	_kick += velocity


func jump(dir: int, amount: float) -> void:
	_jump_request = {"dir": dir, "charge": clampf(amount, 0.0, 1.0), "time": release_buffer}


func jump_velocity(dir: int, amount: float) -> Vector2:
	var speed := lerpf(min_speed, max_speed, amount)
	if boost_time > 0.0:
		speed *= boost_power
	if dir == 0:
		return Vector2(0, -speed)
	var angle := deg_to_rad(lerpf(min_tilt_deg, max_tilt_deg, amount))
	return Vector2(sin(angle) * dir, -cos(angle)) * speed


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _teleport_to != null:
		state.transform = Transform2D(0.0, _teleport_to)
		state.transform = Transform2D(0.0, _teleport_to)
		state.linear_velocity = Vector2.ZERO
		_teleport_to = null
		return

	if carried:
		on_ground = false
		_was_on_ground = false
		_touching_balls = {}
		_kick = Vector2.ZERO
		_bounce = 0.0
		_jump_request = {}
		return
	if _hop_pending:
		_hop_pending = false
		state.transform = Transform2D(0.0, _hop_pos)
		state.transform = Transform2D(0.0, _hop_pos)
		state.linear_velocity = _hop_vel
		_kick = Vector2.ZERO
		_bounce = 0.0
		_jump_request = {}

	on_ground = false
	var touching := {}
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		if normal.y < -0.6:
			on_ground = true
		var other := state.get_contact_collider_object(i) as Ball
		if other != null:
			var id := other.get_instance_id()
			touching[id] = true
			if normal.y < -0.6 and not _touching_balls.has(id) and _last_vy >= stomp_speed \
					and _stomp_cd <= 0.0 and not dead and not other.dead:
				_stomp_cd = stomp_cooldown
				_bounce = maxf(_bounce, stomp_bounce)
				emit_signal.call_deferred("stomped", other)
	_touching_balls = touching
	if on_ground:
		_coyote = coyote_time
		if not _was_on_ground:
			_tilt_vel += state.linear_velocity.x * 0.02
			if _last_vy > 40.0:
				landed.emit(_last_vy)
	_was_on_ground = on_ground
	_last_vy = state.linear_velocity.y
	if dead:
		return

	if not _jump_request.is_empty() and _coyote > 0.0:
		state.linear_velocity = jump_velocity(_jump_request["dir"], _jump_request["charge"])
		_tilt_vel += _jump_request["dir"] * -4.0
		_jump_request = {}
		_coyote = 0.0
		launched.emit()

	if _bounce > 0.0:
		state.linear_velocity.y = -_bounce
		if charge_dir != 0:
			state.linear_velocity.x = charge_dir * lerpf(180.0, 360.0, charge)
		_bounce = 0.0
		_coyote = 0.0

	if _kick != Vector2.ZERO:
		state.linear_velocity += _kick
		_kick = Vector2.ZERO
		_coyote = 0.0


func _update_wobble(delta: float) -> void:
	if charge_dir != 0 and not dead:
		var target := charge_dir * deg_to_rad(lerpf(min_tilt_deg, max_tilt_deg, charge))
		tilt = lerpf(tilt, target, 0.3)
		_tilt_vel = 0.0
		return
	_tilt_vel += (-wobble_stiffness * tilt - wobble_damping * _tilt_vel) * delta
	tilt += _tilt_vel * delta


func teleport(pos: Vector2) -> void:
	_teleport_to = pos
	charge_dir = 0
	charge = 0.0
	_jump_request = {}
	_bounce = 0.0
	_kick = Vector2.ZERO
	_coyote = 0.0
	_hop_pending = false


func begin_carried() -> void:
	if carried:
		return
	carried = true
	_hop_pending = false
	_carry_layer = collision_layer
	_carry_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	charge_dir = 0
	charge = 0.0
	_jump_request = {}
	on_ground = false


func carry_to(pos: Vector2, vel: Vector2) -> void:
	if not carried:
		return
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, pos))
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, vel)
	global_position = pos
	linear_velocity = vel


func end_carried(hop_pos: Variant = null, hop_vel := Vector2.ZERO) -> void:
	if not carried:
		return
	carried = false
	collision_layer = _carry_layer
	collision_mask = _carry_mask
	_jump_request = {}
	charge_dir = 0
	charge = 0.0
	if hop_pos != null:
		_hop_pos = hop_pos
		_hop_vel = hop_vel
		_hop_pending = true


func bounce_up(speed: float) -> void:
	_bounce = speed


func take_hit() -> void:
	if dead or invuln > 0.0:
		return
	if has_shield:
		has_shield = false
		invuln = invuln_after_hit
		shield_changed.emit(false)
		return
	hurt.emit()


func _draw() -> void:
	var base := Vector2(0, radius)
	draw_set_transform(base, tilt)
	if show_placeholder:
		var base_color := Color("#e3a72a")
		var ball_color := Color("#8e1418")
		if player_id == 2:
			base_color = Color(base_color.b, base_color.g, base_color.r)
			ball_color = Color(ball_color.b, ball_color.g, ball_color.r)
		var base_center := Vector2(0, -radius + 1)
		var cup := PackedVector2Array()
		for i in 17:
			var a := PI * i / 16.0
			cup.append(base_center + Vector2(cos(a), sin(a)) * (radius - 1))
		draw_colored_polygon(cup, base_color)
		draw_polyline(cup + PackedVector2Array([cup[0]]), base_color.darkened(0.4), 1.5)
		var ball_center := Vector2(0, -radius - 4)
		var ball_r := radius * 0.7
		draw_circle(ball_center, ball_r, ball_color)
		draw_arc(ball_center, ball_r - 1.5, PI * 0.9, PI * 1.6, 10, ball_color.lightened(0.25), 2.0)
		draw_arc(ball_center, ball_r, 0.0, TAU, 24, ball_color.darkened(0.5), 1.0)
		draw_circle(ball_center + Vector2(-ball_r * 0.35, -ball_r * 0.4), 2.0, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if boost_time > 0.0 and not dead:
		var a := 0.5 + 0.5 * sin(_time * 10.0)
		draw_texture_rect(JUMP_BOOST_TEXTURE, Rect2(Vector2(-12, radius - 8), Vector2(24, 24)), false, Color(1, 1, 1, a))
	if has_shield and not dead:
		var center := Vector2(0, -17) * size_factor
		for i in 28:
			var a := TAU * i / 28.0 + _time * 0.8
			var p := center + Vector2(cos(a), sin(a)) * 38.0 * size_factor
			var col := Color("#7fd6e0") if i % 2 == 0 else Color("#3c8ea0")
			draw_rect(Rect2(p.snapped(Vector2(2, 2)) - Vector2(2, 2), Vector2(4, 4)), Color(col, 0.75))
	if charge_dir != 0 and not dead:
		var v := jump_velocity(charge_dir, charge)
		var start := v.normalized() * (radius + 4.0)
		var tip := v.normalized() * (radius + 14.0 + 30.0 * charge)
		var col := Color(1, 1, 1, 0.85).lerp(Color("#ff5d5d"), charge)
		draw_line(start, tip, col, 3.0)
		var side := tip.normalized().orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([tip + tip.normalized() * 6.0, tip + side, tip - side]), col)
