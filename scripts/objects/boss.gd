class_name Boss                             # tên lớp để file khác dùng "is Boss"
extends Node2D                              # boss tự di chuyển bằng code, không dùng thân vật lý
## Boss "GLOOMFANG": quả cầu quái vật CHỈ LĂN TRÊN MẶT ĐẤT (không bay, không bắn).
## Vòng hành động:
##   1. LĂN qua lại chậm rãi, đụng tường / cổng thì quay đầu.
##   2. CẢNH BÁO: dừng lại, rung lắc, hiện dấu "!" đỏ trên đầu (người chơi chuẩn bị nhảy).
##   3. LAO NHANH về phía người chơi cho tới khi đâm tường.
##   4. CHOÁNG: đứng yên, sao quay trên đầu. Đây là lúc dễ đánh nhất.
## Cách đánh: bắn (F / J) - boss ở ngang mặt đất nên bắn ngang là trúng; hoặc nhảy dẫm lên đầu (trừ 1 máu, bật lên).
## Chạm vào thân boss (không phải từ trên xuống) thì người chơi bị thương.
## Còn nửa máu thì sang giai đoạn 2: đỏ lên, lăn và lao nhanh hơn, lao thường hơn.
## Hết máu: nổ, báo Level mở cổng G. Đổi hình: thêm Sprite2D vào scenes/objects/boss.tscn, tắt show_placeholder.

signal hp_changed(hp: int, max_hp: int)     # báo máu thay đổi (để thanh máu cập nhật)
signal died                                 # báo boss đã chết

enum State { SLEEP, ROLL, WARN, CHARGE, DIZZY }   # các trạng thái: ngủ, lăn, cảnh báo, lao, choáng

@export var boss_name := "MAX VERSTAPPEN"   # tên hiện trên thanh máu boss
@export var max_hp := 24                     # số máu (mỗi phát bắn hoặc mỗi lần dẫm trừ 1)
@export var wake_distance := 800.0           # người chơi cách bao xa (theo chiều ngang) thì boss tỉnh
@export var roam := 448.0                    # chỉ lăn trong khoảng này quanh chỗ đặt (14 ô mỗi bên), như có tường vô hình

@export_group("Lăn và lao")                  # nhóm thông số di chuyển trong Inspector
@export var roll_speed := 100.0              # tốc độ lăn bình thường (pixel/giây)
@export var phase2_roll_speed := 150.0       # tốc độ lăn ở giai đoạn 2
@export var charge_speed := 240.0            # tốc độ lao
@export var phase2_charge_speed := 300.0     # tốc độ lao ở giai đoạn 2
@export var charge_every := 5.0              # lăn bao lâu thì lao một lần
@export var phase2_charge_every := 3.2       # giai đoạn 2 lao thường xuyên hơn
@export var warn_time := 0.5                 # rung lắc cảnh báo bao lâu trước khi lao
@export var dizzy_time := 1.0                # choáng bao lâu sau khi đâm tường

@export_group("Dẫm và hình")                 # nhóm thông số dẫm và hình vẽ
@export var stomp_bounce := 620.0            # dẫm lên đầu boss thì người chơi bật lên với vận tốc này
@export var radius := 30.0                   # bán kính thân (khớp hình 16 x 16 điểm x 4 = 64 pixel)
@export var pixel_size := 4.0                # mỗi điểm ảnh pixel art vẽ to 4 pixel
@export var show_placeholder := true         # bật thì tự vẽ hình boss tạm

var hp := 0                                  # máu hiện tại
var dead := false                            # boss đã chết chưa
var state := State.SLEEP                     # trạng thái hiện tại, bắt đầu là ngủ
var dir := -1                                # -1 lăn sang trái, 1 lăn sang phải
var _timer := 0.0                            # đồng hồ đếm ngược cho trạng thái hiện tại
var _spin := 0.0                             # góc xoay khi lăn (để vẽ)
var _flash := 0.0                            # nháy trắng khi mất máu
var _t := 0.0                                # tổng thời gian đã chạy (cho hiệu ứng)
var _home_x := 0.0                           # chỗ đặt ban đầu (tâm vùng lăn)
var _snapped := false                        # đã đặt sát mặt đất chưa (làm ở khung vật lý đầu tiên)

@onready var hurtbox: Area2D = $Hurtbox      # vùng chạm: nhận đạn và va chạm với người chơi


func _ready() -> void:
	hp = max_hp                                  # bắt đầu đầy máu
	_home_x = position.x                         # nhớ chỗ đặt làm tâm vùng lăn
	hurtbox.body_entered.connect(_on_touch)      # người chơi chạm vào thì gọi _on_touch


