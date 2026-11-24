class_name ChainedHud                   # tên lớp: chained.gd và bài test dùng ChainedHud
extends Control                         # là node giao diện (Control)
## Giao diện chế độ Chained (hai người bị trói bằng dây): số sao đang nằm về phía mỗi người (P1 trái màu đỏ, P2 phải màu xanh dương),
## tên màn và mạng chung (trái tim) ở giữa trên, dòng thông báo, dòng nhắc phím, và bảng kết quả cuối màn.
## Tạo hết bằng code; muốn đổi vị trí, cỡ chữ thì sửa các hằng số dưới và trong setup().

signal next_pressed                     # phát ra khi bấm nút Next level
signal retry_pressed                    # phát ra khi bấm nút Retry
signal menu_pressed                     # phát ra khi bấm nút Menu

const PLAYER_COLORS := [Color("#e8455a"), Color("#4da3ff")]   # màu người chơi 1 (đỏ) và người chơi 2 (xanh dương)
const BOX_SIZE := Vector2(214, 64)      # kích thước ô số sao của mỗi người chơi
const MARGIN := 16.0                    # khoảng cách từ ô tới mép màn hình
const STAR_PX := 4.0                    # mỗi điểm của ngôi sao pixel to 4 x 4
const HEART_TEX := preload("res://assets/items/heart.png")   # ảnh trái tim (cùng ảnh với HUD màn thường)
const HEART_SIZE := 28.0                # cỡ mỗi trái tim vẽ ra
const HEART_GAP := 4.0                  # khoảng cách giữa các trái tim

var level_name := ""                    # tên màn hiện ở giữa trên
var max_lives := 5                      # số mạng tối đa (số trái tim vẽ ra)
var lives := 5                          # số mạng đang có
var counts := Vector2i.ZERO             # số sao của người chơi 1 (x) và 2 (y) đang hiện
var message_label: Label                # chữ thông báo giữa màn hình (đọc để kiểm tra)
var result_panel: PanelContainer        # bảng kết quả (null = chưa hiện)
var result_title: Label                 # dòng "PLAYER 1 WINS THE LEVEL!" / "IT'S A TIE!"
var result_p1: Label                    # sao của người chơi 1 trong bảng (vd "P1  7")
var result_p2: Label                    # sao của người chơi 2 trong bảng (vd "5  P2")
var result_totals: Label                # dòng tổng sao qua các màn
var next_button: Button                 # nút màn kế tiếp (null khi hết màn)
var retry_button: Button                # nút chơi lại màn
var menu_button: Button                 # nút về menu
var _frame: StyleBoxTexture             # khung SHADOW làm nền ô sao
var _flash_tween: Tween                 # hiệu ứng mờ dần của thông báo đang chạy (để hủy khi có thông báo mới)


## chained.gd gọi khi vào màn: cài giao diện, tên màn, số mạng.
func setup(title: String, lives_max: int) -> void:
	theme = UiTheme.make()                      # áp bộ giao diện chung (font, màu, khung)
	level_name = title.to_upper()               # tên màn viết hoa
	max_lives = lives_max                       # số mạng tối đa
	lives = lives_max                           # bắt đầu đầy mạng
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # không chặn chuột (trừ bảng kết quả)
	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)   # khung nền cho ô sao

	message_label = Label.new()                 # chữ thông báo giữa màn hình
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)   # neo ở giữa mép trên
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều hai bên để chữ luôn ở giữa
	message_label.position.y = 132              # nằm dưới tên màn và mạng, trên vùng chơi
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	message_label.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)   # chữ to
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)   # viền chữ đen cho dễ đọc
	message_label.add_theme_constant_override("outline_size", 10)   # viền dày 10 pixel
	message_label.modulate.a = 0.0              # lúc đầu chưa có thông báo
	add_child(message_label)                    # gắn vào HUD

	# dòng nhắc phím: người chơi 1 ở góc dưới trái, người chơi 2 ở góc dưới phải, Esc ở giữa
	_add_hint("P1: A / D + W, S: anchor", Control.PRESET_BOTTOM_LEFT, PLAYER_COLORS[0].lightened(0.35))
	_add_hint("P2: LEFT / RIGHT + UP, DOWN: anchor", Control.PRESET_BOTTOM_RIGHT, PLAYER_COLORS[1].lightened(0.35))
	_add_hint("Esc: menu", Control.PRESET_CENTER_BOTTOM, UiTheme.DIM)
	queue_redraw()                              # yêu cầu vẽ lại (Godot sẽ gọi _draw)


