class_name Pickup
extends Area2D
## Một script dùng chung cho các vật chỉ cần "bóng chạm vào là có tác dụng":
##   star       - ngôi sao, nhặt để tính điểm (mỗi màn 3 sao)
##   checkpoint - cờ lưu: chết thì hồi sinh ở đây
##   finish     - đích: chạm là qua màn
##   trampoline - lò xo: bật bóng lên rất cao
##   heart      - trái tim: +1 mạng (tối đa bằng số mạng ban đầu)
##   shield     - khiên: đỡ 1 đòn
##   gun        - súng: + đạn; mọc lại sau `respawn_time` giây (để đấu boss không bao giờ hết đạn)
## Chọn loại ở biến `kind`. Gốc tọa độ ở giữa đáy ô.

@export_enum("star", "checkpoint", "finish", "trampoline", "heart", "shield", "gun") var kind := "star"
@export var trampoline_speed := 920.0   # lò xo bật lên với vận tốc này (khoảng 9 ô)
@export var gun_ammo := 15              # nhặt súng được bao nhiêu viên đạn
@export var respawn_time := 8.0         # súng mọc lại sau bao nhiêu giây
@export var show_placeholder := true

var used := false       # cờ đã cắm / sao đã nhặt
var _time := 0.0        # cho hiệu ứng lắc lư
var _squash := 0.0      # lò xo nén xuống khi vừa bật


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_squash = maxf(0.0, _squash - delta * 4.0)
	if show_placeholder:
		queue_redraw()


## Bóng chạm vào: làm việc tương ứng với loại vật.
func _on_body_entered(body: Node2D) -> void:
	if not body is Ball or body.dead:
		return
	var level := Level.of(self)
	match kind:
		"star":
			if used:
				return
			used = true
			level.collect_star()
			queue_free()
		"checkpoint":
			if used:
				return
			used = true
			level.reach_checkpoint(global_position + Vector2(0, -16))
		"finish":
			if used:
				return
			used = true
			level.finish()
		"trampoline":
			body.bounce_up(trampoline_speed)
			_squash = 1.0
		"heart":
			if used:
				return
			used = true
			level.collect_heart()
			queue_free()
		"shield":
			if used:
				return
			used = true
			body.give_shield()
			queue_free()
		"gun":
			if used:
				return
			used = true
			body.add_ammo(gun_ammo)
			hide()                                     # ẩn đi rồi mọc lại sau respawn_time giây
			await get_tree().create_timer(respawn_time).timeout
			if is_inside_tree():
				used = false
				show()


## Hình tạm cho từng loại.
func _draw() -> void:
	if not show_placeholder:
		return
	match kind:
		"star":
			var c := Vector2(0, -16 + sin(_time * 3.0) * 3.0)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 5.0))
			draw_colored_polygon(pts, Color("#ffd23f"))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#b8860b"), 1.0)
		"checkpoint", "finish":
			var pole_h := 56.0 if kind == "finish" else 44.0
			draw_line(Vector2(-8, 0), Vector2(-8, -pole_h), Color("#e8e8e8"), 3.0)
			var flag := Color("#4dd27a") if (used or kind == "finish") else Color("#9aa3b5")
			if kind == "finish":
				flag = Color("#ff5d8f")
			var top := -pole_h
			draw_colored_polygon(PackedVector2Array([Vector2(-7, top), Vector2(14, top + 7), Vector2(-7, top + 14)]), flag)
		"trampoline":
			var h := 10.0 - _squash * 5.0
			draw_rect(Rect2(-14, -4, 28, 4), Color("#555b6e"))
			for x in [-10.0, 0.0, 10.0]:
				draw_line(Vector2(x, -4), Vector2(x, -h), Color("#aab2c5"), 2.0)
			draw_rect(Rect2(-15, -h - 4, 30, 4), Color("#ff6b6b"))
		"heart", "shield", "gun":                       # hình pixel nhấp nhô, có quầng sáng
			var c := Vector2(0, -16 + sin(_time * 3.0) * 3.0)
			var glow: Color = {"heart": Color("#e8455a"), "shield": Color("#7fd6e0"), "gun": Color("#f7d046")}[kind]
			draw_circle(c, 15.0, Color(glow, 0.18 + 0.08 * sin(_time * 5.0)))
			var art: Array = {"heart": PixelArt.HEART, "shield": PixelArt.SHIELD, "gun": PixelArt.GUN}[kind]
			PixelArt.draw_centered(self, art, c, 3.0)
