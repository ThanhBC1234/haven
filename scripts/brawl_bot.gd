class_name BrawlBot
extends Node

const DT := 1.0 / 60.0
const FRAME := 1.0 / 60.0
const TILE := 32.0
const CANDIDATE_CHARGES := [0.0, 0.12, 0.25, 0.38, 0.5, 0.62, 0.75, 0.88, 1.0]
const EVALS_PER_FRAME := 4
const MAX_SIM_STEPS := 180
const WAIT_HORIZON := 0.9
const LAND_LEAD := 0.0
const SPIKE_H := 10.0
const SPIKE_W := 26.0
const SPIKE_PAD := 2.0
const FALL_Y := 660.0
const CEILING_Y := -16.0
const ICE_SLIDE := 0.8
const TRAP_SIZE := Vector2(40.0, 30.0)
const GRAPH_CHARGE_STRIDE := 2
const GRAPH_NODES_PER_FRAME := 1
const TICK_BUDGET_USEC := 800
const SLIDE_DECEL := 1260.0
const BOUNCE := 0.55
const FRICTION_CUT := 1.4
const CAREFUL_SCALE := 0.3
const RELAX_AFTER := 1.2
const LAUNCH_CHECK_ERR := 0.05
const LAUNCH_CHECK_MIN_ERR := 0.02
const PREP_CHECK_WAIT := 30
const CHECK_DRIFT := 20.0
const ABORT_COMMIT := 3
const CHECK_LEAD := 24
const THIN_SKIN := -4.0
const THIN_DIVERGE := 24.0
const VETO_SECONDS := 1.5
const ALIGN_FRAMES := 5
const SETTLE_MAX := 40
const PREP_STALE_FRAMES := 20
const MAX_PLAN_DELAY := 1.2
const REST_SPEED := 110.0
const AIR_FIRE_FRAMES := 8
const SAFETY_SKIN := 4.0
const SKIN_Y := 3.0
const SKIN := 2.0
const HIT_NONE := 0
const HIT_LAND := 1
const HIT_BUMP := 2
const HAZARD_PAD := 12.0
const HIGH_WEIGHT := 1.0
const SPRING_SPEED := 920.0
const SPRING_AREA := Rect2(4.0, 4.0, 24.0, 28.0)
const INTRO_GRAPH_USEC := 4000
const EDGE_CANDIDATES := 2
const EDGE_REFINE := [0, -1, 1]
const STOMP_RANGE := 240.0
const STOMP_REWARD := 1500.0
const STOMP_SIGMA_SCALE := 0.3
const REFINE_GAP := 20.0
const REFINE_MAX := 8
const STOMP_MISS := 18.0
const STALL_LOOKAHEAD := 5.0
const MAX_CHECKS := 10
const STILL_LIMIT := 1.5
const STILL_FORCE := 3.5
const DESPERATE_AFTER := 10.0
const BOMB_HURRY := 8.0
const DEADLY_MARGIN := 20.0
const BOX_SPIKE_GAP := 44.0
const AFTER_WAIT_MARGIN := 160.0
const REACT_RANGE := 140.0
const REACT_DELAY := 0.12
const REACT_COOLDOWN := 0.7
const UNDER_FOE := 45.0
const STALL_FLOOR_COST := 150.0

static var tick_budget_usec := TICK_BUDGET_USEC
static var _graph_cache := {}
static var use_prebuilt := true

@export var skill := 0.6

var player_index := 1
var enabled := true
var brawl: Brawl
var ball: Ball
var foe: Ball
var mode := "chase"
var phase := "idle"
var hops := 0
var items_used := 0
var last_jump := ""
var _since_hop := 0.0
var _since_progress := 0.0
var _progress_hops := 999
var _cur_hops := 999
var _progress_dist := INF
var _extra_skin := 0.0
var timing_reason := ""
var timing_aborts := 0
var aborts := 0
var abort_reason := ""
var thoughts := 0
var last_choice := ""
var predicted_end := Vector2.ZERO

var _down := {}
var _pulses := {}
var _solid := PackedByteArray()
var _solid_sum := PackedInt32Array()
var _haz_sum := PackedInt32Array()
var _cols := 0
var _rows := 0
var _nodes: Array[Vector2] = []
var _node_at := PackedInt32Array()
var _redges: Array = []
var _edges: Array = []
var _graph_todo: Array[int] = []
var _graph_ctx := {}
var _graph_node := -1
var _graph_cands: Array = []
var _graph_job: EvalJob = null
var _graph_next := 0
var _graph_outs: Array = []
var last_tick_usec := 0
var _deadline := -1
var _graph_ticks := 0
var _base_radius := 15.0
var _graph_done := false
var _graph_usable := false
var _gdist := PackedInt32Array()
var _goal_node := -1
var _goal_src := -1
var _goal_from := -1
var _haz := PackedByteArray()
var _dyn_spikes: Array[Rect2] = []
var _soon_spikes: Array[Rect2] = []
var _traps: Array[Rect2] = []
var _gravity := 1400.0
var _damp := 0.1
var _clock := 0.0
var _history: Array = []
var _foe_reactive := 0.0
var _foe_was_ground := true
var _think_cd := 0.3
var _queue: Array = []
var _results: Array = []
var _think_job: EvalJob = null
var _think_cand: Array = []
var _ch_job: EvalJob = null
var _lc_job: EvalJob = null
var _ch_ranked: Array = []
var _ch_i := 0
var _ch_checks := 0
var _ch_wait_seen := false
var _ch_wait_score := 0.0
var _ch_amounts: Array = []
var _thick_end := Vector2.ZERO
var _thick_edge := false
var _ch_thin := false
var _ch_k := 0
var _ch_best: Dictionary = {}
var _ch_strict := true
var _ch_sigma := 0.0
var _ch_err := 0.0
var _plan_err := 0.0
var _prep_hold := 0
var _abort_streak := 0
var _refined := false
var _plan_charge := 0.0
var _veto_dir := 0
var _veto_charge := 0.0
var _veto_until := -1.0
var _plan_strict := true
var _aligned := false
var _lc_state := 0
var _lc_lead := 0.0
var _lc_from_x := 0.0
var _lc_dir := 0
var _lc_amounts: Array = []
var _lc_thin := false
var _lc_k := 0
var _lc_safe := true
var _ctx := {}
var _think_frames := 0
var _delay_frames := 0
var _hold_frames := 0
var _plan_dir := 0
var _plan_end := Vector2.ZERO
var _launch_wait := 0
var _launched := false
var _aim_frames := 0
var _comp_rev := false
var _rev_timer := 0.0
var _held_id := ""
var _held_time := 0.0
var _item_cd := 0.5
var _gun_cd := 0.0
var _lure_time := 0.0
var _threat := false
var _celebrate := false
var _box_pos := Vector2.INF


func _init() -> void:
	process_physics_priority = -10


func _ready() -> void:
	brawl = get_parent() as Brawl
	if brawl == null:
		push_error("BrawlBot must be a child of Brawl")
		return
	ball = brawl.balls[player_index]
	ball.action_prefix = "bot%d_" % (player_index + 1)
	foe = brawl.opponent_of(ball)
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1400.0))
	_damp = float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.1))
	_build_map()
	_build_nodes()
	_load_cached_graph()
	ball.launched.connect(_on_launched)
	brawl.point_scored.connect(_on_point_scored)
	brawl.match_over.connect(_on_match_over)


func _exit_tree() -> void:
	release_all()


func _act(action: String) -> String:
	return ball.action_prefix + action


func _key(dir: int) -> String:
	var d := -dir if _comp_rev else dir
	return _act("left" if d < 0 else "right")


func _press(action: String) -> void:
	_pulses.erase(action)
	if not _down.has(action):
		Input.action_press(action)
		_down[action] = true


func _release(action: String) -> void:
	if _down.has(action):
		Input.action_release(action)
		_down.erase(action)


func _pulse(action: String) -> void:
	_release(action)
	Input.action_press(action)
	_down[action] = true
	_pulses[action] = 1


func release_all() -> void:
	for action in _down.keys():
		Input.action_release(action)
	_down.clear()
	_pulses.clear()


func held_actions() -> Array:
	return _down.keys()


func _stop_all() -> void:
	release_all()
	phase = "idle"
	_queue.clear()
	_think_job = null
	_ch_job = null
	_lc_job = null
	_lc_state = 0
	_think_cd = 0.25
	_abort_streak = 0


