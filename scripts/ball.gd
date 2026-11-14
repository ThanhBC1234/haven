class_name Ball
extends RigidBody2D
## Con lật đật (nhân vật chính). Điều khiển:
##   - Giữ A (hoặc ←): nghiêng dần sang TRÁI, tích lực. Giữ D (hoặc →): nghiêng dần sang PHẢI.
##   - Bấm Space / W / ↑: NHẢY theo hướng và lực đang tích. Giữ càng lâu thì nhảy càng mạnh, càng xa.
##   - Thả A/D mà không bấm nhảy: lật đật đứng thẳng lại, không nhảy (đổi ý).
##   - Bấm nhảy khi không giữ A/D: nhảy thẳng lên với lực `straight_jump`.
##   - Chỉ nhảy được khi đang chạm đất (bấm sớm một chút trước khi chạm đất vẫn tính).
##   - Rơi xuống thì nảy như bóng thật (thấp dần rồi đứng yên), thân lắc lư kiểu lật đật.
## Là RigidBody2D nên Godot tự tính vật lý. Độ nảy chỉnh ở Physics Material của scenes/ball.tscn (Bounce).
## Các con số chỉnh cảm giác: chọn scenes/ball.tscn rồi sửa ở Inspector.

signal hurt       # bị thương (gai, quái, rơi vực); play.gd nghe để trừ mạng
signal launched   # vừa nhảy (để gắn âm thanh, hoạt ảnh)
signal landed(impact_speed: float)   # vừa chạm đất, kèm tốc độ rơi (để hoạt ảnh bẹp, âm thanh)
signal shield_changed(on: bool)      # có / mất khiên (HUD hiện biểu tượng)
signal ammo_changed(ammo: int)       # số đạn thay đổi (HUD hiện số đạn)
signal shot                          # vừa bắn (để gắn âm thanh)

const BULLET_SCENE := preload("res://scenes/objects/player_bullet.tscn")

@export var radius := 15.0              # bán kính thân (pixel); 1 ô = 32 pixel

@export_group("Nghiêng và nhảy")
@export var charge_time := 0.7          # giữ phím bao lâu thì nghiêng tối đa (giây)
@export var min_tilt_deg := 12.0        # góc nhảy khi bấm nhanh (tính từ phương thẳng đứng)
@export var max_tilt_deg := 42.0        # góc nhảy khi giữ đủ lâu
@export var min_speed := 300.0          # lực nhảy khi bấm nhanh (nhún nhỏ, khoảng 1 ô)
@export var max_speed := 950.0          # lực nhảy khi giữ đủ lâu (cao khoảng 5.5 ô)
@export var coyote_time := 0.12         # vừa nảy khỏi mặt đất vẫn nhảy được trong 0.12 giây
@export var release_buffer := 0.15      # bấm nhảy khi còn trên không, chạm đất trong 0.15 giây vẫn nhảy
@export var straight_jump := 0.5        # lực (0..1) khi nhảy thẳng lên (bấm nhảy mà không giữ A/D)

@export_group("Lắc lư")
@export var wobble_stiffness := 120.0   # lò xo kéo thân về thẳng đứng (lớn = lắc nhanh)
@export var wobble_damping := 6.0       # giảm lắc (lớn = mau đứng yên)

@export_group("Súng và khiên")
@export var shoot_cooldown := 0.18      # thời gian chờ giữa 2 phát bắn
@export var max_ammo := 99
@export var invuln_after_hit := 1.2     # sau khi bị đánh (hoặc vỡ khiên) được miễn sát thương bao lâu

@export var show_placeholder := false   # vẽ hình tạm bằng code; tắt khi đã có hình thật (node Sprite)

