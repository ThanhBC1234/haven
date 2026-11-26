extends Node

const MAX_SPEED := 450.0

var failures := 0


func _ready() -> void:
	Game.save_enabled = false
	_release_all_keys()
	await _yank_checks()
	await _placement_checks()
	await _camera_checks()
	await _keys_checks()
	await _steal_checks()
	await _hud_checks()
	await _heart_checks()
	await _piggyback_checks()
	await _round2_panel_checks()
	await _round2_rope_checks()
	await _round2_misc_checks()
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
	for action in Game.KEYS:
		Input.action_release(action)


func _cpos(col: float, row: float) -> Vector2:
	return Vector2(col * 32.0 + 16.0, (row + 1.0) * 32.0 - 16.0)


func _make(index := 0) -> Chained:
	Game.chained_index = index
	var ch: Chained = load("res://scenes/chained.tscn").instantiate()
	ch.intro_seconds = 0.2
	ch.respawn_delay = 0.3
	ch.restart_delay = 0.3
	ch.finish_panel_delay = 0.2
	ch.scene_changes_enabled = false
	add_child(ch)
	await _frames(2)
	for i in 200:
		if ch.match_running:
			break
		await _frames(1)
	await _frames(30)
	return ch


func _free(ch: Chained) -> void:
	_release_all_keys()
	await _frames(150)
	ch.queue_free()
	await _frames(2)


func _set_beads(rope: Rope, values: Array) -> void:
	rope.beads.clear()
	for v in values:
		var bd := Rope.Bead.new()
		bd.t = v
		rope.beads.append(bd)


func _place(ch: Chained, a: Vector2, b: Vector2, frames := 30) -> void:
	ch.balls[0].teleport(a)
	ch.balls[1].teleport(b)
	await _frames(frames)


func _track(ch: Chained, frames: int) -> Dictionary:
	var maxv := 0.0
	var died: Array[String] = []
	var cb := func(c: String) -> void: died.append(c)
	ch.players_died.connect(cb)
	for i in frames:
		await _frames(1)
		for bb in ch.balls:
			maxv = maxf(maxv, bb.linear_velocity.length())
	ch.players_died.disconnect(cb)
	return {"maxv": maxv, "died": died}


func _in_solid(ch: Chained, p: Vector2) -> bool:
	return ch.level.char_at(int(floor(p.y / 32.0)), int(floor(p.x / 32.0))) == "#"


func _yank_checks() -> void:
	var ch := await _make(0)
	await _place(ch, _cpos(61, 15), _cpos(71, 15), 5)
	ch.events.start_event("short_leash")
	var r := await _track(ch, 150)
	_expect(r["died"].is_empty() and r["maxv"] <= MAX_SPEED, "SHORT LEASH on both edges of the pit: nobody dies, max speed %.0f px/s" % r["maxv"])
	_expect(ch.rope.max_length >= ch.rope.current_length() - 1.0 and ch.rope.rest_length >= ch.rope.current_length() - 1.0, "SHORT LEASH: the rope starts from the players' own distance (rest %.0f, max %.0f, apart %.0f)" % [ch.rope.rest_length, ch.rope.max_length, ch.rope.current_length()])
	await _free(ch)
	ch = await _make(0)
	await _place(ch, _cpos(72, 15), _cpos(81, 15), 5)
	ch.events.start_event("short_leash")
	r = await _track(ch, 150)
	_expect(r["died"].is_empty() and r["maxv"] <= MAX_SPEED, "SHORT LEASH on flat ground, 288 px apart: max speed %.0f px/s" % r["maxv"])
	await _free(ch)
	ch = await _make(0)
	ch.events.bungee_seconds = 1.0
	ch.events.start_event("bungee")
	await _frames(70)
	await _place(ch, _cpos(72, 15), _cpos(88, 15), 2)
	r = await _track(ch, 150)
	_expect(r["died"].is_empty() and r["maxv"] <= MAX_SPEED, "BUNGEE ending 512 px apart: nobody dies, max speed %.0f px/s" % r["maxv"])
	await _free(ch)
	ch = await _make(0)
	ch.events.freedom_seconds = 1.0
	ch.events.start_event("freedom")
	await _frames(5)
	await _place(ch, _cpos(58, 15), _cpos(75, 15), 40)
	r = await _track(ch, 240)
	_expect(r["died"].is_empty() and r["maxv"] <= MAX_SPEED and not ch.rope.cut, "FREEDOM ending with a pit between the players: reattached, nobody dies, max speed %.0f px/s" % r["maxv"])
	await _free(ch)
	ch = await _make(0)
	ch.events.freedom_seconds = 1.0
	ch.events.start_event("freedom")
	await _frames(5)
	await _place(ch, _cpos(75, 15), _cpos(120, 15), 40)
	var apart := ch.rope.current_length()
	r = await _track(ch, 240)
	_expect(r["died"].is_empty() and r["maxv"] <= MAX_SPEED and not ch.rope.cut, "FREEDOM ending %.0f px apart: nobody dies, max speed %.0f px/s" % [apart, r["maxv"]])
	ch.balls[1].teleport(ch.balls[0].global_position + Vector2(80.0, 0.0))
	await _frames(420)
	_expect(is_equal_approx(ch.rope.rest_length, 160.0) and is_equal_approx(ch.rope.max_length, 320.0) and ch.rope.pull_speed_cap == 0.0, "FREEDOM: once the players are close the rope is back to 160 / 320 and the speed cap is off (%.0f / %.0f)" % [ch.rope.rest_length, ch.rope.max_length])
	await _free(ch)
	ch = await _make(0)
	await _place(ch, _cpos(17, 15), _cpos(30, 15), 3)
	var tension := ch.rope.tension()
	_expect(tension > 20000.0 and ch.rope.pull_speed_cap == 0.0, "normal rope unchanged: 13 tiles apart still pulls hard (tension %.0f)" % tension)
	await _free(ch)


