class_name Enemy                        # đặt tên lớp để file khác dùng "is Enemy"
extends CharacterBody2D                 # thân nhân vật tự di chuyển bằng move_and_slide
## Quái đi tuần: đi qua đi lại, gặp tường hoặc mép vực thì quay đầu.
## Bóng nhảy dẫm lên đầu thì quái bẹp; đụng ngang thì bóng bị thương.

@export var speed := 50.0               # tốc độ đi (pixel/giây)
@export var start_dir := -1             # -1 đi sang trái trước, 1 sang phải
@export var stomp_bounce := 480.0       # dẫm trúng thì bóng bật lên với vận tốc này
@export var show_placeholder := true    # tắt khi đã thêm Sprite2D

const HALF := Vector2(15, 11)           # nửa kích thước thân (rộng 30, cao 22)

var dir := -1                           # hướng đi hiện tại: -1 trái, 1 phải
var dead := false                       # quái đã chết chưa
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")  # cùng trọng lực với cả game

@onready var hitbox: Area2D = $Hitbox   # vùng chạm với bóng (to hơn thân một chút)


## Khi quái được tạo: chọn hướng đi, nối tín hiệu chạm bóng.
func _ready() -> void:
	dir = start_dir                                          # bắt đầu đi theo hướng đã chọn
	hitbox.body_entered.connect(_on_hitbox_body_entered)     # bóng chạm hitbox thì gọi hàm xử lý


## 60 lần mỗi giây: rơi theo trọng lực, đi ngang, quay đầu khi cần.
func _physics_process(delta: float) -> void:
	if dead:                             # chết rồi thì đứng yên
		return
	velocity.y += _gravity * delta       # trọng lực kéo quái rơi xuống
	velocity.x = dir * speed             # đi ngang theo hướng hiện tại
	move_and_slide()                     # di chuyển và trượt dọc tường/đất
	if is_on_wall():                     # vừa đụng tường
		dir = -dir                           # đụng tường: quay đầu
	elif is_on_floor() and not _ground_ahead():   # đang đứng đất nhưng phía trước hụt
		dir = -dir                           # sắp rơi xuống vực: quay đầu
	queue_redraw()                       # vẽ lại để mắt nhìn theo hướng mới


## Bắn một tia ngắn xuống đất ngay phía trước để xem còn đất không.
func _ground_ahead() -> bool:
	var from := global_position + Vector2(dir * (HALF.x + 2), 0)   # điểm ngay trước mũi quái
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, HALF.y + 10), 1 | 8)  # chỉ xét đất (lớp 1) và thùng (lớp 4)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()   # tia trúng gì đó = còn đất


## Bóng chạm vào quái: từ trên xuống thì quái chết, còn lại thì bóng bị thương.
func _on_hitbox_body_entered(body: Node2D) -> void:
	if dead or not body is Ball or body.dead:   # bỏ qua nếu quái chết, không phải bóng, hoặc bóng chết
		return
	# bóng ở cao hơn đầu quái và không đang bay vọt lên = dẫm từ trên xuống
	var from_above: bool = body.global_position.y < global_position.y - 6.0 and body.linear_velocity.y > -100.0
	if from_above:                    # dẫm trúng đầu
		squash()                      # quái bẹp
		body.bounce_up(stomp_bounce)  # bóng nảy lên
	else:
		body.take_hit()               # đụng ngang: bóng mất máu


## Bị dẫm: bẹp xuống rồi biến mất.
func squash() -> void:
	dead = true                                      # đánh dấu đã chết
	$Shape.set_deferred("disabled", true)            # tắt va chạm
	hitbox.set_deferred("monitoring", false)         # hitbox ngừng phát hiện bóng
	var tween := create_tween()                      # tạo hiệu ứng chuyển động
	tween.tween_property(self, "scale", Vector2(1.3, 0.25), 0.1)   # bẹp dẹt xuống trong 0.1 giây
	tween.tween_property(self, "modulate:a", 0.0, 0.4)             # mờ dần đến trong suốt
	tween.tween_callback(queue_free)                 # xong thì xoá quái


## Hình tạm: cục nhầy tím một mắt.
func _draw() -> void:
	if not show_placeholder:                 # đã có hình thật thì không vẽ tạm
		return
	var c := Color("#7b4dff")                # màu tím của thân
	var dome := PackedVector2Array()         # danh sách điểm tạo hình vòm
	for i in 13:                             # 13 điểm dọc nửa vòng tròn
		var a := PI + PI * i / 12.0          # góc từ 180 đến 360 độ (nửa trên)
		dome.append(Vector2(cos(a) * HALF.x, HALF.y + sin(a) * HALF.y * 2.0))   # thêm một điểm của vòm
	draw_colored_polygon(dome, c)            # tô kín thân màu tím
	draw_polyline(dome, c.darkened(0.4), 1.5)   # viền thân màu tím đậm
	draw_circle(Vector2(dir * 4, -2), 5.0, Color.WHITE)        # lòng trắng mắt, lệch theo hướng đi
	draw_circle(Vector2(dir * 6, -2), 2.5, Color("#1b0f33"))   # con ngươi tối màu
