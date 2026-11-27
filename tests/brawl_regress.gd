extends Node

class Driver extends Node:
	var failures := 0

	func _expect(ok: bool, what: String) -> void:
		print(("  ok   " if ok else "  FAIL ") + what)
		if not ok:
			failures += 1

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().physics_frame

	func _make(arena := 0, vs_bot := false) -> Brawl:
		Game.brawl_vs_bot = vs_bot
		var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
		br.arena_index = arena
		br.intro_seconds = 0.2
		br.respawn_delay = 0.3
		br.win_panel_delay = 0.2
		add_child(br)
		Game.brawl_vs_bot = false
		br.events.enabled = false
		br.items.enabled = false
		for i in 200:
			if br.match_running:
				break
			await _frames(1)
		await _frames(45)
		return br

	func _drop(br: Brawl) -> void:
		br.queue_free()
		await _frames(3)

	func _crowns(ball: Ball) -> int:
		var n := 0
		for c in ball.get_children():
			if c is Brawl.CrownMarker and not c.is_queued_for_deletion():
				n += 1
		return n

	func _world(br: Brawl, screen: Vector2) -> Vector2:
		return screen + br.camera.position - br.get_viewport_rect().size / 2.0

	func run() -> void:
		Game.save_enabled = false
		BrawlBot.tick_budget_usec = -1
		await _check_hud()
		await _check_potato()
		await _check_spawn_camp()
		await _check_boxes_buried()
		await _check_swap()
		await _check_winner_crown()
		await _check_double_ko()
		await _check_bot_charge()
		await _check_esc()
		print("RESULT: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures))
		get_tree().quit(1 if failures > 0 else 0)

	func _check_hud() -> void:
		print("-- HUD: panels fade over the balls, roulette banner moved up")
		var br := await _make(0)
		var hud := br.hud
		var a := br.balls[0]
		_expect(is_equal_approx(hud.panel_alpha("score1"), 1.0) and is_equal_approx(hud.panel_alpha("score2"), 1.0) and is_equal_approx(hud.panel_alpha("event"), 1.0), "with nobody under the HUD every panel is fully opaque")
		a.teleport(_world(br, hud.panel_rects()["score1"].get_center()))
		await _frames(14)
		_expect(hud.panel_alpha("score1") <= 0.35 and is_equal_approx(hud.panel_alpha("score2"), 1.0) and is_equal_approx(hud.panel_alpha("event"), 1.0), "a ball over the P1 score box fades only that box to ~30%% (%.2f / %.2f / %.2f)" % [hud.panel_alpha("score1"), hud.panel_alpha("score2"), hud.panel_alpha("event")])
		a.teleport(br.spawn_points[0])
		await _frames(40)
		_expect(is_equal_approx(hud.panel_alpha("score1"), 1.0), "the box fades back to fully opaque once the ball is gone (%.2f)" % hud.panel_alpha("score1"))
		hud.show_event_roulette(["LOW GRAVITY", "SWAP!", "HOT POTATO"], "SWAP!", 30.0)
		await _frames(2)
		var roll: Rect2 = hud.panel_rects()["event"]
		_expect(hud.event_state == "roulette" and roll.position.y >= 0.0 and roll.end.y <= 100.0 and not roll.intersects(Rect2(380, 190, 520, 112)), "the roulette banner sits in the top strip (y %.0f..%.0f), not over the middle of the arena" % [roll.position.y, roll.end.y])
		_expect(roll.position.x >= hud.panel_rects()["item1"].end.x and roll.end.x <= hud.panel_rects()["item2"].position.x, "...between the two item slots, covering none of the score boxes")
		a.teleport(_world(br, Vector2(640.0, 50.0)))
		await _frames(2)
		_expect(hud.panel_alpha("event") < 0.9, "a ball over the roulette banner fades it")
		a.teleport(br.spawn_points[0])
		hud.hide_event()
		br.events.start_event("hot_potato")
		var carrier := br.events.bomb_carrier
		var other := br.opponent_of(carrier)
		other.teleport(br.spawn_points[0] if carrier == br.balls[1] else br.spawn_points[1])
		carrier.teleport(_world(br, Vector2(850.0, 150.0)))
		await _frames(10)
		var body := Rect2(carrier.global_position - _world(br, Vector2.ZERO) - Vector2(carrier.radius, carrier.radius), Vector2(carrier.radius, carrier.radius) * 2.0)
		_expect(not body.intersects(hud.panel_rects()["event"]) and hud.panel_alpha("event") < 0.9, "the bomb over a carrier's head fades the banner even though the ball body is below it (alpha %.2f)" % hud.panel_alpha("event"))
		br.events.stop_event()
		await _drop(br)

	func _check_potato() -> void:
		print("-- HOT POTATO: respawn invulnerability")
		var br := await _make(0)
		var ev := br.events
		var a := br.balls[0]
		var b := br.balls[1]
		b.invuln = 50.0
		var always_a := true
		for i in 12:
			ev.start_event("hot_potato")
			always_a = always_a and ev.bomb_carrier == a
			ev.stop_event()
		_expect(always_a, "an invulnerable player is never handed the bomb")
		ev.start_event("hot_potato")
		for i in 15:
			b.teleport(a.global_position + Vector2(a.radius + b.radius + 0.5, 0.0))
			await _frames(1)
		_expect(ev.bomb_carrier == a, "touching an invulnerable player does not pass the bomb on")
		b.invuln = 0.0
		for i in 15:
			b.teleport(a.global_position + Vector2(a.radius + b.radius + 0.5, 0.0))
			await _frames(1)
		_expect(ev.bomb_carrier == b, "once the invulnerability ends the same touch passes the bomb")
		ev.stop_event()
		a.teleport(br.spawn_points[0])
		b.teleport(br.spawn_points[1])
		await _frames(30)
		ev.start_event("hot_potato")
		var carrier := ev.bomb_carrier
		var before := [br.scores[0], br.scores[1]]
		carrier.invuln = 0.6
		ev.time_left = 0.05
		await _frames(25)
		_expect(ev.active_event == "hot_potato" and br.scores == before and not carrier.dead, "a bomb that runs out while its carrier is invulnerable waits (no free kill)")
		await _frames(30)
		_expect(ev.active_event == "" and br.scores[br.balls.find(br.opponent_of(carrier))] == before[br.balls.find(br.opponent_of(carrier))] + 1, "...and goes off once the invulnerability is over")
		await _drop(br)

	func _check_spawn_camp() -> void:
		print("-- Spawn camping: respawn away from the opponent")
		for arena in 2:
			var br := await _make(arena)
			var a := br.balls[0]
			var b := br.balls[1]
			br.kill(b, "pit")
			a.teleport(br.spawn_points[1] + Vector2(-20.0, 0.0))
			await _frames(60)
			var gap := a.global_position.distance_to(b.global_position) - a.radius - b.radius
			_expect(not b.dead and b.visible and b.invuln > 0.0 and gap >= Brawl.SPAWN_MIN_GAP, "arena %d: respawning next to a camper puts the player at a safe spot (gap %.0f px)" % [arena, gap])
			_expect(b.global_position.distance_to(br.spawn_points[1]) > Brawl.SPAWN_CLEAR, "arena %d: ...not on the camped spawn point (%.0f px away)" % [arena, b.global_position.distance_to(br.spawn_points[1])])
			a.teleport(br.spawn_points[0])
			await _frames(60)
			br.kill(b, "pit")
			await _frames(60)
			_expect(not b.dead and b.global_position.distance_to(br.spawn_points[1]) < 40.0, "arena %d: with nobody camping the player respawns on its own spawn point (%.0f px)" % [arena, b.global_position.distance_to(br.spawn_points[1])])
			await _drop(br)

	func _check_boxes_buried() -> void:
		print("-- SUDDEN DEATH: boxes under the hazard")
		var br := await _make(0, true)
		var it := br.items
		for ball in br.balls:
			ball.invuln = 99.0
		var box = it.spawn_box("gun", Vector2(1000.0, 624.0 - BrawlItems.BOX_LIFT + 16.0))
		_expect(box != null and it.boxes.size() == 1, "a box can be placed before the hazard exists")
		var bot := br.bot
		bot.enabled = false
		br.balls[0].teleport(br.spawn_points[0])
		await _frames(30)
		var mode := bot._pick_mode(br.balls[0].global_position)
		_expect(mode == "get_box" and bot._box_pos.is_finite(), "the bot goes for a free box (mode %s)" % mode)
		br.sudden_death_active = true
		br._sd_y = box.position.y + 80.0
		mode = bot._pick_mode(br.balls[0].global_position)
		_expect(mode != "get_box" and not bot._box_pos.is_finite(), "the bot ignores a box the rising hazard is about to swallow (mode %s)" % mode)
		br._sd_y = box.position.y + 20.0
		await _frames(3)
		_expect(it.boxes.is_empty() and (not is_instance_valid(box) or box.get_parent() == null), "a box the hazard has passed is removed")
		_expect(it.boxes.is_empty(), "...and no longer counts toward max_boxes")
		br._reset_stall()
		var spot: Vector2 = it._find_spot()
		_expect(spot.is_finite() and it.is_valid_spot(spot), "without a hazard a free spot exists and is valid")
		br.sudden_death_active = true
		br._sd_y = 60.0
		var bad := 0
		for i in 30:
			if it._find_spot().is_finite():
				bad += 1
		_expect(bad == 0 and not it.is_valid_spot(spot), "no new box is placed once the hazard is above every floor (%d bad spots)" % bad)
		br._reset_stall()
		await _drop(br)

	func _check_swap() -> void:
		print("-- SWAP!: not wasted while a player is flattened / respawning")
		var br := await _make(0)
		var ev := br.events
		var a := br.balls[0]
		var b := br.balls[1]
		br.kill(b, "stomp")
		await _frames(5)
		var pos_a := a.global_position
		var shown_before := br.hud.message_label.text
		ev.start_event("swap")
		await _frames(5)
		_expect(br.hud.message_label.text == shown_before and ev.rolling_event == "swap" and a.global_position.distance_to(pos_a) < 40.0, "SWAP! with the opponent flattened does not announce 'SWAP!' and moves nobody (waits: %s)" % ev.rolling_event)
		var never := true
		for i in 60:
			ev.last_event = ""
			never = never and ev.pick_event() != "swap"
		_expect(never, "pick_event() never picks SWAP! while a player is dead")
		var swapped := false
		for i in 240:
			await _frames(1)
			if br.hud.message_label.text == "SWAP!" and ev.rolling_event == "":
				swapped = true
				break
		_expect(swapped and not a.dead and not b.dead, "...it then happens as soon as both players are back (%s)" % str(swapped))
		ev.stop_event()
		br.respawn_delay = 99.0
		br.kill(a, "pit")
		await _frames(5)
		br.hud.flash("-", 0.1)
		ev.start_event("swap")
		var shown := false
		for i in 60 * 4:
			await _frames(1)
			if br.hud.message_label.text == "SWAP!" and br.hud.message_label.modulate.a > 0.0:
				shown = true
			if ev.rolling_event == "":
				break
		_expect(not shown and ev.rolling_event == "" and ev.active_event != "swap", "if the player never comes back SWAP! gives way to another event instead of showing up for nothing (now: '%s')" % ev.active_event)
		ev.stop_event()
		await _drop(br)

	func _check_winner_crown() -> void:
		print("-- Winner keeps the crown and the big size on the win screen")
		var br := await _make(0)
		var a := br.balls[0]
		var b := br.balls[1]
		br.scores[0] = 4
		br.scores[1] = 4
		br.hud.set_scores(4, 4)
		br.kill(b, "pit")
		await _frames(4)
		_expect(br.winner == a and not br.match_running and br.leader == a and is_equal_approx(a.size_factor, Brawl.LEADER_SCALE) and _crowns(a) == 1 and _crowns(b) == 0 and is_equal_approx(b.size_factor, 1.0), "winning from a 4-4 tie: the winner is crowned and big at once, the loser is normal")
		await _frames(50)
		var crown: Node2D = null
		for c in a.get_children():
			if c is Brawl.CrownMarker:
				crown = c
		_expect(br.hud.win_panel != null and crown != null and crown.visible and is_equal_approx(a.size_factor, Brawl.LEADER_SCALE) and a.visible, "...and still is when the win panel is up")
		await _drop(br)

	func _check_double_ko() -> void:
		print("-- Double KO: nobody scores")
		var font := UiTheme.main_font()
		var text := Brawl.DOUBLE_KO_TEXT
		_expect(text == text.to_ascii_buffer().get_string_from_ascii() and text.length() <= 40 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE).x <= 1000.0, "the DOUBLE KO message is ASCII and fits in 1000 px at FONT_LARGE ('%s')" % text)
		var br := await _make(0)
		var a := br.balls[0]
		var b := br.balls[1]
		br.scores[0] = 4
		br.scores[1] = 4
		br.hud.set_scores(4, 4)
		var points := [0]
		var kos := [0]
		br.point_scored.connect(func(_s: Ball, _v: Ball, _c: String) -> void: points[0] += 1)
		br.double_ko.connect(func(_c: String) -> void: kos[0] += 1)
		a.teleport(Vector2(400.0, br.arena_rect.size.y + 400.0))
		b.teleport(Vector2(800.0, br.arena_rect.size.y + 400.0))
		await _frames(4)
		_expect(br.scores == [4, 4] and points[0] == 0 and kos[0] == 1 and br.match_running and br.winner == null and br.hud.message_label.text == Brawl.DOUBLE_KO_TEXT, "both balls falling in the same frame: still 4-4, no point either way, DOUBLE KO shown (scores %s)" % str(br.scores))
		await _frames(70)
		_expect(not a.dead and not b.dead and a.visible and b.visible and br.winner == null, "...and both respawn")
		b.teleport(Vector2(800.0, br.arena_rect.size.y + 400.0))
		await _frames(4)
		_expect(br.winner == a and br.scores[0] == 5 and points[0] == 1, "a single fall still scores for the other player")
		await _drop(br)
		br = await _make(0)
		br.scores[0] = 4
		br.scores[1] = 4
		br.hud.set_scores(4, 4)
		br.sudden_death_active = true
		br._stall_time = br.stall_timeout - 0.001
		br._sd_y = 100.0
		await _frames(4)
		_expect(br.scores == [4, 4] and br.winner == null and not br.sudden_death_active and br.hud.message_label.text == Brawl.DOUBLE_KO_TEXT, "both balls touching the rising hazard in the same frame is a double KO too (scores %s)" % str(br.scores))
		await _drop(br)

	func _check_bot_charge() -> void:
		print("-- Bot: the fired jump charge equals the planned one (both modes)")
		for mode in [-1, BrawlBot.TICK_BUDGET_USEC]:
			BrawlBot.tick_budget_usec = mode
			seed(7)
			var all_diffs: Array[float] = []
			for arena in 2:
				var br := await _make(arena, true)
				br.stall_timeout = 9999.0
				br.balls[0].invuln = 1.0e9
				var bot := br.bot
				var hops := bot.hops
				var planned := -1.0
				var diffs: Array[float] = []
				var rx_plan := RegEx.create_from_string("charge=([0-9.]+)")
				var rx_real := RegEx.create_from_string("real_dir=(-?\\d) .*charge=([0-9.]+)")
				for f in 60 * 30:
					await _frames(1)
					if br.winner != null:
						break
					if bot.phase == "prep" or bot.phase == "charge":
						var m := rx_plan.search(bot.last_choice)
						if m:
							planned = float(m.get_string(1))
					if bot.hops != hops:
						hops = bot.hops
						var m2 := rx_real.search(bot.last_jump)
						if m2 and m2.get_string(1) != "0" and planned >= 0.0:
							diffs.append(absf(float(m2.get_string(2)) - planned))
				var mean := 0.0
				for d in diffs:
					mean += d
				mean /= maxf(1.0, diffs.size())
				_expect(mean < 0.03, "%s arena %d: %d tilted jumps, mean |real - planned| = %.3f (< 0.03), timing aborts %d, safety aborts %d" % ["frame mode" if mode < 0 else "budget mode", arena, diffs.size(), mean, bot.timing_aborts, bot.aborts])
				all_diffs.append_array(diffs)
				await _drop(br)
			var total := 0.0
			for d in all_diffs:
				total += d
			_expect(all_diffs.size() >= 10 and total / maxf(1.0, all_diffs.size()) < 0.03, "%s overall: %d tilted jumps (>= 10), mean |real - planned| = %.3f (< 0.03)" % ["frame mode" if mode < 0 else "budget mode", all_diffs.size(), total / maxf(1.0, all_diffs.size())])
		BrawlBot.tick_budget_usec = -1

	func _check_esc() -> void:
		print("-- Esc: first press only asks, second press within 2 s quits")
		Game.start_brawl(false)
		var br: Brawl = null
		for i in 300:
			var cs = get_tree().current_scene
			if cs is Brawl and cs.match_running:
				br = cs
				break
			await _frames(1)
		await _frames(20)
		_expect(br != null and not br.hud.quit_prompt_label.visible, "no quit prompt before Esc")
		Input.action_press("back")
		await _frames(2)
		Input.action_release("back")
		await _frames(10)
		_expect(get_tree().current_scene == br and br.hud.quit_prompt_label.visible and br.hud.quit_prompt_label.text == "PRESS ESC AGAIN TO QUIT", "the first Esc keeps the match running and shows 'PRESS ESC AGAIN TO QUIT'")
		await _frames(60 * 2 + 20)
		_expect(get_tree().current_scene == br and not br.hud.quit_prompt_label.visible, "the prompt goes away after ~2 s")
		Input.action_press("back")
		await _frames(2)
		Input.action_release("back")
		await _frames(2 * 60 + 30)
		_expect(get_tree().current_scene == br, "an Esc after the window expired only asks again (no quit)")
		Input.action_press("back")
		await _frames(2)
		Input.action_release("back")
		await _frames(30)
		Input.action_press("back")
		await _frames(2)
		Input.action_release("back")
		await _frames(30)
		_expect(not (get_tree().current_scene is Brawl), "a second Esc inside the window goes back to the menu")


func _ready() -> void:
	var d := Driver.new()
	get_tree().root.add_child.call_deferred(d)
	d.run.call_deferred()
