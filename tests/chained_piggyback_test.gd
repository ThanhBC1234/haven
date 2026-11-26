extends Node

var failures := 0
var _ids := 0


func _ready() -> void:
	Game.save_enabled = false
	for c in get_children():
		c.queue_free()
	_release_all_keys()
	await _frames(2)
	await _panel_checks()
	await _round_start_checks()
	await _scene_flow_checks()
	await _follow_checks()
	await _jump_checks()
	await _ceiling_checks()
	await _end_checks()
	await _hop_side_checks()
	await _death_checks()
	await _api_checks()
	_release_all_keys()
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
	return Vector2(col * 32.0, (row + 1.0) * 32.0 - 16.0)


func _set_beads(rope: Rope, values: Array) -> void:
	rope.beads.clear()
	for v in values:
		var bd := Rope.Bead.new()
		bd.t = v
		rope.beads.append(bd)


func _make_chained(index := 0, ready := true) -> Chained:
	Game.chained_index = index
	var ch: Chained = load("res://scenes/chained.tscn").instantiate()
	ch.intro_seconds = 0.2
	ch.respawn_delay = 0.3
	ch.restart_delay = 0.3
	ch.finish_panel_delay = 0.2
	ch.scene_changes_enabled = false
	add_child(ch)
	await _frames(2)
	if ready:
		for i in 200:
			if ch.match_running:
				break
			await _frames(1)
		await _frames(45)
	return ch


func _free_chained(ch: Chained) -> void:
	_release_all_keys()
	await _frames(150)
	ch.queue_free()
	await _frames(2)


func _sit_height(rider: Ball) -> float:
	return ChainedPiggyback.HEAD_REACH + rider.radius - ChainedPiggyback.SIT_OVERLAP