## Tạo một dòng nhắc phím nhỏ ở sát mép dưới màn hình. `preset` chọn góc (trái, phải hay giữa).
func _add_hint(text: String, preset: int, color: Color) -> void:
	var hint := Label.new()                     # chữ nhắc phím
	hint.text = text                            # nội dung nhắc
	hint.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)   # chữ nhỏ
	hint.add_theme_color_override("font_color", color)   # màu theo người chơi
	add_child(hint)                             # gắn vào HUD trước, để Godot tính được cỡ chữ
	hint.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)   # neo vào góc / giữa mép dưới, cách mép 20 pixel


## Đặt số mạng chung đang có (vẽ lại các trái tim).
func set_lives(n: int) -> void:
	lives = n                                   # nhớ số mạng mới
	queue_redraw()                              # vẽ lại trái tim


## Đặt số sao đang nằm về phía người chơi 1 (p1) và người chơi 2 (p2).
func set_counts(p1: int, p2: int) -> void:
	if counts == Vector2i(p1, p2):              # không đổi
		return
	counts = Vector2i(p1, p2)                   # nhớ số mới
	queue_redraw()                              # vẽ lại hai ô sao


## Hiện dòng chữ giữa màn hình `seconds` giây rồi mờ dần. `color` là màu chữ (mặc định xanh rêu).
func flash(text: String, seconds := 0.9, color := UiTheme.ACCENT) -> void:
	if message_label == null:                   # chưa setup thì thôi
		return
	message_label.text = text                   # đặt nội dung thông báo
	message_label.add_theme_color_override("font_color", color)   # tô màu
	message_label.modulate.a = 1.0              # hiện rõ hoàn toàn
	if _flash_tween:                            # thông báo trước còn đang mờ dần
		_flash_tween.kill()                     # hủy, để nó không làm mờ thông báo mới
	_flash_tween = create_tween()               # tạo hiệu ứng chuyển động (tween)
	_flash_tween.tween_interval(seconds)        # giữ nguyên chữ trong vài giây
	_flash_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)   # rồi mờ dần về trong suốt trong 0.5 giây


## Người thắng màn: 1 / 2, hoặc 0 nếu hoà (so số sao).
static func winner_of(result: Vector2i) -> int:
	if result.x == result.y:                    # bằng nhau
		return 0                                # hoà
	return 1 if result.x > result.y else 2      # nhiều sao hơn thì thắng


## Bảng kết quả cuối màn: người thắng, sao từng người, tổng sao qua các màn, nút Next level (nếu `has_next`) / Retry / Menu.
func show_result(result: Vector2i, totals: Array, has_next: bool) -> void:
	if result_panel != null:                    # bảng đã hiện rồi thì thôi
		return
	if _flash_tween:                            # hủy thông báo đang mờ dần
		_flash_tween.kill()                     # để nó không che bảng
	message_label.modulate.a = 0.0              # ẩn thông báo giữa màn hình
	result_panel = PanelContainer.new()         # tạo bảng có khung
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)   # neo vào giữa màn hình
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều trái phải
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH   # nới đều trên dưới
	add_child(result_panel)                     # gắn bảng vào HUD
	var box := VBoxContainer.new()              # cột xếp chữ và nút
	box.add_theme_constant_override("separation", 12)   # khoảng cách giữa các dòng
	result_panel.add_child(box)                 # đặt cột vào bảng
	var win := winner_of(result)                # 0 hoà, 1 / 2 thắng
	result_title = Label.new()                  # dòng tiêu đề
	result_title.text = "IT'S A TIE!" if win == 0 else "PLAYER %d WINS THE LEVEL!" % win   # vd PLAYER 1 WINS THE LEVEL!
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	result_title.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)   # chữ to
	result_title.add_theme_color_override("font_color", UiTheme.ACCENT if win == 0 else PLAYER_COLORS[win - 1])   # màu của người thắng
	box.add_child(result_title)                 # đặt vào cột
	var stars_row := HBoxContainer.new()        # hàng sao: P1 bên trái, P2 bên phải
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER   # canh giữa
	stars_row.add_theme_constant_override("separation", 24)   # khoảng cách giữa các phần
	box.add_child(stars_row)                    # đặt vào cột
	result_p1 = _result_label("P1  %d" % result.x, PLAYER_COLORS[0], UiTheme.FONT_LARGE)   # sao người chơi 1
	stars_row.add_child(result_p1)              # đặt vào hàng
	stars_row.add_child(_result_label("STARS", UiTheme.DIM, UiTheme.FONT_MEDIUM))   # chữ nối giữa hai bên
	result_p2 = _result_label("%d  P2" % result.y, PLAYER_COLORS[1], UiTheme.FONT_LARGE)   # sao người chơi 2
	stars_row.add_child(result_p2)              # đặt vào hàng
	result_totals = _result_label("TOTAL   P1 %d  -  %d P2" % [totals[0], totals[1]], UiTheme.TEXT, UiTheme.FONT_MEDIUM)   # tổng sao qua các màn
	box.add_child(result_totals)                # đặt vào cột
	var row := HBoxContainer.new()              # hàng chứa các nút
	row.add_theme_constant_override("separation", 14)   # khoảng cách giữa các nút
	row.alignment = BoxContainer.ALIGNMENT_CENTER   # các nút nằm giữa hàng
	box.add_child(row)                          # đặt hàng nút dưới cùng
	if has_next:                                # còn màn sau
		next_button = Button.new()              # nút màn kế tiếp
		next_button.text = "Next level"         # chữ trên nút
		next_button.pressed.connect(next_pressed.emit)   # bấm thì phát tín hiệu
		row.add_child(next_button)              # đặt vào hàng
	retry_button = Button.new()                 # nút chơi lại
	retry_button.text = "Retry"                 # chữ trên nút
	retry_button.pressed.connect(retry_pressed.emit)   # bấm thì phát tín hiệu
	row.add_child(retry_button)                 # đặt vào hàng
	menu_button = Button.new()                  # nút về menu
	menu_button.text = "Menu"                   # chữ trên nút
	menu_button.pressed.connect(menu_pressed.emit)   # bấm thì phát tín hiệu
	row.add_child(menu_button)                  # đặt vào hàng
	(next_button if next_button != null else retry_button).grab_focus()   # Enter / Space bấm nút đầu tiên (Next level, hoặc Retry khi hết màn)


