extends Node2D
## Cảnh chơi một màn: dựng màn, thả bóng, camera đi theo, tính mạng, sao, hồi sinh, qua màn.

const BALL_SCENE := preload("res://scenes/ball.tscn")   # nạp sẵn cảnh quả bóng để tạo ra khi cần
const LIVES := 3                    # số mạng mỗi lần vào màn
const RESPAWN_DELAY := 0.8          # chết rồi chờ bao lâu mới hồi sinh
const FALL_MARGIN := 160.0          # rơi thấp hơn đáy màn bao nhiêu pixel thì tính là chết

@onready var camera: Camera2D = $Camera   # lấy node camera con khi cảnh sẵn sàng
@onready var hud: Hud = $HUD/Hud          # lấy giao diện HUD (mạng, sao, bảng thông báo)

var level: Level                    # màn đang chơi
var ball: Ball                      # quả bóng người chơi điều khiển
var lives := LIVES                  # số mạng còn lại
var stars := 0                      # số sao đã nhặt trong màn
var respawn_position := Vector2.ZERO   # cờ lưu gần nhất (lúc đầu là chỗ xuất phát)
var _busy := false                      # đang chết / đã qua màn: bỏ qua sự kiện khác


## Dựng màn theo Game.level_index và nối các tín hiệu.
func _ready() -> void:
	var data: Dictionary = LevelData.LEVELS[Game.level_index]   # lấy dữ liệu màn đang chọn
	level = Level.new()                           # tạo màn mới
	add_child(level)                              # thêm màn vào cảnh
	move_child(level, 0)                          # vẽ màn dưới camera và giao diện
	level.build(data["map"])                      # dựng gạch, vật thể theo bản đồ chữ

	ball = BALL_SCENE.instantiate()               # tạo quả bóng từ cảnh mẫu
	ball.position = level.start_position          # đặt bóng ở điểm xuất phát
	level.add_child(ball)                         # thêm bóng vào màn
	respawn_position = level.start_position       # chỗ hồi sinh ban đầu là điểm xuất phát

	ball.hurt.connect(_on_ball_hurt)              # bóng bị thương thì gọi _on_ball_hurt
	level.star_collected.connect(_on_star)        # nhặt sao thì gọi _on_star
	# chạm cờ lưu thì nhớ vị trí cờ làm chỗ hồi sinh
	level.checkpoint_reached.connect(func(pos: Vector2) -> void: respawn_position = pos)
	level.finished.connect(_on_finished)          # chạm đích thì gọi _on_finished

	camera.limit_left = 0                         # camera không đi ra ngoài màn
	camera.limit_top = mini(-int(TILE_MARGIN), int(level.size.y) - 720)   # màn thấp hơn màn hình: canh đáy màn sát đáy màn hình
	camera.limit_right = int(level.size.x)        # camera không vượt mép phải màn
	camera.limit_bottom = int(level.size.y)       # camera không nhìn xuống dưới đáy màn
	camera.global_position = ball.global_position # đặt camera ngay chỗ bóng
	camera.reset_smoothing()                      # bỏ hiệu ứng trượt, nhảy thẳng tới chỗ mới

	hud.setup(data["name"], LIVES, level.star_total)   # cài HUD: tên màn, số mạng, tổng số sao
	hud.next_pressed.connect(_on_next)            # bấm "màn tiếp" thì gọi _on_next
	# bấm "chơi lại" thì vào lại màn hiện tại
	hud.retry_pressed.connect(func() -> void: Game.start_level(Game.level_index))
	hud.menu_pressed.connect(Game.go_to_menu)     # bấm "menu" thì về menu
	hud.watch_ball(ball)                          # HUD hiện số đạn, khiên
	hud.watch_level(level)                        # HUD hiện thanh máu boss
	level.heart_collected.connect(_on_heart)      # nhặt tim thì gọi _on_heart

const TILE_MARGIN := 64.0   # cho camera nhìn cao hơn đỉnh màn một chút


## 60 lần mỗi giây: camera theo bóng, kiểm tra rơi vực, phím tắt.
func _physics_process(_delta: float) -> void:
	if not ball.dead:                             # bóng còn sống
		camera.global_position = ball.global_position + Vector2(ball.linear_velocity.x * 0.25, -40)  # nhìn trước theo hướng lăn
		if ball.global_position.y > level.size.y + FALL_MARGIN:   # rơi xuống vực
			_on_ball_hurt()                       # tính là bị thương
	if Input.is_action_just_pressed("restart") and not _busy:   # bấm R khi không bận
		_on_ball_hurt()                           # R: tự nổ, về cờ lưu (mất 1 mạng), thùng về chỗ cũ
	if Input.is_action_just_pressed("back"):      # bấm Esc
		Game.go_to_menu()                         # Esc: về menu


