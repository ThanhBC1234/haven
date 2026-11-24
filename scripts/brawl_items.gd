class_name BrawlItems                   # tên lớp: brawl.gd tạo ra, bài test và các tính năng thêm sau (bot) dùng
extends Node                            # nút con của Brawl (brawl.items)
## Vật phẩm troll của chế độ đấu 2 người. Khi trận đang chạy, cứ mỗi `spawn_interval` giây một hộp "?" hiện ra ở chỗ đứng được
## (trên đất hoặc bệ, không phải gai / vực / lò xo / sát người chơi), tối đa `max_boxes` hộp. Chạm hộp lúc tay trống thì nhặt được
## vật phẩm bên trong (mỗi người chỉ cầm một món). Bấm phím "use" (S / mũi tên xuống) để dùng:
##   gun    - SÚNG ĐẨY: 3 phát, mỗi phát hất đối thủ thật mạnh (không gây sát thương), thừa sức đẩy ai đó xuống vực
##   banana - CHUỐI: đối thủ bị đảo trái / phải trong `banana_seconds` giây, có quả chuối quay quanh đầu
##   swap   - ĐỔI CHỖ: hai người đổi vị trí và vận tốc ngay lập tức
##   spring - BẪY LÒ XO: thả dưới chân, sau `spring_arm_seconds` giây thì "lên cò", ai chạm trước (kể cả chủ) bị bắn vọt lên cao
## Mất hết vật phẩm khi chết; hiệu ứng trên người chơi bị dọn khi họ chết và khi hồi sinh; hộp và bẫy bị dọn khi hết trận.
##
## Đảo phím chuối + sự kiện REVERSED KEYS: phím của một người đảo khi (chuối còn hiệu lực) HOẶC (đang có REVERSED KEYS).
## Nơi duy nhất đặt Ball.reverse_controls là _sync_reverse(), chạy lại mỗi khi chuối hay sự kiện bắt đầu / kết thúc,
## nên cái nào hết trước thì phím vẫn đúng theo cái còn lại (không kẹt đảo mãi, không mất đảo giữa chừng).
##
## ---- Phần công khai (bài test và các tính năng thêm sau) ----
##   enabled, spawn_interval, first_delay, max_boxes            thông số sinh hộp (bài test rút ngắn)
##   gun_knockback, banana_seconds, spring_arm_seconds, spring_life_seconds, spring_launch   thông số từng vật phẩm
##   ITEM_IDS, ITEM_NAMES, ITEM_ICONS                          mã, tên hiện và hình pixel của vật phẩm
##   held[0/1] = mã vật phẩm đang cầm của người chơi 1 / 2 ("" = tay trống);  boxes = các hộp đang có (box.item_id, box.position)
##   traps = các bẫy lò xo đang nằm trên sàn (trap.armed, trap.age)
##   give(ball, id) = đưa thẳng vật phẩm cho người chơi (thay món đang cầm);  use(ball) = dùng món đang cầm (như bấm phím use)
##   spawn_box(id := "", at := tự chọn) = tạo một hộp;  is_valid_spot(pos) = chỗ đặt hộp có hợp lệ không
##   tín hiệu: item_picked(ball, id), item_used(ball, id), trap_sprung(ball)

signal item_picked(ball: Ball, id: String)   # một người vừa nhặt vật phẩm từ hộp
signal item_used(ball: Ball, id: String)     # một người vừa dùng vật phẩm (súng: mỗi phát bắn phát một lần)
signal trap_sprung(ball: Ball)               # bẫy lò xo vừa bắn `ball` lên

const ITEM_IDS: Array[String] = ["gun", "banana", "swap", "spring"]   # mã bốn vật phẩm
const ITEM_NAMES := {                   # tên hiện trên màn hình (chỉ chữ ASCII)
	"gun": "GUN", "banana": "BANANA", "swap": "SWAP", "spring": "SPRING",
}
const ITEM_ICONS := {                   # hình pixel của từng vật phẩm (HUD và ô vật phẩm dùng)
	"gun": PixelArt.GUN, "banana": PixelArt.BANANA, "swap": PixelArt.SWAP, "spring": PixelArt.SPRING,
}
const BOX_LIFT := 28.0                  # tâm hộp nằm cao hơn mặt đất bấy nhiêu pixel (hộp lơ lửng trên một cái bóng nhỏ)
const PICK_REACH := 18.0                # chạm hộp: khoảng cách tâm bóng - tâm hộp nhỏ hơn bán kính bóng cộng số này
const SPOT_BALL_GAP := 110.0            # hộp mới không hiện gần người chơi hơn bấy nhiêu pixel
const SPOT_BOX_GAP := 200.0             # và không gần hộp khác hơn bấy nhiêu pixel
const GUN_SHOTS := 3                    # súng có bấy nhiêu phát
const GUN_KNOCKBACK := 600.0            # lực hất của mỗi viên đạn (pixel/giây; cộng thêm cú nảy lên 150 của đạn)
const SPRING_LAUNCH := 1250.0           # bẫy lò xo bắn bóng lên với vận tốc này (lò xo thường của đấu trường là 920)
const TRAP_HALF_WIDTH := 20.0           # nửa bề rộng bẫy lò xo (hình rộng 40)
const TRAP_HEIGHT := 30.0               # chiều cao vùng chạm của bẫy
const GROUND_REACH := 900.0             # thả bẫy: tìm mặt đất ở dưới chân tối đa bấy nhiêu pixel