## Tạo một Label canh giữa với cỡ chữ và màu cho bảng kết quả.
func _result_label(text: String, color: Color, font_size: int) -> Label:
	var lab := Label.new()                      # chữ mới
	lab.text = text                             # nội dung
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	lab.add_theme_font_size_override("font_size", font_size)   # cỡ chữ
	lab.add_theme_color_override("font_color", color)   # màu chữ
	return lab


## Vẽ hai ô sao (P1 trái, P2 phải), tên màn và các trái tim mạng chung ở giữa trên.
func _draw() -> void:
	if _frame == null:                          # chưa setup xong
		return
	var font := get_theme_default_font()        # font mặc định để vẽ chữ
	for i in 2:                                 # hai người chơi
		var x := MARGIN if i == 0 else size.x - MARGIN - BOX_SIZE.x   # người chơi 1 sát trái, người chơi 2 sát phải
		var box := Rect2(Vector2(x, 12), BOX_SIZE)   # khung ô sao
		draw_style_box(_frame, box)             # vẽ khung nền
		var col: Color = PLAYER_COLORS[i]       # màu của người chơi này
		draw_string(font, box.position + Vector2(22, 44), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, col)   # nhãn P1 / P2
		_draw_star(box.position + Vector2(86, 17))   # ngôi sao pixel vàng
		var number := str(counts.x if i == 0 else counts.y)   # số sao của người này
		draw_string(font, box.position + Vector2(126, 50), number, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE, col.lightened(0.2))   # số sao to
	var mid := size.x / 2.0                     # giữa màn hình
	draw_string(font, Vector2(mid - 200, 34), level_name, HORIZONTAL_ALIGNMENT_CENTER, 400, UiTheme.FONT_MEDIUM, UiTheme.CYAN)   # tên màn
	var total_w := max_lives * HEART_SIZE + (max_lives - 1) * HEART_GAP   # bề ngang cả hàng trái tim
	for i in max_lives:                         # từng trái tim (mạng đã mất thì mờ đi)
		var tint := Color.WHITE if i < lives else Color(1, 1, 1, 0.2)   # còn mạng: rõ; đã mất: mờ
		var pos := Vector2(mid - total_w / 2.0 + i * (HEART_SIZE + HEART_GAP), 46)   # vị trí trái tim thứ i
		draw_texture_rect(HEART_TEX, Rect2(pos, Vector2(HEART_SIZE, HEART_SIZE)), false, tint)   # vẽ trái tim


## Vẽ ngôi sao pixel vàng (hình Hud.STAR) ở góc trên trái `pos`, kèm viền sáng ở hàng thứ 2 cho có khối.
func _draw_star(pos: Vector2) -> void:
	var pattern: Array = Hud.STAR               # hình ngôi sao 7 x 7 ("0" / "1")
	for y in pattern.size():                    # từng hàng
		var row: String = pattern[y]            # chuỗi của hàng y
		for x in row.length():                  # từng ô trong hàng
			if row[x] == "1":                   # ô có màu
				var c := Color("#ffe27a") if y == 1 else Color("#f7d046")   # hàng thứ 2 sáng hơn
				draw_rect(Rect2(pos + Vector2(x, y) * STAR_PX, Vector2.ONE * STAR_PX), c)   # tô một ô vuông
