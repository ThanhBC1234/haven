class_name Rope                         # tên lớp: chained.gd và bài test dùng Rope
extends Node2D                          # node vẽ dây, gắn làm con của Level (nằm phía sau hai quả bóng)
## Sợi dây đàn hồi trói người chơi 1 (`ball_a`) và người chơi 2 (`ball_b`) của chế độ Chained, cùng các ngôi sao xâu trên dây.
##
## DÂY: dưới `rest_length` thì không có lực (dây chùng, võng xuống). Kéo giãn quá thì như lò xo kéo hai bóng lại gần nhau
## (lực = stiffness * độ giãn), có giảm chấn khi đang rời xa nhau để không rung. Quá `max_length` thì kéo cực mạnh (hard_stiffness)
## nên hai người không thể rời xa hơn. Lực đưa vào bóng bằng Ball.knockback() (xung = lực * dt / khối lượng), không bao giờ dịch bóng.
## Dây không va chạm với địa hình. Dây bị kéo căng quá thì chiều đàn hồi biến thành "súng cao su": một người neo lại (giữ phím use
## lúc đang đứng đất), người kia chạy ra xa cho dây căng rồi nhảy về phía neo thì bị dây hất vọt qua đầu người neo.
##
## NEO (giữ phím use của mình lúc đang đứng đất): bóng không trượt, nặng hơn, ma sát cao, và lực dây tác dụng lên nó chỉ còn
## `anchor_force_scale` (0,1) nên nó thành điểm cố định: giữ được bạn đồng đội lơ lửng trên vực. Thả phím (hoặc nhảy, vì neo cần đang đứng đất)
## thì trả lại đúng ma sát, khối lượng, lực như cũ. Biểu tượng neo (PixelArt.ANCHOR) hiện trên đầu người đang neo.
##
## HẠT (bead): mỗi ngôi sao nhặt được là một hạt xâu trên dây (Chained gọi add_bead). `Bead.t` = vị trí dọc dây: 0 là đầu người chơi 1, 1 là đầu người chơi 2.
## Mỗi khung các hạt trượt về phía người đang đứng THẤP hơn (tốc độ tỉ lệ chênh lệch độ cao, có chặn; chênh quá ít thì đứng yên),
## giữ khoảng cách nhỏ giữa các hạt và dừng ở hai đầu dây. Cuối màn mỗi hạt tính cho người gần nó hơn (bead_counts()).
##
## ---- Phần công khai cho các tính năng thêm sau (sự kiện ngẫu nhiên...) ----
##   ball_a, ball_b                       hai đầu dây (người chơi 1, người chơi 2)
##   rest_length, max_length, stiffness, damping, hard_stiffness, anchor_force_scale   chỉnh được lúc đang chạy (sự kiện co / giãn dây)
##   cut                                  true = dây đứt: không có lực, không vẽ (sự kiện FREEDOM)
##   anchor_enabled                       false = không ai neo được
##   beads                                các hạt (Rope.Bead, có .t); bead_counts() -> Vector2i; add_bead(t); steal_bead(thief, victim); drop_beads(player)
##   current_length(), tension(), is_anchored(ball), point_at(t), reset()
##   tín hiệu: bead_added, beads_dropped(count)

signal bead_added                       # vừa thêm một hạt (ngôi sao mới trên dây)
signal beads_dropped(count: int)        # một số hạt rơi khỏi dây (người chơi chết), kèm số hạt rơi

