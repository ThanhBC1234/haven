class_name Chained                      # tên lớp: bài test và các tính năng thêm sau dùng Chained
extends Node2D                          # cảnh chế độ 2 người bị trói bằng dây (Chained)
## Hai người chơi bị trói bằng một sợi dây đàn hồi (Rope) và phải cùng nhau qua màn. Sao nhặt được không vào túi ai mà xâu lên dây thành "hạt",
## các hạt trượt về phía người đứng THẤP hơn. Tới đích (một trong hai chạm cờ khi cả hai còn sống) thì mỗi hạt tính cho người gần nó hơn:
## ai nhiều sao hơn thắng màn. Nên hai người phải hợp tác để sống sót, nhưng mỗi người lại muốn đứng thấp (gần vực, gai) để kéo sao về phía mình,
## còn nhảy cao là dâng sao cho bạn. Chết thì CẢ HAI hồi sinh ở cờ lưu gần nhất, một nửa số sao phía người chết rơi ra đất để hai người tranh nhau nhặt lại.
## Mạng dùng chung (LIVES). Hết mạng thì chơi lại màn từ đầu.
##
## ---- Phần công khai cho các tính năng thêm sau (màn mới, sự kiện ngẫu nhiên, hình phạt cuối màn) ----
##   balls[0] = người chơi 1, balls[1] = người chơi 2      rope (Rope, scripts/rope.gd): dây + hạt, rope.cut, rope.rest_length...
##   level (Level đã dựng)      lives (mạng chung)      respawn_position (cờ lưu gần nhất, giữa hai người), respawn_points[0/1]
##   match_running = false khi đang giới thiệu (READY...) và sau khi về đích; chỉ khi true mới có chết / về đích
##   kill_both(cause, culprit) = CỔNG DUY NHẤT để giết cả hai (gai, vực, quái, sự kiện... đều gọi hàm này)
##   counts() = số sao đang tính cho từng người (Vector2i, = rope.bead_counts());  winner_of(counts) = 0 hoà / 1 / 2
##   hud.flash(text, seconds, color)  hiện chữ giữa màn hình;  hud (ChainedHud, scripts/ui/chained_hud.gd)
##   tín hiệu: level_started, level_finished(counts), players_died(cause), players_respawned, restart_requested
##   Game.chained_totals = tổng sao hai người qua các màn đã xong; Game.chained_index = màn đang chơi

signal level_started                    # hết phần giới thiệu, bóng điều khiển được
signal level_finished(counts: Vector2i) # về đích: số sao tính cho người chơi 1 (x) và 2 (y) lúc đó
signal players_died(cause: String)      # cả hai vừa chết (cause: "pit", "hurt", hoặc chữ khác do sự kiện đặt)
signal players_respawned                # cả hai vừa hồi sinh ở cờ lưu
signal restart_requested                # hết mạng: màn sắp được chơi lại từ đầu (bài test nghe để khỏi đổi cảnh thật)

const BALL_SCENE := preload("res://scenes/ball.tscn")   # cảnh quả bóng
const LIVES := 5                        # số mạng chung mỗi lần vào màn
const FALL_MARGIN := 160.0              # rơi thấp hơn đáy màn bấy nhiêu pixel thì tính là rơi xuống vực
const RESPAWN_INVULN := 1.5             # vừa hồi sinh: miễn sát thương trong bấy nhiêu giây
const RESPAWN_SPREAD := 24.0            # hồi sinh ở cờ lưu: người chơi 1 lệch trái, người chơi 2 lệch phải bấy nhiêu pixel
const BALL_LAYER := 2                   # lớp va chạm của bóng (bằng Ball.BALL_LAYER)
const PLAYER2_CHAR := "P"               # ký tự chỗ xuất phát của người chơi 2 trong bản đồ (ký tự O là người chơi 1)
const MIN_ZOOM := 0.75                  # camera thu nhỏ tối đa tới mức này khi hai người cách xa nhau hết cỡ dây
const SCATTER_OFFSETS := [64.0, -64.0, 96.0, -96.0, 128.0, -128.0, 160.0, -160.0, 192.0, -192.0, 224.0, -224.0]   # sao rơi cách chỗ hồi sinh bấy nhiêu pixel (xen kẽ phải / trái)
const CAUSE_TEXT := {"pit": "SPLASH!", "hurt": "OUCH!"}   # chữ báo khi chết theo nguyên nhân (còn lại: "OOPS!")