var enabled := true                     # false = không sinh hộp mới (hộp / bẫy đang có vẫn dùng được)
var spawn_interval := 6.0               # cứ bấy nhiêu giây sinh một hộp
var first_delay := 3.0                  # hộp đầu tiên hiện sau bấy nhiêu giây kể từ lúc trận bắt đầu
var max_boxes := 2                      # trên sân tối đa bấy nhiêu hộp (đủ thì tạm dừng đếm giờ)
var gun_knockback := GUN_KNOCKBACK      # lực hất của đạn súng
var banana_seconds := 3.0               # đảo phím bao lâu
var spring_arm_seconds := 0.5           # bẫy lò xo thả xuống bao lâu thì lên cò
var spring_life_seconds := 12.0         # bẫy lò xo tự biến mất sau bấy nhiêu giây kể từ lúc thả
var spring_launch := SPRING_LAUNCH      # vận tốc bắn lên của bẫy lò xo

var held: Array = ["", ""]              # mã vật phẩm đang cầm của người chơi 1 và 2 ("" = tay trống)
var boxes: Array = []                   # các hộp đang nằm trên sân (ItemBox)
var traps: Array = []                   # các bẫy lò xo đang nằm trên sàn (SpringTrap)
var brawl: Brawl                        # cảnh đấu chứa nút này

var _next_in := 0.0                     # còn bao lâu nữa sinh hộp kế tiếp
var _last_id := ""                      # vật phẩm của hộp sinh gần nhất (để hộp kế không trùng)
var _banana_left: Array[float] = [0.0, 0.0]   # chuối còn hiệu lực bao lâu trên người chơi 1 và 2 (0 = không bị)
var _banana_marks: Array = [null, null]       # quả chuối quay quanh đầu nạn nhân (BananaMark)


## Nối vào cảnh đấu cha: nghe bắt đầu / hết trận, ghi điểm, hồi sinh, sự kiện, và phím "use" của hai bóng.
func _ready() -> void:
	brawl = get_parent() as Brawl                 # nút cha là Brawl
	if brawl == null:                             # đặt sai chỗ
		push_error("BrawlItems must be a child of Brawl")   # báo lỗi dùng sai
		return
	brawl.match_started.connect(_on_match_started)   # trận bắt đầu: tính giờ hộp đầu tiên
	brawl.match_over.connect(_on_match_over)      # hết trận: dọn sạch
	brawl.point_scored.connect(_on_point_scored)  # có người chết: mất vật phẩm, hết hiệu ứng
	brawl.player_respawned.connect(_on_player_respawned)   # hồi sinh: dọn lại cho chắc
	if brawl.events != null:                      # sự kiện REVERSED KEYS đổi phím cùng chỗ với chuối
		brawl.events.event_started.connect(_on_event_changed)   # sự kiện bắt đầu: tính lại phím
		brawl.events.event_ended.connect(_on_event_changed)     # sự kiện kết thúc: tính lại phím
	for ball in brawl.balls:                      # hai bóng
		ball.use_pressed.connect(use.bind(ball))  # bấm phím use thì dùng vật phẩm
		ball.ammo_changed.connect(_on_ammo_changed.bind(ball))   # số đạn đổi thì cập nhật ô vật phẩm
	_next_in = first_delay                        # phòng khi trận đã bắt đầu rồi


# ---- Vòng lặp ----

## 60 lần mỗi giây khi trận đang chạy: sinh hộp, nhặt hộp, bẫy lò xo, đếm giờ chuối.
func _physics_process(delta: float) -> void:
	if brawl == null or not brawl.match_running:  # đang giới thiệu hoặc đã hết trận: không có vật phẩm
		return
	if enabled:                                   # còn sinh hộp
		_tick_spawn(delta)                        # đếm giờ, sinh hộp
	_tick_boxes()                                 # ai chạm hộp thì nhặt
	_tick_traps(delta)                            # bẫy lò xo: lên cò, bắn, hết hạn
	_tick_banana(delta)                           # đếm ngược chuối


