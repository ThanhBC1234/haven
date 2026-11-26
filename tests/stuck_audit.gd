extends Node

const TILE := 32.0
const ESCAPE_DIST := 192.0
const FALL_MARGIN := 80.0
const SETTLE_FRAMES := 150
const SETTLE_EXTRA := 150
const REST_SPEED := 60.0
const ROUND1_FRAMES := 480
const ROUND2_FRAMES := 720
const RANDOM_STRATEGIES := 12
const MIN_AIR_FRAMES := 5
const GROUND_PAUSE := 6
const PAD_COLS := 12
const FIT_SLACK := 0.5
const BALL_SCENE := preload("res://scenes/ball.tscn")
const HOLDS := [2, 12, 24, 42]

class Run extends RefCounted:
	var rest: int = 0
	var label: String = ""
	var ball: Ball = null
	var slot: int = 0
	var steps: Array = []
	var rng: RandomNumberGenerator = null
	var step_i: int = 0
	var state: int = 0
	var timer: int = 0
	var keep: bool = false
	var dir: int = 0
	var hold: int = 0
	var hurt: bool = false
	var jumps: int = 0
	var frames: int = 0
	var ground_frames: int = 0
	var best_dist: float = 0.0
	var best_rise: float = 0.0
	var best_ground_dist: float = 0.0

const SELFTEST_MAPS := [
	{"name": "deep shaft", "map": "#...#\n#...#\n#...#\n#...#\n#...#\n#...#\n#...#\n#...#\n#.O.#\n#####"},
	{"name": "tunnel 1 row", "map": "#................#\n#................#\n#................#\n#...############.#\n#..O.............#\n##################"},
	{"name": "sealed room", "map": "#####\n#...#\n#.O.#\n#####"},
	{"name": "tunnel 2 rows", "map": "#................#\n#................#\n#................#\n#...############.#\n#................#\n#..O.............#\n##################"},
]

const BRAWL_VARIANTS := [
	1.0, 1.25,
	{"f": 1.0, "grav": 0.4, "label": "LOW GRAVITY"},
	{"f": 1.0, "bounce": 0.98, "label": "SUPER BOUNCE"},
	{"f": 1.0, "fric": 0.02, "label": "ICE FLOOR"},
	{"f": 1.25, "grav": 0.4, "label": "leader + LOW GRAVITY"},
]

var _variant :={"f": 1.0}
var _survey := false
var _selftest := false
var _slot_total := 0
var _slots_free: Array[int] = []
var _only := ""
var _verbose := false
var _stuck_total := 0
var _fixed_strategies: Array = []
var _run_started_usec := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.trim_prefix("--only=").to_lower()
		if a == "--selftest":
			_selftest = true
		if a == "--survey":
			_survey = true
		if a == "--verbose":
			_verbose = true
	Game.save_enabled = false
	_run_started_usec = Time.get_ticks_usec()
	_make_strategies()
	for m in _all_maps():
		if _only != "" and not String(m["name"]).to_lower().contains(_only):
			continue
		for v in m["sizes"]:
			await _audit_map(m, v if v is Dictionary else {"f": v})
	var secs := (Time.get_ticks_usec() - _run_started_usec) / 1000000.0
	print("STUCK_AUDIT: %d stuck spots (%.0f s)" % [_stuck_total, secs])
	get_tree().quit(1 if _stuck_total > 0 else 0)


func _all_maps() -> Array:
	var out: Array = []
	if _selftest:
		return SELFTEST_MAPS.map(func(s: Dictionary) -> Dictionary: return {"name": "selftest/" + String(s["name"]), "map": s["map"], "sizes": [1.0], "pad": false, "ceiling": false})
	for a in BrawlData.ARENAS:
		out.append({"name": "brawl/" + String(a["name"]), "map": a["map"], "sizes": BRAWL_VARIANTS, "pad": false, "ceiling": true})
	for l in LevelData.LEVELS:
		out.append({"name": "level/" + String(l["name"]), "map": l["map"], "sizes": [1.0], "pad": false, "ceiling": false})
	out.append({"name": "segment/Start", "map": SegmentData.START, "sizes": [1.0], "pad": true, "ceiling": false})
	for s in SegmentData.SEGMENTS:
		out.append({"name": "segment/" + String(s["name"]), "map": s["map"], "sizes": [1.0], "pad": true, "ceiling": false})
	out.append({"name": "segment/Boss Arena", "map": SegmentData.BOSS_ARENA, "sizes": [1.0], "pad": true, "ceiling": false})
	for c in ChainedData.LEVELS:
		out.append({"name": "chained/" + String(c["name"]), "map": c["map"], "sizes": [1.0, 1.6], "pad": false, "ceiling": false})
	return out


