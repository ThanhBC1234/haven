extends Node

var s


func run(smoke: Node) -> void:
	s = smoke
	for c in s.get_children():
		if c != self:
			c.queue_free()
	await s._frames(3)
	s._release_all_keys()
	await _graph_checks()
	await _budget_checks()
	await _key_checks()
	await _panel_checks()
	await _howto_checks()
	await _goal_checks()
	s._release_all_keys()


func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	return ev


func _key_down(keycode: Key) -> void:
	Input.parse_input_event(_key_event(keycode, true))


func _key_up(keycode: Key) -> void:
	Input.parse_input_event(_key_event(keycode, false))


func _tap(keycode: Key, hold_frames := 3) -> void:
	_key_down(keycode)
	await s._frames(hold_frames)
	_key_up(keycode)
	await s._frames(2)


func _bound(action: String, keycode: Key) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == keycode:
			return true
	return false


func _graph_of(arena: int, budget: int, perturb := false) -> Dictionary:
	Game.brawl_vs_bot = true
	var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
	br.arena_index = arena
	br.intro_seconds = 0.05
	add_child(br)
	Game.brawl_vs_bot = false
	br.events.enabled = false
	br.items.enabled = false
	var bot: BrawlBot = br.bot
	bot.set_physics_process(false)
	if perturb:
		bot.ball.boost_time = 5.0
		bot.ball.set_size(1.25)
	var guard := 0
	while not bot._graph_done and guard < 200000:
		bot._graph_step(budget)
		guard += 1
	var result := {"nodes": bot._nodes.duplicate(), "edges": bot._redges.duplicate(true), "ticks": bot._graph_ticks, "done": bot._graph_done}
	await s._frames(8)
	br.queue_free()
	await s._frames(2)
	return result


func _graph_checks() -> void:
	for arena in BrawlData.ARENAS.size():
		var by_frame := await _graph_of(arena, -1)
		var nodes: int = by_frame["nodes"].size()
		var edge_count := 0
		for e in by_frame["edges"]:
			edge_count += e.size()
		var budget := await _graph_of(arena, BrawlBot.TICK_BUDGET_USEC)
		var tiny := await _graph_of(arena, 1)
		var arena_name: String = BrawlData.ARENAS[arena]["name"]
		s._expect(by_frame["done"] and nodes > 20 and edge_count > nodes and by_frame["ticks"] == nodes, "bot graph '%s': frame mode builds %d nodes / %d edges, one node per tick (%d ticks)" % [arena_name, nodes, edge_count, by_frame["ticks"]])
		s._expect(budget["done"] and budget["nodes"] == by_frame["nodes"] and budget["edges"] == by_frame["edges"], "bot graph '%s': the %d us time budget gives the IDENTICAL graph (%d ticks)" % [arena_name, BrawlBot.TICK_BUDGET_USEC, budget["ticks"]])
		s._expect(tiny["done"] and tiny["edges"] == by_frame["edges"] and tiny["ticks"] > nodes * 17 * 5, "bot graph '%s': a jump simulation split over many ticks (1 us budget: %d ticks for %d nodes x 17 jumps, a few steps per tick) is still the IDENTICAL graph" % [arena_name, tiny["ticks"], nodes])
		if arena == 0:
			var odd := await _graph_of(arena, -1, true)
			s._expect(odd["edges"] == by_frame["edges"], "bot graph '%s': a jump boost or a bigger ball at build time does not change the graph" % arena_name)


