class_name Crate
extends RigidBody2D

@export var show_placeholder := true

const SIZE := 30.0

var home := Vector2.ZERO
var _reset_pending := false


func _ready() -> void:
	add_to_group("crates")
	home = global_position


func reset() -> void:
	_reset_pending = true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _reset_pending:
		state.transform = Transform2D(0.0, home)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_reset_pending = false


func _draw() -> void:
	if not show_placeholder:
		return
	var r := Rect2(-SIZE / 2, -SIZE / 2, SIZE, SIZE)
	var wood := Color("#c98a4b")
	draw_rect(r, wood)
	draw_rect(r.grow(-3), wood.darkened(0.2), false, 2.0)
	draw_line(r.position + Vector2(3, 3), r.end - Vector2(3, 3), wood.darkened(0.3), 2.0)
	draw_line(Vector2(r.position.x + 3, r.end.y - 3), Vector2(r.end.x - 3, r.position.y + 3), wood.darkened(0.3), 2.0)
	draw_rect(r, wood.darkened(0.5), false, 1.0)