## Đếm giờ sinh hộp: đủ `max_boxes` thì tạm dừng; hết giờ thì sinh một hộp (không có chỗ thì thử lại sau 1 giây).
func _tick_spawn(delta: float) -> void:
	if boxes.size() >= max_boxes:                 # sân đã đủ hộp
		return
	_next_in -= delta                             # đếm ngược
	if _next_in > 0.0:                            # chưa tới giờ
		return
	_next_in = spawn_interval                     # hẹn hộp kế tiếp
	if spawn_box() == null:                       # không tìm được chỗ
		_next_in = 1.0                            # thử lại sớm


## Mỗi khung: hộp nằm đè lên gai chống câu giờ thì bỏ; người tay trống chạm hộp thì nhặt.
func _tick_boxes() -> void:
	for box: ItemBox in boxes.duplicate():        # duyệt bản sao vì _pick sẽ xoá phần tử
		if not is_instance_valid(box):            # hộp đã bị xoá
			boxes.erase(box)                      # bỏ khỏi danh sách
			continue
		if _on_stall_spike(box.position):         # gai chống câu giờ vừa mọc đúng chỗ hộp
			_remove_box(box)                      # hộp biến mất (không để hộp nằm trên gai)
			continue
		for ball in brawl.balls:                  # hai người chơi
			if ball.dead or held[brawl.balls.find(ball)] != "":   # đang chết hoặc tay không trống
				continue
			if ball.global_position.distance_to(box.position) <= ball.radius + PICK_REACH:   # chạm hộp
				_pick(box, ball)                  # nhặt
				break                             # hộp đã có chủ


## `ball` nhặt `box`: hộp biến mất, vật phẩm vào tay.
func _pick(box: ItemBox, ball: Ball) -> void:
	var id := box.item_id                         # vật phẩm trong hộp
	_remove_box(box)                              # hộp biến mất
	give(ball, id)                                # vào tay
	item_picked.emit(ball, id)                    # báo cho các tính năng khác


# ---- Công khai: sinh hộp, đưa và dùng vật phẩm ----

## Sinh một hộp chứa `id` ("" = bốc ngẫu nhiên, không trùng hộp trước) ở vị trí `at` (mặc định: tự chọn chỗ hợp lệ).
## Chỉ khi trận đang chạy. Trả về hộp, hoặc null nếu không được (hết trận, mã lạ, không tìm được chỗ).
## Gọi trực tiếp thì không bị giới hạn `max_boxes` (chỉ bộ đếm giờ tự sinh mới tôn trọng giới hạn đó).
func spawn_box(id := "", at := Vector2.INF) -> ItemBox:
	if brawl == null or not brawl.match_running:  # đang giới thiệu / đã hết trận
		return null                               # không sinh
	if id == "":                                  # chưa chọn
		id = _random_id()                         # bốc ngẫu nhiên
	if not ITEM_IDS.has(id):                      # mã lạ
		return null
	var pos := at if at.is_finite() else _find_spot()   # chỗ đặt hộp
	if not pos.is_finite():                       # không có chỗ nào
		return null
	var box := ItemBox.new()                      # hộp mới
	box.item_id = id                              # vật phẩm bên trong
	box.position = pos                            # chỗ đặt
	brawl.level.add_child(box)                    # thêm vào màn
	boxes.append(box)                             # lưu danh sách công khai
	_last_id = id                                 # nhớ để hộp sau không trùng
	return box


## Đưa vật phẩm `id` cho `ball` ngay (thay món đang cầm nếu có). Chỉ khi trận đang chạy.
func give(ball: Ball, id: String) -> void:
	var i := brawl.balls.find(ball) if brawl != null else -1   # số thứ tự người chơi
	if i < 0 or not ITEM_IDS.has(id) or not brawl.match_running:   # không phải người chơi, mã lạ, hoặc không đang đấu
		return
	_drop_gun(ball)                               # thay món: nếu đang cầm súng thì bỏ đạn
	held[i] = id                                  # vào tay
	if id == "gun":                               # súng: nạp đạn đẩy
		ball.add_ammo(GUN_SHOTS)                  # 3 phát
		ball.bullet_knockback = gun_knockback     # đạn hất chứ không gây sát thương
	_refresh_hud(i)                               # ô vật phẩm trên HUD


## Dùng vật phẩm đang cầm của `ball` (giống người chơi bấm phím use). Không làm gì nếu tay trống, bóng đang chết,
## hoặc không dùng được lúc này (đối thủ đang chờ hồi sinh với CHUỐI / ĐỔI CHỖ, không có đất dưới chân với BẪY, súng đang hồi giữa hai phát):
## khi đó vật phẩm vẫn còn trong tay.
func use(ball: Ball) -> void:
	var i := brawl.balls.find(ball) if brawl != null else -1   # số thứ tự người chơi
	if i < 0 or not brawl.match_running or ball.dead:   # không đang đấu hoặc bóng đang chết
		return
	var id: String = held[i]                      # món đang cầm
	var used := false                             # đã dùng được chưa
	match id:                                     # theo vật phẩm
		"gun":
			used = _use_gun(ball, i)              # bắn một phát
		"banana":
			used = _use_banana(ball, i)           # ném chuối cho đối thủ
		"swap":
			used = _use_swap(ball, i)             # đổi chỗ
		"spring":
			used = _use_spring(ball, i)           # thả bẫy
	if used:                                      # có tác dụng
		item_used.emit(ball, id)                  # báo cho các tính năng khác


