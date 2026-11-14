extends Area2D
## Đạn của người chơi (pixel). Bay thẳng, chạm đất thì vỡ, trúng quái thì quái chết, trúng boss thì boss mất máu.

@export var speed := 720.0
@export var life_time := 1.2       # bay tối đa bao lâu
@export var damage := 1            # trừ máu boss mỗi viên
@export var show_placeholder := true

var direction := Vector2.RIGHT     # Ball đặt khi bắn
var _age := 0.0


func _ready() -> void:
	rotation = direction.angle()                  # đạn quay theo hướng bay
	body_entered.connect(_on_body_entered)        # chạm đất / quái
	area_entered.connect(_on_area_entered)        # chạm vùng trúng đạn của boss


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > life_time:
		queue_free()
		return
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		if not body.dead:
			body.squash()                         # bắn trúng quái: quái bẹp như bị dẫm
	elif body is Ball:
		return                                    # không trúng chính mình
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	var boss := area.get_parent()
	if boss is Boss:
		boss.take_damage(damage)
		queue_free()


func _draw() -> void:
	if show_placeholder:
		PixelArt.draw_centered(self, PixelArt.BULLET, Vector2.ZERO, 3.0)