@export var intro_seconds := 1.6        # "READY..." kéo dài bao lâu (bóng đứng yên); bài test rút ngắn
@export var respawn_delay := 1.0        # chết rồi chờ bao lâu mới hồi sinh
@export var restart_delay := 1.6        # hết mạng rồi chờ bao lâu mới chơi lại màn
@export var finish_panel_delay := 0.8   # về đích rồi chờ bao lâu mới hiện bảng kết quả
@export var scene_changes_enabled := true   # false = không đổi cảnh thật khi hết mạng (bài test tắt; chỉ phát restart_requested)

@onready var camera: Camera2D = $Camera   # camera đi theo giữa hai người
@onready var hud: ChainedHud = $HUD/Hud   # giao diện: sao từng người, mạng, thông báo, bảng kết quả

var level: Level                        # màn đang chơi
var level_name := ""                    # tên màn
var balls: Array[Ball] = []             # balls[0] = người chơi 1, balls[1] = người chơi 2
var rope: Rope                          # sợi dây và các hạt
var lives := LIVES                      # mạng chung còn lại
var spawn_points: Array[Vector2] = []   # chỗ xuất phát của người chơi 1 và 2 (ký tự O và P)
var respawn_position := Vector2.ZERO    # cờ lưu gần nhất (lúc đầu là giữa hai chỗ xuất phát)
var respawn_points: Array[Vector2] = [] # chỗ hồi sinh của người chơi 1 và 2 (lúc đầu = chỗ xuất phát, sau cờ lưu = cờ lưu lệch hai bên)
var match_running := false              # true = đang chơi; false = đang giới thiệu hoặc đã về đích
var dropped_stars: Array[Pickup] = []   # các ngôi sao rơi ra đất khi có người chết (còn trên màn hay đã nhặt đều có trong danh sách)
var finished := false                   # đã về đích
var _busy := false                      # đang chết / chờ hồi sinh / chờ chơi lại: bỏ qua cú giết và về đích khác
var _base_totals: Array[int] = [0, 0]   # tổng sao trước màn này (Retry thì trả lại)
var _zoom := 1.0                        # độ zoom camera đang dùng (làm mượt)