## Súng: bắn một phát (Ball.shoot lo hướng bắn và thời gian chờ giữa hai phát). Hết đạn thì tay trống.
func _use_gun(ball: Ball, i: int) -> bool:
	var before := ball.ammo                       # số đạn trước khi bắn
	ball.shoot()                                  # bắn (bị chặn nếu đang chờ giữa hai phát)
	if ball.ammo >= before:                       # không bắn được
		return false
	if ball.ammo <= 0:                            # hết đạn
		_clear_hand(i)                            # tay trống
	else:
		_refresh_hud(i)                           # số đạn còn lại
	return true


## Chuối: đối thủ bị đảo phím `banana_seconds` giây.
func _use_banana(ball: Ball, i: int) -> bool:
	var target := brawl.opponent_of(ball)         # nạn nhân
	if target.dead:                               # đang chờ hồi sinh: ném vô ích
		return false
	_clear_hand(i)                                # chuối đã ném
	_start_banana(target)                         # đảo phím + quả chuối quay quanh đầu
	brawl.hud.flash("BANANA! P%d IS DIZZY!" % target.player_id, 1.0, BrawlHud.PLAYER_COLORS[i])   # báo cho cả hai thấy
	return true


## Đổi chỗ: hai người đổi vị trí và vận tốc (dùng chung với SWAP! của sự kiện, nên không đụng hàng với nó).
func _use_swap(ball: Ball, i: int) -> bool:
	if brawl.opponent_of(ball).dead or brawl.events == null:   # đối thủ đang chờ hồi sinh: không có ai để đổi
		return false
	if not brawl.events.swap_players():           # đổi chỗ
		return false
	_clear_hand(i)                                # đã dùng
	brawl.hud.flash("P%d SWAPPED PLACES!" % ball.player_id, 0.8, BrawlHud.PLAYER_COLORS[i])   # báo
	return true


## Bẫy lò xo: thả ngay dưới chân (mặt đất bên dưới; đang ở trên vực không có đất thì không thả được).
func _use_spring(ball: Ball, i: int) -> bool:
	var feet := _ground_below(ball)               # mặt đất dưới chân
	if not feet.is_finite():                      # không có đất
		return false
	_clear_hand(i)                                # đã thả
	var trap := SpringTrap.new()                  # bẫy mới
	trap.position = feet                          # đặt trên mặt đất
	trap.owner_ball = ball                        # người thả (để hình nhớ màu / bài test)
	brawl.level.add_child(trap)                   # thêm vào màn
	traps.append(trap)                            # lưu danh sách công khai
	return true


# ---- Chuối ----

## Bắt đầu (hoặc làm mới) chuối trên `victim`: đảo phím và gắn quả chuối quay quanh đầu.
func _start_banana(victim: Ball) -> void:
	var j := brawl.balls.find(victim)             # số thứ tự nạn nhân
	_banana_left[j] = banana_seconds              # đếm ngược từ đầu
	if _banana_marks[j] == null or not is_instance_valid(_banana_marks[j]):   # chưa có quả chuối nào
		var mark := BananaMark.new()              # quả chuối quay quanh đầu
		mark.ball = victim                        # bóng nó đi theo
		victim.add_child(mark)                    # gắn vào bóng
		_banana_marks[j] = mark                   # nhớ để gỡ
	_banana_marks[j].time_left = banana_seconds   # cho hình biết còn bao lâu (nhấp nháy khi sắp hết)
	_sync_reverse(victim)                         # đảo phím


## Hết chuối trên `ball` (hết giờ, chết, hồi sinh, hết trận): gỡ quả chuối và trả phím theo các nguồn đảo còn lại.
func _end_banana(ball: Ball) -> void:
	var j := brawl.balls.find(ball)               # số thứ tự
	_banana_left[j] = 0.0                         # hết chuối
	if _banana_marks[j] != null:                  # còn quả chuối quay quanh đầu
		if is_instance_valid(_banana_marks[j]):   # còn tồn tại
			ball.remove_child(_banana_marks[j])   # gỡ ngay khỏi bóng (không chờ cuối khung)
			_banana_marks[j].queue_free()         # rồi xoá
		_banana_marks[j] = null                   # không còn
	_sync_reverse(ball)                           # trả phím (vẫn đảo nếu REVERSED KEYS còn chạy)


