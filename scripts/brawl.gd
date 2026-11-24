class_name Brawl                        # tên lớp: bài test và các tính năng thêm sau dùng Brawl
extends Node2D                          # cảnh chế độ đấu 2 người (Bounce Brawl)
## Chế độ đấu 2 người trên một màn hình: hai quả bóng trong một đấu trường 1280 x 720 (camera cố định).
## Ghi 1 điểm khi: dẫm đầu đối thủ (stomp), đối thủ rơi xuống vực (pit) hoặc đối thủ chạm gai (spikes).
## Ai đạt WIN_SCORE điểm trước thì thắng. Chết = bóng vỡ, hồi sinh ở chỗ xuất phát của mình sau một lúc, miễn sát thương ngắn.
## Chống câu giờ: quá `stall_timeout` giây không ai ghi điểm thì gai mọc ở mặt đất, bò dần vào giữa từ hai bên.
##
## ---- Phần công khai cho các tính năng thêm sau (sự kiện ngẫu nhiên, vật phẩm, bot) ----
##   balls[0] = người chơi 1, balls[1] = người chơi 2      scores[0], scores[1] = điểm
##   level (Level đã dựng), arena_rect (vùng chơi), spawn_points[0/1] (chỗ xuất phát)
##   kill(victim, cause)  = CỔNG DUY NHẤT để giết một người chơi và cộng điểm cho người kia (bom, sự kiện... gọi hàm này)
##   opponent_of(ball), spawn_of(ball), hud.flash(text, seconds)
##   match_running = false khi đang giới thiệu (READY...), khi trận đã kết thúc; chỉ khi true mới có điểm
##   tín hiệu: point_scored(scorer, victim, cause), match_started, match_over(winner), player_respawned(ball)
##   events (BrawlEvents) = sự kiện ngẫu nhiên: events.start_event(id), events.stop_event(), events.active_event, events.enabled...

signal point_scored(scorer: Ball, victim: Ball, cause: String)   # có người ghi điểm; cause: "stomp", "pit", "spikes", "bomb" (hoặc chữ khác do sự kiện / vật phẩm đặt)
signal match_started                    # hết phần giới thiệu, trận bắt đầu (bóng điều khiển được)
signal match_over(winner: Ball)         # có người đạt WIN_SCORE
signal player_respawned(ball: Ball)     # một người chơi vừa hồi sinh (để sự kiện / vật phẩm đặt lại trạng thái riêng)

const BALL_SCENE := preload("res://scenes/ball.tscn")   # cảnh quả bóng
const WIN_SCORE := 5                    # đạt chừng này điểm là thắng
const FALL_MARGIN := 80.0               # rơi thấp hơn đáy đấu trường bấy nhiêu pixel thì tính là rơi xuống vực
const FLATTEN_TIME := 0.6               # bị dẫm: dẹt như cái bánh trong bấy nhiêu giây rồi mới vỡ
const RESPAWN_INVULN := 1.5             # vừa hồi sinh: miễn sát thương (và không bị dẫm lấy điểm) trong bấy nhiêu giây
const CEILING_Y := -16.0                # trần vô hình nằm ở đây (sát mép trên màn hình)
const SHOVE_SPEED := 360.0              # lúc hai bóng vừa chạm nhau: mỗi bóng bị hất thêm bấy nhiêu (pixel/giây) ra xa nhau
const SHOVE_LIFT := 180.0               # và hất lên cao một chút cho "nảy"
const SHOVE_GAP := 1.0                  # cách nhau (mép tới mép) dưới bấy nhiêu pixel thì tính là đang chạm (gần như dính nhau)
const SPAWN_CHARS := "OP"               # ký tự xuất phát (O = người chơi 1, P = người chơi 2)
const BALL_LAYER := 2                   # lớp va chạm của bóng (bằng Ball.BALL_LAYER)

static var _last_arena := -1            # đấu trường của trận trước (để trận sau cố đổi sang đấu trường khác)