## Dựng màn, hai người chơi, dây, nối tín hiệu rồi bắt đầu phần giới thiệu.
func _ready() -> void:
	var data: Dictionary = ChainedData.LEVELS[Game.chained_index]   # dữ liệu màn đang chọn
	level_name = data["name"]                     # tên màn
	_base_totals = [Game.chained_totals[0], Game.chained_totals[1]]   # nhớ tổng sao trước màn này

	level = Level.new()                           # tạo màn mới
	add_child(level)                              # thêm vào cảnh
	move_child(level, 0)                          # vẽ màn dưới camera và giao diện
	level.build(data["map"])                      # dựng gạch, gai, sao... từ bản đồ chữ
	spawn_points = [level.start_position, _find_spawn(PLAYER2_CHAR)]   # O là người chơi 1, P là người chơi 2
	respawn_points = spawn_points.duplicate()     # lúc đầu hồi sinh ở chỗ xuất phát
	respawn_position = (spawn_points[0] + spawn_points[1]) / 2.0   # cờ lưu ban đầu: giữa hai người

	camera.limit_left = 0                         # camera không đi ra ngoài màn
	camera.limit_right = int(level.size.x)        # camera không vượt mép phải màn
	camera.limit_bottom = int(level.size.y) + 96  # camera nhìn xuống dưới đáy màn chút xíu (người lơ lửng trên hố vẫn thấy rõ)
	camera.limit_top = mini(-64, int(level.size.y - 720.0 / MIN_ZOOM))   # chừa chỗ phía trên cho lúc zoom ra xa
	camera.position_smoothing_enabled = false     # tự làm mượt (cả vị trí lẫn zoom) trong _update_camera

	# Tường vô hình nối dài hai mép màn lên cao (như play.gd): bật rất cao (lò xo) cũng không bay ra ngoài màn.
	var bounds := StaticBody2D.new()              # thân đứng yên chứa hai bức tường
	for wall_x in [16.0, level.size.x - 16.0]:    # giữa cột tường trái và giữa cột tường phải
		var wall := CollisionShape2D.new()        # hình va chạm của một bức tường
		var rect := RectangleShape2D.new()        # hình chữ nhật
		rect.size = Vector2(32, 2000)             # rộng 1 ô, cao 2000 pixel
		wall.shape = rect                         # gán hình
		wall.position = Vector2(wall_x, -1000)    # nằm ngay trên đỉnh màn (y từ -2000 tới 0)
		bounds.add_child(wall)                    # gắn vào thân
	level.add_child(bounds)                       # thêm vào màn

	for i in 2:                                   # tạo hai quả bóng
		var ball: Ball = BALL_SCENE.instantiate() # tạo bóng từ cảnh mẫu
		ball.position = spawn_points[i]           # đặt ở chỗ xuất phát của người chơi này
		level.add_child(ball)                     # thêm bóng vào màn
		ball.set_player(i + 1)                    # phím riêng (P1: A/D/W + S, P2: mũi tên) và màu riêng
		ball.set_collide_with_balls(true)         # hai bóng va chạm nhau (dẫm đầu được)
		ball.hurt.connect(_on_ball_hurt.bind(ball))   # chạm gai / quái thì gọi _on_ball_hurt
		ball.stomped.connect(_on_stomped.bind(ball))  # dẫm lên đầu bạn thì gọi _on_stomped
		balls.append(ball)                        # lưu vào danh sách công khai

	rope = Rope.new()                             # sợi dây nối hai người
	rope.name = "Rope"                            # tên node cho dễ tìm
	level.add_child(rope)                         # thêm vào màn
	level.move_child(rope, balls[0].get_index())  # dây nằm phía sau hai quả bóng (vẽ trước bóng)
	rope.setup(balls[0], balls[1])                # buộc hai đầu dây

	level.star_collected_by.connect(_on_star)     # nhặt sao thì thêm hạt lên dây
	level.heart_collected.connect(_on_heart)      # nhặt tim thì +1 mạng chung
	level.checkpoint_reached.connect(_on_checkpoint)   # chạm cờ lưu thì cả hai hồi sinh ở đó
	level.finished.connect(_on_finished)          # chạm đích thì gọi _on_finished

	hud.setup(level_name, LIVES)                  # cài giao diện
	hud.next_pressed.connect(func() -> void: Game.start_chained(Game.chained_index + 1))   # Next level: màn kế (tổng sao giữ nguyên)
	hud.retry_pressed.connect(_on_retry)          # Retry: chơi lại màn này
	hud.menu_pressed.connect(Game.go_to_menu)     # Menu: về menu
	_update_camera(0.0, true)                     # camera vào đúng chỗ ngay
	_start_intro()                                # "READY... GO!" rồi mới cho chơi


## Đọc vị trí xuất phát của ký tự `ch` trong bản đồ (cùng công thức với Level: giữa đáy ô, cao hơn nửa thân).
func _find_spawn(ch: String) -> Vector2:
	for r in level.rows.size():                   # duyệt từng hàng
		var c: int = level.rows[r].find(ch)       # tìm ký tự trong hàng
		if c != -1:                               # có ký tự này
			return Vector2((c + 0.5) * Level.TILE, (r + 1) * Level.TILE - 16.0)   # giữa đáy ô, cao hơn đáy nửa thân
	push_error("Chained: level '%s' has no '%s' spawn" % [level_name, ch])   # màn thiếu chỗ xuất phát
	return level.start_position + Vector2(64.0, 0.0)   # tạm đặt cạnh người chơi 1


