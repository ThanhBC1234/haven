extends Node2D

@export var pixel_scale := 2.0

@export_group("Trái banh bẹp khi chạm đất")
@export var land_squash := 0.0006
@export var ball_stiffness := 420.0
@export var ball_damping := 16.0

@export_group("Lò xo nén / giãn")
@export var charge_compress := 0.45
@export var jump_stretch := 0.55
@export var spring_stiffness := 260.0
@export var spring_damping := 9.0

@export_group("Đầu lắc trễ")
@export var head_follow := 150.0
@export var head_damping := 7.0

@export_group("Dẹt như cái bánh (flatten)")
@export var flat_stiffness := 300.0
@export var flat_damping := 14.0
@export var flat_wide := 0.9
@export var flat_thin := 0.85

const BALL_H := 15.0
const SPRING_H := 9.0
const OVERLAP := 1.0

var _squash := 0.0
var _squash_vel := 0.0
var _compress := 0.0
var _compress_vel := 0.0
var _head_angle := 0.0
var _head_vel := 0.0
var _size := 1.0
var _flat := 0.0
var _flat_vel := 0.0
var _flat_time := 0.0

@onready var ball: Ball = get_parent()
@onready var ball_part: Sprite2D = $BallPart
@onready var spring: Sprite2D = $Spring
@onready var head: Sprite2D = $Head


func _ready() -> void:
	position = Vector2(0, ball.radius)
	scale = Vector2.ONE * pixel_scale * _size
	show_behind_parent = true
	ball.landed.connect(_on_landed)
	ball.launched.connect(_on_launched)


func set_size_factor(factor: float) -> void:
	_size = factor
	if not is_node_ready():
		return
	position = Vector2(0, ball.radius)
	_layout()


func flatten(seconds: float) -> void:
	_flat_time = maxf(_flat_time, seconds)


func _on_landed(impact_speed: float) -> void:
	_squash_vel += impact_speed * land_squash * 30.0
	_compress_vel += impact_speed * land_squash * 40.0


func _on_launched() -> void:
	_compress = -jump_stretch
	_compress_vel = 0.0
	_squash = -0.15


func _process(delta: float) -> void:
	var target := charge_compress * ball.charge if ball.charge_dir != 0 else 0.0
	_compress_vel += (-(_compress - target) * spring_stiffness - _compress_vel * spring_damping) * delta
	_compress += _compress_vel * delta

	_squash_vel += (-_squash * ball_stiffness - _squash_vel * ball_damping) * delta
	_squash += _squash_vel * delta

	var head_target := -ball.tilt * 0.6 + clampf(-ball.linear_velocity.x * 0.0008, -0.35, 0.35)
	_head_vel += ((head_target - _head_angle) * head_follow - _head_vel * head_damping) * delta
	_head_angle += _head_vel * delta

	var flat_target := 1.0 if _flat_time > 0.0 else 0.0
	_flat_time = maxf(0.0, _flat_time - delta)
	_flat_vel += (-(_flat - flat_target) * flat_stiffness - _flat_vel * flat_damping) * delta
	_flat += _flat_vel * delta

	_layout()


func _layout() -> void:
	var f := clampf(_flat, -0.3, 1.0)
	scale = Vector2.ONE * pixel_scale * _size * Vector2(1.0 + f * flat_wide, 1.0 - f * flat_thin)
	var sq := clampf(_squash, -0.3, 0.45)
	ball_part.scale = Vector2(1.0 + sq, 1.0 - sq)
	var ball_h := BALL_H * (1.0 - sq)

	var calm := 1.0 - clampf(f, 0.0, 1.0)
	var lean := ball.tilt * calm
	var c := clampf(_compress, -0.7, 0.6)
	spring.scale = Vector2(1.0 + c * 0.25, 1.0 - c)
	var top := Vector2(0, -ball_h + OVERLAP)
	spring.position = top
	spring.rotation = lean
	var spring_h := SPRING_H * (1.0 - c)

	head.position = top + Vector2(0, -spring_h + OVERLAP).rotated(lean)
	head.rotation = lean + _head_angle * calm
