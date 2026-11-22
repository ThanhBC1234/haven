class_name Hud                          # tên lớp: nơi khác dùng Hud để gọi tới
extends Control                         # là node giao diện (Control)
## Giao diện trong màn: tên màn, mạng (trái tim), sao, thông báo, bảng qua màn.
## Tạo hết bằng code; muốn đổi vị trí, cỡ chữ thì sửa trong setup().

signal next_pressed                     # phát ra khi bấm nút sang màn sau
signal retry_pressed                    # phát ra khi bấm nút chơi lại
signal menu_pressed                     # phát ra khi bấm nút về menu

var _lives := 3                         # số mạng hiện có
var _max_lives := 3                     # số mạng tối đa (số tim vẽ ra)
var _stars := 0                         # số sao đã nhặt
var _star_total := 0                    # tổng số sao trong màn
var _title: Label                       # chữ tên màn ở trên cùng
var _message: Label                     # chữ thông báo giữa màn hình
var _panel: PanelContainer              # bảng qua màn / bảng thua
var _frame: StyleBoxTexture             # khung SHADOW dùng làm nền cho ô mạng và ô sao
var _endless := false                   # đang ở chế độ vô tận (hiện điểm, không hiện "x / tổng sao")
var _score_label: Label                 # chữ điểm số (chế độ vô tận)
var _mult_label: Label                  # chữ hệ số nhân (chế độ vô tận)
var _ammo := 0                          # số đạn (hiện ô đạn khi > 0)
var _shield := false                    # đang có khiên (hiện biểu tượng cạnh tim)
var _boss: Node = null                  # boss đang đánh (null = không có thanh máu)
var _boss_hp := 0                       # máu hiện tại của boss
var _boss_max := 0                      # máu tối đa của boss
var _boost := 0.0                       # jump boost còn bao lâu (giây)
var _boost_full := 10.0                 # thời lượng boost đầy, để tính độ dài thanh

const HEART_TEX := preload("res://assets/items/heart.png")   # ảnh trái tim
const SHIELD_TEX := preload("res://assets/items/shield.png")   # ảnh khiên
const BOOST_TEX := preload("res://assets/items/jump_boost.png")   # ảnh jump boost

## Hình pixel 7 x 7 (1 = tô màu) cho trái tim và ngôi sao, vẽ phóng to cho hợp kiểu pixel art.
const HEART := ["0110110", "1111111", "1111111", "1111111", "0111110", "0011100", "0001000"]   # hình trái tim 7 x 7
const STAR := ["0001000", "0011100", "1111111", "0111110", "0011100", "0110110", "0100010"]   # hình ngôi sao 7 x 7
const ICON_PX := 4.0                    # mỗi ô của hình pixel to 4 x 4


## play.gd gọi khi vào màn.
func setup(level_name: String, lives: int, star_total: int) -> void:
	theme = UiTheme.make()                      # áp bộ giao diện chung (font, màu, khung)
	_max_lives = lives                          # nhớ số mạng tối đa
	_lives = lives                              # bắt đầu với đầy mạng
	_star_total = star_total                    # nhớ tổng số sao của màn
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # không chặn chuột

	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)   # tạo khung nền dùng cho các ô HUD

	var top := HBoxContainer.new()               # tên màn ở giữa trên cùng, hai bên có biểu tượng xoay
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)   # neo ở giữa mép trên màn hình
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới rộng đều hai bên để luôn nằm giữa
	top.position.y = 12                         # cách mép trên 12 pixel
	top.add_theme_constant_override("separation", 12)   # khoảng cách giữa các phần tử: 12 pixel
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE   # không chặn chuột
	add_child(top)                              # gắn hàng tiêu đề vào HUD
	var spin_l := SpinnerIcon.new()             # biểu tượng xoay bên trái
	spin_l.pixel_scale = 2.0                    # phóng to gấp 2 lần
	top.add_child(spin_l)                       # đặt vào đầu hàng
	_title = Label.new()                        # tạo chữ tên màn
	_title.text = level_name.to_upper()         # tên màn viết hoa
	_title.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)   # cỡ chữ vừa
	_title.add_theme_color_override("font_color", UiTheme.CYAN)   # chữ màu xanh ngọc
	top.add_child(_title)                       # đặt giữa hai biểu tượng
	var spin_r := SpinnerIcon.new()             # biểu tượng xoay bên phải
	spin_r.pixel_scale = 2.0                    # phóng to gấp 2 lần
	top.add_child(spin_r)                       # đặt vào cuối hàng

	_message = Label.new()                       # thông báo giữa màn hình
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)   # neo vào chính giữa màn hình
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều trái phải để chữ luôn ở giữa
	_message.grow_vertical = Control.GROW_DIRECTION_BOTH   # nới đều trên dưới
	_message.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)   # cỡ chữ vừa
	_message.add_theme_color_override("font_outline_color", Color.BLACK)   # viền chữ màu đen cho dễ đọc
	_message.add_theme_constant_override("outline_size", 8)   # viền dày 8 pixel
	add_child(_message)                         # gắn vào HUD

	var hint := Label.new()                     # dòng gợi ý phím ở góc dưới phải
	hint.text = "R: back to checkpoint (-1 life)   Esc: menu"   # nội dung gợi ý phím
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)   # neo vào góc dưới bên phải
	hint.position -= Vector2(420, 38)           # lùi vào trong để chữ không tràn ra ngoài
	hint.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)   # chữ nhỏ
	hint.add_theme_color_override("font_color", UiTheme.DIM)   # màu chữ mờ (chữ phụ)
	add_child(hint)                             # gắn vào HUD
	queue_redraw()                              # yêu cầu vẽ lại (Godot sẽ gọi _draw)