func _placement_checks() -> void:
	for n in [4, 8, 12]:
		var ch := await _make(1)
		await _place(ch, _cpos(68, 19), _cpos(73, 13), 2)
		var vals := []
		for i in n:
			vals.append(0.5)
		_set_beads(ch.rope, vals)
		ch.rope._separate()
		await _frames(90)
		ch.events.start_event("freedom")
		await _frames(40)
		var bad := 0
		var valid := 0
		for s in ch.events.freedom_stars:
			if is_instance_valid(s):
				valid += 1
				if _in_solid(ch, s.global_position + Vector2(0, -16)) or not ChainedPlacement.star_clear(ch, s.global_position):
					bad += 1
		_expect(bad == 0 and valid > 0, "FREEDOM with %d beads next to a tower: %d of %d (uncollected) stars inside terrain" % [n, bad, valid])
		ch.events.stop_event()
		await _free(ch)
	var ch2 := await _make(0)
	var spot := ChainedPlacement.find(ch2, Vector2(-500.0, -500.0), [], Vector2(123.0, 456.0), {"range": 10.0})
	_expect(not spot["ok"] and spot["ground"] == Vector2(123.0, 456.0), "placement helper: nothing valid in range -> the fallback (owner's position)")
	var inside := ChainedPlacement.find(ch2, Vector2(1000.0, 700.0), [], Vector2.ZERO)
	_expect(ChainedPlacement.star_clear(ch2, inside["start"]) and inside["ok"] and not _in_solid(ch2, inside["start"] + Vector2(0, -16)), "placement helper: a start point inside solid ground is moved to the nearest empty spot (%s)" % str(inside["start"]))
	await _free(ch2)
	for index in 3:
		var ch := await _make(index)
		var spots: Array[Vector2] = [ch.respawn_position]
		for node in ch.level.get_children():
			if node is Pickup and node.kind == "checkpoint":
				spots.append(node.global_position + Vector2(0, -16))
		var worst_inside := 0
		var short := 0
		for sp in spots:
			for want in [3, 6, 12]:
				ch.respawn_position = sp
				var before := ch.dropped_stars.size()
				ch._scatter_stars(want)
				if ch.dropped_stars.size() - before < want:
					short += 1
				for i in range(before, ch.dropped_stars.size()):
					var s: Pickup = ch.dropped_stars[i]
					if _in_solid(ch, s.position + Vector2(0, -16)) or not ChainedPlacement.star_clear(ch, s.position):
						worst_inside += 1
					s.queue_free()
		_expect(worst_inside == 0 and short == 0, "death scatter, level %d, %d spots x (3, 6, 12) stars: %d inside terrain, %d short of the asked count" % [index + 1, spots.size(), worst_inside, short])
		await _free(ch)


func _visible(ch: Chained, p: Vector2) -> bool:
	var c := ch.camera.get_screen_center_position()
	var half := Vector2(640, 360) / ch.camera.zoom
	return absf(p.x - c.x) < half.x and absf(p.y - c.y) < half.y


