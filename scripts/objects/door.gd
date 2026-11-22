class_name Door                         # tên lớp: Level dùng Door để tạo cửa
extends StaticBody2D                    # vật đứng yên, có va chạm (chặn bóng)
## Cửa chắn đường. Mở khi nút cùng kênh đang bị đè, đóng lại khi thả nút.
## Gốc tọa độ ở góc trên bên trái. Cao bao nhiêu ô do bản đồ chữ quyết định.

@export var channel := "a"              # kênh: nút cùng chữ cái sẽ mở cửa này
@export var height_tiles := 3           # cửa cao bao nhiêu ô
@export var show_placeholder := true    # bật = vẽ hình tạm bằng code

const TILE := 32.0                      # cỡ một ô: 32 pixel

var is_open := false                    # cửa đang mở hay đóng


## Tạo hình va chạm theo chiều cao, nghe tín hiệu nút từ Level.
func _ready() -> void:
	var shape := RectangleShape2D.new()         # hình chữ nhật cho va chạm
	shape.size = Vector2(TILE, height_tiles * TILE)   # rộng 1 ô, cao height_tiles ô
	$Shape.shape = shape                        # gán hình cho node Shape
	$Shape.position = shape.size / 2.0          # dời hình để gốc ở góc trên trái
	var level := Level.of(self)                 # tìm màn chơi chứa cửa này
	if level:                                   # có màn thì
		level.channel_changed.connect(_on_channel_changed)   # nghe tín hiệu nút bật / tắt


# Có nút bật / tắt: nếu đúng kênh thì mở / đóng cửa.
func _on_channel_changed(ch: String, on: bool) -> void:
	if ch != channel:                           # không phải kênh của mình thì bỏ qua
		return
	is_open = on                                # nút bật = cửa mở
	$Shape.set_deferred("disabled", on)    # mở cửa = tắt va chạm
	queue_redraw()                              # vẽ lại cửa


## Hình tạm: cửa song sắt màu theo kênh, mở thì mờ đi.
func _draw() -> void:
	if not show_placeholder:                    # tắt hình tạm thì không vẽ
		return
	var color := Level.channel_color(channel)   # màu theo kênh
	var a := 0.18 if is_open else 1.0           # độ đậm: mở thì mờ đi
	var h := height_tiles * TILE                # chiều cao cửa (pixel)
	# nền cửa: màu kênh tối, nửa trong suốt
	draw_rect(Rect2(4, 0, TILE - 8, h), Color(color.darkened(0.6), 0.5 * a))
	for x in [8.0, 16.0, 24.0]:                 # 3 song sắt dọc
		draw_line(Vector2(x, 0), Vector2(x, h), Color(color, a), 3.0)   # vẽ một song sắt
	# viền ngoài của cửa
	draw_rect(Rect2(2, 0, TILE - 4, h), Color(color.darkened(0.3), a), false, 2.0)