@export var arena_index := -1           # chọn đấu trường theo số thứ tự trong BrawlData.ARENAS; -1 = ngẫu nhiên
@export var intro_seconds := 1.4        # phần "READY..." kéo dài bao lâu (bóng đứng yên) trước khi "BOUNCE!"
@export var respawn_delay := 1.2        # chết rồi chờ bao lâu mới hồi sinh
@export var win_panel_delay := 1.0      # đạt điểm thắng rồi chờ bao lâu mới hiện bảng thắng
@export var stall_timeout := 30.0       # bao nhiêu giây không ai ghi điểm thì bắt đầu mọc gai (bài test rút ngắn con số này)
@export var stall_step := 2.0           # gai mọc thêm một ô (mỗi bên) sau mỗi bấy nhiêu giây

@onready var camera: Camera2D = $Camera   # camera cố định
@onready var hud: BrawlHud = $HUD/Hud     # giao diện: điểm, thông báo, bảng thắng

var level: Level                        # đấu trường đang chơi
var arena_name := ""                    # tên đấu trường
var arena_rect := Rect2()               # vùng chơi (toạ độ thế giới), bằng đúng một màn hình rộng 1280
var balls: Array[Ball] = []             # balls[0] = người chơi 1, balls[1] = người chơi 2
var scores: Array[int] = [0, 0]         # điểm của người chơi 1 và 2
var spawn_points: Array[Vector2] = []   # chỗ xuất phát / hồi sinh của người chơi 1 và 2
var match_running := false              # true = đang đấu (có thể ghi điểm); false = đang giới thiệu hoặc đã hết trận
var winner: Ball = null                 # người thắng (null khi chưa hết trận)
var events: BrawlEvents                 # sự kiện ngẫu nhiên (scripts/brawl_events.gd): events.start_event(id), events.active_event...
var vs_bot := false                     # chế độ đánh với máy (chỉ lưu cờ; bot sẽ làm ở phần sau)
var stall_active := false               # đang trong giai đoạn gai chống câu giờ
var stall_spikes: Array[Spikes] = []    # các gai chống câu giờ đang có trên sàn
var _stall_time := 0.0                  # đã bao lâu rồi không ai ghi điểm
var _stall_next := 0.0                  # còn bao lâu nữa gai mọc thêm
var _stall_left: Array[int] = []        # các cột còn lại để mọc gai phía bên trái (từ ngoài vào trong)
var _stall_right: Array[int] = []       # các cột còn lại để mọc gai phía bên phải (từ ngoài vào trong)
var _was_touching := false              # khung trước hai bóng có đang chạm nhau không (để hất đúng lúc VỪA chạm)
var _shove_wait := 0                    # > 0: còn bao nhiêu khung nữa thì hất (hất chậm 1 khung để cú hất cộng THÊM vào cú nảy của vật lý, không thay nó)


