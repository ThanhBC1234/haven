extends Node2D
## Chế độ vô tận (Endless Run), tính điểm kiểu Subway Surfers.
## - Ghép ngẫu nhiên các đoạn trong SegmentData.SEGMENTS nối tiếp nhau. Luôn dựng sẵn vài đoạn phía trước,
##   đoạn đã đi qua xa thì xóa đi cho nhẹ máy. Đầu lượt chỉ ra đoạn dễ, càng xa càng có đoạn khó.
## - Điểm = quãng đường (1 ô = 1 mét) x hệ số nhân + sao x STAR_POINTS x hệ số nhân.
##   Hệ số nhân tăng 1 sau mỗi SEGMENTS_PER_MULT đoạn đi qua (tối đa MAX_MULT).
## - 3 mạng. Chết thì bật lại ở đầu đoạn đang chơi. Hết mạng là thua: lưu kỷ lục, cộng sao vào tổng sao.

const BALL_SCENE := preload("res://scenes/ball.tscn")   # nạp sẵn cảnh quả bóng để tạo ra khi cần
const LIVES := 3                # số mạng mỗi lượt chơi
const AHEAD := 2400.0           # luôn có sẵn đoạn tới trước mặt bóng chừng này pixel
const BEHIND := 1600.0          # đoạn nằm sau bóng xa hơn chừng này thì xóa
const METER := 32.0             # 1 ô = 1 mét
const STAR_POINTS := 25         # mỗi sao được bao nhiêu điểm (nhân với hệ số)
const SEGMENTS_PER_MULT := 4    # qua bao nhiêu đoạn thì hệ số nhân tăng 1
const MAX_MULT := 5             # hệ số nhân lớn nhất
const FALL_MARGIN := 160.0      # rơi thấp hơn đáy màn bao nhiêu pixel thì tính là chết
const RESPAWN_DELAY := 0.8      # chết rồi chờ bao nhiêu giây mới hồi sinh
## Độ khó cho phép theo số đoạn đã qua: [qua từ bao nhiêu đoạn, độ khó tối đa].
const DIFFICULTY_STEPS := [[0, 1], [3, 2], [7, 3]]
const BOSS_EVERY := 8           # cứ dựng bao nhiêu đoạn ngẫu nhiên thì chèn một đấu trường boss
const BOSS_POINTS := 500        # hạ boss được bao nhiêu điểm (nhân với hệ số)

@onready var camera: Camera2D = $Camera   # lấy node camera con khi cảnh sẵn sàng
@onready var hud: Hud = $HUD/Hud          # lấy giao diện HUD (mạng, điểm, sao)

var chunks: Array[Level] = []   # các đoạn đang có trong màn, theo thứ tự trái sang phải
var ball: Ball                  # quả bóng người chơi điều khiển
var lives := LIVES              # số mạng còn lại
var stars := 0                  # số sao đã nhặt trong lượt này
var score := 0.0                # điểm hiện tại
var multiplier := 1             # hệ số nhân điểm hiện tại
var segments_passed := 0        # đã đi qua bao nhiêu đoạn
var _end_x := 0.0               # mép phải của đoạn cuối cùng đã dựng
var _best_x := 0.0              # điểm xa nhất đã tới (chỉ đi tới mới được điểm)
var _next_goal := 0.0           # mép phải của đoạn sắp đi qua (để đếm số đoạn đã qua)
var _goals: Array[float] = []   # danh sách mép phải các đoạn chưa đi qua
var _last_name := ""            # tên đoạn vừa dựng, để không lặp liền 2 lần
var _built := 0                 # đã dựng bao nhiêu đoạn (không tính đoạn mở đầu)
var boss_arenas_built := 0      # đã chèn bao nhiêu đấu trường boss
var _rng := RandomNumberGenerator.new()   # bộ sinh số ngẫu nhiên để chọn đoạn
var _busy := false              # đang chết/hồi sinh: bỏ qua lần bị thương khác
var _over := false              # đã thua (hết mạng) hay chưa