const TILE := 32.0                      # kích thước một ô (pixel)
const ATTACH := Vector2(0.0, -4.0)      # điểm buộc dây trên thân bóng, so với tâm bóng
const DAMP_RAMP := 16.0                 # giảm chấn tăng dần từ 0 tới đủ trong 16 pixel giãn đầu tiên (không giật khi vừa căng)
const SEGMENTS := 18                    # dây vẽ bằng bấy nhiêu đoạn thẳng
const BEAD_END := 0.03                  # hạt dừng cách hai đầu dây bấy nhiêu (tỉ lệ 0..1)
const BEAD_GAP_PX := 15.0               # hai hạt cạnh nhau cách nhau ít nhất bấy nhiêu pixel dọc dây
const BEAD_DEADZONE := 6.0              # hai người chênh độ cao dưới bấy nhiêu pixel thì hạt đứng yên
const BEAD_SPEED_PER_PX := 0.012        # tốc độ hạt (phần dây / giây) cho mỗi pixel chênh độ cao
const BEAD_MAX_SPEED := 1.2             # tốc độ hạt tối đa (phần dây / giây)
const STEAL_LOCK := 2.5                 # hạt vừa bị cướp thì đứng yên bấy nhiêu giây (không trượt ngay về chỗ cũ)
const ANCHOR_MASS_SCALE := 4.0          # bóng đang neo nặng gấp bấy nhiêu lần
const ANCHOR_FRICTION := 4.0            # ma sát của bóng đang neo (rất cao; đất giới hạn ma sát hiệu dụng ở mức của đất)
const ANCHOR_BRAKE := 14.0              # bóng đang neo mà còn trượt: hãm vận tốc ngang với tốc độ này (1/giây)
const ANCHOR_AIR_GRACE := 0.9           # đang neo mà bị nảy lên (vừa đáp xuống): giữ neo tối đa bấy nhiêu giây trên không
const ANCHOR_ICON_PX := 3.0             # mỗi điểm của biểu tượng neo to 3 x 3

static var _bead_tex: ImageTexture = null   # ảnh hạt (ngôi sao có viền), tạo một lần dùng chung

@export var rest_length := 160.0        # dây chùng tới độ dài này (5 ô), chưa có lực
@export var max_length := 320.0         # độ dài tối đa (10 ô): vượt thì bị kéo cực mạnh (hai người không thể xa hơn; súng cao su hất tới gần mức này ở phía bên kia người neo)
@export var stiffness := 16.0           # độ cứng lò xo: gia tốc (pixel/giây^2, bóng nặng 1) cho mỗi pixel giãn quá rest_length
@export var damping := 3.0              # giảm chấn khi hai bóng đang rời xa nhau trong lúc dây căng (chống rung)
@export var hard_stiffness := 320.0     # độ cứng cộng thêm cho mỗi pixel vượt quá max_length
@export var hard_damping := 12.0        # giảm chấn cộng thêm khi đã quá max_length mà còn rời xa nhau
@export var anchor_force_scale := 0.1   # lực dây tác dụng lên bóng đang neo chỉ còn bấy nhiêu phần
@export var anchor_enabled := true      # false = không ai neo được
var cut := false                        # true = dây đứt: không lực, không vẽ (sự kiện FREEDOM)
var beads: Array = []                   # các hạt xâu trên dây (Rope.Bead)
var ball_a: Ball = null                 # đầu dây ở người chơi 1 (t = 0)
var ball_b: Ball = null                 # đầu dây ở người chơi 2 (t = 1)
var freeze_beads := false               # true = các hạt đứng yên (Chained dùng lúc đã về đích để số sao chốt lại)
var _tension := 0.0                     # lực kéo của dây ở khung vừa rồi (0 = chùng)
var _length := 0.0                      # khoảng cách hai đầu dây ở khung vừa rồi
var _anchored: Array[bool] = [false, false]   # [người chơi 1, người chơi 2] đang neo không
var _saved_material: Array = [null, null]     # vật liệu vật lý gốc của từng bóng (trả lại khi thả neo)
var _saved_mass: Array[float] = [1.0, 1.0]    # khối lượng gốc của từng bóng
var _air: Array[float] = [0.0, 0.0]     # [người chơi 1, người chơi 2] đã ở trên không bao lâu (giây)
var _jumped: Array[bool] = [false, false]   # vừa nhảy (tín hiệu launched) mà chưa rời đất: không neo lại ngay khung sau (cờ on_ground cập nhật muộn một khung)
var _time := 0.0                        # đồng hồ cho hiệu ứng nhấp nhô của biểu tượng neo


## Một hạt (ngôi sao) xâu trên dây.
class Bead extends RefCounted:
	var t := 0.5                        # vị trí dọc dây: 0 = đầu người chơi 1, 1 = đầu người chơi 2
	var lock := 0.0                     # còn bao lâu hạt đứng yên (bị cướp)
	var pop := 0.0                      # hiệu ứng phóng to lúc mới xuất hiện (giây còn lại)


