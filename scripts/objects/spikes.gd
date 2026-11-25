class_name Spikes
extends Area2D

@export var show_placeholder := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Ball:
		body.take_hit()


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _draw() -> void:
	if not show_placeholder:
		return
	for x in [-16.0, 0.0]:
		var tri := PackedVector2Array([Vector2(x, 0), Vector2(x + 8, -16), Vector2(x + 16, 0)])
		draw_colored_polygon(tri, Color("#b9c4b0"))
		draw_polyline(tri, Color("#2a3328"), 1.5)
