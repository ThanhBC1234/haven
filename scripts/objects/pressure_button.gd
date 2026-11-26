class_name PressureButton
extends Area2D

@export var channel := "a"
@export var show_placeholder := true

var pressed := false


func _ready() -> void:
	body_entered.connect(_refresh.unbind(1))
	body_exited.connect(_refresh.unbind(1))


func _refresh() -> void:
	var now := false
	for b in get_overlapping_bodies():
		if b is Ball or b is Crate:
			now = true
	if now == pressed:
		return
	pressed = now
	Sfx.play("button_on" if now else "button_off")
	var level := Level.of(self)
	if level:
		level.set_button(channel, self, pressed)
	queue_redraw()


func _draw() -> void:
	if not show_placeholder:
		return
	var color := Level.channel_color(channel)
	var h := 3.0 if pressed else 7.0
	draw_rect(Rect2(-14, -h, 28, h), color)
	draw_rect(Rect2(-16, -2, 32, 2), color.darkened(0.5))