func _camera_checks() -> void:
	var ch := await _make(0)
	ch.events.freedom_seconds = 60.0
	ch.events.start_event("freedom")
	await _frames(5)
	await _place(ch, _cpos(4, 15), _cpos(62, 15), 120)
	var both := _visible(ch, ch.balls[0].global_position) and _visible(ch, ch.balls[1].global_position)
	_expect(both, "FREEDOM camera: both players on screen (apart %.0f px, zoom %.2f)" % [ch.rope.current_length(), ch.camera.zoom.x])
	Input.action_press("p2_right")
	var always := true
	var farthest := 0.0
	for i in 240:
		await _frames(1)
		farthest = maxf(farthest, ch.balls[0].global_position.distance_to(ch.balls[1].global_position))
		always = always and _visible(ch, ch.balls[0].global_position) and _visible(ch, ch.balls[1].global_position)
	Input.action_release("p2_right")
	_expect(always and farthest < Rope.FREE_PULL_CAP * 6.0, "FREEDOM camera: both stay on screen while P2 runs away (farthest %.0f px, zoom %.2f)" % [farthest, ch.camera.zoom.x])
	_expect(ch.balls[0].global_position.distance_to(ch.balls[1].global_position) < ChainedEvents.FREE_MAX_APART + 250.0, "FREEDOM: the cut rope still stops the players from drifting too far apart (%.0f px, limit %.0f)" % [ch.balls[0].global_position.distance_to(ch.balls[1].global_position), ChainedEvents.FREE_MAX_APART])
	ch.events.stop_event()
	await _free(ch)
	ch = await _make(0)
	await _place(ch, _cpos(10, 15), _cpos(12, 15), 60)
	_expect(is_equal_approx(ch.camera.zoom.x, 1.0), "camera: players close together keep zoom 1.0")
	await _free(ch)


func _keys_checks() -> void:
	var ch := await _make(0)
	var lives := ch.lives
	var cp := ch.respawn_points.duplicate()
	await _place(ch, _cpos(20, 15), _cpos(22, 15), 20)
	var died: Array[String] = []
	ch.players_died.connect(func(c: String) -> void: died.append(c))
	Input.action_press("restart")
	await _frames(15)
	Input.action_release("restart")
	await _frames(3)
	_expect(died.is_empty() and ch.lives == lives and ch.hud.restart_hold == 0.0, "R tapped for 0.25 s: nothing happens, no life lost, the bar is empty again (lives %d)" % ch.lives)
	Input.action_press("restart")
	await _frames(20)
	var mid_bar := ch.hud.restart_hold
	_expect(mid_bar > 0.2 and mid_bar < 0.9 and died.is_empty(), "R held for 0.33 s: the fill bar is partway (%.2f) and nothing happened yet" % mid_bar)
	await _frames(25)
	Input.action_release("restart")
	await _frames(3)
	_expect(died == ["restart"] and ch.lives == lives - 1 and ch.hud.restart_hold == 0.0, "R held 0.6 s: both players die (cause 'restart') and it costs one shared life (lives %d -> %d)" % [lives, ch.lives])
	await _frames(2)
	Input.action_press("restart")
	await _frames(40)
	Input.action_release("restart")
	_expect(died.size() == 1 and ch.lives == lives - 1, "R while waiting to respawn is ignored")
	for i in 120:
		await _frames(1)
		if not ch.balls[0].dead:
			break
	await _frames(10)
	_expect(not ch.balls[0].dead and ch.balls[0].global_position.distance_to(cp[0]) < 30.0 and ch.balls[1].global_position.distance_to(cp[1]) < 30.0, "R: both players are back at the last checkpoint (%s / %s)" % [str(ch.balls[0].global_position.round()), str(ch.balls[1].global_position.round())])
	await _free(ch)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	ch = await _make(0)
	Input.action_press("back")
	await _frames(3)
	Input.action_release("back")
	var still_here := get_tree().current_scene == dummy and is_instance_valid(ch) and ch.is_inside_tree()
	_expect(still_here and ch.hud.quit_label.visible and ch.hud.quit_label.text == "PRESS ESC AGAIN TO QUIT", "Esc once: the prompt shows and the game continues")
	await _frames(130)
	_expect(not ch.hud.quit_label.visible, "Esc once: the prompt disappears after about 2 seconds")
	Input.action_press("back")
	await _frames(3)
	Input.action_release("back")
	await _frames(60)
	Input.action_press("back")
	await _frames(3)
	Input.action_release("back")
	await _frames(6)
	var cur := get_tree().current_scene
	_expect(cur != dummy and cur != null and cur.scene_file_path == Game.MENU_SCENE, "Esc twice within 2 s: back to the menu")
	if cur != null and cur != dummy:
		cur.queue_free()
	if is_instance_valid(dummy):
		dummy.queue_free()
	await _frames(3)
	if is_instance_valid(ch):
		ch.queue_free()
	await _frames(3)