## Chế độ vô tận: như setup() nhưng thêm điểm số to ở giữa và hệ số nhân.
func setup_endless(lives: int) -> void:
	setup("Endless Run", lives, 0)              # dựng HUD cơ bản, không có sao để đếm
	_endless = true                             # bật chế độ vô tận
	var box := VBoxContainer.new()              # cột chứa điểm số và hệ số nhân
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)   # neo ở giữa mép trên
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều hai bên cho nằm giữa
	box.position.y = 44                         # nằm ngay dưới tên màn
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE   # không chặn chuột
	box.add_theme_constant_override("separation", -6)   # số âm: kéo hai dòng chữ sát nhau hơn
	add_child(box)                              # gắn vào HUD
	_score_label = Label.new()                   # điểm số
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	_score_label.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)   # chữ to
	_score_label.add_theme_color_override("font_color", UiTheme.TEXT)   # màu chữ thường
	box.add_child(_score_label)                 # đặt vào cột
	_mult_label = Label.new()                    # hệ số nhân
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	_mult_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)   # chữ vừa
	_mult_label.add_theme_color_override("font_color", UiTheme.ACCENT)   # màu nhấn (xanh rêu)
	box.add_child(_mult_label)                  # đặt dưới điểm số


## Cập nhật điểm và hệ số nhân (chế độ vô tận).
func set_score(score: int, mult: int) -> void:
	_score_label.text = "%07d" % score          # điểm luôn đủ 7 chữ số, vd 0001234
	_mult_label.text = "x%d" % mult             # hiện dạng x2, x3...


## Hiện dòng chữ giữa màn hình `seconds` giây rồi mờ dần.
func flash(text: String, seconds := 0.9) -> void:
	_message.text = text                        # đặt nội dung thông báo
	_message.add_theme_color_override("font_color", UiTheme.ACCENT)   # tô màu nhấn
	_message.modulate.a = 1.0                   # hiện rõ hoàn toàn
	var tw := create_tween()                    # tạo hiệu ứng chuyển động (tween)
	tw.tween_interval(seconds)                  # giữ nguyên chữ trong vài giây
	tw.tween_property(_message, "modulate:a", 0.0, 0.5)   # rồi mờ dần về trong suốt trong 0.5 giây


