class_name Spikes                       # tên lớp: Level dùng để tạo gai
extends Area2D                          # vùng cảm ứng: phát hiện vật chạm vào
## Một ô gai. Bóng chạm vào là bị thương. Gốc tọa độ ở giữa đáy ô.
## Trong bản đồ chữ: ^ là gai mọc từ đất, v là gai treo trên trần (xoay 180 độ).

@export var show_placeholder := true    # bật = vẽ hình tạm bằng code


## Nối tín hiệu: có vật thể chạm vào vùng gai.
func _ready() -> void:
	body_entered.connect(_on_body_entered)      # có vật chạm thì gọi _on_body_entered


# Có vật chạm vào gai: là bóng thì bóng bị thương.
func _on_body_entered(body: Node2D) -> void:
	if body is Ball:                            # chỉ bóng mới bị thương
		body.take_hit()                         # trừ máu / mạng của bóng


# 60 lần mỗi giây: bóng còn đứng trên gai thì vẫn bị thương.
# (Tín hiệu body_entered chỉ báo lúc vừa chạm; nếu lúc đó bóng đang được miễn sát thương thì sau đó đứng trên gai mãi không sao.)
func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():       # mọi vật đang nằm trong vùng gai
		_on_body_entered(body)                  # xử lý như lúc vừa chạm (take_hit tự bỏ qua khi đang miễn sát thương)


## Hình tạm: 2 chiếc gai trong một ô.
func _draw() -> void:
	if not show_placeholder:
		return                                  # tắt hình tạm thì không vẽ
	for x in [-16.0, 0.0]:                      # 2 gai: bắt đầu ở x = -16 và x = 0
		# hình tam giác: chân trái, đỉnh, chân phải
		var tri := PackedVector2Array([Vector2(x, 0), Vector2(x + 8, -16), Vector2(x + 16, 0)])
		draw_colored_polygon(tri, Color("#b9c4b0"))   # tô gai màu xám
		draw_polyline(tri, Color("#2a3328"), 1.5)   # viền gai màu tối
