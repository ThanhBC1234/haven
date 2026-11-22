class_name MovingPlatform
extends AnimatableBody2D
## Bệ di chuyển qua lại giữa vị trí đầu (from) và vị trí cuối (to). Bóng đứng trên sẽ được chở theo.
## Bản đồ chữ: === là bệ, dấu > cùng hàng là điểm đến theo chiều ngang,
## dấu | cùng cột với ô đầu tiên của bệ là điểm đến theo chiều dọc.

@export var width_tiles := 3        # bệ dài bao nhiêu ô
@export var speed := 70.0           # pixel/giây
@export var pause := 0.6            # dừng ở mỗi đầu bao lâu
@export var show_placeholder := true   # có vẽ hình bệ bằng code hay không

const TILE := 32.0                  # kích thước 1 ô (pixel)
const THICK := 12.0                 # độ dày của bệ

var from := Vector2.ZERO            # Level đặt khi tạo bệ
var to := Vector2.ZERO              # điểm đến (Level đặt khi tạo bệ)
var _t := 0.0                       # 0 = ở from, 1 = ở to
var _going := 1.0                   # hướng đi: 1 = tới to, -1 = về from
var _wait := 0.0                    # thời gian còn phải đứng chờ


## Tạo hình va chạm theo chiều rộng.
func _ready() -> void:
	sync_to_physics = true          # để bóng và thùng đứng trên được chở theo mượt
	var shape := RectangleShape2D.new()   # tạo hình chữ nhật va chạm
	shape.size = Vector2(width_tiles * TILE, THICK)   # rộng theo số ô, dày THICK
	$Shape.shape = shape            # gán hình cho node va chạm con
	$Shape.position = shape.size / 2.0   # dời hình để góc trên trái trùng gốc bệ
	position = from                 # đặt bệ ở vị trí đầu


## 60 lần mỗi giây: tiến dần từ from tới to rồi quay lại.
func _physics_process(delta: float) -> void:
	if _wait > 0.0:                 # đang dừng ở đầu đường
		_wait -= delta              # đếm ngược thời gian chờ
		return
	var length := from.distance_to(to)   # quãng đường từ from tới to
	if length < 1.0:                # không có điểm đến thì đứng yên
		return
	_t += _going * speed * delta / length   # tiến thêm một chút theo tốc độ
	if _t >= 1.0 or _t <= 0.0:      # đã tới một đầu
		_t = clampf(_t, 0.0, 1.0)   # giữ _t trong khoảng 0..1
		_going = -_going             # tới đầu thì quay lại
		_wait = pause               # đứng chờ một lúc
	position = from.lerp(to, _t)    # đặt bệ ở điểm giữa from và to theo tỉ lệ _t


## Vẽ bệ bằng gạch đá trong bộ Dark Fantasia Forest (forest_decorations.png), phóng to gấp 2.
func _draw() -> void:
	if not show_placeholder:        # tắt hình tạm thì không vẽ
		return
	var tex: Texture2D = preload("res://assets/forest/forest_decorations.png")   # ảnh gạch trang trí
	for i in width_tiles:           # vẽ từng ô của bệ
		var src := Rect2(32 + (i % 6) * 16, 32, 16, 6)            # dải gạch đá trên cùng của bức tường gạch
		draw_texture_rect_region(tex, Rect2(i * TILE, 0, TILE, THICK), src)   # vẽ mảnh gạch phóng to vào ô
	draw_rect(Rect2(0, 0, width_tiles * TILE, THICK), Color("#05080c"), false, 1.0)   # viền tối quanh bệ
