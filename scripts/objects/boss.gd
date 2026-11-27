class_name Boss
extends Node2D

signal hp_changed(hp: int, max_hp: int)
signal died

enum State { SLEEP, ROLL, WARN, CHARGE, DIZZY }

@export var boss_name := "MAX VERSTAPPEN"
@export var max_hp := 24
@export var wake_distance := 800.0
@export var roam := 448.0

@export_group("Lăn và lao")
@export var roll_speed := 100.0
@export var phase2_roll_speed := 150.0
@export var charge_speed := 240.0
@export var phase2_charge_speed := 300.0
@export var charge_every := 5.0
@export var phase2_charge_every := 3.2
@export var warn_time := 0.5
@export var dizzy_time := 1.0

@export_group("Dẫm và hình")
@export var stomp_bounce := 620.0
@export var radius := 30.0
@export var pixel_size := 4.0
@export var show_placeholder := true

var hp := 0
var dead := false
var state := State.SLEEP
var dir := -1
var _timer := 0.0
var _spin := 0.0
var _flash := 0.0
var _t := 0.0
var _home_x := 0.0
var _snapped := false
var _stomp_cd := 0.0

@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	hp = max_hp
	_home_x = position.x
	hurtbox.body_entered.connect(_on_touch)


func _snap_to_ground() -> void:
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 600), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit["position"].y - radius


func is_phase2() -> bool:
	return hp <= max_hp / 2


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not _snapped:
		_snapped = true
		_snap_to_ground()
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_stomp_cd = maxf(0.0, _stomp_cd - delta)
	for body in hurtbox.get_overlapping_bodies():
		_on_touch(body)
	var ball := get_tree().get_first_node_in_group("ball") as Ball
	match state:
		State.SLEEP:
			if ball and absf(ball.global_position.x - global_position.x) < wake_distance:
				_wake()
		State.ROLL:
			_roll(phase2_roll_speed if is_phase2() else roll_speed, delta)
			_timer -= delta
			if _timer <= 0.0 and ball and not ball.dead:
				state = State.WARN
				_timer = warn_time
				dir = 1 if ball.global_position.x > global_position.x else -1
		State.WARN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHARGE
		State.CHARGE:
			if _roll(phase2_charge_speed if is_phase2() else charge_speed, delta):
				state = State.DIZZY
				_timer = dizzy_time
		State.DIZZY:
			_timer -= delta
			if _timer <= 0.0:
				state = State.ROLL
				_timer = phase2_charge_every if is_phase2() else charge_every
	queue_redraw()


func _roll(speed: float, delta: float) -> bool:
	var step := speed * delta
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (radius + step + 2.0), 0), 1)
	var out_of_area := absf(position.x + dir * step - _home_x) > roam
	if out_of_area or not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		dir = -dir
		return true
	position.x += dir * step
	_spin += dir * step / radius
	return false


func _wake() -> void:
	state = State.ROLL
	_timer = 2.0
	var level := Level.of(self)
	if level:
		level.start_boss(self)
	hp_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
	if dead:
		return
	if state == State.SLEEP:
		_wake()
	hp = maxi(0, hp - amount)
	Sfx.play("boss_hit")
	_flash = 0.12
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		_die()


func _die() -> void:
	dead = true
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	died.emit()
	Sfx.play("explosion")
	Sfx.play("win_match")
	var level := Level.of(self)
	if level:
		level.defeat_boss(self)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.0
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 6.0
	p.color = PixelArt.PALETTE["p"]
	p.position = position
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.2), 0.25)
	tw.tween_callback(queue_free)


func _on_touch(body: Node2D) -> void:
	if dead or not body is Ball or body.dead:
		return
	if body.global_position.distance_to(global_position) > radius + body.radius + 8.0:
		return
	var above: bool = body.global_position.y < global_position.y - radius * 0.5
	if not above:
		body.take_hit()
	elif body.linear_velocity.y > -60.0 and _stomp_cd <= 0.0:
		_stomp_cd = 0.3
		body.bounce_up(stomp_bounce)
		take_damage(1)


func _draw() -> void:
	if not show_placeholder:
		return
	var tint := Color(1.0, 0.65, 0.65) if is_phase2() else Color.WHITE
	if _flash > 0.0:
		tint = Color(3, 3, 3)
	var shake := Vector2(sin(_t * 70.0) * 2.0, 0) if state == State.WARN else Vector2.ZERO
	draw_set_transform(shake, _spin)
	PixelArt.draw_centered(self, PixelArt.BOSS, Vector2.ZERO, pixel_size, tint)
	draw_set_transform(Vector2.ZERO)
	if state == State.WARN:
		PixelArt.draw_centered(self, PixelArt.EXCLAIM, Vector2(0, -radius - 26), 4.0)
	elif state == State.DIZZY:
		for i in 3:
			var a := _t * 5.0 + i * TAU / 3.0
			var p := Vector2(cos(a) * 22.0, -radius - 10 + sin(a) * 6.0)
			draw_rect(Rect2(p.snapped(Vector2(2, 2)) - Vector2(3, 3), Vector2(6, 6)), PixelArt.PALETTE["y"])
