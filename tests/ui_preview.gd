extends Node

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(50)
	await _shot("1_menu")
	menu.queue_free()
	await _frames(2)
	for spot in [[0, 0.0, "2_level1_start"], [0, 1750.0, "3_level1_ledge"], [1, 300.0, "4_level2_crate"], [2, 900.0, "5_level3_corridor"]]:
		Game.level_index = spot[0]
		var play: Node = load("res://scenes/play.tscn").instantiate()
		add_child(play)
		await _frames(10)
		if spot[1] > 0.0:
			play.ball.teleport(Vector2(spot[1], play.level.start_position.y - 40))
			await _frames(5)
			play.camera.global_position = play.ball.global_position
			play.camera.reset_smoothing()
		await _frames(40)
		await _shot(spot[2])
		if spot[2] == "5_level3_corridor":
			play.level.collect_star()
			play.level.finish()
			await _frames(10)
			await _shot("6_complete")
		play.queue_free()
		await _frames(3)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name_ + ".png"))
