class_name Pickup                       # tên lớp để file khác nhận ra vật nhặt
extends Area2D                          # vùng chạm: chỉ phát hiện, không cản bóng
## Một script dùng chung cho các vật chỉ cần "bóng chạm vào là có tác dụng":
##   star       - ngôi sao, nhặt để tính điểm (mỗi màn 3 sao)
##   checkpoint - cờ lưu: chết thì hồi sinh ở đây
##   finish     - đích: chạm là qua màn
##   trampoline - lò xo: bật bóng lên rất cao
##   heart      - trái tim: +1 mạng (tối đa bằng số mạng ban đầu)
##   shield     - khiên: đỡ 1 đòn
##   gun        - súng: + đạn; mọc lại sau `respawn_time` giây (để đấu boss không bao giờ hết đạn)
##   jump_boost - mũi tên xanh: nhảy cao hơn trong một lúc (xem Ball.boost_duration)
## Chọn loại ở biến `kind`. Gốc tọa độ ở giữa đáy ô.

# chọn loại vật trong danh sách thả xuống ở Inspector (mặc định là sao)
@export_enum("star", "checkpoint", "finish", "trampoline", "heart", "shield", "gun", "jump_boost") var kind := "star"
@export var trampoline_speed := 920.0   # lò xo bật lên với vận tốc này (khoảng 9 ô)
@export var gun_ammo := 15              # nhặt súng được bao nhiêu viên đạn
@export var respawn_time := 8.0         # súng mọc lại sau bao nhiêu giây
@export var show_placeholder := true    # bật thì tự vẽ hình tạm cho vật

## Ảnh 16 x 16 của nhóm (assets/items/), vẽ phóng to gấp 2. Thay file PNG là đổi hình.
const ITEM_TEXTURES := {
	# mỗi loại vật ứng với một ảnh, nạp sẵn khi mở game
	"heart": preload("res://assets/items/heart.png"),
	"shield": preload("res://assets/items/shield.png"),
	"jump_boost": preload("res://assets/items/jump_boost.png"),
}

const CHECKPOINT_HEIGHT := 320.0         # vùng chạm của cờ lưu cao 10 ô (cao hơn cú nhảy mạnh nhất)

var used := false       # cờ đã cắm / sao đã nhặt
var _time := 0.0        # cho hiệu ứng lắc lư
var _squash := 0.0      # lò xo nén xuống khi vừa bật


func _ready() -> void:
	body_entered.connect(_on_body_entered)       # có vật chạm vào thì gọi hàm xử lý
	if kind == "checkpoint":                     # cờ lưu: vùng chạm là cả cột cao phía trên cờ,
		var tall := RectangleShape2D.new()       # để nhảy vòng qua trên đầu cờ vẫn được tính là đã lưu
		tall.size = Vector2(32, CHECKPOINT_HEIGHT)   # rộng 1 ô, cao CHECKPOINT_HEIGHT pixel
		$Shape.shape = tall                      # thay hình va chạm riêng cho cờ lưu (không đụng tới vật nhặt khác)
		$Shape.position = Vector2(0, -CHECKPOINT_HEIGHT / 2.0)   # cột bắt đầu từ mặt đất đi lên


func _process(delta: float) -> void:
	_time += delta                               # đếm thời gian cho hiệu ứng nhấp nhô
	_squash = maxf(0.0, _squash - delta * 4.0)   # lò xo từ từ hết nén, không xuống dưới 0
	if show_placeholder:                         # đang dùng hình tạm
		queue_redraw()                           # vẽ lại mỗi khung hình để có chuyển động


