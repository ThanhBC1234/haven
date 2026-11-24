class_name BrawlBot                     # tên lớp: brawl.gd tạo ra khi chơi với máy, bài test cũng tạo riêng
extends Node                            # nút con của Brawl (brawl.bot)
## Máy (bot) chơi Bounce Brawl thay một người. Nó điều khiển quả bóng GIỐNG HỆT người: chỉ bấm / nhả phím của người chơi đó
## (p2_left, p2_right, p2_jump, p2_use) bằng Input.action_press / action_release. Không dịch chuyển, không đặt vận tốc.
## Nó biết bản đồ chữ (đất, vực, gai) và các số đo cú nhảy, giống một người chơi giỏi nhớ màn, nên chạy thử trong đầu từng cú nhảy:
## mô phỏng đường bay (trọng lực, đất, gai, vực, đối thủ) rồi chấm điểm. Chọn cú tốt nhất cộng chút ngẫu nhiên.
##
## Trạng thái chiến thuật `mode` (đổi mỗi lần suy nghĩ):
##   chase     - đuổi đối thủ, tìm cách đáp xuống đầu nó (dẫm)
##   get_box   - tay trống và có hộp "?" gần: đi nhặt
##   flee      - chạy khỏi đối thủ (nó đang cầm bom HOT POTATO, hoặc vừa thả bẫy lò xo để nhử)
##   pass_bomb - mình cầm bom: lao vào đối thủ để chuyền
##   dodge     - đối thủ sắp đáp xuống đầu mình: nhảy né
## Giai đoạn thực hiện `phase`:
##   idle (chờ tới lượt nghĩ) -> think (chấm các cú nhảy, vài cú mỗi khung) -> prep (chờ tới lúc bắt đầu giữ phím)
##   -> charge (giữ A/D để tích lực) -> launch (đã bấm nhảy, chờ bóng bật lên) -> idle ...;  aim (quay mặt để bắn súng)
## Nhược điểm cố ý (cho người thắng được): phản ứng trễ, lệch lực nhảy, đôi khi nhảy bừa, bị đảo phím thì loay hoay một lúc mới nhận ra.
##
## ---- Phần công khai ----
##   skill (0..1)       độ giỏi: 0 = chậm và vụng, 1 = nhanh và chuẩn. Mặc định 0.6.
##   player_index       0 = điều khiển bóng người chơi 1, 1 = người chơi 2 (mặc định; để hai bot đấu nhau trong bài test)
##   enabled            false = nằm im, nhả hết phím
##   mode, phase        xem trên;  hops = số cú nhảy đã làm;  items_used = số vật phẩm đã dùng;  thoughts = số lần suy nghĩ
##   held_actions()     các phím đang giữ;  release_all() = nhả hết phím

const DT := 1.0 / 60.0                  # bước mô phỏng (giây): bằng một khung vật lý (bước thô hơn thì bóng "xuyên" qua góc bệ mà bóng thật bị chặn)
const FRAME := 1.0 / 60.0               # một khung vật lý (giây)
const TILE := 32.0                      # cỡ ô (bằng Level.TILE)
const CANDIDATE_CHARGES := [0.0, 0.12, 0.25, 0.38, 0.5, 0.62, 0.75, 0.88, 1.0]   # các độ mạnh cú nhảy sẽ thử (mỗi hướng)
const EVALS_PER_FRAME := 4              # mỗi khung chấm bấy nhiêu cú nhảy (dàn đều ra nhiều khung cho đỡ giật)
const MAX_SIM_STEPS := 140              # mô phỏng tối đa bấy nhiêu bước (hơn 2,3 giây)
const WAIT_HORIZON := 0.9               # cú "đứng yên": nhìn trước bấy nhiêu giây
const LAND_LEAD := 0.06                 # bấm nhảy sớm hơn lúc chạm đất bấy nhiêu giây (bóng đang nảy lên xuống)
const SPIKE_H := 10.0                   # vùng chạm của gai (scenes/objects/spikes.tscn): rộng 26, cao 10, nằm sát mặt ô
const SPIKE_W := 26.0
const SPIKE_PAD := 2.0                  # bóng cách vùng chạm của gai dưới bấy nhiêu pixel cũng coi là dính (bóng thật dính gai sớm hơn tính toán một chút)
const FALL_Y := 660.0                   # tâm bóng thấp hơn mức này là đã rơi xuống vực
const CEILING_Y := -16.0                # trần vô hình (bằng Brawl.CEILING_Y)
const ICE_SLIDE := 0.8                  # trên băng: sau khi chạm đất bóng còn trượt vx x hệ số này (giây)
const TRAP_SIZE := Vector2(40.0, 30.0)  # vùng chạm của bẫy lò xo (bằng BrawlItems.TRAP_HALF_WIDTH x 2, TRAP_HEIGHT)
const GRAPH_CHARGES := [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]   # các độ mạnh thử khi dựng đồ thị đường đi (mỗi hướng)
const GRAPH_NODES_PER_FRAME := 1        # mỗi khung dựng cạnh cho bấy nhiêu nút (đếm theo khung, không theo đồng hồ, để mọi lần chạy giống nhau)
const SLIDE_DECEL := 1260.0             # giảm tốc khi trượt trên đất: ma sát 0,9 x trọng lực 1400
const BOUNCE := 0.55                   # độ nảy của bóng (bằng Physics Material trong scenes/ball.tscn)
const FRICTION_CUT := 1.4               # ma sát lúc va chạm: mất đà theo hướng trượt bằng chừng này lần đà vuông góc (ma sát 0,9 x (1 + độ nảy))
const CAREFUL_SCALE := 0.3              # đứng yên quá lâu thì cú nhảy kế tiếp "cẩn thận": độ lệch lực chỉ còn chừng này lần bình thường
const RELAX_AFTER := 2.5               # đứng yên quá bấy nhiêu giây thì cho phép cú nhảy đáp sát mép (vẫn không cho cú chết)
const LAUNCH_CHECK_ERR := 0.05        # kiểm tra phút chót thử thêm lực lệch ± chừng này (đơn vị độ mạnh 0..1)
const SAFETY_SKIN := 4.0               # lớp đệm thêm khi kiểm tra an toàn trước lúc nhảy (pixel)
const SKIN_Y := 3.0                    # lớp đệm theo chiều dọc (gầm bệ, mặt bệ)
const SKIN := 2.0                  # lớp đệm thêm vào bán kính khi mô phỏng va chạm với đất (pixel)
const HIT_NONE := 0                    # kết quả một bước mô phỏng: không gì xảy ra
const HIT_LAND := 1                     # đáp xuống đất
const HIT_BUMP := 2                     # đụng trần hoặc tường
const HAZARD_PAD := 12.0                # SUDDEN DEATH: đáy bóng cách đỉnh hàng gai dâng dưới bấy nhiêu pixel cũng coi là chết (bóng thật chết sớm hơn tính toán một chút)
const HIGH_WEIGHT := 1.0                # SUDDEN DEATH: mỗi pixel cao hơn được cộng bấy nhiêu điểm (ưu tiên bệ cao nhất)

@export var skill := 0.6                # độ giỏi 0..1: quyết định độ trễ phản ứng, độ lệch lực nhảy, độ hay nhảy bừa

var player_index := 1                   # bot điều khiển balls[player_index]
var enabled := true                     # false = không làm gì (tắt bot)
var brawl: Brawl                        # cảnh đấu chứa bot
var ball: Ball                          # quả bóng bot điều khiển
var foe: Ball                           # đối thủ
var mode := "chase"                     # chiến thuật hiện tại (xem đầu file)
var phase := "idle"                     # giai đoạn thực hiện (xem đầu file)
var hops := 0                           # số cú nhảy đã bấm
var items_used := 0                     # số vật phẩm đã dùng
var last_jump := ""                     # mô tả cú nhảy vừa bấm (chỗ xuất phát, lực thật, chỗ dự đoán đáp): để dò lỗi
var _since_hop := 0.0                   # đã bao lâu rồi chưa nhảy (để khỏi đứng yên mãi vì quá cẩn thận)
var _extra_skin := 0.0                 # lớp đệm va chạm thêm trong lúc kiểm tra an toàn (0 khi chấm điểm và dựng đồ thị bình thường)
var aborts := 0                       # số lần phút chót thấy cú nhảy sẽ chết nên bỏ
var thoughts := 0                       # số lần đã suy nghĩ chọn cú nhảy
var last_choice := ""                   # cú vừa chọn, dạng "dir=1 charge=0.50 score=123" (để xem khi chạy thử)
var predicted_end := Vector2.ZERO       # chỗ bot dự đoán sẽ đáp xuống sau cú nhảy gần nhất đã bấm (để so với thực tế khi chạy thử)

