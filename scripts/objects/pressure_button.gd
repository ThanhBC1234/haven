class_name PressureButton
extends Area2D
## Nút đạp trên sàn. Khi có bóng hoặc thùng đè lên thì nút "bật", thả ra thì "tắt".
## Nút báo cho Level theo kênh (channel): cửa cùng kênh sẽ mở khi nút bật.
## Bản đồ chữ: nút a mở cửa A, nút b mở cửa B, nút d mở cửa D.

@export var channel := "a"
@export var show_placeholder := true

var pressed := false


## Nối tín hiệu: có vật thể đi vào / ra khỏi vùng nút.
func _ready() -> void:
	body_entered.connect(_refresh.unbind(1))
	body_exited.connect(_refresh.unbind(1))


## Tính lại trạng thái nút: bật nếu còn ít nhất một bóng hoặc thùng đè lên.
func _refresh() -> void:
	var now := false
	for b in get_overlapping_bodies():
		if b is Ball or b is Crate:
			now = true
	if now == pressed:
		return
	pressed = now
	var level := Level.of(self)
	if level:
		level.set_button(channel, self, pressed)    # báo cho cửa cùng kênh
	queue_redraw()


## Hình tạm: tấm đạp màu, lún xuống khi bật.
func _draw() -> void:
	if not show_placeholder:
		return
	var color := Level.channel_color(channel)
	var h := 3.0 if pressed else 7.0
	draw_rect(Rect2(-14, -h, 28, h), color)
	draw_rect(Rect2(-16, -2, 32, 2), color.darkened(0.5))
