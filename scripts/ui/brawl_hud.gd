class_name BrawlHud                     # tên lớp: brawl.gd và bài test dùng BrawlHud
extends Control                         # là node giao diện (Control)
## Giao diện chế độ đấu 2 người (Bounce Brawl): điểm hai bên (P1 trái màu đỏ, P2 phải màu xanh dương),
## dòng thông báo giữa trên (READY, BOUNCE, ai ghi điểm), dòng nhắc phím và bảng thắng cuộc.
## Tạo hết bằng code; muốn đổi vị trí, cỡ chữ thì sửa các hằng số dưới và trong setup().

signal rematch_pressed                  # phát ra khi bấm nút Rematch (chơi lại trận)
signal menu_pressed                     # phát ra khi bấm nút Menu (về menu)

const PLAYER_COLORS := [Color("#e8455a"), Color("#4da3ff")]   # màu người chơi 1 (đỏ) và người chơi 2 (xanh dương)
const BOX_SIZE := Vector2(236, 76)      # kích thước ô điểm của mỗi người chơi
const MARGIN := 16.0                    # khoảng cách từ ô điểm tới mép màn hình
const CROWN_PX := 3.0                   # mỗi điểm của vương miện to 3 x 3
const EVENT_Y := 190.0                  # banner sự kiện: mép trên (nằm dưới dòng thông báo giữa trên, giữa hai ô điểm)
const EVENT_SIZE_ROLL := Vector2(520, 112)    # khung banner lúc đang quay roulette
const EVENT_SIZE_ACTIVE := Vector2(560, 68)   # khung banner gọn lúc sự kiện đang chạy: nằm ở dải trên giữa hai ô điểm (y 12..80), thay vương miện và "FIRST TO"
const EVENT_ACTIVE_Y := 12.0           # mép trên của banner gọn (bằng mép trên các ô điểm)
const ROULETTE_TICKS := 18              # roulette nhảy qua bấy nhiêu tên trước khi dừng

var win_score := 5                      # điểm cần để thắng (hiện ở giữa trên)
var win_panel: PanelContainer           # bảng thắng cuộc (null = chưa hiện)
var rematch_button: Button              # nút chơi lại trận (null khi chưa có bảng thắng)
var menu_button: Button                 # nút về menu (null khi chưa có bảng thắng)
var message_label: Label                # chữ thông báo giữa trên (đọc để kiểm tra)
var _scores := [0, 0]                   # điểm hiện tại [người chơi 1, người chơi 2]
var _frame: StyleBoxTexture             # khung SHADOW làm nền cho các ô điểm
var _flash_tween: Tween                 # hiệu ứng mờ dần của thông báo đang chạy (để hủy khi có thông báo mới)
var event_state := ""                   # banner sự kiện: "" = ẩn, "roulette" = đang quay, "active" = đang chạy (đọc để kiểm tra)
var event_text := ""                    # chữ đang hiện trên banner sự kiện (đọc để kiểm tra)
var event_fraction := 0.0               # thanh đếm ngược còn đầy bao nhiêu (1 -> 0), chỉ có nghĩa khi event_state == "active"
var _event_color := Color.WHITE         # màu chữ của sự kiện đang hiện
var _event_time := 0.0                  # banner đã hiện được bao lâu (giây)
var _event_seconds := 1.0               # tổng thời gian của banner (quay roulette hoặc đếm ngược)
var _roulette_ticks: Array = []         # lịch quay: mỗi phần tử [thời điểm, tên] theo thứ tự thời gian
var _roulette_total := 0.0              # thời điểm roulette dừng hẳn ở sự kiện đã chọn


