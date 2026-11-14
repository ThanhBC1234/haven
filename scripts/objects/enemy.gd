class_name Enemy
extends CharacterBody2D
## Quái đi tuần: đi qua đi lại, gặp tường hoặc mép vực thì quay đầu.
## Bóng nhảy dẫm lên đầu thì quái bẹp; đụng ngang thì bóng bị thương.

@export var speed := 50.0               # tốc độ đi (pixel/giây)
@export var start_dir := -1             # -1 đi sang trái trước, 1 sang phải
@export var stomp_bounce := 480.0       # dẫm trúng thì bóng bật lên với vận tốc này
@export var show_placeholder := true    # tắt khi đã thêm Sprite2D

const HALF := Vector2(15, 11)           # nửa kích thước thân (rộng 30, cao 22)

var dir := -1
var dead := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")  # cùng trọng lực với cả game

@onready var hitbox: Area2D = $Hitbox   # vùng chạm với bóng (to hơn thân một chút)


## Khi quái được tạo: chọn hướng đi, nối tín hiệu chạm bóng.
func _ready() -> void:
	dir = start_dir
	hitbox.body_entered.connect(_on_hitbox_body_entered)


## 60 lần mỗi giây: rơi theo trọng lực, đi ngang, quay đầu khi cần.
func _physics_process(delta: float) -> void:
	if dead:
		return
	velocity.y += _gravity * delta
	velocity.x = dir * speed
	move_and_slide()
	if is_on_wall():
		dir = -dir                           # đụng tường: quay đầu
	elif is_on_floor() and not _ground_ahead():
		dir = -dir                           # sắp rơi xuống vực: quay đầu
	queue_redraw()


## Bắn một tia ngắn xuống đất ngay phía trước để xem còn đất không.
func _ground_ahead() -> bool:
	var from := global_position + Vector2(dir * (HALF.x + 2), 0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, HALF.y + 10), 1 | 8)  # chỉ xét đất (lớp 1) và thùng (lớp 4)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Bóng chạm vào quái: từ trên xuống thì quái chết, còn lại thì bóng bị thương.
func _on_hitbox_body_entered(body: Node2D) -> void:
	if dead or not body is Ball or body.dead:
		return
	var from_above: bool = body.global_position.y < global_position.y - 6.0 and body.linear_velocity.y > -100.0
	if from_above:
		squash()
		body.bounce_up(stomp_bounce)
	else:
		body.take_hit()


## Bị dẫm: bẹp xuống rồi biến mất.
func squash() -> void:
	dead = true
	$Shape.set_deferred("disabled", true)            # tắt va chạm
	hitbox.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 0.25), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## Hình tạm: cục nhầy tím một mắt.
func _draw() -> void:
	if not show_placeholder:
		return
	var c := Color("#7b4dff")
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(cos(a) * HALF.x, HALF.y + sin(a) * HALF.y * 2.0))
	draw_colored_polygon(dome, c)
	draw_polyline(dome, c.darkened(0.4), 1.5)
	draw_circle(Vector2(dir * 4, -2), 5.0, Color.WHITE)
	draw_circle(Vector2(dir * 6, -2), 2.5, Color("#1b0f33"))
