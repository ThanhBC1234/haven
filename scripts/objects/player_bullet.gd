extends Area2D

@export var speed := 720.0
@export var life_time := 1.2
@export var damage := 1
@export var show_placeholder := true

var direction := Vector2.RIGHT
var _age := 0.0


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > life_time:
		queue_free()
		return
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		if not body.dead:
			body.squash()
	elif body is Ball:
		return
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var boss := area.get_parent()
	if boss is Boss:
		boss.take_damage(damage)
		queue_free()


func _draw() -> void:
	if show_placeholder:
		PixelArt.draw_centered(self, PixelArt.BULLET, Vector2.ZERO, 3.0)