## Mỗi khung: trừ giờ chuối của từng người; hết giờ thì gỡ.
func _tick_banana(delta: float) -> void:
	for j in 2:                                   # hai người chơi
		if _banana_left[j] <= 0.0:                # không bị chuối
			continue
		_banana_left[j] -= delta                  # đếm ngược
		if _banana_marks[j] != null and is_instance_valid(_banana_marks[j]):   # còn quả chuối
			_banana_marks[j].time_left = _banana_left[j]   # cập nhật cho hình
		if _banana_left[j] <= 0.0:                # hết giờ
			_end_banana(brawl.balls[j])           # gỡ chuối, trả phím


## NƠI DUY NHẤT đặt Ball.reverse_controls của bóng: đảo khi chuối còn hiệu lực HOẶC sự kiện REVERSED KEYS đang chạy.
## (Chỉ đặt khi khác giá trị cần có, vì đặt lại sẽ xoá lực đang tích.)
func _sync_reverse(ball: Ball) -> void:
	var j := brawl.balls.find(ball)               # số thứ tự
	var banana: bool = _banana_left[j] > 0.0      # đang bị chuối
	var event: bool = brawl.events != null and brawl.events.active_event == "reversed_keys"   # đang có REVERSED KEYS
	var want := banana or event                   # cần đảo phím không
	if ball.reverse_controls != want:             # đang khác
		ball.reverse_controls = want              # đặt đúng


## Sự kiện bắt đầu / kết thúc: tính lại phím của cả hai (sự kiện tự khôi phục giá trị nó nhớ, có thể sai nếu chuối chen giữa).
func _on_event_changed(_id: String) -> void:
	for ball in brawl.balls:                      # hai người chơi
		_sync_reverse(ball)                       # đặt lại cho đúng


# ---- Dọn dẹp ----

## Trận bắt đầu (hết phần giới thiệu): dọn mọi thứ còn sót và tính giờ hộp đầu tiên.
func _on_match_started() -> void:
	_clear_all()                                  # chắc chắn sạch sẽ
	_next_in = first_delay                        # hộp đầu tiên sau chừng này giây


## Hết trận: bỏ hộp, bẫy, vật phẩm đang cầm và hiệu ứng chuối.
func _on_match_over(_winner: Ball) -> void:
	_clear_all()                                  # sạch hoàn toàn


## Có người chết: mất vật phẩm đang cầm, hết chuối. (Đòn ném chuối trước đó lên người kia vẫn chạy nốt.)
func _on_point_scored(_scorer: Ball, victim: Ball, _cause: String) -> void:
	_clear_player(victim)                         # tay trống, hết hiệu ứng


## Hồi sinh: dọn lại một lần nữa cho chắc (không có vật phẩm / hiệu ứng nào đi qua cái chết).
func _on_player_respawned(ball: Ball) -> void:
	_clear_player(ball)                           # tay trống, hết hiệu ứng


## Số đạn của `ball` đổi: cập nhật số phát ở ô vật phẩm (chỉ khi đang cầm súng).
func _on_ammo_changed(ammo: int, ball: Ball) -> void:
	var i := brawl.balls.find(ball)               # số thứ tự
	if i >= 0 and held[i] == "gun":               # đang cầm súng
		brawl.hud.set_item(ball.player_id, "gun", ammo)   # số phát mới


## Xoá mọi hộp, mọi bẫy, và dọn vật phẩm + hiệu ứng của cả hai người chơi.
func _clear_all() -> void:
	for box in boxes.duplicate():                 # từng hộp
		_remove_box(box, false)                   # xoá (không hiệu ứng)
	for trap in traps.duplicate():                # từng bẫy
		_remove_trap(trap, false)                 # xoá (không hiệu ứng)
	for ball in brawl.balls:                      # hai người chơi
		_clear_player(ball)                       # tay trống, hết hiệu ứng


## Tay trống, bỏ đạn súng, hết chuối của `ball`.
func _clear_player(ball: Ball) -> void:
	var i := brawl.balls.find(ball)               # số thứ tự
	_clear_hand(i)                                # tay trống (và bỏ đạn súng)
	_end_banana(ball)                             # hết chuối, trả phím


## Tay trống của người chơi thứ `i`; đang cầm súng thì bỏ nốt đạn.
func _clear_hand(i: int) -> void:
	if held[i] == "gun":                          # đang cầm súng
		_drop_gun(brawl.balls[i])                 # bỏ đạn
	held[i] = ""                                  # tay trống
	_refresh_hud(i)                               # ô vật phẩm trống


## Bỏ đạn súng của `ball` (về trạng thái bình thường: không đạn, đạn không hất).
func _drop_gun(ball: Ball) -> void:
	if ball.bullet_knockback > 0.0 or held[brawl.balls.find(ball)] == "gun":   # đang ở chế độ súng đẩy
		ball.ammo = 0                             # hết đạn
		ball.bullet_knockback = 0.0               # đạn thường