func _steal_checks() -> void:
	var ch := await _make(0)
	await _place(ch, _cpos(10, 15), _cpos(13, 15), 30)
	_set_beads(ch.rope, [0.8, 0.9])
	ch.rope.freeze_beads = true
	ch.hud.message_label.text = ""
	ch._on_stomped(ch.balls[0], ch.balls[1])
	_expect(ch.rope.bead_counts() == Vector2i(0, 2) and ch.hud.message_label.text == "", "steal: P2 stomps P1 who has no star: nothing moves, no message ('%s')" % ch.hud.message_label.text)
	_set_beads(ch.rope, [0.1, 0.2])
	ch._on_stomped(ch.balls[1], ch.balls[0])
	_expect(ch.rope.bead_counts() == Vector2i(2, 0) and ch.hud.message_label.text == "", "steal: P1 stomps P2 who has no star: nothing moves, no message")
	_set_beads(ch.rope, [0.1, 0.2, 0.8])
	ch._on_stomped(ch.balls[0], ch.balls[1])
	_expect(ch.rope.bead_counts() == Vector2i(1, 2) and ch.hud.message_label.text == "P2 STEALS A STAR!", "steal: P2 stomps P1 who has stars: one star moves to P2 and the message shows ('%s')" % ch.hud.message_label.text)
	ch.rope.freeze_beads = false
	await _place(ch, _cpos(24, 15), _cpos(27, 12), 30)
	_set_beads(ch.rope, [0.1])
	ch._on_stomped(ch.balls[0], ch.balls[1])
	await _frames(240)
	_expect(ch.rope.bead_counts() == Vector2i(0, 1), "steal: the stolen star stays with the thief 4 s later although the victim stands lower (%s)" % str(ch.rope.bead_counts()))
	ch._on_stomped(ch.balls[1], ch.balls[0])
	await _frames(240)
	_expect(ch.rope.bead_counts() == Vector2i(1, 0), "steal: stolen back, it now stays with the new thief (%s)" % str(ch.rope.bead_counts()))
	ch.kill_both("test")
	await _frames(80)
	await _place(ch, _cpos(24, 15), _cpos(27, 12), 30)
	await _frames(240)
	_expect(ch.rope.beads.size() == 1 and ch.rope.beads[0].pin == 0 and ch.rope.bead_counts() == Vector2i(1, 0), "steal: pins are released when the players die (pin %d, counts %s)" % [ch.rope.beads[0].pin, str(ch.rope.bead_counts())])
	await _free(ch)