## Gắn dây vào hai quả bóng (a = người chơi 1, b = người chơi 2).
func setup(a: Ball, b: Ball) -> void:
	ball_a = a                          # đầu dây người chơi 1
	ball_b = b                          # đầu dây người chơi 2
	_length = _end(a).distance_to(_end(b))   # khoảng cách ban đầu
	a.launched.connect(func() -> void: _jumped[0] = true)   # người chơi 1 vừa nhảy: thả neo, không neo lại cho tới khi rời đất
	b.launched.connect(func() -> void: _jumped[1] = true)   # người chơi 2 vừa nhảy


## Dây đang dài bao nhiêu (khoảng cách hai điểm buộc, pixel).
func current_length() -> float:
	return _length


## Lực kéo của dây ở khung vừa rồi (0 = dây chùng).
func tension() -> float:
	return _tension


## `ball` đang neo không.
func is_anchored(ball: Ball) -> bool:
	return _anchored[0] if ball == ball_a else (_anchored[1] if ball == ball_b else false)


## Đưa dây về trạng thái chùng: thả neo cả hai (trả lại ma sát, khối lượng), bỏ lực. Gọi khi hồi sinh.
func reset() -> void:
	for i in 2:                         # từng người chơi
		_exit_anchor(i)                 # thả neo nếu đang neo
	_tension = 0.0                      # hết lực kéo
	if is_instance_valid(ball_a) and is_instance_valid(ball_b):   # đã gắn bóng (và chưa bị xoá)
		_length = _end(ball_a).distance_to(_end(ball_b))   # đo lại khoảng cách
	queue_redraw()                      # vẽ lại


## Điểm buộc dây (toạ độ thế giới) của `ball`.
func _end(ball: Ball) -> Vector2:
	return ball.global_position + ATTACH * ball.size_factor   # tâm bóng cộng chút lệch


## Toạ độ thế giới của điểm có tham số `t` trên dây (0 = người chơi 1, 1 = người chơi 2); dây chùng thì võng xuống, căng thì thẳng.
func point_at(t: float) -> Vector2:
	var pa := _end(ball_a)              # đầu người chơi 1
	var pb := _end(ball_b)              # đầu người chơi 2
	var sag := _sag(pa.distance_to(pb)) # độ võng ở giữa dây
	return pa.lerp(pb, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t))   # đường parabol: võng nhiều nhất ở giữa


## Độ võng (pixel) của dây khi hai đầu cách nhau `dist`: dây dài rest_length bị chùng thì võng, căng thẳng thì không võng.
func _sag(dist: float) -> float:
	if cut or dist >= rest_length:      # đứt hoặc đã căng thẳng
		return 0.0                      # không võng
	return minf(sqrt(3.0 * maxf(dist, 24.0) * (rest_length - dist) / 8.0), rest_length * 0.45)   # xấp xỉ độ dài dây = khoảng cách + 8 * võng^2 / (3 * khoảng cách)


## 60 lần mỗi giây: cập nhật neo, trượt hạt, rồi kéo hai bóng bằng lực dây.
func _physics_process(delta: float) -> void:
	if ball_a == null or ball_b == null:   # chưa gắn bóng
		return
	_time += delta                      # đồng hồ nhấp nhô
	_update_anchors(delta)              # ai đang neo thì cho neo
	_update_beads(delta)                # hạt trượt về phía người đứng thấp
	_apply_force(delta)                 # lực kéo của dây
	queue_redraw()                      # vẽ lại dây, hạt, biểu tượng neo


## Lực dây: không có khi dây chùng, đứt, hoặc có người đang chết; ngược lại kéo hai bóng lại gần nhau.
func _apply_force(delta: float) -> void:
	_tension = 0.0                      # mặc định không có lực
	var pa := _end(ball_a)              # đầu người chơi 1
	var pb := _end(ball_b)              # đầu người chơi 2
	var offset := pb - pa               # từ bóng 1 tới bóng 2
	_length = offset.length()           # khoảng cách hiện tại
	if cut or ball_a.dead or ball_b.dead or _length < 1.0:   # đứt, có người chết hoặc trùng nhau
		return
	var stretch := _length - rest_length   # giãn quá độ dài chùng bao nhiêu
	if stretch <= 0.0:                  # còn chùng
		return                          # không có lực
	var dir := offset / _length         # hướng từ bóng 1 sang bóng 2
	var force := stiffness * stretch    # lò xo
	if _length > max_length:            # quá độ dài tối đa
		force += hard_stiffness * (_length - max_length)   # kéo cực mạnh
	var closing := (ball_b.linear_velocity - ball_a.linear_velocity).dot(dir)   # > 0: hai bóng đang rời xa nhau
	if closing > 0.0:                   # đang giãn thêm
		force += damping * closing * minf(1.0, stretch / DAMP_RAMP)   # giảm chấn (chỉ lúc rời xa, để hất về không bị mất lực)
		if _length > max_length:        # đã quá độ dài tối đa mà còn rời xa
			force += hard_damping * closing   # hãm mạnh: hai người không vọt ra xa hơn nhiều
	_tension = force                    # nhớ để vẽ màu căng
	_pull(0, dir, force, delta)         # bóng 1 bị kéo về phía bóng 2
	_pull(1, -dir, force, delta)        # bóng 2 bị kéo về phía bóng 1


