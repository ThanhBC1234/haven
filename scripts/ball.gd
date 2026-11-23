class_name Ball                         # tên lớp để file khác dùng "is Ball"
extends RigidBody2D                     # thân vật lý: Godot tự tính rơi, nảy, va chạm
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
signal boost_changed(seconds_left: float)   # jump boost còn bao lâu (0 = hết); HUD hiện thanh đếm ngược
signal use_pressed                   # (2 người chơi) vừa bấm phím "use" của mình; chế độ chơi quyết định "use" làm gì
signal stomped(victim: Ball)         # (2 người chơi) vừa đáp từ trên xuống đầu một quả bóng khác

const BULLET_SCENE := preload("res://scenes/objects/player_bullet.tscn")   # cảnh viên đạn, nạp sẵn để bắn
const JUMP_BOOST_TEXTURE := preload("res://assets/items/jump_boost.png")   # ảnh mũi tên xanh dưới chân
const BALL_LAYER := 2                   # lớp va chạm của các quả bóng (bit giá trị 2), dùng cho set_collide_with_balls
# Người chơi 2 đổi màu bằng cách hoán đổi kênh đỏ và xanh dương của hình (đỏ sẫm thành xanh sẫm, nâu thành xanh nhạt).
const SWAP_RB_CODE := "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR.rgb = COLOR.bgr;\n}\n"   # mã shader hoán đổi màu

static var _swap_rb_shader: Shader = null   # shader dùng chung cho mọi quả bóng của người chơi 2

@export var radius := 15.0              # bán kính thân (pixel); 1 ô = 32 pixel

@export_group("Nghiêng và nhảy")        # gom các biến dưới thành nhóm trong Inspector
@export var charge_time := 0.7          # giữ phím bao lâu thì nghiêng tối đa (giây)
@export var min_tilt_deg := 12.0        # góc nhảy khi bấm nhanh (tính từ phương thẳng đứng)
@export var max_tilt_deg := 42.0        # góc nhảy khi giữ đủ lâu
@export var min_speed := 300.0          # lực nhảy khi bấm nhanh (nhún nhỏ, khoảng 1 ô)
@export var max_speed := 950.0          # lực nhảy khi giữ đủ lâu (cao khoảng 5.5 ô)
@export var coyote_time := 0.12         # vừa nảy khỏi mặt đất vẫn nhảy được trong 0.12 giây
@export var release_buffer := 0.15      # bấm nhảy khi còn trên không, chạm đất trong 0.15 giây vẫn nhảy
@export var straight_jump := 0.5        # lực (0..1) khi nhảy thẳng lên (bấm nhảy mà không giữ A/D)

@export_group("Lắc lư")                 # nhóm thông số lắc lư
@export var wobble_stiffness := 120.0   # lò xo kéo thân về thẳng đứng (lớn = lắc nhanh)
@export var wobble_damping := 6.0       # giảm lắc (lớn = mau đứng yên)

@export_group("Súng và khiên")          # nhóm thông số súng và khiên
@export var shoot_cooldown := 0.18      # thời gian chờ giữa 2 phát bắn
@export var max_ammo := 99              # mang tối đa bao nhiêu viên đạn
@export var invuln_after_hit := 1.2     # sau khi bị đánh (hoặc vỡ khiên) được miễn sát thương bao lâu

@export_group("Jump boost")             # nhóm thông số tăng lực nhảy
@export var boost_duration := 10.0     # nhặt mũi tên xanh thì nhảy cao trong bao nhiêu giây
@export var boost_power := 1.25         # lực nhảy nhân lên bấy nhiêu (1.25 = cao gấp khoảng 1.5 lần)

@export var show_placeholder := false   # vẽ hình tạm bằng code; tắt khi đã có hình thật (node Sprite)

@export_group("Hai người chơi")         # nhóm thông số chế độ 2 người
@export var stomp_speed := 300.0        # phải rơi nhanh hơn bấy nhiêu (pixel/giây) mới tính là dẫm đầu bóng khác
@export var stomp_bounce := 260.0       # dẫm xong được nảy lên nhẹ với vận tốc này (nhỏ hơn stomp_speed để không dẫm liên tục)
@export var stomp_cooldown := 0.4       # sau mỗi lần dẫm phải chờ bấy nhiêu giây mới dẫm tiếp được