func _hud_checks() -> void:
	Game.chained_piggyback = 1
	var ch := await _make(0)
	await _frames(40)
	_expect(ch.piggyback.piggyback_active, "setup: the penalty carry is on")
	ch.hud.flash("CHECKPOINT!", 3.0)
	var y_on := ch.hud.message_label.position.y
	var banner_bottom := ChainedPiggyback.Banner.TOP + ChainedPiggyback.Banner.BOX.y + 36.0
	_expect(y_on >= banner_bottom, "messages sit below the piggyback banner and its key hint (message y %.0f >= %.0f)" % [y_on, banner_bottom])
	ch.piggyback.stop_piggyback()
	await _frames(5)
	_expect(is_equal_approx(ch.hud.message_label.position.y, ChainedHud.MESSAGE_Y), "messages go back to their normal height when the carry ends (y %.0f)" % ch.hud.message_label.position.y)
	await _free(ch)
	ch = await _make(2)
	ch.hud.show_result(Vector2i(12, 9), [27, 31], false)
	_expect(ch.hud.result_overall != null and ch.hud.result_overall.text == "PLAYER 2 WINS THE RUN!" and ch.hud.result_piggyback == null and ch.hud.result_title.text == "PLAYER 1 WINS THE LEVEL!", "last level result: names the overall winner from the totals ('%s') and has no MUST CARRY line" % ch.hud.result_overall.text)
	await _free(ch)
	ch = await _make(2)
	ch.hud.show_result(Vector2i(3, 5), [20, 20], false)
	_expect(ch.hud.result_overall.text == "THE RUN IS A TIE!" and ch.hud.result_piggyback == null, "last level result: equal totals -> 'THE RUN IS A TIE!'")
	await _free(ch)
	ch = await _make(0)
	ch.hud.show_result(Vector2i(3, 5), [3, 5], true)
	_expect(ch.hud.result_overall == null and ch.hud.result_piggyback != null and ch.hud.result_piggyback.text == "P1 MUST CARRY P2 NEXT ROUND!", "earlier levels: unchanged ('%s')" % ch.hud.result_piggyback.text)
	await _free(ch)
	Game.chained_piggyback = 0
	ch = await _make(2)
	var flag: Pickup = null
	for n in ch.level.get_children():
		if n is Pickup and n.kind == "finish":
			flag = n
	_set_beads(ch.rope, [0.1, 0.2, 0.9])
	ch.rope.freeze_beads = true
	ch.balls[0].teleport(flag.global_position + Vector2(0, -16))
	ch.balls[1].teleport(flag.global_position + Vector2(-50, -16))
	for i in 200:
		await _frames(1)
		if ch.hud.result_panel != null:
			break
	_expect(ch.hud.result_panel != null and Game.chained_piggyback == 0, "last level: finishing does not queue a penalty (nothing to carry into)")
	await _free(ch)


func _heart_checks() -> void:
	var ch := await _make(0)
	var heart: Pickup = null
	for n in ch.level.get_children():
		if n is Pickup and n.kind == "heart":
			heart = n
			break
	_expect(heart != null, "setup: level 1 has a heart")
	if heart == null:
		await _free(ch)
		return
	ch.hud.message_label.text = ""
	await _place(ch, heart.global_position + Vector2(-8.0, 0.0), heart.global_position + Vector2(24.0, 0.0), 30)
	_expect(is_instance_valid(heart) and not heart.used and not heart.is_queued_for_deletion() and ch.lives == Chained.LIVES and ch.hud.message_label.text != "+1 LIFE!", "full lives: a heart is left alone (not collected, no '+1 LIFE!')")
	ch.kill_both("test")
	await _frames(60)
	await _place(ch, heart.global_position + Vector2(-8.0, 0.0), heart.global_position + Vector2(24.0, 0.0), 30)
	_expect(ch.lives == Chained.LIVES, "one life missing: the same heart is collected (+1 LIFE, lives %d)" % ch.lives)
	await _free(ch)


func _piggyback_checks() -> void:
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.chained_piggyback = 1
	var ch := await _make(0)
	await _frames(60)
	var before := ch.piggyback.seconds_left
	ch.kill_both("test")
	await _frames(2)
	_expect(not ch.piggyback.piggyback_active, "death during the carry: it stops")
	for i in 120:
		await _frames(1)
		if ch.piggyback.piggyback_active:
			break
	var after := ch.piggyback.seconds_left
	_expect(ch.piggyback.piggyback_active and after > before - 0.3 and after < 9.5, "death during the carry: it resumes after the respawn with the remaining time (%.2f s before, %.2f s after, not 10 s)" % [before, after])
	ch.scene_changes_enabled = true
	ch.restart_level()
	ch.queue_free()
	await _frames(5)
	var cur := get_tree().current_scene
	_expect(cur is Chained and cur != ch and cur.piggyback.start_penalty == 1, "out-of-lives restart keeps the penalty for the replayed round (start_penalty %s)" % str(cur.piggyback.start_penalty if cur is Chained else -1))
	if cur is Chained:
		var nxt: Chained = cur
		for i in 200:
			if nxt.match_running:
				break
			await _frames(1)
		await _frames(5)
		_expect(nxt.piggyback.piggyback_active and nxt.piggyback.piggyback_rider == nxt.balls[0], "out-of-lives restart: the carry starts again after the intro")
		nxt.queue_free()
		await _frames(150)
	Game.chained_piggyback = 0
	if is_instance_valid(dummy):
		dummy.queue_free()
	await _frames(3)


func _key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _stroke(code: int) -> void:
	_key(code, true)
	await _frames(3)
	_key(code, false)
	await _frames(3)


