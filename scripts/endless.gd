extends Node2D
## Chế độ vô tận (Endless Run), tính điểm kiểu Subway Surfers.
## - Ghép ngẫu nhiên các đoạn trong SegmentData.SEGMENTS nối tiếp nhau. Luôn dựng sẵn vài đoạn phía trước,
##   đoạn đã đi qua xa thì xóa đi cho nhẹ máy. Đầu lượt chỉ ra đoạn dễ, càng xa càng có đoạn khó.
## - Điểm = quãng đường (1 ô = 1 mét) x hệ số nhân + sao x STAR_POINTS x hệ số nhân.
##   Hệ số nhân tăng 1 sau mỗi SEGMENTS_PER_MULT đoạn đi qua (tối đa MAX_MULT).
## - 3 mạng. Chết thì bật lại ở đầu đoạn đang chơi. Hết mạng là thua: lưu kỷ lục, cộng sao vào tổng sao.

const BALL_SCENE := preload("res://scenes/ball.tscn")
const LIVES := 3
const AHEAD := 2400.0           # luôn có sẵn đoạn tới trước mặt bóng chừng này pixel
const BEHIND := 1600.0          # đoạn nằm sau bóng xa hơn chừng này thì xóa
const METER := 32.0             # 1 ô = 1 mét
const STAR_POINTS := 25         # mỗi sao được bao nhiêu điểm (nhân với hệ số)
const SEGMENTS_PER_MULT := 4    # qua bao nhiêu đoạn thì hệ số nhân tăng 1
const MAX_MULT := 5
const FALL_MARGIN := 160.0
const RESPAWN_DELAY := 0.8
## Độ khó cho phép theo số đoạn đã qua: [qua từ bao nhiêu đoạn, độ khó tối đa].
const DIFFICULTY_STEPS := [[0, 1], [3, 2], [7, 3]]
const BOSS_EVERY := 8           # cứ dựng bao nhiêu đoạn ngẫu nhiên thì chèn một đấu trường boss
const BOSS_POINTS := 500        # hạ boss được bao nhiêu điểm (nhân với hệ số)

@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD/Hud

var chunks: Array[Level] = []   # các đoạn đang có trong màn, theo thứ tự trái sang phải
var ball: Ball
var lives := LIVES
var stars := 0
var score := 0.0
var multiplier := 1
var segments_passed := 0
var _end_x := 0.0               # mép phải của đoạn cuối cùng đã dựng
var _best_x := 0.0              # điểm xa nhất đã tới (chỉ đi tới mới được điểm)
var _next_goal := 0.0           # mép phải của đoạn sắp đi qua (để đếm số đoạn đã qua)
var _goals: Array[float] = []
var _last_name := ""            # tên đoạn vừa dựng, để không lặp liền 2 lần
var _built := 0                 # đã dựng bao nhiêu đoạn (không tính đoạn mở đầu)
var boss_arenas_built := 0      # đã chèn bao nhiêu đấu trường boss
var _rng := RandomNumberGenerator.new()
var _busy := false
var _over := false


## Dựng đoạn mở đầu, thả bóng, dựng sẵn vài đoạn phía trước, cài camera và HUD.
func _ready() -> void:
	_rng.randomize()
	_add_chunk(SegmentData.START, "Start")
	ball = BALL_SCENE.instantiate()
	ball.position = chunks[0].start_position
	ball.z_index = 5                                  # luôn vẽ trên các đoạn
	add_child(ball)
	ball.hurt.connect(_on_ball_hurt)
	_best_x = ball.global_position.x
	_fill_ahead()

	var height := chunks[0].size.y
	camera.limit_left = 0
	camera.limit_top = mini(-64, int(height) - 720)
	camera.limit_bottom = int(height)
	camera.global_position = ball.global_position
	camera.reset_smoothing()

	hud.setup_endless(LIVES)
	hud.watch_ball(ball)
	hud.set_score(0, 1)
	hud.retry_pressed.connect(Game.start_endless)
	hud.menu_pressed.connect(Game.go_to_menu)


## Thêm một đoạn vào cuối màn.
func _add_chunk(map: String, seg_name: String) -> void:
	var lv := Level.new()
	lv.name = "Chunk_%d" % chunks.size()
	lv.position.x = _end_x
	add_child(lv)
	lv.build(map)
	lv.set_meta("seg_name", seg_name)
	lv.star_collected.connect(_on_star)
	lv.heart_collected.connect(_on_heart)
	lv.boss_defeated.connect(_on_boss_defeated)
	hud.watch_level(lv)                               # HUD hiện thanh máu khi boss trong đoạn này tỉnh
	chunks.append(lv)
	_end_x += lv.size.x
	_goals.append(_end_x)


