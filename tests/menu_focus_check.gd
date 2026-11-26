extends Node

var failures := 0


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("ok   - %s" % what)
	else:
		failures += 1
		print("FAIL - %s" % what)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _neighbor(from: Control, path: NodePath) -> Node:
	return from.get_node_or_null(path)


func _ready() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for k in 4:
		await get_tree().process_frame
	var first_level: Button = menu.level_grid.get_child(1)
	_expect(menu.level_grid.get_child(0).text.begins_with("ENDLESS") and first_level.text.begins_with("1."), "level grid: button 0 is ENDLESS RUN, button 1 is level 1 ('%s')" % first_level.text)
	_expect(get_viewport().gui_get_focus_owner() == first_level, "initial focus is on level 1, not ENDLESS RUN (focus: %s)" % str(get_viewport().gui_get_focus_owner()))
	var spy := {"endless": 0, "level": 0, "chained": 0}
	for sig in [menu.level_grid.get_child(0).pressed, first_level.pressed, menu.chained_button.pressed]:
		for c in sig.get_connections():
			sig.disconnect(c["callable"])
	menu.level_grid.get_child(0).pressed.connect(func() -> void: spy["endless"] += 1)
	first_level.pressed.connect(func() -> void: spy["level"] += 1)
	menu.chained_button.pressed.connect(func() -> void: spy["chained"] += 1)
	first_level.grab_focus()
	for code in [KEY_SPACE, KEY_W, KEY_UP]:
		_key(code, true)
		await get_tree().process_frame
		_key(code, false)
		await get_tree().process_frame
	_expect(spy["level"] == 0 and spy["endless"] == 0, "menu: Space / W / Up do not press the focused button (level %d, endless %d)" % [spy["level"], spy["endless"]])
	_key(KEY_DOWN, true)
	await get_tree().process_frame
	_key(KEY_DOWN, false)
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() != first_level, "menu: arrow keys still move the focus (now: %s)" % str(get_viewport().gui_get_focus_owner()))
	menu.chained_button.grab_focus()
	_key(KEY_SPACE, true)
	await get_tree().process_frame
	_key(KEY_SPACE, false)
	await get_tree().process_frame
	_expect(spy["chained"] == 0, "menu: Space does not press CHAINED 2P either")
	_key(KEY_ENTER, true)
	await get_tree().process_frame
	_key(KEY_ENTER, false)
	await get_tree().process_frame
	_expect(spy["chained"] == 1, "menu: Enter presses the focused button")
	first_level.grab_focus()
	_key(KEY_ENTER, true)
	await get_tree().process_frame
	_key(KEY_ENTER, false)
	await get_tree().process_frame
	_expect(spy["level"] == 1 and spy["endless"] == 0, "menu: Enter on the initial focus starts level 1, not ENDLESS RUN (level %d, endless %d)" % [spy["level"], spy["endless"]])
	var b1: Button = menu.brawl_button
	var b2: Button = menu.bot_button
	var b3: Button = menu.chained_button
	_expect(_neighbor(b1, b1.focus_neighbor_right) == b2, "BRAWL 2P: Right goes to BRAWL VS BOT")
	_expect(_neighbor(b2, b2.focus_neighbor_left) == b1, "BRAWL VS BOT: Left goes to BRAWL 2P")
	_expect(_neighbor(b2, b2.focus_neighbor_right) == b3, "BRAWL VS BOT: Right goes to CHAINED 2P")
	_expect(_neighbor(b3, b3.focus_neighbor_left) == b2, "CHAINED 2P: Left goes to BRAWL VS BOT")
	_expect(_neighbor(b1, b1.focus_neighbor_left) == b1, "BRAWL 2P: Left stays put (end of row)")
	_expect(_neighbor(b3, b3.focus_neighbor_right) == b3, "CHAINED 2P: Right stays put (end of row)")
	var cells: Array = menu.level_grid.get_children()
	var same := cells.size() > 2
	var w0: float = cells[0].size.x
	for c in cells:
		same = same and absf(c.size.x - w0) < 0.5
	_expect(same, "level grid: every button has the same width (%s)" % str(cells.map(func(c): return c.size.x)))
	_expect(absf(menu.level_grid.custom_minimum_size.x - menu.brawl_row.size.x) < 1.0 or absf(menu.level_grid.size.x - menu.brawl_row.size.x) < 1.0, "level grid is as wide as the 2P row")
	menu._show_howto()
	await get_tree().process_frame
	_expect(menu.howto_back.disabled and menu.howto_back.focus_mode == Control.FOCUS_NONE, "HOW TO PLAY page 1: disabled Back has FOCUS_NONE")
	_expect(not menu.howto_next.disabled and menu.howto_next.focus_mode == Control.FOCUS_ALL, "HOW TO PLAY page 1: enabled Next has FOCUS_ALL")
	menu._show_howto_page(1)
	await get_tree().process_frame
	_expect(menu.howto_next.disabled and menu.howto_next.focus_mode == Control.FOCUS_NONE, "HOW TO PLAY page 2: disabled Next has FOCUS_NONE")
	_expect(not menu.howto_back.disabled and menu.howto_back.focus_mode == Control.FOCUS_ALL, "HOW TO PLAY page 2: enabled Back has FOCUS_ALL")
	menu._show_howto_page(0)
	await get_tree().process_frame
	var page_before: int = menu.howto_page
	_key(KEY_SPACE, true)
	await get_tree().process_frame
	_key(KEY_SPACE, false)
	await get_tree().process_frame
	_expect(menu.howto_page == page_before, "HOW TO PLAY: Space on Next does not turn the page (page %d)" % menu.howto_page)
	_key(KEY_ENTER, true)
	await get_tree().process_frame
	_key(KEY_ENTER, false)
	await get_tree().process_frame
	_expect(menu.howto_page == page_before + 1, "HOW TO PLAY: Enter on Next turns the page (page %d)" % menu.howto_page)
	_expect(menu.HOW_TO_PLAY[3][1][1].contains("R: back to checkpoint (-1 life)") and menu.HOW_TO_PLAY[3][1][1].contains("Esc twice: menu") and not menu.HOW_TO_PLAY[3][1][1].contains("respawn"), "HOW TO PLAY page 1 matches the story HUD hints ('%s')" % menu.HOW_TO_PLAY[3][1][1])
	_expect(str(menu._two_player_help()).contains("Hold R"), "HOW TO PLAY page 2: the CHAINED line says hold R")
	for page in 2:
		menu._show_howto_page(page)
		await get_tree().process_frame
		await get_tree().process_frame
		var r: Rect2 = menu._howto.get_global_rect()
		_expect(r.position.y >= 0.0 and r.end.y <= 720.0 and r.position.x >= 0.0 and r.end.x <= 1280.0, "HOW TO PLAY page %d fits 1280x720 (%s)" % [page + 1, str(r)])
	print("MENU FOCUS CHECKS %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	get_tree().quit(failures)