## Tiền tố tên phím: "" = phím đơn (left/right/jump/shoot), "p1_" / "p2_" = phím riêng của người chơi 1 / 2.
## Đổi tiền tố lúc đang chơi (ví dụ hai người hoán đổi phím) thì bỏ luôn lực đang tích, không bị kẹt.
var action_prefix := "":
	set(value):
		action_prefix = value                        # nhận tiền tố mới
		charge_dir = 0                               # phím cũ có thể đang được giữ: bỏ nghiêng
		charge = 0.0                                 # bỏ lực đã tích
## Đảo phím: true thì phím trái làm nhân vật nghiêng phải và ngược lại.
var reverse_controls := false:
	set(value):
		reverse_controls = value                     # nhận chế độ đảo phím mới
		charge_dir = 0                               # đổi phím giữa lúc đang tích thì hủy, tránh kẹt
		charge = 0.0                                 # bỏ lực đã tích
var player_id := 0            # 0 = chơi một mình, 1 / 2 = người chơi (đặt bằng set_player)
var size_factor := 1.0        # hệ số kích thước hiện tại (đặt bằng set_size)
var bullet_knockback := 0.0   # > 0: đạn bắn ra đẩy lùi quả bóng khác với lực này (không gây sát thương)

var on_ground := false        # đang chạm đất không (tính lại mỗi khung vật lý)
var dead := false             # đang chờ hồi sinh: không điều khiển, không bị thương
var charge := 0.0             # 0..1: đã giữ phím được bao nhiêu phần của charge_time
var charge_dir := 0           # -1 đang giữ A (nghiêng trái), 1 đang giữ D (nghiêng phải), 0 không giữ
var tilt := 0.0               # góc nghiêng đang hiển thị của thân (radian), chỉ để vẽ
var _tilt_vel := 0.0          # vận tốc lắc lư của thân
var _coyote := 0.0            # còn bao lâu được nhảy dù vừa rời đất (thời gian coyote)
var _jump_request := {}       # cú nhảy đang chờ chạm đất: {"dir": -1/1, "charge": 0..1, "time": giây còn lại}
var _was_on_ground := false   # khung trước có chạm đất không (để phát hiện lúc vừa chạm)
var _last_vy := 0.0          # vận tốc rơi ở khung trước (để biết chạm đất mạnh cỡ nào)
var _teleport_to = null       # vị trí cần dịch tới ở khung vật lý tới (Vector2 hoặc null)
var _bounce := 0.0            # > 0: khung vật lý tới sẽ bật lên với vận tốc này
var ammo := 0                 # số đạn đang có (nhặt súng để có đạn)
var has_shield := false       # đang có khiên: đỡ được 1 đòn
var invuln := 0.0             # còn miễn sát thương bao lâu (nhấp nháy)
var facing := 1               # hướng đang quay mặt (1 phải, -1 trái), để bắn ngang
var _shoot_timer := 0.0       # còn bao lâu mới bắn được phát tiếp theo
var boost_time := 0.0         # jump boost còn bao lâu
var _time := 0.0              # tổng thời gian đã chạy (cho hiệu ứng nhấp nháy)
var _kick := Vector2.ZERO     # cú hất đang chờ: khung vật lý tới sẽ cộng vào vận tốc (xem knockback)
var _stomp_cd := 0.0          # còn bao lâu mới được dẫm tiếp
var _touching_balls := {}     # các quả bóng đang chạm ở khung trước: {instance id: true} (để biết lúc VỪA chạm)
var _base_radius := 15.0      # bán kính gốc (size 1.0)
var _base_shape_radius := 15.0   # bán kính gốc của vòng va chạm
var _base_mass := 1.0         # khối lượng gốc
var _shape_copied := false    # đã nhân bản vòng va chạm riêng chưa (vì scene dùng chung một resource cho mọi bóng)


## Chạy một lần khi nhân vật được tạo.
func _ready() -> void:
	add_to_group("ball")                             # vào nhóm "ball" để quái, boss, camera tìm thấy
	contact_monitor = true                           # bật để biết đang chạm vào đâu
	max_contacts_reported = 8                        # ghi nhận tối đa 8 điểm chạm cùng lúc
	can_sleep = false                                # không cho vật lý "ngủ", luôn phản ứng phím
	lock_rotation = true                             # lật đật không lăn: thân thật luôn đứng thẳng
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE  # chống xuyên tường khi bay nhanh
	_base_radius = radius                            # nhớ kích thước gốc để set_size(1.0) khôi phục đúng
	_base_mass = mass                                # nhớ khối lượng gốc
	var shape_node := get_node_or_null("Shape") as CollisionShape2D   # node vòng va chạm
	if shape_node != null and shape_node.shape is CircleShape2D:      # là hình tròn như trong scene
		_base_shape_radius = shape_node.shape.radius                  # nhớ bán kính gốc của vòng va chạm