func _round2_panel_checks() -> void:
	var ch := await _make(2)
	var fired := {"retry": 0, "menu": 0, "next": 0}
	ch.hud.retry_pressed.disconnect(ch._on_retry)
	ch.hud.menu_pressed.disconnect(Game.go_to_menu)
	ch.hud.retry_pressed.connect(func() -> void: fired["retry"] += 1)
	ch.hud.menu_pressed.connect(func() -> void: fired["menu"] += 1)
	var flag: Pickup = null
	for node in ch.level.get_children():
		if node is Pickup and node.kind == "finish":
			flag = node
	await _place(ch, flag.global_position + Vector2(0, -16), flag.global_position + Vector2(-50, -16), 4)
	for i in 120:
		if ch.hud.panel_keys_ready:
			break
		await _frames(1)
	_expect(ch.hud.result_panel != null and ch.hud.panel_keys_ready and get_viewport().gui_get_focus_owner() == ch.hud.retry_button, "last level: the result panel is armed and Retry has focus")
	for i in 12:
		await _stroke(KEY_SPACE)
		await _stroke(KEY_W)
		await _stroke(KEY_UP)
	_expect(fired["retry"] == 0 and fired["menu"] == 0, "last level result panel: mashing Space / W / Up presses nothing (retry %d, menu %d)" % [fired["retry"], fired["menu"]])
	_expect(get_viewport().gui_get_focus_owner() == ch.hud.retry_button, "... and the arrow key Up did not break the focus (still Retry)")
	await _stroke(KEY_RIGHT)
	_expect(get_viewport().gui_get_focus_owner() == ch.hud.menu_button, "... but the arrow keys still move the focus (Right: Menu)")
	await _stroke(KEY_SPACE)
	_expect(fired["menu"] == 0, "... and Space on the Menu button does nothing either")
	await _stroke(KEY_ENTER)
	_expect(fired["menu"] == 1 and fired["retry"] == 0, "... while Enter presses the focused button (menu %d)" % fired["menu"])
	await _free(ch)
	ch = await _make(0)
	var nexts := [0]
	ch.hud.next_pressed.connect(func() -> void: nexts[0] += 1)
	var flag1: Pickup = null
	for node in ch.level.get_children():
		if node is Pickup and node.kind == "finish":
			flag1 = node
	await _place(ch, flag1.global_position + Vector2(0, -16), flag1.global_position + Vector2(-50, -16), 4)
	for i in 120:
		if ch.hud.panel_keys_ready:
			break
		await _frames(1)
	await _stroke(KEY_SPACE)
	await _stroke(KEY_SPACE)
	_expect(nexts[0] == 0 and get_viewport().gui_get_focus_owner() == ch.hud.next_button, "level 1 result panel: Space does not press Next level (%d presses)" % nexts[0])
	await _free(ch)


func _rope_normal(ch: Chained) -> bool:
	return is_equal_approx(ch.rope.rest_length, 160.0) and is_equal_approx(ch.rope.max_length, 320.0) and is_equal_approx(ch.rope.stiffness, 16.0) and is_equal_approx(ch.rope.damping, 3.0) and ch.rope.pull_speed_cap == 0.0