## Dựng đấu trường, hai người chơi, nối tín hiệu rồi bắt đầu phần giới thiệu.
func _ready() -> void:
	var count: int = BrawlData.ARENAS.size()      # số đấu trường có sẵn
	if arena_index < 0 or arena_index >= count:   # chưa chọn: bốc ngẫu nhiên, cố tránh trùng trận trước
		arena_index = randi() % count             # bốc một đấu trường
		if count > 1 and arena_index == _last_arena:   # trùng trận trước
			arena_index = (arena_index + 1 + randi() % (count - 1)) % count   # nhảy sang một đấu trường khác
	_last_arena = arena_index                     # nhớ để trận sau đổi
	var data: Dictionary = BrawlData.ARENAS[arena_index]   # dữ liệu đấu trường
	arena_name = data["name"]                     # tên đấu trường
	vs_bot = Game.brawl_vs_bot                    # nhớ có đánh với máy không

	level = Level.new()                           # tạo màn mới
	add_child(level)                              # thêm vào cảnh
	move_child(level, 0)                          # vẽ màn dưới camera và giao diện
	level.build(data["map"])                      # dựng gạch, gai, lò xo từ bản đồ chữ
	arena_rect = Rect2(Vector2.ZERO, level.size)  # vùng chơi = cả bản đồ
	spawn_points = [level.start_position, _find_spawn(BrawlData.PLAYER2_CHAR)]   # O là người chơi 1, P là người chơi 2

	# Camera cố định: đáy đấu trường (cao 704) sát đáy màn hình 720, dải 16 pixel phía trên là nền trời.
	camera.position = Vector2(level.size.x / 2.0, level.size.y - 360.0)   # giữa theo chiều ngang
	camera.make_current()                         # dùng camera này

	# Trần vô hình sát mép trên màn hình (hai bên đã có tường # trong bản đồ): bật rất cao (lò xo) cũng không bay ra ngoài.
	var ceiling := StaticBody2D.new()             # thân đứng yên chứa trần
	var ceiling_shape := CollisionShape2D.new()   # hình va chạm của trần
	var ceiling_rect := RectangleShape2D.new()    # hình chữ nhật
	ceiling_rect.size = Vector2(level.size.x, 200.0)   # rộng bằng đấu trường, dày 200 pixel
	ceiling_shape.shape = ceiling_rect            # gán hình
	ceiling_shape.position = Vector2(level.size.x / 2.0, CEILING_Y - 100.0)   # mép dưới của trần nằm đúng ở CEILING_Y
	ceiling.add_child(ceiling_shape)              # gắn hình vào thân
	level.add_child(ceiling)                      # thêm vào màn

	for i in 2:                                   # tạo hai quả bóng
		var ball: Ball = BALL_SCENE.instantiate() # tạo bóng từ cảnh mẫu
		ball.position = spawn_points[i]           # đặt ở chỗ xuất phát của người chơi này
		level.add_child(ball)                     # thêm bóng vào màn
		ball.set_player(i + 1)                    # phím riêng (P1: A/D/W, P2: mũi tên) và màu riêng
		ball.set_collide_with_balls(true)         # hai bóng va chạm nhau
		ball.hurt.connect(_on_ball_hurt.bind(ball))   # chạm gai thì gọi _on_ball_hurt
		ball.stomped.connect(_on_stomped.bind(ball))  # dẫm lên đầu bóng khác thì gọi _on_stomped
		balls.append(ball)                        # lưu vào danh sách công khai

	events = BrawlEvents.new()                    # sự kiện ngẫu nhiên (LOW GRAVITY, HOT POTATO...), tự nghe match_started
	events.name = "Events"                        # tên node cho dễ tìm
	add_child(events)                             # thêm vào cảnh (sau khi bóng và HUD đã có)
	hud.setup(WIN_SCORE)                          # cài giao diện
	hud.rematch_pressed.connect(func() -> void: Game.start_brawl(Game.brawl_vs_bot))   # bấm Rematch: vào trận mới
	hud.menu_pressed.connect(Game.go_to_menu)     # bấm Menu: về menu
	_start_intro()                                # "READY... BOUNCE!" rồi mới cho đấu


## Đọc vị trí xuất phát của ký tự `ch` trong bản đồ (cùng công thức với Level: giữa đáy ô, cao hơn nửa thân).
func _find_spawn(ch: String) -> Vector2:
	for r in level.rows.size():                   # duyệt từng hàng
		var c: int = level.rows[r].find(ch)       # tìm ký tự trong hàng
		if c != -1:                               # có ký tự này
			return Vector2((c + 0.5) * Level.TILE, (r + 1) * Level.TILE - 16.0)   # giữa đáy ô, cao hơn đáy nửa thân
	push_error("Brawl: arena '%s' has no '%s' spawn" % [arena_name, ch])   # đấu trường thiếu chỗ xuất phát
	return level.size / 2.0                       # tạm đặt giữa đấu trường


