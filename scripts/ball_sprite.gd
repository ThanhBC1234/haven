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

const BALL_H := 15.0
const SPRING_H := 9.0
const OVERLAP := 1.0

var _squash := 0.0
var _squash_vel := 0.0
var _compress := 0.0
var _compress_vel := 0.0
var _head_angle := 0.0
var _head_vel := 0.0

@onready var ball: Ball = get_parent()
@onready var ball_part: Sprite2D = $BallPart
@onready var spring: Sprite2D = $Spring
@onready var head: Sprite2D = $Head


func _ready() -> void:
	position = Vector2(0, ball.radius)
	scale = Vector2.ONE * pixel_scale
	show_behind_parent = true
	ball.landed.connect(_on_landed)
	ball.launched.connect(_on_launched)


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

	_layout()


func _layout() -> void:
	var sq := clampf(_squash, -0.3, 0.45)
	ball_part.scale = Vector2(1.0 + sq, 1.0 - sq)
	var ball_h := BALL_H * (1.0 - sq)

	var lean := ball.tilt
	var c := clampf(_compress, -0.7, 0.6)
	spring.scale = Vector2(1.0 + c * 0.25, 1.0 - c)
	var top := Vector2(0, -ball_h + OVERLAP)
	spring.position = top
	spring.rotation = lean
	var spring_h := SPRING_H * (1.0 - c)

	head.position = top + Vector2(0, -spring_h + OVERLAP).rotated(lean)
	head.rotation = lean + _head_angle