func _round2_rope_checks() -> void:
	var ch := await _make(0)
	ch.events.bungee_seconds = 1.0
	ch.events.start_event("bungee")
	await _frames(70)
	await _place(ch, _cpos(72, 15), _cpos(88, 15), 2)
	var inverted := 0
	var restored_at := -1
	var died: Array[String] = []
	ch.players_died.connect(func(c: String) -> void: died.append(c))
	var worst_speed := 0.0
	for f in 600:
		await _frames(1)
		if ch.rope.rest_length > ch.rope.max_length + 0.01:
			inverted += 1
		worst_speed = maxf(worst_speed, maxf(ch.balls[0].linear_velocity.length(), ch.balls[1].linear_velocity.length()))
		if restored_at < 0 and _rope_normal(ch):
			restored_at = f
	_expect(restored_at >= 0 and restored_at < 180 and inverted == 0, "BUNGEE end, nobody moves: the rope is back to 160 / 320 within 3 s (%d frames), rest never above max (%d frames inverted)" % [restored_at, inverted])
	_expect(died.is_empty() and worst_speed <= MAX_SPEED, "BUNGEE end, nobody moves: nobody dies, fastest %.0f px/s" % worst_speed)
	await _free(ch)
	ch = await _make(0)
	await _place(ch, _cpos(75, 15), _cpos(82, 15), 30)
	ch.events.start_event("short_leash")
	await _frames(300)
	_expect(ch.rope.current_length() < 140.0 and ch.rope.max_length >= ch.rope.rest_length, "SHORT LEASH, nobody moves: the pair is pulled together (%.0f px apart after 5 s, rest %.0f)" % [ch.rope.current_length(), ch.rope.rest_length])
	ch.events.stop_event()
	await _free(ch)
	ch = await _make(0)
	ch.events.freedom_seconds = 1.0
	ch.events.start_event("freedom")
	await _frames(5)
	await _place(ch, _cpos(72, 15), _cpos(87, 15), 90)
	await _frames(300)
	_expect(_rope_normal(ch), "FREEDOM end, nobody moves (480 px apart): the rope is back to 160 / 320 and the speed cap is off (%.0f / %.0f, cap %.0f)" % [ch.rope.rest_length, ch.rope.max_length, ch.rope.pull_speed_cap])
	await _free(ch)
	ch = await _make(0)
	ch.events.freedom_seconds = 1.0
	ch.events.start_event("freedom")
	await _frames(5)
	await _place(ch, _cpos(58, 15), _cpos(75, 15), 40)
	var apart_before := ch.rope.current_length()
	died.clear()
	ch.players_died.connect(func(c: String) -> void: died.append(c))
	await _frames(300)
	_expect(died.is_empty() and absf(ch.rope.current_length() - apart_before) < 20.0 and ch.rope.max_length >= ch.rope.rest_length, "FREEDOM end across the pit: the rope holds, nobody is pulled in (%.0f -> %.0f px, died %s)" % [apart_before, ch.rope.current_length(), str(died)])
	await _free(ch)
	ch = await _make(0)
	var z_normal := ch.zoom_for_separation(240.0)
	ch.rope.rest_length = 64.0
	ch.rope.max_length = 96.0
	var z_short := ch.zoom_for_separation(240.0)
	ch.rope.rest_length = 350.0
	ch.rope.max_length = 320.0
	var z_inverted := ch.zoom_for_separation(240.0)
	_expect(is_equal_approx(z_normal, z_short) and is_equal_approx(z_normal, z_inverted) and z_normal < 1.0 and z_normal > Chained.MIN_ZOOM, "camera zoom depends on the real distance only, not on rest / max (%.3f / %.3f / %.3f at 240 px)" % [z_normal, z_short, z_inverted])
	ch.rope.rest_length = 160.0
	ch.rope.max_length = 320.0
	await _place(ch, _cpos(80, 15), _cpos(86, 15), 60)
	ch.events.short_leash_seconds = 30.0
	ch.events.start_event("short_leash")
	await _frames(60)
	var zs: Array[float] = []
	for i in 300:
		Input.action_release("p1_left")
		Input.action_release("p1_right")
		var phase := (i / 20) % 4
		if phase == 0:
			Input.action_press("p1_right")
		elif phase == 2:
			Input.action_press("p1_left")
		await _frames(1)
		zs.append(ch.camera.zoom.x)
	_release_all_keys()
	var travel := 0.0
	for i in range(1, zs.size()):
		travel += absf(zs[i] - zs[i - 1])
	_expect(travel < 0.1, "camera zoom does not pump during SHORT LEASH while a player wiggles (travel %.3f)" % travel)
	ch.events.stop_event()
	await _free(ch)
	ch = await _make(0)
	await _place(ch, _cpos(24, 15), _cpos(27, 12), 40)
	ch.rope.freeze_beads = false
	ch.rope.beads.clear()
	for i in 6:
		ch.rope.add_bead(0.5)
	await _frames(300)
	var t_max := 0.0
	for b in ch.rope.beads:
		t_max = maxf(t_max, b.t)
	_expect(ch.rope.bead_counts() == Vector2i(6, 0) and t_max > 0.5, "six stars on a short rope all go to the lower player P1 even though spacing draws the last one past the middle (counts %s, last drawn at t %.2f)" % [str(ch.rope.bead_counts()), t_max])
	await _place(ch, _cpos(27, 12), _cpos(24, 15), 40)
	await _frames(300)
	_expect(ch.rope.bead_counts() == Vector2i(0, 6), "... and when P2 is the lower one they all go to P2 (counts %s)" % str(ch.rope.bead_counts()))
	await _free(ch)
	for index in [0, 2]:
		ch = await _make(index)
		_expect(ch.respawn_points[0] == ch.spawn_points[0] and ch.respawn_points[1] == ch.spawn_points[1], "level %d: before any checkpoint the players respawn at their own start spots" % (index + 1))
		ch.rope.beads.clear()
		for i in 4:
			var bead := ch.rope.add_bead(0.5)
			bead.t = 0.1
		ch.kill_both("test", ch.balls[0])
		for i in 200:
			await _frames(1)
			if not ch._busy:
				break
		await _frames(12)
		var closest := 9999.0
		var left := 0
		for star in ch.dropped_stars:
			if is_instance_valid(star) and not star.is_queued_for_deletion() and not star.used:
				left += 1
			if is_instance_valid(star):
				for rp in ch.respawn_points:
					closest = minf(closest, absf(star.position.x - rp.x))
		_expect(ch.dropped_stars.size() >= 2 and left == ch.dropped_stars.size() and closest > 80.0, "level %d: %d stars dropped before the first checkpoint, all still there after the respawn (%d), nearest %.0f px from a player" % [index + 1, ch.dropped_stars.size(), left, closest])
		await _free(ch)