## Giới thiệu: "READY..." (bóng đứng yên) rồi "BOUNCE!" và bắt đầu trận.
func _start_intro() -> void:
	for ball in balls:                            # hai bóng
		ball.dead = true                          # đứng yên, không điều khiển được trong lúc giới thiệu
	hud.flash("READY...", intro_seconds)          # báo chuẩn bị
	await get_tree().create_timer(intro_seconds).timeout   # chờ hết phần giới thiệu
	if not is_inside_tree():                      # cảnh đã bị đổi trong lúc chờ
		return
	for ball in balls:                            # hai bóng
		ball.dead = false                         # cho điều khiển
	match_running = true                          # bắt đầu đấu
	_reset_stall()                                # tính giờ chống câu giờ từ bây giờ
	hud.flash("BOUNCE!", 0.7)                     # báo bắt đầu
	match_started.emit()                          # báo cho các tính năng khác


## Người còn lại (đối thủ) của `ball`.
func opponent_of(ball: Ball) -> Ball:
	return balls[1] if ball == balls[0] else balls[0]   # bóng 0 thì đối thủ là bóng 1 và ngược lại


## Chỗ xuất phát / hồi sinh của `ball`.
func spawn_of(ball: Ball) -> Vector2:
	return spawn_points[balls.find(ball)]         # theo thứ tự của bóng trong danh sách


## 60 lần mỗi giây: phím Esc, rơi xuống vực, hất hai bóng lúc va chạm, gai chống câu giờ.
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("back"):      # bấm Esc
		Game.go_to_menu()                         # về menu bất cứ lúc nào
		return
	if not match_running:                         # đang giới thiệu hoặc đã hết trận
		return
	for ball in balls:                            # kiểm tra từng bóng có rơi ra ngoài không
		# dưới đáy FALL_MARGIN pixel = rơi xuống vực; ra hẳn ngoài hai bên / trên cũng tính vậy (phòng hờ lỗi vật lý)
		if not ball.dead and not arena_rect.grow_individual(200.0, 200.0, 200.0, FALL_MARGIN).has_point(ball.global_position):
			kill(ball, "pit")                     # rơi xuống vực: đối thủ ghi điểm
	_shove_balls()                                # hất hai bóng ra xa nhau lúc vừa chạm
	_update_stall(delta)                          # đếm giờ chống câu giờ


## Hai bóng vừa chạm nhau: hất mỗi bóng thêm một cú ra xa nhau (và hơi lên cao), để va chạm "nảy" mạnh hơn bình thường.
## Hất chậm 1 khung, sau khi vật lý đã tự nảy hai bóng ra, nên cú hất cộng thêm vào chứ không thay thế cú nảy.
## Chạm theo kiểu dẫm lên đầu (gần như thẳng đứng) thì không hất, để cú dẫm vẫn dẫm đúng người.
func _shove_balls() -> void:
	var a := balls[0]                             # người chơi 1
	var b := balls[1]                             # người chơi 2
	var offset := b.global_position - a.global_position   # từ bóng 1 tới bóng 2
	var touching := not a.dead and not b.dead and offset.length() <= a.radius + b.radius + SHOVE_GAP   # hai bóng đang chạm nhau
	if touching and not _was_touching and absf(offset.normalized().y) < 0.75:   # VỪA chạm và không phải dẫm đầu
		_shove_wait = 2                           # hẹn hất sau 1 khung nữa (đếm 2 -> 1 -> 0)
	_was_touching = touching                      # nhớ cho khung sau
	if _shove_wait > 0:                           # đang chờ tới lượt hất
		_shove_wait -= 1                          # đếm ngược
		if _shove_wait == 0 and not a.dead and not b.dead:   # tới lượt và cả hai còn sống
			var dir := offset.normalized()        # hướng từ bóng 1 sang bóng 2 (vị trí hiện tại)
			a.knockback(-dir * SHOVE_SPEED + Vector2(0, -SHOVE_LIFT))   # bóng 1 bị hất lùi
			b.knockback(dir * SHOVE_SPEED + Vector2(0, -SHOVE_LIFT))    # bóng 2 bị hất lùi


