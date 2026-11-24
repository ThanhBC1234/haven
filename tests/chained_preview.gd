extends Node
## Chụp chế độ Chained. Chạy có cửa sổ: godot --path . res://tests/chained_preview.tscn -- --shots=<thư mục>
## Ảnh: menu, đầu màn (READY...), dây căng có hạt trượt về người đứng thấp, một người neo còn người kia lơ lửng trên khe, bảng kết quả, toàn cảnh màn.

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false                       # không ghi đè file lưu thật
	await _menu_shot()
	await _level_shots()
	get_tree().quit()


## Ảnh menu có nút CHAINED 2P.
func _menu_shot() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(8)
	await _shot("menu_chained_button")
	menu.queue_free()
	await _frames(3)


## Dựng cảnh Chained, giới thiệu dài một chút để kịp chụp READY...
func _start() -> Chained:
	Game.chained_index = 0
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	var ch: Chained = load("res://scenes/chained.tscn").instantiate()
	ch.intro_seconds = 0.8
	ch.respawn_delay = 0.5
	ch.finish_panel_delay = 0.3
	ch.scene_changes_enabled = false
	add_child(ch)
	await _frames(2)
	return ch


func _wait_running(ch: Chained) -> void:
	while not ch.match_running:
		await get_tree().physics_frame


## Đặt hai quả bóng ở toạ độ cột / hàng của bản đồ (giữa ô, đứng trên mặt ô).
func _place(ch: Chained, i: int, col: float, row: float) -> void:
	ch.balls[i].teleport(Vector2(col * 32.0, (row + 1) * 32.0 - 16.0))


func _level_shots() -> void:
	var ch := await _start()
	await _frames(20)
	await _shot("level_start_ready")                 # đang READY...
	await _wait_running(ch)
	await _frames(40)

	# --- dây căng, hạt trượt về phía người đứng thấp (người chơi 2 xuống thung lũng); cả hai neo để dây giữ căng ---
	Input.action_press("p1_use")
	Input.action_press("p2_use")
	_place(ch, 0, 31.5, 15)                          # người chơi 1 trên bờ thung lũng
	_place(ch, 1, 39.5, 19)                          # người chơi 2 ở đáy thung lũng
	await _frames(40)
	for i in 6:
		ch.level.collect_star(ch.balls[i % 2])       # nhặt sao: hạt mới xuất hiện ở giữa dây
		await _frames(8)
	await _frames(90)                                # hạt trượt về phía người chơi 2 (thấp hơn)
	await _shot("rope_stretched_beads")
	Input.action_release("p1_use")
	Input.action_release("p2_use")

	# --- một người neo ở mép khe, người kia rơi xuống khe và lơ lửng trên dây ---
	ch.rope.reset()
	Input.action_press("p1_use")                     # người chơi 1 neo
	_place(ch, 0, 63.5, 15)                          # người chơi 1 ở mép khe
	_place(ch, 1, 61.5, 15)
	await _frames(40)
	_place(ch, 1, 66.5, 8)                           # người chơi 2 thả từ trên cao vào khe
	await _frames(200)
	await _shot("anchor_and_dangle")
	Input.action_release("p1_use")

	# --- toàn cảnh màn ---
	ch.set_physics_process(false)                    # camera đứng yên để chụp toàn cảnh
	ch.camera.limit_left = -100000
	ch.camera.limit_top = -100000
	ch.camera.limit_right = 100000
	ch.camera.limit_bottom = 100000
	ch.hud.hide()
	ch.rope.hide()
	for b in ch.balls:
		b.hide()
	var z := 1280.0 / ch.level.size.x
	ch.camera.zoom = Vector2(z, z)
	ch.camera.global_position = ch.level.size / 2.0
	await _frames(6)
	await _shot("level_overview")
	for half in 2:                                   # hai nửa màn, dễ nhìn hơn
		ch.camera.zoom = Vector2(0.62, 0.62)
		ch.camera.global_position = Vector2(ch.level.size.x * (0.25 + 0.5 * half), ch.level.size.y / 2.0)
		await _frames(6)
		await _shot("level_overview_half%d" % (half + 1))
	ch.rope.show()
	ch.hud.show()
	for b in ch.balls:
		b.show()
	ch.queue_free()
	await _frames(150)

	# --- bảng kết quả (P1 hơn P2) ---
	ch = await _start()
	await _wait_running(ch)
	await _frames(30)
	_place(ch, 0, 121.0, 15)                         # hai người ở cạnh cờ đích
	_place(ch, 1, 122.5, 15)
	await _frames(40)
	for i in 5:
		ch.rope.add_bead(0.5)
	ch.rope.beads[0].t = 0.2
	ch.rope.beads[1].t = 0.3
	ch.rope.beads[2].t = 0.4
	ch.rope.beads[3].t = 0.8
	ch.rope.beads[4].t = 0.7
	ch.rope.freeze_beads = true
	ch.level.finish()
	await _frames(80)
	await _shot("result_panel")
	ch.queue_free()
	await _frames(150)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if dir != "" and img:
		img.save_png(dir.path_join(shot_name + ".png"))
