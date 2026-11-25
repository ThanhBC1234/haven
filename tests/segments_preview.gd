extends Node

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(40)
	await _shot("menu")
	menu.queue_free()
	await _frames(2)
	var endless: Node = load("res://scenes/endless.tscn").instantiate()
	add_child(endless)
	await _frames(60)
	await _shot("endless_start")
	for k in 3:
		var far: Level = endless.chunks[-1]
		endless.ball.teleport(far.position + far.start_position)
		await _frames(15)
	await _frames(40)
	await _shot("endless_later")
	for k in 3:
		endless._on_ball_hurt()
		await get_tree().create_timer(1.0).timeout
	await _shot("endless_game_over")
	endless.queue_free()
	await _frames(2)
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	var i := 0
	for seg in SegmentData.SEGMENTS:
		var lv := Level.new()
		add_child(lv)
		lv.build(seg["map"])
		var z := minf(1280.0 / lv.size.x, 720.0 / lv.size.y)
		cam.zoom = Vector2(z, z)
		cam.global_position = lv.size / 2.0
		await _frames(20)
		await _shot("seg_%02d" % i)
		lv.queue_free()
		await _frames(2)
		i += 1
	get_tree().quit()


func _frames(n: int) -> void:
	for k in n:
		await get_tree().physics_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name_ + ".png"))
