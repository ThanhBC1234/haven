class_name BrawlEvents                  # tên lớp: brawl.gd tạo ra, bài test và các tính năng thêm sau dùng
extends Node                            # nút con của Brawl (brawl.events)
## Sự kiện ngẫu nhiên của chế độ đấu 2 người: trong lúc trận đang chạy, cứ mỗi `interval` giây bốc thăm một sự kiện
## (lần đầu sau `first_delay` giây). Trước khi sự kiện bắt đầu có màn quay "roulette" ở giữa trên màn hình (`roulette_seconds`).
## Sáu sự kiện (EVENT_IDS): LOW GRAVITY, SUPER BOUNCE, ICE FLOOR, REVERSED KEYS, SWAP!, HOT POTATO.
## Mọi hiệu ứng đều được hoàn tác đúng như cũ khi sự kiện hết, khi hết trận, hoặc khi gọi stop_event().
## Người chơi hồi sinh giữa chừng được áp lại hiệu ứng đang chạy (nghe player_respawned).
##
## ---- Phần công khai (bài test và các tính năng thêm sau) ----
##   enabled, interval, first_delay, roulette_seconds         thông số bốc thăm (bài test rút ngắn)
##   *_seconds, low_gravity_scale, super_bounce_bounce, ice_friction, potato_pass_cooldown   thông số từng sự kiện
##   active_event ("" = không có), rolling_event (đang quay roulette), time_left, bomb_carrier
##   start_event(id) = bắt đầu ngay, bỏ qua roulette (chỉ chạy khi trận đang diễn ra);  stop_event() = kết thúc ngay
##   pick_event() = bốc một sự kiện, không bao giờ trùng sự kiện ngay trước;  event_name(id), duration_of(id)
##   tín hiệu: event_started(id), event_ended(id)   (SWAP! tức thì: phát cả hai liên tiếp)

signal event_started(id: String)        # một sự kiện vừa bắt đầu (sau roulette)
signal event_ended(id: String)          # sự kiện vừa kết thúc (hết giờ, hết trận hoặc bị stop_event)

const EVENT_IDS: Array[String] = ["low_gravity", "super_bounce", "ice_floor", "reversed_keys", "swap", "hot_potato"]   # mã sáu sự kiện
const EVENT_NAMES := {                  # tên hiện trên màn hình (chỉ chữ ASCII)
	"low_gravity": "LOW GRAVITY", "super_bounce": "SUPER BOUNCE", "ice_floor": "ICE FLOOR",
	"reversed_keys": "REVERSED KEYS", "swap": "SWAP!", "hot_potato": "HOT POTATO",
}
const EVENT_COLORS := {                 # màu chữ của từng sự kiện trên banner
	"low_gravity": Color("#b48cff"), "super_bounce": Color("#a3e05a"), "ice_floor": Color("#9fe0ff"),
	"reversed_keys": Color("#ffb020"), "swap": Color("#7fd6e0"), "hot_potato": Color("#ff6a3d"),
}
const POTATO_TOUCH_GAP := 2.0           # cách nhau (mép tới mép) dưới bấy nhiêu pixel thì tính là chạm nhau (chuyền bom)
const BOMB_OFFSET := 62.0               # tâm quả bom nằm cao hơn mép trên bóng bấy nhiêu pixel (tính từ tâm bóng cộng bán kính)

var enabled := true                     # false = không bốc thăm sự kiện mới (sự kiện đang chạy vẫn chạy nốt)
var interval := 15.0                    # cứ bấy nhiêu giây (từ lúc bắt đầu sự kiện này tới lúc bắt đầu sự kiện sau) bốc thăm một lần
var first_delay := 10.0                 # sự kiện đầu tiên sau bấy nhiêu giây kể từ lúc trận bắt đầu
var roulette_seconds := 2.0             # màn quay roulette kéo dài bao lâu trước khi sự kiện bắt đầu
var low_gravity_seconds := 10.0         # LOW GRAVITY kéo dài bao lâu
var super_bounce_seconds := 10.0        # SUPER BOUNCE kéo dài bao lâu
var ice_floor_seconds := 10.0           # ICE FLOOR kéo dài bao lâu
var reversed_keys_seconds := 8.0        # REVERSED KEYS kéo dài bao lâu
var hot_potato_seconds := 8.0           # ngòi bom cháy bao lâu thì nổ
var low_gravity_scale := 0.4            # LOW GRAVITY: trọng lực nhân với số này (nhảy cao gấp ~2,5 lần, rơi chậm lại)
var super_bounce_bounce := 0.98         # SUPER BOUNCE: độ nảy của bóng (gốc 0,55); gần 1 = gần như không mất năng lượng
var ice_friction := 0.02                # ICE FLOOR: ma sát của bóng (gốc 0,9); gần 0 = trượt mãi
var potato_pass_cooldown := 1.0         # HOT POTATO: sau mỗi lần chuyền, chờ bấy nhiêu giây mới chuyền tiếp được (khỏi nảy qua nảy lại)