## Godot gọi 60 lần mỗi giây: đọc phím, tích lực, cập nhật lắc lư.
func _physics_process(delta: float) -> void:
	if not dead:                                     # còn sống mới điều khiển được
		_read_input(delta)                           # đọc phím A/D/nhảy
	if not _jump_request.is_empty():                 # đang có cú nhảy chờ chạm đất
		_jump_request["time"] -= delta               # đếm ngược thời gian chờ
		if _jump_request["time"] <= 0.0:             # hết thời gian chờ
			_jump_request = {}                       # quá lâu không chạm đất: bỏ cú nhảy
	_coyote = maxf(0.0, _coyote - delta)             # thời gian coyote giảm dần về 0
	_shoot_timer = maxf(0.0, _shoot_timer - delta)   # thời gian chờ bắn giảm dần
	_stomp_cd = maxf(0.0, _stomp_cd - delta)         # thời gian chờ dẫm giảm dần
	invuln = maxf(0.0, invuln - delta)               # thời gian miễn sát thương giảm dần
	if boost_time > 0.0:                             # đang có jump boost
		boost_time = maxf(0.0, boost_time - delta)   # đếm ngược thời gian boost
		boost_changed.emit(boost_time)               # báo HUD cập nhật thanh đếm ngược
	_time += delta                                   # cộng dồn thời gian
	if charge_dir != 0:                              # đang giữ A hoặc D
		facing = charge_dir                          # quay mặt theo hướng đang nghiêng
	elif absf(linear_velocity.x) > 40.0:             # đang bay ngang đủ nhanh
		facing = 1 if linear_velocity.x > 0.0 else -1   # quay mặt theo hướng bay
	if not dead and action_prefix.is_empty() and Input.is_action_just_pressed("shoot"):   # chơi một mình: vừa bấm nút bắn
		shoot()                                      # bắn một viên
	elif not dead and not action_prefix.is_empty() and Input.is_action_just_pressed(action_prefix + "use"):   # 2 người: bấm phím "use"
		use_pressed.emit()                           # báo cho chế độ chơi, nó quyết định "use" làm gì
	modulate.a = (0.35 if int(_time * 14.0) % 2 == 0 else 1.0) if invuln > 0.0 else 1.0   # nhấp nháy khi miễn sát thương
	_update_wobble(delta)                            # cập nhật góc lắc lư của thân
	queue_redraw()                                   # vẽ lại mũi tên, khiên...


## Bắn một viên đạn. Đang giữ A/D thì bắn theo mũi tên (chéo lên), không thì bắn ngang theo hướng quay mặt.
func shoot() -> void:
	if ammo <= 0 or _shoot_timer > 0.0 or dead:      # hết đạn, chưa hồi, hoặc đã chết thì thôi
		return
	_shoot_timer = shoot_cooldown                    # bắt đầu chờ trước phát kế
	ammo -= 1                                        # trừ một viên đạn
	ammo_changed.emit(ammo)                          # báo HUD số đạn mới
	var dir := Vector2(facing, 0)                    # mặc định bắn ngang theo hướng mặt
	if charge_dir != 0:                              # đang nghiêng
		dir = jump_velocity(charge_dir, maxf(charge, 0.3)).normalized()   # bắn theo hướng mũi tên nhảy
	var b: Node2D = BULLET_SCENE.instantiate()       # tạo một viên đạn mới
	b.direction = dir                                # cho đạn biết hướng bay
	b.shooter = self                                 # đạn không trúng người bắn
	b.knockback = bullet_knockback                   # > 0: đạn đẩy lùi quả bóng khác
	b.position = global_position + Vector2(0, -2) + dir * 22.0   # bắn ngang tầm trái banh để trúng quái thấp
	get_parent().add_child(b)                         # đạn nằm trong thế giới, không bay theo nhân vật
	shot.emit()                                      # báo vừa bắn (phát âm thanh)


## Nhặt súng: thêm đạn.
func add_ammo(n: int) -> void:
	ammo = mini(max_ammo, ammo + n)                  # cộng đạn nhưng không vượt quá max_ammo
	ammo_changed.emit(ammo)                          # báo HUD số đạn mới


