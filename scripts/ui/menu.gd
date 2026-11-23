extends Control                         # menu là node giao diện (Control)
## Menu chính: nền rừng đêm, dải đất rừng ở dưới có nhân vật đứng sẵn (bấm A/D để nghịch thử),
## tiêu đề có biểu tượng xoay hai bên, các nút chọn màn (tự tạo từ LevelData), cách chơi, nút thoát.

const BALL_SCENE := preload("res://scenes/ball.tscn")   # cảnh nhân vật (quả bóng) đứng trên dải đất
const LOGO := preload("res://assets/ui/logo.png")   # logo tiêu đề (ảnh gốc 585 x 214)
const LOGO_SIZE := Vector2(410, 150)                # kích thước hiển thị (70% ảnh gốc)

@onready var title: Label = $Center/Box/Title   # chữ tiêu đề (bị ẩn, thay bằng logo)
@onready var level_grid: GridContainer = $Center/Box/LevelGrid   # lưới chứa các nút chọn màn
@onready var help: Label = $Center/Box/Help   # dòng hướng dẫn ngắn
@onready var quit_button: Button = $Center/Box/QuitButton   # nút thoát game

var brawl_button: Button                # nút BRAWL 2P (chế độ đấu 2 người)
var _demo_ball: Ball                    # nhân vật đứng nghịch ở dải đất
var _demo_start := Vector2.ZERO         # chỗ đứng ban đầu, để đưa về khi rơi ra ngoài
var _howto: PanelContainer              # bảng HOW TO PLAY (null = đang đóng)

## Nội dung bảng HOW TO PLAY: [tiêu đề mục, các dòng]. Sửa chữ ở đây.
const HOW_TO_PLAY := [
	# mục 1: di chuyển và nhảy
	["MOVE & JUMP", [
		"Hold A / D (or LEFT / RIGHT) to tilt and charge, then press SPACE / W / UP to jump.",
		"The longer you charge, the farther you jump. Let go of A / D without jumping to cancel.",
		"Press jump without A / D to jump straight up."]],
	# mục 2: bắn súng
	["SHOOT", [
		"Pick up a gun (grey gun icon) to get 15 bullets. Your ammo shows under your hearts.",
		"Press F or J to shoot straight ahead. Hold A / D while shooting to aim up diagonally.",
		"Bullets kill slimes and hurt the boss."]],
	# mục 3: cách đánh boss
	["BOSS", [
		"It only rolls along the ground. Touching its side hurts you.",
		"When a red ! appears it stops and shakes, then charges at you: jump over it!",
		"After it hits a wall it is dizzy. Shoot it, or jump on its head. Every hit = 1 damage."]],
	# mục 4: vật phẩm và phím tắt
	["ITEMS", [
		"Heart: +1 life.   Shield: blocks one hit.   Green arrow: higher jumps for 10 seconds.",
		"Star: points.   R: respawn.   Esc: menu."]],
]


