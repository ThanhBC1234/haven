class_name MovingPlatform
extends AnimatableBody2D

@export var width_tiles := 3
@export var speed := 70.0
@export var pause := 0.6
@export var show_placeholder := true

const TILE := 32.0
const THICK := 12.0

var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0
var _going := 1.0
var _wait := 0.0


func _ready() -> void:
	sync_to_physics = true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * TILE, THICK)
	$Shape.shape = shape
	$Shape.position = shape.size / 2.0
	position = from


func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	var length := from.distance_to(to)
	if length < 1.0:
		return
	_t += _going * speed * delta / length
	if _t >= 1.0 or _t <= 0.0:
		_t = clampf(_t, 0.0, 1.0)
		_going = -_going
		_wait = pause
	position = from.lerp(to, _t)


func _draw() -> void:
	if not show_placeholder:
		return
	var tex: Texture2D = preload("res://assets/forest/forest_decorations.png")
	for i in width_tiles:
		var src := Rect2(32 + (i % 6) * 16, 32, 16, 6)
		draw_texture_rect_region(tex, Rect2(i * TILE, 0, TILE, THICK), src)
	draw_rect(Rect2(0, 0, width_tiles * TILE, THICK), Color("#05080c"), false, 1.0)