## Nhặt mũi tên xanh: nhảy cao hơn trong boost_duration giây (nhặt tiếp thì làm mới thời gian).
func give_jump_boost() -> void:
	boost_time = boost_duration                      # đặt lại thời gian boost đầy đủ
	boost_changed.emit(boost_time)                   # báo HUD hiện thanh đếm ngược


## Nhặt khiên.
func give_shield() -> void:
	has_shield = true                                # có khiên
	shield_changed.emit(true)                        # báo HUD hiện biểu tượng khiên


## Giữ A/D để nghiêng và tích lực; bấm Space/W/↑ để nhảy; thả A/D mà không nhảy thì hủy.
func _read_input(delta: float) -> void:
	var left := Input.is_action_pressed(_action("left"))      # đang giữ phím trái không
	var right := Input.is_action_pressed(_action("right"))    # đang giữ phím phải không
	if reverse_controls:                             # đảo phím: trái thành phải, phải thành trái
		var tmp := left                              # giữ tạm giá trị phím trái
		left = right                                 # phím phải điều khiển hướng trái
		right = tmp                                  # phím trái điều khiển hướng phải
	# Xét phím nhảy TRƯỚC: thả A/D và bấm nhảy cùng lúc vẫn nhảy theo hướng đang nghiêng.
	if Input.is_action_just_pressed(_action("jump")):         # vừa bấm nhảy
		if charge_dir != 0:                          # đang nghiêng một bên
			jump(charge_dir, charge)                          # nhảy theo hướng đang nghiêng
		else:
			jump(0, straight_jump)                            # không giữ A/D: nhảy thẳng lên
		charge_dir = 0                               # nhảy xong thì thôi nghiêng
		charge = 0.0                                 # xoá lực đã tích
		return
	if charge_dir == 0:                              # chưa nghiêng bên nào
		if left and not right:                       # chỉ giữ trái
			charge_dir = -1                          # bắt đầu nghiêng trái
		elif right and not left:                     # chỉ giữ phải
			charge_dir = 1                           # bắt đầu nghiêng phải
		charge = 0.0                                 # bắt đầu tích lực từ 0
	if charge_dir != 0:                              # đang nghiêng
		var holding := left if charge_dir < 0 else right   # còn giữ phím của hướng đó không
		if holding:                                  # vẫn đang giữ
			charge = minf(1.0, charge + delta / charge_time)    # giữ càng lâu càng mạnh
		else:
			charge_dir = 0                                    # thả A/D mà chưa nhảy: hủy, đứng thẳng lại
			charge = 0.0                             # xoá lực đã tích


## Tên hành động đầy đủ: tiền tố của người chơi + tên gốc ("left", "right", "jump", "use"). Mọi đọc phím đều qua đây.
func _action(action: String) -> String:
	return action_prefix + action                    # ví dụ "p2_" + "jump" = "p2_jump"


## Đang giữ phím "use" của mình không (chỉ có nghĩa khi đã có tiền tố người chơi; chơi một mình luôn trả về false).
func is_use_held() -> bool:
	if dead or action_prefix.is_empty():             # đã chết hoặc chơi một mình: không có phím "use"
		return false
	return Input.is_action_pressed(_action("use"))   # đang giữ phím use của người chơi này


## Gắn quả bóng này cho người chơi 1 hoặc 2: đặt tiền tố phím và đổi màu (người chơi 1 giữ màu gốc).
func set_player(id: int) -> void:
	if id != 1 and id != 2:                          # chỉ có hai người chơi
		push_error("Ball.set_player: id must be 1 or 2, got %d" % id)   # báo lỗi dùng sai
		return
	player_id = id                                   # nhớ là người chơi nào
	action_prefix = "p%d_" % id                      # phím riêng: p1_left, p2_jump...
	var sprite := get_node_or_null("Sprite") as Node2D   # node hình (3 phần) của quả bóng
	if sprite != null:                               # có hình thật
		if id == 2:                                  # người chơi 2: hoán đổi màu đỏ/xanh của hình
			if _swap_rb_shader == null:              # lần đầu: tạo shader dùng chung
				_swap_rb_shader = Shader.new()       # tạo shader mới
				_swap_rb_shader.code = SWAP_RB_CODE  # gán mã hoán đổi màu
			var mat := ShaderMaterial.new()          # vật liệu riêng cho quả bóng này
			mat.shader = _swap_rb_shader             # dùng shader chung
			sprite.material = mat                    # áp lên node Sprite (nhấp nháy modulate.a của Ball vẫn chạy bình thường)
		else:
			sprite.material = null                   # người chơi 1: màu gốc
		for part in sprite.get_children():           # 3 phần hình (đầu, lò xo, banh)
			if part is CanvasItem:                   # là node vẽ được
				part.use_parent_material = (id == 2)   # dùng vật liệu của node Sprite cha
	queue_redraw()                                   # vẽ lại hình tạm (nếu có) theo màu mới


