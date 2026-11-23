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

var win_score := 5                      # điểm cần để thắng (hiện ở giữa trên)
var win_panel: PanelContainer           # bảng thắng cuộc (null = chưa hiện)
var rematch_button: Button              # nút chơi lại trận (null khi chưa có bảng thắng)
var menu_button: Button                 # nút về menu (null khi chưa có bảng thắng)
var message_label: Label                # chữ thông báo giữa trên (đọc để kiểm tra)
var _scores := [0, 0]                   # điểm hiện tại [người chơi 1, người chơi 2]
var _frame: StyleBoxTexture             # khung SHADOW làm nền cho các ô điểm
var _flash_tween: Tween                 # hiệu ứng mờ dần của thông báo đang chạy (để hủy khi có thông báo mới)


## brawl.gd gọi khi vào trận: cài giao diện, nhớ số điểm thắng.
func setup(target_score: int) -> void:
	theme = UiTheme.make()                      # áp bộ giao diện chung (font, màu, khung)
	win_score = target_score                    # nhớ số điểm cần để thắng
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # không chặn chuột (trừ bảng thắng)
	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)   # khung nền cho ô điểm

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
	PixelArt.draw_centered(self, PixelArt.CROWN, Vector2(mid, 34), CROWN_PX)   # vương miện pixel
	draw_string(font, Vector2(mid - 100, 70), "FIRST TO %d WINS" % win_score, HORIZONTAL_ALIGNMENT_CENTER, 200, UiTheme.FONT_SMALL, UiTheme.TEXT)
