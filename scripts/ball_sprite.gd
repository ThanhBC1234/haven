extends Node2D
## Hoạt ảnh cho hình nhân vật assets/player.png (16 x 32 pixel, chỉ có MỘT khung hình).
## Ảnh được cắt làm 3 phần (3 node Sprite2D con, mỗi node dùng một vùng của ảnh - Region):
##   Head     - đầu (hàng 0-7 của ảnh)
##   Spring   - cổ lò xo (hàng 8-16)
##   BallPart - trái banh (hàng 17-31)
## Rồi code làm chúng chuyển động để trông như thật:
##   - Giữ A/D: lò xo nén lại (nhún xuống lấy đà), cả người nghiêng theo hướng.
##   - Bật nhảy: lò xo duỗi dài ra.
##   - Chạm đất: trái banh bẹp ra rồi nảy về tròn, lò xo nén lại; rơi càng mạnh càng bẹp.
##   - Cái đầu lắc trễ theo quán tính (bay sang phải thì đầu ngả về sau).
## Gốc của node này đặt ở điểm thấp nhất của trái banh (chỗ chạm đất), mọi phần "đứng" lên từ đó.
## Muốn đổi sang ảnh khác cùng bố cục: chọn từng Sprite2D con, kéo ảnh mới vào Texture, chỉnh Region.

@export var pixel_scale := 2.0          # phóng ảnh pixel lên gấp mấy lần (2 = banh rộng 30 px, khớp vòng va chạm)

@export_group("Trái banh bẹp khi chạm đất")
@export var land_squash := 0.0006       # bẹp bao nhiêu cho mỗi pixel/giây tốc độ chạm đất
@export var ball_stiffness := 420.0     # lò xo kéo banh về tròn (lớn = về nhanh)
@export var ball_damping := 16.0

@export_group("Lò xo nén / giãn")
@export var charge_compress := 0.45     # giữ đủ lực thì lò xo nén còn bao nhiêu (0.45 = ngắn đi 45%)
@export var jump_stretch := 0.55        # lúc bật nhảy lò xo dài ra bao nhiêu
@export var spring_stiffness := 260.0
@export var spring_damping := 9.0

@export_group("Đầu lắc trễ")
@export var head_follow := 150.0        # lớn = đầu bám theo nhanh, nhỏ = lắc lư nhiều
@export var head_damping := 7.0

# Chiều cao (pixel trong ảnh) của từng phần và chỗ chúng chồng lên nhau một chút để không hở.
const BALL_H := 15.0
const SPRING_H := 9.0
const OVERLAP := 1.0

var _squash := 0.0        # > 0: banh đang bẹp; < 0: banh đang dài ra
var _squash_vel := 0.0
var _compress := 0.0      # > 0: lò xo đang nén; < 0: lò xo đang giãn
var _compress_vel := 0.0
var _head_angle := 0.0    # góc lắc của đầu (radian)
var _head_vel := 0.0

@onready var ball: Ball = get_parent()
@onready var ball_part: Sprite2D = $BallPart
@onready var spring: Sprite2D = $Spring
@onready var head: Sprite2D = $Head


## Chạy một lần: đặt gốc ở đáy banh, phóng to ảnh, nghe tín hiệu chạm đất và nhảy.
func _ready() -> void:
	position = Vector2(0, ball.radius)          # đáy của vòng va chạm
	scale = Vector2.ONE * pixel_scale
	show_behind_parent = true                   # để mũi tên lực nhảy (vẽ ở Ball) nằm trên hình
	ball.landed.connect(_on_landed)
	ball.launched.connect(_on_launched)


## Chạm đất: banh bẹp và lò xo nén theo tốc độ rơi.
func _on_landed(impact_speed: float) -> void:
	_squash_vel += impact_speed * land_squash * 30.0
	_compress_vel += impact_speed * land_squash * 40.0


## Bật nhảy: lò xo duỗi dài, banh hơi dài ra.
func _on_launched() -> void:
	_compress = -jump_stretch
	_compress_vel = 0.0
	_squash = -0.15


## Mỗi khung hình: cập nhật các "lò xo" chuyển động rồi xếp lại 3 phần ảnh.
func _process(delta: float) -> void:
	# Lò xo cổ: đang giữ phím thì nén theo lực, không thì về độ dài bình thường (kiểu lò xo có giảm chấn).
	var target := charge_compress * ball.charge if ball.charge_dir != 0 else 0.0
	_compress_vel += (-(_compress - target) * spring_stiffness - _compress_vel * spring_damping) * delta
	_compress += _compress_vel * delta

	# Banh bẹp rồi nảy về tròn.
	_squash_vel += (-_squash * ball_stiffness - _squash_vel * ball_damping) * delta
	_squash += _squash_vel * delta

	# Đầu lắc trễ: ngả ngược chiều nghiêng và ngược chiều bay ngang.
	var head_target := -ball.tilt * 0.6 + clampf(-ball.linear_velocity.x * 0.0008, -0.35, 0.35)
	_head_vel += ((head_target - _head_angle) * head_follow - _head_vel * head_damping) * delta
	_head_angle += _head_vel * delta

	_layout()


## Xếp 3 phần chồng lên nhau theo độ bẹp / nén hiện tại. Mỗi phần có offset để "đứng" trên gốc của nó.
func _layout() -> void:
	var sq := clampf(_squash, -0.3, 0.45)
	ball_part.scale = Vector2(1.0 + sq, 1.0 - sq)       # bẹp: rộng ra, thấp xuống
	var ball_h := BALL_H * (1.0 - sq)

	# Trái banh tròn nên không cần xoay; lò xo và đầu ngả quanh đỉnh banh theo góc nghiêng (gồm cả lắc lư).
	var lean := ball.tilt
	var c := clampf(_compress, -0.7, 0.6)
	spring.scale = Vector2(1.0 + c * 0.25, 1.0 - c)       # nén: ngắn lại, hơi phình ra
	var top := Vector2(0, -ball_h + OVERLAP)              # đỉnh trái banh: chân lò xo
	spring.position = top
	spring.rotation = lean
	var spring_h := SPRING_H * (1.0 - c)

	head.position = top + Vector2(0, -spring_h + OVERLAP).rotated(lean)   # đầu nằm ở đỉnh lò xo
	head.rotation = lean + _head_angle
