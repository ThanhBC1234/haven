class_name SpinnerIcon
extends Control

@export var sheet: Texture2D = preload("res://assets/ui/spinner_4.png")
@export var fps := 10.0
@export var pixel_scale := 3.0
@export var tint := Color.WHITE

const FRAME := 14.0

var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * FRAME * pixel_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if sheet == null:
		return
	var frames := maxi(1, int(sheet.get_width() / FRAME))
	var i := int(_time * fps) % frames
	var dst := Vector2.ONE * FRAME * pixel_scale
	draw_texture_rect_region(sheet, Rect2((size - dst) / 2.0, dst), Rect2(i * FRAME, 0, FRAME, FRAME), tint)