## Kéo bóng thứ `i` (0 / 1) theo hướng `dir` với lực `force`: xung = lực * dt / khối lượng, đưa vào bằng knockback.
## Bóng đang neo chỉ chịu `anchor_force_scale` lực (dùng khối lượng gốc, không phải khối lượng nặng lúc neo).
func _pull(i: int, dir: Vector2, force: float, delta: float) -> void:
	var ball: Ball = ball_a if i == 0 else ball_b   # bóng bị kéo
	var factor := anchor_force_scale if _anchored[i] else 1.0   # neo thì lực nhẹ đi
	var m: float = _saved_mass[i] if _anchored[i] else ball.mass   # khối lượng dùng để tính xung
	ball.knockback(dir * (force * factor * delta / maxf(m, 0.01)))   # cộng vào vận tốc ở khung vật lý tới


# ---- Neo ----

## Ai giữ phím use lúc đang đứng đất thì neo. Thả phím, hoặc nhảy (tín hiệu launched), hoặc rời đất quá ANCHOR_AIR_GRACE giây thì thả neo.
## (Vừa chạm đất thì bóng còn nảy lên vài lần: đang neo thì giữ neo qua các lần nảy đó, không thì dây kéo lại ngay lúc người đó vừa đáp.)
## Bóng đang neo mà còn trượt thì hãm lại.
func _update_anchors(delta: float) -> void:
	for i in 2:                         # từng người chơi
		var ball: Ball = ball_a if i == 0 else ball_b   # bóng của người này
		if ball.on_ground:              # đang chạm đất
			_air[i] = 0.0               # không ở trên không
		else:                           # đang ở trên không
			_air[i] += delta            # đếm thời gian trên không
			_jumped[i] = false          # đã thật sự rời đất: cú nhảy vừa rồi đã xong, lần chạm đất sau được neo lại
		var holding := anchor_enabled and not cut and ball.is_use_held()   # đang giữ phím và được phép neo
		var want := holding and not _jumped[i] and (ball.on_ground or (_anchored[i] and _air[i] < ANCHOR_AIR_GRACE))   # neo mới (đang đứng đất) hoặc giữ neo qua các lần nảy
		if want and not _anchored[i]:   # vừa bắt đầu neo
			_enter_anchor(i, ball)      # đổi ma sát, khối lượng
		elif not want and _anchored[i]: # vừa hết neo
			_exit_anchor(i)             # trả lại như cũ
		if _anchored[i]:                # đang neo
			ball.knockback(Vector2(-ball.linear_velocity.x * minf(1.0, ANCHOR_BRAKE * delta), 0.0))   # hãm trượt ngang (đứng yên thì bằng 0, không ảnh hưởng cú nhảy)


## Bắt đầu neo bóng thứ `i`: nhớ vật liệu và khối lượng gốc, đổi sang ma sát rất cao, không nảy, nặng hơn.
func _enter_anchor(i: int, ball: Ball) -> void:
	_anchored[i] = true                 # đánh dấu đang neo
	_saved_material[i] = ball.physics_material_override   # nhớ vật liệu gốc (dùng chung trong scene, KHÔNG sửa trực tiếp)
	_saved_mass[i] = ball.mass          # nhớ khối lượng gốc
	var mat := PhysicsMaterial.new()    # vật liệu riêng cho lúc neo
	mat.friction = ANCHOR_FRICTION      # ma sát rất cao
	mat.bounce = 0.0                    # không nảy
	ball.physics_material_override = mat   # áp vật liệu neo
	ball.mass = _saved_mass[i] * ANCHOR_MASS_SCALE   # nặng hơn: bạn đồng đội đụng vào cũng không đẩy được