func _budget_checks() -> void:
	var br: Brawl = await s._bot_br(0, 301)
	var bot: BrawlBot = br.bot
	bot.enabled = false
	var b := br.balls[1]
	await s._frames(10)
	var runs: Array = []
	for slow in [false, true]:
		seed(7)
		bot._deadline = 0 if slow else Time.get_ticks_usec() + 1000000000
		bot._begin_think()
		var calls := 0
		while bot.phase == "think" or bot.phase == "choose":
			if bot.phase == "think":
				bot._think_step()
			else:
				bot._choose_step()
			calls += 1
		runs.append([bot.last_choice, bot._plan_dir, bot._hold_frames, bot.phase, calls])
	s._expect(runs[0][0] == runs[1][0] and runs[0][1] == runs[1][1] and runs[0][2] == runs[1][2] and runs[0][3] == runs[1][3], "bot budget: choosing in one go or one step per tick gives the SAME choice ('%s' vs '%s')" % [runs[0][0], runs[1][0]])
	s._expect(runs[0][4] == 1 and runs[1][4] > 20, "bot budget: with plenty of time thinking + choosing take one call, with no time left they are spread over many ticks (%d vs %d calls)" % [runs[0][4], runs[1][4]])
	var outcomes: Array = []
	for slow in [false, true]:
		bot.release_all()
		bot._pulses.clear()
		b.charge_dir = 1
		b.charge = 0.6
		bot._plan_dir = 1
		bot._plan_end = b.global_position
		var hops0 := bot.hops
		var aborts0 := bot.aborts
		bot._deadline = 0 if slow else Time.get_ticks_usec() + 1000000000
		bot._jump_now()
		var calls := 1
		while bot.phase == "check" and calls < 5000:
			bot._launch_step()
			calls += 1
		outcomes.append([bot.hops - hops0, bot.aborts - aborts0, calls])
	s._expect(outcomes[0][0] == outcomes[1][0] and outcomes[0][1] == outcomes[1][1] and outcomes[0][0] + outcomes[0][1] == 1, "bot budget: the last-moment launch check gives the SAME verdict in one go or one jump size per tick (jumps %d / aborts %d vs %d / %d, %d vs %d calls)" % [outcomes[0][0], outcomes[0][1], outcomes[1][0], outcomes[1][1], outcomes[0][2], outcomes[1][2]])
	bot.release_all()
	b.charge_dir = 0
	b.charge = 0.0
	await s._free_brawl(br)
	var saved := BrawlBot.tick_budget_usec
	br = await s._bot_br(0, 104)
	bot = br.bot
	var a := br.balls[0]
	b = br.balls[1]
	a.teleport(Vector2(60, 625))
	b.teleport(Vector2(330, 625))
	await s._frames(40)
	var start_gap := absf(b.global_position.x - a.global_position.x)
	var closest := start_gap
	var longest_spread := 0
	var spread := 0
	var deaths := [0]
	br.point_scored.connect(func(_s: Ball, v: Ball, _c: String) -> void: deaths[0] += 1 if v == b else 0)
	BrawlBot.tick_budget_usec = 250
	for i in 60 * 10:
		await s._frames(1)
		closest = minf(closest, absf(b.global_position.x - a.global_position.x))
		spread = spread + 1 if bot.phase == "think" or bot.phase == "choose" or bot.phase == "check" else 0
		longest_spread = maxi(longest_spread, spread)
	BrawlBot.tick_budget_usec = saved
	s._expect(bot.hops >= 2 and closest < start_gap - 100.0 and deaths[0] == 0, "bot budget: even with only 0.25 ms per tick the bot hops toward the player without dying (gap %.0f -> %.0f px, %d hops, deaths %d)" % [start_gap, closest, bot.hops, deaths[0]])
	s._expect(longest_spread >= 5, "bot budget: a small budget spreads a decision over many ticks (%d in a row)" % longest_spread)
	await s._free_brawl(br)