func _make_strategies() -> void:
	_fixed_strategies = []
	for d in [-1, 1]:
		for h in HOLDS:
			_fixed_strategies.append({"name": "%s hold %d" % ["left" if d < 0 else "right", h], "steps": [[d, h]]})
	_fixed_strategies.append({"name": "straight up", "steps": [[0, 0]]})
	for d in [-1, 1]:
		_fixed_strategies.append({"name": "%s held forever" % ("left" if d < 0 else "right"), "steps": [[d, 1000000]], "keep": true})
		for h in [12, 42]:
			_fixed_strategies.append({"name": "%s keep hold %d" % ["left" if d < 0 else "right", h], "steps": [[d, h]], "keep": true})
	for h in [12, 42]:
		_fixed_strategies.append({"name": "alternate hold %d" % h, "steps": [[-1, h], [1, h]]})
		_fixed_strategies.append({"name": "alternate-up hold %d" % h, "steps": [[-1, h], [0, 0], [1, h], [0, 0]]})


func _build(m: Dictionary) -> Dictionary:
	var text: String = m["map"]
	var pad := 0
	if m["pad"]:
		pad = PAD_COLS
		var lines: PackedStringArray = []
		for line in text.replace("\r", "").strip_edges(false, true).split("\n"):
			if line.strip_edges() != "":
				lines.append(line)
		var n := lines.size()
		var out: PackedStringArray = []
		for r in n:
			var ground := r >= n - 2
			var side := ("#" if ground else ".").repeat(PAD_COLS - 1)
			out.append("#" + side + lines[r] + side + "#")
		text = "\n".join(out)
	var world := Node2D.new()
	world.visible = false
	add_child(world)
	var level := Level.new()
	level.decorate = false
	world.add_child(level)
	level.build(text)
	for ch in level.get_children():
		var keep: bool = ch.name == "Terrain" or ch is Spikes or ch is MovingPlatform or (ch is Pickup and ch.kind == "trampoline")
		if not keep:
			ch.queue_free()
	if m["ceiling"]:
		var ceiling := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(level.size.x, 200.0)
		shape.shape = rect
		shape.position = Vector2(level.size.x / 2.0, Brawl.CEILING_Y - 100.0)
		ceiling.add_child(shape)
		level.add_child(ceiling)
	return {"world": world, "level": level, "pad": pad}


func _is_solid(level: Level, c: int, r: int) -> bool:
	var ch := level.char_at(r, c)
	return ch == "#" or Level.SLOPES.has(ch)


func _reachable(level: Level) -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = []
	for r in level.rows.size():
		for c in level.cols:
			var ch := level.rows[r][c]
			if ch == "O" or ch == "P":
				seen[Vector2i(c, r)] = true
				queue.append(Vector2i(c, r))
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.x >= level.cols or nb.y < 0 or nb.y >= level.rows.size():
				continue
			if seen.has(nb) or level.rows[nb.y][nb.x] == "#":
				continue
			seen[nb] = true
			queue.append(nb)
	return seen