var _down := {}                         # các phím đang giữ: {tên phím: true}
var _pulses := {}                       # phím bấm một khung: {tên phím: số khung còn lại}
var _solid := PackedByteArray()         # bản đồ đất: 1 = ô đất (#)
var _cols := 0                          # số cột của đấu trường
var _rows := 0                          # số hàng của đấu trường
var _nodes: Array[Vector2] = []         # đồ thị đường đi: tâm bóng khi đứng ở từng ô đất (nút)
var _node_at := PackedInt32Array()      # ô (hàng * cột) -> số thứ tự nút, -1 nếu không có
var _redges: Array = []                 # _redges[j] = các nút i có một cú nhảy an toàn tới j
var _graph_todo: Array[int] = []        # các nút còn chờ dựng cạnh
var _graph_ctx := {}                    # bức tranh dùng khi dựng đồ thị (không có đối thủ)
var _graph_done := false                # dựng xong chưa
var _graph_usable := false              # lần nghĩ này có dùng đồ thị để tính đường tới đích không
var _gdist := PackedInt32Array()        # số cú nhảy từ mỗi nút tới nút đích hiện tại
var _goal_node := -1                    # nút đích mà _gdist đang tính cho
var _haz := PackedByteArray()          # nguy hiểm cố định của từng ô: 0 = không, 1 = gai mọc từ đất (^), 2 = lò xo (T), 3 = gai treo (v)
var _dyn_spikes: Array[Rect2] = []      # gai chống câu giờ đang có (tính lại mỗi lần nghĩ)
var _traps: Array[Rect2] = []           # bẫy lò xo vật phẩm đang nằm trên sàn (tính lại mỗi lần nghĩ)
var _gravity := 1400.0                  # trọng lực mặc định của dự án
var _damp := 0.1                        # lực cản mặc định của dự án
var _clock := 0.0                       # đồng hồ của bot (giây)
var _history: Array = []                # lịch sử đối thủ [thời điểm, vị trí, vận tốc]: bot chỉ thấy bản cũ `reaction` giây
var _think_cd := 0.3                    # còn bao lâu tới lần nghĩ kế tiếp
var _queue: Array = []                  # các cú nhảy đang chờ chấm: [hướng, độ mạnh]
var _results: Array = []                # kết quả đã chấm: {"dir", "charge", "score", "res"}
var _ctx := {}                          # bức tranh lúc bắt đầu nghĩ (vị trí hai bên, trọng lực...)
var _think_frames := 0                  # đã nghĩ được bao nhiêu khung (để trừ vào thời gian chờ của kế hoạch)
var _delay_frames := 0                  # prep: còn bao nhiêu khung nữa thì bắt đầu giữ phím
var _hold_frames := 0                   # charge: còn bao nhiêu khung giữ phím nữa thì bấm nhảy
var _plan_dir := 0                      # hướng của kế hoạch đang làm (-1 trái, 1 phải, 0 thẳng lên)
var _plan_end := Vector2.ZERO           # chỗ dự đoán sẽ đáp của kế hoạch đang làm
var _launch_wait := 0                   # launch: còn bao nhiêu khung chờ bóng bật lên
var _launched := false                  # bóng vừa phát tín hiệu launched
var _aim_frames := 0                    # aim: còn bao nhiêu khung giữ phím quay mặt
var _comp_rev := false                  # đã nhận ra phím bị đảo và đang bù lại
var _rev_timer := 0.0                   # phím thật sự khác với cái bot tưởng đã bao lâu
var _held_id := ""                      # vật phẩm đang cầm (để tính thời gian cầm)
var _held_time := 0.0                   # đã cầm vật phẩm bao lâu
var _item_cd := 0.5                     # còn bao lâu tới lần cân nhắc dùng vật phẩm
var _gun_cd := 0.0                      # chờ giữa hai phát súng
var _lure_time := 0.0                   # > 0: vừa thả bẫy lò xo, đang lùi ra xa để nhử đối thủ dẫm vào
var _threat := false                    # lần nghĩ gần nhất thấy đối thủ sắp đáp xuống đầu mình
var _celebrate := false                 # vừa ghi điểm: nhảy tưng lên ăn mừng một cái
var _box_pos := Vector2.INF             # hộp đang nhắm tới (INF = không)


## Chạy trước hai quả bóng trong mỗi khung vật lý: phím vừa bấm được bóng đọc ngay khung đó (is_action_just_pressed).
func _init() -> void:
	process_physics_priority = -10                # số nhỏ chạy trước (bóng dùng 0)


## Nối vào cảnh đấu cha, đọc bản đồ để biết chỗ đất, gai, lò xo.
func _ready() -> void:
	brawl = get_parent() as Brawl                 # nút cha là Brawl
	if brawl == null:                             # đặt sai chỗ
		push_error("BrawlBot must be a child of Brawl")   # báo lỗi dùng sai
		return
	ball = brawl.balls[player_index]              # quả bóng mình điều khiển
	foe = brawl.opponent_of(ball)                 # đối thủ
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1400.0))   # trọng lực dự án
	_damp = float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.1))     # lực cản dự án
	_build_map()                                  # nhớ bản đồ
	_build_nodes()                                # các ô đất đứng được (đồ thị đường đi dựng dần sau)
	ball.launched.connect(_on_launched)           # biết lúc bóng thật sự bật lên
	brawl.point_scored.connect(_on_point_scored)  # có điểm: nhả phím, ăn mừng
	brawl.match_over.connect(_on_match_over)      # hết trận: nhả hết phím


## Bị xoá khỏi cảnh (đổi cảnh, Rematch, test dọn): nhả hết phím để không có phím nào bị kẹt.
func _exit_tree() -> void:
	release_all()                                 # nhả hết


# ---- Phím bấm ----

## Tên đầy đủ của hành động ("left", "right", "jump", "use") của người chơi mình điều khiển.
func _act(action: String) -> String:
	return ball.action_prefix + action            # vd "p2_" + "left"


## Phím nghiêng theo hướng thế giới `dir` (-1 trái, 1 phải); đã nhận ra phím bị đảo thì bấm ngược lại cho đúng.
func _key(dir: int) -> String:
	var d := -dir if _comp_rev else dir           # bù đảo phím
	return _act("left" if d < 0 else "right")


## Giữ một phím.
func _press(action: String) -> void:
	_pulses.erase(action)                         # đang chờ nhả thì thôi, giữ tiếp
	if not _down.has(action):                     # chưa giữ
		Input.action_press(action)                # bấm
		_down[action] = true                      # nhớ để nhả


## Nhả một phím.
func _release(action: String) -> void:
	if _down.has(action):                         # đang giữ
		Input.action_release(action)              # nhả
		_down.erase(action)                       # quên


## Bấm một phím trong đúng một khung (rồi tự nhả ở đầu khung sau).
func _pulse(action: String) -> void:
	_release(action)                              # nhả cái cũ (nếu còn) để lần bấm này là "vừa bấm" mới
	Input.action_press(action)                    # bấm
	_down[action] = true                          # nhớ
	_pulses[action] = 1                           # nhả sau 1 khung


## Nhả hết mọi phím bot đang giữ (công khai: bài test và khi bot bị xoá dùng).
func release_all() -> void:
	for action in _down.keys():                   # từng phím đang giữ
		Input.action_release(action)              # nhả
	_down.clear()                                 # không còn phím nào
	_pulses.clear()                               # không còn phím bấm một khung nào


## Các phím bot đang giữ (để bài test kiểm tra).
func held_actions() -> Array:
	return _down.keys()


## Dừng mọi việc: nhả phím, bỏ kế hoạch (chết, hết trận, bị tắt).
func _stop_all() -> void:
	release_all()                                 # nhả hết phím
	phase = "idle"                                # chờ
	_queue.clear()                                # bỏ các cú đang chấm
	_think_cd = 0.25                              # hồi sinh xong nghĩ chậm một chút


# ---- Vòng lặp ----