## Cập nhật ô vật phẩm trên HUD của người chơi thứ `i`.
func _refresh_hud(i: int) -> void:
	var ball := brawl.balls[i]                    # bóng của người chơi này
	brawl.hud.set_item(ball.player_id, held[i], ball.ammo if held[i] == "gun" else 0)   # hình + số đạn


# ---- Hộp ----

## Chỗ đặt hộp `pos` (tâm hộp) có hợp lệ không: chân hộp (pos + BOX_LIFT) đúng mặt trên của một ô đất, hai ô phía trên trống,
## ô đứng và hai ô bên cạnh không có gai / lò xo, không nằm trên gai chống câu giờ. (Chỗ đang đứng của người chơi không xét ở đây.)
func is_valid_spot(pos: Vector2) -> bool:
	var level := brawl.level                      # màn đang chơi
	var floor_y := pos.y + BOX_LIFT               # mặt đất dưới hộp
	var r := roundi(floor_y / Level.TILE)         # hàng của ô đất ngay dưới hộp
	if absf(floor_y - r * Level.TILE) > 1.0:      # không đúng mặt trên một ô
		return false
	var c := floori(pos.x / Level.TILE)           # cột
	if level.char_at(r, c) != "#":                # dưới chân không phải đất (vực, hoặc ô trống)
		return false
	if level.char_at(r - 1, c) != "." or level.char_at(r - 2, c) != ".":   # phía trên không trống (đất, chỗ xuất phát, gai treo...)
		return false
	for dc in [-1, 0, 1]:                         # ô đứng và hai ô bên cạnh
		var ch := level.char_at(r - 1, c + dc)    # ký tự ở hàng mặt đất
		if ch == "^" or ch == "T":                # gai hoặc lò xo
			return false
	return not _on_stall_spike(Vector2(pos.x, floor_y))   # gai chống câu giờ đã mọc ở đó


## Chọn ngẫu nhiên một chỗ hợp lệ, xa người chơi và xa hộp khác; không có thì Vector2.INF.
func _find_spot() -> Vector2:
	var level := brawl.level                      # màn đang chơi
	var spots: Array[Vector2] = []                # các chỗ đủ điều kiện
	for r in range(2, level.rows.size()):         # từng hàng đất (hàng 0, 1 không thể có chỗ trống phía trên)
		for c in range(1, level.cols - 1):        # từng cột (bỏ hai tường)
			var pos := Vector2((c + 0.5) * Level.TILE, r * Level.TILE - BOX_LIFT)   # tâm hộp nếu đặt ở đây
			if not is_valid_spot(pos):            # không hợp lệ
				continue
			var far := true                       # đủ xa mọi người và mọi hộp không
			for ball in brawl.balls:              # từng người chơi
				far = far and ball.global_position.distance_to(pos) >= SPOT_BALL_GAP
			for box in boxes:                     # từng hộp đang có
				far = far and box.position.distance_to(pos) >= SPOT_BOX_GAP
			if far:                               # đạt
				spots.append(pos)                 # thêm vào danh sách
	if spots.is_empty():                          # không có chỗ nào
		return Vector2.INF
	return spots[randi() % spots.size()]          # bốc ngẫu nhiên


## Bốc vật phẩm cho hộp mới: ngẫu nhiên, không trùng hộp sinh ngay trước.
func _random_id() -> String:
	var options: Array[String] = []               # các vật phẩm được phép
	for id in ITEM_IDS:                           # bốn vật phẩm
		if id != _last_id:                        # bỏ cái vừa rồi
			options.append(id)                    # còn lại thì được bốc
	return options[randi() % options.size()]      # bốc ngẫu nhiên


## Điểm `pos` (ở mặt đất) có gai chống câu giờ không.
func _on_stall_spike(pos: Vector2) -> bool:
	for s in brawl.stall_spikes:                  # các gai chống câu giờ đang có
		if is_instance_valid(s) and absf(s.position.x - pos.x) < 36.0 and absf(s.position.y - pos.y) < 40.0:   # cùng ô
			return true
	return false


## Xoá một hộp (`fx`: có chùm tia lúc biến mất không).
func _remove_box(box: ItemBox, fx := true) -> void:
	boxes.erase(box)                              # bỏ khỏi danh sách công khai
	if not is_instance_valid(box):                # đã bị xoá
		return
	if fx:                                        # nhặt xong thì có tia sáng
		_burst(box.position, Color("#f7d046"), 12, 60.0, 200.0, 0.4)
	box.get_parent().remove_child(box)            # gỡ ngay khỏi màn (bài test đếm node con)
	box.queue_free()                              # rồi xoá


# ---- Bẫy lò xo ----