func _physics_process(delta: float) -> void:
	if brawl == null or ball == null:
		return
	var t0 := Time.get_ticks_usec()
	_deadline = t0 + tick_budget_usec if tick_budget_usec >= 0 else -1
	if not _graph_done and tick_budget_usec >= 0 and brawl.match_running:
		_graph_step(tick_budget_usec / 2)
	_play(delta)
	if not _graph_done:
		var used := Time.get_ticks_usec() - t0
		var left := -1
		if tick_budget_usec >= 0:
			if brawl.match_running:
				left = clampi(tick_budget_usec - used, 0, tick_budget_usec / 2)
			else:
				left = maxi(0, maxi(INTRO_GRAPH_USEC, tick_budget_usec * 2) - used)
		_graph_step(left)
	last_tick_usec = Time.get_ticks_usec() - t0


func _play(delta: float) -> void:
	for action in _pulses.keys():
		_pulses[action] -= 1
		if _pulses[action] <= 0:
			_release(action)
			_pulses.erase(action)
	if not enabled or not brawl.match_running or ball.dead:
		if not _down.is_empty() or phase != "idle":
			_stop_all()
		return
	_clock += delta
	_held_time += delta
	_since_hop += delta
	_since_progress += delta
	_gun_cd = maxf(0.0, _gun_cd - delta)
	_lure_time = maxf(0.0, _lure_time - delta)
	_record_foe()
	_track_reverse(delta)
	match phase:
		"idle":
			_think_cd -= delta
			if not _try_items(delta) and _think_cd <= 0.0:
				_begin_think()
		"think":
			_think_step()
			_try_items(delta)
		"choose":
			_think_frames += 1
			_choose_step()
			_try_items(delta)
		"check":
			_launch_step()
		"prep":
			_delay_frames -= 1
			if _delay_frames > PREP_STALE_FRAMES and ball.on_ground and absf(ball.linear_velocity.y) < REST_SPEED:
				timing_aborts += 1
				timing_reason = "stale_prep"
				_cancel_jump()
				return
			if _delay_frames <= 0 and _plan_dir != 0 and not _aligned:
				_aligned = true
				var wait := _align_wait()
				if wait < 0 and _abort_streak >= ABORT_COMMIT:
					wait = 0
				if wait < 0:
					timing_aborts += 1
					timing_reason = "no_align"
					_cancel_jump()
					return
				_delay_frames = wait
			if _plan_dir != 0 and not _early_check(maxi(_delay_frames, 0) + _hold_frames):
				return
			if _delay_frames <= 0:
				if _plan_dir != 0 and _lc_state == 1 and _prep_hold < PREP_CHECK_WAIT and ball.on_ground and absf(ball.linear_velocity.y) < REST_SPEED:
					_prep_hold += 1
					return
				phase = "charge"
				_start_charge()
		"charge":
			_hold_frames -= 1
			if not _early_check(maxi(_hold_frames, 0)):
				return
			if _hold_frames <= 0:
				_fire_charged()
				return
		"launch":
			_launch_wait -= 1
			if _launched or _launch_wait <= 0:
				phase = "idle"
				_think_cd = 0.02 if _launched else 0.1
		"aim":
			_aim_frames -= 1
			if _aim_frames <= 0:
				for action in [_act("left"), _act("right")]:
					_release(action)
				phase = "idle"
				_think_cd = 0.0
				_item_cd = 0.0


func _on_launched() -> void:
	_launched = true


func _on_point_scored(scorer: Ball, victim: Ball, _cause: String) -> void:
	_since_progress = 0.0
	_progress_hops = 999
	_progress_dist = INF
	if victim == ball:
		_stop_all()
	elif scorer == ball:
		_celebrate = randf() < 0.5
		if phase != "idle":
			_stop_all()


func _on_match_over(_winner: Ball) -> void:
	_stop_all()


func _reaction() -> float:
	return lerpf(0.30, 0.03, skill)


func _record_foe() -> void:
	_history.append([_clock, foe.global_position, foe.linear_velocity])
	while _history.size() > 1 and _history[1][0] <= _clock - _reaction():
		_history.pop_front()
	_learn_foe(FRAME)


func _learn_foe(delta: float) -> void:
	var near := not foe.dead and not ball.dead and absf(ball.global_position.x - foe.global_position.x) < REACT_RANGE + 20.0 and ball.global_position.y < foe.global_position.y + 40.0
	var apart := ball.global_position.distance_to(foe.global_position) > ball.radius + foe.radius + 6.0
	var hopped := _foe_was_ground and not foe.on_ground and foe.linear_velocity.y < -450.0 and absf(foe.linear_velocity.x) < 150.0 and apart
	_foe_was_ground = foe.on_ground
	if near and hopped:
		_foe_reactive = minf(1.0, _foe_reactive + 0.4)
	elif near and foe.on_ground:
		_foe_reactive = maxf(0.0, _foe_reactive - 0.25 * delta)


func _foe_view() -> Array:
	return _history[0]


func _track_reverse(delta: float) -> void:
	if ball.reverse_controls == _comp_rev:
		_rev_timer = 0.0
		return
	_rev_timer += delta
	if _rev_timer >= lerpf(1.2, 0.3, skill):
		_comp_rev = ball.reverse_controls
		_rev_timer = 0.0


func _build_map() -> void:
	var level := brawl.level
	_cols = level.cols
	_rows = level.rows.size()
	_solid.resize(_cols * _rows)
	_haz.resize(_cols * _rows)
	for r in _rows:
		for c in _cols:
			var ch := level.char_at(r, c)
			_solid[r * _cols + c] = 1 if ch == "#" else 0
			_haz[r * _cols + c] = {"^": 1, "T": 2, "v": 3}.get(ch, 0)
	_solid_sum = _prefix_sums(_solid)
	_haz_sum = _prefix_sums(_haz)


func _prefix_sums(grid: PackedByteArray) -> PackedInt32Array:
	var w := _cols + 1
	var sums := PackedInt32Array()
	sums.resize(w * (_rows + 1))
	for r in _rows:
		for c in _cols:
			var cell := 1 if grid[r * _cols + c] != 0 else 0
			sums[(r + 1) * w + c + 1] = cell + sums[r * w + c + 1] + sums[(r + 1) * w + c] - sums[r * w + c]
	return sums


func _count_in(sums: PackedInt32Array, r0: int, r1: int, c0: int, c1: int) -> int:
	var w := _cols + 1
	return sums[(r1 + 1) * w + c1 + 1] - sums[r0 * w + c1 + 1] - sums[(r1 + 1) * w + c0] + sums[r0 * w + c0]


func _is_solid(r: int, c: int) -> bool:
	if c < 0 or c >= _cols:
		return true
	if r < 0 or r >= _rows:
		return false
	return _solid[r * _cols + c] == 1


func _hit_solid(p: Vector2, rad: float) -> bool:
	var c0 := floori((p.x - rad) / TILE)
	var c1 := floori((p.x + rad) / TILE)
	var r0 := floori((p.y - rad) / TILE)
	var r1 := floori((p.y + rad) / TILE)
	if c0 >= 0 and c1 < _cols:
		var rr0 := maxi(r0, 0)
		var rr1 := mini(r1, _rows - 1)
		if rr0 > rr1 or _count_in(_solid_sum, rr0, rr1, c0, c1) == 0:
			return false
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if not _is_solid(r, c):
				continue
			var nx := clampf(p.x, c * TILE, c * TILE + TILE)
			var ny := clampf(p.y, r * TILE, r * TILE + TILE)
			if (p.x - nx) * (p.x - nx) + (p.y - ny) * (p.y - ny) < rad * rad:
				return true
	return false


func _circle_hits(p: Vector2, rad: float, rect: Rect2) -> bool:
	var nx := clampf(p.x, rect.position.x, rect.end.x)
	var ny := clampf(p.y, rect.position.y, rect.end.y)
	return (p.x - nx) * (p.x - nx) + (p.y - ny) * (p.y - ny) < rad * rad


func _danger_at(p: Vector2, rad: float) -> int:
	var mask := 0
	if p.y > FALL_Y:
		return 1
	var tr0 := maxi(floori((p.y - rad) / TILE), 0)
	var tr1 := mini(floori((p.y + rad) / TILE), _rows - 1)
	var tc0 := maxi(floori((p.x - rad) / TILE), 0)
	var tc1 := mini(floori((p.x + rad) / TILE), _cols - 1)
	if tr0 <= tr1 and tc0 <= tc1 and _count_in(_haz_sum, tr0, tr1, tc0, tc1) > 0:
		for r in range(tr0, tr1 + 1):
			for c in range(tc0, tc1 + 1):
				var kind := _haz[r * _cols + c]
				if kind == 0:
					continue
				var x := c * TILE
				var y := r * TILE
				if kind == 2:
					if _circle_hits(p, rad, Rect2(Vector2(x, y) + SPRING_AREA.position, SPRING_AREA.size)):
						mask |= 2
				elif _circle_hits(p, rad + SPIKE_PAD, Rect2(x + (TILE - SPIKE_W) / 2.0, y + TILE - SPIKE_H if kind == 1 else y, SPIKE_W, SPIKE_H)):
					return 1
	for s in _dyn_spikes:
		if _circle_hits(p, rad + SPIKE_PAD, s):
			return 1
	for s in _traps:
		if _circle_hits(p, rad, s):
			mask |= 4
	return mask