func _key_checks() -> void:
	s._expect(_bound("p1_jump", KEY_W) and _bound("p1_jump", KEY_SPACE) and not _bound("p2_jump", KEY_SPACE), "P1 jumps with W or SPACE (p1_jump), P2 does not get SPACE")
	var solo_ok := true
	for pair in [["solo_left", [KEY_A, KEY_LEFT]], ["solo_right", [KEY_D, KEY_RIGHT]], ["solo_jump", [KEY_W, KEY_SPACE, KEY_UP]], ["solo_use", [KEY_S, KEY_DOWN, KEY_F, KEY_J]]]:
		for k in pair[1]:
			solo_ok = solo_ok and _bound(pair[0], k)
	s._expect(solo_ok, "solo_left / right / jump / use cover A + LEFT, D + RIGHT, W + SPACE + UP, S + DOWN + F + J")
	var plain_ok := _bound("left", KEY_A) and _bound("left", KEY_LEFT) and _bound("right", KEY_D) and _bound("right", KEY_RIGHT) and _bound("jump", KEY_SPACE) and _bound("jump", KEY_W) and _bound("jump", KEY_UP) and _bound("shoot", KEY_F) and _bound("shoot", KEY_J)
	s._expect(plain_ok, "single-player actions left / right / jump / shoot keep their keys")
	_key_down(KEY_SPACE)
	await s._frames(2)
	var space_p1 := Input.is_action_pressed("p1_jump") and Input.is_action_pressed("jump") and Input.is_action_pressed("solo_jump") and not Input.is_action_pressed("p2_jump")
	_key_up(KEY_SPACE)
	await s._frames(2)
	s._expect(space_p1 and not Input.is_action_pressed("p1_jump"), "a real SPACE press triggers p1_jump (not p2_jump) and is released again")

	var br: Brawl = await s._make_brawl(0, 0.2)
	await s._brawl_ready(br)
	var a := br.balls[0]
	var b := br.balls[1]
	var launches := [0, 0]
	a.launched.connect(func() -> void: launches[0] += 1)
	b.launched.connect(func() -> void: launches[1] += 1)
	await _tap(KEY_SPACE, 4)
	await s._frames(6)
	s._expect(launches[0] == 1 and launches[1] == 0, "2P Brawl: SPACE makes P1 jump (P1 launches %d, P2 launches %d)" % [launches[0], launches[1]])
	await s._free_brawl(br)

	br = await s._bot_br(0, 201)
	var bot: BrawlBot = br.bot
	bot.enabled = false
	a = br.balls[0]
	b = br.balls[1]
	var human_launch := [0]
	var bot_launch := [0]
	var uses := [0]
	a.launched.connect(func() -> void: human_launch[0] += 1)
	b.launched.connect(func() -> void: bot_launch[0] += 1)
	a.use_pressed.connect(func() -> void: uses[0] += 1)
	s._expect(a.action_prefix == "solo_" and b.action_prefix == "bot2_" and a.player_id == 1 and b.player_id == 2, "vs-bot: P1 uses the solo_ keys, the bot's ball uses bot2_")
	await _tap(KEY_SPACE, 4)
	await s._frames(60)
	_key_down(KEY_RIGHT)
	await s._frames(12)
	var arrow_right := a.charge_dir == 1 and b.charge_dir == 0 and bot.held_actions().is_empty()
	_key_up(KEY_RIGHT)
	await s._frames(3)
	_key_down(KEY_LEFT)
	await s._frames(12)
	var arrow_left := a.charge_dir == -1 and b.charge_dir == 0 and bot.held_actions().is_empty()
	_key_up(KEY_LEFT)
	await s._frames(3)
	s._expect(arrow_right and arrow_left, "vs-bot: the RIGHT / LEFT arrows tilt P1's ball and never the bot's (bot charge_dir %d)" % b.charge_dir)
	_key_down(KEY_D)
	await s._frames(12)
	var d_ok := a.charge_dir == 1 and b.charge_dir == 0
	_key_up(KEY_D)
	await s._frames(3)
	_key_down(KEY_A)
	await s._frames(12)
	var a_ok := a.charge_dir == -1 and b.charge_dir == 0
	_key_up(KEY_A)
	await s._frames(3)
	s._expect(d_ok and a_ok, "vs-bot: A / D still tilt P1's ball")
	var jumps_ok := true
	for k in [KEY_UP, KEY_W]:
		var before: int = human_launch[0]
		for i in 120:
			if a.on_ground:
				break
			await s._frames(1)
		await s._frames(10)
		await _tap(k, 4)
		await s._frames(6)
		jumps_ok = jumps_ok and human_launch[0] == before + 1
		await s._frames(60)
	s._expect(human_launch[0] == 3 and jumps_ok, "vs-bot: SPACE, UP and W each make P1 jump (%d launches)" % human_launch[0])
	s._expect(bot_launch[0] == 0 and b.charge_dir == 0 and bot.held_actions().is_empty(), "vs-bot: no arrow / jump key ever moved the bot's ball (%d launches)" % bot_launch[0])
	await _tap(KEY_DOWN)
	await _tap(KEY_S)
	s._expect(uses[0] == 2, "vs-bot: DOWN and S are P1's 'use item' keys (%d presses heard)" % uses[0])
	bot.enabled = true
	var heard := [0]
	b.launched.connect(func() -> void: heard[0] += 1)
	for i in 300:
		await s._frames(1)
		if heard[0] >= 1:
			break
	s._expect(heard[0] >= 1 and bot.hops >= 1, "vs-bot: the bot still plays through its own bot2_ actions (%d launches)" % heard[0])
	await s._free_brawl(br)
	s._release_all_keys()