## Bóng bị thương: trừ mạng, vỡ bóng, hồi sinh ở cờ lưu. Hết mạng thì chơi lại màn.
func _on_ball_hurt() -> void:
	if _busy:                                     # đang chết / đã qua màn thì bỏ qua
		return
	_busy = true                                  # khóa lại, tránh bị trừ mạng 2 lần
	lives -= 1                                    # trừ 1 mạng
	hud.set_lives(lives)                          # cập nhật số mạng trên HUD
	_pop_effect(ball.global_position)             # hiệu ứng bóng vỡ tại chỗ chết
	ball.dead = true                              # đánh dấu bóng đã chết
	ball.hide()                                   # ẩn bóng
	ball.teleport(respawn_position)               # dịch bóng về cờ lưu (đang ẩn)
	if lives <= 0:                                # hết mạng
		hud.show_message("Out of lives! Restarting...")   # báo hết mạng
		await get_tree().create_timer(1.4).timeout   # chờ 1,4 giây cho người chơi đọc
		Game.start_level(Game.level_index)        # chơi lại màn từ đầu
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout   # chờ một lúc rồi hồi sinh
	ball.teleport(respawn_position)               # đặt lại bóng ở cờ lưu
	level.reset_crates()                          # thùng về chỗ cũ để không bị kẹt
	camera.global_position = respawn_position     # camera nhảy tới chỗ hồi sinh
	ball.dead = false                             # bóng sống lại
	ball.invuln = 1.0                             # vừa hồi sinh: miễn sát thương 1 giây
	ball.show()                                   # hiện bóng
	_busy = false                                 # mở khóa


## Nhặt trái tim: +1 mạng, tối đa LIVES.
func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)                # thêm 1 mạng nhưng không vượt LIVES
	hud.set_lives(lives)                          # cập nhật số mạng trên HUD


func _on_star() -> void:
	stars += 1                                    # thêm 1 sao
	hud.set_stars(stars)                          # cập nhật số sao trên HUD


## Chạm đích: dừng bóng, ghi sao, hiện bảng qua màn.
func _on_finished() -> void:
	if _busy:                                     # đang chết hoặc đã qua màn thì bỏ qua
		return
	_busy = true                                  # khóa, không xử lý sự kiện khác nữa
	ball.dead = true                              # dừng điều khiển bóng
	Game.record_stars(Game.level_index, stars)    # lưu số sao của màn
	var has_next := Game.level_index + 1 < LevelData.LEVELS.size()   # còn màn kế tiếp không
	hud.show_complete(stars, level.star_total, has_next)   # hiện bảng qua màn


func _on_next() -> void:
	if not Game.next_level():                     # sang màn kế; nếu không còn màn nào
		Game.go_to_menu()                         # màn cuối: về menu


## Hiệu ứng bóng vỡ thành mảnh.
func _pop_effect(pos: Vector2) -> void:
	var p := CPUParticles2D.new()                 # tạo bộ phát hạt
	p.one_shot = true                             # chỉ phát một lần
	p.amount = 18                                 # 18 mảnh vỡ
	p.lifetime = 0.7                              # mỗi mảnh tồn tại 0,7 giây
	p.explosiveness = 1.0                         # bắn ra tất cả cùng lúc
	p.spread = 180.0                              # bắn tỏa ra mọi hướng
	p.initial_velocity_min = 120.0                # tốc độ bay nhỏ nhất
	p.initial_velocity_max = 260.0                # tốc độ bay lớn nhất
	p.gravity = Vector2(0, 900)                   # mảnh rơi xuống do trọng lực
	p.scale_amount_min = 3.0                      # mảnh nhỏ nhất
	p.scale_amount_max = 5.0                      # mảnh lớn nhất
	p.color = Color("#ffb020")                    # màu cam của bóng
	p.position = pos                              # đặt ở chỗ bóng vỡ
	level.add_child(p)                            # thêm vào màn
	p.emitting = true                             # bắt đầu phát hạt
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)   # sau 1 giây thì xóa bộ phát hạt