var on_ground := false        # đang chạm đất không (tính lại mỗi khung vật lý)
var dead := false             # đang chờ hồi sinh: không điều khiển, không bị thương
var charge := 0.0             # 0..1: đã giữ phím được bao nhiêu phần của charge_time
var charge_dir := 0           # -1 đang giữ A (nghiêng trái), 1 đang giữ D (nghiêng phải), 0 không giữ
var tilt := 0.0               # góc nghiêng đang hiển thị của thân (radian), chỉ để vẽ
var _tilt_vel := 0.0          # vận tốc lắc lư của thân
var _coyote := 0.0
var _jump_request := {}       # cú nhảy đang chờ chạm đất: {"dir": -1/1, "charge": 0..1, "time": giây còn lại}
var _was_on_ground := false
var _last_vy := 0.0          # vận tốc rơi ở khung trước (để biết chạm đất mạnh cỡ nào)
var _teleport_to = null       # vị trí cần dịch tới ở khung vật lý tới (Vector2 hoặc null)
var _bounce := 0.0            # > 0: khung vật lý tới sẽ bật lên với vận tốc này
var ammo := 0                 # số đạn đang có (nhặt súng để có đạn)
var has_shield := false       # đang có khiên: đỡ được 1 đòn
var invuln := 0.0             # còn miễn sát thương bao lâu (nhấp nháy)
var facing := 1               # hướng đang quay mặt (1 phải, -1 trái), để bắn ngang
var _shoot_timer := 0.0
var _time := 0.0


## Chạy một lần khi nhân vật được tạo.
func _ready() -> void:
	add_to_group("ball")
	contact_monitor = true                           # bật để biết đang chạm vào đâu
	max_contacts_reported = 8
	can_sleep = false
	lock_rotation = true                             # lật đật không lăn: thân thật luôn đứng thẳng
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE  # chống xuyên tường khi bay nhanh


## Godot gọi 60 lần mỗi giây: đọc phím, tích lực, cập nhật lắc lư.
func _physics_process(delta: float) -> void:
	if not dead:
		_read_input(delta)
	if not _jump_request.is_empty():
		_jump_request["time"] -= delta
		if _jump_request["time"] <= 0.0:
			_jump_request = {}                       # quá lâu không chạm đất: bỏ cú nhảy
	_coyote = maxf(0.0, _coyote - delta)
	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	invuln = maxf(0.0, invuln - delta)
	_time += delta
	if charge_dir != 0:
		facing = charge_dir                          # quay mặt theo hướng đang nghiêng
	elif absf(linear_velocity.x) > 40.0:
		facing = 1 if linear_velocity.x > 0.0 else -1
	if not dead and Input.is_action_just_pressed("shoot"):
		shoot()
	modulate.a = (0.35 if int(_time * 14.0) % 2 == 0 else 1.0) if invuln > 0.0 else 1.0   # nhấp nháy khi miễn sát thương
	_update_wobble(delta)
	queue_redraw()


## Bắn một viên đạn. Đang giữ A/D thì bắn theo mũi tên (chéo lên), không thì bắn ngang theo hướng quay mặt.
func shoot() -> void:
	if ammo <= 0 or _shoot_timer > 0.0 or dead:
		return
	_shoot_timer = shoot_cooldown
	ammo -= 1
	ammo_changed.emit(ammo)
	var dir := Vector2(facing, 0)
	if charge_dir != 0:
		dir = jump_velocity(charge_dir, maxf(charge, 0.3)).normalized()
	var b: Node2D = BULLET_SCENE.instantiate()
	b.direction = dir
	b.position = global_position + Vector2(0, -2) + dir * 22.0   # bắn ngang tầm trái banh để trúng quái thấp
	get_parent().add_child(b)                         # đạn nằm trong thế giới, không bay theo nhân vật
	shot.emit()


## Nhặt súng: thêm đạn.
func add_ammo(n: int) -> void:
	ammo = mini(max_ammo, ammo + n)
	ammo_changed.emit(ammo)


## Nhặt khiên.
func give_shield() -> void:
	has_shield = true
	shield_changed.emit(true)