## Dựng đoạn mở đầu, thả bóng, dựng sẵn vài đoạn phía trước, cài camera và HUD.
func _ready() -> void:
	_rng.randomize()                                  # trộn hạt giống để mỗi lượt khác nhau
	_add_chunk(SegmentData.START, "Start")            # dựng đoạn mở đầu
	ball = BALL_SCENE.instantiate()                   # tạo quả bóng từ cảnh mẫu
	ball.position = chunks[0].start_position          # đặt bóng ở điểm xuất phát
	ball.z_index = 5                                  # luôn vẽ trên các đoạn
	add_child(ball)                                   # thêm bóng vào cảnh
	ball.hurt.connect(_on_ball_hurt)                  # bóng bị thương thì gọi _on_ball_hurt
	_best_x = ball.global_position.x                  # mốc tính điểm quãng đường ban đầu
	_fill_ahead()                                     # dựng sẵn các đoạn phía trước

	var height := chunks[0].size.y                    # chiều cao của màn (theo đoạn đầu)
	camera.limit_left = 0                             # camera không đi qua mép trái
	camera.limit_top = mini(-64, int(height) - 720)   # giới hạn trên: nhìn cao hơn đỉnh màn một chút
	camera.limit_bottom = int(height)                 # camera không nhìn xuống dưới đáy màn
	camera.global_position = ball.global_position     # đặt camera ngay chỗ bóng
	camera.reset_smoothing()                          # bỏ hiệu ứng trượt, nhảy thẳng tới chỗ mới

	hud.setup_endless(LIVES)                          # cài HUD cho chế độ vô tận
	hud.watch_ball(ball)                              # HUD theo dõi bóng (đạn, khiên)
	hud.set_score(0, 1)                               # điểm 0, hệ số x1
	hud.retry_pressed.connect(Game.start_endless)     # bấm "chơi lại" thì vào lại chế độ vô tận
	hud.menu_pressed.connect(Game.go_to_menu)         # bấm "menu" thì về menu


## Thêm một đoạn vào cuối màn.
func _add_chunk(map: String, seg_name: String) -> void:
	var lv := Level.new()                             # tạo một đoạn màn mới
	lv.name = "Chunk_%d" % chunks.size()              # đặt tên theo số thứ tự
	lv.position.x = _end_x                            # đặt nối ngay sau đoạn cuối
	add_child(lv)                                     # thêm đoạn vào cảnh
	lv.build(map)                                     # dựng gạch, vật thể theo bản đồ chữ
	lv.set_meta("seg_name", seg_name)                 # ghi tên đoạn vào đoạn (để tra cứu)
	lv.star_collected.connect(_on_star)               # nhặt sao trong đoạn thì gọi _on_star
	lv.heart_collected.connect(_on_heart)             # nhặt tim thì gọi _on_heart
	lv.boss_defeated.connect(_on_boss_defeated)       # hạ boss thì gọi _on_boss_defeated
	hud.watch_level(lv)                               # HUD hiện thanh máu khi boss trong đoạn này tỉnh
	chunks.append(lv)                                 # thêm vào danh sách đoạn
	_end_x += lv.size.x                               # dời mép phải tới cuối đoạn mới
	_goals.append(_end_x)                             # ghi mốc để đếm khi đi qua đoạn này


## Chọn ngẫu nhiên một đoạn hợp độ khó hiện tại, không trùng đoạn vừa dựng.
func _pick_segment() -> Dictionary:
	var max_diff := 1                                 # mặc định chỉ cho đoạn dễ nhất
	for step in DIFFICULTY_STEPS:                     # duyệt từng bậc độ khó
		if segments_passed >= step[0]:                # đã đi đủ xa để mở bậc này
			max_diff = step[1]                        # nâng độ khó tối đa
	# lọc ra các đoạn đủ dễ và khác đoạn vừa dựng
	var pool := SegmentData.SEGMENTS.filter(func(s): return s["difficulty"] <= max_diff and s["name"] != _last_name)
	if pool.is_empty():                               # không còn đoạn nào hợp lệ
		pool = SegmentData.SEGMENTS                   # thì cho chọn mọi đoạn
	return pool[_rng.randi() % pool.size()]           # bốc ngẫu nhiên một đoạn


## Dựng thêm đoạn cho tới khi phía trước bóng có đủ AHEAD pixel; xóa đoạn đã qua xa.
func _fill_ahead() -> void:
	while _end_x < ball.global_position.x + AHEAD:    # phía trước còn thiếu đoạn thì dựng tiếp
		_built += 1                                   # đếm thêm một đoạn
		if _built % BOSS_EVERY == 0:                  # tới lượt chèn boss
			_add_chunk(SegmentData.BOSS_ARENA, "Boss Arena")   # đấu trường boss định kỳ
			boss_arenas_built += 1                    # đếm số đấu trường boss
			continue                                  # bỏ qua phần chọn đoạn ngẫu nhiên
		var seg := _pick_segment()                    # chọn một đoạn ngẫu nhiên
		_add_chunk(seg["map"], seg["name"])           # dựng đoạn đó vào cuối màn
		_last_name = seg["name"]                      # nhớ tên để lần sau không lặp
	# còn hơn 2 đoạn và đoạn đầu đã nằm quá xa phía sau bóng thì xóa
	while chunks.size() > 2 and chunks[0].position.x + chunks[0].size.x < ball.global_position.x - BEHIND:
		chunks.pop_front().queue_free()               # bỏ khỏi danh sách và xóa khỏi cảnh