var active_event := ""                  # sự kiện đang chạy ("" = không có; SWAP! tức thì nên không bao giờ nằm ở đây)
var rolling_event := ""                 # sự kiện đang được quay roulette (sắp bắt đầu), "" = không quay
var last_event := ""                    # sự kiện bốc / bắt đầu gần nhất (để không trùng hai lần liên tiếp)
var time_left := 0.0                    # sự kiện đang chạy còn bao nhiêu giây
var bomb_carrier: Ball = null           # HOT POTATO: người đang cầm bom (null khi không có)
var brawl: Brawl                        # cảnh đấu chứa nút này

var _next_in := 0.0                     # còn bao lâu nữa bốc thăm sự kiện kế tiếp
var _roll_left := 0.0                   # roulette còn quay bao lâu
var _saved := {}                        # giá trị gốc của bóng trước khi sự kiện đổi: {Ball: {"gravity": .., "material": .., "reverse": ..}}
var _ice: IceOverlay = null             # lớp phủ băng trên đất (null khi không có ICE FLOOR)
var _bomb: BombMarker = null            # quả bom nổi trên đầu người cầm (null khi không có HOT POTATO)
var _pass_cd := 0.0                     # còn bao lâu nữa mới được chuyền bom
var _swap_wait := 0                     # > 0: còn bao nhiêu khung nữa thì trả vận tốc cho hai bóng vừa hoán đổi chỗ
var _swap_velocities: Array[Vector2] = []   # vận tốc mới của bóng 0 và bóng 1 sau khi hoán đổi


## Nối vào cảnh đấu cha: nghe bắt đầu trận, hết trận, hồi sinh và ghi điểm.
func _ready() -> void:
	brawl = get_parent() as Brawl                 # nút cha là Brawl
	if brawl == null:                             # đặt sai chỗ
		push_error("BrawlEvents must be a child of Brawl")   # báo lỗi dùng sai
		return
	brawl.match_started.connect(_on_match_started)   # trận bắt đầu: tính giờ sự kiện đầu tiên
	brawl.match_over.connect(_on_match_over)      # hết trận: hoàn tác mọi thứ
	brawl.player_respawned.connect(_on_player_respawned)   # hồi sinh: áp lại hiệu ứng đang chạy
	brawl.point_scored.connect(_on_point_scored)  # có điểm: người cầm bom chết thì sự kiện bom kết thúc
	_next_in = first_delay                        # phòng khi trận đã bắt đầu rồi


## Tên hiện trên màn hình của sự kiện `id` (vd. "LOW GRAVITY").
func event_name(id: String) -> String:
	return EVENT_NAMES.get(id, id.to_upper())     # id lạ thì in hoa chính id


## Sự kiện `id` kéo dài bao lâu (giây); SWAP! tức thì nên là 0.
func duration_of(id: String) -> float:
	match id:                                     # theo sự kiện
		"low_gravity":
			return low_gravity_seconds            # nhảy cao rơi chậm
		"super_bounce":
			return super_bounce_seconds           # nảy như cao su
		"ice_floor":
			return ice_floor_seconds              # sàn băng
		"reversed_keys":
			return reversed_keys_seconds          # đảo trái phải
		"hot_potato":
			return hot_potato_seconds             # thời gian cháy ngòi
	return 0.0                                    # SWAP! hoặc id lạ


## Bốc một sự kiện ngẫu nhiên, không bao giờ trùng sự kiện ngay trước (last_event); ghi nhớ kết quả vào last_event.
func pick_event() -> String:
	var options: Array[String] = []               # các sự kiện được phép bốc
	for e in EVENT_IDS:                           # duyệt sáu sự kiện
		if e != last_event:                       # bỏ sự kiện vừa rồi
			options.append(e)                     # còn lại thì được bốc
	var id: String = options[randi() % options.size()]   # bốc ngẫu nhiên
	last_event = id                               # nhớ để lần sau không trùng
	return id                                     # trả về mã sự kiện