## Giữ A/D để nghiêng và tích lực; bấm Space/W/↑ để nhảy; thả A/D mà không nhảy thì hủy.
func _read_input(delta: float) -> void:
	var left := Input.is_action_pressed("left")
	var right := Input.is_action_pressed("right")
	# Xét phím nhảy TRƯỚC: thả A/D và bấm nhảy cùng lúc vẫn nhảy theo hướng đang nghiêng.
	if Input.is_action_just_pressed("jump"):
		if charge_dir != 0:
			jump(charge_dir, charge)                          # nhảy theo hướng đang nghiêng
		else:
			jump(0, straight_jump)                            # không giữ A/D: nhảy thẳng lên
		charge_dir = 0
		charge = 0.0
		return
	if charge_dir == 0:
		if left and not right:
			charge_dir = -1
		elif right and not left:
			charge_dir = 1
		charge = 0.0
	if charge_dir != 0:
		var holding := left if charge_dir < 0 else right
		if holding:
			charge = minf(1.0, charge + delta / charge_time)    # giữ càng lâu càng mạnh
		else:
			charge_dir = 0                                    # thả A/D mà chưa nhảy: hủy, đứng thẳng lại
			charge = 0.0


## Yêu cầu một cú nhảy theo hướng `dir` (-1 trái, 1 phải, 0 thẳng lên) với độ mạnh `amount` (0..1).
## Nhảy ngay nếu đang chạm đất, không thì chờ tối đa release_buffer giây.
func jump(dir: int, amount: float) -> void:
	_jump_request = {"dir": dir, "charge": clampf(amount, 0.0, 1.0), "time": release_buffer}


## Hướng và vận tốc của cú nhảy với độ mạnh `amount`.
func jump_velocity(dir: int, amount: float) -> Vector2:
	var speed := lerpf(min_speed, max_speed, amount)
	if dir == 0:
		return Vector2(0, -speed)                             # nhảy thẳng lên
	var angle := deg_to_rad(lerpf(min_tilt_deg, max_tilt_deg, amount))
	return Vector2(sin(angle) * dir, -cos(angle)) * speed


## Godot gọi trong lúc tính vật lý. Mọi thay đổi vận tốc làm ở đây để không đánh nhau với vật lý.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _teleport_to != null:                         # dịch tới chỗ hồi sinh, đứng yên
		state.transform = Transform2D(0.0, _teleport_to)
		state.linear_velocity = Vector2.ZERO
		_teleport_to = null
		return

	# 1. Chạm đất? Xét các điểm tiếp xúc có pháp tuyến hướng lên trên.
	on_ground = false
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y < -0.6:
			on_ground = true
	if on_ground:
		_coyote = coyote_time
		if not _was_on_ground:
			_tilt_vel += state.linear_velocity.x * 0.02   # chạm đất: thân lắc theo đà ngang
			if _last_vy > 40.0:
				landed.emit(_last_vy)                    # báo chạm đất (kèm tốc độ rơi)
	_was_on_ground = on_ground
	_last_vy = state.linear_velocity.y
	if dead:
		return

	# 2. Nhảy nếu có yêu cầu và đang (hoặc vừa) chạm đất.
	if not _jump_request.is_empty() and _coyote > 0.0:
		state.linear_velocity = jump_velocity(_jump_request["dir"], _jump_request["charge"])
		_tilt_vel += _jump_request["dir"] * -4.0       # bật thẳng người lên khi nhảy
		_jump_request = {}
		_coyote = 0.0
		launched.emit()

	# 3. Bật lên do dẫm quái hoặc lò xo. Đang giữ A/D thì bật chéo theo hướng đó (để không kẹt nảy thẳng mãi).
	if _bounce > 0.0:
		state.linear_velocity.y = -_bounce
		if charge_dir != 0:
			state.linear_velocity.x = charge_dir * lerpf(180.0, 360.0, charge)
		_bounce = 0.0
		_coyote = 0.0


## Lắc lư kiểu lật đật: lúc giữ phím thì nghiêng theo lực, thả ra thì lò xo kéo về thẳng.
func _update_wobble(delta: float) -> void:
	if charge_dir != 0 and not dead:
		var target := charge_dir * deg_to_rad(lerpf(min_tilt_deg, max_tilt_deg, charge))
		tilt = lerpf(tilt, target, 0.3)
		_tilt_vel = 0.0
		return
	_tilt_vel += (-wobble_stiffness * tilt - wobble_damping * _tilt_vel) * delta
	tilt += _tilt_vel * delta


