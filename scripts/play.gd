extends Node2D
## Cảnh chơi một màn: dựng màn, thả bóng, camera đi theo, tính mạng, sao, hồi sinh, qua màn.

const BALL_SCENE := preload("res://scenes/ball.tscn")
const LIVES := 3                    # số mạng mỗi lần vào màn
const RESPAWN_DELAY := 0.8          # chết rồi chờ bao lâu mới hồi sinh
const FALL_MARGIN := 160.0          # rơi thấp hơn đáy màn bao nhiêu pixel thì tính là chết

@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD/Hud

var level: Level
var ball: Ball
var lives := LIVES
var stars := 0
var respawn_position := Vector2.ZERO   # cờ lưu gần nhất (lúc đầu là chỗ xuất phát)
var _busy := false                      # đang chết / đã qua màn: bỏ qua sự kiện khác


## Dựng màn theo Game.level_index và nối các tín hiệu.
func _ready() -> void:
	var data: Dictionary = LevelData.LEVELS[Game.level_index]
	level = Level.new()
	add_child(level)
	move_child(level, 0)                          # vẽ màn dưới camera và giao diện
	level.build(data["map"])

	ball = BALL_SCENE.instantiate()
	ball.position = level.start_position
	level.add_child(ball)
	respawn_position = level.start_position

	ball.hurt.connect(_on_ball_hurt)
	level.star_collected.connect(_on_star)
	level.checkpoint_reached.connect(func(pos: Vector2) -> void: respawn_position = pos)
	level.finished.connect(_on_finished)

	camera.limit_left = 0                         # camera không đi ra ngoài màn
	camera.limit_top = mini(-int(TILE_MARGIN), int(level.size.y) - 720)   # màn thấp hơn màn hình: canh đáy màn sát đáy màn hình
	camera.limit_right = int(level.size.x)
	camera.limit_bottom = int(level.size.y)
	camera.global_position = ball.global_position
	camera.reset_smoothing()

	hud.setup(data["name"], LIVES, level.star_total)
	hud.next_pressed.connect(_on_next)
	hud.retry_pressed.connect(func() -> void: Game.start_level(Game.level_index))
	hud.menu_pressed.connect(Game.go_to_menu)
	hud.watch_ball(ball)                          # HUD hiện số đạn, khiên
	hud.watch_level(level)                        # HUD hiện thanh máu boss
	level.heart_collected.connect(_on_heart)

const TILE_MARGIN := 64.0   # cho camera nhìn cao hơn đỉnh màn một chút


## 60 lần mỗi giây: camera theo bóng, kiểm tra rơi vực, phím tắt.
func _physics_process(_delta: float) -> void:
	if not ball.dead:
		camera.global_position = ball.global_position + Vector2(ball.linear_velocity.x * 0.25, -40)  # nhìn trước theo hướng lăn
		if ball.global_position.y > level.size.y + FALL_MARGIN:
			_on_ball_hurt()
	if Input.is_action_just_pressed("restart") and not _busy:
		_on_ball_hurt()                           # R: tự nổ, về cờ lưu (mất 1 mạng), thùng về chỗ cũ
	if Input.is_action_just_pressed("back"):
		Game.go_to_menu()                         # Esc: về menu


## Bóng bị thương: trừ mạng, vỡ bóng, hồi sinh ở cờ lưu. Hết mạng thì chơi lại màn.
func _on_ball_hurt() -> void:
	if _busy:
		return
	_busy = true
	lives -= 1
	hud.set_lives(lives)
	_pop_effect(ball.global_position)
	ball.dead = true
	ball.hide()
	ball.teleport(respawn_position)               # dịch bóng về cờ lưu (đang ẩn)
	if lives <= 0:
		hud.show_message("Out of lives! Restarting...")
		await get_tree().create_timer(1.4).timeout
		Game.start_level(Game.level_index)
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	ball.teleport(respawn_position)
	level.reset_crates()                          # thùng về chỗ cũ để không bị kẹt
	camera.global_position = respawn_position
	ball.dead = false
	ball.invuln = 1.0                             # vừa hồi sinh: miễn sát thương 1 giây
	ball.show()
	_busy = false


## Nhặt trái tim: +1 mạng, tối đa LIVES.
func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)
	hud.set_lives(lives)


func _on_star() -> void:
	stars += 1
	hud.set_stars(stars)


## Chạm đích: dừng bóng, ghi sao, hiện bảng qua màn.
func _on_finished() -> void:
	if _busy:
		return
	_busy = true
	ball.dead = true
	Game.record_stars(Game.level_index, stars)
	var has_next := Game.level_index + 1 < LevelData.LEVELS.size()
	hud.show_complete(stars, level.star_total, has_next)


func _on_next() -> void:
	if not Game.next_level():
		Game.go_to_menu()                         # màn cuối: về menu


## Hiệu ứng bóng vỡ thành mảnh.
func _pop_effect(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color("#ffb020")
	p.position = pos
	level.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