## Bắt đầu sự kiện `id` NGAY (bỏ qua roulette). Chỉ chạy khi trận đang diễn ra; sự kiện đang chạy (nếu có) bị kết thúc trước.
func start_event(id: String) -> void:
	if not EVENT_IDS.has(id) or brawl == null or not brawl.match_running:   # mã lạ, hoặc đang giới thiệu / đã hết trận
		return
	stop_event()                                  # dọn sự kiện và roulette đang có
	_next_in = interval                           # tính lại giờ cho sự kiện bốc thăm kế tiếp
	_begin(id)                                    # bắt đầu luôn


## Kết thúc ngay sự kiện đang chạy (và huỷ roulette đang quay): hoàn tác mọi hiệu ứng, ẩn banner, phát event_ended.
func stop_event() -> void:
	rolling_event = ""                            # huỷ roulette
	_roll_left = 0.0                              # hết giờ quay
	var id := active_event                        # sự kiện đang chạy
	if brawl != null and brawl.hud != null:       # ẩn banner (cả khi chỉ đang quay roulette)
		brawl.hud.hide_event()                    # banner biến mất
	if id == "":                                  # không có sự kiện nào đang chạy
		return
	_revert(id)                                   # trả mọi thứ về như cũ
	active_event = ""                             # không còn sự kiện nào
	time_left = 0.0                               # hết giờ
	event_ended.emit(id)                          # báo cho các tính năng khác


## Bắt đầu quay roulette cho sự kiện `id`: banner quay vài giây rồi dừng ở đúng sự kiện đó.
func _start_roulette(id: String) -> void:
	_next_in = interval                           # đếm giờ từ lúc bắt đầu sự kiện này
	if roulette_seconds <= 0.0:                   # không quay
		_begin(id)                                # vào luôn
		return
	rolling_event = id                            # đang quay tới sự kiện này
	_roll_left = roulette_seconds                 # quay chừng này giây
	var names: Array = []                         # tên các sự kiện để banner quay qua
	for e in EVENT_IDS:                           # duyệt sáu sự kiện
		names.append(EVENT_NAMES[e])              # thêm tên hiện trên màn hình
	brawl.hud.show_event_roulette(names, EVENT_NAMES[id], roulette_seconds, EVENT_COLORS[id])   # banner quay và dừng ở sự kiện đã bốc


## Sự kiện `id` thực sự bắt đầu: áp hiệu ứng cho hai người chơi, hiện banner đếm ngược.
func _begin(id: String) -> void:
	rolling_event = ""                            # hết quay
	_roll_left = 0.0                              # hết giờ quay
	last_event = id                               # nhớ để không bốc trùng
	if id == "swap":                              # SWAP! tức thì: không có thời lượng
		event_started.emit(id)                    # báo bắt đầu
		brawl.hud.hide_event()                    # tắt banner roulette
		_do_swap()                                # hai người đổi chỗ
		brawl.hud.flash("SWAP!", 0.8, EVENT_COLORS[id])   # báo chữ lớn ở giữa trên
		event_ended.emit(id)                      # xong ngay
		return
	active_event = id                             # đang chạy sự kiện này
	time_left = duration_of(id)                   # đếm ngược từ đây
	_pass_cd = 0.0                                # (HOT POTATO) chuyền được ngay
	if id == "ice_floor":                         # sàn băng: phủ màu xanh nhạt lên đất
		_ice_on()                                 # hiện lớp phủ băng
	elif id == "hot_potato":                      # bom: bốc người cầm
		_give_bomb()                              # phát bom cho một người
	for ball in brawl.balls:                      # áp cho cả hai người chơi
		_apply_to(ball, id)                       # đổi trọng lực / độ nảy / ma sát / phím
	brawl.hud.show_event(EVENT_NAMES[id], time_left, EVENT_COLORS[id])   # banner tên + thanh đếm ngược
	event_started.emit(id)                        # báo bắt đầu


## 60 lần mỗi giây khi trận đang chạy: đếm giờ bốc thăm, quay roulette, đếm ngược sự kiện, chuyền bom.
func _physics_process(delta: float) -> void:
	if _swap_wait > 0:                            # hoán đổi chỗ xong, đợi vật lý dịch bóng rồi mới trả vận tốc
		_swap_wait -= 1                           # đếm ngược số khung
		if _swap_wait == 0:                       # tới lúc
			for i in 2:                           # hai bóng
				if is_instance_valid(brawl.balls[i]) and not brawl.balls[i].dead:   # còn sống
					brawl.balls[i].linear_velocity = _swap_velocities[i]   # trả vận tốc đã hoán đổi
	if brawl == null or not brawl.match_running:  # đang giới thiệu hoặc đã hết trận: không có sự kiện
		return
	_next_in = maxf(0.0, _next_in - delta)        # đếm giờ bốc thăm (chạy cả lúc đang có sự kiện)
	if rolling_event != "":                       # đang quay roulette
		_roll_left -= delta                       # đếm ngược
		if _roll_left <= 0.0:                     # quay xong
			_begin(rolling_event)                 # sự kiện bắt đầu
	elif active_event != "":                      # đang có sự kiện
		_tick_active(delta)                       # đếm ngược, chuyền bom
	elif enabled and _next_in <= 0.0:             # rảnh và tới giờ
		_start_roulette(pick_event())             # bốc thăm và quay