## 60 lần mỗi giây: nhả phím bấm một khung, kiểm tra còn đang đấu không, rồi chạy giai đoạn hiện tại.
func _physics_process(delta: float) -> void:
	if brawl == null or ball == null:             # chưa nối xong
		return
	_graph_step()                                 # dựng dần đồ thị đường đi (cả lúc đang giới thiệu)
	for action in _pulses.keys():                 # các phím bấm một khung
		_pulses[action] -= 1                      # đếm ngược
		if _pulses[action] <= 0:                  # hết một khung
			_release(action)                      # nhả
			_pulses.erase(action)                 # quên
	if not enabled or not brawl.match_running or ball.dead:   # bị tắt, đang giới thiệu, hết trận hoặc bóng đang chết
		if not _down.is_empty() or phase != "idle":   # còn phím hoặc kế hoạch dang dở
			_stop_all()                           # dừng hẳn
		return
	_clock += delta                               # đồng hồ
	_held_time += delta                           # đã cầm vật phẩm bao lâu
	_since_hop += delta                           # đã bao lâu chưa nhảy
	_gun_cd = maxf(0.0, _gun_cd - delta)          # chờ giữa hai phát súng
	_lure_time = maxf(0.0, _lure_time - delta)    # hết thời gian nhử bẫy
	_record_foe()                                 # ghi lại đối thủ để bot chỉ thấy bản cũ
	_track_reverse(delta)                         # nhận ra phím bị đảo sau một lúc
	match phase:
		"idle":
			_think_cd -= delta                    # đếm tới lần nghĩ
			if not _try_items(delta) and _think_cd <= 0.0:   # dùng vật phẩm (nếu hợp lý), không thì nghĩ
				_begin_think()                    # bắt đầu chấm các cú nhảy
		"think":
			_think_step()                         # chấm tiếp vài cú
			_try_items(delta)                     # vẫn dùng vật phẩm được (không đụng phím nhảy)
		"prep":
			_delay_frames -= 1                    # chờ tới lúc giữ phím
			if _delay_frames <= 0:                # tới lúc
				phase = "charge"                  # bắt đầu giữ phím
				_start_charge()                   # giữ phím hướng (hoặc nhảy thẳng ngay)
		"charge":
			_hold_frames -= 1                     # đã giữ thêm một khung
			if _hold_frames <= 0:                 # đủ lực
				if ball.on_ground or _hold_frames < -6:   # bóng đang chạm đất (hoặc đã chờ quá 6 khung): bấm nhảy, nhả phím hướng
					_jump_now()
					return
		"launch":
			_launch_wait -= 1                     # đếm thời gian chờ bóng bật lên
			if _launched or _launch_wait <= 0:    # đã bật lên (hoặc không bật được: nghĩ lại)
				phase = "idle"                    # nghĩ tiếp ngay (đang bay cũng nghĩ được: bot biết trước chỗ sẽ chạm đất)
				_think_cd = 0.02 if _launched else 0.1
		"aim":
			_aim_frames -= 1                      # giữ phím quay mặt thêm một khung
			if _aim_frames <= 0:                  # đủ để quay mặt
				for action in [_act("left"), _act("right")]:   # nhả phím hướng (không nhảy: chỉ để quay mặt)
					_release(action)              # nhả
				phase = "idle"                    # xong
				_think_cd = 0.0                   # bắn ngay lượt sau
				_item_cd = 0.0                    # cân nhắc súng ngay


## Bóng vừa bật lên thật sự.
func _on_launched() -> void:
	_launched = true                              # phase "launch" sẽ thấy


## Có người ghi điểm: bóng mình chết thì nhả hết; mình ghi điểm thì nhảy tưng ăn mừng một cái.
func _on_point_scored(scorer: Ball, victim: Ball, _cause: String) -> void:
	if victim == ball:                            # mình bị giết
		_stop_all()                               # nhả hết phím, bỏ kế hoạch
	elif scorer == ball:                          # mình ghi điểm
		_celebrate = randf() < 0.5                # nửa số lần ăn mừng bằng cú nhảy thẳng
		if phase != "idle":                       # đang dở kế hoạch cũ
			_stop_all()                           # bỏ


## Hết trận: nhả hết phím.
func _on_match_over(_winner: Ball) -> void:
	_stop_all()                                   # nhả hết


# ---- Mắt: đối thủ (trễ một chút), phím bị đảo ----

## Thời gian phản ứng: bot chỉ thấy đối thủ như `reaction` giây trước (0,30 giây khi vụng, 0,03 giây khi giỏi).
func _reaction() -> float:
	return lerpf(0.30, 0.03, skill)               # skill càng cao càng nhanh


## Ghi vị trí và vận tốc đối thủ mỗi khung, bỏ bản quá cũ.
func _record_foe() -> void:
	_history.append([_clock, foe.global_position, foe.linear_velocity])   # bản mới nhất
	while _history.size() > 1 and _history[1][0] <= _clock - _reaction():   # bản kế tiếp vẫn đủ cũ: bản đầu hết cần
		_history.pop_front()                      # bỏ


## Đối thủ như bot "thấy": bản cũ `reaction` giây. Trả [thời điểm, vị trí, vận tốc].
func _foe_view() -> Array:
	return _history[0]


## Phím của mình bị đảo (chuối, REVERSED KEYS) mà bot chưa hay: mất một lúc mới nhận ra rồi bù lại; hết đảo cũng vậy (vấp một lúc).
func _track_reverse(delta: float) -> void:
	if ball.reverse_controls == _comp_rev:        # bot đang hiểu đúng
		_rev_timer = 0.0                          # không có gì lạ
		return
	_rev_timer += delta                           # lạ rồi, đang loay hoay
	if _rev_timer >= lerpf(1.2, 0.3, skill):      # đủ lâu để nhận ra
		_comp_rev = ball.reverse_controls         # bù lại (hoặc thôi bù)
		_rev_timer = 0.0                          # xong


# ---- Bản đồ ----

## Đọc bản đồ chữ của đấu trường: ô đất, vùng gai, lò xo.
func _build_map() -> void:
	var level := brawl.level                      # màn đang chơi
	_cols = level.cols                            # số cột
	_rows = level.rows.size()                     # số hàng
	_solid.resize(_cols * _rows)                  # một byte mỗi ô
	_haz.resize(_cols * _rows)
	for r in _rows:                               # từng hàng
		for c in _cols:                           # từng cột
			var ch := level.char_at(r, c)         # ký tự của ô
			_solid[r * _cols + c] = 1 if ch == "#" else 0   # ô đất
			_haz[r * _cols + c] = {"^": 1, "T": 2, "v": 3}.get(ch, 0)   # gai, lò xo, gai treo


## Ô (r, c) có phải đất không. Ngoài bản đồ: hai bên là tường, trên và dưới là trống.
func _is_solid(r: int, c: int) -> bool:
	if c < 0 or c >= _cols:                       # ngoài hai bên
		return true                               # coi là tường
	if r < 0 or r >= _rows:                       # trên hoặc dưới
		return false                              # trống
	return _solid[r * _cols + c] == 1             # tra bản đồ


## Hình tròn (tâm `p`, bán kính `rad`) có chạm ô đất nào không.
func _hit_solid(p: Vector2, rad: float) -> bool:
	var c0 := floori((p.x - rad) / TILE)          # cột trái nhất có thể chạm
	var c1 := floori((p.x + rad) / TILE)          # cột phải nhất
	var r0 := floori((p.y - rad) / TILE)          # hàng trên nhất
	var r1 := floori((p.y + rad) / TILE)          # hàng dưới nhất
	for r in range(r0, r1 + 1):                   # từng hàng
		for c in range(c0, c1 + 1):               # từng cột
			if not _is_solid(r, c):               # không phải đất
				continue
			var nx := clampf(p.x, c * TILE, c * TILE + TILE)   # điểm của ô gần tâm nhất
			var ny := clampf(p.y, r * TILE, r * TILE + TILE)
			if (p.x - nx) * (p.x - nx) + (p.y - ny) * (p.y - ny) < rad * rad:   # gần hơn bán kính
				return true                       # chạm
	return false


## Hình tròn có chạm hình chữ nhật không.
func _circle_hits(p: Vector2, rad: float, rect: Rect2) -> bool:
	var nx := clampf(p.x, rect.position.x, rect.end.x)   # điểm của hình chữ nhật gần tâm nhất
	var ny := clampf(p.y, rect.position.y, rect.end.y)
	return (p.x - nx) * (p.x - nx) + (p.y - ny) * (p.y - ny) < rad * rad   # gần hơn bán kính


## Nguy hiểm ở chỗ tâm bóng `p`: bit 1 = chết (rơi vực, gai), bit 2 = lò xo (bị bắn đi), bit 4 = bẫy lò xo vật phẩm.
func _danger_at(p: Vector2, rad: float) -> int:
	var mask := 0                                 # chưa có gì nguy hiểm
	if p.y > FALL_Y:                              # thấp hơn mặt đất: đang rơi xuống vực
		return 1
	for r in range(floori((p.y - rad) / TILE), floori((p.y + rad) / TILE) + 1):   # các ô bóng đang phủ lên
		if r < 0 or r >= _rows:
			continue
		for c in range(floori((p.x - rad) / TILE), floori((p.x + rad) / TILE) + 1):
			if c < 0 or c >= _cols:
				continue
			var kind := _haz[r * _cols + c]       # nguy hiểm của ô
			if kind == 0:
				continue
			var x := c * TILE
			var y := r * TILE
			if kind == 2:                         # lò xo: cả ô
				if _circle_hits(p, rad, Rect2(x, y, TILE, TILE)):
					mask |= 2
			elif _circle_hits(p, rad + SPIKE_PAD, Rect2(x + (TILE - SPIKE_W) / 2.0, y + TILE - SPIKE_H if kind == 1 else y, SPIKE_W, SPIKE_H)):   # gai (mọc từ đất ở đáy ô, gai treo ở đỉnh ô)
				return 1
	for s in _dyn_spikes:                         # gai chống câu giờ
		if _circle_hits(p, rad + SPIKE_PAD, s):
			return 1
	for s in _traps:                              # bẫy lò xo vật phẩm
		if _circle_hits(p, rad, s):
			mask |= 4
	return mask


