class_name Seesaw
extends Node2D
## Bập bênh: tấm ván (RigidBody2D) gắn vào trục cố định bằng khớp PinJoint2D.
## Bóng và thùng đè lên một đầu thì ván nghiêng thật theo vật lý.
## Gốc tọa độ là trục quay. Tạo toàn bộ bằng code nên scene chỉ có node gốc.

@export var length_tiles := 5        # chiều dài ván (ô)
@export var plank_mass := 2.0        # khối lượng ván (nặng thì khó nghiêng hơn)
@export var max_tilt_deg := 22.0     # nghiêng tối đa mỗi bên
@export var show_placeholder := true   # có vẽ hình tạm bằng code hay không

const TILE := 32.0                   # kích thước 1 ô (pixel)

var plank: RigidBody2D               # tấm ván, tạo trong _ready


## Dựng trục, ván và khớp nối.
func _ready() -> void:
	var pivot := StaticBody2D.new()                  # trục cố định
	pivot.collision_layer = 0                        # trục không va chạm với gì
	add_child(pivot)                                 # thêm trục vào cảnh

	plank = RigidBody2D.new()                        # tấm ván
	plank.mass = plank_mass                          # đặt khối lượng ván
	plank.collision_layer = 1                        # ván là "đất": bóng, thùng, quái đứng lên được
	plank.collision_mask = 1 | 2 | 8                 # ván chạm đất, bóng, thùng
	plank.can_sleep = false                          # không cho ván "ngủ", luôn phản ứng vật lý
	plank.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE   # chống ván xuyên qua khối chặn khi bị đập mạnh
	var mat := PhysicsMaterial.new()                 # tạo vật liệu vật lý
	mat.friction = 1.0                               # ma sát cao để bóng không trượt khỏi ván
	plank.physics_material_override = mat            # gán vật liệu cho ván
	var shape := CollisionShape2D.new()              # node hình va chạm của ván
	var rect := RectangleShape2D.new()               # hình chữ nhật
	rect.size = Vector2(length_tiles * TILE, 10)     # dài theo số ô, dày 10 pixel
	shape.shape = rect                               # gán hình chữ nhật cho node va chạm
	plank.add_child(shape)                           # gắn hình va chạm vào ván
	add_child(plank)                                 # thêm ván vào cảnh

	var joint := PinJoint2D.new()                    # khớp: ván chỉ xoay quanh trục
	add_child(joint)                                 # thêm khớp vào cảnh
	joint.node_a = joint.get_path_to(pivot)          # đầu thứ nhất của khớp nối vào trục
	joint.node_b = joint.get_path_to(plank)          # đầu thứ hai nối vào ván

	# Hai khối chặn vô hình dưới hai đầu ván: ván nghiêng tới max_tilt_deg thì chạm vào và dừng.
	# Chúng ở lớp va chạm 5, chỉ ván chạm vào (bóng, thùng đi xuyên qua).
	var half := length_tiles * TILE / 2.0            # nửa chiều dài ván
	var drop := (half - 6.0) * sin(deg_to_rad(max_tilt_deg)) + 5.0 + 3.0   # độ sâu đầu ván khi nghiêng tối đa
	for side in [-1.0, 1.0]:                         # bên trái (-1) và bên phải (1)
		var stop := StaticBody2D.new()               # khối chặn đứng yên
		stop.collision_layer = 16                    # nằm ở lớp 5 (giá trị bit 16)
		stop.collision_mask = 0                      # khối chặn không tự dò va chạm
		var stop_shape := CollisionShape2D.new()     # node hình va chạm của khối chặn
		var stop_rect := RectangleShape2D.new()      # hình chữ nhật
		stop_rect.size = Vector2(16, 12)             # kích thước khối chặn
		stop_shape.shape = stop_rect                 # gán hình chữ nhật
		stop.add_child(stop_shape)                   # gắn hình vào khối chặn
		stop.position = Vector2(side * (half - 6.0), drop + 3.0)   # đặt dưới đầu ván bên này
		add_child(stop)                              # thêm khối chặn vào cảnh
	plank.collision_mask |= 16                        # ván chạm khối chặn


func _process(_delta: float) -> void:
	if show_placeholder:                             # đang dùng hình tạm
		queue_redraw()                               # vẽ lại mỗi khung để theo kịp ván nghiêng


## Hình tạm: chân đỡ hình tam giác và tấm ván xoay theo vật lý.
func _draw() -> void:
	if not show_placeholder or plank == null:        # tắt hình tạm hoặc chưa có ván thì thôi
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-10, 18), Vector2(10, 18)]), Color("#6b5a4a"))   # chân đỡ tam giác
	draw_set_transform(plank.position, plank.rotation)   # dời và xoay bút vẽ theo ván
	var w := length_tiles * TILE                     # chiều dài ván (pixel)
	draw_rect(Rect2(-w / 2, -5, w, 10), Color("#d69a5a"))   # thân ván màu gỗ
	draw_rect(Rect2(-w / 2, -5, w, 10), Color("#7a4f28"), false, 1.0)   # viền ván
	draw_set_transform(Vector2.ZERO)                 # trả bút vẽ về bình thường
	draw_circle(Vector2.ZERO, 3.0, Color("#3a2f25")) # chốt trục ở giữa
