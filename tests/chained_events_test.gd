extends Node

const GROUND_Y := 512.0
const PIT_FROM := 2048.0
const PIT_TO := 2272.0

var failures := 0


func _ready() -> void:
	Game.save_enabled = false
	_release_all_keys()
	await _api_checks()
	await _body_swap_checks()
	await _one_brain_checks()
	await _rope_event_checks()
	await _giant_tiny_checks()
	await _freedom_checks()
	await _earthquake_checks()
	await _respawn_checks()
	await _schedule_checks()
	await _lifecycle_checks()
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


func _until(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await _frames(1)
	return cond.call()


func _cpos(col: float, row: float) -> Vector2:
	return Vector2(col * 32.0, (row + 1.0) * 32.0 - 16.0)


func _new(ready := true, seconds := 3.0) -> Chained:
	Game.chained_index = 0
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	var ch: Chained = load("res://scenes/chained.tscn").instantiate()
	ch.intro_seconds = 0.2
	ch.respawn_delay = 0.3
	ch.restart_delay = 0.3
	ch.finish_panel_delay = 0.2
	ch.scene_changes_enabled = false
	add_child(ch)
	await _frames(2)
	_fast(ch.events, seconds)
	if ready:
		await _until(func() -> bool: return ch.match_running, 200)
		await _frames(45)
	return ch


func _fast(ev: ChainedEvents, seconds: float) -> void:
	ev.body_swap_seconds = seconds
	ev.one_brain_seconds = seconds
	ev.brain_switch_seconds = seconds / 2.0
	ev.short_leash_seconds = seconds
	ev.bungee_seconds = seconds
	ev.giant_tiny_seconds = seconds
	ev.freedom_seconds = seconds
	ev.earthquake_seconds = seconds
	ev.glide_seconds = 0.6


func _free(ch: Chained) -> void:
	_release_all_keys()
	await _frames(150)
	ch.queue_free()
	await _frames(2)


func _place(ch: Chained, c1: float, c2: float, frames := 45) -> void:
	ch.balls[0].teleport(_cpos(c1, 15.0))
	ch.balls[1].teleport(_cpos(c2, 15.0))
	await _frames(frames)


func _hop(prefix: String, dir: String, charge := 8) -> void:
	Input.action_press(prefix + dir)
	await _frames(charge)
	Input.action_press(prefix + "jump")
	await _frames(1)
	Input.action_release(prefix + "jump")
	Input.action_release(prefix + dir)


func _snap(ch: Chained) -> Dictionary:
	var d := {}
	for i in 2:
		var b := ch.balls[i]
		var shape := (b.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
		d["b%d.prefix" % i] = b.action_prefix
		d["b%d.size" % i] = b.size_factor
		d["b%d.mass" % i] = b.mass
		d["b%d.radius" % i] = b.radius
		d["b%d.shape" % i] = shape.radius
		d["b%d.reverse" % i] = b.reverse_controls
		d["b%d.tinted" % i] = (b.get_node("Sprite") as Node2D).material != null
		d["b%d.material" % i] = b.physics_material_override
		d["b%d.gravity" % i] = b.gravity_scale
		d["b%d.children" % i] = b.get_child_count()
		d["b%d.balls_mask" % i] = b.get_collision_mask_value(2)
	d["rope.rest"] = ch.rope.rest_length
	d["rope.max"] = ch.rope.max_length
	d["rope.stiffness"] = ch.rope.stiffness
	d["rope.damping"] = ch.rope.damping
	d["rope.hard"] = ch.rope.hard_stiffness
	d["rope.anchor_scale"] = ch.rope.anchor_force_scale
	d["rope.cut"] = ch.rope.cut
	d["rope.anchor_enabled"] = ch.rope.anchor_enabled
	d["camera.offset"] = ch.camera.offset
	return d


func _snap_diff(a: Dictionary, b: Dictionary) -> String:
	var out := ""
	for key in a:
		if a[key] != b[key]:
			out += "%s: %s -> %s; " % [key, str(a[key]), str(b[key])]
	return out


func _markers_on(ball: Ball) -> Array:
	var texts := []
	for c in ball.get_children():
		if c is ChainedEvents.KeyMarker:
			texts.append(c.text)
	return texts


func _in_terrain(ch: Chained, ball: Ball) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = maxf((ball.get_node("Shape") as CollisionShape2D).shape.radius - 2.0, 1.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, ball.global_position)
	query.collision_mask = 1
	return not ch.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _on_solid_ground(ch: Chained, pos: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(pos + Vector2(0.0, -6.0), pos + Vector2(0.0, 10.0), 1)
	return not ch.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _stars_on_ground(ev: ChainedEvents) -> int:
	var n := 0
	for s in ev.freedom_stars:
		if is_instance_valid(s) and not s.is_queued_for_deletion() and not s.used:
			n += 1
	return n


func _api_checks() -> void:
	var ch := await _new(false)
	var ev := ch.events
	var d := ChainedEvents.new()
	_expect(ch.events != null and ev.get_parent() == ch and ev.chained == ch, "chained.events is a ChainedEvents child of the Chained scene")
	_expect(ChainedEvents.EVENT_IDS.size() == 7 and ChainedEvents.EVENT_IDS.has("body_swap") and ChainedEvents.EVENT_IDS.has("one_brain") and ChainedEvents.EVENT_IDS.has("short_leash") and ChainedEvents.EVENT_IDS.has("bungee") and ChainedEvents.EVENT_IDS.has("giant_tiny") and ChainedEvents.EVENT_IDS.has("freedom") and ChainedEvents.EVENT_IDS.has("earthquake"), "EVENT_IDS lists the 7 events")
	var named := true
	for id in ChainedEvents.EVENT_IDS:
		named = named and ev.event_name(id) != "" and ChainedEvents.EVENT_COLORS.has(id) and ev.duration_of(id) > 0.0
	_expect(named, "every event has a name, a colour and a duration")
	_expect(d.interval == 20.0 and d.first_delay == 12.0 and d.roulette_seconds == 2.0, "defaults: an event every 20 s, the first after 12 s, roulette 2 s (%.0f / %.0f / %.0f)" % [d.interval, d.first_delay, d.roulette_seconds])
	_expect(d.duration_of("body_swap") == 10.0 and d.duration_of("one_brain") == 10.0 and d.brain_switch_seconds == 5.0 and d.duration_of("short_leash") == 10.0 and d.duration_of("bungee") == 10.0 and d.duration_of("giant_tiny") == 10.0 and d.duration_of("freedom") == 10.0 and d.duration_of("earthquake") == 8.0, "defaults: 10 s events (ONE BRAIN switches at 5 s), EARTHQUAKE 8 s")
	_expect(d.short_leash_rest == 2.0 and d.short_leash_max == 3.0 and d.bungee_rest == 6.0 and d.bungee_max == 18.0 and d.giant_scale == 1.6 and d.tiny_scale == 0.6, "defaults: short leash 2 / 3 tiles, bungee 6 / 18 tiles, giant 1.6, tiny 0.6")
	d.free()
	_expect(not ev.enabled, "test scenes (scene_changes_enabled = false) have the automatic roulette off by default")
	_expect(ev.active_event == "" and ev.rolling_event == "" and ev.last_event == "" and ev.stash_counts() == Vector2i.ZERO and not ev.reattach_pending, "no event is running at the start")
	ev.last_event = ""
	var seen := {}
	var repeats := 0
	var prev := ""
	for i in 400:
		var id := ev.pick_event()
		seen[id] = true
		if id == prev:
			repeats += 1
		prev = id
	_expect(repeats == 0 and seen.size() == 7, "pick_event: never the same event twice in a row over 400 picks, all 7 events come up (%d repeats, %d kinds)" % [repeats, seen.size()])
	_expect(ChainedHud.EVENT_ACTIVE_Y >= 46.0 + ChainedHud.HEART_SIZE + 4.0 and ChainedHud.EVENT_ACTIVE_Y + ChainedHud.EVENT_SIZE_ACTIVE.y <= ChainedHud.MESSAGE_Y_EVENT, "HUD: the active banner sits below the level title and the hearts, the shifted message sits below the banner")
	await _free(ch)


func _body_swap_checks() -> void:
	var ch := await _new()
	var ev := ch.events
	var a := ch.balls[0]
	var b := ch.balls[1]
	var base := _snap(ch)
	await _place(ch, 57.5, 60.5)
	var xa := a.global_position.x
	var xb := b.global_position.x
	await _hop("p1_", "left")
	await _frames(70)
	var move_a := a.global_position.x - xa
	var move_b := b.global_position.x - xb
	_expect(move_a < -30.0 and move_a < move_b - 20.0, "control: without the event P1's key moves P1's ball (P1 ball %+.0f px, P2 ball %+.0f px)" % [move_a, move_b])

	await _place(ch, 57.5, 60.5)
	var fired: Array[String] = []
	ev.event_started.connect(func(id: String) -> void: fired.append("start " + id))
	ev.event_ended.connect(func(id: String) -> void: fired.append("end " + id))
	ev.start_event("body_swap")
	_expect(ev.active_event == "body_swap" and a.action_prefix == "p2_" and b.action_prefix == "p1_" and fired == ["start body_swap"], "BODY SWAP: the balls swap key prefixes (%s / %s)" % [a.action_prefix, b.action_prefix])
	_expect(_markers_on(a) == ["P2"] and _markers_on(b) == ["P1"], "BODY SWAP: a marker over each ball shows whose keys drive it (P1 ball %s, P2 ball %s)" % [str(_markers_on(a)), str(_markers_on(b))])
	_expect(ch.hud.event_state == "active" and ch.hud.event_text == "BODY SWAP" and ch.hud.event_fraction > 0.95 and ch.hud.message_label.position.y == ChainedHud.MESSAGE_Y_EVENT, "BODY SWAP: the HUD shows the active banner and moves the message line below it")
	xa = a.global_position.x
	xb = b.global_position.x
	await _hop("p1_", "right")
	await _frames(70)
	move_a = a.global_position.x - xa
	move_b = b.global_position.x - xb
	_expect(move_b > 30.0 and move_b > move_a + 20.0, "BODY SWAP: pressing P1's keys moves P2's ball (P2 ball %+.0f px, P1 ball %+.0f px)" % [move_b, move_a])
	await _place(ch, 57.5, 60.5)
	xa = a.global_position.x
	xb = b.global_position.x
	await _hop("p2_", "left")
	await _frames(70)
	move_a = a.global_position.x - xa
	move_b = b.global_position.x - xb
	_expect(move_a < -30.0 and move_a < move_b - 20.0, "BODY SWAP: pressing P2's keys moves P1's ball (P1 ball %+.0f px, P2 ball %+.0f px)" % [move_a, move_b])

	ev.stop_event()
	await _frames(3)
	_expect(ev.active_event == "" and fired == ["start body_swap", "end body_swap"] and ch.hud.event_state == "" and ch.hud.message_label.position.y == ChainedHud.MESSAGE_Y, "BODY SWAP: stop_event ends it, fires event_ended and hides the banner")
	var diff := _snap_diff(base, _snap(ch))
	_expect(diff == "" and _markers_on(a).is_empty() and _markers_on(b).is_empty(), "BODY SWAP: prefixes, sizes, mass, tint, rope and markers are exactly back to the original (%s)" % diff)
	await _place(ch, 57.5, 60.5)
	xa = a.global_position.x
	await _hop("p1_", "left")
	await _frames(70)
	_expect(a.global_position.x - xa < -30.0, "BODY SWAP: afterwards P1's key moves P1's ball again")

	ev.body_swap_seconds = 1.0
	ev.start_event("body_swap")
	var frames_run := 0
	while ev.active_event != "" and frames_run < 200:
		await _frames(1)
		frames_run += 1
	_expect(frames_run >= 58 and frames_run <= 64 and a.action_prefix == "p1_" and b.action_prefix == "p2_" and fired.back() == "end body_swap", "BODY SWAP: it ends by itself after its duration (%d frames for 1.0 s) and restores the keys" % frames_run)
	await _free(ch)


func _one_brain_checks() -> void:
	var ch := await _new(true, 10.0)
	var ev := ch.events
	ev.brain_switch_seconds = 5.0
	var a := ch.balls[0]
	var b := ch.balls[1]
	var base := _snap(ch)
	await _place(ch, 57.5, 60.5)
	ev.start_event("one_brain")
	var first := ev.brain
	var other := 3 - first
	var fp := "p%d_" % first
	var op := "p%d_" % other
	_expect((first == 1 or first == 2) and a.action_prefix == fp and b.action_prefix == fp, "ONE BRAIN: both balls get the same prefix, P%d's (%s / %s)" % [first, a.action_prefix, b.action_prefix])
	_expect(_markers_on(a) == ["P%d" % first] and _markers_on(b) == ["P%d" % first], "ONE BRAIN: both balls carry the brain's marker (%s / %s)" % [str(_markers_on(a)), str(_markers_on(b))])
	_expect(ch.hud.event_text == "ONE BRAIN: P%d" % first and ch.hud.event_state == "active", "ONE BRAIN: the banner says whose brain it is ('%s')" % ch.hud.event_text)
	var xa := a.global_position.x
	var xb := b.global_position.x
	await _hop(fp, "right")
	await _frames(70)
	var move_a := a.global_position.x - xa
	var move_b := b.global_position.x - xb
	_expect(move_a > 25.0 and move_b > 25.0, "ONE BRAIN: both balls react to the brain's key (%+.0f / %+.0f px)" % [move_a, move_b])
	await _place(ch, 57.5, 60.5)
	xa = a.global_position.x
	xb = b.global_position.x
	await _hop(op, "right")
	await _frames(70)
	move_a = a.global_position.x - xa
	move_b = b.global_position.x - xb
	_expect(absf(move_a) < 10.0 and absf(move_b) < 10.0, "ONE BRAIN: the other player's keys do nothing (%+.0f / %+.0f px)" % [move_a, move_b])
	var started := 600 - int(ev.time_left * 60.0)
	var frames_to_switch := started
	while ev.brain == first and frames_to_switch < 700:
		await _frames(1)
		frames_to_switch += 1
	_expect(ev.brain == other and frames_to_switch >= 296 and frames_to_switch <= 306, "ONE BRAIN: the brain switches to the other player after 5 s (%d frames)" % frames_to_switch)
	_expect(a.action_prefix == op and b.action_prefix == op and _markers_on(a) == ["P%d" % other] and ch.hud.event_text == "ONE BRAIN: P%d" % other, "ONE BRAIN: after the switch both balls use P%d's keys, markers and banner follow ('%s')" % [other, ch.hud.event_text])
	await _place(ch, 57.5, 60.5)
	xa = a.global_position.x
	xb = b.global_position.x
	await _hop(op, "right")
	await _frames(70)
	move_a = a.global_position.x - xa
	move_b = b.global_position.x - xb
	_expect(move_a > 25.0 and move_b > 25.0, "ONE BRAIN: both balls obey the new brain (%+.0f / %+.0f px)" % [move_a, move_b])
	var ran := 0
	while ev.active_event != "" and ran < 400:
		await _frames(1)
		ran += 1
	var diff := _snap_diff(base, _snap(ch))
	_expect(ev.active_event == "" and ev.brain == 0 and diff == "", "ONE BRAIN: ends by itself after 10 s and everything is exactly back (%s)" % diff)
	await _free(ch)


func _rope_event_checks() -> void:
	var ch := await _new(true, 2.0)
	var ev := ch.events
	var rope := ch.rope
	var a := ch.balls[0]
	var b := ch.balls[1]
	var base := _snap(ch)
	_expect(rope.rest_length == 160.0 and rope.max_length == 320.0 and rope.stiffness == 16.0 and rope.damping == 3.0, "rope defaults are the ones the events must restore (rest 160, max 320, stiffness 16, damping 3)")

	a.teleport(_cpos(17.5, 15.0))
	b.teleport(_cpos(30.5, 15.0))
	await _frames(3)
	var normal_tension := rope.tension()
	var normal_start := rope.current_length()
	await _frames(40)
	var normal_apart := rope.current_length()
	_expect(normal_start > 400.0 and normal_tension > 20000.0 and normal_apart < 345.0, "normal rope: 13 tiles apart is far beyond the limit, the rope pulls hard and the players end up within 10 tiles (%.0f px, tension %.0f -> %.0f px apart)" % [normal_start, normal_tension, normal_apart])

	await _place(ch, 55.5, 62.5)
	ev.short_leash_seconds = 3.5
	ev.start_event("short_leash")
	var prev_max := rope.max_length
	var prev_rest := rope.rest_length
	var worst_step := 0.0
	var monotonic := true
	var worst_move := 0.0
	var pa := a.global_position
	var pb := b.global_position
	for f in 100:
		await _frames(1)
		worst_step = maxf(worst_step, prev_max - rope.max_length)
		monotonic = monotonic and rope.max_length <= prev_max and rope.rest_length <= prev_rest
		prev_max = rope.max_length
		prev_rest = rope.rest_length
		worst_move = maxf(worst_move, maxf(a.global_position.distance_to(pa), b.global_position.distance_to(pb)))
		pa = a.global_position
		pb = b.global_position
	_expect(rope.rest_length == 64.0 and rope.max_length == 96.0, "SHORT LEASH: rest / max become 2 / 3 tiles (%.0f / %.0f px)" % [rope.rest_length, rope.max_length])
	_expect(monotonic and worst_step < 8.0 and worst_step > 3.0, "SHORT LEASH: the rope tightens smoothly, no snap (largest step %.1f px per frame)" % worst_step)
	_expect(worst_move < 25.0 and ch.lives == Chained.LIVES, "SHORT LEASH: the players are tugged together, nobody teleports or dies (largest move %.1f px per frame)" % worst_move)
	_expect(rope.current_length() < 110.0 and a.on_ground and b.on_ground, "SHORT LEASH: they end up about 3 tiles apart (%.0f px, from 224)" % rope.current_length())
	var hold_apart := 0.0
	for f in 60:
		b.knockback(Vector2(-30.0, 0.0))
		await _frames(1)
		hold_apart = maxf(hold_apart, rope.current_length())
	_expect(hold_apart < 96.0 + 40.0, "SHORT LEASH: the rope keeps them close (longest %.0f px, limit 96 + 40)" % hold_apart)
	var ran := 0
	while ev.active_event != "" and ran < 400:
		await _frames(1)
		ran += 1
	await _frames(8)
	_expect(ev.active_event == "" and rope.max_length > 96.0 and rope.max_length < 320.0, "SHORT LEASH: when it ends the rope glides back instead of snapping (max now %.0f)" % rope.max_length)
	await _frames(60)
	var diff := _snap_diff(base, _snap(ch))
	_expect(diff == "", "SHORT LEASH: after the glide the rope numbers are exactly the originals (%s)" % diff)

	await _place(ch, 55.5, 56.5)
	ev.start_event("bungee")
	await _frames(50)
	_expect(rope.rest_length == 192.0 and rope.max_length == 576.0 and rope.stiffness == 5.0 and rope.damping == 1.5, "BUNGEE: rest 6 tiles, max 18 tiles, soft and bouncy (%.0f / %.0f px, stiffness %.1f, damping %.1f)" % [rope.rest_length, rope.max_length, rope.stiffness, rope.damping])
	a.teleport(_cpos(17.5, 15.0))
	b.teleport(_cpos(30.5, 15.0))
	await _frames(3)
	var bungee_tension := rope.tension()
	await _frames(40)
	var bungee_apart := rope.current_length()
	_expect(bungee_tension < 2000.0 and bungee_tension < normal_tension / 10.0 and bungee_apart > 400.0 and bungee_apart > normal_apart + 60.0, "BUNGEE: the same 13 tiles apart is just a gentle stretch (tension %.0f vs %.0f, still %.0f px apart vs %.0f with the normal rope)" % [bungee_tension, normal_tension, bungee_apart, normal_apart])
	var prev := rope.max_length
	worst_step = 0.0
	ev.stop_event()
	_expect(rope.max_length == 320.0 and rope.rest_length == 160.0 and rope.stiffness == 16.0 and rope.damping == 3.0, "BUNGEE: stop_event restores the rope instantly and exactly")
	ev.bungee_seconds = 1.0
	await _place(ch, 55.5, 56.5)
	ev.start_event("bungee")
	await _frames(50)
	ran = 0
	prev = rope.max_length
	worst_step = 0.0
	var glided := false
	while ran < 300:
		await _frames(1)
		ran += 1
		if ev.active_event == "":
			worst_step = maxf(worst_step, prev - rope.max_length)
			glided = glided or (rope.max_length < 576.0 and rope.max_length > 320.0)
		prev = rope.max_length
		if ev.active_event == "" and rope.max_length == 320.0:
			break
	_expect(glided and worst_step < 8.0 and rope.max_length == 320.0 and ch.lives == Chained.LIVES, "BUNGEE: when it ends the rope glides back to normal (largest step %.1f px per frame), nobody dies" % worst_step)
	await _frames(30)
	diff = _snap_diff(base, _snap(ch))
	_expect(diff == "", "BUNGEE: after the glide the rope numbers are exactly the originals (%s)" % diff)
	await _free(ch)


func _giant_tiny_checks() -> void:
	var ch := await _new(true, 4.0)
	var ev := ch.events
	var a := ch.balls[0]
	var b := ch.balls[1]
	var base := _snap(ch)
	var mass_a := a.mass
	await _place(ch, 57.5, 60.5)
	ev.giant_override = 1
	ev.start_event("giant_tiny")
	await _frames(40)
	var shape_a := (a.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
	var shape_b := (b.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
	_expect(ev.giant_player == 1 and is_equal_approx(a.size_factor, 1.6) and is_equal_approx(b.size_factor, 0.6), "GIANT & TINY: P1 becomes big (x%.1f), P2 tiny (x%.1f)" % [a.size_factor, b.size_factor])
	_expect(is_equal_approx(shape_a.radius, 15.0 * 1.6) and is_equal_approx(shape_b.radius, 15.0 * 0.6) and absf(a.mass - mass_a * 2.56) < 0.001 and absf(b.mass - mass_a * 0.36) < 0.001, "GIANT & TINY: collision circles and masses follow the size (radius %.1f / %.1f, mass %.2f / %.2f)" % [shape_a.radius, shape_b.radius, a.mass, b.mass])
	_expect(not _in_terrain(ch, a) and not _in_terrain(ch, b), "GIANT & TINY: nobody is inside terrain after the change")
	await _frames(60)
	_expect(a.on_ground and b.on_ground and absf(a.global_position.y + shape_a.radius - GROUND_Y) < 4.0 and absf(b.global_position.y + shape_b.radius - GROUND_Y) < 4.0, "GIANT & TINY: both stand on the floor, nobody sinks or falls through (feet %.1f / %.1f)" % [a.global_position.y + shape_a.radius, b.global_position.y + shape_b.radius])
	_expect(ch.hud.event_text == "GIANT & TINY" and ch.rope.rest_length == 160.0, "GIANT & TINY: banner shown, rope untouched")
	ev.stop_event()
	await _frames(40)
	var diff := _snap_diff(base, _snap(ch))
	_expect(diff == "" and a.mass == mass_a and not _in_terrain(ch, a) and not _in_terrain(ch, b), "GIANT & TINY: sizes, circles and masses are exactly back, nobody ends up in terrain (%s)" % diff)
	await _frames(40)
	_expect(a.on_ground and b.on_ground and absf(b.global_position.y + 15.0 - GROUND_Y) < 4.0, "GIANT & TINY: the tiny one grows back and stands on the floor, not in it (feet %.1f)" % (b.global_position.y + 15.0))

	ev.giant_override = 2
	ev.start_event("giant_tiny")
	await _frames(40)
	_expect(ev.giant_player == 2 and is_equal_approx(b.size_factor, 1.6) and is_equal_approx(a.size_factor, 0.6), "GIANT & TINY: P2 can be the big one too")
	ev.stop_event()
	await _frames(40)

	ev.giant_override = 0
	var big := {}
	var ok := true
	for i in 16:
		ev.start_event("giant_tiny")
		await _frames(3)
		big[ev.giant_player] = true
		ok = ok and ((is_equal_approx(a.size_factor, 1.6) and is_equal_approx(b.size_factor, 0.6)) or (is_equal_approx(b.size_factor, 1.6) and is_equal_approx(a.size_factor, 0.6)))
		ev.stop_event()
		await _frames(3)
	_expect(ok and big.size() == 2, "GIANT & TINY: the big player is picked at random (both players came up in 16 tries), always exactly one big and one tiny")
	await _frames(30)
	diff = _snap_diff(base, _snap(ch))
	_expect(diff == "", "GIANT & TINY: 16 start / stop cycles leave everything exactly as before (%s)" % diff)

	await _place(ch, 57.5, 60.5)
	Input.action_press("p1_use")
	await _frames(10)
	_expect(ch.rope.is_anchored(a), "setup: P1 is anchored")
	ev.giant_override = 1
	ev.start_event("giant_tiny")
	await _frames(20)
	ev.stop_event()
	await _frames(20)
	Input.action_release("p1_use")
	await _frames(20)
	_expect(a.mass == mass_a and a.size_factor == 1.0 and not ch.rope.is_anchored(a), "GIANT & TINY: resizing an anchored ball and restoring it leaves the mass exactly original (%.3f)" % a.mass)

	var slab := StaticBody2D.new()
	slab.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(600.0, 100.0)
	shape.shape = rect
	slab.add_child(shape)
	slab.position = Vector2(1888.0, GROUND_Y - 34.0 - 50.0)
	ch.level.add_child(slab)
	await _place(ch, 57.5, 60.5)
	_expect(not _in_terrain(ch, a) and not _in_terrain(ch, b), "setup: both players stand under a low ceiling")
	ev.giant_override = 1
	ev.start_event("giant_tiny")
	await _frames(40)
	_expect(a.size_factor == 1.0 and is_equal_approx(b.size_factor, 0.6) and not _in_terrain(ch, a) and not _in_terrain(ch, b), "GIANT & TINY: the big one is skipped when there is no room under the ceiling (P1 x%.1f, P2 x%.1f), nobody is stuck in terrain" % [a.size_factor, b.size_factor])
	ev.stop_event()
	await _frames(40)
	_expect(not _in_terrain(ch, a) and not _in_terrain(ch, b) and a.size_factor == 1.0 and b.size_factor == 1.0, "GIANT & TINY: the tiny one grows back under the ceiling without getting stuck")
	slab.queue_free()
	await _free(ch)


func _freedom_checks() -> void:
	var ch := await _new(true, 6.0)
	var ev := ch.events
	var rope := ch.rope
	var a := ch.balls[0]
	var b := ch.balls[1]
	var base := _snap(ch)
	var died: Array[String] = []
	ch.players_died.connect(func(cause: String) -> void: died.append(cause))
	_expect(ch.counts() == Vector2i.ZERO, "setup: no stars yet")

	for t in [0.2, 0.35, 0.5, 0.65, 0.8]:
		rope.add_bead(t)
	_expect(rope.beads.size() == 5, "setup: five beads on the rope")
	a.teleport(_cpos(55.5, 15.0))
	b.teleport(_cpos(74.5, 15.0))
	ev.start_event("freedom")
	await _frames(45)
	_expect(rope.cut and rope.beads.is_empty() and ev.freedom_stars.size() == 5, "FREEDOM: the rope is cut and every bead falls off (%d beads left, %d stars dropped)" % [rope.beads.size(), ev.freedom_stars.size()])
	var all_ground := true
	var none_in_pit := true
	var min_gap := 9999.0
	var xs: Array[float] = []
	for s in ev.freedom_stars:
		all_ground = all_ground and is_instance_valid(s) and _on_solid_ground(ch, s.global_position)
		none_in_pit = none_in_pit and not (s.global_position.x > PIT_FROM - 8.0 and s.global_position.x < PIT_TO + 8.0)
		xs.append(s.global_position.x)
	for i in xs.size():
		for j in range(i + 1, xs.size()):
			min_gap = minf(min_gap, absf(xs[i] - xs[j]))
	_expect(all_ground and none_in_pit, "FREEDOM: the stars land on solid ground, none over the pit (x = %s)" % str(xs))
	_expect(min_gap >= 18.0 and _stars_on_ground(ev) == 5, "FREEDOM: stars do not overlap (closest %.0f px) and all 5 can still be collected" % min_gap)
	await _frames(30)
	_expect(rope.tension() == 0.0 and absf(a.global_position.x - 1776.0) < 12.0 and absf(b.global_position.x - 2384.0) < 12.0, "FREEDOM: the cut rope has no force (tension %.0f, players %.0f / %.0f px)" % [rope.tension(), a.global_position.x, b.global_position.x])
	_expect(ch.hud.event_text == "FREEDOM" and died.is_empty(), "FREEDOM: banner shown, nobody died")

	var right_most: Pickup = ev.freedom_stars[0]
	for s in ev.freedom_stars:
		if s.global_position.x > right_most.global_position.x:
			right_most = s
	b.teleport(right_most.global_position + Vector2(0.0, -16.0))
	await _frames(40)
	var got :=5 - _stars_on_ground(ev)
	_expect(got >= 1 and (not is_instance_valid(right_most) or right_most.is_queued_for_deletion()), "FREEDOM: P2 can pick up a fallen star (%d picked)" % got)
	_expect(rope.beads.is_empty() and ev.stash_counts() == Vector2i(0, got) and ch.counts() == Vector2i(0, got), "FREEDOM: the stars P2 picked are stored for P2, not put on the rope (stash %s, counts %s, %d picked, %d beads on the rope)" % [str(ev.stash_counts()), str(ch.counts()), got, rope.beads.size()])
	ch.level.collect_star(a)
	ch.level.collect_star(a)
	await _frames(2)
	_expect(ev.stash_counts() == Vector2i(2, got) and ch.hud.counts == Vector2i(2, got) and rope.beads.is_empty(), "FREEDOM: P1's stars go to P1's end (stash %s), the HUD counts them (%s)" % [str(ev.stash_counts()), str(ch.hud.counts)])
	b.teleport(_cpos(56.5, 15.0))
	await _frames(3)
	ev.stop_event()
	await _frames(3)
	var tmin := 1.0
	var tmax := 0.0
	for bead in rope.beads:
		tmin = minf(tmin, bead.t)
		tmax = maxf(tmax, bead.t)
	_expect(not rope.cut and rope.beads.size() == 2 + got and rope.bead_counts() == Vector2i(2, got) and tmin < 0.06 and tmax > 0.94 and ev.stash_counts() == Vector2i.ZERO, "FREEDOM: when the rope returns the stored stars are on the picker's side: 2 for P1 (first at t %.2f), %d for P2 (last at t %.2f), counts %s" % [tmin, got, tmax, str(rope.bead_counts())])
	_expect(_stars_on_ground(ev) == 5 - got and died.is_empty(), "FREEDOM: stars nobody picked stay on the ground (%d), nobody died" % _stars_on_ground(ev))
	for s in ev.freedom_stars:
		if is_instance_valid(s) and not s.is_queued_for_deletion() and not s.used:
			a.teleport(s.global_position + Vector2(0.0, -16.0))
			await _frames(8)
	_expect(rope.beads.size() == 7 and _stars_on_ground(ev) == 0, "FREEDOM: stars left on the ground still count when picked up after the event (%d beads: 5 fallen + 2 extra)" % rope.beads.size())
	await _place(ch, 57.5, 60.5)
	var diff := _snap_diff(base, _snap(ch))
	_expect(diff == "", "FREEDOM: rope numbers, sizes and prefixes are exactly back (%s)" % diff)

	await _free(ch)
	ch = await _new(true, 6.0)
	ev = ch.events
	rope = ch.rope
	a = ch.balls[0]
	b = ch.balls[1]
	died.clear()
	ch.players_died.connect(func(cause: String) -> void: died.append(cause))
	ev.glide_seconds = 1.0
	ev.freedom_seconds = 1.0
	base = _snap(ch)
	ev.start_event("freedom")
	a.teleport(_cpos(2.5, 15.0))
	b.teleport(_cpos(17.5, 15.0))
	await _frames(20)
	var apart := rope.current_length()
	_expect(rope.cut and apart > 440.0 and rope.tension() == 0.0, "FREEDOM: players can be farther apart than the rope length while it lasts (%.0f px apart, rope max %.0f)" % [apart, rope.max_length])
	var prev_len := apart
	var worst_close := 0.0
	var reattach_frames := 0
	var pulled_in := false
	for f in 400:
		await _frames(1)
		if ev.active_event == "":
			var len := rope.current_length()
			worst_close = maxf(worst_close, prev_len - len)
			prev_len = len
			if not rope.cut:
				reattach_frames += 1
			if not rope.cut and len < 330.0:
				pulled_in = true
				break
	_expect(pulled_in and not rope.cut, "FREEDOM: the rope reattaches and the players end up within the normal rope length (%.0f px apart)" % rope.current_length())
	_expect(reattach_frames >= 15 and worst_close < 25.0, "FREEDOM: the far-apart players are pulled together smoothly over about a second (%d frames, fastest %.1f px per frame), not snapped" % [reattach_frames, worst_close])
	_expect(died.is_empty() and ch.lives == Chained.LIVES, "FREEDOM: reattaching never kills anyone")
	await _frames(90)
	diff = _snap_diff(base, _snap(ch))
	_expect(diff == "" and ev.active_event == "" and not ev.reattach_pending, "FREEDOM: after the glide the rope numbers are exactly the originals (%s)" % diff)

	ev.freedom_seconds = 0.2
	a.teleport(_cpos(62.5, 15.0))
	b.teleport(Vector2(PIT_FROM + 112.0, 200.0))
	await _frames(3)
	ev.start_event("freedom")
	await _until(func() -> bool: return ev.active_event == "", 60)
	await _frames(10)
	_expect(ev.reattach_pending and rope.cut and ev._over_pit(b), "FREEDOM: with a player airborne over the pit at the end the rope stays cut and waits (pending %s)" % str(ev.reattach_pending))
	await _until(func() -> bool: return not ev.reattach_pending, 400)
	_expect(not ev.reattach_pending and not rope.cut, "FREEDOM: ... and it reattaches once the wait is over (the player fell, the death restored the rope)")
	await _until(func() -> bool: return not a.dead and not b.dead and ch.match_running, 300)
	await _frames(60)
	ev.freedom_seconds = 0.2
	a.teleport(_cpos(10.5, 15.0))
	b.teleport(Vector2(13.5 * 32.0, 400.0))
	await _frames(3)
	ev.start_event("freedom")
	await _until(func() -> bool: return ev.active_event == "", 60)
	await _frames(3)
	_expect(not ev.reattach_pending and not rope.cut, "FREEDOM: a player airborne over solid ground does not delay the reattach")
	ev.stop_event()
	await _free(ch)


func _earthquake_checks() -> void:
	var ch := await _new(true, 3.0)
	var ev := ch.events
	var rope := ch.rope
	var base := _snap(ch)
	await _place(ch, 57.5, 60.5)
	for t in [0.12, 0.25, 0.38, 0.62, 0.75, 0.88]:
		rope.add_bead(t)
	var start_t: Array[float] = []
	for bead in rope.beads:
		start_t.append(bead.t)
	start_t.sort()
	ev.start_event("earthquake")
	var in_bounds := true
	var max_shake := 0.0
	var seen_counts := {}
	var moved := 0.0
	var prev: Array[float] = start_t.duplicate()
	for f in 170:
		await _frames(1)
		var cur: Array[float] = []
		for bead in rope.beads:
			in_bounds = in_bounds and bead.t >= 0.03 - 0.0001 and bead.t <= 0.97 + 0.0001
			cur.append(bead.t)
		cur.sort()
		for i in cur.size():
			moved += absf(cur[i] - prev[i])
		prev = cur
		max_shake = maxf(max_shake, ch.camera.offset.length())
		seen_counts[ch.rope.bead_counts()] = true
	_expect(in_bounds and rope.beads.size() == 6, "EARTHQUAKE: every bead stays within 0.03 .. 0.97 and none is lost (%d beads)" % rope.beads.size())
	_expect(moved > 1.5 and seen_counts.size() >= 3, "EARTHQUAKE: the beads wander along the rope, stars move between the two halves (%.1f total movement, %d different splits seen)" % [moved, seen_counts.size()])
	_expect(max_shake > 1.0 and max_shake <= ev.quake_shake * 1.5, "EARTHQUAKE: the camera shakes (up to %.1f px)" % max_shake)
	_expect(ch.hud.event_text == "EARTHQUAKE", "EARTHQUAKE: banner shown")
	await _until(func() -> bool: return ev.active_event == "", 120)
	await _frames(3)
	var diff := _snap_diff(base, _snap(ch))
	_expect(ev.active_event == "" and ch.camera.offset == Vector2.ZERO and rope.beads.size() == 6 and diff == "", "EARTHQUAKE: ends by itself, the camera is exactly still again and no star was lost (%s)" % diff)
	var c := rope.bead_counts()
	_expect(c.x + c.y <= 6 and c.x + c.y >= 5, "EARTHQUAKE: the stars are still counted for the players afterwards (%s)" % str(c))
	await _free(ch)


func _effect_on(ch: Chained, id: String) -> bool:
	var ev := ch.events
	var a := ch.balls[0]
	var b := ch.balls[1]
	var rope := ch.rope
	match id:
		"body_swap":
			return a.action_prefix == "p2_" and b.action_prefix == "p1_" and _markers_on(a) == ["P2"] and _markers_on(b) == ["P1"]
		"one_brain":
			return (ev.brain == 1 or ev.brain == 2) and a.action_prefix == "p%d_" % ev.brain and b.action_prefix == a.action_prefix and _markers_on(a).size() == 1
		"short_leash":
			return rope.rest_length == 64.0 and rope.max_length == 96.0
		"bungee":
			return rope.rest_length == 192.0 and rope.max_length == 576.0 and rope.stiffness == 5.0 and rope.damping == 1.5
		"giant_tiny":
			return is_equal_approx(a.size_factor, 1.6) and is_equal_approx(b.size_factor, 0.6) and not _in_terrain(ch, a) and not _in_terrain(ch, b)
		"freedom":
			return rope.cut and rope.beads.is_empty()
		"earthquake":
			return ch.camera.offset != Vector2.ZERO
	return false


func _respawn_checks() -> void:
	var ch := await _new(true, 8.0)
	var ev := ch.events
	var rope := ch.rope
	var a := ch.balls[0]
	var b := ch.balls[1]
	ch.lives = 99
	var died: Array[String] = []
	ch.players_died.connect(func(cause: String) -> void: died.append(cause))
	ev.giant_override = 1
	for id in ChainedEvents.EVENT_IDS:
		await _place(ch, 57.5, 60.5)
		rope.beads.clear()
		for t in [0.3, 0.4, 0.6, 0.7]:
			rope.add_bead(t)
		var base := _snap(ch)
		var lives0 := ch.lives
		ev.start_event(id)
		await _frames(80)
		_expect(ev.active_event == id and _effect_on(ch, id), "%s: effect is on before the death" % id)
		ch.kill_both("test")
		await _frames(2)
		var diff := _snap_diff(base, _snap(ch))
		var beads_now := rope.beads.size() + (_stars_on_ground(ev) if id == "freedom" else 0)
		_expect(ev.active_event == id and diff == "" and beads_now == 4, "%s: on death everything is undone at once, the event keeps its clock (%s, %d stars in total)" % [id, diff, beads_now])
		await _until(func() -> bool: return not a.dead and not b.dead and ch.match_running, 300)
		await _frames(80)
		_expect(ch.lives == lives0 - 1 and ev.active_event == id, "%s: the respawn costs exactly one life and the event is still active (lives %d)" % [id, ch.lives])
		_expect(_effect_on(ch, id), "%s: after the respawn the still-active event is applied again (sizes %.2f / %.2f, keys %s / %s, rope %.0f / %.0f, cut %s)" % [id, a.size_factor, b.size_factor, a.action_prefix, b.action_prefix, rope.rest_length, rope.max_length, str(rope.cut)])
		if id == "giant_tiny":
			await _frames(30)
			_expect(a.on_ground and b.on_ground and not _in_terrain(ch, a) and not _in_terrain(ch, b), "%s: after the respawn nobody is stuck in terrain or floating" % id)
		ev.stop_event()
		await _frames(40)
		diff = _snap_diff(base, _snap(ch))
		beads_now = rope.beads.size() + (_stars_on_ground(ev) if id == "freedom" else 0)
		_expect(diff == "" and beads_now == 4 and ch.camera.offset == Vector2.ZERO, "%s: after stop_event everything is exactly back, bead count conserved (%s)" % [id, diff])
	_expect(died.size() == ChainedEvents.EVENT_IDS.size() and ch.lives == 99 - died.size(), "respawn checks: exactly one death per event (%d), no extra deaths from the events" % died.size())

	ev.giant_tiny_seconds = 0.8
	ev.start_event("giant_tiny")
	await _frames(10)
	ch.kill_both("test")
	await _until(func() -> bool: return not a.dead and not b.dead and ch.match_running, 300)
	await _frames(30)
	_expect(ev.active_event == "" and a.size_factor == 1.0 and b.size_factor == 1.0 and ch.hud.event_state == "", "an event that runs out while the players are dead is not re-applied after the respawn")
	await _free(ch)


func _schedule_checks() -> void:
	var ch := await _new(false, 1.0)
	var ev := ch.events
	ev.enabled = true
	ev.first_delay = 1.0
	ev.interval = 3.0
	ev.roulette_seconds = 0.5
	_expect(ev.active_event == "" and ev.rolling_event == "", "schedule: nothing yet while the intro is running")
	await _until(func() -> bool: return ch.match_running, 200)
	var starts: Array = []
	var ends: Array = []
	var clock: Array[int] = [0]
	ev.event_started.connect(func(id: String) -> void: starts.append([id, clock[0]]))
	ev.event_ended.connect(func(id: String) -> void: ends.append([id, clock[0]]))
	var saw_roll := false
	var saw_active := false
	var active_text_ok := true
	var stale_banner := false
	for f in 860:
		await _frames(1)
		clock[0] += 1
		if ev.rolling_event != "" and ch.hud.event_state == "roulette":
			saw_roll = true
		if ev.active_event != "" and ch.hud.event_state == "active":
			saw_active = true
			active_text_ok = active_text_ok and ch.hud.event_text.begins_with(ev.event_name(ev.active_event))
		if ev.active_event == "" and ev.rolling_event == "" and ch.hud.event_state != "":
			stale_banner = true
	_expect(starts.size() >= 4 and absi(starts.size() - ends.size()) <= 1, "schedule: events fire by themselves (%d started in 14 s, %d ended)" % [starts.size(), ends.size()])
	var first_at: float = starts[0][1] / 60.0
	_expect(absf(first_at - 1.5) < 0.2, "schedule: the first event starts first_delay + roulette after the level starts (%.2f s, expected 1.5)" % first_at)
	var gaps_ok := true
	var no_repeat := true
	for i in range(1, starts.size()):
		gaps_ok = gaps_ok and absf((starts[i][1] - starts[i - 1][1]) / 60.0 - 3.0) < 0.2
		no_repeat = no_repeat and starts[i][0] != starts[i - 1][0]
	_expect(gaps_ok and no_repeat, "schedule: one event every `interval` seconds, never the same twice in a row (%s)" % str(starts.map(func(s: Array) -> String: return s[0])))
	_expect(saw_roll and saw_active and active_text_ok and not stale_banner, "schedule: the HUD shows the roulette banner and then the active banner, and no banner is left behind between events")
	ev.enabled = false
	await _until(func() -> bool: return ev.active_event == "" and ev.rolling_event == "", 200)
	await _frames(5)
	_expect(ch.hud.event_state == "" and ch.lives == Chained.LIVES, "schedule: with enabled = false the running event finishes, then the HUD banner is gone")
	var before := starts.size()
	await _frames(300)
	_expect(starts.size() == before, "schedule: enabled = false means no new event is drawn")
	await _free(ch)


func _lifecycle_checks() -> void:
	var ch := await _new(false)
	var ev := ch.events
	ev.enabled = true
	ev.first_delay = 0.0
	ev._next_in = 0.0
	ev.roulette_seconds = 0.0
	ev.start_event("bungee")
	await _frames(6)
	_expect(not ch.match_running and ev.active_event == "" and ev.rolling_event == "" and ch.rope.max_length == 320.0, "intro: no event starts during READY... (start_event is ignored, no roulette)")
	await _until(func() -> bool: return ch.match_running, 200)
	ev.enabled = false
	ev.stop_event()
	await _free(ch)

	for id in ["body_swap", "one_brain", "short_leash", "bungee", "giant_tiny", "earthquake"]:
		ch = await _new(true, 20.0)
		ev = ch.events
		var base := _snap(ch)
		await _place(ch, 57.5, 60.5)
		ev.giant_override = 2
		ev.start_event(id)
		await _frames(60)
		ch.level.finish()
		await _frames(3)
		var diff := _snap_diff(base, _snap(ch))
		_expect(ch.finished and ev.active_event == "" and diff == "" and ch.hud.event_state == "", "finish during %s: the event is cleaned up at once, everything is exactly back (%s)" % [id, diff])
		ev.enabled = true
		ev._next_in = 0.0
		ev.start_event("bungee")
		await _frames(150)
		_expect(ev.active_event == "" and ev.rolling_event == "" and ch.rope.max_length == 320.0, "after the finish (%s) no event starts, not even with enabled = true and start_event" % id)
		await _free(ch)

	ch = await _new(true, 20.0)
	ev = ch.events
	var results: Array[Vector2i] = []
	ch.level_finished.connect(func(c: Vector2i) -> void: results.append(c))
	await _place(ch, 57.5, 60.5)
	ev.start_event("freedom")
	await _frames(40)
	ch.level.collect_star(ch.balls[0])
	ch.level.collect_star(ch.balls[0])
	ch.level.collect_star(ch.balls[1])
	await _frames(2)
	ch.level.finish()
	await _frames(3)
	_expect(results.size() == 1 and results[0] == Vector2i(2, 1) and not ch.rope.cut and ev.active_event == "" and ev.stash_counts() == Vector2i.ZERO, "finish during FREEDOM: the stored stars are counted for the players who picked them (result %s)" % str(results))
	await _free(ch)

	for id in ["giant_tiny", "freedom", "one_brain", "earthquake", "bungee"]:
		ch = await _new(true, 60.0)
		ev = ch.events
		await _place(ch, 57.5, 60.5)
		ch.rope.add_bead(0.4)
		ev.giant_override = 1
		ev.start_event(id)
		await _frames(40)
		var started: bool = ev.active_event == id
		await _free(ch)
		_expect(started and not is_instance_valid(ch), "scene freed during %s: no errors, nothing left behind" % id)
	_release_all_keys()