## Đứng ở (x, y) (tâm bóng) có đất ngay bên dưới và không có gai kề bên không.
func _ground_ok(x: float, y: float, rad: float) -> bool:
	var r := floori((y + rad + 2.0) / TILE)       # hàng ngay dưới chân
	if not _is_solid(r, floori(x / TILE)):        # dưới chân là trống (vực)
		return false
	return (_danger_at(Vector2(x, y), rad + 4.0) & 1) == 0   # gai gần quá thì không ổn


## Đường thẳng từ `a` tới `b` có thông thoáng (không xuyên đất) không. Dùng để biết có bắn trúng được không.
func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 16.0)     # lấy mẫu mỗi 16 pixel
	for i in range(1, steps):                     # từng điểm giữa
		var p := a.lerp(b, float(i) / steps)      # điểm mẫu
		if _is_solid(floori(p.y / TILE), floori(p.x / TILE)):   # xuyên đất
			return false
	return true


# ---- Đồ thị đường đi: từ ô đất nào nhảy được sang ô đất nào ----
# Một cú nhảy chọn theo khoảng cách thẳng sẽ kẹt khi giữa đường có bệ, gai hay vực (đi vòng mới tới). Nên bot dựng một đồ thị:
# mỗi "nút" là một ô đất đứng được (mặt trên không có gai / lò xo); mỗi "cạnh" là một cú nhảy an toàn (đã mô phỏng) từ nút này sang nút kia.
# Đồ thị dựng dần (một nút mỗi khung, cả lúc đang giới thiệu, xong khoảng 1-2 giây sau khi cảnh dựng); trong lúc chưa xong bot dùng khoảng cách thẳng.
# Khi nghĩ, bot đếm số cú nhảy từ chỗ đáp của từng cú tới ô đối thủ đang đứng (tìm đường ngược từ đích), rồi ưu tiên cú đi gần đích hơn.

## Tìm các ô đất đứng được và xếp hàng chờ dựng cạnh.
func _build_nodes() -> void:
	_node_at.resize(_cols * _rows)                # ô -> số thứ tự nút
	_node_at.fill(-1)
	var base_radius := ball.radius / ball.size_factor   # bán kính gốc
	for r in range(1, _rows):                     # từng hàng (hàng 0 không có gì phía trên)
		for c in range(1, _cols - 1):             # bỏ hai cột tường
			if not _is_solid(r, c) or _is_solid(r - 1, c) or _haz[(r - 1) * _cols + c] != 0:   # không phải mặt đất, bị chắn phía trên, hoặc có gai / lò xo đứng ở đó
				continue
			_node_at[r * _cols + c] = _nodes.size()   # nút mới
			_nodes.append(Vector2((c + 0.5) * TILE, r * TILE - base_radius))   # tâm bóng khi đứng giữa mặt ô
	for i in _nodes.size():
		_redges.append([])                        # danh sách cạnh ngược
		_graph_todo.append(i)                     # chờ dựng
	_graph_ctx = {"me_pos": Vector2.ZERO, "me_vel": Vector2.ZERO, "g_me": _gravity, "foe_pos": Vector2.ZERO, "foe_vel": Vector2.ZERO,
		"g_foe": _gravity, "foe_on": false, "foe_invuln": 0.0, "my_invuln": 0.0, "ice": false, "box_pos": Vector2.INF, "t_contact": 0.0, "margin": 0.0}


## Dựng thêm vài nút của đồ thị mỗi khung (chạy cả lúc đang giới thiệu).
func _graph_step() -> void:
	if _graph_todo.is_empty():                    # dựng xong
		_graph_done = true
		return
	for n in GRAPH_NODES_PER_FRAME:               # vài nút mỗi khung
		if _graph_todo.is_empty():
			break
		_expand_node(_graph_todo.pop_front())     # dựng các cạnh từ một nút
	if _graph_todo.is_empty():
		_graph_done = true


## Thử mọi cú nhảy từ nút `i`; cú nào đáp an toàn xuống một nút khác thì thêm cạnh (ghi ngược: nút đáp <- nút i).
func _expand_node(i: int) -> void:
	_graph_ctx["me_pos"] = _nodes[i]              # đứng yên ở nút này
	var cands: Array = [[0, 0.5]]                 # nhảy thẳng lên
	for dir in [-1, 1]:
		for amount in GRAPH_CHARGES:
			cands.append([dir, amount])
	for cand in cands:
		var res := _evaluate(cand[0], cand[1], false, _graph_ctx)   # mô phỏng
		if res["dead"] or not res["landed"] or res["spring"]:   # chết, không đáp xuống đất, hoặc dính lò xo: không phải đường đi
			continue
		var j := _node_index_at(res["end"])       # đáp xuống nút nào
		if j >= 0 and j != i and not _redges[j].has(i):
			_redges[j].append(i)                  # thêm cạnh i -> j


## Số thứ tự nút đang đứng ở tâm bóng `p` (ô đất ngay dưới chân); -1 nếu không có nút.
func _node_index_at(p: Vector2) -> int:
	var c := floori(p.x / TILE)                   # cột
	var r := floori((p.y + ball.radius + 2.0) / TILE)   # hàng đất dưới chân
	if c < 0 or c >= _cols or r < 0 or r >= _rows:
		return -1
	return _node_at[r * _cols + c]


## Nút đất ngay bên dưới điểm `p` (nơi đối thủ / hộp đang đứng). Phía dưới là vực thì lấy nút gần nhất.
func _node_below(p: Vector2) -> int:
	var c := clampi(floori(p.x / TILE), 0, _cols - 1)   # cột
	for r in range(maxi(0, floori(p.y / TILE)), _rows):   # quét xuống tìm mặt đất
		var n: int = _node_at[r * _cols + c]
		if n >= 0:
			return n
	var best := -1                                # không có đất bên dưới: nút gần nhất
	var best_d := INF
	for i in _nodes.size():
		var d := _nodes[i].distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## SUDDEN DEATH: nút đích là mặt bệ cao nhất mà từ chỗ mình đi tới được bằng các cú nhảy (mỗi độ cao lấy nút gần mình nhất theo chiều ngang).
## Không bệ nào tới được thì lấy nút ngay dưới chân.
func _high_goal() -> int:
	var mine := _node_below(ball.global_position)   # nút dưới chân mình
	var best_of_row := {}                         # độ cao (y tâm bóng) -> nút gần mình nhất ở độ cao đó
	for i in _nodes.size():
		var y := _nodes[i].y
		if not best_of_row.has(y) or absf(_nodes[i].x - ball.global_position.x) < absf(_nodes[best_of_row[y]].x - ball.global_position.x):
			best_of_row[y] = i
	var heights: Array = best_of_row.keys()       # các độ cao
	heights.sort()                                # nhỏ trước = cao nhất trước
	for y in heights:
		var g: int = best_of_row[y]
		if mine < 0 or _goal_hops(g)[mine] < 999: # từ chỗ mình tới được nút này
			return g
	return mine


