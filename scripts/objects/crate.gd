class_name Crate                        # tên lớp: nút đạp nhận ra thùng nhờ tên này
extends RigidBody2D                     # vật có vật lý thật: bị đẩy, rơi, lăn
## Thùng gỗ: bóng đẩy được, đứng lên được, đặt lên nút để giữ cửa mở.
## Khối lượng và ma sát chỉnh ở Inspector (Mass, Physics Material Override).

@export var show_placeholder := true    # bật = vẽ hình tạm bằng code

const SIZE := 30.0     # nhỏ hơn 1 ô (32) một chút để lọt khe vừa 1 ô

var home := Vector2.ZERO      # vị trí ban đầu, để đặt lại khi người chơi hồi sinh
var _reset_pending := false             # đang chờ đưa thùng về chỗ cũ


## Nhớ vị trí ban đầu.
func _ready() -> void:
	add_to_group("crates")                      # vào nhóm crates để Level tìm được
	home = global_position                      # nhớ vị trí ban đầu


## Đưa thùng về chỗ cũ (Level gọi khi bóng hồi sinh, để không bị kẹt vì đẩy thùng sai chỗ).
func reset() -> void:
	_reset_pending = true                       # chỉ đánh dấu, việc dời làm trong _integrate_forces


## Godot gọi trong lúc tính vật lý: dịch thùng về chỗ cũ ở đây cho an toàn.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _reset_pending:                          # có yêu cầu đưa về chỗ cũ thì
		state.transform = Transform2D(0.0, home)   # đặt lại vị trí, không xoay
		state.linear_velocity = Vector2.ZERO    # dừng chuyển động
		state.angular_velocity = 0.0            # dừng xoay
		_reset_pending = false                  # xong việc, bỏ đánh dấu


## Hình tạm: thùng gỗ có chữ X.
func _draw() -> void:
	if not show_placeholder:                    # tắt hình tạm thì không vẽ
		return
	var r := Rect2(-SIZE / 2, -SIZE / 2, SIZE, SIZE)   # hình vuông canh giữa gốc tọa độ
	var wood := Color("#c98a4b")                # màu gỗ
	draw_rect(r, wood)                          # tô thùng
	draw_rect(r.grow(-3), wood.darkened(0.2), false, 2.0)   # viền trong tối hơn
	# nét chéo từ góc trên trái xuống góc dưới phải
	draw_line(r.position + Vector2(3, 3), r.end - Vector2(3, 3), wood.darkened(0.3), 2.0)
	# nét chéo còn lại (tạo thành chữ X)
	draw_line(Vector2(r.position.x + 3, r.end.y - 3), Vector2(r.end.x - 3, r.position.y + 3), wood.darkened(0.3), 2.0)
	draw_rect(r, wood.darkened(0.5), false, 1.0)   # viền ngoài tối
