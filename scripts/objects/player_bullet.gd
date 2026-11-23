extends Area2D                     # đạn là vùng chạm (Area2D), không bị vật lý đẩy
## Đạn của người chơi (pixel). Bay thẳng, chạm đất thì vỡ, trúng quái thì quái chết, trúng boss thì boss mất máu.
## Đạn đẩy lùi (knockback > 0, chế độ 2 người): trúng quả bóng khác thì hất nó đi chứ không gây sát thương.

const BALL_LAYER := 2              # lớp va chạm của các quả bóng (bit giá trị 2)

@export var speed := 720.0         # tốc độ bay (pixel/giây), chỉnh được trong Inspector
@export var life_time := 1.2       # bay tối đa bao lâu
@export var damage := 1            # trừ máu boss mỗi viên
@export var knockback_lift := 150.0   # đạn đẩy lùi hất thêm lên trên bấy nhiêu cho "đã" tay
@export var show_placeholder := true   # bật thì tự vẽ hình đạn pixel tạm
## > 0: đạn đẩy lùi. Đạn va chạm cả với quả bóng khác (trừ người bắn) và hất nó đi với lực này.
@export var knockback := 0.0:
	set(value):
		knockback = value                             # nhận lực đẩy mới
		if value > 0.0:                               # đạn đẩy lùi
			collision_mask |= BALL_LAYER              # nhìn thấy cả quả bóng khác
		else:
			collision_mask &= ~BALL_LAYER             # đạn thường: không va chạm với bóng

var direction := Vector2.RIGHT     # Ball đặt khi bắn
var shooter: Ball = null           # quả bóng đã bắn viên này (đạn đẩy lùi bỏ qua nó)
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
	elif body is Ball:                            # chạm vào một quả bóng
		if knockback <= 0.0 or body == shooter or body.dead:   # đạn thường, hoặc chính người bắn, hoặc bóng đã chết
			return                                # không trúng (đạn bay xuyên qua)
		body.knockback(direction.normalized() * knockback + Vector2(0.0, -knockback_lift))   # hất bóng đi, kèm cú nảy lên
		queue_free()                              # đạn biến mất, không gây sát thương
		return
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