## Một khung của sự kiện đang chạy: trừ giờ; HOT POTATO thì chuyền bom khi chạm và nổ khi hết ngòi.
func _tick_active(delta: float) -> void:
	time_left -= delta                            # trừ thời gian còn lại
	if active_event == "hot_potato":              # bom đang cháy
		_tick_potato(delta)                       # chuyền bom, cập nhật số đếm
	if time_left <= 0.0 and active_event != "":   # hết giờ
		if active_event == "hot_potato":          # bom hết ngòi
			_explode_potato()                     # nổ
		else:
			stop_event()                          # hoàn tác mọi hiệu ứng


## Áp hiệu ứng của sự kiện `id` lên một quả bóng (gọi lại nhiều lần vẫn an toàn: lúc bắt đầu và lúc hồi sinh).
func _apply_to(ball: Ball, id: String) -> void:
	match id:                                     # theo sự kiện
		"low_gravity":
			_save(ball, "gravity", ball.gravity_scale)   # nhớ trọng lực gốc
			ball.gravity_scale = low_gravity_scale   # rơi chậm, nhảy cao (vận tốc nhảy giữ nguyên)
		"super_bounce":
			_set_material(ball, "bounce", super_bounce_bounce)   # nảy như cao su
		"ice_floor":
			_set_material(ball, "friction", ice_friction)   # gần như không ma sát: trượt
		"reversed_keys":
			_save(ball, "reverse", ball.reverse_controls)   # nhớ chế độ phím gốc
			if not ball.reverse_controls:         # chưa đảo (đặt lại sẽ xoá lực đang tích nên chỉ đặt khi cần)
				ball.reverse_controls = true      # trái thành phải, phải thành trái


## Hoàn tác hiệu ứng của sự kiện `id` trên cả hai bóng, trả đúng giá trị gốc đã nhớ.
func _revert(id: String) -> void:
	for ball in _saved.keys():                    # mọi quả bóng đã bị đổi
		if not is_instance_valid(ball):           # bóng đã bị xoá (cảnh đang đóng)
			continue
		var s: Dictionary = _saved[ball]          # giá trị gốc của bóng này
		match id:                                 # theo sự kiện
			"low_gravity":
				if s.has("gravity"):              # đã đổi trọng lực
					ball.gravity_scale = s["gravity"]   # trả trọng lực gốc
			"super_bounce", "ice_floor":
				if s.has("material"):             # đã thay vật liệu vật lý
					ball.physics_material_override = s["material"]   # trả đúng vật liệu gốc (dùng chung của cảnh bóng)
			"reversed_keys":
				if s.has("reverse") and ball.reverse_controls != s["reverse"]:   # còn đang đảo
					ball.reverse_controls = s["reverse"]   # trả phím như cũ
	_saved.clear()                                # quên hết giá trị gốc
	if id == "ice_floor":                         # sàn băng
		_ice_off()                                # bỏ lớp phủ băng
	elif id == "hot_potato":                      # bom
		_remove_bomb()                            # bỏ bom khỏi đầu người cầm


## Nhớ giá trị gốc `key` của bóng (chỉ lần đầu: hồi sinh áp lại hiệu ứng sẽ không ghi đè giá trị gốc bằng giá trị đã đổi).
func _save(ball: Ball, key: String, value: Variant) -> void:
	var s: Dictionary = _saved.get_or_add(ball, {})   # sổ giá trị gốc của bóng này
	if not s.has(key):                            # chưa nhớ
		s[key] = value                            # nhớ giá trị gốc