func _ground_ok(x: float, y: float, rad: float) -> bool:
	var r := floori((y + rad + 2.0) / TILE)
	if not _is_solid(r, floori(x / TILE)):
		return false
	return (_danger_at(Vector2(x, y), rad + 4.0) & 1) == 0


func _ground_y_below(x: float, y: float, rad: float) -> float:
	var c := floori(x / TILE)
	var r0 := floori((y + rad + 2.0) / TILE)
	for r in range(r0, r0 + 4):
		if _is_solid(r, c):
			return r * TILE - rad
	return INF


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 16.0)
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		if _is_solid(floori(p.y / TILE), floori(p.x / TILE)):
			return false
	return true


func _graph_key() -> String:
	return "%s|%d|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.1f" % [brawl.arena_name, str(brawl.level.rows).hash(), _base_radius, ball.min_speed, ball.max_speed,
		ball.min_tilt_deg, ball.max_tilt_deg, ball.charge_time, _gravity, _damp * 100.0]


func _charge_steps() -> int:
	return maxi(1, roundi(ball.charge_time * 60.0))


func _load_cached_graph() -> bool:
	var key := _graph_key()
	var packed: Array = _graph_cache.get(key, [])
	if packed.is_empty() and use_prebuilt:
		packed = BrawlGraphs.GRAPHS.get(key, [])
	if packed.size() != _nodes.size():
		return false
	_unpack_graph(packed)
	_graph_todo.clear()
	_graph_done = true
	return true


func _store_graph() -> void:
	_graph_cache[_graph_key()] = pack_graph()


func pack_graph() -> Array:
	var steps := _charge_steps()
	var out: Array = []
	for i in _nodes.size():
		var row: Array = []
		for e in _edges[i]:
			row.append(int(e[0]) * 1000 + (int(e[1]) + 1) * 100 + roundi(float(e[2]) * steps))
		out.append(row)
	return out


func _unpack_graph(packed: Array) -> void:
	var steps := _charge_steps()
	for i in _nodes.size():
		_edges[i] = []
		_redges[i] = []
	for i in _nodes.size():
		for code in packed[i]:
			var j: int = int(code) / 1000
			var dir: int = (int(code) / 100) % 10 - 1
			var amount := float(int(code) % 100) / steps
			_edges[i].append([j, dir, amount])
			if not _redges[j].has(i):
				_redges[j].append(i)


func _build_nodes() -> void:
	_node_at.resize(_cols * _rows)
	_node_at.fill(-1)
	var base_radius := ball.radius / ball.size_factor
	_base_radius = base_radius
	for r in range(1, _rows):
		for c in range(1, _cols - 1):
			if not _is_solid(r, c) or _is_solid(r - 1, c) or _haz[(r - 1) * _cols + c] != 0:
				continue
			_node_at[r * _cols + c] = _nodes.size()
			_nodes.append(Vector2((c + 0.5) * TILE, r * TILE - base_radius))
	for i in _nodes.size():
		_redges.append([])
		_edges.append([])
		_graph_todo.append(i)
	_graph_ctx = {"me_pos": Vector2.ZERO, "me_vel": Vector2.ZERO, "g_me": _gravity, "foe_pos": Vector2.ZERO, "foe_vel": Vector2.ZERO,
		"g_foe": _gravity, "foe_on": false, "foe_invuln": 0.0, "my_invuln": 0.0, "ice": false, "box_pos": Vector2.INF, "t_contact": 0.0, "margin": 0.0,
		"rad": base_radius, "plain": true}


func _graph_step(budget_usec: int) -> void:
	if _graph_done or budget_usec == 0:
		return
	_graph_ticks += 1
	if budget_usec < 0:
		for n in GRAPH_NODES_PER_FRAME:
			if _graph_todo.is_empty() and _graph_node < 0:
				break
			_graph_run_one(-1)
			while _graph_node >= 0:
				_graph_run_one(-1)
	else:
		var until := Time.get_ticks_usec() + budget_usec
		while _graph_node >= 0 or not _graph_todo.is_empty():
			if not _graph_run_one(until) or Time.get_ticks_usec() >= until:
				break
	_graph_done = _graph_node < 0 and _graph_job == null and _graph_todo.is_empty()
	if _graph_done:
		_store_graph()


func _graph_begin_node(i: int) -> void:
	_graph_node = i
	_graph_ctx["me_pos"] = _nodes[i]
	_graph_cands = [[0, 0.5]]
	var steps := _charge_steps()
	for dir in [-1, 1]:
		for n in range(0, steps + 1, GRAPH_CHARGE_STRIDE):
			_graph_cands.append([dir, float(n) / steps])
	_graph_next = 0
	_graph_outs = []


func _graph_run_one(until_usec: int) -> bool:
	if _graph_node < 0:
		_graph_begin_node(_graph_todo.pop_front())
	if _graph_job == null:
		var cand: Array = _graph_cands[_graph_next]
		_graph_job = _eval_begin(cand[0], cand[1], false, _graph_ctx, 0.0, true)
	if not _eval_run(_graph_job, until_usec):
		return false
	var res := _graph_job.res
	_graph_job = null
	var j := -2 if res["dead"] or not res["landed"] or (res["spring"] and res["bonk"]) else _node_index_at(res["end"], _base_radius)
	_graph_outs.append(j)
	_graph_next += 1
	if _graph_next >= _graph_cands.size():
		_graph_finish_node(_graph_node)
		_graph_node = -1
	return true


func _graph_finish_node(i: int) -> void:
	for k in _graph_cands.size():
		var j: int = _graph_outs[k]
		if j < 0 or j == i:
			continue
		var cand: Array = _graph_cands[k]
		if cand[0] != 0:
			var fragile := false
			for nk in [k - 1, k + 1]:
				if nk >= 1 and nk < _graph_cands.size() and _graph_cands[nk][0] == cand[0] and _graph_outs[nk] < 0:
					fragile = true
			if fragile:
				continue
		if not _redges[j].has(i):
			_redges[j].append(i)
		_edges[i].append([j, cand[0], cand[1]])


func _node_index_at(p: Vector2, rad := -1.0) -> int:
	var c := floori(p.x / TILE)
	var r := floori((p.y + (rad if rad >= 0.0 else ball.radius) + 2.0) / TILE)
	if c < 0 or c >= _cols or r < 0 or r >= _rows:
		return -1
	return _node_at[r * _cols + c]


func _node_below(p: Vector2) -> int:
	var c := clampi(floori(p.x / TILE), 0, _cols - 1)
	for r in range(maxi(0, floori(p.y / TILE)), _rows):
		var n: int = _node_at[r * _cols + c]
		if n >= 0:
			return n
	var best := -1
	var best_d := INF
	for i in _nodes.size():
		var d := _nodes[i].distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _high_goal() -> int:
	var mine := _node_below(ball.global_position)
	var best_of_row := {}
	for i in _nodes.size():
		var y := _nodes[i].y
		if not best_of_row.has(y) or absf(_nodes[i].x - ball.global_position.x) < absf(_nodes[best_of_row[y]].x - ball.global_position.x):
			best_of_row[y] = i
	var heights: Array = best_of_row.keys()
	heights.sort()
	for y in heights:
		var g: int = best_of_row[y]
		if mine < 0 or _goal_hops(g)[mine] < 999:
			return g
	return mine


func _nearest_reachable(from: int, pos: Vector2) -> int:
	var seen := {from: true}
	var queue: Array[int] = [from]
	var best := from
	var best_d := _nodes[from].distance_to(pos)
	while not queue.is_empty():
		var n: int = queue.pop_front()
		for e in _edges[n]:
			var j: int = e[0]
			if seen.has(j):
				continue
			seen[j] = true
			queue.append(j)
			var d := _nodes[j].distance_to(pos)
			if d < best_d:
				best_d = d
				best = j
	return best


