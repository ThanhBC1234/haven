extends Node
## Chụp ảnh phóng to nhân vật ở 4 khoảnh khắc để xem hoạt ảnh. Chạy có cửa sổ:
##   godot --path . res://tests/ball_preview.tscn -- --shots=<thư mục>
## Lưu: 1_idle, 2_charge (giữ D), 3_jump (vừa thả), 4_land (vừa chạm đất).

var dir := ""
var cam: Camera2D
var ball: Ball


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	var level := Level.new()
	add_child(level)
	var rows := []
	for i in 10:
		rows.append("#" + ".".repeat(30) + "#")
	rows.append("#..O" + ".".repeat(27) + "#")
	rows.append("#".repeat(32))
	level.build("\n".join(rows))
	ball = load("res://scenes/ball.tscn").instantiate()
	ball.position = level.start_position
	level.add_child(ball)
	cam = Camera2D.new()
	cam.zoom = Vector2(5, 5)
	add_child(cam)
	cam.make_current()
	await _frames(60)
	await _shot("1_idle")
	Input.action_press("right")
	await _frames(28)
	await _shot("2_charge")
	Input.action_release("right")
	await _frames(4)
	await _shot("3_jump")
	await ball.landed
	await _frames(3)
	await _shot("4_land")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name_: String) -> void:
	cam.global_position = ball.global_position + Vector2(0, -20)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name_ + ".png"))