## Đổi độ nảy / ma sát của bóng bằng một PhysicsMaterial nhân bản (vật liệu trong cảnh bóng dùng chung cho mọi bóng nên không sửa trực tiếp).
func _set_material(ball: Ball, property: String, value: float) -> void:
	_save(ball, "material", ball.physics_material_override)   # nhớ vật liệu gốc (đúng đối tượng dùng chung)
	var base: PhysicsMaterial = _saved[ball]["material"]   # vật liệu gốc
	var mat: PhysicsMaterial = base.duplicate() if base != null else PhysicsMaterial.new()   # bản riêng của bóng này
	if ball.physics_material_override != null and ball.physics_material_override != base:   # đã có bản riêng (vd. hồi sinh): giữ thay đổi của sự kiện
		mat = ball.physics_material_override      # dùng lại bản riêng đó
	mat.set(property, value)                      # đổi độ nảy hoặc ma sát
	ball.physics_material_override = mat          # gán cho bóng


## Người chơi vừa hồi sinh: áp lại hiệu ứng của sự kiện đang chạy (nếu có), để hiệu ứng không "rơi mất" khi chết.
func _on_player_respawned(ball: Ball) -> void:
	if active_event != "" and active_event != "hot_potato":   # đang có sự kiện kéo dài (bom đã kết thúc khi người cầm chết)
		_apply_to(ball, active_event)             # áp lại cho đúng người này


## Trận bắt đầu (hết phần giới thiệu): dọn mọi thứ còn sót và tính giờ sự kiện đầu tiên.
func _on_match_started() -> void:
	stop_event()                                  # chắc chắn sạch sẽ
	_next_in = first_delay                        # sự kiện đầu tiên sau chừng này giây


## Hết trận: kết thúc sự kiện đang chạy / đang quay, hoàn tác mọi hiệu ứng.
func _on_match_over(_winner: Ball) -> void:
	stop_event()                                  # trả mọi thứ về như cũ


## Có người ghi điểm: người cầm bom chết vì lý do khác (vực, dẫm, gai) thì sự kiện bom kết thúc, không thêm điểm.
func _on_point_scored(_scorer: Ball, victim: Ball, cause: String) -> void:
	if active_event == "hot_potato" and victim == bomb_carrier and cause != "bomb":   # bom nổ do hết ngòi tự xử lý ở _explode_potato
		stop_event()                              # bom biến mất cùng người cầm


# ---- SWAP! ----

## Hai người chơi đổi chỗ cho nhau (vị trí và vận tốc). Bỏ qua nếu một người đang chết (đang chờ hồi sinh).
func _do_swap() -> void:
	var a := brawl.balls[0]                       # người chơi 1
	var b := brawl.balls[1]                       # người chơi 2
	if a.dead or b.dead:                          # một người đang chờ hồi sinh: không có gì để đổi
		return
	var pos_a := a.global_position                # chỗ cũ của người chơi 1
	var pos_b := b.global_position                # chỗ cũ của người chơi 2
	_swap_velocities = [b.linear_velocity, a.linear_velocity]   # mỗi người nhận vận tốc của người kia
	_burst(pos_a, BrawlHud.PLAYER_COLORS[0], 14, 80.0, 220.0, 0.45)   # tia sáng ở chỗ cũ của người chơi 1
	_burst(pos_b, BrawlHud.PLAYER_COLORS[1], 14, 80.0, 220.0, 0.45)   # tia sáng ở chỗ cũ của người chơi 2
	a.teleport(pos_b)                             # dịch người chơi 1 sang chỗ người chơi 2 (teleport xoá vận tốc)
	b.teleport(pos_a)                             # và ngược lại
	_swap_wait = 2                                # 2 khung nữa vật lý đã dịch xong thì trả vận tốc


# ---- HOT POTATO ----

## Phát bom cho một người chơi còn sống (ngẫu nhiên), gắn quả bom nổi lên trên đầu.
func _give_bomb() -> void:
	var options: Array[Ball] = []                 # những người được nhận bom
	for ball in brawl.balls:                      # duyệt hai người
		if not ball.dead:                         # còn sống
			options.append(ball)                  # được nhận
	if options.is_empty():                        # cả hai đang chờ hồi sinh (rất hiếm)
		options.append_array(brawl.balls)         # thôi thì ai cũng được
	_set_carrier(options[randi() % options.size()])   # bốc ngẫu nhiên
	_bomb.fuse_left = time_left                   # số đếm bắt đầu từ ngòi đầy
	_bomb.fuse_total = time_left                  # tổng thời gian ngòi (để tính tốc độ nhấp nháy)
	brawl.hud.flash("P%d HAS THE BOMB!" % bomb_carrier.player_id, 1.0, BrawlHud.PLAYER_COLORS[brawl.balls.find(bomb_carrier)])   # báo ai cầm


