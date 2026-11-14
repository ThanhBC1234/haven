extends Control
## Menu chính: nền rừng đêm, dải đất rừng ở dưới có nhân vật đứng sẵn (bấm A/D để nghịch thử),
## tiêu đề có biểu tượng xoay hai bên, các nút chọn màn (tự tạo từ LevelData), cách chơi, nút thoát.

const BALL_SCENE := preload("res://scenes/ball.tscn")

@onready var title: Label = $Center/Box/Title
@onready var level_grid: GridContainer = $Center/Box/LevelGrid
@onready var help: Label = $Center/Box/Help
@onready var quit_button: Button = $Center/Box/QuitButton

var _demo_ball: Ball
var _demo_start := Vector2.ZERO
var _howto: PanelContainer

## Nội dung bảng HOW TO PLAY: [tiêu đề mục, các dòng]. Sửa chữ ở đây.
const HOW_TO_PLAY := [
	["MOVE & JUMP", [
		"Hold A / D (or LEFT / RIGHT) to tilt and charge, then press SPACE / W / UP to jump.",
		"The longer you charge, the farther you jump. Let go of A / D without jumping to cancel.",
		"Press jump without A / D to jump straight up."]],
	["SHOOT", [
		"Pick up a gun (grey gun icon) to get 15 bullets. Your ammo shows under your hearts.",
		"Press F or J to shoot straight ahead. Hold A / D while shooting to aim up diagonally.",
		"Bullets kill slimes and hurt the boss."]],
	["BOSS - GLOOMFANG", [
		"It only rolls along the ground. Touching its side hurts you.",
		"When a red ! appears it stops and shakes, then charges at you: jump over it!",
		"After it hits a wall it is dizzy. Shoot it, or jump on its head. Every hit = 1 damage."]],
	["ITEMS", [
		"Heart: +1 life.   Shield: blocks one hit.   Star: points.   R: respawn.   Esc: menu."]],
]


## Khi menu mở: áp giao diện, dựng dải đất trang trí, tạo nút cho từng màn.
func _ready() -> void:
	theme = UiTheme.make()
	_build_ground()
	$Center.offset_bottom = -110                       # đẩy khối nút lên trên, chừa chỗ cho dải đất

	# Tiêu đề: chữ xanh rêu, viền tối, hai bên là biểu tượng xoay của bộ SHADOW.
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.add_theme_color_override("font_outline_color", Color("#0b1a10"))
	title.add_theme_constant_override("outline_size", 14)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var box := title.get_parent()
	box.add_child(row)
	box.move_child(row, title.get_index())
	title.reparent(row)
	var spin_l := SpinnerIcon.new()
	spin_l.sheet = preload("res://assets/ui/spinner_2.png")
	row.add_child(spin_l)
	row.move_child(spin_l, 0)
	var spin_r := SpinnerIcon.new()
	spin_r.sheet = preload("res://assets/ui/spinner_2.png")
	row.add_child(spin_r)

	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_color", UiTheme.DIM)
	var endless := Button.new()                       # nút chế độ vô tận, đứng đầu danh sách
	endless.text = "ENDLESS RUN   best %d" % Game.best_score
	endless.custom_minimum_size = Vector2(380, 60)
	endless.add_theme_font_size_override("font_size", 24)
	endless.pressed.connect(Game.start_endless)
	level_grid.add_child(endless)
	for i in LevelData.LEVELS.size():
		var b := Button.new()
		var stars: int = Game.best_stars.get(i, 0)
		b.text = "%d. %s   %s" % [i + 1, LevelData.LEVELS[i]["name"], "★".repeat(stars)]   # hiện số sao tốt nhất
		b.custom_minimum_size = Vector2(380, 56)
		b.pressed.connect(Game.start_level.bind(i))    # bấm là vào màn i
		level_grid.add_child(b)
	var bank := Label.new()                            # tổng sao đã gom
	bank.text = "★ %d stars collected" % Game.total_stars
	bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank.add_theme_color_override("font_color", Color("#f7d046"))
	level_grid.get_parent().add_child(bank)
	level_grid.get_parent().move_child(bank, level_grid.get_index() + 1)
	var howto_button := Button.new()                   # nút mở bảng hướng dẫn
	howto_button.text = "HOW TO PLAY"
	howto_button.custom_minimum_size = Vector2(240, 52)
	howto_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	howto_button.pressed.connect(_show_howto)
	quit_button.get_parent().add_child(howto_button)
	quit_button.get_parent().move_child(howto_button, quit_button.get_index())
	help.text = "Hold A / D to aim, SPACE to jump, F / J to shoot.  Open HOW TO PLAY for everything else."
	quit_button.custom_minimum_size = Vector2(160, 52)
	quit_button.pressed.connect(get_tree().quit)
	level_grid.get_child(0).grab_focus()               # chọn sẵn màn 1, bấm Enter là chơi


## Dải đất rừng ở đáy menu (dùng chính Level và bộ gạch), có nhân vật đứng chơi được.
func _build_ground() -> void:
	var rows := []
	for r in 23:
		rows.append(".".repeat(40))
	rows[18] = ".".repeat(30) + "####" + ".".repeat(6)         # một mô đất nhỏ bên phải
	rows[19] = "....O" + ".".repeat(25) + "####" + ".".repeat(6)
	for r in range(20, 23):
		rows[r] = "#".repeat(40)
	var level := Level.new()
	add_child(level)
	move_child(level, 1)                                       # vẽ sau nền, trước các nút
	level.build("\n".join(rows))
	_demo_start = level.start_position
	_demo_ball = BALL_SCENE.instantiate()
	_demo_ball.position = _demo_start
	level.add_child(_demo_ball)


## Bảng HOW TO PLAY: các mục hướng dẫn, nút Close (hoặc Esc) để đóng.
func _show_howto() -> void:
	if _howto:
		return
	_howto = PanelContainer.new()
	_howto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_howto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_howto.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_howto)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_howto.add_child(box)
	for section in HOW_TO_PLAY:
		var head := Label.new()
		head.text = section[0]
		head.add_theme_font_size_override("font_size", 22)
		head.add_theme_color_override("font_color", UiTheme.ACCENT)
		box.add_child(head)
		for line in section[1]:
			var l := Label.new()
			l.text = "  " + line
			l.add_theme_font_size_override("font_size", 17)
			box.add_child(l)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_hide_howto)
	box.add_child(close)
	close.grab_focus()


func _hide_howto() -> void:
	if _howto:
		_howto.queue_free()
		_howto = null
		level_grid.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _howto and event.is_action_pressed("back"):
		_hide_howto()


## Nhân vật nhảy ra khỏi màn hình thì đưa về chỗ cũ.
func _physics_process(_delta: float) -> void:
	if _demo_ball and (_demo_ball.global_position.x < -40 or _demo_ball.global_position.x > 1320 or _demo_ball.global_position.y > 800):
		_demo_ball.teleport(_demo_start)