func _mash_ui_keys() -> void:
	for k in [KEY_SPACE, KEY_ENTER, KEY_DOWN, KEY_RIGHT, KEY_LEFT, KEY_UP]:
		_key_down(k)
		await s._frames(1)
		_key_up(k)
		await s._frames(1)


func _brawl_panel_checks(vs_bot: bool) -> void:
	var tag := "vs-bot " if vs_bot else "2P "
	var br: Brawl
	if vs_bot:
		br = await s._bot_br(0, 202)
		br.bot.enabled = false
	else:
		br = await s._make_brawl(0, 0.2)
		await s._brawl_ready(br)
	br.scores[0] = Brawl.WIN_SCORE - 1
	br.kill(br.balls[1], "pit")
	for i in 90:
		if br.hud.win_panel != null:
			break
		await s._frames(1)
	var hud := br.hud
	s._expect(hud.win_panel != null and hud.rematch_button != null and hud.menu_button != null, "%sBrawl win panel appears" % tag)
	var presses := {"rematch": 0, "menu": 0}
	for sig in [hud.rematch_pressed, hud.menu_pressed]:
		for conn in sig.get_connections():
			sig.disconnect(conn["callable"])
	hud.rematch_pressed.connect(func() -> void: presses["rematch"] += 1)
	hud.menu_pressed.connect(func() -> void: presses["menu"] += 1)
	s._expect(not hud.panel_keys_ready and hud.rematch_button.focus_mode == Control.FOCUS_NONE and not hud.rematch_button.has_focus() and not hud.menu_button.has_focus(), "%sBrawl win panel: no button has keyboard focus at first" % tag)
	await _mash_ui_keys()
	s._expect(presses["rematch"] == 0 and presses["menu"] == 0 and not hud.rematch_button.has_focus() and not hud.menu_button.has_focus(), "%sBrawl win panel: Space, Enter and the arrow keys do nothing for the first 0.6 s (rematch %d, menu %d)" % [tag, presses["rematch"], presses["menu"]])
	if not vs_bot:
		var at: Vector2 = hud.menu_button.get_global_rect().get_center()
		var vp := get_tree().root
		var move := InputEventMouseMotion.new()
		move.position = at
		move.global_position = at
		vp.push_input(move, true)
		await s._frames(2)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = true
		click.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(click, true)
		await s._frames(2)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = at
		release.global_position = at
		release.pressed = false
		vp.push_input(release, true)
		await s._frames(3)
		s._expect(presses["menu"] == 1 and presses["rematch"] == 0, "2P Brawl win panel: a mouse click works at once (menu pressed %d)" % presses["menu"])
	await s._frames(40)
	s._expect(hud.panel_keys_ready and hud.rematch_button.has_focus() and hud.rematch_button.focus_mode == Control.FOCUS_ALL and hud.menu_button.focus_mode == Control.FOCUS_ALL, "%sBrawl win panel: after 0.6 s Rematch is focused and the keyboard works" % tag)
	var before_rematch: int = presses["rematch"]
	await _tap(KEY_ENTER, 2)
	s._expect(presses["rematch"] == before_rematch + 1, "%sBrawl win panel: the first deliberate Enter after the delay presses Rematch" % tag)
	await _tap(KEY_RIGHT, 2)
	s._expect(hud.menu_button.has_focus(), "%sBrawl win panel: arrow keys move the focus once the panel is ready" % tag)
	await s._free_brawl(br)


