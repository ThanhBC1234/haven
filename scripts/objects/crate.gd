class_name Crate
extends RigidBody2D
## Thùng gỗ: bóng đẩy được, đứng lên được, đặt lên nút để giữ cửa mở.
## Khối lượng và ma sát chỉnh ở Inspector (Mass, Physics Material Override).

@export var show_placeholder := true

const SIZE := 30.0     # nhỏ hơn 1 ô (32) một chút để lọt khe vừa 1 ô

var home := Vector2.ZERO      # vị trí ban đầu, để đặt lại khi người chơi hồi sinh
var _reset_pending := false


## Nhớ vị trí ban đầu.
func _ready() -> void:
	add_to_group("crates")
	home = global_position


## Đưa thùng về chỗ cũ (Level gọi khi bóng hồi sinh, để không bị kẹt vì đẩy thùng sai chỗ).
func reset() -> void:
	_reset_pending = true


## Godot gọi trong lúc tính vật lý: dịch thùng về chỗ cũ ở đây cho an toàn.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _reset_pending:
		state.transform = Transform2D(0.0, home)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_reset_pending = false


## Hình tạm: thùng gỗ có chữ X.
func _draw() -> void:
	if not show_placeholder:
		return
	var r := Rect2(-SIZE / 2, -SIZE / 2, SIZE, SIZE)
	var wood := Color("#c98a4b")
	draw_rect(r, wood)
	draw_rect(r.grow(-3), wood.darkened(0.2), false, 2.0)
	draw_line(r.position + Vector2(3, 3), r.end - Vector2(3, 3), wood.darkened(0.3), 2.0)
	draw_line(Vector2(r.position.x + 3, r.end.y - 3), Vector2(r.end.x - 3, r.position.y + 3), wood.darkened(0.3), 2.0)
	draw_rect(r, wood.darkened(0.5), false, 1.0)