## Khi menu mở: áp giao diện, dựng dải đất trang trí, tạo nút cho từng màn.
func _ready() -> void:
	theme = UiTheme.make()                      # áp bộ giao diện chung
	_build_ground()                             # dựng dải đất rừng và nhân vật ở đáy
	$Center.offset_bottom = -110                       # đẩy khối nút lên trên, chừa chỗ cho dải đất

	# Tiêu đề: logo của nhóm (assets/ui/logo.png) thay cho chữ, phập phồng nhẹ.
	title.hide()                                       # giữ node Title (chữ) nhưng ẩn đi
	var logo := TextureRect.new()               # khung hiện ảnh logo
	logo.texture = LOGO                         # gán ảnh logo
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # cho đặt cỡ tùy ý, không theo cỡ ảnh
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # giữ tỉ lệ ảnh, canh giữa
	logo.custom_minimum_size = LOGO_SIZE        # cỡ hiển thị của logo
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # giữ pixel sắc nét
	logo.pivot_offset = LOGO_SIZE / 2.0         # tâm phóng to nằm giữa logo
	var box := title.get_parent()               # khối chứa tiêu đề và các nút
	box.add_theme_constant_override("separation", 8)   # thêm nút BRAWL 2P nên thu hẹp khoảng cách giữa các hàng (14 -> 8) cho vừa màn hình
	box.add_child(logo)                         # gắn logo vào khối
	box.move_child(logo, title.get_index())     # đưa logo lên đúng chỗ của tiêu đề
	var tw := logo.create_tween().set_loops()         # phập phồng nhẹ cho sinh động
	tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)   # phóng to 3% trong 0.9 giây
	tw.tween_property(logo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)   # rồi thu về cỡ cũ

	help.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)   # dòng hướng dẫn: chữ nhỏ
	help.add_theme_color_override("font_color", UiTheme.DIM)   # màu chữ mờ
	var endless := Button.new()                       # nút chế độ vô tận, đứng đầu danh sách
	endless.text = "ENDLESS RUN   best %d" % Game.best_score   # hiện kèm kỷ lục điểm
	endless.custom_minimum_size = Vector2(380, 60)   # cỡ nút

	endless.pressed.connect(Game.start_endless)   # bấm là vào chế độ vô tận
	level_grid.add_child(endless)               # đặt vào lưới nút
	var star_icon := _star_texture()            # ngôi sao pixel (font Peaberry không có ký tự ★, trình duyệt cũng không có font dự phòng)
	for i in LevelData.LEVELS.size():           # tạo một nút cho mỗi màn
		var b := Button.new()                   # nút mới
		var stars: int = Game.best_stars.get(i, 0)   # số sao tốt nhất của màn i (chưa chơi = 0)
		b.text = "%d. %s   %d" % [i + 1, LevelData.LEVELS[i]["name"], stars]   # hiện số sao tốt nhất
		b.icon = star_icon                      # ngôi sao pixel nằm sau con số
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT   # icon đứng bên phải chữ
		b.expand_icon = false                   # giữ đúng cỡ icon, không kéo giãn
		b.custom_minimum_size = Vector2(380, 56)   # cỡ nút
		b.pressed.connect(Game.start_level.bind(i))    # bấm là vào màn i
		level_grid.add_child(b)                 # đặt vào lưới
	var bank := HBoxContainer.new()                    # hàng tổng sao đã gom: icon sao + chữ
	bank.alignment = BoxContainer.ALIGNMENT_CENTER     # canh giữa
	var bank_icon := TextureRect.new()                 # icon ngôi sao
	bank_icon.texture = star_icon                      # dùng chung hình sao pixel
	bank_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED   # giữ cỡ gốc, nằm giữa ô
	bank.add_child(bank_icon)                          # đặt icon vào hàng
	var bank_text := Label.new()                       # chữ số sao
	bank_text.text = "%d stars collected" % Game.total_stars   # vd: 12 stars collected
	bank_text.add_theme_color_override("font_color", Color("#f7d046"))   # chữ màu vàng
	bank.add_child(bank_text)                          # đặt chữ sau icon
	brawl_button = Button.new()                        # nút chế độ đấu 2 người, một hàng rộng ngay dưới lưới nút
	brawl_button.text = "BRAWL 2P"                     # chữ trên nút
	brawl_button.custom_minimum_size = Vector2(0, 56)   # cao 56; chiều ngang tự giãn rộng đúng bằng lưới nút màn
	brawl_button.add_theme_color_override("font_color", Color("#ff8e9c"))   # chữ đỏ hồng, nhắc màu người chơi 1
	brawl_button.pressed.connect(Game.start_brawl.bind(false))   # bấm là vào chế độ đấu 2 người
	level_grid.get_parent().add_child(brawl_button)   # gắn vào khối chứa lưới nút
	level_grid.get_parent().move_child(brawl_button, level_grid.get_index() + 1)   # đặt ngay dưới lưới nút
	level_grid.get_parent().add_child(bank)     # gắn vào khối chứa lưới nút
	level_grid.get_parent().move_child(bank, brawl_button.get_index() + 1)   # đặt ngay dưới nút BRAWL 2P
	level_grid.columns = 2                             # các nút màn xếp 2 cột cho gọn
	level_grid.add_theme_constant_override("h_separation", 12)   # khoảng cách ngang giữa hai cột
	var bottom_row := HBoxContainer.new()              # hàng dưới cùng: HOW TO PLAY và Quit
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER   # các nút nằm giữa hàng
	bottom_row.add_theme_constant_override("separation", 12)   # khoảng cách giữa các nút
	quit_button.get_parent().add_child(bottom_row)   # gắn hàng vào khối chứa nút Quit
	quit_button.get_parent().move_child(bottom_row, quit_button.get_index())   # đặt hàng vào đúng chỗ nút Quit
	var howto_button := Button.new()                   # nút mở bảng hướng dẫn
	howto_button.text = "HOW TO PLAY"           # chữ trên nút
	howto_button.custom_minimum_size = Vector2(240, 52)   # cỡ nút
	howto_button.pressed.connect(_show_howto)   # bấm là mở bảng hướng dẫn
	bottom_row.add_child(howto_button)          # đặt vào hàng
	quit_button.reparent(bottom_row)            # chuyển nút Quit vào hàng dưới cùng
	# dòng hướng dẫn ngắn dưới các nút
	help.text = "Hold A / D to aim, SPACE to jump, F / J to shoot.  Open HOW TO PLAY for everything else."
	quit_button.custom_minimum_size = Vector2(160, 52)   # cỡ nút Quit
	quit_button.pressed.connect(get_tree().quit)   # bấm là thoát game
	quit_button.visible = not OS.has_feature("web")   # trên trình duyệt (itch.io) không thoát được nên ẩn nút Quit
	level_grid.get_child(0).grab_focus()               # chọn sẵn màn 1, bấm Enter là chơi