func _solid_at(ch: Chained, p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = ChainedPiggyback.WORLD_MASK
	return not ch.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _watch(ch: Chained, rider: Ball, carrier: Ball, n: int) -> Dictionary:
	var out := {"dx": 0.0, "dy_min": 1e9, "dy_max": -1e9, "inside": 0}
	var rest := -_sit_height(rider)
	for i in n:
		await get_tree().process_frame
		var gap := rider.global_position - carrier.global_position
		out["dx"] = maxf(out["dx"], absf(gap.x))
		out["dy_min"] = minf(out["dy_min"], gap.y - rest)
		out["dy_max"] = maxf(out["dy_max"], gap.y - rest)
		if _solid_at(ch, rider.global_position):
			out["inside"] += 1
	return out


func _add_block(ch: Chained, pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos + size / 2.0
	body.add_child(shape)
	ch.level.add_child(body)
	return body


func _add_ramp(ch: Chained, foot: Vector2, run: float, rise: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([foot, foot + Vector2(run, -rise), foot + Vector2(run, 4.0), foot + Vector2(0.0, 4.0)])
	shape.shape = poly
	body.add_child(shape)
	ch.level.add_child(body)
	return body


func _finish_with(ch: Chained, want: Vector2i) -> void:
	ch.rope.freeze_beads = true
	var values: Array[float] = []
	for i in want.x:
		values.append(0.1 + 0.05 * i)
	for i in want.y:
		values.append(0.9 - 0.05 * i)
	_set_beads(ch.rope, values)
	ch.level.finish()


func _count_signals(ch: Chained) -> Dictionary:
	var counts := {"started": 0, "ended": 0}
	ch.piggyback.piggyback_started.connect(func() -> void: counts["started"] += 1)
	ch.piggyback.piggyback_ended.connect(func() -> void: counts["ended"] += 1)
	return counts


func _panel_checks() -> void:
	for scenario in [[Vector2i(3, 1), 1, "P2 MUST CARRY P1 NEXT ROUND!"], [Vector2i(1, 2), 2, "P1 MUST CARRY P2 NEXT ROUND!"], [Vector2i(2, 2), 0, ""]]:
		Game.chained_piggyback = 0
		var want: Vector2i = scenario[0]
		var ch := await _make_chained()
		_finish_with(ch, want)
		await _frames(3)
		_expect(ch.finished and ch.hud.result_panel == null and Game.chained_piggyback == 0, "panel %s: nothing is decided before the result panel shows" % str(want))
		await _frames(30)
		_expect(ch.hud.result_panel != null and Game.chained_piggyback == scenario[1], "panel %s: Game.chained_piggyback = %d (is %d)" % [str(want), scenario[1], Game.chained_piggyback])
		if scenario[1] == 0:
			_expect(ch.hud.result_piggyback == null and ch.hud.result_title.text == "IT'S A TIE!", "panel %s: a tie announces no piggyback" % str(want))
		else:
			_expect(ch.hud.result_piggyback != null and ch.hud.result_piggyback.text == scenario[2], "panel %s: the panel announces '%s' (%s)" % [str(want), scenario[2], ch.hud.result_piggyback.text if ch.hud.result_piggyback else "-"])
		await _free_chained(ch)
		_expect(Game.chained_piggyback == 0, "panel %s: closing the scene any other way than Retry / Next does not leak the penalty into later games" % str(want))
	Game.chained_piggyback = 0


func _round_start_checks() -> void:
	for who in [1, 2]:
		Game.chained_piggyback = who
		var ch := await _make_chained(0, false)
		var counts := _count_signals(ch)
		var rider := ch.balls[who - 1]
		var carrier := ch.balls[2 - who]
		_expect(Game.chained_piggyback == 0, "round start (P%d rides): the penalty is consumed when the level is built" % who)
		_expect(not ch.piggyback.piggyback_active and not ch.match_running and rider.dead and carrier.dead, "round start (P%d rides): nothing happens during the intro" % who)
		for i in 200:
			if ch.match_running:
				break
			await _frames(1)
		await _frames(2)
		_expect(ch.piggyback.piggyback_active and counts["started"] == 1 and counts["ended"] == 0, "round start (P%d rides): the piggyback starts right after the intro (started %d)" % [who, counts["started"]])
		_expect(ch.piggyback.piggyback_rider == rider and ch.piggyback.piggyback_carrier == carrier, "round start (P%d rides): P%d sits on P%d" % [who, who, 3 - who])
		_expect(rider.carried and carrier.jump_locked and not rider.jump_locked and not carrier.carried, "round start (P%d rides): the rider is carried and the carrier's jump key is locked" % who)
		_expect(ch.piggyback.seconds_left > 9.8 and ch.piggyback.seconds_left <= 10.0, "round start (P%d rides): 10 seconds on the clock (%.2f)" % [who, ch.piggyback.seconds_left])
		_expect(ch.hud.message_label.text != "GO!" and ch.hud.message_label.modulate.a < 0.01, "round start (P%d rides): no GO! flash and no fading READY... under the piggyback banner ('%s', alpha %.2f)" % [who, ch.hud.message_label.text, ch.hud.message_label.modulate.a])
		await _frames(60)
		_expect(ch.piggyback.piggyback_active and ch.piggyback.seconds_left < 9.1 and ch.piggyback.seconds_left > 8.8, "round start (P%d rides): the clock runs (%.2f after 1 s)" % [who, ch.piggyback.seconds_left])
		_expect(ch.hud.message_label.text != "GO!" and not "STARS" in ch.hud.message_label.text and ch.hud.message_label.modulate.a < 0.01, "round start (P%d rides): neither GO! nor the level-1 goal line appears while the banner is up ('%s', alpha %.2f)" % [who, ch.hud.message_label.text, ch.hud.message_label.modulate.a])
		await _free_chained(ch)
		_expect(counts["ended"] == 1, "round start (P%d rides): leaving the scene mid-piggyback ends it cleanly" % who)
	Game.chained_piggyback = 0
	var ch2 := await _make_chained()
	_expect(not ch2.piggyback.piggyback_active and not ch2.balls[0].carried and not ch2.balls[1].carried and not ch2.balls[0].jump_locked and not ch2.balls[1].jump_locked, "round start: no penalty, no piggyback")
	_expect(ch2.hud.message_label.text == "GO!", "round start: without a penalty the usual GO! flash still shows ('%s')" % ch2.hud.message_label.text)
	await _free_chained(ch2)


func _use_dummy_scene() -> Node:
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	return dummy


func _scene_flow_checks() -> void:
	Game.chained_piggyback = 0
	_use_dummy_scene()
	var ch := await _make_chained()
	_finish_with(ch, Vector2i(2, 1))
	await _frames(30)
	_expect(Game.chained_piggyback == 1 and ch.hud.retry_button != null, "retry: after the result panel P1 rides next round")
	ch.hud.retry_pressed.emit()
	ch.queue_free()
	await _frames(4)
	var cur := get_tree().current_scene
	_expect(cur is Chained and cur != ch, "retry: the level is rebuilt as a new scene")
	if cur is Chained:
		var nxt: Chained = cur
		_expect(Game.chained_piggyback == 0 and Game.chained_index == 0, "retry: the penalty was handed to the new round (consumed), level index unchanged")
		_expect(not nxt.piggyback.piggyback_active, "retry: it does not start during the intro")
		for i in 400:
			if nxt.match_running:
				break
			await _frames(1)
		await _frames(3)
		_expect(nxt.piggyback.piggyback_active and nxt.piggyback.piggyback_rider == nxt.balls[0], "retry: the piggyback starts after the intro, P1 on P2's head")
		nxt.queue_free()
		await _frames(200)
	Game.chained_piggyback = 2
	_use_dummy_scene()
	Game.go_to_menu()
	await _frames(4)
	_expect(Game.chained_piggyback == 0, "menu: going to the menu clears the penalty")
	var menu := get_tree().current_scene
	_expect(menu != null and menu.scene_file_path == Game.MENU_SCENE, "menu: the menu scene is now current")
	if menu != null:
		menu.queue_free()
	await _frames(3)
	Game.chained_piggyback = 2
	_use_dummy_scene()
	Game.start_chained()
	await _frames(4)
	_expect(Game.chained_piggyback == 0, "start_chained(0): starting from the menu clears the penalty")
	cur = get_tree().current_scene
	if cur is Chained:
		var fresh: Chained = cur
		for i in 400:
			if fresh.match_running:
				break
			await _frames(1)
		await _frames(30)
		_expect(not fresh.piggyback.piggyback_active and not fresh.balls[0].carried and not fresh.balls[1].carried, "start_chained(0): no piggyback in the new game")
		fresh.queue_free()
		await _frames(200)
	else:
		_expect(false, "start_chained(0): the Chained scene is current")
	get_tree().current_scene = self
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	Game.chained_index = 0


func _follow_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	var rest := _sit_height(a)
	var rest_flags := {"layer": a.collision_layer, "mask": a.collision_mask}
	ch.piggyback.start_piggyback(a, b, 60.0)
	_expect(a.carried and a.collision_layer == 0 and a.collision_mask == 0, "follow: the rider stops colliding with anything while carried")
	await _frames(40)
	var gap := a.global_position - b.global_position
	_expect(absf(gap.x) < 3.0 and absf(gap.y + rest) < 3.0, "follow: after mounting the rider sits on the carrier's head (gap %s, want (0, %.0f))" % [str(gap.round()), -rest])
	var w := await _watch(ch, a, b, 60)
	_expect(w["dx"] < 2.0 and w["dy_min"] > -2.0 and w["dy_max"] < 2.0, "follow: standing still the rider does not drift (dx %.2f, dy %.2f..%.2f)" % [w["dx"], w["dy_min"], w["dy_max"]])
	_expect(ch.rope.tension() == 0.0 and not ch.rope.is_anchored(a) and not ch.rope.is_anchored(b), "follow: the rope is slack and nobody is anchored")
	_expect(a.charge_dir == 0 and not a.is_use_held(), "follow: the rider has no controls of their own")
	Input.action_press("p1_right")
	Input.action_press("p1_use")
	await _frames(30)
	_expect(a.charge_dir == 0 and a.charge == 0.0 and not ch.rope.is_anchored(a) and not a.is_use_held(), "follow: the rider's tilt and anchor keys do nothing")
	Input.action_release("p1_right")
	Input.action_release("p1_use")
	var x_before := b.global_position.x
	b.knockback(Vector2(800.0, 0.0))
	w = await _watch(ch, a, b, 90)
	_expect(w["dx"] < 2.0 and w["dy_min"] > -2.0 and w["dy_max"] < 2.0 and w["inside"] == 0, "follow: while the carrier slides on flat ground the rider stays on top (dx %.2f, dy %.2f..%.2f)" % [w["dx"], w["dy_min"], w["dy_max"]])
	_expect(b.global_position.x > x_before + 60.0, "follow: ...and the carrier really moved (x %.0f -> %.0f)" % [x_before, b.global_position.x])
	var ramp := _add_ramp(ch, Vector2(300.0, 512.0), 240.0, 120.0)
	b.teleport(_cpos(4.0, 15))
	await _frames(40)
	var start_x := b.global_position.x
	var worst := {"dx": 0.0, "dy_min": 1e9, "dy_max": -1e9, "inside": 0}
	var top_y := 1e9
	for hop in 3:
		Input.action_press("p2_right")
		await _frames(14)
		Input.action_press("p1_jump")
		await _frames(1)
		Input.action_release("p1_jump")
		Input.action_release("p2_right")
		for i in 8:
			var step := await _watch(ch, a, b, 12)
			worst["dx"] = maxf(worst["dx"], step["dx"])
			worst["dy_min"] = minf(worst["dy_min"], step["dy_min"])
			worst["dy_max"] = maxf(worst["dy_max"], step["dy_max"])
			worst["inside"] += step["inside"]
			top_y = minf(top_y, b.global_position.y)
	_expect(b.global_position.x > 330.0 and b.global_position.x < 540.0 and b.global_position.y < 470.0 and top_y < 440.0, "follow: the carrier hopped across the flat and up the slope (x %.0f -> %.0f, y %.0f, highest y %.0f)" % [start_x, b.global_position.x, b.global_position.y, top_y])
	_expect(worst["dx"] < 2.0 and worst["dy_min"] > -2.0 and worst["dy_max"] < 2.0 and worst["inside"] == 0, "follow: through hops and the slope the rider stays on top (worst dx %.1f, dy %.1f..%.1f, inside terrain %d)" % [worst["dx"], worst["dy_min"], worst["dy_max"], worst["inside"]])
	await _frames(120)
	w = await _watch(ch, a, b, 30)
	_expect(w["dx"] < 3.0 and absf(w["dy_min"]) < 3.0 and absf(w["dy_max"]) < 3.0, "follow: at rest again the rider is exactly on the head (dx %.2f, dy %.2f..%.2f)" % [w["dx"], w["dy_min"], w["dy_max"]])
	_expect(ch.lives == Chained.LIVES and b.on_ground, "follow: nobody died and the carrier is standing")
	ramp.queue_free()
	b.teleport(_cpos(10.0, 15))
	await _frames(60)
	_expect(absf(b.global_position.y - 496.0) < 2.0, "follow: the rider's weight does not sink the carrier into the ground (y %.1f, ground contact at 496)" % b.global_position.y)
	ch.piggyback.stop_piggyback()
	await _frames(120)
	_expect(a.collision_layer == rest_flags["layer"] and a.collision_mask == rest_flags["mask"], "follow: layers restored after the piggyback")
	await _free_chained(ch)


func _jump_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	ch.piggyback.start_piggyback(a, b, 60.0)
	await _frames(45)
	var launched := {"a": 0, "b": 0}
	a.launched.connect(func() -> void: launched["a"] += 1)
	b.launched.connect(func() -> void: launched["b"] += 1)
	var y0 := b.global_position.y
	Input.action_press("p2_jump")
	await _frames(3)
	Input.action_release("p2_jump")
	await _frames(40)
	_expect(launched["b"] == 0 and launched["a"] == 0 and absf(b.global_position.y - y0) < 1.5, "jump: the carrier's own jump key does nothing (launches %d, y change %.1f)" % [launched["b"], b.global_position.y - y0])
	Input.action_press("p2_right")
	await _frames(25)
	_expect(b.charge_dir == 1 and b.charge > 0.3 and b.charge < 0.9, "jump: the carrier still tilts and charges with left/right (charge %.2f)" % b.charge)
	Input.action_press("p2_jump")
	await _frames(3)
	Input.action_release("p2_jump")
	await _frames(5)
	_expect(launched["b"] == 0 and b.charge_dir == 1 and b.on_ground, "jump: ...and pressing their own jump key while charged still does nothing")
	await _frames(30)
	_expect(b.charge >= 0.999, "jump: the carrier's charge is full (%.2f)" % b.charge)
	Input.action_press("p1_jump")
	await _frames(1)
	Input.action_release("p1_jump")
	var inside := 0
	var worst_dx := 0.0
	var worst_dy := 0.0
	var seen_vel := Vector2.ZERO
	for i in 4:
		await _frames(1)
		if launched["b"] == 1 and seen_vel == Vector2.ZERO:
			seen_vel = b.linear_velocity
	Input.action_release("p2_right")
	var want := b.jump_velocity(1, 1.0)
	_expect(launched["b"] == 1 and launched["a"] == 0, "jump: the rider's jump key makes the carrier jump (carrier launches %d, rider launches %d)" % [launched["b"], launched["a"]])
	_expect(seen_vel.x > want.x - 60.0 and seen_vel.x < want.x + 60.0 and seen_vel.y > want.y - 60.0 and seen_vel.y < want.y + 60.0, "jump: ...with the carrier's full charge (velocity %s, expected about %s)" % [str(seen_vel.round()), str(want.round())])
	var w := await _watch(ch, a, b, 10)
	var air := 0
	for i in 150:
		await get_tree().process_frame
		var gap := a.global_position - b.global_position
		worst_dx = maxf(worst_dx, absf(gap.x))
		worst_dy = maxf(worst_dy, absf(gap.y + _sit_height(a)))
		if _solid_at(ch, a.global_position):
			inside += 1
		if not b.on_ground:
			air += 1
	_expect(air > 30 and worst_dx < 2.0 and worst_dy < 2.0 and inside == 0, "jump: during the jump the rider stays on top (airborne %d frames, worst dx %.1f, dy %.1f, inside terrain %d)" % [air, worst_dx, worst_dy, inside])
	_expect(w["inside"] == 0 and b.on_ground and a.charge_dir == 0, "jump: the carrier lands and the rider is still not controlling anything")
	await _frames(40)
	var launches_before: int = launched["b"]
	Input.action_press("p1_jump")
	await _frames(1)
	Input.action_release("p1_jump")
	var straight := Vector2.ZERO
	for i in 4:
		await _frames(1)
		if launched["b"] == launches_before + 1 and straight == Vector2.ZERO:
			straight = b.linear_velocity
	var want_straight := b.jump_velocity(0, b.straight_jump)
	_expect(launched["b"] == launches_before + 1 and absf(straight.x) < 30.0 and absf(straight.y - want_straight.y) < 60.0, "jump: without charge the rider's key gives a straight jump (velocity %s, expected about %s)" % [str(straight.round()), str(want_straight.round())])
	_expect(launched["a"] == 0, "jump: the rider never launches by themselves")
	await _frames(100)
	await _free_chained(ch)


func _ceiling_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	ch.piggyback.start_piggyback(a, b, 60.0)
	await _frames(45)
	var rest := _sit_height(a)
	var block_a := _add_block(ch, Vector2(220.0, 300.0), Vector2(120.0, 126.0))
	b.teleport(Vector2(280.0, 496.0))
	await _frames(90)
	var head_top := a.global_position.y - ChainedPiggyback.HEAD_REACH * a.size_factor
	_expect(head_top >= 426.0 - 1.0 and a.global_position.y < 496.0 - 5.0, "ceiling: under a low ceiling the rider ducks so the head does not enter it (head top y %.1f, ceiling at 426)" % head_top)
	_expect(not _solid_at(ch, a.global_position) and absf(b.global_position.y - 496.0) < 2.0 and b.linear_velocity.length() < 10.0, "ceiling: the rider is outside the terrain and the carrier is not pushed (carrier y %.1f, speed %.1f)" % [b.global_position.y, b.linear_velocity.length()])
	var block_b := _add_block(ch, Vector2(380.0, 300.0), Vector2(120.0, 160.0))
	b.teleport(Vector2(440.0, 496.0))
	await _frames(90)
	_expect(not _solid_at(ch, a.global_position) and a.global_position.y >= 460.0 and a.global_position.y <= b.global_position.y + 2.0 and absf(b.global_position.y - 496.0) < 2.0, "ceiling: under a very low ceiling the rider sinks into the carrier, still never inside the terrain (rider y %.1f)" % a.global_position.y)
	var inside := 0
	b.teleport(Vector2(240.0, 496.0))
	await _frames(60)
	Input.action_press("p2_right")
	await _frames(20)
	Input.action_press("p1_jump")
	await _frames(1)
	Input.action_release("p1_jump")
	Input.action_release("p2_right")
	for i in 120:
		await get_tree().process_frame
		var p := a.global_position
		var under_a := p.x > 220.0 and p.x < 340.0 and p.y < 426.0
		var under_b := p.x > 380.0 and p.x < 500.0 and p.y < 460.0
		if _solid_at(ch, p) or under_a or under_b:
			inside += 1
	_expect(inside == 0 and absf(a.global_position.y - b.global_position.y) < 62.0, "ceiling: jumping under the low ceiling never puts the rider in the terrain or above its underside (bad frames %d)" % inside)
	b.teleport(Vector2(140.0, 496.0))
	await _frames(90)
	var gap := a.global_position - b.global_position
	_expect(absf(gap.x) < 3.0 and absf(gap.y + rest) < 3.0, "ceiling: out from under the ceiling the rider sits on the head again (gap %s)" % str(gap.round()))
	block_a.queue_free()
	block_b.queue_free()
	await _free_chained(ch)


func _end_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	var counts := _count_signals(ch)
	var before := {
		"a_prefix": a.action_prefix, "b_prefix": b.action_prefix,
		"a_layer": a.collision_layer, "b_layer": b.collision_layer, "a_mask": a.collision_mask, "b_mask": b.collision_mask,
		"freeze": ch.rope.freeze_beads, "cut": ch.rope.cut, "anchor": ch.rope.anchor_enabled,
		"a_mass": a.mass, "b_mass": b.mass, "a_mat": a.physics_material_override, "b_mat": b.physics_material_override,
		"a_scale": a.gravity_scale, "b_scale": b.gravity_scale, "rest": ch.rope.rest_length, "max": ch.rope.max_length,
	}
	ch.piggyback.start_piggyback(a, b)
	_expect(is_equal_approx(ch.piggyback.seconds_left, 10.0) and ch.piggyback.duration == 10.0, "end: the default length is 10 seconds")
	await _frames(590)
	_expect(ch.piggyback.piggyback_active and ch.piggyback.seconds_left > 0.1 and counts["ended"] == 0, "end: still riding at 9.8 s (left %.2f)" % ch.piggyback.seconds_left)
	_expect(is_instance_valid(ch.piggyback._banner), "end: the countdown banner is showing")
	await _frames(15)
	_expect(not ch.piggyback.piggyback_active and counts["started"] == 1 and counts["ended"] == 1, "end: the piggyback ends after 10 s (ended %d)" % counts["ended"])
	_expect(not a.carried and not b.jump_locked and ch.piggyback.piggyback_rider == null and ch.piggyback.piggyback_carrier == null, "end: flags are back to normal")
	await _frames(150)
	var gap := a.global_position - b.global_position
	_expect(absf(gap.x) > 20.0 and absf(gap.x) < 260.0 and absf(gap.y) < 12.0 and a.on_ground and b.on_ground, "end: the rider hopped off beside the carrier and stands on the ground (gap %s)" % str(gap.round()))
	_expect(not _solid_at(ch, a.global_position) and ch.lives == Chained.LIVES and not a.dead and not b.dead, "end: nobody is in the terrain and nobody died")
	_expect(a.action_prefix == before["a_prefix"] and b.action_prefix == before["b_prefix"] and a.player_id == 1 and b.player_id == 2, "end: key prefixes are exactly as before")
	_expect(a.collision_layer == before["a_layer"] and b.collision_layer == before["b_layer"] and a.collision_mask == before["a_mask"] and b.collision_mask == before["b_mask"], "end: collision layers and masks are exactly as before (%d/%d, %d/%d)" % [a.collision_layer, a.collision_mask, b.collision_layer, b.collision_mask])
	_expect(ch.rope.freeze_beads == before["freeze"] and ch.rope.cut == before["cut"] and ch.rope.anchor_enabled == before["anchor"] and ch.rope.rest_length == before["rest"] and ch.rope.max_length == before["max"], "end: rope settings are exactly as before")
	_expect(a.mass == before["a_mass"] and b.mass == before["b_mass"] and a.physics_material_override == before["a_mat"] and b.physics_material_override == before["b_mat"] and a.gravity_scale == before["a_scale"] and b.gravity_scale == before["b_scale"], "end: mass, material and gravity are unchanged")
	var launched := {"a": 0, "b": 0}
	a.launched.connect(func() -> void: launched["a"] += 1)
	b.launched.connect(func() -> void: launched["b"] += 1)
	Input.action_press("p2_jump")
	await _frames(2)
	Input.action_release("p2_jump")
	await _frames(100)
	_expect(launched["b"] == 1 and launched["a"] == 0, "end: the carrier's own jump key works again and only moves them (b %d, a %d)" % [launched["b"], launched["a"]])
	Input.action_press("p1_jump")
	await _frames(2)
	Input.action_release("p1_jump")
	await _frames(100)
	_expect(launched["a"] == 1 and launched["b"] == 1, "end: the rider's own jump key jumps the rider and not the other (a %d, b %d)" % [launched["a"], launched["b"]])
	Input.action_press("p1_right")
	await _frames(20)
	_expect(a.charge_dir == 1 and a.charge > 0.2, "end: the rider tilts and charges with their own keys again")
	Input.action_release("p1_right")
	Input.action_press("p1_use")
	await _frames(10)
	_expect(ch.rope.is_anchored(a), "end: the rider can anchor again")
	Input.action_release("p1_use")
	await _free_chained(ch)


func _hop_side_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	var edge_ok := ch.level.char_at(16, 36) == "#" and ch.level.char_at(16, 37) == "." and ch.level.char_at(15, 36) == "."
	_expect(edge_ok, "hop side: the valley edge is where the test expects it (column 36 is the last ground tile)")
	b.teleport(_cpos(35.5, 15))
	a.teleport(_cpos(33.0, 15))
	await _frames(30)
	ch.piggyback.start_piggyback(a, b, 1.0)
	b.facing = 1
	await _frames(40)
	_expect(ch.piggyback.piggyback_active, "hop side: riding at the pit edge")
	await _frames(60)
	_expect(not ch.piggyback.piggyback_active, "hop side: the 1 s piggyback is over")
	await _frames(150)
	_expect(a.global_position.x < b.global_position.x - 10.0 and a.on_ground and a.global_position.y < 520.0 and ch.lives == Chained.LIVES, "hop side: at the pit edge the rider hops to the safe side (rider x %.0f, carrier x %.0f, lives %d)" % [a.global_position.x, b.global_position.x, ch.lives])
	await _free_chained(ch)

	ch = await _make_chained()
	a = ch.balls[0]
	b = ch.balls[1]
	var spike_col: int = ch.level.rows[15].find("^")
	_expect(spike_col > 60, "hop side: found the first spike at column %d" % spike_col)
	var spot := float(spike_col) - 3.0
	b.teleport(_cpos(spot + 0.5, 15))
	a.teleport(_cpos(spot - 1.5, 15))
	await _frames(40)
	ch.piggyback.start_piggyback(a, b, 1.0)
	b.facing = 1
	await _frames(100)
	var rider_x := a.global_position.x
	await _frames(120)
	_expect(not ch.piggyback.piggyback_active and a.global_position.x < b.global_position.x - 10.0 and ch.lives == Chained.LIVES, "hop side: next to spikes on the right the rider hops left (rider x %.0f, carrier x %.0f, lives %d)" % [a.global_position.x, b.global_position.x, ch.lives])
	_expect(rider_x > 0.0 and a.on_ground, "hop side: the rider ends standing on the ground")
	await _free_chained(ch)
	Game.chained_piggyback = 0


func _death_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	var counts := _count_signals(ch)
	var layer0 := a.collision_layer
	var mask0 := a.collision_mask
	ch.piggyback.start_piggyback(a, b, 10.0)
	await _frames(50)
	_expect(ch.piggyback.piggyback_active, "death: riding")
	var lives := ch.lives
	ch.kill_both("hurt", b)
	_expect(not ch.piggyback.piggyback_active and counts["ended"] == 1, "death: the piggyback ends the instant someone dies")
	_expect(not a.carried and not b.jump_locked and a.collision_layer == layer0 and a.collision_mask == mask0, "death: flags and the rider's collision are restored at once")
	await _frames(3)
	_expect(ch.lives == lives - 1 and a.dead and b.dead, "death: the shared life is lost as usual")
	for i in 120:
		await _frames(1)
		if not a.dead:
			break
	var resumed_left := ch.piggyback.seconds_left
	_expect(not a.dead and not b.dead and ch.piggyback.piggyback_active and ch.piggyback.piggyback_rider == a and resumed_left > 8.0 and resumed_left < 9.9, "death: both respawn and the carry resumes with the time that was left (%.2f of 10 s)" % resumed_left)
	ch.piggyback._end(false)
	await _frames(5)
	_expect(not a.dead and not b.dead and not a.carried and not b.jump_locked and not ch.piggyback.piggyback_active, "death: both respawn normally")
	_expect(a.global_position.distance_to(ch.respawn_points[0]) < 30.0 and b.global_position.distance_to(ch.respawn_points[1]) < 30.0, "death: both are at their respawn spots, the rider was not flung anywhere (%s, %s)" % [str(a.global_position.round()), str(b.global_position.round())])
	await _frames(60)
	_expect(a.global_position.distance_to(ch.respawn_points[0]) < 40.0 and a.on_ground and a.collision_layer == layer0 and a.collision_mask == mask0, "death: after landing the rider is still at its spot with its normal collision")
	ch.piggyback.start_piggyback(b, a, 10.0)
	await _frames(40)
	ch.kill_both("pit", b)
	_expect(not ch.piggyback.piggyback_active and not b.carried and not a.jump_locked, "death: also ends when the culprit is the rider")
	await _free_chained(ch)

	ch = await _make_chained()
	a = ch.balls[0]
	b = ch.balls[1]
	counts = _count_signals(ch)
	ch.piggyback.start_piggyback(a, b, 10.0)
	await _frames(50)
	_set_beads(ch.rope, [0.2, 0.8])
	ch.level.finish()
	await _frames(3)
	_expect(ch.finished and not ch.piggyback.piggyback_active and counts["ended"] == 1 and not a.carried and not b.jump_locked, "finish: reaching the flag ends the piggyback")
	_expect(ch.rope.freeze_beads, "finish: the stars stay frozen after the finish (the piggyback does not unfreeze them)")
	await _frames(100)
	_expect(a.global_position.y >= b.global_position.y - 25.0 and a.global_position.distance_to(b.global_position) > 25.0, "finish: the rider is not left floating above the carrier (gap %s)" % str((a.global_position - b.global_position).round()))
	await _free_chained(ch)


func _api_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	var counts := _count_signals(ch)
	_expect(ch.piggyback is ChainedPiggyback and not ch.piggyback.piggyback_active and ch.piggyback.piggyback_rider == null, "api: Chained.piggyback exists and is idle")
	ch.piggyback.stop_piggyback()
	_expect(counts["ended"] == 0, "api: stop_piggyback when idle does nothing")
	ch.piggyback.start_piggyback(a, a)
	ch.piggyback.start_piggyback(null, b)
	_expect(not ch.piggyback.piggyback_active and counts["started"] == 0, "api: start_piggyback ignores a missing / identical ball")
	b.dead = true
	ch.piggyback.start_piggyback(a, b)
	_expect(not ch.piggyback.piggyback_active and not a.carried, "api: start_piggyback ignores a dead ball")
	b.dead = false
	_set_beads(ch.rope, [0.3, 0.5, 0.7])
	ch.rope.freeze_beads = false
	ch.piggyback.start_piggyback(a, b, 3.0)
	_expect(ch.piggyback.piggyback_active and counts["started"] == 1 and ch.piggyback.piggyback_rider == a and ch.piggyback.piggyback_carrier == b and ch.rope.freeze_beads, "api: start_piggyback(rider, carrier, 3.0) starts and the stars on the rope freeze")
	await _frames(70)
	_expect(is_equal_approx(ch.rope.beads[0].t, 0.3) and is_equal_approx(ch.rope.beads[2].t, 0.7), "api: the stars do not slide while riding (the rider is higher: they would all run to the carrier)")
	_expect(ch.piggyback._banner != null and ch.piggyback._banner.is_inside_tree() and ch.piggyback.seconds_left < 2.0, "api: the banner is up and the clock runs (%.2f s left)" % ch.piggyback.seconds_left)
	ch.piggyback.start_piggyback(b, a, 4.0)
	_expect(ch.piggyback.piggyback_active and counts["started"] == 2 and counts["ended"] == 1 and ch.piggyback.piggyback_rider == b and not a.carried and b.carried and a.jump_locked and not b.jump_locked, "api: starting again swaps roles cleanly (started %d, ended %d)" % [counts["started"], counts["ended"]])
	await _frames(50)
	ch.piggyback.stop_piggyback()
	_expect(not ch.piggyback.piggyback_active and counts["ended"] == 2 and not b.carried and not a.jump_locked and not ch.rope.freeze_beads, "api: stop_piggyback ends it at once and restores the rope")
	await _frames(2)
	_expect(ch.piggyback._banner == null, "api: the banner is gone after the piggyback")
	await _frames(150)
	_expect(not _solid_at(ch, b.global_position) and b.on_ground and a.on_ground, "api: both stand on the ground after the manual stop")
	await _free_chained(ch)