## Giới thiệu: "READY..." (bóng đứng yên) rồi "GO!" và bắt đầu.
func _start_intro() -> void:
	for ball in balls:                            # hai bóng
		ball.dead = true                          # đứng yên, không điều khiển được trong lúc giới thiệu
	hud.flash("READY...", intro_seconds)          # báo chuẩn bị
	await get_tree().create_timer(intro_seconds).timeout   # chờ hết phần giới thiệu
	if not is_inside_tree():                      # cảnh đã bị đổi trong lúc chờ
		return
	for ball in balls:                            # hai bóng
		ball.dead = false                         # cho điều khiển
	match_running = true                          # bắt đầu chơi
	hud.flash("GO!", 0.7, Color("#f7d046"))       # báo bắt đầu
	level_started.emit()                          # báo cho các tính năng khác


## Số sao đang tính cho từng người (x = người chơi 1, y = người chơi 2); hạt đúng giữa dây không tính cho ai.
func counts() -> Vector2i:
	return rope.bead_counts()                     # đếm hạt theo phía


## Người thắng màn theo số sao: 1 / 2, hoặc 0 nếu hoà.
func winner_of(result: Vector2i) -> int:
	return ChainedHud.winner_of(result)           # dùng chung với bảng kết quả


## Có màn kế tiếp không.
func has_next_level() -> bool:
	return Game.chained_index + 1 < ChainedData.LEVELS.size()   # còn màn sau trong danh sách


## 60 lần mỗi giây: phím Esc, camera, rơi xuống vực, cập nhật số sao trên HUD.
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("back"):      # bấm Esc
		Game.go_to_menu()                         # về menu bất cứ lúc nào
		return
	_update_camera(delta)                         # camera theo giữa hai người
	if not match_running or _busy:                # đang giới thiệu, đã về đích hoặc đang chết
		return
	for ball in balls:                            # kiểm tra từng bóng có rơi xuống vực không
		if ball.global_position.y > level.size.y + FALL_MARGIN:   # thấp hơn đáy màn quá xa
			kill_both("pit", ball)                # rơi xuống vực: cả hai chết, bóng này là người gây ra
			return
	var c := rope.bead_counts()                   # số sao đang nằm về phía mỗi người
	hud.set_counts(c.x, c.y)                      # cập nhật HUD


## Camera đi theo giữa hai người và thu nhỏ dần khi dây căng ra (zoom 1.0 lúc dây chùng, MIN_ZOOM lúc dây căng hết cỡ). `snap` = nhảy tới ngay, không làm mượt.
func _update_camera(delta: float, snap := false) -> void:
	var a := balls[0].global_position             # người chơi 1
	var b := balls[1].global_position             # người chơi 2
	var target := (a + b) / 2.0 + Vector2(0.0, -40.0)   # giữa hai người, nhìn cao hơn một chút
	var want_zoom := zoom_for_separation(a.distance_to(b))   # độ zoom hợp với khoảng cách
	if snap:                                      # nhảy tới ngay
		camera.global_position = target           # đặt vị trí
		_zoom = want_zoom                         # đặt zoom
	else:                                         # trượt mượt
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-6.0 * delta))   # vị trí
		_zoom = lerpf(_zoom, want_zoom, 1.0 - exp(-3.0 * delta))   # zoom chậm hơn vị trí cho đỡ chóng mặt
	camera.zoom = Vector2(_zoom, _zoom)           # áp zoom


## Độ zoom camera khi hai người cách nhau `dist` pixel: 1.0 từ lúc dây chùng (rest_length) trở xuống, giảm dần tới MIN_ZOOM lúc dây căng hết cỡ (max_length).
func zoom_for_separation(dist: float) -> float:
	var f := clampf(inverse_lerp(rope.rest_length, rope.max_length, dist), 0.0, 1.0)   # 0 = chùng, 1 = căng hết cỡ
	return lerpf(1.0, MIN_ZOOM, f)                # zoom tương ứng