## Bật / tắt va chạm với các quả bóng khác (mặc định tắt, chơi một mình không đổi). Cả hai bóng nên cùng bật.
func set_collide_with_balls(on: bool) -> void:
	set_collision_mask_value(BALL_LAYER, on)         # bật/tắt bit lớp "ball" trong mặt nạ va chạm


## Đổi kích thước: `factor` 1.0 = gốc, 2.0 = gấp đôi. Đổi vòng va chạm, bán kính, hình và khối lượng (theo diện tích).
## Gọi sau khi quả bóng đã vào cảnh. Bán kính, hình, khối lượng đổi ngay; vòng va chạm đổi vào cuối khung hình.
func set_size(factor: float) -> void:
	factor = maxf(factor, 0.1)                       # không cho nhỏ tới mức biến mất
	size_factor = factor                             # nhớ hệ số hiện tại
	_apply_shape_size.call_deferred()                # vòng va chạm đổi muộn một chút: gọi trong tín hiệu vật lý (nhặt đồ) sẽ báo lỗi nếu đổi ngay
	radius = _base_radius * factor                   # bán kính (tính từ gốc nên set_size(1.0) khôi phục đúng)
	mass = _base_mass * factor * factor              # khối lượng tỉ lệ với diện tích
	var sprite := get_node_or_null("Sprite")         # node hình
	if sprite != null and sprite.has_method("set_size_factor"):   # có script hoạt ảnh
		sprite.set_size_factor(factor)               # phóng hình và đặt lại chân ở đáy vòng mới
	queue_redraw()                                   # vẽ lại theo bán kính mới


## Đặt bán kính vòng va chạm theo size_factor hiện tại (set_size gọi muộn để không đụng lúc Godot đang xử lý vật lý).
func _apply_shape_size() -> void:
	var shape_node := get_node_or_null("Shape") as CollisionShape2D   # node vòng va chạm
	if shape_node == null or not shape_node.shape is CircleShape2D:   # không có hoặc không phải hình tròn
		return
	if not _shape_copied:                            # resource trong scene dùng chung cho mọi quả bóng
		shape_node.shape = shape_node.shape.duplicate()   # nhân bản riêng trước khi sửa
		_shape_copied = true                         # chỉ nhân bản một lần
	shape_node.shape.radius = _base_shape_radius * size_factor   # đổi bán kính vòng va chạm (tính từ gốc nên 1.0 khôi phục đúng)


## Làm nhân vật dẹt như cái bánh trong `seconds` giây rồi bật trở lại (chỉ hiệu ứng hình, vòng va chạm giữ nguyên).
func flatten(seconds: float) -> void:
	var sprite := get_node_or_null("Sprite")         # node hình
	if sprite != null and sprite.has_method("flatten"):   # có script hoạt ảnh
		sprite.flatten(seconds)                      # nhờ node hình làm hoạt ảnh dẹt


## Hất quả bóng một cú: cộng `velocity` vào vận tốc ở khung vật lý tới (an toàn khi gọi từ tín hiệu va chạm).
func knockback(velocity: Vector2) -> void:
	_kick += velocity                                # ghi lại, _integrate_forces sẽ thực hiện


## Yêu cầu một cú nhảy theo hướng `dir` (-1 trái, 1 phải, 0 thẳng lên) với độ mạnh `amount` (0..1).
## Nhảy ngay nếu đang chạm đất, không thì chờ tối đa release_buffer giây.
func jump(dir: int, amount: float) -> void:
	# ghi lại cú nhảy; _integrate_forces sẽ thực hiện khi chạm đất
	_jump_request = {"dir": dir, "charge": clampf(amount, 0.0, 1.0), "time": release_buffer}