## Chọn ngẫu nhiên một đoạn hợp độ khó hiện tại, không trùng đoạn vừa dựng.
func _pick_segment() -> Dictionary:
	var max_diff := 1
	for step in DIFFICULTY_STEPS:
		if segments_passed >= step[0]:
			max_diff = step[1]
	var pool := SegmentData.SEGMENTS.filter(func(s): return s["difficulty"] <= max_diff and s["name"] != _last_name)
	if pool.is_empty():
		pool = SegmentData.SEGMENTS
	return pool[_rng.randi() % pool.size()]


## Dựng thêm đoạn cho tới khi phía trước bóng có đủ AHEAD pixel; xóa đoạn đã qua xa.
func _fill_ahead() -> void:
	while _end_x < ball.global_position.x + AHEAD:
		_built += 1
		if _built % BOSS_EVERY == 0:
			_add_chunk(SegmentData.BOSS_ARENA, "Boss Arena")   # đấu trường boss định kỳ
			boss_arenas_built += 1
			continue
		var seg := _pick_segment()
		_add_chunk(seg["map"], seg["name"])
		_last_name = seg["name"]
	while chunks.size() > 2 and chunks[0].position.x + chunks[0].size.x < ball.global_position.x - BEHIND:
		chunks.pop_front().queue_free()


## 60 lần mỗi giây: camera, điểm quãng đường, đếm đoạn đã qua, rơi vực, phím tắt.
func _physics_process(_delta: float) -> void:
	if _over:
		if Input.is_action_just_pressed("back"):
			Game.go_to_menu()
		return
	if not ball.dead:
		camera.global_position = ball.global_position + Vector2(ball.linear_velocity.x * 0.25 + 160, -40)   # nhìn trước về bên phải
		var x := ball.global_position.x
		if x > _best_x:
			score += (x - _best_x) / METER * multiplier       # đi tới bao nhiêu mét thì cộng bấy nhiêu (x hệ số)
			_best_x = x
		while not _goals.is_empty() and x > _goals[0] + 2.0 * METER:
			_goals.pop_front()
			segments_passed += 1
			var m := mini(MAX_MULT, 1 + floori(segments_passed / float(SEGMENTS_PER_MULT)))
			if m > multiplier:
				multiplier = m
				hud.flash("x%d MULTIPLIER!" % multiplier)
		hud.set_score(int(score), multiplier)
		_fill_ahead()
		if ball.global_position.y > chunks[0].size.y + FALL_MARGIN:
			_on_ball_hurt()
	if Input.is_action_just_pressed("restart") and not _busy:
		_on_ball_hurt()
	if Input.is_action_just_pressed("back"):
		Game.go_to_menu()


## Nhặt sao: đếm sao và cộng điểm.
func _on_star() -> void:
	stars += 1
	score += STAR_POINTS * multiplier
	hud.set_stars(stars)


## Nhặt trái tim: +1 mạng, tối đa LIVES.
func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)
	hud.set_lives(lives)


## Hạ boss: cộng điểm lớn.
func _on_boss_defeated(_boss: Node) -> void:
	score += BOSS_POINTS * multiplier


## Bị thương: trừ mạng, bật lại ở đầu đoạn đang chơi. Hết mạng thì thua.
func _on_ball_hurt() -> void:
	if _busy or _over:
		return
	_busy = true
	lives -= 1
	hud.set_lives(lives)
	var respawn := _respawn_point(ball.global_position.x)
	ball.dead = true
	ball.hide()
	ball.teleport(respawn)
	if lives <= 0:
		_game_over()
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	ball.teleport(respawn)
	camera.global_position = respawn
	ball.dead = false
	ball.invuln = 1.0                                 # vừa hồi sinh: miễn sát thương 1 giây
	ball.show()
	_busy = false


## Chỗ hồi sinh: ký tự O của đoạn chứa vị trí x.
func _respawn_point(x: float) -> Vector2:
	for lv in chunks:
		if x < lv.position.x + lv.size.x:
			return lv.position + lv.start_position
	return chunks[-1].position + chunks[-1].start_position


func _game_over() -> void:
	_over = true
	var new_best := Game.record_endless(int(score), stars)
	hud.show_game_over(int(score), Game.best_score, new_best, stars, Game.total_stars)
