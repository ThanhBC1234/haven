extends Node

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false
	if OS.get_cmdline_user_args().has("--only-bot"):
		await _bot_shots()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only-sudden"):
		for i in BrawlData.ARENAS.size():
			await _sudden_shots(i)
		get_tree().quit()
		return
	for i in BrawlData.ARENAS.size():
		var brawl := await _start(i)
		brawl.events.enabled = false
		await _frames(20)
		await _shot("arena%d_start" % i)
		await _wait_match(brawl)
		Input.action_press("p1_right")
		await _frames(25)
		brawl.kill(brawl.balls[1], "pit")
		await _frames(100)
		Input.action_release("p1_right")
		var b := brawl.balls[1]
		brawl.scores[0] = 2
		brawl.hud.set_scores(2, 1)
		b.teleport(brawl.balls[0].global_position + Vector2(180, -120))
		await _frames(30)
		await _shot("arena%d_mid" % i)
		brawl.kill(brawl.balls[1], "stomp")
		await _frames(18)
		await _shot("arena%d_pancake" % i)
		brawl.stall_timeout = 0.1
		brawl.stall_step = 0.1
		brawl._stall_time = 0.0
		await _frames(110)
		await _shot("arena%d_stall_spikes" % i)
		brawl.scores[0] = Brawl.WIN_SCORE - 1
		brawl.kill(brawl.balls[1], "spikes")
		await _frames(110)
		await _shot("arena%d_win" % i)
		brawl.queue_free()
		await _frames(3)
		await _event_shots(i)
		await _item_shots(i)
	await _bot_shots()
	get_tree().quit()


func _sudden_shots(index: int) -> void:
	var brawl := await _start(index)
	brawl.events.enabled = false
	brawl.items.enabled = false
	await _wait_match(brawl)
	await _frames(40)
	brawl.stall_timeout = 0.2
	brawl.stall_step = 0.05
	brawl.sudden_death_delay = 0.5
	brawl.sudden_death_speed = 120.0
	brawl._reset_stall()
	var tops := {0: Vector2(640, 340), 1: Vector2(640, 250)}
	brawl.balls[0].teleport(tops[index] + Vector2(-60, 0))
	brawl.balls[1].teleport(tops[index] + Vector2(60, 0))
	for ball in brawl.balls:
		ball.invuln = 9999.0
	while not brawl.sudden_death_active:
		await _frames(1)
	await _frames(20)
	await _shot("arena%d_sudden_start" % index)
	while brawl.hazard_y() > 470.0:
		await _frames(1)
	await _shot("arena%d_sudden_midrise" % index)
	brawl.queue_free()
	await _frames(3)


func _bot_shots() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(8)
	await _shot("menu_brawl_buttons")
	menu.queue_free()
	await _frames(3)
	Game.brawl_vs_bot = true
	var brawl := await _start(0)
	brawl.events.enabled = false
	brawl.items.enabled = false
	await _wait_match(brawl)
	await _frames(20)
	await _shot("bot_ready_bounce")
	await _frames(60 * 9)
	brawl.items.give(brawl.balls[1], "gun")
	await _frames(20)
	await _shot("bot_match_in_progress")
	brawl.kill(brawl.balls[1], "pit")
	await _frames(12)
	await _shot("bot_taunt")
	brawl.scores[1] = Brawl.WIN_SCORE - 1
	brawl.hud.set_scores(brawl.scores[0], brawl.scores[1])
	await _frames(100)
	brawl.kill(brawl.balls[0], "stomp")
	await _frames(110)
	await _shot("bot_wins")
	brawl.queue_free()
	await _frames(3)
	Game.brawl_vs_bot = false


func _event_shots(index: int) -> void:
	var brawl := await _start(index)
	var ev := brawl.events
	ev.enabled = true
	ev.first_delay = 0.2
	ev.roulette_seconds = 2.4
	ev.ice_floor_seconds = 4.0
	await _wait_match(brawl)
	await _frames(60)
	await _shot("arena%d_event_roulette" % index)
	ev.enabled = false
	await _frames(20)
	await _shot("arena%d_event_roulette2" % index)
	ev.start_event("ice_floor")
	await _frames(70)
	await _shot("arena%d_event_ice" % index)
	ev.hot_potato_seconds = 5.0
	ev.start_event("hot_potato")
	await _frames(45)
	await _shot("arena%d_event_bomb" % index)
	ev.time_left = 2.0
	await _frames(25)
	await _shot("arena%d_event_bomb_late" % index)
	await _frames(4)
	await _shot("arena%d_event_bomb_late2" % index)
	await _frames(4)
	await _shot("arena%d_event_bomb_late3" % index)
	ev.start_event("reversed_keys")
	await _frames(40)
	await _shot("arena%d_event_reversed" % index)
	brawl.queue_free()
	await _frames(3)


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


func _item_shots(index: int) -> void:
	var brawl := await _start(index)
	brawl.events.enabled = false
	brawl.items.enabled = false
	await _wait_match(brawl)
	await _frames(40)
	var it := brawl.items
	var a := brawl.balls[0]
	var b := brawl.balls[1]
	it.spawn_box("gun")
	it.spawn_box("banana")
	await _frames(50)
	await _shot("arena%d_items_boxes" % index)
	for bx in it.boxes.duplicate():
		it.boxes.erase(bx)
		bx.queue_free()
	var others := {"gun": "spring", "banana": "swap", "swap": "gun", "spring": "banana"}
	for id in BrawlItems.ITEM_IDS:
		it.give(a, id)
		it.give(b, others[id])
		await _frames(6)
		await _shot("arena%d_item_%s" % [index, id])
	it.give(a, "banana")
	it.give(b, "banana")
	it.banana_seconds = 6.0
	it.use(a)
	await _frames(25)
	await _shot("arena%d_item_banana_effect" % index)
	it.give(b, "spring")
	it.use(b)
	b.teleport(b.global_position + Vector2(-110, 0))
	await _frames(45)
	await _shot("arena%d_item_spring_trap" % index)
	for trap in it.traps.duplicate():
		it.traps.erase(trap)
		trap.queue_free()
	brawl.kill(b, "pit")
	await _frames(90)
	await _shot("arena%d_crown_leader" % index)
	var font := UiTheme.main_font()
	var widest := ""
	var widest_w := 0.0
	for cause in BrawlData.TAUNTS:
		for line in BrawlData.TAUNTS[cause]:
			for pair in [[1, 2], [2, 1]]:
				var text := String(line).format({"s": "P%d" % pair[0], "v": "P%d" % pair[1]})
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE).x
				if w > widest_w:
					widest_w = w
					widest = text
	print("longest taunt: '%s' %.0f px at FONT_LARGE" % [widest, widest_w])
	brawl.hud.flash(widest, 6.0, BrawlHud.PLAYER_COLORS[0])
	await _frames(5)
	await _shot("arena%d_taunt_longest" % index)
	brawl.queue_free()
	await _frames(3)
