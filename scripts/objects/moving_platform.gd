class_name MovingPlatform
extends AnimatableBody2D
## Bệ di chuyển qua lại giữa vị trí đầu (from) và vị trí cuối (to). Bóng đứng trên sẽ được chở theo.
## Bản đồ chữ: === là bệ, dấu > cùng hàng là điểm đến theo chiều ngang,
## dấu | cùng cột với ô đầu tiên của bệ là điểm đến theo chiều dọc.

@export var width_tiles := 3
@export var speed := 70.0           # pixel/giây
@export var pause := 0.6            # dừng ở mỗi đầu bao lâu
@export var show_placeholder := true

const TILE := 32.0
const THICK := 12.0                 # độ dày của bệ

var from := Vector2.ZERO            # Level đặt khi tạo bệ
var to := Vector2.ZERO
var _t := 0.0                       # 0 = ở from, 1 = ở to
var _going := 1.0
var _wait := 0.0


## Tạo hình va chạm theo chiều rộng.
func _ready() -> void:
	sync_to_physics = true          # để bóng và thùng đứng trên được chở theo mượt
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width_tiles * TILE, THICK)
	$Shape.shape = shape
	$Shape.position = shape.size / 2.0
	position = from


## 60 lần mỗi giây: tiến dần từ from tới to rồi quay lại.
func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	var length := from.distance_to(to)
	if length < 1.0:
		return
	_t += _going * speed * delta / length
	if _t >= 1.0 or _t <= 0.0:
		_t = clampf(_t, 0.0, 1.0)
		_going = -_going             # tới đầu thì quay lại
		_wait = pause
	position = from.lerp(to, _t)


## Vẽ bệ bằng gạch đá trong bộ Dark Fantasia Forest (forest_decorations.png), phóng to gấp 2.
func _draw() -> void:
	if not show_placeholder:
		return
	var tex: Texture2D = preload("res://assets/forest/forest_decorations.png")
	for i in width_tiles:
		var src := Rect2(32 + (i % 6) * 16, 32, 16, 6)            # dải gạch đá trên cùng của bức tường gạch
		draw_texture_rect_region(tex, Rect2(i * TILE, 0, TILE, THICK), src)
	draw_rect(Rect2(0, 0, width_tiles * TILE, THICK), Color("#05080c"), false, 1.0)
