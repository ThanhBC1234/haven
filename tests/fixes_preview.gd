extends Node

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false
	await _menu_shots()
	await _brawl_shots(true)
	await _brawl_shots(false)
	await _chained_shots()
	get_tree().quit()


func _menu_shots() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(50)
	await _shot("1_menu")
	menu._show_howto()
	await _frames(6)
	await _shot("2_howto_page1")
	menu.howto_next.pressed.emit()
	await _frames(6)
	await _shot("3_howto_page2")
	menu.queue_free()
	await _frames(3)


func _brawl_shots(vs_bot: bool) -> void:
	var tag := "bot" if vs_bot else "2p"
	Game.brawl_vs_bot = vs_bot
	var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
	br.arena_index = 0
	add_child(br)
	Game.brawl_vs_bot = false
	br.events.enabled = false
	br.items.enabled = false
	await _frames(30)
	await _shot("4_brawl_%s_ready" % tag)
	while not br.match_running:
		await get_tree().physics_frame
	await _frames(20)
	await _shot("5_brawl_%s_bounce" % tag)
	await _frames(60)
	await _shot("6_brawl_%s_goal" % tag)
	await _frames(200)
	await _shot("7_brawl_%s_hint" % tag)
	if vs_bot:
		br.bot.enabled = false
		br.scores[0] = Brawl.WIN_SCORE - 1
		br.kill(br.balls[1], "pit")
		await _frames(100)
		await _shot("8_brawl_bot_win_panel")
	br.queue_free()
	await _frames(200)


func _chained_shots() -> void:
	Game.chained_index = 0
	Game.chained_piggyback = 1
	var ch := await _chained_start()
	await _wait_running(ch)
	await _frames(14)
	await _shot("9_chained_piggyback_start")
	await _frames(40)
	await _shot("10_chained_piggyback_later")
	ch.queue_free()
	await _frames(200)
	Game.chained_piggyback = 0
	ch = await _chained_start()
	await _wait_running(ch)
	await _frames(14)
	await _shot("11_chained_go")
	await _frames(60)
	await _shot("12_chained_goal")
	ch.queue_free()
	await _frames(200)


func _chained_start() -> Chained:
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	var ch: Chained = load("res://scenes/chained.tscn").instantiate()
	ch.intro_seconds = 0.8
	ch.scene_changes_enabled = false
	add_child(ch)
	await _frames(2)
	ch.events.enabled = false
	return ch


func _wait_running(ch: Chained) -> void:
	while not ch.match_running:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if dir != "" and img:
		img.save_png(dir.path_join(shot_name + ".png"))
