class_name Hud
extends Control
## Giao diện trong màn: tên màn, mạng (trái tim), sao, thông báo, bảng qua màn.
## Tạo hết bằng code; muốn đổi vị trí, cỡ chữ thì sửa trong setup().

signal next_pressed
signal retry_pressed
signal menu_pressed

var _lives := 3
var _max_lives := 3
var _stars := 0
var _star_total := 0
var _title: Label
var _message: Label
var _panel: PanelContainer
var _frame: StyleBoxTexture             # khung SHADOW dùng làm nền cho ô mạng và ô sao
var _endless := false                   # đang ở chế độ vô tận (hiện điểm, không hiện "x / tổng sao")
var _score_label: Label
var _mult_label: Label
var _ammo := 0                          # số đạn (hiện ô đạn khi > 0)
var _shield := false                    # đang có khiên (hiện biểu tượng cạnh tim)
var _boss: Node = null                  # boss đang đánh (null = không có thanh máu)
var _boss_hp := 0
var _boss_max := 0

## Hình pixel 7 x 7 (1 = tô màu) cho trái tim và ngôi sao, vẽ phóng to cho hợp kiểu pixel art.
const HEART := ["0110110", "1111111", "1111111", "1111111", "0111110", "0011100", "0001000"]
const STAR := ["0001000", "0011100", "1111111", "0111110", "0011100", "0110110", "0100010"]
const ICON_PX := 4.0                    # mỗi ô của hình pixel to 4 x 4


## play.gd gọi khi vào màn.
func setup(level_name: String, lives: int, star_total: int) -> void:
	theme = UiTheme.make()
	_max_lives = lives
	_lives = lives
	_star_total = star_total
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # không chặn chuột

	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)

	var top := HBoxContainer.new()               # tên màn ở giữa trên cùng, hai bên có biểu tượng xoay
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 12
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var spin_l := SpinnerIcon.new()
	spin_l.pixel_scale = 2.0
	top.add_child(spin_l)
	_title = Label.new()
	_title.text = level_name.to_upper()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", UiTheme.CYAN)
	top.add_child(_title)
	var spin_r := SpinnerIcon.new()
	spin_r.pixel_scale = 2.0
	top.add_child(spin_r)

	_message = Label.new()                       # thông báo giữa màn hình
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message.add_theme_font_size_override("font_size", 36)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 8)
	add_child(_message)

	var hint := Label.new()
	hint.text = "R: back to checkpoint (-1 life)   Esc: menu"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position -= Vector2(420, 38)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UiTheme.DIM)
	add_child(hint)
	queue_redraw()


## Chế độ vô tận: như setup() nhưng thêm điểm số to ở giữa và hệ số nhân.
func setup_endless(lives: int) -> void:
	setup("Endless Run", lives, 0)
	_endless = true
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 44
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -6)
	add_child(box)
	_score_label = Label.new()                   # điểm số
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 44)
	_score_label.add_theme_color_override("font_color", UiTheme.TEXT)
	box.add_child(_score_label)
	_mult_label = Label.new()                    # hệ số nhân
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mult_label.add_theme_font_size_override("font_size", 22)
	_mult_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(_mult_label)


## Cập nhật điểm và hệ số nhân (chế độ vô tận).
func set_score(score: int, mult: int) -> void:
	_score_label.text = "%07d" % score
	_mult_label.text = "x%d" % mult


## Hiện dòng chữ giữa màn hình `seconds` giây rồi mờ dần.
func flash(text: String, seconds := 0.9) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", UiTheme.ACCENT)
	_message.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_message, "modulate:a", 0.0, 0.5)


## Bảng thua ở chế độ vô tận: điểm, kỷ lục, sao gom được, nút chơi lại / menu.
func show_game_over(score: int, best: int, new_best: bool, stars: int, total_stars: int) -> void:
	_message.text = ""
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var lines := [
		["GAME OVER", 44, UiTheme.ACCENT],
		["Score  %d" % score, 30, UiTheme.TEXT],
		["NEW BEST!" if new_best else "Best  %d" % best, 22, Color("#f7d046") if new_best else UiTheme.DIM],
		["Stars  +%d   (total %d)" % [stars, total_stars], 22, UiTheme.TEXT],
	]
	for l in lines:
		var lab := Label.new()
		lab.text = l[0]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", l[1])
		lab.add_theme_color_override("font_color", l[2])
		box.add_child(lab)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for item in [["Menu", menu_pressed], ["Play again", retry_pressed]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1].emit)
		row.add_child(b)
	row.get_child(1).grab_focus()                # Enter để chơi lại ngay


