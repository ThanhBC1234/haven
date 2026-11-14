class_name SpinnerIcon
extends Control
## Biểu tượng chuyển động từ gói SHADOW (assets/ui/spinner_1.png ... spinner_6.png).
## Mỗi file là một dải khung hình 14 x 14 xếp ngang; node này lần lượt hiện từng khung.
## Dùng làm trang trí ở menu và HUD. Đổi kiểu bằng `sheet`, tốc độ bằng `fps`, độ to bằng `pixel_scale`.

@export var sheet: Texture2D = preload("res://assets/ui/spinner_4.png")
@export var fps := 10.0
@export var pixel_scale := 3.0
@export var tint := Color.WHITE

const FRAME := 14.0      # mỗi khung hình 14 x 14 pixel

var _time := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * FRAME * pixel_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST     # giữ pixel sắc nét
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Vẽ khung hình hiện tại vào giữa ô.
func _draw() -> void:
	if sheet == null:
		return
	var frames := maxi(1, int(sheet.get_width() / FRAME))
	var i := int(_time * fps) % frames
	var dst := Vector2.ONE * FRAME * pixel_scale
	draw_texture_rect_region(sheet, Rect2((size - dst) / 2.0, dst), Rect2(i * FRAME, 0, FRAME, FRAME), tint)