## Dịch tới `pos` (dùng khi hồi sinh).
func teleport(pos: Vector2) -> void:
	_teleport_to = pos
	charge_dir = 0
	charge = 0.0
	_jump_request = {}


## Bật lên với vận tốc `speed` (quái gọi khi bị dẫm, lò xo gọi khi chạm).
func bounce_up(speed: float) -> void:
	_bounce = speed


## Bị thương. Đồ vật nguy hiểm gọi hàm này; play.gd quyết định trừ mạng, hồi sinh.
## Có khiên thì khiên vỡ thay (không mất mạng); vừa bị đánh thì được miễn sát thương một lúc.
func take_hit() -> void:
	if dead or invuln > 0.0:
		return
	if has_shield:
		has_shield = false
		invuln = invuln_after_hit
		shield_changed.emit(false)
		return
	hurt.emit()


## Vẽ: thân lật đật (nếu bật show_placeholder) và mũi tên lực nhảy khi đang giữ phím (luôn vẽ).
func _draw() -> void:
	var base := Vector2(0, radius)                   # lật đật nghiêng quanh điểm chạm đất
	draw_set_transform(base, tilt)
	if show_placeholder:
		# Theo mẫu của nhóm: trái banh đỏ sẫm có chấm sáng, ngồi trên đế vàng nửa vòng tròn.
		var base_color := Color("#e3a72a")             # đế vàng
		var ball_color := Color("#8e1418")             # banh đỏ sẫm
		var base_center := Vector2(0, -radius + 1)     # tâm của nửa vòng tròn đế
		var cup := PackedVector2Array()
		for i in 17:                                   # nửa vòng tròn phía dưới (đáy chạm đất)
			var a := PI * i / 16.0
			cup.append(base_center + Vector2(cos(a), sin(a)) * (radius - 1))
		draw_colored_polygon(cup, base_color)
		draw_polyline(cup + PackedVector2Array([cup[0]]), base_color.darkened(0.4), 1.5)
		var ball_center := Vector2(0, -radius - 4)     # banh nằm trên đế
		var ball_r := radius * 0.7
		draw_circle(ball_center, ball_r, ball_color)
		draw_arc(ball_center, ball_r - 1.5, PI * 0.9, PI * 1.6, 10, ball_color.lightened(0.25), 2.0)   # viền sáng phía trên trái
		draw_arc(ball_center, ball_r, 0.0, TAU, 24, ball_color.darkened(0.5), 1.0)
		draw_circle(ball_center + Vector2(-ball_r * 0.35, -ball_r * 0.4), 2.0, Color.WHITE)   # chấm sáng
	draw_set_transform(Vector2.ZERO)
	if has_shield and not dead:                      # khiên: vòng tròn pixel xanh ngọc bao quanh nhân vật
		var center := Vector2(0, -17)
		for i in 28:
			var a := TAU * i / 28.0 + _time * 0.8
			var p := center + Vector2(cos(a), sin(a)) * 38.0
			var col := Color("#7fd6e0") if i % 2 == 0 else Color("#3c8ea0")
			draw_rect(Rect2(p.snapped(Vector2(2, 2)) - Vector2(2, 2), Vector2(4, 4)), Color(col, 0.75))
	if charge_dir != 0 and not dead:                 # mũi tên: hướng và độ mạnh cú nhảy
		var v := jump_velocity(charge_dir, charge)
		var start := v.normalized() * (radius + 4.0)                  # bắt đầu từ mép thân, không đè lên banh
		var tip := v.normalized() * (radius + 14.0 + 30.0 * charge)   # càng giữ lâu mũi tên càng dài
		var col := Color(1, 1, 1, 0.85).lerp(Color("#ff5d5d"), charge)
		draw_line(start, tip, col, 3.0)
		var side := tip.normalized().orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([tip + tip.normalized() * 6.0, tip + side, tip - side]), col)