## Hướng và vận tốc của cú nhảy với độ mạnh `amount`.
func jump_velocity(dir: int, amount: float) -> Vector2:
	var speed := lerpf(min_speed, max_speed, amount)          # lực mạnh dần từ min tới max theo amount
	if boost_time > 0.0:                                      # đang có jump boost
		speed *= boost_power                                  # đang có jump boost: nhảy mạnh hơn
	if dir == 0:                                              # không nghiêng
		return Vector2(0, -speed)                             # nhảy thẳng lên
	var angle := deg_to_rad(lerpf(min_tilt_deg, max_tilt_deg, amount))   # góc nhảy, tích càng lâu càng chéo
	return Vector2(sin(angle) * dir, -cos(angle)) * speed     # vận tốc theo góc: x ngang, y hướng lên


## Godot gọi trong lúc tính vật lý. Mọi thay đổi vận tốc làm ở đây để không đánh nhau với vật lý.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _teleport_to != null:                         # dịch tới chỗ hồi sinh, đứng yên
		state.transform = Transform2D(0.0, _teleport_to)   # đặt thẳng vị trí mới, không xoay
		# Đặt LẦN HAI cùng vị trí: lần đầu Godot còn nhớ chỗ cũ làm "điểm xuất phát" cho chống xuyên tường (CCD),
		# khung sau nó tưởng bóng vừa bay xuyên qua đất nằm giữa hai chỗ và kéo bóng ngược về mép đất gần nhất
		# (hồi sinh xong lại rơi xuống vực). Lần hai làm nó quên chỗ cũ.
		state.transform = Transform2D(0.0, _teleport_to)   # đặt lại lần nữa để xoá vị trí cũ trong bộ nhớ CCD
		state.linear_velocity = Vector2.ZERO         # đứng yên tại chỗ
		_teleport_to = null                          # đã dịch xong
		return

	# 1. Chạm đất? Xét các điểm tiếp xúc có pháp tuyến hướng lên trên.
	on_ground = false                                # mặc định là đang trên không
	var touching := {}                               # các quả bóng khác đang chạm ở khung này
	for i in state.get_contact_count():              # duyệt từng điểm chạm
		var normal := state.get_contact_local_normal(i)   # pháp tuyến mặt chạm
		if normal.y < -0.6:                          # mặt chạm hướng lên = mặt đất
			on_ground = true                         # có chạm đất
		var other := state.get_contact_collider_object(i) as Ball   # vật chạm có phải quả bóng khác không
		if other != null:                            # đang chạm một quả bóng khác
			var id := other.get_instance_id()        # mã định danh của nó
			touching[id] = true                      # ghi nhận đang chạm
			# Dẫm: bóng khác nằm DƯỚI (pháp tuyến hướng lên), VỪA chạm (không phải đang đứng trên đầu), rơi đủ nhanh, hết thời gian chờ.
			if normal.y < -0.6 and not _touching_balls.has(id) and _last_vy >= stomp_speed \
					and _stomp_cd <= 0.0 and not dead and not other.dead:
				_stomp_cd = stomp_cooldown           # bắt đầu thời gian chờ dẫm
				_bounce = maxf(_bounce, stomp_bounce)   # nảy lên nhẹ sau khi dẫm
				emit_signal.call_deferred("stomped", other)   # báo muộn một chút để chế độ chơi đổi vật lý (kích thước, va chạm) thoải mái
	_touching_balls = touching                       # nhớ để khung sau biết quả nào VỪA chạm
	if on_ground:                                    # đang đứng trên đất
		_coyote = coyote_time                        # chạm đất thì nạp lại thời gian coyote
		if not _was_on_ground:                       # vừa mới chạm đất ở khung này
			_tilt_vel += state.linear_velocity.x * 0.02   # chạm đất: thân lắc theo đà ngang
			if _last_vy > 40.0:                      # rơi đủ mạnh mới tính là đáp đất
				landed.emit(_last_vy)                    # báo chạm đất (kèm tốc độ rơi)
	_was_on_ground = on_ground                       # nhớ trạng thái cho khung sau
	_last_vy = state.linear_velocity.y               # nhớ tốc độ rơi cho khung sau
	if dead:                                         # đang chết thì không nhảy, không bật
		return

	# 2. Nhảy nếu có yêu cầu và đang (hoặc vừa) chạm đất.
	if not _jump_request.is_empty() and _coyote > 0.0:   # có lệnh nhảy và còn được phép nhảy
		state.linear_velocity = jump_velocity(_jump_request["dir"], _jump_request["charge"])   # đặt vận tốc nhảy
		_tilt_vel += _jump_request["dir"] * -4.0       # bật thẳng người lên khi nhảy
		_jump_request = {}                           # đã nhảy, xoá yêu cầu
		_coyote = 0.0                                # hết coyote để không nhảy hai lần
		launched.emit()                              # báo vừa nhảy

	# 3. Bật lên do dẫm quái hoặc lò xo. Đang giữ A/D thì bật chéo theo hướng đó (để không kẹt nảy thẳng mãi).
	if _bounce > 0.0:                                # có yêu cầu bật lên
		state.linear_velocity.y = -_bounce           # bay vọt lên
		if charge_dir != 0:                          # đang nghiêng
			state.linear_velocity.x = charge_dir * lerpf(180.0, 360.0, charge)   # thêm vận tốc ngang theo hướng nghiêng
		_bounce = 0.0                                # đã bật, xoá yêu cầu
		_coyote = 0.0                                # đang bay nên không được nhảy tiếp

	# 4. Bị hất (đạn đẩy lùi, chiêu của người chơi khác): cộng thẳng vào vận tốc.
	if _kick != Vector2.ZERO:                        # có cú hất đang chờ
		state.linear_velocity += _kick               # cộng vào vận tốc hiện tại
		_kick = Vector2.ZERO                         # đã hất, xoá yêu cầu
		_coyote = 0.0                                # bị hất bay thì không được nhảy "ké" từ chỗ cũ