func _chained_panel_checks() -> void:
	var hud := ChainedHud.new()
	add_child(hud)
	hud.setup("x", 5)
	hud.show_result(Vector2i(1, 0), [1, 0], true)
	var presses := {"next": 0, "retry": 0, "menu": 0}
	hud.next_pressed.connect(func() -> void: presses["next"] += 1)
	hud.retry_pressed.connect(func() -> void: presses["retry"] += 1)
	hud.menu_pressed.connect(func() -> void: presses["menu"] += 1)
	s._expect(not hud.panel_keys_ready and hud.next_button.focus_mode == Control.FOCUS_NONE and not hud.next_button.has_focus(), "Chained result panel: no button has keyboard focus at first")
	await _mash_ui_keys()
	s._expect(presses["next"] == 0 and presses["retry"] == 0 and presses["menu"] == 0 and not hud.next_button.has_focus() and not hud.retry_button.has_focus(), "Chained result panel: Space, Enter and the arrow keys do nothing for the first 0.6 s (next %d, retry %d, menu %d)" % [presses["next"], presses["retry"], presses["menu"]])
	await s._frames(40)
	s._expect(hud.panel_keys_ready and hud.next_button.has_focus() and hud.retry_button.focus_mode == Control.FOCUS_ALL, "Chained result panel: after 0.6 s Next level is focused")
	await _tap(KEY_SPACE, 2)
	s._expect(presses["next"] == 0 and hud.next_button.has_focus(), "Chained result panel: SPACE (a jump key) never presses Next level, even after the delay")
	await _tap(KEY_ENTER, 2)
	s._expect(presses["next"] == 1, "Chained result panel: the first deliberate ENTER after the delay presses Next level")
	hud.queue_free()
	var hud2 := ChainedHud.new()
	add_child(hud2)
	hud2.setup("x", 5)
	hud2.show_result(Vector2i(0, 1), [0, 1], false)
	await s._frames(40)
	s._expect(hud2.next_button == null and hud2.retry_button.has_focus(), "Chained result panel on the last level: Retry is focused after the delay")
	hud2.queue_free()
	await s._frames(2)


func _panel_checks() -> void:
	await _brawl_panel_checks(false)
	await _brawl_panel_checks(true)
	await _chained_panel_checks()
	s._release_all_keys()


func _ascii(text: String) -> bool:
	for i in text.length():
		if text.unicode_at(i) > 126 or (text.unicode_at(i) < 32 and text[i] != "\n"):
			return false
	return true