## brawl.gd gọi khi vào trận: cài giao diện, nhớ số điểm thắng.
func setup(target_score: int) -> void:
	theme = UiTheme.make()                      # áp bộ giao diện chung (font, màu, khung)
	win_score = target_score                    # nhớ số điểm cần để thắng
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # không chặn chuột (trừ bảng thắng)
	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)   # khung nền cho ô điểm
	set_process(false)                          # _process chỉ chạy khi banner sự kiện đang hiện

	message_label = Label.new()                 # chữ thông báo giữa trên
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)   # neo ở giữa mép trên
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều hai bên để chữ luôn ở giữa
	message_label.position.y = 118              # nằm dưới ô điểm, trên vùng chơi
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	message_label.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)   # chữ to
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)   # viền chữ đen cho dễ đọc
	message_label.add_theme_constant_override("outline_size", 10)   # viền dày 10 pixel
	message_label.modulate.a = 0.0              # lúc đầu chưa có thông báo
	add_child(message_label)                    # gắn vào HUD

	# dòng nhắc phím: người chơi 1 ở góc dưới trái, người chơi 2 ở góc dưới phải, Esc ở giữa
	_add_hint("P1:  A / D + W", Control.PRESET_BOTTOM_LEFT, PLAYER_COLORS[0].lightened(0.35))
	_add_hint("P2:  LEFT / RIGHT + UP", Control.PRESET_BOTTOM_RIGHT, PLAYER_COLORS[1].lightened(0.35))
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


## Đặt điểm của người chơi `player_id` (1 hoặc 2).
func set_score(player_id: int, value: int) -> void:
	_scores[player_id - 1] = value              # nhớ điểm mới
	queue_redraw()                              # vẽ lại ô điểm


## Đặt điểm cả hai người chơi cùng lúc.
func set_scores(p1: int, p2: int) -> void:
	_scores = [p1, p2]                          # nhớ điểm mới của cả hai
	queue_redraw()                              # vẽ lại ô điểm


## Hiện dòng chữ giữa trên màn hình `seconds` giây rồi mờ dần. `color` là màu chữ (mặc định xanh rêu).
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


## Banner sự kiện, kiểu máy đánh bạc: các tên trong `names` nhấp nháy qua thật nhanh, chậm dần rồi dừng ở `chosen` (cuối `seconds` giây).
## Quay xong banner đứng nguyên (nhấp nháy) cho tới khi gọi show_event() hoặc hide_event().
## `color`: màu chữ nhấp nháy khi dừng.
func show_event_roulette(names: Array, chosen: String, seconds := 2.0, color := UiTheme.ACCENT) -> void:
	if names.is_empty():                        # không có tên nào để quay
		return
	_roulette_ticks.clear()                     # lập lịch quay mới
	var chosen_index := maxi(0, names.find(chosen))   # tên được chọn nằm ở đâu trong danh sách
	for i in ROULETTE_TICKS:                    # từng lần nhảy
		var t := seconds * 0.72 * pow(float(i) / (ROULETTE_TICKS - 1), 1.8)   # thời điểm nhảy: dày lúc đầu, thưa dần
		var shown: String = names[posmod(chosen_index - (ROULETTE_TICKS - 1 - i), names.size())]   # lần nhảy cuối rơi đúng vào tên được chọn
		_roulette_ticks.append([t, shown])      # ghi vào lịch
	_roulette_total = _roulette_ticks[-1][0]    # thời điểm dừng hẳn
	_event_seconds = maxf(seconds, 0.1)         # tổng thời gian roulette
	_event_time = 0.0                           # bắt đầu từ 0
	_event_color = color                        # màu chữ khi dừng
	event_state = "roulette"                    # đang quay
	event_text = _roulette_ticks[0][1]          # tên đầu tiên
	set_process(true)                           # bật cập nhật mỗi khung
	queue_redraw()                              # vẽ lại


## Banner sự kiện đang chạy: tên sự kiện và thanh đếm ngược `seconds` giây (thanh cạn dần, banner ở yên cho tới hide_event()).
func show_event(event_name: String, seconds: float, color := UiTheme.ACCENT) -> void:
	event_state = "active"                      # đang chạy
	event_text = event_name                     # tên sự kiện
	_event_color = color                        # màu chữ
	_event_seconds = maxf(seconds, 0.01)        # tổng thời gian đếm ngược
	_event_time = 0.0                           # bắt đầu từ 0
	event_fraction = 1.0                        # thanh đầy
	set_process(true)                           # bật cập nhật mỗi khung
	queue_redraw()                              # vẽ lại


## Ẩn banner sự kiện (đang quay hay đang chạy đều ẩn).
func hide_event() -> void:
	event_state = ""                            # không còn banner
	event_text = ""                             # xoá chữ
	event_fraction = 0.0                        # xoá thanh
	_roulette_ticks.clear()                     # bỏ lịch quay
	set_process(false)                          # tắt cập nhật mỗi khung
	queue_redraw()                              # vẽ lại cho banner biến mất