## Lắc lư kiểu lật đật: lúc giữ phím thì nghiêng theo lực, thả ra thì lò xo kéo về thẳng.
func _update_wobble(delta: float) -> void:
	if charge_dir != 0 and not dead:                 # đang giữ phím nghiêng
		var target := charge_dir * deg_to_rad(lerpf(min_tilt_deg, max_tilt_deg, charge))   # góc cần nghiêng tới
		tilt = lerpf(tilt, target, 0.3)              # nghiêng dần về góc đó cho mượt
		_tilt_vel = 0.0                              # không lắc khi đang giữ
		return
	_tilt_vel += (-wobble_stiffness * tilt - wobble_damping * _tilt_vel) * delta   # lò xo kéo về thẳng, có giảm chấn
	tilt += _tilt_vel * delta                        # cập nhật góc nghiêng


## Dịch tới `pos` (dùng khi hồi sinh).
func teleport(pos: Vector2) -> void:
	_teleport_to = pos                               # hẹn dịch ở khung vật lý tới
	charge_dir = 0                                   # bỏ nghiêng
	charge = 0.0                                     # bỏ lực đã tích
	_jump_request = {}                               # bỏ cú nhảy đang chờ
	_bounce = 0.0                                    # bỏ cú bật lò xo / dẫm quái còn sót lại
	_kick = Vector2.ZERO                             # bỏ cú hất còn sót lại
	_coyote = 0.0                                    # không được nhảy "ké" từ chỗ cũ


## Bật lên với vận tốc `speed` (quái gọi khi bị dẫm, lò xo gọi khi chạm).
func bounce_up(speed: float) -> void:
	_bounce = speed                                  # ghi lại, _integrate_forces sẽ thực hiện


## Bị thương. Đồ vật nguy hiểm gọi hàm này; play.gd quyết định trừ mạng, hồi sinh.
## Có khiên thì khiên vỡ thay (không mất mạng); vừa bị đánh thì được miễn sát thương một lúc.
func take_hit() -> void:
	if dead or invuln > 0.0:                         # đã chết hoặc đang miễn sát thương
		return
	if has_shield:                                   # có khiên
		has_shield = false                           # khiên vỡ
		invuln = invuln_after_hit                    # được miễn sát thương một lúc
		shield_changed.emit(false)                   # báo HUD ẩn biểu tượng khiên
		return
	hurt.emit()                                      # không có khiên: báo bị thương (mất mạng)