## Giao bom cho `ball`: bom nổi trên đầu người đó (người cũ mất bom).
func _set_carrier(ball: Ball) -> void:
	var fuse := time_left                         # ngòi còn bao lâu (giữ nguyên khi chuyền)
	var total := hot_potato_seconds               # tổng thời gian ngòi
	if _bomb != null:                             # đang ở trên đầu người khác
		fuse = _bomb.fuse_left                    # giữ số đếm hiện tại
		total = _bomb.fuse_total                  # giữ tổng thời gian
		_bomb.queue_free()                        # gỡ khỏi người cũ
	bomb_carrier = ball                           # người cầm mới
	_bomb = BombMarker.new()                      # tạo quả bom mới
	_bomb.fuse_left = fuse                        # số đếm
	_bomb.fuse_total = total                      # tổng thời gian
	_bomb.position = Vector2(0, -(ball.radius + BOMB_OFFSET))   # nổi cao hơn đầu bóng
	ball.add_child(_bomb)                         # gắn vào bóng để đi theo


## Mỗi khung khi bom cháy: cập nhật số đếm, chạm người kia thì chuyền bom (có thời gian chờ).
func _tick_potato(delta: float) -> void:
	_pass_cd = maxf(0.0, _pass_cd - delta)        # hết dần thời gian chờ chuyền
	if _bomb != null:                             # còn quả bom
		_bomb.fuse_left = maxf(0.0, time_left)    # số đếm hiện trên đầu
	var other := brawl.opponent_of(bomb_carrier)  # người không cầm bom
	if _pass_cd > 0.0 or bomb_carrier.dead or other.dead:   # đang chờ, hoặc ai đó đang chờ hồi sinh
		return
	var gap := bomb_carrier.global_position.distance_to(other.global_position) - bomb_carrier.radius - other.radius   # khoảng cách mép tới mép
	if gap <= POTATO_TOUCH_GAP:                   # hai người chạm nhau
		_pass_cd = potato_pass_cooldown           # bắt đầu chờ để không nảy qua nảy lại trong một lần chạm
		_set_carrier(other)                       # chuyền bom
		_bomb.fuse_left = maxf(0.0, time_left)    # giữ số đếm
		_burst(other.global_position, EVENT_COLORS["hot_potato"], 10, 80.0, 200.0, 0.4)   # tia lửa báo đã chuyền
		brawl.hud.flash("P%d HAS THE BOMB!" % other.player_id, 0.8, BrawlHud.PLAYER_COLORS[brawl.balls.find(other)])   # báo ai cầm


## Hết ngòi: bom nổ, người cầm bị giết (người kia ghi điểm), rồi sự kiện kết thúc.
func _explode_potato() -> void:
	var carrier := bomb_carrier                   # người cầm bom
	var pos := carrier.global_position            # chỗ nổ
	_burst(pos, Color("#ffb020"), 70, 160.0, 520.0, 0.9)   # chùm lửa cam lớn
	_burst(pos, Color("#f7d046"), 40, 100.0, 380.0, 0.7)   # chùm tia vàng
	var ring := Ring.new()                        # vòng sóng xung kích
	ring.position = Vector2(pos.x, minf(pos.y, brawl.level.size.y - 24.0))   # nổ trong màn hình
	brawl.level.add_child(ring)                   # thêm vào màn
	brawl.kill(carrier, "bomb")                   # CỔNG DUY NHẤT: người cầm chết, người kia ghi 1 điểm
	stop_event()                                  # bom biến mất, hoàn tác (nếu trận vừa hết thì đã được dọn rồi)


## Gỡ quả bom khỏi đầu người cầm.
func _remove_bomb() -> void:
	if _bomb != null and is_instance_valid(_bomb):   # còn quả bom
		_bomb.queue_free()                        # xoá khỏi bóng
	_bomb = null                                  # không còn
	bomb_carrier = null                           # không ai cầm


# ---- ICE FLOOR ----

## Phủ màu băng xanh nhạt lên đất (nằm dưới các quả bóng, trên hình đất của màn).
func _ice_on() -> void:
	_ice_off()                                    # không phủ hai lớp
	_ice = IceOverlay.new()                       # lớp phủ mới
	_ice.setup(brawl.level)                       # đọc bản đồ để biết ô đất nào cần phủ
	brawl.level.add_child(_ice)                   # thêm vào màn
	brawl.level.move_child(_ice, 0)               # vẽ ngay trên đất nhưng dưới bóng, gai, lò xo