## Bóng chạm gai: đối thủ ghi điểm. (Ball.take_hit đã bỏ qua lúc đang miễn sát thương.)
func _on_ball_hurt(ball: Ball) -> void:
	kill(ball, "spikes")                          # chết vì gai


## `stomper` vừa đáp xuống đầu `victim`. Chỉ tính điểm khi trận đang chạy và nạn nhân không đang miễn sát thương.
func _on_stomped(victim: Ball, stomper: Ball) -> void:
	if not match_running or stomper.dead or victim.dead or victim.invuln > 0.0:   # đã chết / mới hồi sinh: dẫm không ăn điểm
		return
	kill(victim, "stomp")                         # nạn nhân bị dẹt rồi vỡ, người dẫm ghi điểm


## CỔNG DUY NHẤT để giết một người chơi: đối thủ ghi 1 điểm, nạn nhân vỡ rồi (nếu trận chưa hết) hồi sinh ở chỗ xuất phát.
## `cause`: "stomp" (nạn nhân dẹt như bánh trước khi vỡ), "pit", "spikes"... hoặc chữ khác tuỳ sự kiện / vật phẩm.
## Bỏ qua nếu trận không chạy (đang giới thiệu, đã hết) hoặc nạn nhân đã chết (đang chờ hồi sinh).
func kill(victim: Ball, cause: String) -> void:
	if not match_running or victim == null or victim.dead:   # không tính điểm lúc này
		return
	var scorer := opponent_of(victim)             # người ghi điểm
	var si := balls.find(scorer)                  # số thứ tự của người ghi điểm (0 hoặc 1)
	victim.dead = true                            # đánh dấu chết ngay: không bị giết hai lần, không điều khiển được
	scores[si] += 1                               # cộng điểm
	hud.set_score(scorer.player_id, scores[si])   # cập nhật giao diện
	_reset_stall()                                # có điểm: bỏ gai chống câu giờ, tính giờ lại
	var over: bool = scores[si] >= WIN_SCORE      # đủ điểm thắng chưa
	if over:                                      # đủ điểm
		match_running = false                     # hết trận: không ai ghi thêm điểm nữa
		winner = scorer                           # nhớ người thắng
	point_scored.emit(scorer, victim, cause)      # báo cho các tính năng khác
	hud.flash(_point_text(scorer, victim, cause), 1.0, BrawlHud.PLAYER_COLORS[si])   # thông báo ai ghi điểm
	if over:                                      # kết thúc trận
		_end_match(scorer)                        # hiện bảng thắng sau một lúc
	_death_sequence(victim, cause, not over)      # nạn nhân vỡ; hồi sinh nếu trận còn tiếp


## Chữ thông báo cho một điểm, vd "P1 STOMPS P2!".
func _point_text(scorer: Ball, victim: Ball, cause: String) -> String:
	match cause:                                  # theo nguyên nhân
		"stomp":
			return "P%d STOMPS P%d!" % [scorer.player_id, victim.player_id]   # dẫm đầu
		"pit":
			return "P%d FELL IN!" % victim.player_id   # rơi xuống vực
		"spikes":
			return "P%d GOT SPIKED!" % victim.player_id   # dính gai
		"bomb":
			return "P%d WENT BOOM!" % victim.player_id   # bom HOT POTATO nổ trên đầu
	return "P%d SCORES!" % scorer.player_id       # nguyên nhân khác (sự kiện, vật phẩm)