## Đặt boss nằm sát mặt đất ngay bên dưới chỗ đặt.
func _snap_to_ground() -> void:
	var from := global_position                  # bắn tia từ tâm boss
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 600), 1)   # tia thẳng xuống, chỉ xét đất
	var hit := get_world_2d().direct_space_state.intersect_ray(query)   # tìm điểm chạm đất
	if not hit.is_empty():                       # có đất bên dưới
		global_position.y = hit["position"].y - radius   # đặt boss ngồi ngay trên mặt đất


func is_phase2() -> bool:
	return hp <= max_hp / 2                      # còn nửa máu trở xuống là giai đoạn 2


func _physics_process(delta: float) -> void:
	if dead:                                     # chết rồi thì không làm gì nữa
		return
	if not _snapped:                             # chưa đặt sát đất
		_snapped = true                          # chỉ làm một lần
		_snap_to_ground()                            # khung đầu: đất đã có trong thế giới vật lý
	_t += delta                                  # cộng dồn thời gian
	_flash = maxf(0.0, _flash - delta)           # hiệu ứng nháy trắng giảm dần
	var ball := get_tree().get_first_node_in_group("ball") as Ball   # tìm người chơi
	match state:                                 # làm việc theo trạng thái hiện tại
		State.SLEEP:
			# người chơi lại đủ gần theo chiều ngang thì boss tỉnh dậy
			if ball and absf(ball.global_position.x - global_position.x) < wake_distance:
				_wake()                          # thức dậy và bắt đầu trận đấu
		State.ROLL:
			_roll(phase2_roll_speed if is_phase2() else roll_speed, delta)   # lăn qua lại
			_timer -= delta                      # đếm ngược tới lần lao tiếp theo
			if _timer <= 0.0 and ball and not ball.dead:   # đến giờ lao và người chơi còn sống
				state = State.WARN                       # chuẩn bị lao: dừng lại rung lắc
				_timer = warn_time               # rung lắc trong bao lâu
				dir = 1 if ball.global_position.x > global_position.x else -1   # quay mặt về phía người chơi
		State.WARN:
			_timer -= delta                      # đếm ngược thời gian cảnh báo
			if _timer <= 0.0:                    # hết thời gian cảnh báo
				state = State.CHARGE             # bắt đầu lao
		State.CHARGE:
			# lao nhanh; hàm trả về true khi đâm tường
			if _roll(phase2_charge_speed if is_phase2() else charge_speed, delta):
				state = State.DIZZY                      # đâm tường: choáng
				_timer = dizzy_time              # choáng trong bao lâu
		State.DIZZY:
			_timer -= delta                      # đếm ngược thời gian choáng
			if _timer <= 0.0:                    # hết choáng
				state = State.ROLL               # quay lại lăn bình thường
				_timer = phase2_charge_every if is_phase2() else charge_every   # hẹn giờ lao lần sau
	queue_redraw()                               # vẽ lại boss mỗi khung hình


## Lăn một đoạn theo hướng `dir`. Gặp tường / cổng phía trước thì quay đầu và trả về true.
func _roll(speed: float, delta: float) -> bool:
	var step := speed * delta                    # quãng đường lăn trong khung hình này
	var from := global_position                  # tia bắn ra từ tâm boss
	# tia ngang hướng về phía trước, dài hơn bán kính một chút, chỉ xét đất/tường
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (radius + step + 2.0), 0), 1)
	var out_of_area := absf(position.x + dir * step - _home_x) > roam   # ra khỏi vùng lăn: coi như đụng tường
	if out_of_area or not get_world_2d().direct_space_state.intersect_ray(query).is_empty():   # sắp ra ngoài hoặc có tường
		dir = -dir                               # quay đầu
		return true                              # báo là vừa đụng tường
	position.x += dir * step                     # lăn tới
	_spin += dir * step / radius                     # quay theo quãng đường lăn
	return false                                 # chưa đụng gì


func _wake() -> void:
	state = State.ROLL                           # tỉnh dậy thì bắt đầu lăn
	_timer = 2.0                                 # lăn 2 giây rồi mới lao lần đầu
	var level := Level.of(self)                  # tìm màn chơi chứa boss
	if level:                                    # nếu có màn chơi
		level.start_boss(self)                   # báo màn chơi: bắt đầu đánh boss (hiện thanh máu)
	hp_changed.emit(hp, max_hp)                  # gửi máu hiện tại cho thanh máu


## Mất máu (đạn của người chơi, hoặc bị dẫm).
func take_damage(amount: int) -> void:
	if dead:                                     # chết rồi thì không trừ nữa
		return
	if state == State.SLEEP:                     # đang ngủ mà bị bắn
		_wake()                                  # thì tỉnh dậy luôn
	hp = maxi(0, hp - amount)                    # trừ máu, không cho xuống dưới 0
	_flash = 0.12                                # nháy trắng một chút
	hp_changed.emit(hp, max_hp)                  # báo thanh máu cập nhật
	if hp == 0:                                  # hết máu
		_die()                                   # thì chết