func _fit_position(level: Level, c: int, r: int, f: float) -> Vector2:
	var radius := 15.0 * f
	var probe := CircleShape2D.new()
	probe.radius = radius - FIT_SLACK
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = probe
	q.collision_mask = 1
	var cx := (c + 0.5) * TILE
	for y in [(r + 0.5) * TILE, (r + 1) * TILE - radius, r * TILE + radius]:
		q.transform = Transform2D(0.0, Vector2(cx, y))
		if level.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
			return Vector2(cx, y)
	return Vector2.INF


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _new_ball(world: Node2D, pos: Vector2, f: float) -> Ball:
	var b: Ball = BALL_SCENE.instantiate()
	b.position = pos
	world.add_child(b)
	if f != 1.0:
		b.set_size(f)
	if _variant.has("grav"):
		b.gravity_scale = _variant["grav"]
	if _variant.has("bounce") or _variant.has("fric"):
		var mat: PhysicsMaterial = b.physics_material_override.duplicate()
		if _variant.has("bounce"):
			mat.bounce = _variant["bounce"]
		if _variant.has("fric"):
			mat.friction = _variant["fric"]
		b.physics_material_override = mat
	return b


func _vlabel() -> String:
	return "size=%.2f%s" % [float(_variant["f"]), (" " + String(_variant["label"])) if _variant.has("label") else ""]


func _audit_map(m: Dictionary, variant: Dictionary) -> void:
	_variant = variant
	var f: float = variant["f"]
	var built := _build(m)
	var world: Node2D = built["world"]
	var level: Level = built["level"]
	var pad: int = built["pad"]
	await _frames(3)
	var tag := String(m["name"])
	var reach := _reachable(level)

	for ch in level.get_children():
		if ch is Pickup:
			ch.set_deferred("monitoring", false)
	var drops: Array = []
	var cells := 0
	var no_fit := 0
	for cell in reach.keys():
		var c: int = cell.x
		var r: int = cell.y
		var chr := level.rows[r][c]
		if _is_solid(level, c, r) or chr == "^" or chr == "v" or c < pad or c >= level.cols - pad:
			continue
		cells += 1
		var p := _fit_position(level, c, r, f)
		if p == Vector2.INF:
			no_fit += 1
			continue
		var b := _new_ball(world, p, f)
		var d := {"ball": b, "cell": cell, "hurt": false}
		b.hurt.connect(func() -> void: d["hurt"] = true)
		drops.append(d)
	print("  [%s %s] dropped %d balls at %.0f s" % [tag, _vlabel(), drops.size(), (Time.get_ticks_usec() - _run_started_usec) / 1000000.0])
	await _frames(SETTLE_FRAMES)
	print("  [%s %s] settled at %.0f s" % [tag, _vlabel(), (Time.get_ticks_usec() - _run_started_usec) / 1000000.0])
	await _frames(1)
	for pass_i in 2:
		var moving := false
		for d in drops:
			var b: Ball = d["ball"]
			if is_instance_valid(b) and b.linear_velocity.length() > REST_SPEED and not d["hurt"]:
				moving = true
		if moving and pass_i == 0:
			await _frames(SETTLE_EXTRA)
	var rests: Array = []
	var seen_keys := {}
	var unsettled := 0
	for d in drops:
		var b: Ball = d["ball"]
		var p := b.global_position
		var hurt: bool = d["hurt"]
		var ok: bool = not hurt and p.y <= level.size.y + FALL_MARGIN and b.linear_velocity.length() <= REST_SPEED
		if not hurt and p.y <= level.size.y + FALL_MARGIN and not ok:
			unsettled += 1
		if ok:
			var rc := Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))
			var key := Vector2i(int(round(p.x / 6.0)), int(round(p.y / 6.0)))
			if not seen_keys.has(key) and level.char_at(rc.y, rc.x) != "F" and rc.x >= pad and rc.x < level.cols - pad:
				seen_keys[key] = true
				rests.append({"pos": p, "cell": rc, "from": d["cell"], "alive": true, "stats": [], "esc": 0, "first": 99999})
		b.queue_free()
	await _frames(2)

	for ch in level.get_children():
		if ch is Pickup:
			ch.set_deferred("monitoring", true)
	await _run_round(world, level, rests, f, false)
	if _survey:
		for rest in rests:
			if rest["esc"] > 0:
				if rest["esc"] * 2 < _fixed_strategies.size():
					print("HARD %s col=%d row=%d %s: only %d of %d strategies escaped in %d s, first after %.1f s" % [
						tag.replace("/", " "), rest["cell"].x, rest["cell"].y, _vlabel(), rest["esc"], _fixed_strategies.size(), ROUND1_FRAMES / 60, rest["first"] / 60.0])
				rest["alive"] = false
	await _run_round(world, level, rests, f, true)

	var stuck_here := 0
	rests.sort_custom(func(a, b) -> bool: return a["cell"].y < b["cell"].y or (a["cell"].y == b["cell"].y and a["cell"].x < b["cell"].x))
	for rest in rests:
		if rest["alive"]:
			stuck_here += 1
			print("STUCK %s col=%d row=%d reason=%s" % [tag.replace("/", " "), rest["cell"].x, rest["cell"].y, _reason(level, rest, f)])
			if _verbose:
				for run in rest["stats"]:
					print("    try %-22s jumps=%d ground=%d/%d best_dist=%.0f best_ground=%.0f rise=%.0f rest=(%.0f, %.0f)" % [
						run.label, run.jumps, run.ground_frames, run.frames, run.best_dist, run.best_ground_dist, run.best_rise, rest["pos"].x, rest["pos"].y])
	_stuck_total += stuck_here
	if _verbose or stuck_here > 0:
		print("  audit %s %s: %d cells dropped (%d did not fit), %d resting spots (%d unsettled), %d stuck" % [tag, _vlabel(), cells, no_fit, rests.size(), unsettled, stuck_here])
	world.queue_free()
	await _frames(2)


