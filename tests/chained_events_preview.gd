extends Node

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false
	await _shots()
	get_tree().quit()


func _start() -> Chained:
	Game.chained_index = 0
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	var ch: Chained = load("res://scenes/chained.tscn").instantiate()
	ch.intro_seconds = 0.3
	ch.respawn_delay = 0.5
	ch.scene_changes_enabled = false
	add_child(ch)
	await _frames(2)
	while not ch.match_running:
		await get_tree().physics_frame
	await _frames(40)
	return ch


func _place(ch: Chained, c1: float, c2: float, frames := 50) -> void:
	ch.balls[0].teleport(Vector2(c1 * 32.0, 16 * 32.0 - 16.0))
	ch.balls[1].teleport(Vector2(c2 * 32.0, 16 * 32.0 - 16.0))
	await _frames(frames)


func _regroup(ch: Chained, c1: float, c2: float) -> void:
	ch.balls[0].teleport(Vector2(c1 * 32.0, 16 * 32.0 - 16.0))
	ch.balls[1].teleport(Vector2(c2 * 32.0, 16 * 32.0 - 16.0))
	await _frames(6)


func _beads(ch: Chained, ts: Array) -> void:
	for t in ts:
		ch.rope.add_bead(t)


func _shots() -> void:
	var ch := await _start()
	var ev := ch.events
	ev.glide_seconds = 0.6
	await _place(ch, 10.5, 14.5)
	_beads(ch, [0.25, 0.4, 0.6, 0.75])
	await _frames(30)

	ev._start_roulette("giant_tiny")
	await _seconds(0.8)
	await _shot("roulette_spinning")
	await _seconds(0.95)
	await _shot("roulette_landed")
	await _seconds(0.5)

	await _frames(60)
	await _shot("giant_and_tiny")
	ev.stop_event()
	await _frames(40)

	ev.start_event("body_swap")
	await _frames(40)
	await _shot("body_swap_markers")
	ev.stop_event()

	ev.start_event("one_brain")
	await _frames(40)
	await _shot("one_brain")
	ev.stop_event()
	await _frames(20)

	ev.start_event("short_leash")
	await _frames(100)
	await _shot("short_leash")
	ev.stop_event()
	await _frames(60)

	await _place(ch, 8.5, 9.5)
	ev.start_event("bungee")
	await _frames(40)
	for f in 36:
		ch.balls[1].knockback(Vector2(150.0, 0.0))
		await _frames(1)
	await _frames(14)
	await _shot("bungee_stretched")
	ev.stop_event()
	await _frames(100)

	_beads(ch, [0.2, 0.4, 0.6, 0.8])
	ch.balls[0].teleport(Vector2(55.5 * 32.0, 16 * 32.0 - 16.0))
	ch.balls[1].teleport(Vector2(74.5 * 32.0, 16 * 32.0 - 16.0))
	ev.start_event("freedom")
	await _frames(70)
	await _shot("freedom_pit")
	var target: Pickup = null
	for s in ev.freedom_stars:
		if is_instance_valid(s) and not s.used and (target == null or s.global_position.x > target.global_position.x):
			target = s
	ch.balls[1].teleport(target.global_position + Vector2(0.0, -16.0))
	await _frames(30)
	await _shot("freedom_pickup")
	await _regroup(ch, 55.5, 57.5)
	ev.stop_event()
	await _frames(60)

	_beads(ch, [0.3, 0.7])
	ch.balls[0].teleport(Vector2(4.5 * 32.0, 16 * 32.0 - 16.0))
	ch.balls[1].teleport(Vector2(24.5 * 32.0, 16 * 32.0 - 16.0))
	ev.start_event("freedom")
	await _frames(70)
	await _shot("freedom_far_apart")
	await _regroup(ch, 10.5, 12.5)
	ev.stop_event()
	await _frames(120)

	await _place(ch, 10.5, 14.5)
	_beads(ch, [0.2, 0.5, 0.8])
	ev.start_event("earthquake")
	await _frames(50)
	await _shot("earthquake")
	ev.stop_event()
	ch.queue_free()
	await _frames(150)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(round(s * 60.0)))


func _shot(shot_name: String) -> void:
	print("shot ", shot_name)
	await get_tree().process_frame
	RenderingServer.force_draw()
	var img := get_viewport().get_texture().get_image()
	if dir != "" and img:
		img.save_png(dir.path_join(shot_name + ".png"))