func _goal_hops(goal: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(_nodes.size())
	d.fill(999)
	d[goal] = 0
	var queue: Array[int] = [goal]
	while not queue.is_empty():
		var n: int = queue.pop_front()
		for p in _redges[n]:
			if d[p] == 999:
				d[p] = d[n] + 1
				queue.append(p)
	return d


func _hops_to_goal(e: Vector2) -> int:
	var j := _node_index_at(e)
	if j < 0:
		return 12
	return mini(_gdist[j], 12)


class SimBody extends RefCounted:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var rad := 15.0
	var air := true


func _slide(b: SimBody, v: float) -> bool:
	var dir_x := signf(v)
	var dist := v * v / (2.0 * SLIDE_DECEL)
	var moved := 0.0
	while moved < dist:
		var nx := b.pos.x + dir_x * 4.0
		if _hit_solid(Vector2(nx, b.pos.y), b.rad):
			return false
		b.pos.x = nx
		moved += 4.0
		if not _is_solid(floori((b.pos.y + b.rad + 2.0) / TILE), floori(nx / TILE)):
			b.vel.x = dir_x * sqrt(maxf(0.0, v * v - 2.0 * SLIDE_DECEL * moved))
			b.air = true
			return true
	return false


func _friction_cut(v: float, amount: float) -> float:
	return signf(v) * maxf(0.0, absf(v) - amount)


func _advance(b: SimBody, g: float) -> int:
	var result := HIT_NONE
	b.vel.y += g * DT
	b.vel *= maxf(0.0, 1.0 - _damp * DT)
	var rs := b.rad + SKIN + _extra_skin
	var x0 := b.pos.x
	var nx := b.pos.x + b.vel.x * DT
	if _hit_solid(Vector2(nx, b.pos.y), rs) and not _hit_solid(b.pos, rs):
		var vn := b.vel.x
		b.vel.x = -BOUNCE * vn
		b.vel.y = _friction_cut(b.vel.y, FRICTION_CUT * absf(vn))
		result = HIT_BUMP
	else:
		b.pos.x = nx
	var ny := b.pos.y + b.vel.y * DT
	if ny - b.rad < CEILING_Y:
		b.vel.y = 0.0
		return HIT_BUMP
	var np := Vector2(b.pos.x, ny)
	var rsy := b.rad + SKIN_Y + _extra_skin
	var touching: bool = _hit_solid(np, b.rad) if b.vel.y > 0.0 else (_hit_solid(np, rsy) and not _hit_solid(b.pos, rsy))
	if not touching and b.vel.y > 0.0 and _hit_solid(np, rsy) and not _hit_solid(b.pos, rsy):
		touching = true
	if touching:
		if b.vel.y > 0.0:
			var surface := floorf((ny + rsy) / TILE) * TILE - b.rad
			if ny > b.pos.y:
				b.pos.x = lerpf(x0, b.pos.x, clampf((surface - b.pos.y) / (ny - b.pos.y), 0.0, 1.0))
			b.pos.y = surface
			var slide_v := _friction_cut(b.vel.x, FRICTION_CUT * absf(b.vel.y))
			b.vel = Vector2.ZERO
			b.air = false
			if absf(slide_v) > 20.0 and _slide(b, slide_v):
				return HIT_NONE
			return HIT_LAND
		var vn := b.vel.y
		b.vel.y = -BOUNCE * vn
		b.vel.x = _friction_cut(b.vel.x, FRICTION_CUT * absf(vn))
		return HIT_BUMP
	b.pos.y = ny
	return result


func _evaluate(dir: int, charge: float, immediate := false, ctx := {}) -> Dictionary:
	var job := _eval_begin(dir, charge, immediate, ctx, _extra_skin)
	_eval_run(job, -1)
	return job.res


class EvalJob extends RefCounted:
	var dir := 0
	var charge := 0.0
	var c := {}
	var skin := 0.0
	var isolate := false
	var me: SimBody
	var op: SimBody
	var wait := false
	var launch_at := 0.0
	var res := {}
	var launched := false
	var landed := false
	var land_t := 0.0
	var vx_land := 0.0
	var t := 0.0
	var min_gap := 9999.0
	var step := 0
	var finished := false
	var in_spring := false
	var springs := 0
	var foe_gone := false
	var foe_hop_t := -1.0


func _eval_begin(dir: int, charge: float, immediate := false, ctx := {}, skin := 0.0, isolate := false, min_launch := 0.0) -> EvalJob:
	var c: Dictionary = ctx if not ctx.is_empty() else _ctx
	var me := SimBody.new()
	me.pos = c["me_pos"]
	me.vel = c["me_vel"]
	me.rad = c.get("rad", ball.radius)
	var op := SimBody.new()
	op.pos = c["foe_pos"]
	op.vel = c["foe_vel"]
	op.rad = foe.radius
	var g_me: float = c["g_me"]
	var g_foe: float = c["g_foe"]
	var foe_on: bool = c["foe_on"]
	var wait := charge < 0.0
	var hold_s := 0.0 if (wait or dir == 0 or immediate) else charge * ball.charge_time
	var launch_at := 0.0 if wait else maxf(maxf(hold_s + FRAME, float(c["t_contact"]) - LAND_LEAD), min_launch)
	var res := {"dead": false, "stomp_opp": -1.0, "stomp_me": -1.0, "bump": false, "min_gap": 9999.0, "box": false,
		"trap": false, "spring": false, "edge": false, "edge_deadly": false, "soon": false, "bonk": false, "landed": false, "end": me.pos, "end_opp": op.pos, "t_end": 0.0, "delay": launch_at - hold_s}
	var job := EvalJob.new()
	job.dir = dir
	job.charge = charge
	job.c = c
	job.skin = skin
	job.isolate = isolate
	job.me = me
	job.op = op
	job.wait = wait
	job.launch_at = launch_at
	job.res = res
	return job


func _eval_run(job: EvalJob, until_usec: int) -> bool:
	if job.finished:
		return true
	var keep_skin := _extra_skin
	_extra_skin = job.skin
	var keep_spikes := _dyn_spikes
	var keep_traps := _traps
	if job.isolate:
		var no_spikes: Array[Rect2] = []
		var no_traps: Array[Rect2] = []
		_dyn_spikes = no_spikes
		_traps = no_traps
	var c: Dictionary = job.c
	var me := job.me
	var op := job.op
	var res := job.res
	var dir := job.dir
	var charge := job.charge
	var wait := job.wait
	var launch_at := job.launch_at
	var g_me: float = c["g_me"]
	var g_foe: float = c["g_foe"]
	var foe_on: bool = c["foe_on"]
	var reactive: bool = c.get("foe_reactive", false)
	var foe_hop: Vector2 = c.get("foe_hop", Vector2.ZERO)
	var hazard_y: float = float(c.get("hazard", INF))
	var sd_speed: float = brawl.sudden_death_speed
	var has_hazard := hazard_y != INF
	var box_pos: Vector2 = c["box_pos"]
	var box_on := box_pos.is_finite()
	var box_reach := me.rad + BrawlItems.PICK_REACH - 2.0
	var launched := job.launched
	var landed := job.landed
	var land_t := job.land_t
	var vx_land := job.vx_land
	var t := job.t
	var min_gap := job.min_gap
	var paused := false
	while job.step < MAX_SIM_STEPS:
		job.step += 1
		t += DT
		if not launched:
			if me.air:
				_advance(me, g_me)
			if not wait and t >= launch_at:
				me.vel = _jump_vel(dir, charge, c)
				me.pos.y -= 1.0
				me.air = true
				launched = true
		elif me.air:
			vx_land = me.vel.x
			var hit := _advance(me, g_me)
			if hit == HIT_LAND:
				landed = true
				land_t = t
				res["landed"] = true
			elif hit == HIT_BUMP:
				res["bonk"] = true
		if foe_on and job.foe_gone:
			foe_on = false
		if foe_on and not op.air and reactive and (job.foe_hop_t < 0.0 or t - job.foe_hop_t >= REACT_COOLDOWN) and t >= REACT_DELAY and absf(me.pos.x - op.pos.x) < REACT_RANGE and me.pos.y < op.pos.y + 40.0:
			op.vel = foe_hop
			op.pos.y -= 1.0
			op.air = true
			job.foe_hop_t = t
		if foe_on and op.air:
			_advance(op, g_foe)
		var danger := _danger_at(me.pos, me.rad)
		if has_hazard and me.pos.y + me.rad + HAZARD_PAD >= hazard_y - sd_speed * t:
			danger |= 1
		if danger & 1 != 0:
			res["dead"] = true
			break
		var in_spring := danger & 2 != 0
		if in_spring and not job.in_spring:
			res["spring"] = true
			job.springs += 1
			if job.springs > 2:
				job.in_spring = true
				break
			me.vel.y = -SPRING_SPEED
			me.air = true
			if launched:
				landed = false
				res["landed"] = false
		job.in_spring = in_spring
		if danger & 4 != 0:
			res["trap"] = true
		if box_on and me.pos.distance_to(box_pos) <= box_reach:
			res["box"] = true
		if foe_on:
			var d := me.pos - op.pos
			var dist := maxf(d.length(), 0.01)
			var gap := dist - me.rad - op.rad
			min_gap = minf(min_gap, gap)
			if gap <= 1.0:
				var above := -d.y / dist
				if above > 0.6 and me.air and me.vel.y >= ball.stomp_speed:
					if float(c["foe_invuln"]) > t:
						break
					res["stomp_opp"] = t
					me.vel.y = -ball.stomp_bounce
					job.foe_gone = true
					foe_on = false
					continue
				elif above < -0.6 and op.air and op.vel.y >= foe.stomp_speed:
					if float(c["my_invuln"]) <= t:
						res["stomp_me"] = t
					break
				else:
					res["bump"] = true
					if launched:
						landed = true
						land_t = t
		if landed and t >= land_t + 0.08:
			break
		if wait and t >= WAIT_HORIZON:
			break
		if until_usec >= 0 and (job.step & 3) == 0 and Time.get_ticks_usec() >= until_usec:
			paused = true
			break
	if paused:
		job.launched = launched
		job.landed = landed
		job.land_t = land_t
		job.vx_land = vx_land
		job.t = t
		job.min_gap = min_gap
		_extra_skin = keep_skin
		_dyn_spikes = keep_spikes
		_traps = keep_traps
		return false
	res["min_gap"] = min_gap
	res["t_end"] = t
	res["end"] = me.pos
	res["end_opp"] = op.pos
	if not res["dead"] and (landed or wait) and not job.isolate:
		for s in _soon_spikes:
			if _circle_hits(me.pos, me.rad, s):
				res["soon"] = true
	if landed and not res["dead"]:
		var end: Vector2 = me.pos
		if c["ice"]:
			var slide := vx_land * ICE_SLIDE
			for k in range(1, 7):
				if not _ground_ok(end.x + slide * k / 6.0, end.y, me.rad):
					res["dead"] = true
			end.x = clampf(end.x + slide, 48.0, _cols * TILE - 48.0)
			res["end"] = end
		var m: float = c["margin"]
		var gy := _ground_y_below(end.x, end.y, me.rad)
		for off in [-m, 0.0, m]:
			if not gy < INF or not _ground_ok(end.x + off, gy, me.rad):
				res["edge"] = true
		for off in [-DEADLY_MARGIN, 0.0, DEADLY_MARGIN]:
			var below := _ground_y_below(end.x + off, gy, me.rad) if gy < INF else INF
			if not below < INF or (_danger_at(Vector2(end.x + off, below), me.rad + 4.0) & 1) != 0:
				res["edge_deadly"] = true
	job.finished = true
	_extra_skin = keep_skin
	_dyn_spikes = keep_spikes
	_traps = keep_traps
	return true


func _jump_vel(dir: int, charge: float, c: Dictionary) -> Vector2:
	if not c.get("plain", false):
		return ball.jump_velocity(dir, charge)
	var boost := ball.boost_time
	ball.boost_time = 0.0
	var v := ball.jump_velocity(dir, charge)
	ball.boost_time = boost
	return v


func _score(res: Dictionary) -> float:
	if res["dead"]:
		return -1000.0
	var s := 0.0
	var e: Vector2 = res["end"]
	var o: Vector2 = res["end_opp"]
	var bold: bool = brawl.stall_active
	if brawl.stall_active and not brawl.sudden_death_active and e.y > (brawl.floor_row() + 1) * TILE - 40.0:
		s -= STALL_FLOOR_COST
	if brawl.sudden_death_active:
		s -= HIGH_WEIGHT * e.y
	if res["stomp_opp"] >= 0.0:
		s += STOMP_REWARD * (1.2 if bold else 1.0) - 30.0 * res["stomp_opp"]
	if res["stomp_me"] >= 0.0:
		s -= 180.0 if bold else 450.0
	elif _ctx.get("foe_reactive", false) and res["stomp_opp"] < 0.0 and absf(e.x - o.x) < UNDER_FOE and e.y > o.y - 40.0:
		s -= 300.0
	if res["trap"]:
		s -= 350.0
	if res["spring"]:
		s -= 40.0
	if res["edge_deadly"]:
		s -= 150.0
	if res["soon"]:
		s -= 500.0
	if res["edge"]:
		s -= 60.0
	if res["bonk"]:
		s -= 100.0
	if res["box"] and brawl.items.held[player_index] == "":
		s += 260.0 if mode == "get_box" else 120.0
	if res["stomp_opp"] >= 0.0 and mode != "flee":
		return s
	match mode:
		"flee":
			s += minf(_path_cost(e, e.distance_to(o)), 700.0)
			s -= 150.0 * clampf((110.0 - minf(e.x, _cols * TILE - e.x)) / 110.0, 0.0, 1.0)
			if res["bump"] or res["min_gap"] <= 3.0:
				s -= 250.0
		"pass_bomb":
			s -= _path_cost(e, e.distance_to(o))
			if res["bump"] or res["min_gap"] <= 3.0:
				s += 350.0
		"get_box":
			s -= _path_cost(e, e.distance_to(_box_pos))
		_:
			var dy := e.y - o.y
			var gap := 170.0 if _ctx.get("foe_reactive", false) else 80.0
			s -= _path_cost(e, 0.7 * absf(absf(e.x - o.x) - gap) + 0.9 * (absf(dy) + maxf(dy, 0.0)))
	return s


func _path_cost(e: Vector2, near_cost: float) -> float:
	if not _graph_usable:
		return near_cost
	var hops := _hops_to_goal(e)
	if hops == 0:
		return near_cost
	return 150.0 * minf(hops, 12) + 0.25 * near_cost


func _begin_think() -> void:
	_snapshot()
	var foe_pos: Vector2 = _ctx["foe_pos"]
	mode = _pick_mode(foe_pos)
	_ctx["box_pos"] = _box_pos if mode == "get_box" or brawl.items.held[player_index] == "" else Vector2.INF
	_graph_usable = false
	_cur_hops = 999
	if _graph_done:
		var goal_pos: Vector2 = _box_pos if mode == "get_box" else foe_pos
		if mode == "pass_bomb":
			goal_pos = foe_pos + (_ctx["foe_vel"] as Vector2).limit_length(400.0) * 0.5
		var g := _high_goal() if brawl.sudden_death_active and (mode == "chase" or mode == "get_box") else _node_below(goal_pos)
		var mine := _node_below(ball.global_position)
		if g >= 0:
			if g != _goal_src or mine != _goal_from:
				_goal_src = g
				_goal_from = mine
				_goal_node = g
				_gdist = _goal_hops(g)
				if mine >= 0 and _gdist[mine] >= 999:
					var alt := _nearest_reachable(mine, goal_pos)
					if alt >= 0 and alt != g:
						_goal_node = alt
						_gdist = _goal_hops(alt)
			_graph_usable = true
			if mine >= 0:
				_cur_hops = _gdist[mine]
	_track_progress(foe_pos)
	_queue = [[0, -1.0], [0, 0.5]]
	for dir in [-1, 1]:
		for amount in CANDIDATE_CHARGES:
			_queue.append([dir, amount])
	for cand in _edge_candidates():
		_add_candidate(cand)
	for cand in _stomp_candidates():
		_add_candidate(cand)
	_results.clear()
	_think_job = null
	_think_frames = 0
	_refined = false
	phase = "think"
	thoughts += 1


func _track_progress(foe_pos: Vector2) -> void:
	if _graph_usable and _cur_hops < 999:
		if _cur_hops < _progress_hops:
			_since_progress = 0.0
		_progress_hops = _cur_hops
		return
	var d := ball.global_position.distance_to(foe_pos)
	if d < _progress_dist - 48.0:
		_since_progress = 0.0
		_progress_dist = d


func _add_candidate(cand: Array) -> void:
	for q in _queue:
		if q[0] == cand[0] and absf(float(q[1]) - float(cand[1])) < 0.01:
			return
	_queue.append(cand)


func _edge_candidates() -> Array:
	var out: Array = []
	if not _graph_usable or _cur_hops <= 0 or _cur_hops >= 999 or mode == "flee":
		return out
	var mine := _node_below(ball.global_position)
	if mine < 0:
		return out
	var by_node := {}
	for e in _edges[mine]:
		var j: int = e[0]
		if _gdist[j] < _cur_hops:
			if not by_node.has(j):
				by_node[j] = []
			by_node[j].append([e[1], e[2]])
	var targets: Array = by_node.keys()
	targets.sort_custom(func(a: int, b: int) -> bool: return _gdist[a] < _gdist[b])
	var steps := float(_charge_steps())
	for k in mini(EDGE_CANDIDATES, targets.size()):
		var jumps: Array = by_node[targets[k]]
		var mid: Array = jumps[jumps.size() / 2]
		for dk in EDGE_REFINE:
			var amount: float = float(mid[1]) + dk / steps
			if amount >= 0.0 and amount <= 1.0:
				out.append([mid[0], amount])
	return out


func _stomp_candidates() -> Array:
	var out: Array = []
	if mode == "flee" or not bool(_ctx["foe_on"]) or not (_ctx["land_pos"] as Vector2).is_finite() or float(_ctx["foe_invuln"]) > 1.0:
		return out
	var me: Vector2 = _ctx["land_pos"]
	var fp: Vector2 = _ctx["foe_pos"]
	var fv: Vector2 = _ctx["foe_vel"]
	var steps0 := maxi(1, roundi(ball.charge_time * 60.0))
	if _ctx.get("foe_reactive", false) and absf(fp.y - me.y) < 60.0 and absf(fp.x - me.x) > REACT_RANGE and absf(fp.x - me.x) < 2.0 * STOMP_RANGE:
		for n in range(steps0 - 8, steps0 + 1, 2):
			out.append([signi(roundi(fp.x - me.x)), float(n) / steps0])
	if absf(fp.x - me.x) > STOMP_RANGE or fp.y - me.y < -200.0 or fp.y - me.y > 420.0 or fv.length() > 80.0:
		return out
	var g: float = _ctx["g_me"]
	var target_y := fp.y - (ball.radius + foe.radius) * 0.85
	var steps := maxi(1, roundi(ball.charge_time * 60.0))
	for dir in [-1, 1]:
		if absf(fp.x - me.x) > 6.0 and signf(fp.x - me.x) != dir:
			continue
		var hits: Array = []
		for n in range(0, steps + 1):
			var amount := float(n) / steps
			var v := _jump_vel(dir, amount, _ctx)
			var c0 := me.y - 1.0 - target_y
			var disc := v.y * v.y - 2.0 * g * c0
			if disc < 0.0:
				continue
			if fp.y > me.y + 40.0:
				var x_back := me.x + v.x * (-2.0 * v.y / g)
				if _is_solid(floori((me.y + ball.radius + 2.0) / TILE), floori(x_back / TILE)):
					continue
			var t := (-v.y + sqrt(disc)) / g
			if v.y + g * t < ball.stomp_speed:
				continue
			var x := me.x + v.x * (1.0 - exp(-_damp * t)) / maxf(_damp, 0.0001)
			var wall_l := TILE + ball.radius
			var wall_r := _cols * TILE - TILE - ball.radius
			if x < wall_l:
				x = wall_l + (wall_l - x) * BOUNCE
			elif x > wall_r:
				x = wall_r - (x - wall_r) * BOUNCE
			var miss := absf(x - fp.x)
			if miss < STOMP_MISS:
				hits.append([miss, amount])
		hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for k in mini(2, hits.size()):
			out.append([dir, hits[k][1]])
	return out


func _snapshot() -> void:
	var view := _foe_view()
	var foe_pos: Vector2 = view[1]
	_dyn_spikes.clear()
	for s in brawl.stall_spikes:
		if is_instance_valid(s):
			_dyn_spikes.append(Rect2(s.position.x - SPIKE_W / 2.0, s.position.y - SPIKE_H, SPIKE_W, SPIKE_H))
	_soon_spikes.clear()
	for col in brawl.upcoming_stall_columns(2, STALL_LOOKAHEAD):
		_soon_spikes.append(Rect2(col * TILE, brawl.floor_row() * TILE, TILE, TILE))
	_traps.clear()
	for t in brawl.items.traps:
		if is_instance_valid(t):
			_traps.append(Rect2(t.position + Vector2(-TRAP_SIZE.x / 2.0, -TRAP_SIZE.y), TRAP_SIZE))
	var ice: bool = brawl.events != null and brawl.events.active_event == "ice_floor"
	_ctx = {
		"me_pos": ball.global_position, "me_vel": ball.linear_velocity, "g_me": _gravity * ball.gravity_scale,
		"foe_pos": foe_pos, "foe_vel": view[2], "g_foe": _gravity * foe.gravity_scale, "foe_on": not foe.dead,
		"foe_invuln": foe.invuln, "my_invuln": ball.invuln, "ice": ice, "box_pos": Vector2.INF, "t_contact": 0.0,
		"margin": (18.0 + 70.0 * (1.0 - skill)) * (1.6 if ice else 1.0),
		"hazard": brawl.hazard_y(),
		"foe_reactive": _foe_reactive > 0.5, "foe_hop": foe.jump_velocity(0, foe.straight_jump),
	}
	_ctx["land_pos"] = Vector2.INF
	_ctx["t_contact"] = _time_to_contact()


func _time_to_contact() -> float:
	var b := SimBody.new()
	b.pos = ball.global_position
	b.vel = ball.linear_velocity
	b.rad = ball.radius
	var g: float = _ctx["g_me"]
	for i in 90:
		if _advance(b, g) == HIT_LAND:
			_ctx["land_pos"] = b.pos
			return (i + 1) * DT
	return 99.0


func _pick_mode(foe_pos: Vector2) -> String:
	_box_pos = Vector2.INF
	var carrier: Ball = brawl.events.bomb_carrier if brawl.events != null else null
	if carrier == ball:
		return "pass_bomb"
	if carrier != null:
		return "flee"
	if _lure_time > 0.0:
		return "flee"
	if brawl.items.held[player_index] == "" and not foe.dead:
		var best := minf(560.0, maxf(160.0, 0.6 * ball.global_position.distance_to(foe_pos)))
		for box in brawl.items.boxes:
			if not is_instance_valid(box):
				continue
			if brawl.items.is_buried(box.position + Vector2(0.0, 60.0)):
				continue
			if (_danger_at(box.position, BOX_SPIKE_GAP) & 1) != 0:
				continue
			if not _ground_y_below(box.position.x - BOX_SPIKE_GAP, box.position.y, ball.radius) < INF or not _ground_y_below(box.position.x + BOX_SPIKE_GAP, box.position.y, ball.radius) < INF:
				continue
			var d: float = box.position.distance_to(ball.global_position)
			if d < best and box.position.distance_to(foe_pos) > 120.0:
				best = d
				_box_pos = box.position
		if _box_pos.is_finite():
			return "get_box"
	return "chase"


func _out_of_time() -> bool:
	return _deadline >= 0 and Time.get_ticks_usec() >= _deadline


func _think_step() -> void:
	_think_frames += 1
	var done := 0
	while _think_job != null or not _queue.is_empty():
		if _think_job == null:
			_think_cand = _queue.pop_front()
			_think_job = _eval_begin(_think_cand[0], _think_cand[1])
		if not _eval_run(_think_job, _deadline):
			break
		var res := _think_job.res
		_think_job = null
		_results.append({"dir": _think_cand[0], "charge": _think_cand[1], "res": res, "score": _score(res)})
		done += 1
		if (_deadline < 0 and done >= EVALS_PER_FRAME) or _out_of_time():
			break
	if _think_job == null and _queue.is_empty() and not _refined:
		_refined = true
		_refine_near_misses()
		if not _queue.is_empty():
			return
	if _think_job == null and _queue.is_empty():
		_choose_begin()
		_choose_step()


func _refine_near_misses() -> void:
	if mode == "flee" or not bool(_ctx["foe_on"]) or float(_ctx["foe_invuln"]) > 1.0:
		return
	var near: Array = []
	for r in _results:
		var res: Dictionary = r["res"]
		if res["stomp_opp"] >= 0.0:
			return
		if r["dir"] != 0 and r["charge"] >= 0.0 and not res["dead"] and res["min_gap"] < REFINE_GAP:
			near.append([res["min_gap"], r["dir"], r["charge"]])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var steps := float(_charge_steps())
	var added := 0
	for n in near:
		for dk in [-1, 1, -2, 2]:
			var amount: float = float(n[2]) + dk / steps
			if amount < 0.0 or amount > 1.0 or added >= REFINE_MAX:
				continue
			var before := _queue.size()
			_add_candidate([n[1], amount])
			for r in _results:
				if r["dir"] == n[1] and absf(float(r["charge"]) - amount) < 0.01 and _queue.size() > before:
					_queue.pop_back()
					break
			if _queue.size() > before:
				added += 1


func _choose_begin() -> void:
	var wait_res: Dictionary = _results[0]["res"]
	_threat = wait_res["stomp_me"] >= 0.0
	if _threat and mode == "chase":
		mode = "dodge"
	var noise := (1.5 - skill) * 18.0
	var ranked: Array = []
	var here := _node_below(ball.global_position)
	for r in _results:
		var cost := 0.0
		if r["charge"] >= 0.0:
			cost = 6.0
			if r["res"]["stomp_opp"] < 0.0 and _node_index_at(r["res"]["end"]) == here:
				cost = 30.0
		ranked.append([float(r["score"]) + randf_range(-noise, noise) - cost, r])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if randf() < (1.0 - skill) * 0.06:
		var pick: Array = ranked[randi() % ranked.size()]
		if pick[1]["charge"] >= 0.0 and not pick[1]["res"]["dead"]:
			ranked.push_front(pick)
	if _celebrate:
		_celebrate = false
		ranked.push_front([0.0, _results[1]])
	var strict := _since_progress < RELAX_AFTER and not brawl.stall_active and mode != "pass_bomb"
	var sigma := (0.02 + 0.12 * (1.0 - skill)) * (1.0 if strict else CAREFUL_SCALE)
	_ch_job = null
	_ch_ranked = ranked
	_ch_strict = strict
	_ch_sigma = sigma
	_ch_best = _results[0]
	_ch_i = 0
	_ch_checks = 0
	_ch_wait_seen = false
	_ch_amounts = []
	_ch_k = 0
	_ch_thin = false
	phase = "choose"


func _choose_step() -> void:
	while _ch_i < _ch_ranked.size():
		var r: Dictionary = _ch_ranked[_ch_i][1]
		if _ch_amounts.is_empty():
			if r["charge"] < 0.0:
				_ch_best = r
				if _ch_wait_seen or not _keep_looking():
					break
				_ch_wait_seen = true
				_ch_wait_score = _ch_ranked[_ch_i][0]
				_ch_i += 1
				continue
			if r["res"]["dead"] or (r["dir"] != 0 and _clock < _veto_until and r["dir"] == _veto_dir and absf(r["charge"] - _veto_charge) < 0.13):
				_ch_i += 1
				continue
			if _ch_wait_seen:
				if _ch_ranked[_ch_i][0] < _ch_wait_score - AFTER_WAIT_MARGIN and _since_hop <= STILL_FORCE:
					break
				if not _moves_on(r):
					_ch_i += 1
					continue
			if r["dir"] == 0:
				_ch_best = r
				break
			if _ch_checks >= (MAX_CHECKS * 2 if _since_hop > STILL_FORCE else MAX_CHECKS):
				_ch_i += 1
				continue
			_ch_checks += 1
			var charge: float = r["charge"]
			var sig := _ch_sigma * (STOMP_SIGMA_SCALE if r["res"]["stomp_opp"] >= 0.0 else 1.0)
			var err := 1.5 * _jump_sigma(sig, charge) * (2.0 if r["res"]["spring"] else 1.0)
			_ch_amounts = [maxf(0.0, charge - err), charge, minf(1.0, charge + err)]
			_ch_err = err
			_ch_k = 0
		if _ch_job == null:
			_ch_job = _eval_begin(r["dir"], _ch_amounts[_ch_k], false, {}, THIN_SKIN if _ch_thin else SAFETY_SKIN)
		if not _eval_run(_ch_job, _deadline):
			return
		var res := _ch_job.res
		_ch_job = null
		var unsafe: bool = res["dead"] or ((res["soon"] or res["edge_deadly"]) and not _desperate()) or (_ch_strict and res["edge"]) or (res["spring"] and res["bonk"])
		if _ch_thin and not unsafe:
			unsafe = (res["end"] as Vector2).distance_to(_thick_end) > THIN_DIVERGE and (res["edge"] or _thick_edge)
		if not unsafe and res["bonk"] and not _ch_thin:
			_ch_thin = true
			_thick_end = res["end"]
			_thick_edge = res["edge"]
			if _out_of_time():
				return
			continue
		_ch_thin = false
		_ch_k += 1
		if unsafe:
			_ch_amounts = []
			_ch_i += 1
		elif _ch_k >= _ch_amounts.size():
			_ch_best = r
			break
		if _out_of_time():
			return
	_choose_finish(_ch_best)


func _desperate() -> bool:
	if _since_progress > DESPERATE_AFTER:
		return true
	if mode == "pass_bomb" and brawl.events != null and brawl.events.time_left < BOMB_HURRY:
		return true
	if _results.is_empty():
		return false
	var w: Dictionary = _results[0]["res"]
	return w["dead"] or w["soon"]


func _keep_looking() -> bool:
	if _since_hop > STILL_LIMIT:
		return true
	if mode == "flee":
		return false
	if _graph_usable and _cur_hops < 999:
		return _cur_hops > 0
	return ball.global_position.distance_to(_ctx["foe_pos"]) > 120.0


func _moves_on(r: Dictionary) -> bool:
	var res: Dictionary = r["res"]
	if res["stomp_opp"] >= 0.0:
		return true
	if not res["landed"]:
		return false
	var e: Vector2 = res["end"]
	if _since_hop > STILL_FORCE:
		return e.distance_to(ball.global_position) > 40.0
	if _graph_usable and _cur_hops < 999:
		var h := _hops_to_goal(e)
		if h < _cur_hops:
			return true
		var limit := _cur_hops + (1 if _since_hop > 2.0 * STILL_LIMIT else 0)
		return _since_hop > STILL_LIMIT and h <= limit and _node_index_at(e) != _node_below(ball.global_position)
	var o: Vector2 = _ctx["foe_pos"]
	return e.distance_to(o) < ball.global_position.distance_to(o) - 40.0 or (_since_hop > STILL_LIMIT and absf(e.x - ball.global_position.x) > 40.0)


func _choose_finish(best: Dictionary) -> void:
	var sigma := _ch_sigma
	_ch_ranked = []
	_think_cd = lerpf(0.30, 0.03, skill)
	phase = "idle"
	if best["charge"] < 0.0:
		last_choice = "wait score=%d mode=%s" % [best.get("score", 0), mode]
		return
	var dir: int = best["dir"]
	var amount: float = best["charge"]
	if dir != 0:
		if best["res"]["stomp_opp"] >= 0.0:
			sigma *= STOMP_SIGMA_SCALE
		var s := _jump_sigma(sigma, amount)
		amount = clampf(amount + clampf(randfn(0.0, s), -1.5 * s, 1.5 * s), 0.0, 1.0)
	_plan_end = best["res"]["end"]
	last_choice = "dir=%d charge=%.2f score=%d mode=%s" % [dir, amount, best["score"], mode]
	_plan_dir = dir
	_plan_charge = amount
	_lc_state = 0
	_aligned = false
	_plan_strict = _ch_strict
	_plan_err = _ch_err if dir != 0 else LAUNCH_CHECK_MIN_ERR
	_prep_hold = 0
	_hold_frames = 0 if dir == 0 else maxi(1, roundi(amount * ball.charge_time * 60.0))
	var res: Dictionary = best["res"]
	_delay_frames = maxi(0, roundi(float(res["delay"]) * 60.0) - _think_frames)
	if _delay_frames > roundi(MAX_PLAN_DELAY * 60.0):
		phase = "idle"
		_think_cd = 0.1
		return
	phase = "prep"


func _jump_sigma(sigma: float, charge: float) -> float:
	return sigma * (0.3 + charge)


func _start_charge() -> void:
	if _plan_dir == 0:
		_jump_now()
		return
	_press(_key(_plan_dir))


func _early_check(frames_left: int) -> bool:
	if _lc_state != 0 and phase == "charge" and ball.charge_dir != 0 and ball.charge_dir != _lc_dir:
		_lc_state = 0
		_lc_job = null
	if _lc_state == 0 and frames_left <= CHECK_LEAD:
		_launch_begin(_plan_charge, float(maxi(frames_left, 0)) * DT)
		_lc_state = 1
	if _lc_state == 1 and _launch_check_run():
		_lc_state = 2
	if _lc_state == 2 and not _lc_safe:
		_launch_finish(false)
		return false
	return true


func _fire_charged() -> void:
	var off_plan: bool = ball.charge_dir == 0 or ball.charge_dir != _lc_dir or absf(ball.charge - _plan_charge) > LAUNCH_CHECK_ERR or (_lc_from_x < INF and absf(ball.global_position.x - _lc_from_x) > CHECK_DRIFT)
	var too_high: bool = not ball.on_ground and _frames_to_ground(AIR_FIRE_FRAMES) > AIR_FIRE_FRAMES
	var commit := _abort_streak >= ABORT_COMMIT
	if commit:
		off_plan = ball.charge_dir == 0 or ball.charge_dir != _lc_dir or absf(ball.charge - _plan_charge) > 2.0 * LAUNCH_CHECK_ERR or (_lc_from_x < INF and absf(ball.global_position.x - _lc_from_x) > CHECK_DRIFT)
	if (_lc_state != 2 and not (commit and _lc_k >= 2)) or off_plan or too_high or (_lc_state == 2 and not _lc_safe):
		timing_aborts += 1
		timing_reason = "check_late=%s off_plan=%s (dir %d/%d charge %.2f/%.2f) too_high=%s (to ground %d frames, vel %s, hold %d)" % [_lc_state != 2, off_plan, ball.charge_dir, _lc_dir, ball.charge, _plan_charge, too_high, _frames_to_ground(60), ball.linear_velocity.round(), _hold_frames]
		_cancel_jump()
		return
	_launch_finish(true)


func _align_wait() -> int:
	var total := _hold_frames + SETTLE_MAX
	var b := SimBody.new()
	b.pos = ball.global_position
	b.vel = ball.linear_velocity
	b.rad = ball.radius
	var g := _gravity * ball.gravity_scale
	var contacts: Array[int] = []
	var settle := 1 << 30
	if ball.on_ground and absf(b.vel.y) < REST_SPEED:
		settle = 0
	else:
		for f in range(1, total + 1):
			var vy_in := b.vel.y + g * DT
			if _advance(b, g) == HIT_LAND:
				if vy_in < REST_SPEED:
					settle = f
					break
				contacts.append(f)
				b.vel = Vector2(0.0, -BOUNCE * vy_in)
				b.air = true
	for k in range(0, SETTLE_MAX + 1):
		var fire := k + _hold_frames
		if fire >= settle:
			return k
		for c in contacts:
			if c >= fire:
				if c - fire <= ALIGN_FRAMES:
					return k
				break
	return -1


func _frames_to_ground(limit: int) -> int:
	if ball.on_ground:
		return 0
	var b := SimBody.new()
	b.pos = ball.global_position
	b.vel = ball.linear_velocity
	b.rad = ball.radius
	var g := _gravity * ball.gravity_scale
	for i in limit:
		if _advance(b, g) == HIT_LAND:
			return i + 1
	return limit + 1


func _cancel_jump() -> void:
	for key in [_act("left"), _act("right")]:
		_release(key)
	_lc_state = 0
	_lc_job = null
	phase = "idle"
	_think_cd = 0.0
	_abort_streak += 1


func _launch_begin(planned := -1.0, lead := 0.0) -> void:
	_snapshot()
	if planned >= 0.0:
		_lc_dir = ball.charge_dir if (phase == "charge" and ball.charge_dir != 0) else _plan_dir
	else:
		_lc_dir = ball.charge_dir if _plan_dir != 0 else 0
	var amount := planned if planned >= 0.0 else (ball.charge if _lc_dir != 0 else ball.straight_jump)
	if _lc_dir == 0:
		amount = ball.straight_jump
	_lc_amounts = []
	var err := clampf(_plan_err, LAUNCH_CHECK_MIN_ERR, LAUNCH_CHECK_ERR)
	for delta in [-err, 0.0, err]:
		_lc_amounts.append(clampf(amount + delta, 0.0, 1.0))
	_lc_lead = lead
	_lc_from_x = ball.global_position.x if ball.on_ground and absf(ball.linear_velocity.x) < 30.0 else INF
	_lc_thin = false
	_lc_k = 0
	_lc_safe = true
	_lc_job = null


func _launch_check_run() -> bool:
	while _lc_k < _lc_amounts.size() and _lc_safe:
		if _lc_job == null:
			_lc_job = _eval_begin(_lc_dir, _lc_amounts[_lc_k], true, {}, THIN_SKIN if _lc_thin else SAFETY_SKIN, false, _lc_lead)
		if not _eval_run(_lc_job, _deadline):
			return false
		var res := _lc_job.res
		_lc_job = null
		var unsafe: bool = res["dead"] or res["soon"] or (res["spring"] and res["bonk"]) or (_abort_streak < ABORT_COMMIT and _plan_strict and res["bonk"] and res["edge"])
		if _lc_thin and not unsafe:
			unsafe = (res["end"] as Vector2).distance_to(_thick_end) > THIN_DIVERGE and (res["edge"] or _thick_edge)
		if not unsafe and res["bonk"] and not _lc_thin:
			_lc_thin = true
			_thick_end = res["end"]
			_thick_edge = res["edge"]
			if _out_of_time():
				return false
			continue
		_lc_thin = false
		_lc_k += 1
		if unsafe:
			_lc_safe = false
			abort_reason = "charge=%.2f dead=%s bonk=%s edge=%s thin=%s end=%s stomp=%.2f" % [_lc_amounts[_lc_k - 1], res["dead"], res["bonk"], res["edge"], _lc_thin, (res["end"] as Vector2).round(), res["stomp_opp"]]
		elif _lc_k < _lc_amounts.size() and _out_of_time():
			return false
	return true


func _launch_step() -> void:
	if _launch_check_run():
		_launch_finish(_lc_safe)


func _jump_now() -> void:
	_launch_begin()
	phase = "check"
	_launch_step()


func _launch_finish(safe: bool) -> void:
	_lc_state = 0
	if not safe:
		_veto_dir = _plan_dir
		_veto_charge = _plan_charge
		_veto_until = _clock + VETO_SECONDS
		aborts += 1
		_cancel_jump()
		return
	for key in [_act("left"), _act("right")]:
		if _down.has(key):
			_pulses[key] = 3
	_pulse(_act("jump"))
	predicted_end = _plan_end
	last_jump = "from=%s plan_dir=%d real_dir=%d rev=%s charge=%.2f pred=%s vel=%s ground=%s" % [ball.global_position.round(), _plan_dir, ball.charge_dir, ball.reverse_controls, ball.charge, _plan_end.round(), ball.linear_velocity.round(), ball.on_ground]
	_launched = false
	_launch_wait = 40
	_abort_streak = 0
	phase = "launch"
	hops += 1
	_since_hop = 0.0


func _try_items(delta: float) -> bool:
	var id: String = brawl.items.held[player_index]
	if id != _held_id:
		_held_id = id
		_held_time = 0.0
	if id == "" or foe.dead:
		return false
	_item_cd -= delta
	if _item_cd > 0.0:
		return false
	_item_cd = lerpf(0.4, 0.12, skill)
	var view := _foe_view()
	var fp: Vector2 = view[1]
	var fv: Vector2 = view[2]
	var me := ball.global_position
	var d := fp - me
	match id:
		"gun":
			return _try_gun(fp)
		"banana":
			if d.length() < 600.0 and _held_time > 0.6:
				return _use_item()
		"swap":
			var worse := fp.y < me.y - 90.0
			var cornered := _threat and _held_time > 0.3
			if worse or cornered or (d.length() < 160.0 and randf() < 0.1):
				return _use_item()
		"spring":
			var level_with := absf(d.y) < 50.0 and absf(d.x) > 90.0 and absf(d.x) < 320.0
			var coming := signf(fv.x) == -signf(d.x) and absf(fv.x) > 40.0 or foe.charge_dir == -signi(d.x)
			if level_with and coming:
				_lure_time = 1.8
				return _use_item()
	return false


func _use_item() -> bool:
	_pulse(_act("use"))
	items_used += 1
	return true


func _try_gun(fp: Vector2) -> bool:
	if ball.ammo <= 0 or _gun_cd > 0.0:
		return false
	var d := fp - ball.global_position
	var ax := absf(d.x)
	if absf(d.y) > 24.0 or ax < 50.0 or ax > 560.0 or not _line_clear(ball.global_position, fp):
		return false
	var dirx := 1 if d.x > 0.0 else -1
	var edge := false
	for k in [40.0, 90.0, 140.0]:
		edge = edge or not _ground_ok(fp.x + dirx * k, fp.y, foe.radius)
	if not edge and randf() > 0.35 + 0.4 * skill:
		return false
	if ball.facing != dirx:
		_press(_key(dirx))
		_aim_frames = 3
		phase = "aim"
		_queue.clear()
		return true
	_gun_cd = 0.3
	return _use_item()
