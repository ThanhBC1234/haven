extends Node2D                          # node vẽ hình, gắn làm con của Ball
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

@export_group("Trái banh bẹp khi chạm đất")   # gom các biến dưới thành một nhóm trong Inspector
@export var land_squash := 0.0006       # bẹp bao nhiêu cho mỗi pixel/giây tốc độ chạm đất
@export var ball_stiffness := 420.0     # lò xo kéo banh về tròn (lớn = về nhanh)
@export var ball_damping := 16.0        # giảm rung: lớn = banh hết nảy nhanh hơn

@export_group("Lò xo nén / giãn")       # nhóm thông số của cổ lò xo
@export var charge_compress := 0.45     # giữ đủ lực thì lò xo nén còn bao nhiêu (0.45 = ngắn đi 45%)
@export var jump_stretch := 0.55        # lúc bật nhảy lò xo dài ra bao nhiêu
@export var spring_stiffness := 260.0   # độ cứng lò xo: lớn = về độ dài cũ nhanh
@export var spring_damping := 9.0       # giảm rung của lò xo

@export_group("Đầu lắc trễ")            # nhóm thông số lắc đầu
@export var head_follow := 150.0        # lớn = đầu bám theo nhanh, nhỏ = lắc lư nhiều
@export var head_damping := 7.0         # giảm rung: lớn = đầu thôi lắc nhanh hơn

# Chiều cao (pixel trong ảnh) của từng phần và chỗ chúng chồng lên nhau một chút để không hở.
const BALL_H := 15.0                    # trái banh cao 15 pixel
const SPRING_H := 9.0                   # lò xo cao 9 pixel
const OVERLAP := 1.0                    # chồng 1 pixel để các phần không hở khe

var _squash := 0.0        # > 0: banh đang bẹp; < 0: banh đang dài ra
var _squash_vel := 0.0    # tốc độ thay đổi độ bẹp
var _compress := 0.0      # > 0: lò xo đang nén; < 0: lò xo đang giãn
var _compress_vel := 0.0  # tốc độ thay đổi độ nén
var _head_angle := 0.0    # góc lắc của đầu (radian)
var _head_vel := 0.0      # tốc độ lắc của đầu

@onready var ball: Ball = get_parent()           # node cha chính là quả bóng người chơi
@onready var ball_part: Sprite2D = $BallPart     # hình phần trái banh
@onready var spring: Sprite2D = $Spring          # hình phần lò xo
@onready var head: Sprite2D = $Head              # hình phần đầu


## Chạy một lần: đặt gốc ở đáy banh, phóng to ảnh, nghe tín hiệu chạm đất và nhảy.
func _ready() -> void:
	position = Vector2(0, ball.radius)          # đáy của vòng va chạm
	scale = Vector2.ONE * pixel_scale           # phóng to cả hình
	show_behind_parent = true                   # để mũi tên lực nhảy (vẽ ở Ball) nằm trên hình
	ball.landed.connect(_on_landed)             # bóng chạm đất thì gọi _on_landed
	ball.launched.connect(_on_launched)         # bóng bật nhảy thì gọi _on_launched


## Chạm đất: banh bẹp và lò xo nén theo tốc độ rơi.
func _on_landed(impact_speed: float) -> void:
	_squash_vel += impact_speed * land_squash * 30.0     # rơi càng nhanh banh càng bẹp
	_compress_vel += impact_speed * land_squash * 40.0   # lò xo cũng bị dồn nén


## Bật nhảy: lò xo duỗi dài, banh hơi dài ra.
func _on_launched() -> void:
	_compress = -jump_stretch           # lò xo giãn dài ngay lập tức
	_compress_vel = 0.0                 # bỏ chuyển động nén cũ
	_squash = -0.15                     # banh hơi kéo dài theo chiều dọc


## Mỗi khung hình: cập nhật các "lò xo" chuyển động rồi xếp lại 3 phần ảnh.
func _process(delta: float) -> void:
	# Lò xo cổ: đang giữ phím thì nén theo lực, không thì về độ dài bình thường (kiểu lò xo có giảm chấn).
	var target := charge_compress * ball.charge if ball.charge_dir != 0 else 0.0   # độ nén mong muốn
	# lực lò xo kéo về đích, trừ đi lực giảm chấn, đổi thành tốc độ
	_compress_vel += (-(_compress - target) * spring_stiffness - _compress_vel * spring_damping) * delta
	_compress += _compress_vel * delta  # cập nhật độ nén theo tốc độ

	# Banh bẹp rồi nảy về tròn.
	_squash_vel += (-_squash * ball_stiffness - _squash_vel * ball_damping) * delta   # kéo banh về tròn
	_squash += _squash_vel * delta      # cập nhật độ bẹp

	# Đầu lắc trễ: ngả ngược chiều nghiêng và ngược chiều bay ngang.
	var head_target := -ball.tilt * 0.6 + clampf(-ball.linear_velocity.x * 0.0008, -0.35, 0.35)   # góc đầu muốn tới
	_head_vel += ((head_target - _head_angle) * head_follow - _head_vel * head_damping) * delta   # đầu đuổi theo góc đích
	_head_angle += _head_vel * delta    # cập nhật góc đầu

	_layout()                           # xếp lại vị trí 3 phần hình


## Xếp 3 phần chồng lên nhau theo độ bẹp / nén hiện tại. Mỗi phần có offset để "đứng" trên gốc của nó.
func _layout() -> void:
	var sq := clampf(_squash, -0.3, 0.45)               # giới hạn độ bẹp để hình không méo quá
	ball_part.scale = Vector2(1.0 + sq, 1.0 - sq)       # bẹp: rộng ra, thấp xuống
	var ball_h := BALL_H * (1.0 - sq)                   # chiều cao banh sau khi bẹp

	# Trái banh tròn nên không cần xoay; lò xo và đầu ngả quanh đỉnh banh theo góc nghiêng (gồm cả lắc lư).
	var lean := ball.tilt                                 # góc nghiêng hiện tại của bóng
	var c := clampf(_compress, -0.7, 0.6)                 # giới hạn độ nén/giãn của lò xo
	spring.scale = Vector2(1.0 + c * 0.25, 1.0 - c)       # nén: ngắn lại, hơi phình ra
	var top := Vector2(0, -ball_h + OVERLAP)              # đỉnh trái banh: chân lò xo
	spring.position = top                                 # đặt lò xo ngay trên banh
	spring.rotation = lean                                # lò xo nghiêng theo bóng
	var spring_h := SPRING_H * (1.0 - c)                  # chiều cao lò xo sau khi nén

	head.position = top + Vector2(0, -spring_h + OVERLAP).rotated(lean)   # đầu nằm ở đỉnh lò xo
	head.rotation = lean + _head_angle                    # đầu nghiêng theo bóng cộng thêm lắc lư
