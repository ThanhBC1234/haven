extends Node

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false
	await _menu_shot()
	await _level_shots()
	await _new_level_shots(1, "level2", [[62.4, 19, 68.7, 19], [83.5, 13, 85.0, 13]])
	await _new_level_shots(2, "level3", [[80.0, 19, 78.8, 19], [104.5, 19, 103.4, 19]])
	get_tree().quit()


func _menu_shot() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(8)
	await _shot("menu_chained_button")
	menu.queue_free()
	await _frames(3)


func _start(index := 0) -> Chained:
	Game.chained_index = index
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


func _place(ch: Chained, i: int, col: float, row: float) -> void:
	ch.balls[i].teleport(Vector2(col * 32.0, (row + 1) * 32.0 - 16.0))


func _level_shots() -> void:
	var ch := await _start()
	await _frames(20)
	await _shot("level_start_ready")
	await _wait_running(ch)
	await _frames(40)

	Input.action_press("p1_use")
	Input.action_press("p2_use")
	_place(ch, 0, 31.5, 15)
	_place(ch, 1, 39.5, 19)
	await _frames(40)
	for i in 6:
		ch.level.collect_star(ch.balls[i % 2])
		await _frames(8)
	await _frames(90)
	await _shot("rope_stretched_beads")
	Input.action_release("p1_use")
	Input.action_release("p2_use")

	ch.rope.reset()
	Input.action_press("p1_use")
	_place(ch, 0, 63.5, 15)
	_place(ch, 1, 61.5, 15)
	await _frames(40)
	_place(ch, 1, 66.5, 8)
	await _frames(200)
	await _shot("anchor_and_dangle")
	Input.action_release("p1_use")

	ch.set_physics_process(false)
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
	for half in 2:
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

	ch = await _start()
	await _wait_running(ch)
	await _frames(30)
	_place(ch, 0, 121.0, 15)
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


func _new_level_shots(index: int, prefix: String, spots: Array) -> void:
	var ch := await _start(index)
	await _wait_running(ch)
	await _frames(30)
	for i in spots.size():
		var s: Array = spots[i]
		Input.action_press("p2_use")
		_place(ch, 0, s[0], s[1])
		_place(ch, 1, s[2], s[3])
		await _frames(40)
		for k in 4:
			ch.level.collect_star(ch.balls[k % 2])
			await _frames(6)
		await _frames(60)
		await _shot("%s_gameplay%d" % [prefix, i + 1])
		Input.action_release("p2_use")
	ch.set_physics_process(false)
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
	await _shot("%s_overview" % prefix)
	for half in 2:
		ch.camera.zoom = Vector2(0.5, 0.5)
		ch.camera.global_position = Vector2(ch.level.size.x * (0.25 + 0.5 * half), ch.level.size.y / 2.0)
		await _frames(6)
		await _shot("%s_overview_half%d" % [prefix, half + 1])
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