# ---- Sao, tim, cờ lưu ----

## Nhặt một ngôi sao: thêm hạt lên giữa dây (nó sẽ trượt về phía người đứng thấp hơn).
func _on_star(_by: Ball) -> void:
	rope.add_bead(0.5)                            # hạt mới ở giữa dây


## Nhặt trái tim: +1 mạng chung, tối đa LIVES.
func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)                # thêm 1 mạng nhưng không vượt LIVES
	hud.set_lives(lives)                          # cập nhật HUD
	hud.flash("+1 LIFE!", 0.9, Color("#ff6b81"))  # báo


## Một trong hai người chạm cờ lưu: cả hai hồi sinh ở đây từ giờ.
func _on_checkpoint(pos: Vector2) -> void:
	respawn_position = pos                        # nhớ chỗ hồi sinh mới
	respawn_points = [pos + Vector2(-RESPAWN_SPREAD, 0.0), pos + Vector2(RESPAWN_SPREAD, 0.0)]   # người chơi 1 lệch trái, người chơi 2 lệch phải
	hud.flash("CHECKPOINT!", 1.0)                 # báo


# ---- Cướp sao ----

## `stomper` vừa đáp xuống đầu `victim`: hạt gần đầu nạn nhân nhất nhảy sang đầu kẻ dẫm (nạn nhân đang miễn sát thương thì không tính).
func _on_stomped(victim: Ball, stomper: Ball) -> void:
	if not match_running or _busy or stomper.dead or victim.dead or victim.invuln > 0.0:   # lúc này không tính
		return
	if rope.steal_bead(stomper, victim):          # có hạt để cướp
		hud.flash("P%d STEALS A STAR!" % stomper.player_id, 1.0, ChainedHud.PLAYER_COLORS[stomper.player_id - 1])   # báo


# ---- Chết và hồi sinh ----

## Một người chạm gai / quái: cả hai chết, người đó là người gây ra. Gọi muộn để khỏi đổi vật lý ngay trong lúc Godot đang xử lý va chạm.
func _on_ball_hurt(ball: Ball) -> void:
	kill_both.call_deferred("hurt", ball)         # gai, quái... đều tính là "hurt"


## CỔNG DUY NHẤT để giết cả hai người chơi (gai, vực, quái, sự kiện... đều gọi hàm này): mất 1 mạng chung, cả hai hồi sinh ở cờ lưu gần nhất,
## một nửa (làm tròn lên) số sao ở phía `culprit` rơi ra đất quanh chỗ hồi sinh. `culprit` = null (sự kiện, môi trường) thì không rơi sao nào.
## Bỏ qua nếu đang giới thiệu, đã về đích, hoặc đã đang chết. `cause` hiện ra trong tín hiệu players_died: "pit", "hurt", hoặc chữ khác tuỳ sự kiện.
func kill_both(cause: String, culprit: Ball = null) -> void:
	if not match_running or _busy:                # không tính lúc này
		return
	_busy = true                                  # khoá: không bị giết hai lần
	lives -= 1                                    # mất 1 mạng chung
	hud.set_lives(maxi(lives, 0))                 # cập nhật HUD
	for ball in balls:                            # cả hai không điều khiển được, không bị thương nữa
		ball.dead = true                          # đánh dấu chết ngay
	players_died.emit(cause)                      # báo cho các tính năng khác
	_death_sequence.call_deferred(cause, culprit) # hiệu ứng, đổi vật lý: làm ở cuối khung