## Số cú nhảy ít nhất từ mỗi nút tới nút `goal` (tìm đường ngược từ đích). 999 = không tới được.
func _goal_hops(goal: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(_nodes.size())
	d.fill(999)
	d[goal] = 0
	var queue: Array[int] = [goal]
	while not queue.is_empty():
		var n: int = queue.pop_front()
		for p in _redges[n]:                      # các nút nhảy được tới n
			if d[p] == 999:
				d[p] = d[n] + 1
				queue.append(p)
	return d


## Từ chỗ đáp `e` còn bao nhiêu cú nhảy tới đích hiện tại (tối đa 12; không có nút hoặc không tới được thì 12).
func _hops_to_goal(e: Vector2) -> int:
	var j := _node_index_at(e)
	if j < 0:
		return 12
	return mini(_gdist[j], 12)


# ---- Mô phỏng đường bay ----

## Một quả bóng trong đầu bot: vị trí, vận tốc, bán kính, đang trên không không.
class SimBody extends RefCounted:
	var pos := Vector2.ZERO                   # tâm bóng
	var vel := Vector2.ZERO                   # vận tốc (pixel/giây)
	var rad := 15.0                           # bán kính
	var air := true                           # đang trên không (false = đang đứng trên đất)


## Bóng `b` vừa đáp xuống còn đà ngang `v`: trượt trên mặt đất tới khi ma sát làm dừng (quãng v^2 / 2 / SLIDE_DECEL), chặn lại bởi tường.
## Trượt quá mép đất thì chuyển sang rơi tự do (b.air = true, giữ đà còn lại) và trả về true; trượt xong an toàn trả về false.
func _slide(b: SimBody, v: float) -> bool:
	var dir_x := signf(v)
	var dist := v * v / (2.0 * SLIDE_DECEL)       # quãng trượt tới khi dừng
	var moved := 0.0
	while moved < dist:
		var nx := b.pos.x + dir_x * 4.0
		if _hit_solid(Vector2(nx, b.pos.y), b.rad):   # đụng tường / cạnh bệ: dừng
			return false
		b.pos.x = nx
		moved += 4.0
		if not _is_solid(floori((b.pos.y + b.rad + 2.0) / TILE), floori(nx / TILE)):   # tâm bóng đã quá mép đất: rơi
			b.vel.x = dir_x * sqrt(maxf(0.0, v * v - 2.0 * SLIDE_DECEL * moved))   # đà ngang còn lại
			b.air = true
			return true
	return false


## Giảm độ lớn vận tốc `v` đi `amount` (không đổi dấu): ma sát lúc va chạm.
func _friction_cut(v: float, amount: float) -> float:
	return signf(v) * maxf(0.0, absf(v) - amount)


## Tiến một bước DT: trọng lực, cản, đụng tường / trần / đất. Trả về HIT_LAND khi đáp xuống đất (vận tốc về 0, đứng lại).
## Chỉ gần đúng: bóng thật còn nảy lên xuống nhưng không trôi ngang sau khi chạm đất (đã đo bằng tests/measure.tscn), nên đủ dùng.
func _advance(b: SimBody, g: float) -> int:
	var result := HIT_NONE                        # chưa có gì
	b.vel.y += g * DT                             # trọng lực
	b.vel *= maxf(0.0, 1.0 - _damp * DT)          # lực cản không khí
	var rs := b.rad + SKIN + _extra_skin          # bán kính tính thêm lớp đệm: đường bay sát góc bệ vài pixel trong đầu thì thực tế đã quệt vào
	var x0 := b.pos.x                             # chỗ ngang đầu bước (để nội suy lúc đáp)
	var nx := b.pos.x + b.vel.x * DT              # thử đi ngang
	if _hit_solid(Vector2(nx, b.pos.y), rs) and not _hit_solid(b.pos, rs):   # đụng tường / cạnh bệ (đang dính sát mà đi ra xa thì không tính)
		var vn := b.vel.x                         # đụng cạnh bệ / tường: nảy ngược, ma sát làm mất đà dọc (đã đo: bóng thật đập cạnh bệ rồi rơi thẳng xuống)
		b.vel.x = -BOUNCE * vn
		b.vel.y = _friction_cut(b.vel.y, FRICTION_CUT * absf(vn))
		result = HIT_BUMP
	else:
		b.pos.x = nx                              # đi được
	var ny := b.pos.y + b.vel.y * DT              # thử đi dọc
	if ny - b.rad < CEILING_Y:                    # đụng trần vô hình
		b.vel.y = 0.0
		return HIT_BUMP
	var np := Vector2(b.pos.x, ny)                # chỗ mới nếu đi được
	var rsy := b.rad + SKIN_Y + _extra_skin       # lớp đệm theo chiều dọc dày hơn: bóng thật quệt gầm bệ sớm hơn tính toán vài pixel
	var touching: bool = _hit_solid(np, b.rad) if b.vel.y > 0.0 else (_hit_solid(np, rsy) and not _hit_solid(b.pos, rsy))   # rơi: chạm đất thật; bay lên: mới quệt vào lớp đệm (đang đứng sát đất mà nhảy lên thì không tính)
	if not touching and b.vel.y > 0.0 and _hit_solid(np, rsy) and not _hit_solid(b.pos, rsy):   # rơi sát vào góc bệ (trong lớp đệm): cũng coi là chạm
		touching = true
	if touching:                                  # đụng đất
		if b.vel.y > 0.0:                         # đang rơi: đáp xuống mặt trên của ô
			var surface := floorf((ny + rsy) / TILE) * TILE - b.rad  # tâm bóng khi đứng sát mặt trên của ô đất vừa chạm
			if ny > b.pos.y:                      # bước dọc dài hơn 0: nội suy chỗ ngang lúc chạm đúng mặt đất (bước thô nên cần cho chính xác)
				b.pos.x = lerpf(x0, b.pos.x, clampf((surface - b.pos.y) / (ny - b.pos.y), 0.0, 1.0))
			b.pos.y = surface
			var slide_v := _friction_cut(b.vel.x, FRICTION_CUT * absf(b.vel.y))   # đáp mạnh: ma sát giết hết đà ngang (đã đo); đáp sượt (rơi chậm, đà ngang lớn): còn trượt
			b.vel = Vector2.ZERO
			b.air = false
			if absf(slide_v) > 20.0 and _slide(b, slide_v):   # trượt trên mặt đất; trượt khỏi mép thì rơi tiếp
				return HIT_NONE
			return HIT_LAND
		var vn := b.vel.y                         # đụng gầm bệ: nảy xuống, ma sát làm mất đà ngang
		b.vel.y = -BOUNCE * vn
		b.vel.x = _friction_cut(b.vel.x, FRICTION_CUT * absf(vn))
		return HIT_BUMP
	b.pos.y = ny                                  # đi được
	return result


## Chạy thử một cú nhảy (`dir`: -1 trái, 1 phải, 0 thẳng lên; `charge`: 0..1; charge < 0 nghĩa là đứng yên, không nhảy)
## và trả về kết quả: có chết không, có dẫm được đối thủ không, bị dẫm không, chạm hộp / bẫy / lò xo không, chỗ đáp.
## `immediate` = true: nhảy ngay (kiểm tra phút chót: lực `charge` đã tích xong, chỉ chờ bóng chạm đất rồi bật lên).
## `ctx` = bức tranh dùng để mô phỏng (mặc định là _ctx của lần nghĩ hiện tại; việc dựng đồ thị truyền bức tranh riêng).
func _evaluate(dir: int, charge: float, immediate := false, ctx := {}) -> Dictionary:
	var c: Dictionary = ctx if not ctx.is_empty() else _ctx   # bức tranh lúc bắt đầu nghĩ
	var me := SimBody.new()                       # bóng của mình trong đầu
	me.pos = c["me_pos"]
	me.vel = c["me_vel"]
	me.rad = ball.radius
	var op := SimBody.new()                       # bóng đối thủ trong đầu (rơi theo trọng lực, đứng yên khi chạm đất)
	op.pos = c["foe_pos"]
	op.vel = c["foe_vel"]
	op.rad = foe.radius
	var g_me: float = c["g_me"]                   # trọng lực của mình
	var g_foe: float = c["g_foe"]                 # trọng lực của đối thủ
	var foe_on: bool = c["foe_on"]                # đối thủ có đang ở trên sân không (không phải đang chờ hồi sinh)
	var wait := charge < 0.0                      # cú "đứng yên"
	var hold_s := 0.0 if (wait or dir == 0 or immediate) else charge * ball.charge_time   # thời gian giữ phím
	var launch_at := 0.0 if wait else maxf(hold_s + FRAME, float(c["t_contact"]) - LAND_LEAD)   # lúc bấm nhảy
	var res := {"dead": false, "stomp_opp": -1.0, "stomp_me": -1.0, "bump": false, "min_gap": 9999.0, "box": false,
		"trap": false, "spring": false, "edge": false, "bonk": false, "landed": false, "end": me.pos, "end_opp": op.pos, "t_end": 0.0, "delay": launch_at - hold_s}
	var launched := false                         # đã nhảy chưa
	var landed := false                           # đã đáp xuống sau cú nhảy chưa
	var land_t := 0.0                             # lúc đáp
	var vx_land := 0.0                            # vận tốc ngang lúc sắp đáp (để tính trượt trên băng)
	var t := 0.0                                  # thời gian mô phỏng
	for i in MAX_SIM_STEPS:
		t += DT
		if not launched:                          # chưa nhảy: đang rơi xuống hoặc đứng chờ
			if me.air:
				_advance(me, g_me)                # rơi tiếp tới khi chạm đất
			if not wait and t >= launch_at:       # tới lúc bấm nhảy
				me.vel = ball.jump_velocity(dir, charge)   # vận tốc nhảy đúng như bóng thật
				me.pos.y -= 1.0                   # nhấc khỏi mặt đất một chút
				me.air = true
				launched = true
		elif me.air:                              # đang bay
			vx_land = me.vel.x
			var hit := _advance(me, g_me)
			if hit == HIT_LAND:                   # đáp xuống
				landed = true
				land_t = t
				res["landed"] = true
			elif hit == HIT_BUMP:                 # đụng trần / cạnh bệ giữa đường bay: cú nhảy này khó đoán
				res["bonk"] = true
		if foe_on and op.air:                     # đối thủ đang rơi
			_advance(op, g_foe)
		var danger := _danger_at(me.pos, me.rad)  # nguy hiểm dưới chân
		if me.pos.y + me.rad + HAZARD_PAD >= float(c.get("hazard", INF)) - brawl.sudden_death_speed * t:   # SUDDEN DEATH: hàng gai dâng (lúc t đã cao thêm speed x t) quét tới bóng: coi như chết
			danger |= 1
		if danger & 1 != 0:                       # rơi vực hoặc chạm gai
			res["dead"] = true
			break
		if danger & 2 != 0:
			res["spring"] = true                  # chạm lò xo của đấu trường
		if danger & 4 != 0:
			res["trap"] = true                    # chạm bẫy vật phẩm
		var box_pos: Vector2 = c["box_pos"]       # hộp đang nhắm
		if box_pos.is_finite() and me.pos.distance_to(box_pos) <= me.rad + BrawlItems.PICK_REACH - 2.0:   # chạm hộp
			res["box"] = true
		if foe_on:                                # hai bóng có chạm nhau không
			var d := me.pos - op.pos              # từ đối thủ tới mình
			var dist := maxf(d.length(), 0.01)    # khoảng cách tâm
			var gap := dist - me.rad - op.rad     # khoảng cách mép tới mép
			res["min_gap"] = minf(res["min_gap"], gap)
			if gap <= 1.0:                        # chạm nhau
				var above := -d.y / dist          # > 0,6: mình nằm trên đầu đối thủ
				if above > 0.6 and me.air and me.vel.y >= ball.stomp_speed:   # mình rơi xuống đầu nó đủ nhanh: DẪM
					if float(c["foe_invuln"]) <= t:   # nó không đang miễn sát thương
						res["stomp_opp"] = t
					break
				elif above < -0.6 and op.air and op.vel.y >= foe.stomp_speed:   # nó rơi xuống đầu mình đủ nhanh: BỊ DẪM
					if float(c["my_invuln"]) <= t:   # mình không đang miễn sát thương
						res["stomp_me"] = t
					break
				else:                             # va nhau kiểu khác: bị hất ra
					res["bump"] = true
					if launched:                  # đang bay thì chặng bay kết thúc ở đây
						landed = true
						land_t = t
		if landed and t >= land_t + 0.08:         # đã đáp xong
			break
		if wait and t >= WAIT_HORIZON:            # đứng yên: nhìn đủ xa rồi
			break
	res["t_end"] = t
	res["end"] = me.pos
	res["end_opp"] = op.pos
	if landed and not res["dead"]:                # kiểm tra chỗ đáp có an toàn không
		var end: Vector2 = me.pos
		if c["ice"]:                              # trên băng: còn trượt tiếp sau khi chạm đất
			var slide := vx_land * ICE_SLIDE
			for k in range(1, 7):                 # dọc đường trượt có vực / gai không
				if not _ground_ok(end.x + slide * k / 6.0, end.y, me.rad):
					res["dead"] = true
			end.x = clampf(end.x + slide, 48.0, _cols * TILE - 48.0)
			res["end"] = end
		var m: float = c["margin"]                # chừa lề vì cú nhảy có thể lệch
		for off in [-m, 0.0, m]:                  # chỗ đáp và hai bên lề
			if not _ground_ok(end.x + off, end.y, me.rad):   # lề là vực / gai
				res["edge"] = true
	return res


## Chấm điểm kết quả `res` theo chiến thuật hiện tại: càng cao càng tốt. Chết là -1000.
func _score(res: Dictionary) -> float:
	if res["dead"]:                               # chết thì không bao giờ chọn (trừ khi cú nào cũng chết)
		return -1000.0
	var s := 0.0                                  # điểm
	var e: Vector2 = res["end"]                   # chỗ mình cuối cùng
	var o: Vector2 = res["end_opp"]               # chỗ đối thủ lúc đó
	var bold: bool = brawl.stall_active           # gai chống câu giờ đang mọc: đứng yên là chết dần, liều hơn
	if brawl.sudden_death_active:                 # SUDDEN DEATH: chỗ càng cao càng sống lâu
		s -= HIGH_WEIGHT * e.y
	if res["stomp_opp"] >= 0.0:                   # dẫm được đối thủ
		s += (750.0 if bold else 500.0) - 30.0 * res["stomp_opp"]   # càng sớm càng tốt
	if res["stomp_me"] >= 0.0:                    # bị đối thủ dẫm
		s -= 180.0 if bold else 450.0
	if res["trap"]:                               # dẫm bẫy lò xo
		s -= 350.0
	if res["spring"]:                             # chạm lò xo của đấu trường (bị bắn vọt lên, đáp ở đâu không đoán được)
		s -= 400.0
	if res["edge"]:                               # chỗ đáp sát mép vực / gai
		s -= 120.0
	if res["bonk"]:                               # đường bay quệt vào bệ
		s -= 100.0
	if res["box"] and brawl.items.held[player_index] == "":   # nhặt được hộp khi tay trống
		s += 260.0 if mode == "get_box" else 120.0
	match mode:                                   # mục tiêu của từng chiến thuật
		"flee":
			s += minf(e.distance_to(o), 520.0)    # càng xa đối thủ càng tốt
			s -= 150.0 * clampf((110.0 - minf(e.x, _cols * TILE - e.x)) / 110.0, 0.0, 1.0)   # tránh bị dồn vào góc
			if res["bump"] or res["min_gap"] <= 3.0:   # để đối thủ chạm vào mình
				s -= 250.0
		"pass_bomb":
			s -= e.distance_to(o)                 # càng gần đối thủ càng tốt
			if res["bump"] or res["min_gap"] <= 3.0:   # chạm nhau: chuyền được bom
				s += 350.0
		"get_box":
			s -= _path_cost(e, e.distance_to(_box_pos))   # càng gần hộp càng tốt (đi theo đường nhảy được)
		_:                                        # chase, dodge
			var dy := e.y - o.y                   # > 0: mình thấp hơn đối thủ
			s -= _path_cost(e, 0.7 * absf(absf(e.x - o.x) - 80.0) + 0.9 * (absf(dy) + maxf(dy, 0.0)))   # tới gần cỡ 80 pixel, và lên ngang hoặc cao hơn nó
	return s


## Chi phí tới đích của chiến thuật: còn bao nhiêu cú nhảy theo đồ thị đường đi (mỗi cú 150), cộng chút khoảng cách thẳng `near_cost`.
## Tới nơi rồi (0 cú nhảy) hoặc chưa có đồ thị thì chỉ tính `near_cost`.
func _path_cost(e: Vector2, near_cost: float) -> float:
	if not _graph_usable:                         # chưa dựng xong đồ thị / không có đích
		return near_cost
	var hops := _hops_to_goal(e)                  # từ chỗ đáp `e` còn mấy cú nhảy
	if hops == 0:                                 # đã ở ô của đích
		return near_cost
	return 150.0 * minf(hops, 12) + 0.25 * near_cost   # đường đi quan trọng hơn khoảng cách thẳng (đi vòng qua gai, lên bệ)


# ---- Suy nghĩ: chọn cú nhảy ----

## Bắt đầu một lần nghĩ: chụp bức tranh hiện tại, chọn chiến thuật, xếp các cú nhảy sẽ chấm (cú đứng yên trước).
func _begin_think() -> void:
	_snapshot()                                   # chụp bức tranh hiện tại
	var foe_pos: Vector2 = _ctx["foe_pos"]
	mode = _pick_mode(foe_pos)                    # chiến thuật
	_ctx["box_pos"] = _box_pos if mode == "get_box" or brawl.items.held[player_index] == "" else Vector2.INF
	_graph_usable = false                         # đích của đường đi: chỗ đối thủ đứng (đuổi) hoặc cái hộp (nhặt)
	if _graph_done and (mode == "chase" or mode == "get_box"):
		var goal_pos: Vector2 = _box_pos if mode == "get_box" else foe_pos
		var g := _high_goal() if brawl.sudden_death_active else _node_below(goal_pos)   # SUDDEN DEATH: đích là bệ cao nhất, không phải chỗ đối thủ
		if g >= 0:
			if g != _goal_node:                   # đích đổi: tìm đường lại
				_goal_node = g
				_gdist = _goal_hops(g)
			_graph_usable = true
	_queue =[[0, -1.0], [0, 0.5]]                # cú đứng yên, rồi cú nhảy thẳng lên
	for dir in [-1, 1]:                           # nhảy trái / phải
		for amount in CANDIDATE_CHARGES:          # mỗi độ mạnh
			_queue.append([dir, amount])
	_results.clear()                              # chưa chấm cú nào
	_think_frames = 0
	phase = "think"
	thoughts += 1


## Chụp bức tranh hiện tại vào _ctx: vị trí và vận tốc hai bên (đối thủ như bot thấy, trễ một chút), trọng lực, gai, bẫy, bao lâu nữa chạm đất.
func _snapshot() -> void:
	var view := _foe_view()                       # đối thủ như bot thấy (trễ một chút)
	var foe_pos: Vector2 = view[1]
	_dyn_spikes.clear()                           # gai chống câu giờ đang có
	for s in brawl.stall_spikes:
		if is_instance_valid(s):
			_dyn_spikes.append(Rect2(s.position.x - SPIKE_W / 2.0, s.position.y - SPIKE_H, SPIKE_W, SPIKE_H))
	for col in brawl.upcoming_stall_columns(2):   # các ô gai chống câu giờ sắp mọc cũng coi là gai (đừng đứng đó)
		_dyn_spikes.append(Rect2(col * TILE + (TILE - SPIKE_W) / 2.0, (brawl.floor_row() + 1) * TILE - SPIKE_H, SPIKE_W, SPIKE_H))
	_traps.clear()                                # bẫy lò xo đang nằm trên sàn
	for t in brawl.items.traps:
		if is_instance_valid(t):
			_traps.append(Rect2(t.position + Vector2(-TRAP_SIZE.x / 2.0, -TRAP_SIZE.y), TRAP_SIZE))
	var ice: bool = brawl.events != null and brawl.events.active_event == "ice_floor"   # đang có sàn băng
	_ctx = {
		"me_pos": ball.global_position, "me_vel": ball.linear_velocity, "g_me": _gravity * ball.gravity_scale,
		"foe_pos": foe_pos, "foe_vel": view[2], "g_foe": _gravity * foe.gravity_scale, "foe_on": not foe.dead,
		"foe_invuln": foe.invuln, "my_invuln": ball.invuln, "ice": ice, "box_pos": Vector2.INF, "t_contact": 0.0,
		"margin": (18.0 + 70.0 * (1.0 - skill)) * (1.6 if ice else 1.0),   # lề an toàn quanh chỗ đáp
		"hazard": brawl.hazard_y(),               # đỉnh hàng gai SUDDEN DEATH lúc này (INF = chưa có)
	}
	_ctx["t_contact"] = _time_to_contact()        # bao lâu nữa chạm đất (đang đứng thì ~0)


## Bao lâu nữa bóng mình chạm đất nếu cứ để rơi (giây). Không chạm (rơi xuống vực) thì 99.
func _time_to_contact() -> float:
	var b := SimBody.new()                        # bóng mình trong đầu
	b.pos = ball.global_position
	b.vel = ball.linear_velocity
	b.rad = ball.radius
	var g: float = _ctx["g_me"]
	for i in 90:                                  # tối đa 1,5 giây
		if _advance(b, g) == HIT_LAND:            # chạm đất
			return (i + 1) * DT
	return 99.0


## Chọn chiến thuật cho lần nghĩ này, theo thứ tự ưu tiên: bom, nhử bẫy, nhặt hộp, đuổi. (`dodge` do kết quả chấm quyết định sau.)
func _pick_mode(foe_pos: Vector2) -> String:
	_box_pos = Vector2.INF
	var carrier: Ball = brawl.events.bomb_carrier if brawl.events != null else null   # ai đang cầm bom
	if carrier == ball:                           # mình cầm bom: chuyền cho nó
		return "pass_bomb"
	if carrier != null:                           # nó cầm bom: tránh xa
		return "flee"
	if _lure_time > 0.0:                          # vừa thả bẫy: lùi ra để nó dẫm vào
		return "flee"
	if brawl.items.held[player_index] == "" and not foe.dead:   # tay trống: tìm hộp gần
		var best := 560.0                         # chỉ để ý hộp trong tầm này
		for box in brawl.items.boxes:
			if not is_instance_valid(box):
				continue
			var d: float = box.position.distance_to(ball.global_position)
			if d < best and box.position.distance_to(foe_pos) > 120.0:   # gần mình và không nằm sát mặt đối thủ
				best = d
				_box_pos = box.position
		if _box_pos.is_finite():                  # có hộp đáng đi lấy
			return "get_box"
	return "chase"


## Mỗi khung khi đang nghĩ: chấm vài cú nhảy; chấm hết thì chọn.
func _think_step() -> void:
	_think_frames += 1
	for n in EVALS_PER_FRAME:                     # vài cú mỗi khung
		if _queue.is_empty():
			break
		var cand: Array = _queue.pop_front()      # cú kế tiếp
		var res := _evaluate(cand[0], cand[1])    # mô phỏng
		_results.append({"dir": cand[0], "charge": cand[1], "res": res, "score": _score(res)})
	if _queue.is_empty():                         # chấm hết
		_choose()                                 # chọn và bắt đầu làm


## Chọn cú nhảy tốt nhất (có chút ngẫu nhiên), lệch lực nhảy một chút, rồi bắt đầu thực hiện. Cú đứng yên tốt nhất thì chờ.
func _choose() -> void:
	var wait_res: Dictionary = _results[0]["res"]   # kết quả của cú đứng yên
	_threat = wait_res["stomp_me"] >= 0.0         # đứng yên có bị dẫm không
	if _threat and mode == "chase":               # đối thủ sắp rơi xuống đầu: đang né
		mode = "dodge"
	var noise := (1.5 - skill) * 18.0             # độ ngẫu nhiên trong việc chọn
	var ranked: Array = []                        # các cú xếp theo điểm giảm dần: [điểm, kết quả]
	for r in _results:                            # từng cú đã chấm
		var is_hop: bool = r["charge"] >= 0.0
		ranked.append([float(r["score"]) + randf_range(-noise, noise) - (6.0 if is_hop else 0.0), r])   # nhảy tốn công: thắng một chút khi ngang nhau
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if randf() < (1.0 - skill) * 0.06:            # thỉnh thoảng nhảy bừa (nhưng không phải cú nhảy vào chỗ chết): đưa một cú ngẫu nhiên lên đầu
		var pick: Array = ranked[randi() % ranked.size()]
		if pick[1]["charge"] >= 0.0 and not pick[1]["res"]["dead"]:
			ranked.push_front(pick)
	if _celebrate:                               # vừa ghi điểm: nhảy thẳng lên ăn mừng nếu an toàn
		_celebrate = false
		ranked.push_front([0.0, _results[1]])
	var strict := _since_hop < RELAX_AFTER and not brawl.stall_active   # mới nhảy gần đây: kiểm tra khắt khe; đứng yên quá lâu thì bớt khắt khe và nhảy cẩn thận hơn
	var sigma := (0.02 + 0.12 * (1.0 - skill)) * (1.0 if strict else CAREFUL_SCALE)   # độ lệch lực nhảy của bot (đơn vị: độ mạnh 0..1); cẩn thận thì giữ phím chuẩn hơn
	var best: Dictionary = _results[0]            # không cú nào qua được kiểm tra thì đứng yên
	var checks := 0                               # số cú đã kiểm tra độ chắc chắn
	for item in ranked:                           # từ cú điểm cao nhất xuống
		var r: Dictionary = item[1]
		if r["charge"] < 0.0:                     # đứng yên (luôn chọn được)
			best = r
			break
		if r["res"]["dead"]:                      # cú nhảy này chết
			continue
		if r["dir"] == 0:                         # nhảy thẳng lên không lệch hướng nên khỏi kiểm tra thêm
			best = r
			break
		if checks >= 6:                           # hết lượt kiểm tra: bỏ qua cú còn lại
			continue
		checks += 1
		if _robust(r["dir"], r["charge"], 1.5 * _jump_sigma(sigma, r["charge"]), strict):   # lệch lực cũng không chết (đứng yên quá lâu thì bớt khắt khe chuyện đáp sát mép)
			best = r
			break
	_think_cd = lerpf(0.30, 0.03, skill)          # nghĩ chậm lại sau mỗi lần
	phase = "idle"
	if best["charge"] < 0.0:                      # đứng yên là tốt nhất
		last_choice = "wait score=%d mode=%s" % [best.get("score", 0), mode]
		return
	var dir: int = best["dir"]
	var amount: float = best["charge"]            # độ mạnh dự định
	if dir != 0:                                  # lệch lực nhảy: người cũng không giữ phím chuẩn tới từng khung (nhưng không quá mức đã kiểm tra)
		var s := _jump_sigma(sigma, amount)       # độ lệch cho cú nhảy này
		amount = clampf(amount + clampf(randfn(0.0, s), -1.5 * s, 1.5 * s), 0.0, 1.0)
	_plan_end = best["res"]["end"]
	last_choice = "dir=%d charge=%.2f score=%d mode=%s" % [dir, amount, best["score"], mode]
	_plan_dir = dir
	_hold_frames = 0 if dir == 0 else maxi(1, roundi(amount * ball.charge_time * 60.0))   # số khung giữ phím trước khi bấm nhảy
	var res: Dictionary = best["res"]
	_delay_frames = maxi(0, roundi(float(res["delay"]) * 60.0) - _think_frames)   # chờ bóng sắp chạm đất mới bắt đầu giữ phím
	phase = "prep"                                # chờ tới lúc bắt đầu


## Độ lệch lực nhảy của một cú nhảy có độ mạnh `charge`: cú ngắn (bước nhỏ) giữ phím chuẩn hơn cú dài.
func _jump_sigma(sigma: float, charge: float) -> float:
	return sigma * (0.3 + charge)


## Cú nhảy (`dir`, `charge`) có an toàn dù lực nhảy lệch ± `err` không (không chết ở cả hai đầu lệch).
## Kiểm tra kỹ hơn lúc chấm: lớp đệm va chạm dày thêm SAFETY_SKIN, nên đường bay sát góc bệ vài pixel cũng coi là quệt (rồi rơi xuống gai / vực thì loại).
## `strict` = true: cũng loại cú đáp sát mép vực / gai (hết nghi ngờ thì mới nhảy); false: chỉ loại cú chết hoặc dính lò xo.
func _robust(dir: int, charge: float, err: float, strict := true) -> bool:
	_extra_skin = SAFETY_SKIN                     # chỉ trong lúc kiểm tra
	var safe := true
	for amount in [maxf(0.0, charge - err), charge, minf(1.0, charge + err)]:   # lệch ít, đúng, lệch nhiều
		var res := _evaluate(dir, amount)
		if res["dead"] or res["spring"] or (strict and res["edge"]):   # chết, chạm lò xo (bị bắn đi không đoán được), hoặc đáp sát mép vực / gai (nảy hay trượt vài pixel là rơi)
			safe = false
			break
	_extra_skin = 0.0
	return safe


## Bắt đầu giữ phím hướng (cú nhảy thẳng lên thì nhảy luôn).
func _start_charge() -> void:
	if _plan_dir == 0:                            # nhảy thẳng lên
		_jump_now()
		return
	_press(_key(_plan_dir))                       # giữ phím hướng để nghiêng và tích lực


## Kiểm tra phút chót: nhảy ngay bây giờ (với lực và hướng bóng thật đang tích) có chết không, tính từ vị trí thật của bóng.
func _launch_is_safe() -> bool:
	_snapshot()                                   # vị trí thật lúc này
	var real_dir := ball.charge_dir if _plan_dir != 0 else 0   # hướng bóng thật sẽ nhảy (phím bị đảo thì khác kế hoạch, bot chưa biết nên không tính)
	var amount := ball.charge if real_dir != 0 else ball.straight_jump
	_extra_skin = SAFETY_SKIN                     # kiểm tra kỹ như _robust
	var safe := true
	for delta in [-LAUNCH_CHECK_ERR, 0.0, LAUNCH_CHECK_ERR]:   # mô phỏng và thực tế lệch nhau vài pixel: thử cả hai bên lực hiện có
		var res := _evaluate(real_dir, clampf(amount + delta, 0.0, 1.0), true)
		if res["dead"] or res["spring"] or (res["bonk"] and res["edge"]):
			safe = false
			break
	_extra_skin = 0.0
	return safe


## Bấm nhảy và nhả phím hướng (cùng một khung, giống người chơi).
func _jump_now() -> void:
	if not _launch_is_safe():                     # phút chót: bóng đã lệch khỏi chỗ dự tính (nảy trên mép bệ...) và cú nhảy này sẽ chết
		for key in [_act("left"), _act("right")]:
			_release(key)                         # thôi, không nhảy
		aborts += 1
		phase = "idle"
		_think_cd = 0.0                           # nghĩ lại ngay
		return
	# Bóng đọc phím ở khung này hoặc khung sau tuỳ thứ tự xử lý, nên phím hướng được giữ thêm 2 khung sau cú bấm nhảy
	# (người thật cũng nhả A/D chậm hơn một chút); nhả sớm thì bóng đã quên hướng và nhảy thẳng lên.
	for key in [_act("left"), _act("right")]:     # phím hướng đang giữ
		if _down.has(key):
			_pulses[key] = 3                      # nhả sau 3 khung
	_pulse(_act("jump"))                          # bấm nhảy một khung
	predicted_end = _plan_end                     # nhớ chỗ dự đoán sẽ đáp
	last_jump = "from=%s plan_dir=%d real_dir=%d rev=%s charge=%.2f pred=%s vel=%s ground=%s" % [ball.global_position.round(), _plan_dir, ball.charge_dir, ball.reverse_controls, ball.charge, _plan_end.round(), ball.linear_velocity.round(), ball.on_ground]
	_launched = false                             # chờ tín hiệu bóng bật lên
	_launch_wait = 40                             # chờ tối đa 40 khung (bóng đang nảy trên không có thể chưa nhảy ngay)
	phase = "launch"
	hops += 1
	_since_hop = 0.0


# ---- Vật phẩm ----

## Cân nhắc dùng vật phẩm đang cầm (súng, chuối, đổi chỗ, bẫy lò xo). Trả về true nếu vừa làm gì đó (bấm "use" hoặc quay mặt để bắn).
func _try_items(delta: float) -> bool:
	var id: String = brawl.items.held[player_index]   # món đang cầm
	if id != _held_id:                            # vừa đổi món
		_held_id = id
		_held_time = 0.0
	if id == "" or foe.dead:                      # tay trống hoặc đối thủ đang chờ hồi sinh
		return false
	_item_cd -= delta                             # đếm tới lần cân nhắc
	if _item_cd > 0.0:
		return false
	_item_cd = lerpf(0.4, 0.12, skill)            # lần sau
	var view := _foe_view()                       # đối thủ như bot thấy
	var fp: Vector2 = view[1]
	var fv: Vector2 = view[2]
	var me := ball.global_position                # chỗ mình
	var d := fp - me                              # từ mình tới đối thủ
	match id:
		"gun":
			return _try_gun(fp)                   # bắn nếu đối thủ ngang tầm và ở phía trước
		"banana":
			if d.length() < 600.0 and _held_time > 0.6:   # đối thủ trong tầm mắt: ném chuối rồi đuổi
				return _use_item()
		"swap":
			var worse := fp.y < me.y - 90.0       # đối thủ đứng cao hơn hẳn: đổi chỗ để lên cao
			var cornered := _threat and _held_time > 0.3   # sắp bị dẫm: đổi chỗ để thoát
			if worse or cornered or (d.length() < 160.0 and randf() < 0.1):
				return _use_item()
		"spring":
			var level_with := absf(d.y) < 50.0 and absf(d.x) > 90.0 and absf(d.x) < 320.0   # đối thủ ngang tầm, cách một quãng
			var coming := signf(fv.x) == -signf(d.x) and absf(fv.x) > 40.0 or foe.charge_dir == -signi(d.x)   # đang tiến về phía mình
			if level_with and coming:             # nó đi dọc mặt đất tới: thả bẫy rồi lùi ra
				_lure_time = 1.8
				return _use_item()
	return false


## Bấm phím "use" một khung.
func _use_item() -> bool:
	_pulse(_act("use"))                           # bấm dùng vật phẩm
	items_used += 1
	return true


## Súng: đối thủ ngang tầm, ở phía trước trong tầm, không bị đất che thì bắn; chưa quay mặt về phía nó thì quay trước (giữ phím hướng vài khung).
## Gần mép vực (bắn là hất nó xuống) thì chắc chắn bắn; còn lại bắn tuỳ hứng.
func _try_gun(fp: Vector2) -> bool:
	if ball.ammo <= 0 or _gun_cd > 0.0:           # hết đạn hoặc đang chờ
		return false
	var d := fp - ball.global_position            # từ mình tới đối thủ
	var ax := absf(d.x)
	if absf(d.y) > 24.0 or ax < 50.0 or ax > 560.0 or not _line_clear(ball.global_position, fp):   # lệch tầm, quá gần / xa, bị che
		return false
	var dirx := 1 if d.x > 0.0 else -1            # hướng của đối thủ
	var edge := false                             # sau lưng đối thủ có vực / gai không
	for k in [40.0, 90.0, 140.0]:
		edge = edge or not _ground_ok(fp.x + dirx * k, fp.y, foe.radius)
	if not edge and randf() > 0.35 + 0.4 * skill:   # không có vực: bắn tuỳ hứng
		return false
	if ball.facing != dirx:                       # chưa quay mặt về phía đối thủ
		_press(_key(dirx))                        # giữ phím hướng vài khung chỉ để quay mặt (rồi nhả, không nhảy)
		_aim_frames = 3
		phase = "aim"
		_queue.clear()
		return true
	_gun_cd = 0.3                                 # chờ giữa hai phát
	return _use_item()                            # bắn
