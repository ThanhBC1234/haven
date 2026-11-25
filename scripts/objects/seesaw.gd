class_name Seesaw
extends Node2D

@export var length_tiles := 5
@export var plank_mass := 2.0
@export var max_tilt_deg := 22.0
@export var show_placeholder := true

const TILE := 32.0

var plank: RigidBody2D


func _ready() -> void:
	var pivot := StaticBody2D.new()
	pivot.collision_layer = 0
	add_child(pivot)

	plank = RigidBody2D.new()
	plank.mass = plank_mass
	plank.collision_layer = 1
	plank.collision_mask = 1 | 2 | 8
	plank.can_sleep = false
	plank.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	plank.physics_material_override = mat
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length_tiles * TILE, 10)
	shape.shape = rect
	plank.add_child(shape)
	add_child(plank)

	var joint := PinJoint2D.new()
	add_child(joint)
	joint.node_a = joint.get_path_to(pivot)
	joint.node_b = joint.get_path_to(plank)

	var half := length_tiles * TILE / 2.0
	var drop := (half - 6.0) * sin(deg_to_rad(max_tilt_deg)) + 5.0 + 3.0
	for side in [-1.0, 1.0]:
		var stop := StaticBody2D.new()
		stop.collision_layer = 16
		stop.collision_mask = 0
		var stop_shape := CollisionShape2D.new()
		var stop_rect := RectangleShape2D.new()
		stop_rect.size = Vector2(16, 12)
		stop_shape.shape = stop_rect
		stop.add_child(stop_shape)
		stop.position = Vector2(side * (half - 6.0), drop + 3.0)
		add_child(stop)
	plank.collision_mask |= 16


func _process(_delta: float) -> void:
	if show_placeholder:
		queue_redraw()


func _draw() -> void:
	if not show_placeholder or plank == null:
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-10, 18), Vector2(10, 18)]), Color("#6b5a4a"))
	draw_set_transform(plank.position, plank.rotation)
	var w := length_tiles * TILE
	draw_rect(Rect2(-w / 2, -5, w, 10), Color("#d69a5a"))
	draw_rect(Rect2(-w / 2, -5, w, 10), Color("#7a4f28"), false, 1.0)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, 3.0, Color("#3a2f25"))