## Hết trận: khoá người thắng đứng yên, báo tín hiệu, một lúc sau hiện bảng thắng.
func _end_match(scorer: Ball) -> void:
	scorer.dead = true                            # người thắng không điều khiển nữa (bảng thắng nhận phím)
	match_over.emit(scorer)                       # báo cho các tính năng khác
	await get_tree().create_timer(win_panel_delay).timeout   # để người chơi kịp thấy cú ăn điểm cuối
	if not is_inside_tree():                      # cảnh đã bị đổi trong lúc chờ
		return
	hud.show_win(scorer.player_id, scores)        # hiện bảng PLAYER n WINS! với nút Rematch / Menu


## Cảnh nạn nhân chết: bị dẫm thì dẹt như bánh một lúc, rồi vỡ, ẩn đi, về chỗ xuất phát; hồi sinh nếu `respawn`.
func _death_sequence(victim: Ball, cause: String, respawn: bool) -> void:
	var idx := balls.find(victim)                 # số thứ tự của nạn nhân
	if cause == "stomp":                          # bị dẫm đầu
		victim.flatten(FLATTEN_TIME + 0.2)        # dẹt như cái bánh
		await get_tree().create_timer(FLATTEN_TIME).timeout   # giữ dẹt một lúc cho vui
		if not is_inside_tree():                  # cảnh đã bị đổi trong lúc chờ
			return
	_pop_effect(victim.global_position, BrawlHud.PLAYER_COLORS[idx])   # bóng vỡ thành mảnh
	victim.hide()                                 # ẩn bóng
	victim.collision_layer = 0                    # bóng ẩn không cản đường, không dính gai, không bị dẫm
	victim.teleport(spawn_points[idx])            # dịch về chỗ xuất phát (đang ẩn)
	if not respawn:                               # trận đã hết: nằm yên
		return
	await get_tree().create_timer(respawn_delay).timeout   # chờ một lúc rồi hồi sinh
	if not is_inside_tree():                      # cảnh đã bị đổi trong lúc chờ
		return
	_respawn(victim)                              # hồi sinh


## Hồi sinh `ball` ở chỗ xuất phát, miễn sát thương một lúc. (Trận đã hết thì chỉ hiện ra, không điều khiển.)
func _respawn(ball: Ball) -> void:
	ball.teleport(spawn_of(ball))                 # đặt lại ở chỗ xuất phát
	ball.collision_layer = BALL_LAYER             # va chạm trở lại
	ball.show()                                   # hiện bóng
	ball.invuln = RESPAWN_INVULN                  # miễn sát thương, không bị dẫm lấy điểm
	ball.dead = not match_running                 # còn trận thì sống lại; hết trận thì đứng yên
	player_respawned.emit(ball)                   # báo cho các tính năng khác


## Hiệu ứng bóng vỡ thành mảnh (màu của người chơi). Rơi xuống vực thì vỡ ngay sát đáy màn hình cho nhìn thấy.
func _pop_effect(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()                 # tạo bộ phát hạt
	p.one_shot = true                             # chỉ phát một lần
	p.amount = 22                                 # 22 mảnh vỡ
	p.lifetime = 0.8                              # mỗi mảnh tồn tại 0,8 giây
	p.explosiveness = 1.0                         # bắn ra tất cả cùng lúc
	p.spread = 180.0                              # bắn tỏa ra mọi hướng
	p.initial_velocity_min = 140.0                # tốc độ bay nhỏ nhất
	p.initial_velocity_max = 300.0                # tốc độ bay lớn nhất
	p.gravity = Vector2(0, 900)                   # mảnh rơi xuống do trọng lực
	p.scale_amount_min = 3.0                      # mảnh nhỏ nhất
	p.scale_amount_max = 6.0                      # mảnh lớn nhất
	p.color = color                               # màu của người chơi
	p.position = Vector2(pos.x, minf(pos.y, level.size.y - 24.0))   # vỡ trong màn hình ngay cả khi rơi xuống vực
	level.add_child(p)                            # thêm vào màn
	p.emitting = true                             # bắt đầu phát hạt
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)   # sau 1,2 giây thì xóa bộ phát hạt


# ---- Gai chống câu giờ ----