## Mỗi khung khi banner sự kiện đang hiện: chạy đồng hồ, chọn tên đang hiện của roulette, cạn thanh đếm ngược.
func _process(delta: float) -> void:
	if event_state == "":                       # không có banner
		set_process(false)                      # khỏi chạy nữa
		return
	_event_time += delta                        # cộng thời gian
	if event_state == "roulette":               # đang quay
		for tick in _roulette_ticks:            # tìm lần nhảy mới nhất đã tới giờ
			if tick[0] <= _event_time:          # đã tới giờ lần nhảy này
				event_text = tick[1]            # tên đang hiện
	else:
		event_fraction = clampf(1.0 - _event_time / _event_seconds, 0.0, 1.0)   # thanh cạn dần
	queue_redraw()                              # vẽ lại


## Bảng thắng cuộc: "PLAYER n WINS!", tỉ số, nút Rematch và Menu.
func show_win(winner_id: int, final_scores: Array) -> void:
	if win_panel != null:                       # bảng đã hiện rồi thì thôi
		return
	if _flash_tween:                            # hủy thông báo đang mờ dần
		_flash_tween.kill()                     # để nó không che bảng
	message_label.modulate.a = 0.0              # ẩn thông báo giữa trên
	win_panel = PanelContainer.new()            # tạo bảng có khung
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)   # neo vào giữa màn hình
	win_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều trái phải
	win_panel.grow_vertical = Control.GROW_DIRECTION_BOTH   # nới đều trên dưới
	add_child(win_panel)                        # gắn bảng vào HUD
	var box := VBoxContainer.new()              # cột xếp chữ và nút
	box.add_theme_constant_override("separation", 12)   # khoảng cách giữa các dòng
	win_panel.add_child(box)                    # đặt cột vào bảng
	var title := Label.new()                    # dòng tiêu đề
	title.text = "PLAYER %d WINS!" % winner_id  # vd PLAYER 1 WINS!
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	title.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)   # chữ to
	title.add_theme_color_override("font_color", PLAYER_COLORS[winner_id - 1])   # màu của người thắng
	box.add_child(title)                        # đặt vào cột
	var score_label := Label.new()              # dòng tỉ số
	score_label.text = "%d  -  %d" % [final_scores[0], final_scores[1]]   # vd 5 - 3
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # canh giữa
	score_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)   # chữ vừa
	box.add_child(score_label)                  # đặt vào cột
	var row := HBoxContainer.new()              # hàng chứa các nút
	row.add_theme_constant_override("separation", 14)   # khoảng cách giữa các nút
	row.alignment = BoxContainer.ALIGNMENT_CENTER   # các nút nằm giữa hàng
	box.add_child(row)                          # đặt hàng nút dưới cùng
	rematch_button = Button.new()               # nút chơi lại trận
	rematch_button.text = "Rematch"             # chữ trên nút
	rematch_button.pressed.connect(rematch_pressed.emit)   # bấm thì phát tín hiệu chơi lại
	row.add_child(rematch_button)               # đặt vào hàng
	menu_button = Button.new()                  # nút về menu
	menu_button.text = "Menu"                   # chữ trên nút
	menu_button.pressed.connect(menu_pressed.emit)   # bấm thì phát tín hiệu về menu
	row.add_child(menu_button)                  # đặt vào hàng
	rematch_button.grab_focus()                 # Enter / Space bấm nút Rematch