## Mặt đất ngay dưới `ball` (bắn tia xuống lớp "world"); không có đất (đang ở trên vực) thì Vector2.INF.
func _ground_below(ball: Ball) -> Vector2:
	var from := ball.global_position              # từ tâm bóng
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, GROUND_REACH), 1)   # tia đi xuống, chỉ thấy lớp 1 (đất, tường)
	var hit := brawl.get_world_2d().direct_space_state.intersect_ray(query)   # tia chạm gì
	if hit.is_empty():                            # không chạm gì: dưới là vực
		return Vector2.INF
	return hit["position"]                        # điểm chạm = mặt trên của đất


## Mỗi khung: tăng tuổi bẫy, lên cò sau `spring_arm_seconds`, hết hạn sau `spring_life_seconds`, bắn người đầu tiên chạm vào.
func _tick_traps(delta: float) -> void:
	for trap: SpringTrap in traps.duplicate():    # duyệt bản sao vì _remove_trap xoá phần tử
		if not is_instance_valid(trap):           # bẫy đã bị xoá
			traps.erase(trap)                     # bỏ khỏi danh sách
			continue
		trap.age += delta                         # già thêm
		trap.armed = trap.age >= spring_arm_seconds   # đã lên cò chưa
		trap.life_left = spring_life_seconds - trap.age   # còn bao lâu (để hình nhấp nháy khi sắp hết)
		if trap.life_left <= 0.0:                 # hết hạn
			_remove_trap(trap)                    # tự biến mất
			continue
		if not trap.armed:                        # chưa lên cò: vô hại
			continue
		for ball in brawl.balls:                  # ai chạm trước (kể cả chủ)
			if ball.dead or not _trap_touches(trap, ball):   # chết hoặc không chạm
				continue
			ball.bounce_up(spring_launch)         # bắn vọt lên (Ball xử lý ở khung vật lý tới)
			_burst(trap.position + Vector2(0.0, -16.0), Color("#e8455a"), 14, 80.0, 260.0, 0.45)   # tia đỏ
			_remove_trap(trap, false)             # bẫy dùng một lần
			trap_sprung.emit(ball)                # báo
			break                                 # chỉ bắn một người


## Quả bóng `ball` có chạm vùng của bẫy không (hình tròn của bóng với hình chữ nhật của bẫy).
func _trap_touches(trap: SpringTrap, ball: Ball) -> bool:
	var area := Rect2(trap.position + Vector2(-TRAP_HALF_WIDTH, -TRAP_HEIGHT), Vector2(TRAP_HALF_WIDTH * 2.0, TRAP_HEIGHT))   # vùng chạm của bẫy
	var c := ball.global_position                 # tâm bóng
	var nearest := Vector2(clampf(c.x, area.position.x, area.end.x), clampf(c.y, area.position.y, area.end.y))   # điểm của hình chữ nhật gần tâm bóng nhất
	return c.distance_to(nearest) <= ball.radius  # tâm cách hình chữ nhật không quá bán kính


## Xoá một bẫy (`fx`: có chùm khói xám lúc hết hạn không).
func _remove_trap(trap: SpringTrap, fx := true) -> void:
	traps.erase(trap)                             # bỏ khỏi danh sách công khai
	if not is_instance_valid(trap):               # đã bị xoá
		return
	if fx:                                        # hết hạn: bụi xám
		_burst(trap.position + Vector2(0.0, -12.0), Color("#b8c0c8"), 8, 40.0, 120.0, 0.35)
	trap.get_parent().remove_child(trap)          # gỡ ngay khỏi màn
	trap.queue_free()                             # rồi xoá


# ---- Hiệu ứng hạt ----

## Chùm hạt một lần tại `pos` (cùng kiểu với BrawlEvents._burst): `amount` mảnh, tốc độ từ `vmin` tới `vmax`.
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
	p.scale_amount_max = 6.0                      # mảnh lớn nhất
	p.color = color                               # màu mảnh
	p.position = pos                              # chỗ phát
	brawl.level.add_child(p)                      # thêm vào màn
	p.emitting = true                             # bắt đầu phát
	get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)   # xoá sau khi hạt tan hết


## Hộp "?" nằm trên sân: khối vàng nhấp nhô lơ lửng trên một cái bóng nhỏ, quầng sáng nhấp nháy. Hiện ra với hiệu ứng nảy.
class ItemBox extends Node2D:
	const PX := 4.0                           # mỗi điểm ảnh của hộp to 4 x 4 (hộp rộng 44)
	var item_id := ""                         # vật phẩm bên trong (BrawlItems đặt; không hiện ra cho người chơi, hộp nào cũng là "?")
	var _time := 0.0                          # đồng hồ nhấp nhô

	## Vẽ trên đất và gai, dưới bóng; hiện ra từ không có gì với hiệu ứng nảy.
	func _ready() -> void:
		z_index = 5                           # nằm trên các hình của màn
		scale = Vector2.ZERO                  # bắt đầu từ không
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # nảy ra

	## Chạy đồng hồ, vẽ lại.
	func _process(delta: float) -> void:
		_time += delta                        # cộng thời gian
		queue_redraw()                        # vẽ lại cho nhấp nhô

	## Bóng dưới đất, quầng sáng, khối "?".
	func _draw() -> void:
		var bob := sin(_time * 3.0) * 3.0     # lên xuống 3 pixel
		draw_rect(Rect2(Vector2(-17.0, BrawlItems.BOX_LIFT - 2.0), Vector2(34.0, 4.0)), Color(0, 0, 0, 0.35))   # cái bóng nằm trên mặt đất
		draw_circle(Vector2(0.0, bob), 31.0, Color(1.0, 0.85, 0.3, 0.16 + 0.1 * sin(_time * 5.0)))   # quầng sáng nhấp nháy
		PixelArt.draw_centered(self, PixelArt.ITEM_BOX, Vector2(0.0, bob), PX)   # khối "?"