func _run_round(world: Node2D, level: Level, rests: Array, f: float, random: bool) -> void:
	var runs: Array[Run] = []
	for i in rests.size():
		if not rests[i]["alive"]:
			continue
		var strategies: Array = []
		if random:
			for s in RANDOM_STRATEGIES:
				strategies.append({"name": "random %d" % s, "seed": 1000 + s, "keep": s % 2 == 1})
		else:
			strategies = _fixed_strategies
		for st in strategies:
			var run := Run.new()
			run.rest = i
			run.slot = _alloc_slot()
			run.keep = st.get("keep", false)
			run.label = st["name"]
			if st.has("seed"):
				run.rng = RandomNumberGenerator.new()
				run.rng.seed = st["seed"] + i * 7919
			else:
				run.steps = st["steps"]
			run.ball = _new_ball(world, rests[i]["pos"], f)
			run.ball.action_prefix = "au%d_" % run.slot
			if run.keep:
				var first_dir: int = run.steps[0][0] if run.rng == null else (-1 if run.rng.randi() % 2 == 0 else 1)
				_set_dir_key("au%d_" % run.slot, first_dir)
			run.ball.hurt.connect(func() -> void: run.hurt = true)
			run.ball.launched.connect(func() -> void: run.jumps += 1)
			runs.append(run)
	var frames := ROUND2_FRAMES if random else ROUND1_FRAMES
	for t in frames:
		await get_tree().physics_frame
		var done: Array[int] = []
		var live: Array[Run] = []
		for run in runs:
			if not rests[run.rest]["alive"] or not is_instance_valid(run.ball):
				_release(run)
				continue
			if _tick(run, level, rests[run.rest]["pos"]):
				if _survey and not random:
					rests[run.rest]["esc"] += 1
					rests[run.rest]["first"] = mini(rests[run.rest]["first"], t)
					_release(run)
					continue
				done.append(run.rest)
			live.append(run)
		for i in done:
			rests[i]["alive"] = false
		runs = live
		if runs.is_empty():
			break
	for run in runs:
		rests[run.rest]["stats"].append(run)
		_release_keys(run)
		run.ball.queue_free()
	await _frames(2)
	for run in runs:
		_slots_free.append(run.slot)


func _release(run: Run) -> void:
	_release_keys(run)
	if is_instance_valid(run.ball):
		run.ball.queue_free()
	_slots_free.append(run.slot)


func _release_keys(run: Run) -> void:
	for a in ["left", "right", "jump", "use"]:
		Input.action_release("au%d_%s" % [run.slot, a])


