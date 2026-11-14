class_name Door
extends StaticBody2D

@export var channel := "a"
@export var height_tiles := 3
@export var show_placeholder := true

const TILE := 32.0

var is_open := false


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, height_tiles * TILE)
	$Shape.shape = shape
	$Shape.position = shape.size / 2.0
	var level := Level.of(self)
	if level:
		level.channel_changed.connect(_on_channel_changed)


func _on_channel_changed(ch: String, on: bool) -> void:
	if ch != channel:
		return
	is_open = on
	$Shape.set_deferred("disabled", on)
	queue_redraw()


func _draw() -> void:
	if not show_placeholder:
		return
	var color := Level.channel_color(channel)
	var a := 0.18 if is_open else 1.0
	var h := height_tiles * TILE
	draw_rect(Rect2(4, 0, TILE - 8, h), Color(color.darkened(0.6), 0.5 * a))
	for x in [8.0, 16.0, 24.0]:
		draw_line(Vector2(x, 0), Vector2(x, h), Color(color, a), 3.0)
	draw_rect(Rect2(2, 0, TILE - 4, h), Color(color.darkened(0.3), a), false, 2.0)
