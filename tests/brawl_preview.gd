extends Node
## Chụp chế độ đấu 2 người. Chạy có cửa sổ: godot --path . res://tests/brawl_preview.tscn -- --shots=<thư mục>
## Ảnh: từng đấu trường lúc bắt đầu (READY...), giữa trận có điểm (người bị dẫm đang dẹt), gai chống câu giờ, bảng thắng.

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false                       # không ghi đè file lưu thật
	for i in BrawlData.ARENAS.size():
		var brawl := await _start(i)
		await _frames(20)
		await _shot("arena%d_start" % i)             # đang READY...
		await _wait_match(brawl)
		Input.action_press("p1_right")               # người chơi 1 giữ D: hiện mũi tên lực nhảy
		await _frames(25)
		brawl.kill(brawl.balls[1], "pit")            # người chơi 2 rơi xuống vực: P1 có điểm
		await _frames(100)                           # người chơi 2 đã hồi sinh (nhấp nháy)
		Input.action_release("p1_right")
		var b := brawl.balls[1]
		brawl.scores[0] = 2
		brawl.hud.set_scores(2, 1)
		b.teleport(brawl.balls[0].global_position + Vector2(180, -120))   # người chơi 2 rơi xuống gần người chơi 1
		await _frames(30)
		await _shot("arena%d_mid" % i)               # giữa trận, điểm 2 - 1
		brawl.kill(brawl.balls[1], "stomp")          # dẫm: người chơi 2 dẹt như bánh
		await _frames(18)
		await _shot("arena%d_pancake" % i)
		brawl.stall_timeout = 0.1                    # gai chống câu giờ mọc nhanh để chụp
		brawl.stall_step = 0.1
		brawl._stall_time = 0.0
		await _frames(110)                           # chờ hồi sinh + gai mọc vài ô
		await _shot("arena%d_stall_spikes" % i)
		brawl.scores[0] = Brawl.WIN_SCORE - 1
		brawl.kill(brawl.balls[1], "spikes")         # điểm thứ 5: thắng
		await _frames(110)
		await _shot("arena%d_win" % i)
		brawl.queue_free()
		await _frames(3)
	get_tree().quit()


## Dựng cảnh đấu với đấu trường số `index`, giới thiệu dài một chút để kịp chụp READY...
func _start(index: int) -> Brawl:
	var brawl: Brawl = load("res://scenes/brawl.tscn").instantiate()
	brawl.arena_index = index
	brawl.intro_seconds = 0.9
	brawl.respawn_delay = 0.4
	brawl.win_panel_delay = 0.4
	add_child(brawl)
	await _frames(2)
	return brawl


func _wait_match(brawl: Brawl) -> void:
	while not brawl.match_running:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if dir != "" and img:
		img.save_png(dir.path_join(shot_name + ".png"))