## Bảng thua ở chế độ vô tận: điểm, kỷ lục, sao gom được, nút chơi lại / menu.
func show_game_over(score: int, best: int, new_best: bool, stars: int, total_stars: int) -> void:
	_message.text = ""                          # xóa thông báo cũ
	_panel = PanelContainer.new()               # tạo bảng có khung
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)   # neo vào giữa màn hình
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều trái phải
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH   # nới đều trên dưới
	add_child(_panel)                           # gắn bảng vào HUD
	var box := VBoxContainer.new()              # cột xếp các dòng chữ và nút
	box.add_theme_constant_override("separation", 10)   # khoảng cách giữa các dòng
	_panel.add_child(box)                       # đặt cột vào bảng
	var lines := [                              # mỗi dòng: [nội dung, cỡ chữ, màu]
		# dòng tiêu đề GAME OVER, chữ to
		["GAME OVER", UiTheme.FONT_LARGE, UiTheme.ACCENT],
		# điểm lần này
		["Score  %d" % score, UiTheme.FONT_MEDIUM, UiTheme.TEXT],
		# phá kỷ lục thì báo NEW BEST, không thì hiện kỷ lục cũ
		["NEW BEST!" if new_best else "Best  %d" % best, UiTheme.FONT_MEDIUM, Color("#f7d046") if new_best else UiTheme.DIM],
		# số sao gom được lần này và tổng số sao
		["Stars  +%d   (total %d)" % [stars, total_stars], UiTheme.FONT_SMALL, UiTheme.TEXT],
	]
	for l in lines:                             # tạo một Label cho từng dòng
		var lab := Label.new()                  # chữ mới
		lab.text = l[0]                         # nội dung
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
		lab.add_theme_font_size_override("font_size", l[1])   # cỡ chữ
		lab.add_theme_color_override("font_color", l[2])   # màu chữ
		box.add_child(lab)                      # đặt vào cột
	var row := HBoxContainer.new()              # hàng chứa các nút
	row.add_theme_constant_override("separation", 10)   # khoảng cách giữa các nút
	row.alignment = BoxContainer.ALIGNMENT_CENTER   # các nút nằm giữa hàng
	box.add_child(row)                          # đặt hàng nút dưới các dòng chữ
	for item in [["Menu", menu_pressed], ["Play again", retry_pressed]]:   # mỗi nút: [chữ, tín hiệu phát ra khi bấm]
		var b := Button.new()                   # tạo nút
		b.text = item[0]                        # chữ trên nút
		b.pressed.connect(item[1].emit)         # bấm nút thì phát tín hiệu tương ứng
		row.add_child(b)                        # đặt vào hàng
	row.get_child(1).grab_focus()                # Enter để chơi lại ngay


## Theo dõi nhân vật: số đạn, khiên.
func watch_ball(ball: Ball) -> void:
	ball.ammo_changed.connect(func(n: int) -> void:   # khi số đạn thay đổi:
		if _ammo == 0 and n > 0:                # trước đó hết đạn, giờ mới có súng
			# hiện thông báo có súng kèm cách bắn
			flash("GOT A GUN!
Press F or J to shoot", 1.8)   # nhắc cách bắn mỗi khi có súng lại
		_ammo = n                               # nhớ số đạn mới
		queue_redraw())                         # vẽ lại ô đạn
	ball.shield_changed.connect(func(on: bool) -> void:   # khi bật / tắt khiên:
		_shield = on                            # nhớ trạng thái khiên
		queue_redraw())                         # vẽ lại biểu tượng khiên
	_boost_full = ball.boost_duration           # nhớ thời lượng boost đầy để vẽ thanh
	ball.boost_changed.connect(func(t: float) -> void:   # khi thời gian boost còn lại thay đổi:
		if _boost == 0.0 and t > 0.0:           # vừa mới nhặt được boost
			# báo nhảy cao hơn trong bao nhiêu giây
			flash("JUMP BOOST!\nJumps are higher for %d seconds" % int(ball.boost_duration), 1.4)
		_boost = t                              # nhớ thời gian còn lại
		queue_redraw())                         # vẽ lại thanh boost


## Theo dõi một màn / một đoạn: boss xuất hiện và bị hạ.
func watch_level(level: Level) -> void:
	level.boss_started.connect(_on_boss_started)   # boss xuất hiện thì gọi _on_boss_started
	level.boss_defeated.connect(_on_boss_defeated)   # boss bị hạ thì gọi _on_boss_defeated


# Boss xuất hiện: nhớ boss, theo dõi máu, hiện cách đánh.
func _on_boss_started(boss: Node) -> void:
	_boss = boss                                # nhớ boss đang đánh
	_boss_max = boss.max_hp                     # máu tối đa
	_boss_hp = boss.hp                          # máu hiện tại
	boss.hp_changed.connect(func(hp: int, max_hp: int) -> void:   # mỗi khi máu boss thay đổi:
		_boss_hp = hp                           # cập nhật máu
		_boss_max = max_hp                      # cập nhật máu tối đa
		queue_redraw())                         # vẽ lại thanh máu
	# hiện tên boss và cách đánh nó trong 2.6 giây
	flash("%s APPEARS!
Shoot it (F / J) or jump on its head.
When it shows a red ! - jump over its charge!" % boss.boss_name, 2.6)
	queue_redraw()                              # vẽ thanh máu boss


# Boss bị hạ: bỏ thanh máu, báo chiến thắng.
func _on_boss_defeated(_boss_node: Node) -> void:
	_boss = null                                # không còn boss
	_boss_max = 0                               # máu tối đa 0 = không vẽ thanh máu
	flash("BOSS DEFEATED!")                     # báo đã hạ boss
	queue_redraw()                              # vẽ lại để xóa thanh máu


# Cập nhật số mạng (play.gd gọi khi mất / thêm mạng).
func set_lives(n: int) -> void:
	_lives = n                                  # nhớ số mạng mới
	queue_redraw()                              # vẽ lại các trái tim


# Cập nhật số sao đã nhặt.
func set_stars(n: int) -> void:
	_stars = n                                  # nhớ số sao mới
	queue_redraw()                              # vẽ lại ô sao


# Hiện một dòng chữ giữa màn hình (không tự mờ đi).
func show_message(text: String) -> void:
	_message.text = text                        # đặt nội dung thông báo


## Bảng qua màn: số sao và 3 nút.
func show_complete(stars: int, total: int, has_next: bool) -> void:
	_panel = PanelContainer.new()               # tạo bảng có khung
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)   # neo vào giữa màn hình
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều trái phải
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH   # nới đều trên dưới
	add_child(_panel)                           # gắn bảng vào HUD
	var box := VBoxContainer.new()              # cột xếp chữ và nút
	box.add_theme_constant_override("separation", 14)   # khoảng cách giữa các dòng
	_panel.add_child(box)                       # đặt cột vào bảng
	var title := Label.new()                    # dòng tiêu đề
	title.text = "Level complete!"              # nội dung tiêu đề
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	title.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)   # chữ to
	title.add_theme_color_override("font_color", UiTheme.ACCENT)   # màu nhấn
	box.add_child(title)                        # đặt vào cột
	var star_label := Label.new()               # dòng số sao
	star_label.text = "Stars: %d / %d" % [stars, total]   # vd Stars: 2 / 3
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	star_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)   # chữ vừa
	box.add_child(star_label)                   # đặt vào cột
	var row := HBoxContainer.new()              # hàng chứa các nút
	row.add_theme_constant_override("separation", 10)   # khoảng cách giữa các nút
	row.alignment = BoxContainer.ALIGNMENT_CENTER   # các nút nằm giữa hàng
	box.add_child(row)                          # đặt hàng nút dưới cùng
	var buttons := [["Menu", menu_pressed], ["Retry", retry_pressed]]   # luôn có nút Menu và Retry
	if has_next:                                # còn màn sau thì
		buttons.append(["Next level", next_pressed])   # thêm nút sang màn sau
	for item in buttons:                        # tạo nút cho từng mục
		var b := Button.new()                   # tạo nút
		b.text = item[0]                        # chữ trên nút
		b.pressed.connect(item[1].emit)         # bấm nút thì phát tín hiệu tương ứng
		row.add_child(b)                        # đặt vào hàng
	row.get_child(row.get_child_count() - 1).grab_focus()   # Enter / Space bấm nút cuối