## 60 lần mỗi giây: camera, điểm quãng đường, đếm đoạn đã qua, rơi vực, phím tắt.
func _physics_process(_delta: float) -> void:
	if _over:                                         # đã thua: chỉ chờ người chơi về menu
		if Input.is_action_just_pressed("back"):      # bấm Esc
			Game.go_to_menu()                         # về menu
		return
	if not ball.dead:                                 # bóng còn sống
		camera.global_position = ball.global_position + Vector2(ball.linear_velocity.x * 0.25 + 160, -40)   # nhìn trước về bên phải
		var x := ball.global_position.x               # vị trí ngang của bóng
		if x > _best_x:                               # đi xa hơn kỷ lục trong lượt
			score += (x - _best_x) / METER * multiplier       # đi tới bao nhiêu mét thì cộng bấy nhiêu (x hệ số)
			_best_x = x                               # cập nhật điểm xa nhất
		# bóng đã qua mép phải đoạn (thêm 2 mét) thì tính là qua đoạn
		while not _goals.is_empty() and x > _goals[0] + 2.0 * METER:
			_goals.pop_front()                        # bỏ mốc đã qua
			segments_passed += 1                      # đếm thêm một đoạn đã qua
			var m := mini(MAX_MULT, 1 + floori(segments_passed / float(SEGMENTS_PER_MULT)))   # hệ số nhân mới, tối đa MAX_MULT
			if m > multiplier:                        # hệ số vừa tăng
				multiplier = m                        # lưu hệ số mới
				hud.flash("x%d MULTIPLIER!" % multiplier)   # hiện chữ báo hệ số mới
		hud.set_score(int(score), multiplier)         # cập nhật điểm trên HUD
		_fill_ahead()                                 # dựng thêm / xóa bớt đoạn
		if ball.global_position.y > chunks[0].size.y + FALL_MARGIN:   # rơi xuống vực
			_on_ball_hurt()                           # tính là bị thương
	if Input.is_action_just_pressed("restart") and not _busy:   # bấm R
		_on_ball_hurt()                               # tự nổ, mất 1 mạng
	if Input.is_action_just_pressed("back"):          # bấm Esc
		Game.go_to_menu()                             # về menu


## Nhặt sao: đếm sao và cộng điểm.
func _on_star() -> void:
	stars += 1                                        # thêm 1 sao
	score += STAR_POINTS * multiplier                 # cộng điểm sao (nhân hệ số)
	hud.set_stars(stars)                              # cập nhật số sao trên HUD


## Nhặt trái tim: +1 mạng, tối đa LIVES.
func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)                    # thêm 1 mạng nhưng không vượt LIVES
	hud.set_lives(lives)                              # cập nhật số mạng trên HUD


## Hạ boss: cộng điểm lớn.
func _on_boss_defeated(_boss: Node) -> void:
	score += BOSS_POINTS * multiplier                 # cộng điểm hạ boss (nhân hệ số)


## Bị thương: trừ mạng, bật lại ở đầu đoạn đang chơi. Hết mạng thì thua.
func _on_ball_hurt() -> void:
	if _busy or _over:                                # đang hồi sinh hoặc đã thua thì bỏ qua
		return
	_busy = true                                      # khóa lại, tránh bị trừ mạng 2 lần
	lives -= 1                                        # trừ 1 mạng
	hud.set_lives(lives)                              # cập nhật số mạng trên HUD
	var respawn := _respawn_point(ball.global_position.x)   # tìm chỗ hồi sinh ở đầu đoạn hiện tại
	ball.dead = true                                  # đánh dấu bóng đã chết
	ball.hide()                                       # ẩn bóng
	ball.teleport(respawn)                            # dịch bóng về chỗ hồi sinh (đang ẩn)
	if lives <= 0:                                    # hết mạng
		_game_over()                                  # thua
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout   # chờ một lúc
	ball.teleport(respawn)                            # đặt lại bóng ở chỗ hồi sinh
	camera.global_position = respawn                  # camera nhảy tới chỗ hồi sinh
	ball.dead = false                                 # bóng sống lại
	ball.invuln = 1.5                                 # vừa hồi sinh: miễn sát thương 1,5 giây (đủ để quái đi ngang qua)
	ball.show()                                       # hiện bóng
	_busy = false                                     # mở khóa


## Chỗ hồi sinh: ký tự O của đoạn chứa vị trí x.
func _respawn_point(x: float) -> Vector2:
	for lv in chunks:                                 # duyệt các đoạn từ trái sang phải
		if x < lv.position.x + lv.size.x:             # x nằm trong đoạn này
			return lv.position + lv.start_position    # trả về điểm xuất phát của đoạn
	return chunks[-1].position + chunks[-1].start_position   # không tìm thấy: dùng đoạn cuối


func _game_over() -> void:
	_over = true                                      # đánh dấu đã thua
	var new_best := Game.record_endless(int(score), stars)   # lưu kỷ lục, cộng sao; true nếu phá kỷ lục
	hud.show_game_over(int(score), Game.best_score, new_best, stars, Game.total_stars)   # hiện bảng thua