## Thả neo bóng thứ `i` (không làm gì nếu không đang neo): trả đúng vật liệu và khối lượng gốc.
func _exit_anchor(i: int) -> void:
	if not _anchored[i]:                # không đang neo
		return
	_anchored[i] = false                # hết neo
	var ball: Ball = ball_a if i == 0 else ball_b   # bóng của người này
	if is_instance_valid(ball):         # bóng còn tồn tại
		ball.physics_material_override = _saved_material[i]   # trả lại vật liệu gốc (đúng resource cũ)
		ball.mass = _saved_mass[i]      # trả lại khối lượng gốc
	_saved_material[i] = null           # quên vật liệu đã nhớ


## Dây bị xoá khỏi cảnh thì thả neo, không để bóng giữ vật liệu neo.
func _exit_tree() -> void:
	reset()


# ---- Hạt (ngôi sao xâu trên dây) ----

## Thêm một hạt ở vị trí `t` (mặc định giữa dây), đẩy các hạt gần đó ra cho khỏi chồng. Trả về hạt mới.
func add_bead(t := 0.5) -> Bead:
	var bead := Bead.new()              # hạt mới
	bead.t = clampf(t, BEAD_END, 1.0 - BEAD_END)   # nằm trong dây
	bead.pop = 0.35                     # phóng to một chút lúc mới xuất hiện
	beads.append(bead)                  # thêm vào danh sách
	_separate()                         # tách hạt chồng nhau
	bead_added.emit()                   # báo có hạt mới
	return bead


## Bỏ một hạt khỏi dây (không phát tín hiệu).
func remove_bead(bead: Bead) -> void:
	beads.erase(bead)                   # gỡ khỏi danh sách


## Số hạt của từng người: x = phía người chơi 1 (t < 0,5), y = phía người chơi 2 (t > 0,5). Hạt đúng giữa dây (0,5) không tính cho ai.
func bead_counts() -> Vector2i:
	var counts := Vector2i.ZERO         # đếm
	for bead in beads:                  # từng hạt
		if absf(bead.t - 0.5) < 0.001:  # đúng giữa dây
			continue                    # không tính cho ai
		if bead.t < 0.5:                # gần người chơi 1 hơn
			counts.x += 1               # tính cho người chơi 1
		else:                           # gần người chơi 2 hơn
			counts.y += 1               # tính cho người chơi 2
	return counts


## Cướp sao: `thief` vừa dẫm đầu `victim`, hạt gần đầu `victim` nhất nhảy sang đầu `thief` (và đứng yên STEAL_LOCK giây). Trả về false nếu không có hạt.
func steal_bead(thief: Ball, victim: Ball) -> bool:
	if beads.is_empty() or thief == victim:   # không có gì để cướp
		return false
	var victim_is_a := victim == ball_a # nạn nhân là đầu người chơi 1 (t = 0)?
	var pick: Bead = null               # hạt gần đầu nạn nhân nhất
	for bead in beads:                  # tìm hạt
		if pick == null or (bead.t < pick.t if victim_is_a else bead.t > pick.t):   # gần đầu nạn nhân hơn
			pick = bead                 # nhớ hạt
	pick.t = (1.0 - BEAD_END) if victim_is_a else BEAD_END   # nhảy sang đầu kẻ cướp (đầu kia của dây)
	pick.lock = STEAL_LOCK              # đứng yên một lúc
	pick.pop = 0.35                     # nhấp nháy cho dễ thấy
	_separate()                         # các hạt khác nhường chỗ nếu cần
	return true


## Người chơi `player` (1 hoặc 2) chết: một nửa (làm tròn lên) số hạt ở phía họ rơi khỏi dây (những hạt gần đầu họ nhất). Trả về số hạt rơi.
func drop_beads(player: int) -> int:
	var side: Array = []                # các hạt ở phía người này
	for bead in beads:                  # từng hạt
		if player == 1 and bead.t < 0.5 - 0.001:   # phía người chơi 1
			side.append(bead)           # thêm vào
		elif player == 2 and bead.t > 0.5 + 0.001:   # phía người chơi 2
			side.append(bead)           # thêm vào
	side.sort_custom(func(x: Bead, y: Bead) -> bool: return x.t < y.t if player == 1 else x.t > y.t)   # hạt gần đầu người chết nhất đứng đầu
	var count := ceili(side.size() / 2.0)   # một nửa, làm tròn lên
	for i in count:                     # gỡ từng hạt
		beads.erase(side[i])            # rơi khỏi dây
	if count > 0:                       # có hạt rơi
		beads_dropped.emit(count)       # báo
	return count


