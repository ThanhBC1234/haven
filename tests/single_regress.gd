extends Node

const TMP_SAVE := "user://single_regress_tmp.cfg"

var failures := 0


func _ready() -> void:
	Game.save_enabled = false
	_release_all_keys()
	await _panel_checks()
	await _controls_tip_checks()
	await _checkpoint_checks()
	await _platform_checks()
	await _pickup_checks()
	_star_checks()
	_load_checks()
	await _boss_message_checks()
	await _esc_story_checks()
	await _esc_endless_checks()
	await _endless_wall_checks()
	await _endless_hud_checks()
	if FileAccess.file_exists(TMP_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	print("RESULT: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _release_all_keys() -> void:
	for a in Game.KEYS:
		Input.action_release(a)


func _play(index: int) -> Node:
	Game.level_index = index
	var play: Node = load("res://scenes/play.tscn").instantiate()
	add_child(play)
	await _frames(20)
	return play


func _endless() -> Node:
	var e: Node = load("res://scenes/endless.tscn").instantiate()
	add_child(e)
	e.hud.retry_pressed.disconnect(Game.start_endless)
	e.hud.menu_pressed.disconnect(Game.go_to_menu)
	await _frames(30)
	return e


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _first_of(node: Node, kind: String) -> Pickup:
	for c in node.get_children():
		if c is Pickup and c.kind == kind and not c.is_queued_for_deletion():
			return c
	return null


func _controls_tip_checks() -> void:
	print("-- the controls tip shows on level 1 and Endless")
	var play := await _play(0)
	_expect(play.hud._message.text == Hud.CONTROLS_TEXT and play.hud._message.modulate.a > 0.9, "level 1: '%s' is on screen right after the start ('%s')" % [Hud.CONTROLS_TEXT, play.hud._message.text])
	play.hud.flash("BOSS DEFEATED!")
	await _frames(170)
	_expect(play.hud._message.text == Hud.CONTROLS_TEXT and play.hud._message.modulate.a > 0.9, "level 1: a later message does not cut the tip off (3.2 s in: '%s')" % play.hud._message.text)
	await _frames(100)
	_expect(play.hud._message.text == "BOSS DEFEATED!", "level 1: the queued message follows once the tip is done ('%s')" % play.hud._message.text)
	play.queue_free()
	await _frames(3)
	play = await _play(1)
	_expect(play.hud._message.modulate.a < 0.05 or play.hud._message.text != Hud.CONTROLS_TEXT, "level 2: no controls tip ('%s')" % play.hud._message.text)
	play.queue_free()
	await _frames(3)
	Game.level_index = 0
	var e := await _endless()
	_expect(e.hud._message.text == Hud.CONTROLS_TEXT and e.hud._message.modulate.a > 0.9, "Endless: the controls tip is on screen at the start ('%s')" % e.hud._message.text)
	e.queue_free()
	await _frames(3)


func _panel_checks() -> void:
	print("-- end panels: Space never presses a button (and everything is locked for 0.7 s)")
	for idx in [0, LevelData.LEVELS.size() - 1]:
		var play := await _play(idx)
		var fired := []
		for sig in [play.hud.next_pressed, play.hud.retry_pressed, play.hud.menu_pressed]:
			for c in sig.get_connections():
				sig.disconnect(c["callable"])
			sig.connect(func() -> void: fired.append(1))
		play.level.finish()
		await _frames(2)
		var row: Container = play.hud._panel.find_children("*", "HBoxContainer", true, false)[0]
		var all_off := true
		for b in row.get_children():
			all_off = all_off and (b as Button).disabled
		_expect(all_off, "level %d: the panel buttons are disabled right after it appears" % (idx + 1))
		_key(KEY_SPACE, true)
		await _frames(2)
		_key(KEY_SPACE, false)
		await _frames(3)
		_expect(fired.is_empty(), "level %d: Space (jump) 2 frames after finishing triggers nothing (%d presses)" % [idx + 1, fired.size()])
		await _frames(50)
		var last: Button = row.get_child(row.get_child_count() - 1)
		_expect(not last.disabled and get_viewport().gui_get_focus_owner() == last, "level %d: after 0.7 s the last button ('%s') is enabled and focused" % [idx + 1, last.text])
		for code in [KEY_SPACE, KEY_W, KEY_UP]:
			_key(code, true)
			await _frames(2)
			_key(code, false)
			await _frames(2)
		_expect(fired.is_empty() and get_viewport().gui_get_focus_owner() == last, "level %d: Space / W / Up never press a panel button, even once it is armed (%d presses, focus kept)" % [idx + 1, fired.size()])
		_key(KEY_ENTER, true)
		await _frames(2)
		_key(KEY_ENTER, false)
		await _frames(2)
		_expect(fired.size() == 1, "level %d: Enter presses the focused button once the panel is armed" % (idx + 1))
		play.queue_free()
		await _frames(3)
	var e := await _endless()
	var retried := []
	e.hud.retry_pressed.connect(func() -> void: retried.append(1))
	e.lives = 1
	e._on_ball_hurt()
	await _frames(2)
	_key(KEY_SPACE, true)
	await _frames(2)
	_key(KEY_SPACE, false)
	await _frames(3)
	_expect(e._over and retried.is_empty(), "Endless game over: Space right after losing does not restart (%d)" % retried.size())
	await _frames(50)
	_key(KEY_SPACE, true)
	await _frames(2)
	_key(KEY_SPACE, false)
	await _frames(2)
	_expect(retried.is_empty(), "Endless game over: Space never restarts, not even after the panel is armed (%d)" % retried.size())
	_key(KEY_ENTER, true)
	await _frames(2)
	_key(KEY_ENTER, false)
	await _frames(2)
	_expect(retried.size() == 1, "Endless game over: Enter restarts after the panel is armed")
	e.queue_free()
	await _frames(3)


func _checkpoint_checks() -> void:
	print("-- Seesaw Valley checkpoint is out of the slime's reach")
	var play := await _play(1)
	var flag := _first_of(play.level, "checkpoint")
	var slime: Enemy = null
	for c in play.level.get_children():
		if c is Enemy and absf(c.global_position.x - flag.global_position.x) < 600.0:
			slime = c
	var min_x := INF
	var max_x := -INF
	for f in 60 * 45:
		await _frames(1)
		min_x = minf(min_x, slime.global_position.x)
		max_x = maxf(max_x, slime.global_position.x)
	var gap := flag.global_position.x - max_x
	_expect(gap > 3.0 * 32.0, "the slime nearest the checkpoint patrols cols %.1f..%.1f, at least 3 tiles from the flag (col %.1f, gap %.0f px)" % [min_x / 32.0, max_x / 32.0, flag.global_position.x / 32.0, gap])
	play.queue_free()
	await _frames(3)


func _platform_checks() -> void:
	print("-- Seesaw Valley moving platform leaves room for a resting ball")
	var play := await _play(1)
	var plat: MovingPlatform = null
	for c in play.level.get_children():
		if c is MovingPlatform:
			plat = c
	var floor_y: float = play.level.size.y - 2.0 * 32.0
	var bottom: float = maxf(plat.from.y, plat.to.y) + MovingPlatform.THICK
	_expect(floor_y - bottom >= 31.0, "the platform's lowest underside (y=%.0f) leaves at least a ball diameter above the floor (y=%.0f)" % [bottom, floor_y])
	play.lives = 50
	play.ball.teleport(Vector2(plat.from.x + 48.0, floor_y - 17.0))
	await _frames(3)
	var max_y := -INF
	var max_v := 0.0
	for f in 60 * 12:
		await _frames(1)
		max_y = maxf(max_y, play.ball.global_position.y)
		max_v = maxf(max_v, play.ball.linear_velocity.length())
	_expect(max_y < floor_y - 14.0 and max_v < 80.0, "a ball resting under the platform is not pressed into the floor (max y %.1f, floor %.0f, max speed %.0f)" % [max_y, floor_y, max_v])
	var tops := [plat.from.y, plat.to.y]
	_expect(absf(tops[0] - tops[1]) > 160.0, "the platform still travels far enough to reach the finish ledge (%.0f px)" % absf(tops[0] - tops[1]))
	play.queue_free()
	await _frames(3)


func _pickup_checks() -> void:
	print("-- heart at full lives and shield while shielded are left alone")
	var play := await _play(LevelData.LEVELS.size() - 1)
	var ball: Ball = play.ball
	var heart := _first_of(play.level, "heart")
	var shield := _first_of(play.level, "shield")
	ball.teleport(heart.global_position + Vector2(0, -16))
	await _frames(6)
	_expect(is_instance_valid(heart) and not heart.used and play.lives == 3, "heart at full lives stays on the map and stays uncollected (lives %d)" % play.lives)
	play.lives = 2
	play.hud.set_lives(2)
	await _frames(4)
	_expect(play.lives == 3 and not is_instance_valid(heart), "standing on the heart after losing a life collects it (lives %d)" % play.lives)
	ball.teleport(shield.global_position + Vector2(0, -16))
	await _frames(6)
	_expect(ball.has_shield and not is_instance_valid(shield), "the shield is collected when the ball has none")
	var extra: Pickup = load("res://scenes/objects/pickup.tscn").instantiate()
	extra.kind = "shield"
	extra.position = ball.global_position + Vector2(0, 16)
	play.level.add_child(extra)
	await _frames(6)
	_expect(is_instance_valid(extra) and not extra.used and ball.has_shield, "a second shield is left in place while already shielded")
	ball.invuln = 0.0
	ball.take_hit()
	await _frames(6)
	_expect(not is_instance_valid(extra) or extra.is_queued_for_deletion(), "after the shield breaks, the shield under the ball is collected")
	_expect(ball.has_shield, "...and gives a fresh shield")
	play.queue_free()
	await _frames(3)
	var e := await _endless()
	var h: Pickup = load("res://scenes/objects/pickup.tscn").instantiate()
	h.kind = "heart"
	h.position = e.ball.global_position + Vector2(0, 16)
	e.chunks[0].add_child(h)
	await _frames(6)
	_expect(is_instance_valid(h) and not h.used and e.lives == 3, "Endless: heart at full lives is left alone")
	e.lives = 1
	await _frames(4)
	_expect(e.lives == 2 and not is_instance_valid(h), "Endless: collected once a life is missing (lives %d)" % e.lives)
	e.queue_free()
	await _frames(3)


func _star_checks() -> void:
	print("-- stars count once per star")
	Game.best_score = 0
	Game.best_stars = {}
	Game.endless_stars = 0
	Game.total_stars = 0
	var cap := Game.story_star_total()
	_expect(cap == 9, "the story levels hold %d stars in total" % cap)
	Game.record_stars(0, 2)
	Game.record_stars(0, 2)
	Game.record_stars(0, 1)
	_expect(Game.total_stars == 2 and Game.best_stars[0] == 2, "replaying a level with the same or fewer stars adds nothing (total %d)" % Game.total_stars)
	Game.record_stars(0, 3)
	_expect(Game.total_stars == 3, "a better run adds only the new stars (total %d)" % Game.total_stars)
	for i in 5:
		for lv in LevelData.LEVELS.size():
			Game.record_stars(lv, Game.star_cap(lv))
	_expect(Game.story_stars() == 9 and Game.total_stars == 9, "after clearing and replaying everything the total is exactly the 9 existing stars (%d)" % Game.total_stars)
	var nb := Game.record_endless(500, 4)
	_expect(Game.total_stars == 13 and Game.endless_stars == 4 and nb, "Endless stars are banked on top of the story stars (endless %d, total %d)" % [Game.endless_stars, Game.total_stars])
	Game.record_stars(1, 3)
	_expect(Game.total_stars == 13, "...and replaying a story level does not touch them (total %d)" % Game.total_stars)


func _write_cfg(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("progress", k, values[k])
	cfg.save(TMP_SAVE)


func _load_checks() -> void:
	print("-- save file validation")
	Game.best_score = 77
	Game.best_stars = {1: 2}
	Game.endless_stars = 5
	_write_cfg({"best_score": "abc", "total_stars": 9, "best_stars": {0: 3, 2: 1}, "endless_stars": 6})
	Game.load_progress(TMP_SAVE)
	_expect(Game.best_score == 77, "best_score=\"abc\" is ignored (kept %d)" % Game.best_score)
	_expect(Game.best_stars == {0: 3, 2: 1} and Game.endless_stars == 6 and Game.total_stars == 10, "the valid keys still load (best_stars %s, endless %d, total %d)" % [str(Game.best_stars), Game.endless_stars, Game.total_stars])
	_write_cfg({"best_score": 1500, "total_stars": "x", "best_stars": "oops", "endless_stars": 2.5})
	Game.load_progress(TMP_SAVE)
	_expect(Game.best_score == 1500 and Game.best_stars.is_empty() and Game.endless_stars == 0, "wrong-typed best_stars / endless_stars are ignored per key (score %d, stars %s, endless %d)" % [Game.best_score, str(Game.best_stars), Game.endless_stars])
	_write_cfg({"best_score": 10, "best_stars": {0: "a", "b": 1, 1: -3, 99: 4, 2: 50}, "endless_stars": 1})
	Game.load_progress(TMP_SAVE)
	_expect(Game.best_stars == {2: 3}, "bad best_stars entries are dropped one by one, values are capped at the level's star count (%s)" % str(Game.best_stars))
	_write_cfg({"best_score": 40, "total_stars": 31, "best_stars": {0: 3, 1: 3, 2: 3}})
	Game.load_progress(TMP_SAVE)
	_expect(Game.endless_stars == 22 and Game.total_stars == 31, "an old save (only total_stars) keeps the surplus as endless stars once Endless was played (endless %d, total %d)" % [Game.endless_stars, Game.total_stars])
	_write_cfg({"best_score": 0, "total_stars": 31, "best_stars": {0: 3, 1: 3, 2: 3}})
	Game.load_progress(TMP_SAVE)
	_expect(Game.endless_stars == 0 and Game.total_stars == 9, "an old save of someone who never played Endless drops the replay surplus (total %d)" % Game.total_stars)
	Game.best_score = 0
	Game.best_stars = {}
	Game.endless_stars = 0
	Game.total_stars = 0


func _boss_message_checks() -> void:
	print("-- the boss tutorial is not replaced by GOT A GUN")
	var play := await _play(LevelData.LEVELS.size() - 1)
	var gun := _first_of(play.level, "gun")
	play.ball.teleport(gun.global_position + Vector2(0, -16))
	await _frames(8)
	var t0: String = play.hud._message.text
	_expect(t0.contains("APPEARS") and play.hud._ammo == 15, "the boss tutorial is on screen while the gun is picked up ('%s')" % t0.split("\n")[0])
	await _frames(100)
	_expect(play.hud._message.text.contains("APPEARS") and play.hud._message.modulate.a > 0.9, "...and still there 1.8 s later")
	await _frames(100)
	_expect(play.hud._message.text.begins_with("GOT A GUN") and play.hud._message.modulate.a > 0.9, "the GOT A GUN message follows afterwards ('%s')" % play.hud._message.text.split("\n")[0])
	play.queue_free()
	await _frames(3)


func _press_back() -> void:
	Input.action_press("back")
	await _frames(2)
	Input.action_release("back")
	await _frames(2)


func _become_current(node: Node) -> void:
	remove_child(node)
	get_tree().root.add_child(node)
	get_tree().current_scene = node


func _esc_story_checks() -> void:
	print("-- Esc in a story level asks twice")
	var play := await _play(0)
	_become_current(play)
	await _press_back()
	_expect(get_tree().current_scene == play and play.hud.quit_label.visible and play.hud.quit_label.text == "PRESS ESC AGAIN TO QUIT", "first Esc shows PRESS ESC AGAIN TO QUIT and stays in the level")
	await _frames(135)
	_expect(not play.hud.quit_label.visible and get_tree().current_scene == play, "the prompt disappears after 2 s")
	await _press_back()
	await _frames(60)
	_expect(play.hud.quit_label.visible and get_tree().current_scene == play, "a late second Esc only asks again")
	await _press_back()
	await _frames(5)
	_expect(get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.MENU_SCENE, "the second Esc inside the window goes to the menu")
	get_tree().current_scene.queue_free()
	await _frames(3)
	var play2 := await _play(0)
	_become_current(play2)
	play2.level.finish()
	await _frames(3)
	await _press_back()
	await _frames(5)
	_expect(get_tree().current_scene.scene_file_path == Game.MENU_SCENE, "Esc on the level-complete panel goes straight to the menu")
	get_tree().current_scene.queue_free()
	await _frames(3)


func _esc_endless_checks() -> void:
	print("-- Esc in Endless asks twice and the run is recorded")
	Game.best_score = 100
	Game.endless_stars = 10
	Game.best_stars = {}
	Game.total_stars = 10
	var e := await _endless()
	e.hud.retry_pressed.connect(Game.start_endless)
	e.hud.menu_pressed.connect(Game.go_to_menu)
	_become_current(e)
	for k in 4:
		e.chunks[-1].collect_star()
	e.score = 5000.0
	await _press_back()
	_expect(get_tree().current_scene == e and e.hud.quit_label.visible and Game.best_score == 100 and Game.endless_stars == 10, "first Esc only asks (best %d, endless stars %d)" % [Game.best_score, Game.endless_stars])
	await _press_back()
	await _frames(5)
	_expect(get_tree().current_scene.scene_file_path == Game.MENU_SCENE, "second Esc leaves for the menu")
	_expect(Game.best_score == 5000 and Game.endless_stars == 14 and Game.total_stars == 14, "quitting records the run (best %d, endless stars %d, total %d)" % [Game.best_score, Game.endless_stars, Game.total_stars])
	get_tree().current_scene.queue_free()
	await _frames(3)
	var e2 := await _endless()
	e2.chunks[-1].collect_star()
	e2.score = 7000.0
	e2.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	e2.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	_expect(Game.best_score == 7000 and Game.endless_stars == 15, "closing the window records the run once (best %d, endless stars %d)" % [Game.best_score, Game.endless_stars])
	e2.queue_free()
	await _frames(3)
	var e3 := await _endless()
	e3.hud.menu_pressed.connect(Game.go_to_menu)
	_become_current(e3)
	e3.chunks[-1].collect_star()
	e3.lives = 1
	e3._on_ball_hurt()
	await _frames(3)
	var banked: int = Game.endless_stars
	await _press_back()
	await _frames(5)
	_expect(get_tree().current_scene.scene_file_path == Game.MENU_SCENE and Game.endless_stars == banked, "Esc on the game over panel goes to the menu without recording the run twice (%d stars)" % Game.endless_stars)
	get_tree().current_scene.queue_free()
	await _frames(3)
	Game.best_score = 0
	Game.endless_stars = 0
	Game.total_stars = 0


func _endless_wall_checks() -> void:
	print("-- Endless has a wall at the left edge")
	var e := await _endless()
	var lives0: int = e.lives
	e.ball.jump(-1, 1.0)
	await _frames(150)
	_expect(e.lives == lives0 and e.ball.global_position.x > 0.0 and e.ball.global_position.y < 600.0, "a full left jump from the start costs no life and the ball stays inside (lives %d -> %d, x=%.0f)" % [lives0, e.lives, e.ball.global_position.x])
	e.ball.teleport(e.chunks[0].start_position)
	await _frames(30)
	e.ball.jump(-1, 0.4)
	await _frames(150)
	_expect(e.lives == lives0 and e.ball.global_position.x > 0.0, "a 0.4 left jump neither (lives %d, x=%.0f)" % [e.lives, e.ball.global_position.x])
	for k in 8:
		var far: Level = e.chunks[-1]
		e.ball.teleport(far.position + far.start_position)
		await _frames(12)
	var oldest: Level = e.chunks[0]
	_expect(oldest.get_meta("seg_name") != "Start" and absf(e._left_wall.position.x - (oldest.position.x - 16.0)) < 0.5, "after old chunks are freed the wall follows the oldest chunk (wall x %.0f, chunk x %.0f)" % [e._left_wall.position.x, oldest.position.x])
	e.lives = 3
	e.ball.teleport(oldest.position + Vector2(70.0, oldest.size.y - 64.0 - 16.0))
	await _frames(20)
	e.ball.jump(-1, 1.0)
	await _frames(150)
	_expect(e.lives == 3 and e.ball.global_position.x > oldest.position.x, "a left jump at the oldest chunk's edge stays in (lives %d, x=%.0f, edge %.0f)" % [e.lives, e.ball.global_position.x, oldest.position.x])
	e.queue_free()
	await _frames(3)


func _endless_hud_checks() -> void:
	print("-- Endless HUD: boss bar vs multiplier, game over leftovers, hint")
	var e := await _endless()
	var hud: Hud = e.hud
	_expect(not hud._hint.text.contains("checkpoint") and hud._hint.text.contains("segment"), "the Endless hint talks about the segment start, not a checkpoint ('%s')" % hud._hint.text)
	hud.set_score(1234, 5)
	await _frames(3)
	var mult_bottom: float = hud._mult_label.get_global_rect().end.y
	var title_top: float = Hud.ENDLESS_BOSS_BAR_Y - 6.0 - float(UiTheme.FONT_SMALL) - 4.0
	_expect(title_top > mult_bottom, "the boss name line (top y=%.0f) is below the multiplier text (bottom y=%.0f)" % [title_top, mult_bottom])
	hud._boss_max = 24
	hud._boss_hp = 24
	hud._shield = true
	_expect(hud.boss_bar_visible() and hud.shield_icon_visible(), "(boss bar and shield icon visible while playing)")
	e.lives = 1
	e._on_ball_hurt()
	await _frames(3)
	_expect(e._over and not hud.boss_bar_visible() and not hud.shield_icon_visible(), "game over hides the boss bar (and its hint line) and the shield icon")
	hud.flash("TOO LATE")
	await _frames(2)
	_expect(hud._message.text == "", "no flash message is drawn over the game over panel")
	e.queue_free()
	await _frames(3)