func _controls_of(node: Node) -> Array:
	var out: Array = []
	for n in node.find_children("*", "Control", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree():
			out.append(n)
	return out


func _howto_page_ok(menu: Control) -> bool:
	var screen := Rect2(0, 0, 1280, 720)
	var panel: Rect2 = menu._howto.get_global_rect()
	if not screen.encloses(panel):
		return false
	var rects: Array = []
	for c in _controls_of(menu._howto):
		var r: Rect2 = c.get_global_rect()
		if not panel.encloses(r) or r.size.x <= 0.0 or r.size.y <= 0.0:
			return false
		if c is Label and not _ascii(c.text):
			return false
		rects.append(r)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				return false
	return rects.size() > 8


func _howto_text(menu: Control) -> String:
	var parts: PackedStringArray = []
	for c in _controls_of(menu._howto):
		if c is Label:
			parts.append(c.text)
	return "\n".join(parts)


func _howto_checks() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await s._frames(3)
	var screen := Rect2(0, 0, 1280, 720)
	var hint: Label = menu.two_player_hint
	var hint_rect: Rect2 = hint.get_global_rect()
	s._expect(hint != null and hint.text == "Alone? Try BRAWL VS BOT.  Two players share one keyboard." and _ascii(hint.text), "menu: a one-line hint under the 2P buttons ('%s')" % hint.text)
	var below_row: bool = hint_rect.position.y >= menu.brawl_row.get_global_rect().end.y - 1.0
	var clear := not hint_rect.intersects(menu.brawl_row.get_global_rect()) and not hint_rect.intersects(menu.help.get_global_rect()) and not hint_rect.intersects(menu.level_grid.get_global_rect()) and not hint_rect.intersects(menu.quit_button.get_global_rect())
	s._expect(screen.encloses(hint_rect) and below_row and clear and screen.encloses(menu.brawl_row.get_global_rect()) and screen.encloses(menu.help.get_global_rect()), "menu: the hint sits right under the 2P row, on screen, overlapping nothing (%s)" % hint_rect)
	var logo_ok := true
	for c in _controls_of(menu.get_node("Center")):
		logo_ok = logo_ok and screen.encloses(c.get_global_rect())
	s._expect(logo_ok and screen.encloses(menu.get_node("Center/Box").get_global_rect()), "menu: every label and button still fits the 1280x720 screen")
	menu._show_howto()
	await s._frames(3)
	s._expect(menu._howto != null and menu.howto_page == 0 and menu.howto_back != null and menu.howto_next != null and menu.howto_close != null, "HOW TO PLAY opens on page 1 with Back / Close / Next buttons")
	s._expect(menu.howto_back.text == "Back" and menu.howto_next.text == "Next" and menu.howto_close.text == "Close" and menu.howto_back.disabled and not menu.howto_next.disabled and menu.howto_next.has_focus(), "page 1: Back is disabled, Next is enabled and focused")
	var text1 := _howto_text(menu)
	s._expect("SINGLE PLAYER" in text1 and "MOVE & JUMP" in text1 and "BOSS" in text1 and not "BOUNCE BRAWL" in text1, "page 1 is titled SINGLE PLAYER and has the old single-player help")
	s._expect(_howto_page_ok(menu), "page 1 fits 1280x720 with nothing overlapping (%s)" % menu._howto.get_global_rect())
	await s._shot("howto_page1")
	menu.howto_next.pressed.emit()
	await s._frames(3)
	var text2 := _howto_text(menu)
	s._expect(menu.howto_page == 1 and "2 PLAYERS" in text2 and not "MOVE & JUMP" in text2, "Next opens page 2 titled 2 PLAYERS")
	var has_keys := "A / D + W or SPACE" in text2 and "S = item / anchor" in text2 and "LEFT / RIGHT + UP" in text2 and "DOWN = item / anchor" in text2 and "tilt and charge" in text2 and "press jump to launch" in text2
	var has_brawl := "BOUNCE BRAWL" in text2 and "Stomp their head" in text2 and ("First to %d" % Brawl.WIN_SCORE) in text2 and "pits and spikes" in text2 and "item boxes" in text2 and "BRAWL VS BOT" in text2
	var has_chained := "CHAINED" in text2 and "tied by a rope" in text2 and "LOWER" in text2 and "closer" in text2 and "anchor and slingshot" in text2 and "steal a star" in text2 and "carries the winner" in text2
	s._expect(has_keys and has_brawl and has_chained, "page 2 explains the keys, BOUNCE BRAWL (incl. BRAWL VS BOT) and CHAINED (rope, LOWER, anchor / slingshot, steal, carry)")
	s._expect(menu.howto_next.disabled and not menu.howto_back.disabled and menu.howto_close.has_focus(), "page 2: Next is disabled, Back is enabled, Close is focused")
	s._expect(_howto_page_ok(menu), "page 2 fits 1280x720 with nothing overlapping (%s)" % menu._howto.get_global_rect())
	await s._shot("howto_page2")
	menu.howto_back.pressed.emit()
	await s._frames(3)
	s._expect(menu.howto_page == 0 and "SINGLE PLAYER" in _howto_text(menu) and menu.howto_next.has_focus() and _howto_page_ok(menu), "Back returns to page 1")
	await _tap(KEY_ENTER, 2)
	await s._frames(3)
	s._expect(menu.howto_page == 1, "keyboard: Enter on the focused Next opens page 2")
	await _tap(KEY_LEFT, 2)
	s._expect(menu.howto_back.has_focus(), "keyboard: the LEFT arrow moves the focus from Close to Back")
	await _tap(KEY_ENTER, 2)
	await s._frames(3)
	s._expect(menu.howto_page == 0, "keyboard: Enter on Back returns to page 1")
	menu.howto_next.pressed.emit()
	await s._frames(3)
	await _tap(KEY_ESCAPE, 2)
	await s._frames(2)
	s._expect(menu._howto == null and menu.get_node("Center").visible, "Esc closes the panel from page 2 and shows the menu again")
	menu._show_howto()
	await s._frames(3)
	s._expect(menu._howto != null and menu.howto_page == 0, "re-opening starts on page 1 again")
	await _tap(KEY_ESCAPE, 2)
	await s._frames(2)
	s._expect(menu._howto == null, "Esc closes the panel from page 1")
	menu._show_howto()
	await s._frames(3)
	menu.howto_close.pressed.emit()
	await s._frames(2)
	s._expect(menu._howto == null and menu.get_node("Center").visible, "the Close button closes the panel")
	await s._shot("menu_with_hint")
	menu.queue_free()
	await s._frames(2)


func _goal_checks() -> void:
	var br: Brawl = await s._make_brawl(0, 0.2)
	await s._brawl_ready(br)
	s._expect(br.hud.message_label.text != "STOMP THEIR HEAD! FIRST TO %d" % Brawl.WIN_SCORE or br.hud.message_label.modulate.a < 0.5, "Brawl: the goal line is not shown yet right after BOUNCE! ('%s')" % br.hud.message_label.text)
	await s._frames(20)
	s._expect(br.hud.message_label.text == "STOMP THEIR HEAD! FIRST TO %d" % Brawl.WIN_SCORE and br.hud.message_label.modulate.a > 0.9, "Brawl: the goal line 'STOMP THEIR HEAD! FIRST TO %d' appears after READY... / BOUNCE!" % Brawl.WIN_SCORE)
	await s._free_brawl(br)
	br = await s._make_brawl(1, 0.2)
	for i in 200:
		if br.match_running:
			break
		await s._frames(1)
	await s._frames(10)
	br.kill(br.balls[1], "pit")
	var taunt: String = br.hud.message_label.text
	await s._frames(70)
	s._expect(br.hud.message_label.text == taunt and not "STOMP" in br.hud.message_label.text and Brawl.WIN_SCORE == 5, "Brawl: a point scored before the goal line is due keeps its own message ('%s')" % taunt)
	await s._free_brawl(br)
	var ch: Chained = await s._make_chained(0)
	await s._frames(20)
	s._expect(ch.hud.message_label.text == "STARS SLIDE TO THE LOWER PLAYER!" and ch.hud.message_label.modulate.a > 0.9, "Chained level 1: the goal line 'STARS SLIDE TO THE LOWER PLAYER!' appears after GO! ('%s')" % ch.hud.message_label.text)
	await s._free_chained(ch)
	ch = await s._make_chained(1)
	await s._frames(20)
	s._expect(ch.hud.message_label.text == "GO!" or ch.hud.message_label.modulate.a < 0.05, "Chained level 2: no goal line, only the usual GO! ('%s')" % ch.hud.message_label.text)
	await s._free_chained(ch)
	Game.chained_index = 0
