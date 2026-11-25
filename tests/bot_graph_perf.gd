extends Node


func _ready() -> void:
	Game.save_enabled = false
	for arena in BrawlData.ARENAS.size():
		Game.brawl_vs_bot = true
		var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
		br.arena_index = arena
		br.intro_seconds = 0.05
		add_child(br)
		Game.brawl_vs_bot = false
		var bot: BrawlBot = br.bot
		bot.set_physics_process(false)
		var times: Array[float] = []
		var total := 0.0
		while not bot._graph_done and times.size() < 100000:
			var t0 := Time.get_ticks_usec()
			bot._graph_step(BrawlBot.TICK_BUDGET_USEC)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			times.append(ms)
			total += ms
		var worst := 0.0
		for ms in times:
			worst = maxf(worst, ms)
		print("arena %d (%s): %d nodes, %d ticks to finish, worst tick %.2f ms, mean tick %.2f ms, total %.0f ms, graph hash %d" % [
			arena, br.arena_name, bot._nodes.size(), times.size(), worst, total / maxf(1.0, times.size()), total, str(bot._redges).hash()])
		for k in 20:
			await get_tree().physics_frame
		br.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	get_tree().quit()