## Hàng ô sát mặt đất: gai chống câu giờ mọc ở hàng này (hàng thứ 3 từ dưới lên, ngay trên hai hàng đất).
func floor_row() -> int:
	return level.rows.size() - 3                  # hai hàng cuối là đất, hàng ngay trên là "mặt đất"


## Có thể mọc gai ở cột `c` không: dưới là đất, ô mặt đất còn trống (hoặc là chỗ xuất phát), chưa có gai / lò xo.
func _can_spike(c: int) -> bool:
	var r := floor_row()                          # hàng mặt đất
	return level.char_at(r + 1, c) == "#" and (level.char_at(r, c) == "." or level.char_at(r, c) in SPAWN_CHARS)   # đất ở dưới, ô trống ở trên


## Bỏ hết gai chống câu giờ và tính lại giờ (gọi khi có điểm, và lúc bắt đầu trận).
func _reset_stall() -> void:
	_stall_time = 0.0                             # tính lại từ đầu
	_stall_next = 0.0                             # gai đầu tiên mọc ngay khi hết giờ
	stall_active = false                          # chưa ở giai đoạn gai
	for s in stall_spikes:                        # xoá từng gai đã mọc
		if is_instance_valid(s):                  # gai còn tồn tại
			s.queue_free()                        # xoá khỏi màn
	stall_spikes.clear()                          # bỏ danh sách
	_stall_left.clear()                           # lập lại danh sách cột bên trái: từ mép ngoài vào giữa
	_stall_right.clear()                          # lập lại danh sách cột bên phải
	var cols := level.cols                        # số cột
	var half := cols >> 1                         # cột giữa (chia đôi số cột)
	for c in range(1, half):                      # nửa trái, bỏ cột tường 0
		if _can_spike(c):                         # cột này mọc gai được
			_stall_left.append(c)                 # thêm vào, thứ tự từ ngoài vào trong
	for c in range(cols - 2, half - 1, -1):       # nửa phải, bỏ cột tường cuối
		if _can_spike(c):                         # cột này mọc gai được
			_stall_right.append(c)                # thêm vào, thứ tự từ ngoài vào trong


## Mỗi khung: đếm giờ không ai ghi điểm; hết giờ thì cứ mỗi `stall_step` giây mọc thêm một ô gai mỗi bên.
func _update_stall(delta: float) -> void:
	_stall_time += delta                          # thêm thời gian trôi qua
	if _stall_time < stall_timeout:               # chưa hết giờ
		return
	if not stall_active:                          # vừa hết giờ
		stall_active = true                       # bắt đầu giai đoạn gai
		hud.flash("NO POINTS - SPIKES!", 1.4, Color("#ffb020"))   # cảnh báo
	_stall_next -= delta                          # đếm ngược tới gai kế tiếp
	if _stall_next > 0.0:                         # chưa tới lúc
		return
	_stall_next = stall_step                      # hẹn gai kế tiếp
	if not _stall_left.is_empty():                # còn cột bên trái
		_add_stall_spike(_stall_left.pop_front()) # mọc một ô gai bên trái
	if not _stall_right.is_empty():               # còn cột bên phải
		_add_stall_spike(_stall_right.pop_front())   # mọc một ô gai bên phải


## Mọc một ô gai ở cột `c` trên mặt đất, nhô lên dần cho dễ thấy.
func _add_stall_spike(c: int) -> void:
	var s: Spikes = Level.SPIKES.instantiate()    # tạo một ô gai
	s.position = Vector2((c + 0.5) * Level.TILE, (floor_row() + 1) * Level.TILE)   # giữa đáy ô mặt đất
	level.add_child(s)                            # thêm vào màn
	stall_spikes.append(s)                        # lưu để xoá khi có điểm
	s.scale = Vector2(1.0, 0.1)                   # bắt đầu thấp lè tè
	s.create_tween().tween_property(s, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # nhô lên (tween gắn vào gai, gai bị xoá thì tween tự dừng)
