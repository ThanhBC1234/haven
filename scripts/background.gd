extends Node2D
## Nền rừng đêm, hợp tông với bộ gạch Dark Fantasia Forest:
## trời tối chuyển màu, 3 lớp rừng cây thông (xa mờ, gần đậm) trôi chậm hơn camera (parallax),
## sương mù và đom đóm lấp lánh. Vẽ hoàn toàn bằng code.
## Nằm trong CanvasLayer có layer = -1 nên luôn ở sau màn chơi.
## Muốn dùng ảnh nền PNG: thêm Parallax2D + Sprite2D vào play.tscn và xóa node này.

const SKY_TOP := Color("#0b0e18")        # trời trên cùng
const SKY_BOTTOM := Color("#1d3140")     # trời sát chân trời
## Mỗi lớp rừng: [tốc độ trôi so với camera, độ cao chân rừng (tỉ lệ màn hình), chiều cao cây, khoảng cách cây, màu]
const LAYERS := [
	[0.10, 0.62, 120.0, 46.0, Color("#16242f")],   # lớp xa nhất: trôi chậm, màu nhạt
	[0.25, 0.74, 150.0, 58.0, Color("#111b24")],   # lớp giữa
	[0.45, 0.88, 190.0, 74.0, Color("#0b1118")],   # lớp gần nhất: trôi nhanh, màu đậm
]
const FIREFLY := Color("#c8f56a")        # màu đom đóm

var _time := 0.0                         # thời gian đã trôi (giây), dùng cho chuyển động


func _process(delta: float) -> void:
	_time += delta                         # cộng dồn thời gian
	queue_redraw()                         # vẽ lại mỗi khung để rừng trôi theo camera, đom đóm nhấp nháy


func _draw() -> void:
	var view := get_viewport_rect().size   # kích thước màn hình
	var cam := get_viewport().get_camera_2d()   # camera đang dùng (có thể không có)
	var cam_x := cam.get_screen_center_position().x if cam else _time * 20.0   # menu không có camera: tự trôi chậm
	# vẽ bầu trời: hình chữ nhật phủ màn hình, màu chuyển từ trên xuống dưới
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	var moon := Vector2(view.x * 0.9, view.y * 0.2)   # vị trí trăng: góc trên bên phải
	draw_circle(moon, 40.0, Color("#d9e6c8", 0.08))       # quầng trăng
	draw_circle(moon, 24.0, Color("#e9f2dc", 0.8))        # trăng
	for i in LAYERS.size():                # vẽ từng lớp rừng, từ xa tới gần
		var l: Array = LAYERS[i]           # thông số của lớp này
		_forest(view, cam_x * l[0], view.y * l[1], l[2], l[3], l[4], i)   # vẽ một dãy rừng
		# sương mù mỏng giữa các lớp rừng
		var mist_y: float = view.y * l[1] - 10.0   # sương nằm ngay trên chân rừng
		draw_rect(Rect2(0, mist_y, view.x, 40), Color("#5d7a86", 0.05))   # dải sương mờ
	_fireflies(view, cam_x)                # vẽ đom đóm lên trên cùng


## Một dãy cây thông hình tam giác chồng tầng, chân rừng ở `base_y`.
func _forest(view: Vector2, offset: float, base_y: float, tree_h: float, gap: float, color: Color, seed_: int) -> void:
	draw_rect(Rect2(0, base_y, view.x, view.y - base_y), color)   # tô kín phần đất dưới chân rừng
	var first := floori(offset / gap) - 1  # số thứ tự cây đầu tiên lọt vào màn hình
	var count := int(view.x / gap) + 3     # cần vẽ bao nhiêu cây cho đủ màn hình
	for k in count:                        # vẽ từng cây
		var i := first + k                 # số thứ tự cây (cố định để cây không đổi hình)
		var x := i * gap - offset          # vị trí ngang của cây trên màn hình
		var h := tree_h * (0.7 + 0.3 * absf(sin(i * 12.9898 + seed_ * 3.1)))   # cây cao thấp khác nhau
		var w := h * 0.42                  # bề ngang cây theo chiều cao
		for tier in 3:                                                        # 3 tầng lá
			var top := base_y - h + tier * h * 0.22   # đỉnh của tầng lá này
			var half := w * (0.55 + tier * 0.22)      # nửa bề ngang tầng lá (tầng dưới rộng hơn)
			# vẽ tầng lá hình tam giác
			draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x - half, top + h * 0.42), Vector2(x + half, top + h * 0.42)]), color)


## Đom đóm: chấm sáng nhỏ trôi lơ lửng, nhấp nháy.
func _fireflies(view: Vector2, cam_x: float) -> void:
	for i in 26:                           # 26 con đom đóm
		var fx := fposmod(i * 197.0 - cam_x * 0.6 + sin(_time * 0.7 + i) * 30.0, view.x)   # vị trí ngang, lắc lư và quấn vòng màn hình
		var fy := view.y * (0.45 + 0.4 * fposmod(i * 0.618, 1.0)) + sin(_time * 1.3 + i * 2.0) * 12.0   # vị trí dọc, nhấp nhô
		var glow := 0.35 + 0.65 * maxf(0.0, sin(_time * 2.0 + i * 1.7))   # độ sáng thay đổi theo thời gian
		draw_circle(Vector2(fx, fy), 4.0, Color(FIREFLY, 0.12 * glow))   # quầng sáng mờ
		draw_circle(Vector2(fx, fy), 1.5, Color(FIREFLY, 0.9 * glow))    # chấm sáng ở giữa
