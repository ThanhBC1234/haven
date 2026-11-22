extends Area2D                     # đạn là vùng chạm (Area2D), không bị vật lý đẩy
## Đạn của người chơi (pixel). Bay thẳng, chạm đất thì vỡ, trúng quái thì quái chết, trúng boss thì boss mất máu.

@export var speed := 720.0         # tốc độ bay (pixel/giây), chỉnh được trong Inspector
@export var life_time := 1.2       # bay tối đa bao lâu
@export var damage := 1            # trừ máu boss mỗi viên
@export var show_placeholder := true   # bật thì tự vẽ hình đạn pixel tạm

var direction := Vector2.RIGHT     # Ball đặt khi bắn
var _age := 0.0                    # đạn đã bay được bao lâu (giây)


func _ready() -> void:
	rotation = direction.angle()                  # đạn quay theo hướng bay
	body_entered.connect(_on_body_entered)        # chạm đất / quái
	area_entered.connect(_on_area_entered)        # chạm vùng trúng đạn của boss


func _physics_process(delta: float) -> void:
	_age += delta                                 # cộng dồn thời gian đã bay
	if _age > life_time:                          # bay quá lâu rồi
		queue_free()                              # thì xoá đạn khỏi màn chơi
		return
	position += direction * speed * delta         # bay thẳng theo hướng đã bắn


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:                             # trúng một con quái
		if not body.dead:                         # quái còn sống
			body.squash()                         # bắn trúng quái: quái bẹp như bị dẫm
	elif body is Ball:                            # chạm vào chính bóng người chơi
		return                                    # không trúng chính mình
	queue_free()                                  # trúng gì khác (đất, quái) thì đạn vỡ


func _on_area_entered(area: Area2D) -> void:
	var boss := area.get_parent()                 # vùng trúng đạn là con của boss
	if boss is Boss:                              # đúng là boss thật
		boss.take_damage(damage)                  # trừ máu boss
		queue_free()                              # đạn biến mất sau khi trúng


func _draw() -> void:
	if show_placeholder:                          # chỉ vẽ khi bật hình tạm
		# vẽ hình viên đạn pixel ở giữa, phóng to 3 lần
		PixelArt.draw_centered(self, PixelArt.BULLET, Vector2.ZERO, 3.0)