func _die() -> void:
	dead = true                                  # đánh dấu đã chết
	hurtbox.set_deferred("monitoring", false)    # ngừng phát hiện người chơi
	hurtbox.set_deferred("monitorable", false)   # đạn không trúng được nữa
	died.emit()                                  # phát tín hiệu boss chết
	var level := Level.of(self)                  # tìm màn chơi
	if level:                                    # nếu có màn chơi
		level.defeat_boss(self)                  # báo thắng boss (mở cổng)
	var p := CPUParticles2D.new()                     # nổ thành mảnh pixel
	p.one_shot = true                            # chỉ nổ một lần
	p.amount = 40                                # 40 mảnh vụn
	p.lifetime = 1.0                             # mỗi mảnh sống 1 giây
	p.explosiveness = 1.0                        # tất cả mảnh bắn ra cùng lúc
	p.spread = 180.0                             # bắn ra mọi hướng
	p.initial_velocity_min = 120.0               # tốc độ bay ra nhỏ nhất
	p.initial_velocity_max = 320.0               # tốc độ bay ra lớn nhất
	p.gravity = Vector2(0, 500)                  # mảnh vụn rơi xuống
	p.scale_amount_min = 4.0                     # kích thước mảnh nhỏ nhất
	p.scale_amount_max = 6.0                     # kích thước mảnh lớn nhất
	p.color = PixelArt.PALETTE["p"]              # màu mảnh lấy từ bảng màu pixel art
	p.position = position                        # nổ ngay chỗ boss
	get_parent().add_child(p)                    # thêm vào màn (không gắn vào boss sắp bị xoá)
	p.emitting = true                            # bắt đầu nổ
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)   # 1.5 giây sau xoá hiệu ứng nổ
	var tw := create_tween()                     # hiệu ứng boss bẹp xuống
	tw.tween_property(self, "scale", Vector2(1.4, 0.2), 0.25)   # bẹp dẹt trong 0.25 giây
	tw.tween_callback(queue_free)                # xong thì xoá boss


## Người chơi chạm vào boss: từ trên rơi xuống thì dẫm trúng đầu (boss mất máu), còn lại người chơi bị thương.
func _on_touch(body: Node2D) -> void:
	if dead or not body is Ball or body.dead:    # chỉ xét người chơi còn sống
		return
	# người chơi ở cao hơn nửa thân boss và không đang bay vọt lên = dẫm từ trên
	var from_above: bool = body.global_position.y < global_position.y - radius * 0.5 and body.linear_velocity.y > -60.0
	if from_above:                               # dẫm trúng đầu
		body.bounce_up(stomp_bounce)             # người chơi bật lên
		take_damage(1)                           # boss mất 1 máu
	else:
		body.take_hit()                          # đụng ngang: người chơi bị thương


func _draw() -> void:
	if not show_placeholder:                     # đã có hình thật thì không vẽ tạm
		return
	var tint := Color(1.0, 0.65, 0.65) if is_phase2() else Color.WHITE   # giai đoạn 2 thì ửng đỏ
	if _flash > 0.0:                             # đang trong lúc nháy
		tint = Color(3, 3, 3)                        # nháy trắng khi mất máu
	var shake := Vector2(sin(_t * 70.0) * 2.0, 0) if state == State.WARN else Vector2.ZERO   # rung ngang khi cảnh báo
	draw_set_transform(shake, _spin)             # dịch theo độ rung và xoay theo vòng lăn
	PixelArt.draw_centered(self, PixelArt.BOSS, Vector2.ZERO, pixel_size, tint)   # vẽ thân boss pixel art
	draw_set_transform(Vector2.ZERO)             # trả về bình thường cho các hình sau
	if state == State.WARN:                           # dấu ! đỏ: sắp lao
		PixelArt.draw_centered(self, PixelArt.EXCLAIM, Vector2(0, -radius - 26), 4.0)   # vẽ dấu ! trên đầu
	elif state == State.DIZZY:                        # sao vàng quay: đang choáng
		for i in 3:                                   # 3 ngôi sao
			var a := _t * 5.0 + i * TAU / 3.0         # góc mỗi sao, cách đều nhau và quay theo thời gian
			var p := Vector2(cos(a) * 22.0, -radius - 10 + sin(a) * 6.0)   # vị trí sao trên vòng elip
			# vẽ ô vuông vàng 6x6, làm tròn vị trí để trông pixel
			draw_rect(Rect2(p.snapped(Vector2(2, 2)) - Vector2(3, 3), Vector2(6, 6)), PixelArt.PALETTE["y"])
