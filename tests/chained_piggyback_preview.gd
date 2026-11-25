extends Node

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false
	await _panel_shot()
	await _riding_shots()
	get_tree().quit()


func _start() -> Chained:
	Game.chained_index = 0
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	var ch: Chained = load("res://scenes/chained.tscn").instantiate()
	ch.intro_seconds = 0.6
	ch.respawn_delay = 0.5
	ch.finish_panel_delay = 0.3
	ch.scene_changes_enabled = false
	add_child(ch)
	await _frames(2)
	return ch


func _wait_running(ch: Chained) -> void:
	while not ch.match_running:
		await get_tree().physics_frame


func _panel_shot() -> void:
	Game.chained_piggyback = 0
	var ch := await _start()
	await _wait_running(ch)
	await _frames(30)
	ch.balls[0].teleport(Vector2(121.0 * 32.0, 15.0 * 32.0 + 16.0))
	ch.balls[1].teleport(Vector2(122.5 * 32.0, 15.0 * 32.0 + 16.0))
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
	await _shot("1_result_panel")
	ch.queue_free()
	await _frames(150)


func _riding_shots() -> void:
	Game.chained_piggyback = 1
	var ch := await _start()
	await _wait_running(ch)
	await _frames(8)
	await _shot("2_mounting")
	await _frames(60)
	await _shot("3_riding_banner")
	Input.action_press("p2_right")
	await _frames(30)
	await _shot("4_charging")
	Input.action_press("p1_jump")
	await _frames(1)
	Input.action_release("p1_jump")
	Input.action_release("p2_right")
	await _frames(22)
	await _shot("5_jump_riding")
	await _frames(70)
	ch.balls[1].teleport(Vector2(30.0 * 32.0, 15.0 * 32.0 + 16.0))
	await _frames(60)
	ch.piggyback.seconds_left = 1.5
	await _frames(55)
	await _shot("6_almost_over")
	await _frames(32)
	await _frames(8)
	await _shot("7_hop_off")
	await _frames(60)
	await _shot("8_after")
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