## Vẽ ô mạng (góc trái) và ô sao (góc phải), mỗi ô có khung SHADOW làm nền.
func _draw() -> void:
	if _frame == null:                          # chưa có khung tức là chưa setup
		return                                   # chưa setup xong
	# ô mạng: khung bên trái, rộng theo số tim (+1 chỗ nếu có khiên)
	var left_box := Rect2(16, 12, 40 + _max_lives * 38 + (38 if _shield else 0), 58)
	draw_style_box(_frame, left_box)            # vẽ khung nền ô mạng
	for i in _max_lives:                         # trái tim: ảnh của nhóm, mạng đã mất thì mờ đi
		var col := Color.WHITE if i < _lives else Color(1, 1, 1, 0.2)   # còn mạng: rõ; đã mất: mờ
		# vẽ trái tim thứ i, cỡ 32 x 32
		draw_texture_rect(HEART_TEX, Rect2(Vector2(34 + i * 38, 25), Vector2(32, 32)), false, col)
	if _shield:                                  # biểu tượng khiên ngay sau các trái tim
		# vẽ khiên ngay sau trái tim cuối
		draw_texture_rect(SHIELD_TEX, Rect2(Vector2(34 + _max_lives * 38, 25), Vector2(32, 32)), false)
	if _boost > 0.0:                             # ô jump boost: biểu tượng + thanh thời gian còn lại
		var by := 74.0 + (78.0 if _ammo > 0 else 0.0)   # nằm dưới ô đạn nếu đang có đạn
		var boost_box := Rect2(16, by, 150, 52)   # khung ô boost
		draw_style_box(_frame, boost_box)       # vẽ khung nền
		# biểu tượng jump boost bên trái ô
		draw_texture_rect(BOOST_TEX, Rect2(boost_box.position + Vector2(14, 10), Vector2(32, 32)), false)
		var bar := Rect2(boost_box.position + Vector2(56, 22), Vector2(78, 10))   # vị trí thanh thời gian
		draw_rect(bar, Color("#123018"))        # nền thanh màu tối
		# phần còn lại của thanh, ngắn dần khi boost sắp hết
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_boost / _boost_full, 0.0, 1.0), bar.size.y)), Color("#22b14c"))
	if _ammo > 0:                                # ô đạn dưới ô mạng
		var ammo_box := Rect2(16, 74, 150, 52)   # khung ô đạn
		draw_style_box(_frame, ammo_box)        # vẽ khung nền
		PixelArt.draw(self, PixelArt.GUN, ammo_box.position + Vector2(20, 16), 3.0)   # vẽ hình khẩu súng pixel
		# số đạn còn lại, vd x 15
		draw_string(get_theme_default_font(), ammo_box.position + Vector2(64, 35), "x %d" % _ammo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, UiTheme.TEXT)
		# dòng nhắc phím bắn dưới ô đạn
		draw_string(get_theme_default_font(), ammo_box.position + Vector2(14, 74), "Shoot: F / J   (hold A / D to aim up)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.DIM)
	if _boss_max > 0:                           # đang có boss thì
		_draw_boss_bar()                        # vẽ thanh máu boss

	var right_box := Rect2(size.x - 196, 12, 180, 58)   # ô sao: khung bên phải
	draw_style_box(_frame, right_box)           # vẽ khung nền
	_pixel_icon(STAR, right_box.position + Vector2(22, 15), Color("#f7d046"))   # vẽ ngôi sao vàng
	var star_text := str(_stars) if _endless else "%d / %d" % [_stars, _star_total]   # vô tận: chỉ đếm số sao
	# vẽ chữ số sao cạnh ngôi sao
	draw_string(get_theme_default_font(), right_box.position + Vector2(66, 40), star_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, UiTheme.TEXT)


## Vẽ hình pixel `pattern` (mảng chuỗi "0"/"1") tại `pos` với màu `col`, kèm viền sáng trên cùng cho có khối.
func _pixel_icon(pattern: Array, pos: Vector2, col: Color) -> void:
	for y in pattern.size():                    # duyệt từng hàng
		var row: String = pattern[y]            # chuỗi của hàng y
		for x in row.length():                  # duyệt từng ô trong hàng
			if row[x] == "1":                   # ô có màu
				var c := col.lightened(0.35) if y == 1 and col.a > 0.5 else col   # hàng thứ 2 sáng hơn, tạo viền nổi
				# tô một ô vuông cỡ ICON_PX
				draw_rect(Rect2(pos + Vector2(x, y) * ICON_PX, Vector2.ONE * ICON_PX), c)


## Thanh máu boss kiểu pixel: khung SHADOW, mỗi ô là 1 máu; ô còn máu đỏ, ô mất máu tối.
func _draw_boss_bar() -> void:
	var w := 520.0                              # chiều rộng thanh máu
	var y := 128.0 if _endless else 64.0         # chế độ vô tận: nằm dưới điểm số
	var bar := Rect2((size.x - w) / 2.0, y, w, 46)   # khung thanh, canh giữa theo chiều ngang
	draw_style_box(_frame, bar)                 # vẽ khung nền
	var font := get_theme_default_font()        # font mặc định để vẽ chữ
	var title := "%s   %d / %d" % [_boss.boss_name if _boss else "BOSS", _boss_hp, _boss_max]   # chữ trên thanh: tên boss và máu
	# vẽ tên boss + máu ngay trên thanh
	draw_string(font, Vector2(bar.position.x, y - 6), title, HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.FONT_SMALL, Color("#f2a0aa"))
	var inner := bar.grow(-14)                  # phần bên trong khung (thụt vào 14 pixel)
	var seg_w := inner.size.x / float(_boss_max)   # bề rộng mỗi ô máu
	# dòng nhắc cách đánh boss dưới thanh
	draw_string(font, Vector2(bar.position.x, y + 66), "Shoot: F / J    Stomp its head    Jump over it when it charges",
		HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.FONT_SMALL, UiTheme.DIM)
	var phase2 := _boss_hp <= _boss_max / 2     # còn nửa máu trở xuống: giai đoạn 2
	for i in _boss_max:                         # vẽ từng ô máu
		var r := Rect2(inner.position.x + i * seg_w, inner.position.y, seg_w - 2.0, inner.size.y)   # ô thứ i, chừa khe 2 pixel
		var col := Color("#3a1620")             # màu ô đã mất máu (tối)
		if i < _boss_hp:                        # ô còn máu
			col = Color("#ff5d6d") if phase2 else Color("#e8455a")   # giai đoạn 2 đỏ tươi hơn
		draw_rect(r, col)                       # tô ô
		if i < _boss_hp:                        # ô còn máu thì
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("#ffb3bb"))   # viền sáng trên mỗi ô