## Bóng chạm vào: làm việc tương ứng với loại vật.
func _on_body_entered(body: Node2D) -> void:
	if not body is Ball or body.dead:            # chỉ bóng còn sống mới nhặt được
		return
	var level := Level.of(self)                  # tìm màn chơi đang chứa vật này
	match kind:                                  # xử lý theo loại vật
		"star":
			if used:                             # đã nhặt rồi thì bỏ qua
				return
			used = true                          # đánh dấu đã nhặt
			level.collect_star(body)             # báo màn chơi +1 sao, kèm quả bóng đã nhặt
			queue_free()                         # xoá ngôi sao khỏi màn
		"checkpoint":
			if used:                             # cờ đã cắm rồi
				return
			used = true                          # cắm cờ
			level.reach_checkpoint(global_position + Vector2(0, -16))   # lưu chỗ hồi sinh ngay trên cờ
		"finish":
			if used:                             # tránh qua màn hai lần
				return
			used = true                          # đánh dấu đã về đích
			level.finish()                       # báo màn chơi: qua màn
		"trampoline":
			body.bounce_up(trampoline_speed)     # bật bóng lên thật cao
			_squash = 1.0                        # lò xo nén hết cỡ để trông như vừa bật
		"heart":
			if used:                             # đã nhặt rồi
				return
			used = true                          # đánh dấu đã nhặt
			level.collect_heart()                # +1 mạng
			queue_free()                         # xoá trái tim
		"shield":
			if used:                             # đã nhặt rồi
				return
			used = true                          # đánh dấu đã nhặt
			body.give_shield()                   # cho bóng một tấm khiên
			queue_free()                         # xoá vật khiên
		"jump_boost":
			if used:                             # đã nhặt rồi
				return
			used = true                          # đánh dấu đã nhặt
			body.give_jump_boost()               # bóng được nhảy cao hơn một lúc
			queue_free()                         # xoá mũi tên
		"gun":
			if used:                             # súng đang ẩn chờ mọc lại
				return
			used = true                          # đánh dấu đã nhặt
			body.add_ammo(gun_ammo)              # cộng đạn cho bóng
			hide()                                     # ẩn đi rồi mọc lại sau respawn_time giây
			await get_tree().create_timer(respawn_time).timeout   # chờ đủ số giây
			if is_inside_tree():                 # vật vẫn còn trong màn (chưa bị xoá)
				used = false                     # cho phép nhặt lại
				show()                           # hiện súng ra lại


## Hình tạm cho từng loại.
func _draw() -> void:
	if not show_placeholder:                     # đã có hình thật thì không vẽ tạm
		return
	match kind:                                  # vẽ theo loại vật
		"star":
			var c := Vector2(0, -16 + sin(_time * 3.0) * 3.0)   # tâm sao nhấp nhô lên xuống
			var pts := PackedVector2Array()                     # các đỉnh của ngôi sao
			for i in 10:                                        # 10 đỉnh: 5 nhọn, 5 lõm
				var a := -PI / 2 + i * PI / 5                   # góc của đỉnh, bắt đầu từ trên cùng
				# đỉnh chẵn ở xa (cánh nhọn), đỉnh lẻ ở gần (chỗ lõm)
				pts.append(c + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 5.0))
			draw_colored_polygon(pts, Color("#ffd23f"))         # tô sao màu vàng
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#b8860b"), 1.0)   # viền sao khép kín
		"checkpoint", "finish":
			var pole_h := 56.0 if kind == "finish" else 44.0    # cột đích cao hơn cột cờ lưu
			draw_line(Vector2(-8, 0), Vector2(-8, -pole_h), Color("#e8e8e8"), 3.0)   # vẽ cột cờ
			var flag := Color("#4dd27a") if (used or kind == "finish") else Color("#9aa3b5")   # cờ xanh khi đã cắm, xám khi chưa
			if kind == "finish":                                # cờ đích
				flag = Color("#ff5d8f")                         # thì màu hồng
			var top := -pole_h                                  # đỉnh cột
			# vẽ lá cờ hình tam giác ở đỉnh cột
			draw_colored_polygon(PackedVector2Array([Vector2(-7, top), Vector2(14, top + 7), Vector2(-7, top + 14)]), flag)
		"trampoline":
			var h := 10.0 - _squash * 5.0                       # chiều cao lò xo, thấp xuống khi nén
			draw_rect(Rect2(-14, -4, 28, 4), Color("#555b6e"))  # đế lò xo
			for x in [-10.0, 0.0, 10.0]:                        # 3 thanh lò xo
				draw_line(Vector2(x, -4), Vector2(x, -h), Color("#aab2c5"), 2.0)   # vẽ một thanh
			draw_rect(Rect2(-15, -h - 4, 30, 4), Color("#ff6b6b"))   # mặt nhún màu đỏ
		"heart", "shield", "gun", "jump_boost":         # vật phẩm nhấp nhô, có quầng sáng
			var c := Vector2(0, -16 + sin(_time * 3.0) * 3.0)   # tâm vật nhấp nhô
			# chọn màu quầng sáng theo loại vật
			var glow: Color = {"heart": Color("#e8455a"), "shield": Color("#00a2e8"), "gun": Color("#f7d046"), "jump_boost": Color("#22b14c")}[kind]
			draw_circle(c, 17.0, Color(glow, 0.18 + 0.08 * sin(_time * 5.0)))   # quầng sáng nhấp nháy
			if ITEM_TEXTURES.has(kind):                         # loại này có ảnh riêng
				draw_texture_rect(ITEM_TEXTURES[kind], Rect2(c - Vector2(16, 16), Vector2(32, 32)), false)   # ảnh 16x16 phóng gấp 2
			else:
				PixelArt.draw_centered(self, PixelArt.GUN, c, 3.0)   # súng thì vẽ bằng pixel art
