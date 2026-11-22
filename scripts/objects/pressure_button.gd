class_name PressureButton               # tên lớp: Level dùng để tạo nút đạp
extends Area2D                          # vùng cảm ứng (không chặn, chỉ phát hiện vật)
## Nút đạp trên sàn. Khi có bóng hoặc thùng đè lên thì nút "bật", thả ra thì "tắt".
## Nút báo cho Level theo kênh (channel): cửa cùng kênh sẽ mở khi nút bật.
## Bản đồ chữ: nút a mở cửa A, nút b mở cửa B, nút d mở cửa D.

@export var channel := "a"              # kênh: cửa cùng chữ cái sẽ mở
@export var show_placeholder := true    # bật = vẽ hình tạm bằng code

var pressed := false                    # nút đang bị đè hay không


## Nối tín hiệu: có vật thể đi vào / ra khỏi vùng nút.
func _ready() -> void:
	body_entered.connect(_refresh.unbind(1))    # có vật đi vào thì tính lại (bỏ tham số body)
	body_exited.connect(_refresh.unbind(1))     # có vật đi ra thì tính lại


## Tính lại trạng thái nút: bật nếu còn ít nhất một bóng hoặc thùng đè lên.
func _refresh() -> void:
	var now := false                            # giả sử chưa có gì đè
	for b in get_overlapping_bodies():          # duyệt mọi vật đang nằm trong vùng nút
		if b is Ball or b is Crate:             # là bóng hoặc thùng
			now = true                          # thì nút bị đè
	if now == pressed:                          # trạng thái không đổi thì thôi
		return
	pressed = now                               # lưu trạng thái mới
	var level := Level.of(self)                 # tìm màn chơi chứa nút này
	if level:                                   # có màn thì
		level.set_button(channel, self, pressed)    # báo cho cửa cùng kênh
	queue_redraw()                              # vẽ lại nút


## Hình tạm: tấm đạp màu, lún xuống khi bật.
func _draw() -> void:
	if not show_placeholder:                    # tắt hình tạm thì không vẽ
		return
	var color := Level.channel_color(channel)   # màu theo kênh
	var h := 3.0 if pressed else 7.0            # bật thì tấm đạp thấp xuống
	draw_rect(Rect2(-14, -h, 28, h), color)     # tấm đạp màu kênh
	draw_rect(Rect2(-16, -2, 32, 2), color.darkened(0.5))   # đế nút màu tối