## Theo dõi nhân vật: số đạn, khiên.
func watch_ball(ball: Ball) -> void:
	ball.ammo_changed.connect(func(n: int) -> void:
		if _ammo == 0 and n > 0:
			flash("GOT A GUN!
Press F or J to shoot", 1.8)   # nhắc cách bắn mỗi khi có súng lại
		_ammo = n
		queue_redraw())
	ball.shield_changed.connect(func(on: bool) -> void:
		_shield = on
		queue_redraw())


## Theo dõi một màn / một đoạn: boss xuất hiện và bị hạ.
func watch_level(level: Level) -> void:
	level.boss_started.connect(_on_boss_started)
	level.boss_defeated.connect(_on_boss_defeated)


func _on_boss_started(boss: Node) -> void:
	_boss = boss
	_boss_max = boss.max_hp
	_boss_hp = boss.hp
	boss.hp_changed.connect(func(hp: int, max_hp: int) -> void:
		_boss_hp = hp
		_boss_max = max_hp
		queue_redraw())
	flash("%s APPEARS!
Shoot it (F / J) or jump on its head.
When it shows a red ! - jump over its charge!" % boss.boss_name, 2.6)
	queue_redraw()


func _on_boss_defeated(_boss_node: Node) -> void:
	_boss = null
	_boss_max = 0
	flash("BOSS DEFEATED!")
	queue_redraw()


func set_lives(n: int) -> void:
	_lives = n
	queue_redraw()


func set_stars(n: int) -> void:
	_stars = n
	queue_redraw()


func show_message(text: String) -> void:
	_message.text = text


## Bảng qua màn: số sao và 3 nút.
func show_complete(stars: int, total: int, has_next: bool) -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Level complete!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title)
	var star_label := Label.new()
	star_label.text = "Stars: %d / %d" % [stars, total]
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.add_theme_font_size_override("font_size", 24)
	box.add_child(star_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var buttons := [["Menu", menu_pressed], ["Retry", retry_pressed]]
	if has_next:
		buttons.append(["Next level", next_pressed])
	for item in buttons:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1].emit)
		row.add_child(b)
	row.get_child(row.get_child_count() - 1).grab_focus()   # Enter / Space bấm nút cuối


## Vẽ ô mạng (góc trái) và ô sao (góc phải), mỗi ô có khung SHADOW làm nền.
func _draw() -> void:
	if _frame == null:
		return                                   # chưa setup xong
	var left_box := Rect2(16, 12, 40 + _max_lives * 38 + (38 if _shield else 0), 58)
	draw_style_box(_frame, left_box)
	for i in _max_lives:
		var col := Color("#e8455a") if i < _lives else Color(1, 1, 1, 0.18)
		_pixel_icon(HEART, Vector2(38 + i * 38, 27), col)
	if _shield:                                  # biểu tượng khiên ngay sau các trái tim
		PixelArt.draw(self, PixelArt.SHIELD, Vector2(38 + _max_lives * 38, 27), 4.0)
	if _ammo > 0:                                # ô đạn dưới ô mạng
		var ammo_box := Rect2(16, 74, 150, 52)
		draw_style_box(_frame, ammo_box)
		PixelArt.draw(self, PixelArt.GUN, ammo_box.position + Vector2(20, 16), 3.0)
		draw_string(get_theme_default_font(), ammo_box.position + Vector2(64, 35), "x %d" % _ammo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiTheme.TEXT)
		draw_string(get_theme_default_font(), ammo_box.position + Vector2(10, 74), "F / J: shoot   (hold A / D to aim up)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.DIM)
	if _boss_max > 0:
		_draw_boss_bar()

	var right_box := Rect2(size.x - 196, 12, 180, 58)
	draw_style_box(_frame, right_box)
	_pixel_icon(STAR, right_box.position + Vector2(22, 15), Color("#f7d046"))
	var star_text := str(_stars) if _endless else "%d / %d" % [_stars, _star_total]   # vô tận: chỉ đếm số sao
	draw_string(get_theme_default_font(), right_box.position + Vector2(66, 40), star_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiTheme.TEXT)


## Vẽ hình pixel `pattern` (mảng chuỗi "0"/"1") tại `pos` với màu `col`, kèm viền sáng trên cùng cho có khối.
func _pixel_icon(pattern: Array, pos: Vector2, col: Color) -> void:
	for y in pattern.size():
		var row: String = pattern[y]
		for x in row.length():
			if row[x] == "1":
				var c := col.lightened(0.35) if y == 1 and col.a > 0.5 else col
				draw_rect(Rect2(pos + Vector2(x, y) * ICON_PX, Vector2.ONE * ICON_PX), c)


## Thanh máu boss kiểu pixel: khung SHADOW, mỗi ô là 1 máu; ô còn máu đỏ, ô mất máu tối.
func _draw_boss_bar() -> void:
	var w := 520.0
	var y := 128.0 if _endless else 64.0         # chế độ vô tận: nằm dưới điểm số
	var bar := Rect2((size.x - w) / 2.0, y, w, 46)
	draw_style_box(_frame, bar)
	var font := get_theme_default_font()
	var title := "%s   %d / %d" % [_boss.boss_name if _boss else "BOSS", _boss_hp, _boss_max]
	draw_string(font, Vector2(bar.position.x, y - 6), title, HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color("#f2a0aa"))
	var inner := bar.grow(-14)
	var seg_w := inner.size.x / float(_boss_max)
	draw_string(font, Vector2(bar.position.x, y + 66), "Shoot: F / J    Stomp its head    Jump over it when it charges",
		HORIZONTAL_ALIGNMENT_CENTER, w, 15, UiTheme.DIM)
	var phase2 := _boss_hp <= _boss_max / 2
	for i in _boss_max:
		var r := Rect2(inner.position.x + i * seg_w, inner.position.y, seg_w - 2.0, inner.size.y)
		var col := Color("#3a1620")
		if i < _boss_hp:
			col = Color("#ff5d6d") if phase2 else Color("#e8455a")
		draw_rect(r, col)
		if i < _boss_hp:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("#ffb3bb"))   # viền sáng trên mỗi ô
