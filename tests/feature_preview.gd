extends Node
## Chụp ảnh trận boss, vật phẩm và các đoạn đường cong. Chạy có cửa sổ:
##   godot --path . res://tests/feature_preview.tscn -- --shots=<thư mục>

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false
	# Bảng HOW TO PLAY
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(20)
	menu._show_howto()
	await _frames(10)
	await _shot("menu_howto")
	menu.queue_free()
	await _frames(2)
	# Trận boss: lúc boss cảnh báo (dấu !) và lúc boss choáng
	Game.level_index = LevelData.LEVELS.size() - 1
	var play: Node = load("res://scenes/play.tscn").instantiate()
	add_child(play)
	await _frames(10)
	play.ball.teleport(Vector2(400, play.level.start_position.y))
	play.ball.add_ammo(15)
	play.ball.give_shield()
	play.ball.give_jump_boost()
	play.level.heart_collected.emit()
	await _frames(30)
	await _shot("boss_appears")
	var boss: Boss = null
	for c in play.level.get_children():
		if c is Boss:
			boss = c
	play.ball.invuln = 99.0
	boss.state = Boss.State.WARN
	boss._timer = 5.0
	await _frames(12)
	await _shot("boss_warn")
	boss.state = Boss.State.DIZZY
	boss._timer = 5.0
	boss.take_damage(7)
	await _frames(12)
	await _shot("boss_dizzy_phase2")
	play.queue_free()
	await _frames(2)
	# Vật phẩm cận cảnh
	var lv := Level.new()
	add_child(lv)
	lv.build("#................#\n#................#\n#................#\n#..O..+..h..g..j.#\n##################")
	var cam := Camera2D.new()
	cam.zoom = Vector2(2.2, 2.2)
	add_child(cam)
	cam.make_current()
	cam.global_position = Vector2(300, 110)
	var ball: Ball = load("res://scenes/ball.tscn").instantiate()
	ball.position = lv.start_position
	lv.add_child(ball)
	await _frames(30)
	await _shot("pickups")
	lv.queue_free()
	await _frames(2)
	# Các đoạn đường cong
	for seg in SegmentData.SEGMENTS:
		if not seg["name"] in ["Rolling Hills", "Bumpy Road", "Valley Ride"]:
			continue
		var l := Level.new()
		add_child(l)
		l.build(seg["map"])
		var z := minf(1280.0 / l.size.x, 720.0 / l.size.y) * 1.6
		cam.zoom = Vector2(z, z)
		cam.global_position = Vector2(l.size.x / 2.0, l.size.y - 140)
		await _frames(20)
		await _shot("curve_" + String(seg["name"]).replace(" ", "_"))
		l.queue_free()
		await _frames(2)
	get_tree().quit()


func _frames(n: int) -> void:
	for k in n:
		await get_tree().physics_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name_ + ".png"))
