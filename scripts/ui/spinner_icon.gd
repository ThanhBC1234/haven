class_name SpinnerIcon                  # tên lớp: tạo bằng SpinnerIcon.new()
extends Control                         # là node giao diện (Control)
## Biểu tượng chuyển động từ gói SHADOW (assets/ui/spinner_1.png ... spinner_6.png).
## Mỗi file là một dải khung hình 14 x 14 xếp ngang; node này lần lượt hiện từng khung.
## Dùng làm trang trí ở menu và HUD. Đổi kiểu bằng `sheet`, tốc độ bằng `fps`, độ to bằng `pixel_scale`.

@export var sheet: Texture2D = preload("res://assets/ui/spinner_4.png")   # dải ảnh khung hình (chọn kiểu biểu tượng)
@export var fps := 10.0                 # số khung hình mỗi giây (tốc độ xoay)
@export var pixel_scale := 3.0          # phóng to bao nhiêu lần
@export var tint := Color.WHITE         # màu nhuộm (trắng = giữ màu gốc)

const FRAME := 14.0      # mỗi khung hình 14 x 14 pixel

var _time := 0.0                        # thời gian đã chạy (giây)


# Chạy một lần khi node vào cảnh: đặt cỡ, giữ pixel sắc nét.
func _ready() -> void:
	custom_minimum_size = Vector2.ONE * FRAME * pixel_scale   # cỡ tối thiểu = 1 khung x độ phóng
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST     # giữ pixel sắc nét
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # không chặn chuột


# Godot gọi mỗi khung hình: cộng thời gian rồi vẽ lại.
func _process(delta: float) -> void:
	_time += delta                              # cộng dồn thời gian
	queue_redraw()                              # yêu cầu vẽ lại


## Vẽ khung hình hiện tại vào giữa ô.
func _draw() -> void:
	if sheet == null:                           # chưa có ảnh thì không vẽ
		return
	var frames := maxi(1, int(sheet.get_width() / FRAME))   # số khung trong dải (ít nhất 1)
	var i := int(_time * fps) % frames          # khung đang hiện, hết thì quay vòng
	var dst := Vector2.ONE * FRAME * pixel_scale   # cỡ vẽ trên màn hình
	# cắt khung thứ i từ dải ảnh, vẽ vào giữa ô
	draw_texture_rect_region(sheet, Rect2((size - dst) / 2.0, dst), Rect2(i * FRAME, 0, FRAME, FRAME), tint)