## Vẽ: thân lật đật (nếu bật show_placeholder) và mũi tên lực nhảy khi đang giữ phím (luôn vẽ).
func _draw() -> void:
	var base := Vector2(0, radius)                   # lật đật nghiêng quanh điểm chạm đất
	draw_set_transform(base, tilt)                   # dời gốc vẽ xuống chân và xoay theo góc nghiêng
	if show_placeholder:                             # chỉ vẽ thân tạm khi bật
		# Theo mẫu của nhóm: trái banh đỏ sẫm có chấm sáng, ngồi trên đế vàng nửa vòng tròn.
		var base_color := Color("#e3a72a")             # đế vàng
		var ball_color := Color("#8e1418")             # banh đỏ sẫm
		if player_id == 2:                             # người chơi 2: hoán đổi đỏ/xanh cho khác người chơi 1
			base_color = Color(base_color.b, base_color.g, base_color.r)   # đế vàng thành xanh
			ball_color = Color(ball_color.b, ball_color.g, ball_color.r)   # banh đỏ thành xanh sẫm
		var base_center := Vector2(0, -radius + 1)     # tâm của nửa vòng tròn đế
		var cup := PackedVector2Array()                # các điểm của hình đế
		for i in 17:                                   # nửa vòng tròn phía dưới (đáy chạm đất)
			var a := PI * i / 16.0                     # góc từ 0 đến 180 độ
			cup.append(base_center + Vector2(cos(a), sin(a)) * (radius - 1))   # thêm một điểm của đế
		draw_colored_polygon(cup, base_color)          # tô đế màu vàng
		draw_polyline(cup + PackedVector2Array([cup[0]]), base_color.darkened(0.4), 1.5)   # viền đế khép kín
		var ball_center := Vector2(0, -radius - 4)     # banh nằm trên đế
		var ball_r := radius * 0.7                     # banh nhỏ hơn thân một chút
		draw_circle(ball_center, ball_r, ball_color)   # vẽ trái banh đỏ
		draw_arc(ball_center, ball_r - 1.5, PI * 0.9, PI * 1.6, 10, ball_color.lightened(0.25), 2.0)   # viền sáng phía trên trái
		draw_arc(ball_center, ball_r, 0.0, TAU, 24, ball_color.darkened(0.5), 1.0)   # viền tối quanh banh
		draw_circle(ball_center + Vector2(-ball_r * 0.35, -ball_r * 0.4), 2.0, Color.WHITE)   # chấm sáng
	draw_set_transform(Vector2.ZERO)                 # trả gốc vẽ về bình thường, không xoay
	if boost_time > 0.0 and not dead:                # jump boost: mũi tên xanh nhấp nháy dưới chân
		var a := 0.5 + 0.5 * sin(_time * 10.0)       # độ trong suốt dao động từ 0 đến 1
		# vẽ ảnh mũi tên xanh 24x24 dưới chân với độ mờ a
		draw_texture_rect(JUMP_BOOST_TEXTURE, Rect2(Vector2(-12, radius - 8), Vector2(24, 24)), false, Color(1, 1, 1, a))
	if has_shield and not dead:                      # khiên: vòng tròn pixel xanh ngọc bao quanh nhân vật
		var center := Vector2(0, -17) * size_factor  # tâm vòng khiên (to theo kích thước bóng)
		for i in 28:                                 # 28 ô vuông nhỏ tạo thành vòng tròn
			var a := TAU * i / 28.0 + _time * 0.8    # góc mỗi ô, cả vòng quay chậm theo thời gian
			var p := center + Vector2(cos(a), sin(a)) * 38.0 * size_factor   # vị trí ô trên vòng bán kính 38
			var col := Color("#7fd6e0") if i % 2 == 0 else Color("#3c8ea0")   # xen kẽ hai màu xanh
			draw_rect(Rect2(p.snapped(Vector2(2, 2)) - Vector2(2, 2), Vector2(4, 4)), Color(col, 0.75))   # vẽ ô 4x4 hơi trong
	if charge_dir != 0 and not dead:                 # mũi tên: hướng và độ mạnh cú nhảy
		var v := jump_velocity(charge_dir, charge)   # vận tốc nhảy nếu nhảy ngay bây giờ
		var start := v.normalized() * (radius + 4.0)                  # bắt đầu từ mép thân, không đè lên banh
		var tip := v.normalized() * (radius + 14.0 + 30.0 * charge)   # càng giữ lâu mũi tên càng dài
		var col := Color(1, 1, 1, 0.85).lerp(Color("#ff5d5d"), charge)   # trắng chuyển dần sang đỏ khi tích đầy
		draw_line(start, tip, col, 3.0)              # vẽ thân mũi tên
		var side := tip.normalized().orthogonal() * 5.0   # hướng vuông góc để làm hai cánh đầu mũi tên
		# vẽ đầu mũi tên hình tam giác
		draw_colored_polygon(PackedVector2Array([tip + tip.normalized() * 6.0, tip + side, tip - side]), col)