func _alloc_slot() -> int:
	if not _slots_free.is_empty():
		return _slots_free.pop_back()
	var id := _slot_total
	_slot_total += 1
	for a in ["left", "right", "jump", "use"]:
		InputMap.add_action("au%d_%s" % [id, a])
	return id


func _tick(run: Run, level: Level, rest: Vector2) -> bool:
	var b := run.ball
	var p := b.global_position
	var key := "au%d_" % run.slot
	run.frames += 1
	if b.on_ground:
		run.ground_frames += 1
	var dist := p.distance_to(rest)
	run.best_dist = maxf(run.best_dist, dist)
	run.best_rise = maxf(run.best_rise, rest.y - p.y)
	if b.on_ground:
		run.best_ground_dist = maxf(run.best_ground_dist, dist)
	if run.hurt or p.y > level.size.y + FALL_MARGIN:
		return true
	if level.char_at(int(floor(p.y / TILE)), int(floor(p.x / TILE))) == "F":
		return true
	if b.on_ground and dist >= ESCAPE_DIST:
		return true
	run.timer += 1
	match run.state:
		0:
			if b.on_ground and run.timer >= GROUND_PAUSE:
				var step: Array = _next_step(run)
				run.dir = step[0]
				run.hold = step[1]
				run.timer = 0
				if run.dir == 0:
					Input.action_press(key + "jump")
					run.state = 2
				else:
					_set_dir_key(key, run.dir)
					run.state = 1
		1:
			run.hold -= 1
			if run.hold <= 0:
				Input.action_press(key + "jump")
				run.timer = 0
				run.state = 2
		2:
			Input.action_release(key + "jump")
			if not run.keep:
				Input.action_release(key + "left")
				Input.action_release(key + "right")
			run.timer = 0
			run.state = 3
		3:
			if b.on_ground and run.timer >= MIN_AIR_FRAMES:
				run.timer = 0
				run.state = 0
	return false


func _set_dir_key(key: String, dir: int) -> void:
	Input.action_release(key + ("right" if dir < 0 else "left"))
	Input.action_press(key + ("left" if dir < 0 else "right"))


func _next_step(run: Run) -> Array:
	if run.rng != null:
		var r := run.rng.randi() % 5
		var d := -1 if r < 2 else (1 if r < 4 else 0)
		var h: int = [2, 6, 12, 20, 30, 42][run.rng.randi() % 6]
		return [d, h]
	var s: Array = run.steps[run.step_i % run.steps.size()]
	run.step_i += 1
	return s


func _reason(level: Level, rest: Dictionary, f: float) -> String:
	var runs: Array = rest["stats"]
	var best_dist := 0.0
	var best_rise := 0.0
	var best_ground := 0.0
	var jumps := 0
	var ground := 0
	var frames := 0
	for run in runs:
		best_dist = maxf(best_dist, run.best_dist)
		best_rise = maxf(best_rise, run.best_rise)
		best_ground = maxf(best_ground, run.best_ground_dist)
		jumps += run.jumps
		ground += run.ground_frames
		frames += run.frames
	var cell: Vector2i = rest["cell"]
	var head := 0
	while head < 40 and not _is_solid(level, cell.x, cell.y - 1 - head) and cell.y - 1 - head >= 0:
		head += 1
	var wl := 0
	while wl < 8 and not _is_solid(level, cell.x - 1 - wl, cell.y):
		wl += 1
	var wr := 0
	while wr < 8 and not _is_solid(level, cell.x + 1 + wr, cell.y):
		wr += 1
	var kind := ""
	if frames > 0 and ground == 0:
		kind = "wedged, never had an upward contact (on_ground stayed false)"
	elif best_rise < 1.6 * TILE:
		kind = "low ceiling or pocket: best jump rise %.0f px, headroom %d tiles" % [best_rise, head]
	elif wl < 8 and wr < 8:
		kind = "pit or narrow slot: free tiles left %d right %d, headroom %d" % [wl, wr, head]
	else:
		kind = "no way out found"
	return "%s %s; best move %.0f px (on ground %.0f px) in %d tries, %d%% of frames on ground" % [
		_vlabel(), kind, best_dist, best_ground, runs.size(), int(100.0 * ground / maxf(1.0, frames))]