## Vẽ hai ô điểm (P1 trái, P2 phải) và ô "FIRST TO n" ở giữa trên.
func _draw() -> void:
	if _frame == null:                          # chưa setup xong
		return
	var font := get_theme_default_font()        # font mặc định để vẽ chữ
	for i in 2:                                 # hai người chơi
		var x := MARGIN if i == 0 else size.x - MARGIN - BOX_SIZE.x   # người chơi 1 sát trái, người chơi 2 sát phải
		var box := Rect2(Vector2(x, 12), BOX_SIZE)   # khung ô điểm
		draw_style_box(_frame, box)             # vẽ khung nền
		var col: Color = PLAYER_COLORS[i]       # màu của người chơi này
		# nhãn P1 / P2 bên trái ô
		draw_string(font, box.position + Vector2(34, 50), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, col)
		# điểm số to bên phải ô
		draw_string(font, box.position + Vector2(112, 56), str(_scores[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE, col.lightened(0.2))
		# "/ n" nhỏ cạnh điểm: cho biết cần bao nhiêu điểm để thắng
		draw_string(font, box.position + Vector2(160, 56), "/ %d" % win_score, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.DIM)
	var mid := size.x / 2.0                     # giữa màn hình
	if event_state != "active":                 # sự kiện đang chạy thì banner gọn chiếm chỗ vương miện và chữ FIRST TO (hết sự kiện lại hiện)
		PixelArt.draw_centered(self, PixelArt.CROWN, Vector2(mid, 34), CROWN_PX)   # vương miện pixel
		draw_string(font, Vector2(mid - 100, 70), "FIRST TO %d WINS" % win_score, HORIZONTAL_ALIGNMENT_CENTER, 200, UiTheme.FONT_SMALL, UiTheme.TEXT)
	if event_state != "":                       # có banner sự kiện
		_draw_event_banner(font, mid)           # vẽ banner dưới dòng thông báo


## Vẽ banner sự kiện giữa trên: lúc quay thì tên chạy qua với hai mũi tên hai bên, lúc chạy thì tên và thanh đếm ngược.
func _draw_event_banner(font: Font, mid: float) -> void:
	if event_state == "roulette":               # đang quay roulette
		var box := Rect2(Vector2(mid - EVENT_SIZE_ROLL.x / 2.0, EVENT_Y), EVENT_SIZE_ROLL)   # khung banner
		draw_style_box(_frame, box)             # nền khung giống ô điểm
		draw_string(font, Vector2(box.position.x, box.position.y + 40), "RANDOM EVENT", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_SMALL, UiTheme.DIM)   # tiêu đề nhỏ
		var landed := _event_time >= _roulette_total   # đã dừng ở sự kiện được chọn chưa
		var col := UiTheme.TEXT                 # đang quay: chữ trắng ngả xanh
		if landed:                              # đã dừng: nhấp nháy màu sự kiện cho nổi bật
			col = _event_color if int(_event_time * 8.0) % 2 == 0 else Color.WHITE
		draw_string_outline(font, Vector2(box.position.x, box.position.y + 90), event_text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_LARGE, 8, Color.BLACK)   # viền đen
		draw_string(font, Vector2(box.position.x, box.position.y + 90), event_text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_LARGE, col)   # tên đang hiện
		var arrow := UiTheme.ACCENT if landed else UiTheme.DIM   # mũi tên hai bên sáng lên khi dừng
		var cy := box.position.y + box.size.y / 2.0 + 8.0   # độ cao của mũi tên
		draw_colored_polygon(PackedVector2Array([Vector2(box.position.x + 40, cy - 12), Vector2(box.position.x + 40, cy + 12), Vector2(box.position.x + 58, cy)]), arrow)   # mũi tên trái chỉ vào
		draw_colored_polygon(PackedVector2Array([Vector2(box.end.x - 40, cy - 12), Vector2(box.end.x - 40, cy + 12), Vector2(box.end.x - 58, cy)]), arrow)   # mũi tên phải chỉ vào
		return
	var panel := Rect2(Vector2(mid - EVENT_SIZE_ACTIVE.x / 2.0, EVENT_ACTIVE_Y), EVENT_SIZE_ACTIVE)   # khung banner đang chạy
	draw_style_box(_frame, panel)               # nền khung
	draw_string_outline(font, Vector2(panel.position.x, panel.position.y + 38), event_text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, UiTheme.FONT_MEDIUM, 6, Color.BLACK)   # viền đen
	draw_string(font, Vector2(panel.position.x, panel.position.y + 38), event_text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, UiTheme.FONT_MEDIUM, _event_color)   # tên sự kiện
	var bar := Rect2(Vector2(panel.position.x + 60, panel.position.y + 46), Vector2(panel.size.x - 120, 8))   # thanh đếm ngược
	draw_rect(bar.grow(2), Color("#05080c"))    # nền tối có viền
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * event_fraction, bar.size.y)), _event_color if event_fraction > 0.25 or int(_event_time * 6.0) % 2 == 0 else Color.WHITE)   # phần còn lại, nhấp nháy trắng khi sắp hết