## Bỏ lớp phủ băng ngay lập tức.
func _ice_off() -> void:
	if _ice != null and is_instance_valid(_ice):  # còn lớp phủ
		_ice.get_parent().remove_child(_ice)      # gỡ khỏi màn ngay (không chờ cuối khung)
		_ice.queue_free()                         # rồi xoá
	_ice = null                                   # không còn


# ---- Hiệu ứng hạt ----

## Chùm hạt một lần tại `pos` (cùng kiểu với bóng vỡ của brawl.gd): `amount` mảnh, tốc độ từ `vmin` tới `vmax`.
func _burst(pos: Vector2, color: Color, amount: int, vmin: float, vmax: float, lifetime: float) -> void:
	var p := CPUParticles2D.new()                 # bộ phát hạt
	p.one_shot = true                             # chỉ phát một lần
	p.amount = amount                             # số mảnh
	p.lifetime = lifetime                         # mỗi mảnh tồn tại chừng này giây
	p.explosiveness = 1.0                         # bắn ra tất cả cùng lúc
	p.spread = 180.0                              # tỏa ra mọi hướng
	p.initial_velocity_min = vmin                 # tốc độ nhỏ nhất
	p.initial_velocity_max = vmax                 # tốc độ lớn nhất
	p.gravity = Vector2(0, 700)                   # mảnh rơi xuống
	p.scale_amount_min = 3.0                      # mảnh nhỏ nhất
	p.scale_amount_max = 7.0                      # mảnh lớn nhất
	p.color = color                               # màu mảnh
	p.position = Vector2(pos.x, minf(pos.y, brawl.level.size.y - 24.0))   # nổ trong màn hình
	brawl.level.add_child(p)                      # thêm vào màn
	p.emitting = true                             # bắt đầu phát
	get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)   # xoá sau khi hạt tan hết


## Quả bom nổi trên đầu người cầm: hình PixelArt.BOMB, số giây còn lại trong thân bom, nhấp nháy đỏ nhanh dần khi ngòi sắp hết.
class BombMarker extends Node2D:
	const PX := 7.0                           # mỗi điểm ảnh của quả bom to 7 x 7
	var fuse_left := 8.0                      # ngòi còn bao nhiêu giây (BrawlEvents cập nhật mỗi khung)
	var fuse_total := 8.0                     # tổng thời gian ngòi (để tính nhịp nhấp nháy)
	var lit := false                          # đang ở nhịp "đỏ" của nhấp nháy
	var _phase := 0.0                         # pha nhấp nháy (mỗi 1.0 là một chu kỳ)
	var _font: Font = null                    # font pixel của dự án

	## Vẽ trên mọi thứ, nhất là trên bóng của người kia.
	func _init() -> void:
		z_index = 20                          # nằm trên các hình khác
		_font = UiTheme.main_font()           # font Peaberry

	## Mỗi khung: tăng pha nhấp nháy (càng sát giờ nổ càng nhanh, từ 2 lần tới 16 lần mỗi giây), vẽ lại.
	func _process(delta: float) -> void:
		var urgency := 1.0 - clampf(fuse_left / maxf(fuse_total, 0.01), 0.0, 1.0)   # 0 lúc đầu, 1 lúc sắp nổ
		_phase += (2.0 + 14.0 * urgency * urgency) * delta   # tốc độ nhấp nháy tăng dần
		lit = fmod(_phase, 1.0) < 0.5         # nửa chu kỳ đầu là đỏ
		queue_redraw()                        # vẽ lại

	## Quả bom, ngòi lửa, và số giây (làm tròn lên) nằm trong thân bom.
	func _draw() -> void:
		var tint := Color(3.0, 0.9, 0.8) if lit else Color.WHITE   # nhân màu: thân xám thành đỏ rực ở nhịp "đỏ"
		PixelArt.draw_centered(self, PixelArt.BOMB, Vector2.ZERO, PX, tint)   # vẽ quả bom
		var digit := str(ceili(fuse_left))    # số giây còn lại
		var col := Color("#ffd23a") if fuse_left <= 3.0 else Color.WHITE   # còn ít thì số vàng
		var at := Vector2(-25.0, PX * 1.5 + 9.0)   # thân bom nằm giữa theo chiều ngang, lệch xuống dưới tâm hình một chút
		draw_string_outline(_font, at, digit, HORIZONTAL_ALIGNMENT_CENTER, 50.0, UiTheme.FONT_MEDIUM, 6, Color.BLACK)   # viền đen cho dễ đọc
		draw_string(_font, at, digit, HORIZONTAL_ALIGNMENT_CENTER, 50.0, UiTheme.FONT_MEDIUM, col)   # số