## Cảnh chết: bóng vỡ, hạt rơi khỏi dây, rồi chờ hồi sinh (hoặc chơi lại màn nếu hết mạng).
func _death_sequence(cause: String, culprit: Ball) -> void:
	var dropped := 0                              # số hạt rơi khỏi dây
	if culprit != null:                           # có người gây ra
		dropped = rope.drop_beads(culprit.player_id)   # một nửa số hạt phía họ rơi
	for ball in balls:                            # hai bóng vỡ
		_pop_effect(ball.global_position, ChainedHud.PLAYER_COLORS[ball.player_id - 1])   # mảnh vỡ
		ball.hide()                               # ẩn bóng
		ball.collision_layer = 0                  # bóng ẩn không cản đường, không dính gai
		ball.teleport(respawn_points[ball.player_id - 1])   # dịch về cờ lưu (đang ẩn)
	rope.reset()                                  # dây chùng lại, thả neo
	rope.hide()                                   # dây ẩn cùng hai bóng
	var text: String = CAUSE_TEXT.get(cause, "OOPS!")   # chữ báo theo nguyên nhân
	if dropped > 0:                               # có sao rơi
		text += "\nP%d DROPPED %d STAR%s!" % [culprit.player_id, dropped, "" if dropped == 1 else "S"]   # nói rõ ai làm rơi
	if lives <= 0:                                # hết mạng
		hud.flash("Out of lives! Restarting...", restart_delay + 0.5, Color("#ff5d5d"))   # báo hết mạng
		await get_tree().create_timer(restart_delay).timeout   # chờ cho người chơi đọc
		if not is_inside_tree():                  # cảnh đã bị đổi trong lúc chờ
			return
		restart_level()                           # chơi lại màn từ đầu
		return
	hud.flash(text, respawn_delay + 0.4, Color("#ff9a5d"))   # báo chết
	await get_tree().create_timer(respawn_delay).timeout   # chờ một lúc rồi hồi sinh
	if not is_inside_tree():                      # cảnh đã bị đổi trong lúc chờ
		return
	_respawn(dropped)                             # hồi sinh cả hai


## Hồi sinh cả hai ở cờ lưu gần nhất, miễn sát thương một lúc; rải `dropped` ngôi sao ra đất quanh đó.
func _respawn(dropped: int) -> void:
	level.reset_crates()                          # thùng về chỗ cũ để không bị kẹt
	for ball in balls:                            # từng người
		ball.teleport(respawn_points[ball.player_id - 1])   # đặt lại ở cờ lưu
		ball.collision_layer = BALL_LAYER         # va chạm trở lại
		ball.show()                               # hiện bóng
		ball.invuln = RESPAWN_INVULN              # miễn sát thương
		ball.dead = false                         # sống lại
	rope.reset()                                  # dây chùng
	rope.show()                                   # hiện dây
	_scatter_stars(dropped)                       # sao rơi ra đất để hai người tranh nhau nhặt
	_update_camera(0.0, true)                     # camera nhảy tới chỗ hồi sinh
	_busy = false                                 # mở khoá
	players_respawned.emit()                      # báo cho các tính năng khác


## Rải `count` ngôi sao nhặt lại được ra mặt đất quanh chỗ hồi sinh (xen kẽ trái / phải, xa dần). Nhặt lại thì thành hạt mới ở giữa dây.
## Nhiều quá thì xếp thêm tầng cao hơn (nhảy mới với tới). Chỗ không có đất hoặc có gai thì bỏ qua.
func _scatter_stars(count: int) -> void:
	var placed := 0                               # số sao đã đặt
	for tier in 4:                                # tối đa 4 tầng
		for off: float in SCATTER_OFFSETS:        # từng chỗ
			if placed >= count:                   # đủ rồi
				return
			var ground = _ground_point(respawn_position.x + off)   # mặt đất ở chỗ này (null nếu không có)
			if ground == null:                    # không có đất
				continue
			var star: Pickup = Level.PICKUP.instantiate()   # tạo ngôi sao
			star.kind = "star"                    # loại sao
			star.position = ground + Vector2(0.0, -40.0 * tier)   # đặt trên mặt đất (tầng cao thì lơ lửng)
			level.add_child(star)                 # thêm vào màn
			dropped_stars.append(star)            # nhớ để bài test và các tính năng khác tìm
			placed += 1                           # đếm