## Khoảng cách tối thiểu giữa hai hạt, tính theo tham số t.
func _spacing() -> float:
	var by_length := BEAD_GAP_PX / maxf(_length, 48.0)   # cách nhau BEAD_GAP_PX pixel
	return minf(by_length, (1.0 - 2.0 * BEAD_END) * 0.98 / maxf(beads.size(), 1.0))   # nhiều hạt quá thì thu hẹp để vẫn vừa dây


## Tách các hạt chồng nhau (đẩy đều hai phía), rồi dồn vào trong hai đầu dây. Giữ nguyên thứ tự hạt.
func _separate() -> void:
	var n := beads.size()               # số hạt
	if n < 2:                           # một hạt thì khỏi tách
		return
	beads.sort_custom(func(x: Bead, y: Bead) -> bool: return x.t < y.t)   # xếp theo vị trí
	var s := _spacing()                 # khoảng cách tối thiểu
	for _pass in 8:                     # vài lượt đẩy đều hai phía
		var moved := false              # lượt này có đẩy gì không
		for i in range(1, n):           # từng cặp hạt kề nhau
			var gap: float = beads[i].t - beads[i - 1].t   # khoảng cách hiện tại
			if gap < s - 0.0001:        # gần quá
				var push := (s - gap) * 0.5   # mỗi hạt lùi một nửa
				beads[i - 1].t -= push  # hạt trước lùi
				beads[i].t += push      # hạt sau tiến
				moved = true            # có đẩy
		if not moved:                   # xong
			break
	beads[0].t = maxf(beads[0].t, BEAD_END)   # không vượt đầu dây phía người chơi 1
	for i in range(1, n):               # quét xuôi: giữ đúng khoảng cách tối thiểu
		beads[i].t = maxf(beads[i].t, beads[i - 1].t + s)
	beads[n - 1].t = minf(beads[n - 1].t, 1.0 - BEAD_END)   # không vượt đầu dây phía người chơi 2
	for i in range(n - 2, -1, -1):      # quét ngược: dồn vào trong nếu bị đẩy quá đầu dây
		beads[i].t = minf(beads[i].t, beads[i + 1].t - s)


## Mỗi khung: các hạt trượt về phía người đứng thấp hơn (y lớn hơn). Hạt bị khoá hoặc bị hạt khác chặn thì đứng yên.
func _update_beads(delta: float) -> void:
	for bead in beads:                  # đếm ngược hiệu ứng, thời gian khoá
		bead.lock = maxf(0.0, bead.lock - delta)   # hết khoá dần
		bead.pop = maxf(0.0, bead.pop - delta)     # hết nhấp nháy dần
	if beads.is_empty() or freeze_beads or cut or ball_a.dead or ball_b.dead:   # không có gì để trượt
		return
	var dy := ball_b.global_position.y - ball_a.global_position.y   # > 0: người chơi 2 đứng thấp hơn
	if absf(dy) < BEAD_DEADZONE:        # chênh quá ít
		_separate()                     # chỉ giữ khoảng cách (dây ngắn lại thì hạt có thể chồng)
		return
	var speed := clampf(dy * BEAD_SPEED_PER_PX, -BEAD_MAX_SPEED, BEAD_MAX_SPEED)   # phần dây / giây, > 0 là về phía người chơi 2
	var s := _spacing()                 # khoảng cách tối thiểu
	beads.sort_custom(func(x: Bead, y: Bead) -> bool: return x.t < y.t)   # xếp theo vị trí
	var n := beads.size()               # số hạt
	if speed > 0.0:                     # về phía t = 1: xử lý hạt ở xa đầu kia trước để chúng dồn lại đúng thứ tự
		for i in range(n - 1, -1, -1):  # từ hạt gần đầu người chơi 2 nhất
			var bead: Bead = beads[i]   # hạt này
			var limit: float = (1.0 - BEAD_END) if i == n - 1 else beads[i + 1].t - s   # chặn bởi hạt phía trước
			if bead.lock <= 0.0:        # không bị khoá
				bead.t = maxf(bead.t, minf(bead.t + speed * delta, limit))   # tiến tới, không vượt chặn, không lùi
	else:                               # về phía t = 0
		for i in n:                     # từ hạt gần đầu người chơi 1 nhất
			var bead: Bead = beads[i]   # hạt này
			var limit: float = BEAD_END if i == 0 else beads[i - 1].t + s   # chặn bởi hạt phía trước
			if bead.lock <= 0.0:        # không bị khoá
				bead.t = minf(bead.t, maxf(bead.t + speed * delta, limit))   # lùi tới, không vượt chặn, không tiến