## Lớp phủ băng: tô xanh nhạt các ô đất, vạch sáng ở mép trên, vài điểm lấp lánh nhấp nháy. Mờ dần hiện ra.
class IceOverlay extends Node2D:
	const TILE := 32.0                        # cỡ một ô (bằng Level.TILE)
	var _tiles: Array[Rect2] = []             # các ô đất cần phủ
	var _tops: Array[Rect2] = []              # mép trên (vạch sáng) của các ô lộ thiên
	var _sparkles: Array[Vector2] = []        # vị trí các điểm lấp lánh
	var _area := Rect2()                      # cả đấu trường (phủ nhẹ một lớp lạnh)
	var _time := 0.0                          # thời gian đã chạy (cho lấp lánh)

	## Đọc bản đồ của màn: ô # nào thì phủ ô đó.
	func setup(level: Level) -> void:
		_area = Rect2(Vector2.ZERO, level.size)   # vùng đấu trường
		for r in level.rows.size():           # duyệt từng hàng
			for c in level.cols:              # duyệt từng cột
				if level.char_at(r, c) != "#":   # chỉ ô đất
					continue
				var cell := Rect2(Vector2(c, r) * TILE, Vector2(TILE, TILE))   # ô này
				_tiles.append(cell)           # phủ băng
				if level.char_at(r - 1, c) != "#":   # lộ thiên phía trên
					_tops.append(Rect2(cell.position, Vector2(TILE, 4.0)))   # vạch sáng dày 4 pixel
					if (c * 7 + r * 3) % 3 == 0:   # cứ vài ô lại có một điểm lấp lánh
						_sparkles.append(cell.position + Vector2(8.0 + (c * 11) % 16, -6.0))   # nằm ngay trên mép
		modulate.a = 0.0                      # bắt đầu trong suốt
		z_index = 0                           # cùng lớp với màn

	## Hiện ra dần trong 0,3 giây.
	func _ready() -> void:
		create_tween().tween_property(self, "modulate:a", 1.0, 0.3)   # mờ dần hiện

	## Chạy đồng hồ lấp lánh.
	func _process(delta: float) -> void:
		_time += delta                        # cộng thời gian
		queue_redraw()                        # vẽ lại cho lấp lánh nhấp nháy

	## Phủ lớp lạnh, ô băng, vạch sáng, điểm lấp lánh.
	func _draw() -> void:
		draw_rect(_area, Color(0.55, 0.8, 1.0, 0.07))   # cả đấu trường hơi lạnh
		for t in _tiles:                      # từng ô đất
			draw_rect(t, Color(0.6, 0.88, 1.0, 0.45))   # băng xanh nhạt
		for t in _tops:                       # mép trên
			draw_rect(t, Color(0.92, 0.99, 1.0, 0.95))   # vạch trắng xanh sáng
		for i in _sparkles.size():            # điểm lấp lánh
			if sin(_time * 4.0 + i * 1.7) > 0.2:   # lúc sáng lúc tắt
				var p := _sparkles[i]         # vị trí
				draw_rect(Rect2(p + Vector2(-1, -5), Vector2(2, 10)), Color.WHITE)   # nét dọc của ngôi sao
				draw_rect(Rect2(p + Vector2(-5, -1), Vector2(10, 2)), Color.WHITE)   # nét ngang


## Vòng sóng xung kích khi bom nổ: nở rộng và mờ dần rồi tự xoá.
class Ring extends Node2D:
	var radius := 10.0                        # bán kính hiện tại

	## Bắt đầu nở: 0,45 giây từ 10 tới 190 pixel, mờ dần.
	func _ready() -> void:
		z_index = 15                          # nằm trên bóng
		var tw := create_tween().set_parallel(true)   # hai chuyển động cùng lúc
		tw.tween_method(_set_radius, 10.0, 190.0, 0.45)   # nở rộng
		tw.tween_property(self, "modulate:a", 0.0, 0.45)   # mờ dần
		tw.chain().tween_callback(queue_free)  # xong thì xoá

	## Đặt bán kính và vẽ lại.
	func _set_radius(r: float) -> void:
		radius = r                            # bán kính mới
		queue_redraw()                        # vẽ lại

	## Vòng cam dày với viền vàng mảnh.
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color("#ffb020"), 8.0)   # vòng cam
		draw_arc(Vector2.ZERO, radius - 6.0, 0.0, TAU, 48, Color("#fff2a0"), 3.0)   # viền sáng bên trong