func _round2_misc_checks() -> void:
	var ch := await _make(0)
	ch.events.enabled = true
	ch.events.first_delay = 0.0
	ch.events._next_in = 0.0
	ch.events.roulette_seconds = 1.0
	ch.kill_both("pit", ch.balls[0])
	var overlap := 0
	var rolled := false
	for i in 400:
		await _frames(1)
		if ch.events.rolling_event != "" or ch.events.active_event != "":
			rolled = true
		if ch.hud.event_state == "roulette" and ch.hud.message_label.modulate.a > 0.02 and ch.hud.message_label.text.contains("\n"):
			overlap += 1
	_expect(rolled and overlap == 0, "the death message and the roulette never show together (roulette started %s, %d overlapping frames)" % [str(rolled), overlap])
	ch.events.stop_event()
	ch.events.enabled = false
	await _free(ch)
	ch = await _make(0)
	await _place(ch, _cpos(20, 15), _cpos(22, 15), 40)
	ch.respawn_delay = 1.0
	ch.kill_both("test")
	await _frames(3)
	var cam_a := ch.camera.global_position
	await _frames(40)
	var cam_b := ch.camera.global_position
	_expect(cam_a.distance_to(cam_b) < 1.0, "camera during the death wait does not drift toward the respawn spot (moved %.1f px)" % cam_a.distance_to(cam_b))
	for i in 120:
		await _frames(1)
		if not ch._busy:
			break
	await _frames(2)
	var want := (ch.balls[0].global_position + ch.balls[1].global_position) / 2.0 + Vector2(0.0, -40.0)
	_expect(ch.camera.global_position.distance_to(want) < 40.0, "after the respawn the camera is on the players (off by %.0f px)" % ch.camera.global_position.distance_to(want))
	await _free(ch)
	Game.chained_piggyback = 1
	ch = await _make(0)
	await _frames(40)
	ch.kill_both("pit", ch.balls[0])
	await _frames(3)
	var y_dead := ch.hud.message_label.position.y
	var ys: Array[float] = []
	for i in 120:
		await _frames(1)
		ys.append(ch.hud.message_label.position.y)
	var jumped := false
	for y in ys:
		jumped = jumped or not is_equal_approx(y, y_dead)
	_expect(is_equal_approx(y_dead, ChainedHud.MESSAGE_Y_PIGGYBACK) and not jumped, "death during the carry: the message already sits under the banner (y %.0f) and never jumps when the carry resumes" % y_dead)
	await _free(ch)
	Game.chained_piggyback = 0
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	Game.chained_piggyback = 2
	ch = await _make(2)
	_expect(ch.piggyback.start_penalty == 2, "setup: the last level starts with P2 riding")
	ch.scene_changes_enabled = true
	ch.hud.retry_pressed.emit()
	ch.queue_free()
	await _frames(5)
	var cur := get_tree().current_scene
	_expect(cur is Chained and cur != ch and cur.piggyback.start_penalty == 2, "Retry on the last level keeps the penalty the round started with (start_penalty %s)" % str(cur.piggyback.start_penalty if cur is Chained else -1))
	if cur is Chained:
		cur.queue_free()
		await _frames(150)
	Game.chained_piggyback = 0
	if is_instance_valid(dummy):
		dummy.queue_free()
	await _frames(3)