## Mặt đất ngay dưới (hoặc quanh) toạ độ x gần cờ lưu: Vector2 hoặc null nếu không có đất / ô đó có gai.
func _ground_point(x: float):
	var from := Vector2(x, respawn_position.y - 48.0)   # bắn tia từ phía trên cờ lưu xuống
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 120.0), 1)   # chỉ xét đất (lớp 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)   # tia chạm gì
	if hit.is_empty():                            # không có đất
		return null
	var point: Vector2 = hit["position"]          # chỗ chạm = mặt đất
	var tile_c := int(point.x / Level.TILE)       # cột ô
	var tile_r := int(point.y / Level.TILE) - 1   # hàng ô ngay trên mặt đất (chỗ ngôi sao đứng)
	var above := level.char_at(tile_r, tile_c)    # ký tự ở ô đó
	if above == "^" or above == "v" or above == "T":   # gai hoặc lò xo
		return null
	return point


## Hiệu ứng bóng vỡ thành mảnh (màu của người chơi).
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


## Hết mạng: màn được chơi lại từ đầu. (Bài test đặt scene_changes_enabled = false thì chỉ phát tín hiệu.)
func restart_level() -> void:
	restart_requested.emit()                      # báo
	if scene_changes_enabled:                     # chạy thật
		Game.start_chained(Game.chained_index)    # vào lại màn này (màn đầu thì tổng sao về 0)


## Bấm Retry ở bảng kết quả: trả tổng sao về như trước màn này rồi chơi lại màn.
func _on_retry() -> void:
	Game.chained_totals[0] = _base_totals[0]      # bỏ phần sao của lần chơi vừa xong
	Game.chained_totals[1] = _base_totals[1]      # (khỏi tính hai lần khi chơi lại)
	Game.start_chained(Game.chained_index)        # chơi lại màn này


# ---- Về đích ----

## Chạm đích: chỉ tính khi đang chơi và cả hai còn sống. Chốt số sao, cộng vào tổng, hiện bảng kết quả sau một lúc.
func _on_finished() -> void:
	if not match_running or _busy or balls[0].dead or balls[1].dead:   # lúc này không tính (đang chết, giới thiệu...)
		_reopen_finish()                          # lá cờ đích đã "dùng" rồi: mở lại để chạm lần sau còn tính
		return
	match_running = false                         # hết màn: không chết, không về đích nữa
	finished = true                               # đã về đích
	rope.freeze_beads = true                      # chốt số sao: hạt không trượt nữa
	var result := rope.bead_counts()              # số sao của mỗi người lúc này
	Game.chained_totals[0] = _base_totals[0] + result.x   # cộng vào tổng
	Game.chained_totals[1] = _base_totals[1] + result.y   # (tính từ tổng trước màn này, Retry không cộng hai lần)
	hud.set_counts(result.x, result.y)            # HUD hiện số cuối
	for ball in balls:                            # hai người đứng yên (bảng kết quả nhận phím)
		ball.dead = true                          # không điều khiển nữa
	level_finished.emit(result)                   # báo cho các tính năng khác (màn mới, hình phạt cuối màn...)
	hud.flash("FINISH!", finish_panel_delay, Color("#f7d046"))   # báo về đích
	await get_tree().create_timer(finish_panel_delay).timeout   # để người chơi kịp thấy
	if not is_inside_tree():                      # cảnh đã bị đổi trong lúc chờ
		return
	hud.show_result(result, Game.chained_totals, has_next_level())   # bảng kết quả với nút Next level / Retry / Menu


## Mở lại lá cờ đích (Pickup đích chỉ phát tín hiệu một lần; nếu lần chạm đó không tính thì phải mở lại).
func _reopen_finish() -> void:
	for node in level.get_children():             # duyệt mọi vật trong màn
		if node is Pickup and node.kind == "finish":   # là cờ đích
			node.used = false                     # cho chạm lại