# ---- Vẽ ----

## Ảnh hạt: ngôi sao vàng 7 x 7 có viền nâu, vẽ phóng to khi dùng. Tạo một lần.
static func bead_texture() -> ImageTexture:
	if _bead_tex != null:               # đã có
		return _bead_tex
	var pattern: Array = Hud.STAR       # hình ngôi sao 7 x 7 của HUD (chuỗi "0" / "1")
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)   # ảnh 9 x 9 trong suốt (chừa 1 điểm viền)
	for y in 9:                         # từng điểm ảnh
		for x in 9:
			var on := _star_on(pattern, x - 1, y - 1)   # điểm này thuộc ngôi sao không
			if on:                      # thân ngôi sao
				img.set_pixel(x, y, Color("#ffe27a") if y <= 3 else Color("#f7d046"))   # nửa trên sáng hơn
			elif _star_on(pattern, x - 2, y - 1) or _star_on(pattern, x, y - 1) or _star_on(pattern, x - 1, y - 2) or _star_on(pattern, x - 1, y):   # kề ngôi sao
				img.set_pixel(x, y, Color("#6b4b0a"))   # viền nâu
	_bead_tex = ImageTexture.create_from_image(img)   # đổi thành ảnh vẽ được
	return _bead_tex


## Điểm (x, y) của hình ngôi sao `pattern` có tô không (ngoài hình là không).
static func _star_on(pattern: Array, x: int, y: int) -> bool:
	return y >= 0 and y < pattern.size() and x >= 0 and x < String(pattern[y]).length() and pattern[y][x] == "1"


## Vẽ dây (viền tối + lõi sáng, các điểm bám lưới 2 pixel cho ra kiểu pixel; căng thì ngả đỏ), các hạt, biểu tượng neo.
func _draw() -> void:
	if cut or ball_a == null or ball_b == null:   # đứt hoặc chưa gắn
		return
	var pts := PackedVector2Array()     # các điểm dọc dây
	for i in SEGMENTS + 1:              # từ đầu bóng 1 tới đầu bóng 2
		pts.append(to_local(point_at(float(i) / SEGMENTS)).snapped(Vector2(2.0, 2.0)))   # bám lưới pixel
	var taut := clampf(_tension / 2400.0, 0.0, 1.0)   # 0 = chùng, 1 = căng hết cỡ
	draw_polyline(pts, Color("#2e1f0e"), 8.0)         # viền tối
	draw_polyline(pts, Color("#c9a45c").lerp(Color("#e8455a"), taut), 4.0)   # lõi dây, căng thì ngả đỏ
	var tex := bead_texture()           # ảnh hạt
	for bead: Bead in beads:            # từng hạt
		var center := to_local(point_at(bead.t)).snapped(Vector2(2.0, 2.0))   # vị trí trên dây
		var grow: float = 1.0 + bead.pop * 2.0   # mới xuất hiện / bị cướp thì to hơn
		var size_px: Vector2 = Vector2(18.0, 18.0) * grow   # ảnh 9 x 9 phóng gấp 2
		draw_texture_rect(tex, Rect2(center - size_px / 2.0, size_px), false)   # vẽ hạt
	for i in 2:                         # biểu tượng neo trên đầu người đang neo
		if _anchored[i]:                # đang neo
			var ball: Ball = ball_a if i == 0 else ball_b   # bóng này
			var bob := sin(_time * 6.0) * 2.0   # nhấp nhô nhẹ
			PixelArt.draw_centered(self, PixelArt.ANCHOR, to_local(ball.global_position) + Vector2(0.0, -72.0 * ball.size_factor + bob).snapped(Vector2(2.0, 2.0)), ANCHOR_ICON_PX)