## Dải đất rừng ở đáy menu (dùng chính Level và bộ gạch), có nhân vật đứng chơi được.
## Tạo ảnh ngôi sao vàng từ hình pixel STAR của HUD, phóng 3 lần (21 x 21).
func _star_texture() -> ImageTexture:
	const PX := 3                               # mỗi ô pixel của hình = 3 x 3 pixel thật
	var pattern: Array = Hud.STAR               # hình ngôi sao 7 x 7 (chuỗi "0"/"1")
	var img := Image.create(7 * PX, 7 * PX, false, Image.FORMAT_RGBA8)   # ảnh trong suốt
	for y in pattern.size():                    # duyệt từng hàng của hình
		for x in pattern[y].length():           # duyệt từng ô trong hàng
			if pattern[y][x] == "1":            # ô "1" là có màu
				img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), Color("#f7d046"))   # tô ô màu vàng
	return ImageTexture.create_from_image(img)  # đổi ảnh thành texture để hiển thị


func _build_ground() -> void:
	var rows := []                              # các hàng của bản đồ chữ
	for r in 23:                                # bản đồ cao 23 hàng
		rows.append(".".repeat(40))             # mỗi hàng 40 ô trống
	rows[18] = ".".repeat(30) + "####" + ".".repeat(6)         # một mô đất nhỏ bên phải
	rows[19] = "....O" + ".".repeat(25) + "####" + ".".repeat(6)   # O = chỗ nhân vật đứng; thêm mô đất
	for r in range(20, 23):                     # 3 hàng cuối
		rows[r] = "#".repeat(40)                # toàn đất
	var level := Level.new()                    # tạo màn chơi để vẽ dải đất
	add_child(level)                            # gắn vào menu
	move_child(level, 1)                                       # vẽ sau nền, trước các nút
	level.build("\n".join(rows))                # dựng gạch từ bản đồ chữ
	_demo_start = level.start_position          # lấy chỗ đứng (ô O)
	_demo_ball = BALL_SCENE.instantiate()       # tạo nhân vật
	_demo_ball.position = _demo_start           # đặt vào chỗ đứng
	level.add_child(_demo_ball)                 # gắn nhân vật vào màn


## Bảng HOW TO PLAY: các mục hướng dẫn, nút Close (hoặc Esc) để đóng.
func _show_howto() -> void:
	if _howto:                                  # bảng đang mở rồi thì thôi
		return
	$Center.hide()                                     # ẩn menu phía sau cho bảng dễ đọc
	_howto = PanelContainer.new()               # tạo bảng có khung
	_howto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)   # neo vào giữa màn hình
	_howto.grow_horizontal = Control.GROW_DIRECTION_BOTH   # nới đều trái phải
	_howto.grow_vertical = Control.GROW_DIRECTION_BOTH   # nới đều trên dưới
	add_child(_howto)                           # gắn bảng vào menu
	var box := VBoxContainer.new()              # cột xếp các dòng chữ
	box.add_theme_constant_override("separation", 6)   # khoảng cách giữa các dòng
	_howto.add_child(box)                       # đặt cột vào bảng
	for section in HOW_TO_PLAY:                 # từng mục hướng dẫn
		var head := Label.new()                 # dòng tiêu đề mục
		head.text = section[0]                  # tên mục
		head.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)   # chữ vừa
		head.add_theme_color_override("font_color", UiTheme.ACCENT)   # màu nhấn
		box.add_child(head)                     # đặt vào cột
		for line in section[1]:                 # từng dòng nội dung của mục
			var l := Label.new()                # chữ mới
			l.text = "  " + line                # thụt vào 2 dấu cách
			l.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)   # chữ nhỏ
			box.add_child(l)                    # đặt vào cột
	var close := Button.new()                   # nút đóng bảng
	close.text = "Close"                        # chữ trên nút
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # nút gọn, nằm giữa
	close.pressed.connect(_hide_howto)          # bấm là đóng bảng
	box.add_child(close)                        # đặt cuối bảng
	close.grab_focus()                          # chọn sẵn nút Close, bấm Enter là đóng


# Đóng bảng HOW TO PLAY, hiện lại menu.
func _hide_howto() -> void:
	if _howto:                                  # bảng đang mở thì
		_howto.queue_free()                     # xóa bảng
		_howto = null                           # đánh dấu đã đóng
		$Center.show()                          # hiện lại menu
		level_grid.get_child(0).grab_focus()    # chọn lại nút đầu tiên


# Godot gọi khi có phím bấm chưa nơi nào xử lý.
func _unhandled_input(event: InputEvent) -> void:
	if _howto and event.is_action_pressed("back"):   # đang mở bảng mà bấm Esc (back)
		_hide_howto()                           # thì đóng bảng


## Nhân vật nhảy ra khỏi màn hình thì đưa về chỗ cũ.
func _physics_process(_delta: float) -> void:
	# nhân vật ra khỏi khung hình (trái, phải hoặc rơi xuống dưới)
	if _demo_ball and (_demo_ball.global_position.x < -40 or _demo_ball.global_position.x > 1320 or _demo_ball.global_position.y > 800):
		_demo_ball.teleport(_demo_start)        # đưa về chỗ đứng ban đầu