## Bẫy lò xo trên sàn: hình PixelArt.SPRING (to hơn lò xo thường của đấu trường). Chưa lên cò: mờ và nhấp nháy nhanh;
## đã lên cò: rõ nét, nhún nhảy kèm mũi tên chỉ lên; 3 giây cuối trước khi hết hạn: nhấp nháy.
class SpringTrap extends Node2D:
	const PX := 4.0                           # mỗi điểm ảnh to 4 x 4 (bẫy rộng 40, cao 32)
	var armed := false                        # đã lên cò chưa (BrawlItems cập nhật)
	var age := 0.0                            # đã nằm trên sàn bao lâu (giây)
	var life_left := 12.0                     # còn bao lâu thì tự biến mất
	var owner_ball: Ball = null               # người đã thả bẫy
	var _time := 0.0                          # đồng hồ hoạt ảnh

	## Vẽ trên đất, dưới bóng.
	func _init() -> void:
		z_index = 4                           # nằm trên các hình của màn

	## Chạy đồng hồ, vẽ lại.
	func _process(delta: float) -> void:
		_time += delta                        # cộng thời gian
		queue_redraw()                        # vẽ lại cho hoạt ảnh

	## Hình lò xo (gốc ở mặt đất, giữa bẫy) và mũi tên lên cò.
	func _draw() -> void:
		var tint := Color.WHITE               # màu nhân thêm
		var lift := 0.0                       # nhún lên xuống
		if not armed:                         # chưa lên cò
			tint = Color(0.8, 0.9, 1.0, 0.4 + 0.25 * sin(_time * 22.0))   # mờ và nhấp nháy nhanh
		else:
			lift = absf(sin(_time * 9.0)) * 3.0   # nhún nhảy
			if life_left < 3.0 and int(_time * 8.0) % 2 == 0:   # sắp hết hạn: nhấp nháy mờ
				tint = Color(1, 1, 1, 0.35)
		PixelArt.draw(self, PixelArt.SPRING, Vector2(-20.0, -32.0 - lift), PX, tint)   # lò xo, đáy chạm đất
		if armed:                             # mũi tên chỉ lên báo "bước vào là bay"
			var y := -44.0 - lift - 3.0 * sin(_time * 6.0)   # độ cao mũi tên
			draw_polyline(PackedVector2Array([Vector2(-8, y), Vector2(0, y - 8), Vector2(8, y)]), Color("#fff2a0"), 3.0)


## Chuối quay quanh đầu nạn nhân: ba quả chuối bay vòng tròn (hình elip) quanh đầu, nhấp nháy khi sắp hết hiệu lực.
class BananaMark extends Node2D:
	var ball: Ball = null                     # bóng bị chuối
	var time_left := 3.0                      # còn bao lâu hết đảo phím (BrawlItems cập nhật)
	var _time := 0.0                          # đồng hồ quay

	## Vẽ trên bóng.
	func _init() -> void:
		z_index = 12                          # nằm trên bóng

	## Mỗi khung: quay, đi theo đầu (đầu cao hơn khi bóng to), ẩn khi bóng đang chết.
	func _process(delta: float) -> void:
		_time += delta                        # cộng thời gian
		visible = not ball.dead               # bóng đang dẹt / chờ hồi sinh thì không hiện
		position = Vector2(0.0, -36.0 * ball.size_factor)   # ngang tầm đầu
		queue_redraw()                        # vẽ lại

	## Ba quả chuối xếp đều trên vòng elip đang quay.
	func _draw() -> void:
		if time_left < 0.9 and int(_time * 10.0) % 2 == 0:   # sắp hết: nhấp nháy
			return
		var f := ball.size_factor               # hệ số cỡ bóng
		for k in 3:                             # ba quả chuối
			var a := _time * 6.0 + k * TAU / 3.0   # góc của quả này
			PixelArt.draw_centered(self, PixelArt.BANANA, Vector2(cos(a) * 38.0 * f, sin(a) * 10.0 * f), 3.0)   # vẽ quả chuối
