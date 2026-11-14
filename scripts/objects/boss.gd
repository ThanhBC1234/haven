class_name Boss
extends Node2D
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

signal hp_changed(hp: int, max_hp: int)
signal died

enum State { SLEEP, ROLL, WARN, CHARGE, DIZZY }

@export var boss_name := "GLOOMFANG"
@export var max_hp := 12                     # số máu (mỗi phát bắn hoặc mỗi lần dẫm trừ 1)
@export var wake_distance := 600.0           # người chơi cách bao xa (theo chiều ngang) thì boss tỉnh
@export var roam := 448.0                    # chỉ lăn trong khoảng này quanh chỗ đặt (14 ô mỗi bên), như có tường vô hình

@export_group("Lăn và lao")
@export var roll_speed := 70.0               # tốc độ lăn bình thường (pixel/giây)
@export var phase2_roll_speed := 110.0
@export var charge_speed := 240.0            # tốc độ lao
@export var phase2_charge_speed := 300.0
@export var charge_every := 4.5              # lăn bao lâu thì lao một lần
@export var phase2_charge_every := 3.2
@export var warn_time := 1.0                 # rung lắc cảnh báo bao lâu trước khi lao
@export var dizzy_time := 2.0                # choáng bao lâu sau khi đâm tường

@export_group("Dẫm và hình")
@export var stomp_bounce := 620.0            # dẫm lên đầu boss thì người chơi bật lên với vận tốc này
@export var radius := 30.0                   # bán kính thân (khớp hình 16 x 16 điểm x 4 = 64 pixel)
@export var pixel_size := 4.0
@export var show_placeholder := true

var hp := 0
var dead := false
var state := State.SLEEP
var dir := -1                                # -1 lăn sang trái, 1 lăn sang phải
var _timer := 0.0
var _spin := 0.0                             # góc xoay khi lăn (để vẽ)
var _flash := 0.0                            # nháy trắng khi mất máu
var _t := 0.0
var _home_x := 0.0                           # chỗ đặt ban đầu (tâm vùng lăn)
var _snapped := false                        # đã đặt sát mặt đất chưa (làm ở khung vật lý đầu tiên)

@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	hp = max_hp
	_home_x = position.x
	hurtbox.body_entered.connect(_on_touch)


## Đặt boss nằm sát mặt đất ngay bên dưới chỗ đặt.
func _snap_to_ground() -> void:
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 600), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit["position"].y - radius


func is_phase2() -> bool:
	return hp <= max_hp / 2


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not _snapped:
		_snapped = true
		_snap_to_ground()                            # khung đầu: đất đã có trong thế giới vật lý
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	var ball := get_tree().get_first_node_in_group("ball") as Ball
	match state:
		State.SLEEP:
			if ball and absf(ball.global_position.x - global_position.x) < wake_distance:
				_wake()
		State.ROLL:
			_roll(phase2_roll_speed if is_phase2() else roll_speed, delta)
			_timer -= delta
			if _timer <= 0.0 and ball and not ball.dead:
				state = State.WARN                       # chuẩn bị lao: dừng lại rung lắc
				_timer = warn_time
				dir = 1 if ball.global_position.x > global_position.x else -1
		State.WARN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHARGE
		State.CHARGE:
			if _roll(phase2_charge_speed if is_phase2() else charge_speed, delta):
				state = State.DIZZY                      # đâm tường: choáng
				_timer = dizzy_time
		State.DIZZY:
			_timer -= delta
			if _timer <= 0.0:
				state = State.ROLL
				_timer = phase2_charge_every if is_phase2() else charge_every
	queue_redraw()


## Lăn một đoạn theo hướng `dir`. Gặp tường / cổng phía trước thì quay đầu và trả về true.
func _roll(speed: float, delta: float) -> bool:
	var step := speed * delta
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (radius + step + 2.0), 0), 1)
	var out_of_area := absf(position.x + dir * step - _home_x) > roam   # ra khỏi vùng lăn: coi như đụng tường
	if out_of_area or not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		dir = -dir
		return true
	position.x += dir * step
	_spin += dir * step / radius                     # quay theo quãng đường lăn
	return false


func _wake() -> void:
	state = State.ROLL
	_timer = 2.0
	var level := Level.of(self)
	if level:
		level.start_boss(self)
	hp_changed.emit(hp, max_hp)


## Mất máu (đạn của người chơi, hoặc bị dẫm).
func take_damage(amount: int) -> void:
	if dead:
		return
	if state == State.SLEEP:
		_wake()
	hp = maxi(0, hp - amount)
	_flash = 0.12
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		_die()


func _die() -> void:
	dead = true
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	died.emit()
	var level := Level.of(self)
	if level:
		level.defeat_boss(self)
	var p := CPUParticles2D.new()                     # nổ thành mảnh pixel
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.0
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 6.0
	p.color = PixelArt.PALETTE["p"]
	p.position = position
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.2), 0.25)
	tw.tween_callback(queue_free)


## Người chơi chạm vào boss: từ trên rơi xuống thì dẫm trúng đầu (boss mất máu), còn lại người chơi bị thương.
func _on_touch(body: Node2D) -> void:
	if dead or not body is Ball or body.dead:
		return
	var from_above: bool = body.global_position.y < global_position.y - radius * 0.5 and body.linear_velocity.y > -60.0
	if from_above:
		body.bounce_up(stomp_bounce)
		take_damage(1)
	else:
		body.take_hit()


func _draw() -> void:
	if not show_placeholder:
		return
	var tint := Color(1.0, 0.65, 0.65) if is_phase2() else Color.WHITE
	if _flash > 0.0:
		tint = Color(3, 3, 3)                        # nháy trắng khi mất máu
	var shake := Vector2(sin(_t * 70.0) * 2.0, 0) if state == State.WARN else Vector2.ZERO
	draw_set_transform(shake, _spin)
	PixelArt.draw_centered(self, PixelArt.BOSS, Vector2.ZERO, pixel_size, tint)
	draw_set_transform(Vector2.ZERO)
	if state == State.WARN:                           # dấu ! đỏ: sắp lao
		PixelArt.draw_centered(self, PixelArt.EXCLAIM, Vector2(0, -radius - 26), 4.0)
	elif state == State.DIZZY:                        # sao vàng quay: đang choáng
		for i in 3:
			var a := _t * 5.0 + i * TAU / 3.0
			var p := Vector2(cos(a) * 22.0, -radius - 10 + sin(a) * 6.0)
			draw_rect(Rect2(p.snapped(Vector2(2, 2)) - Vector2(3, 3), Vector2(6, 6)), PixelArt.PALETTE["y"])
