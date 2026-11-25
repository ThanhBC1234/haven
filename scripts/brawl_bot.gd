class_name BrawlBot
extends Node

const DT := 1.0 / 60.0
const FRAME := 1.0 / 60.0
const TILE := 32.0
const CANDIDATE_CHARGES := [0.0, 0.12, 0.25, 0.38, 0.5, 0.62, 0.75, 0.88, 1.0]
const EVALS_PER_FRAME := 4
const MAX_SIM_STEPS := 140
const WAIT_HORIZON := 0.9
const LAND_LEAD := 0.06
const SPIKE_H := 10.0
const SPIKE_W := 26.0
const SPIKE_PAD := 2.0
const FALL_Y := 660.0
const CEILING_Y := -16.0
const ICE_SLIDE := 0.8
const TRAP_SIZE := Vector2(40.0, 30.0)
const GRAPH_CHARGES := [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]
const GRAPH_NODES_PER_FRAME := 1
const SLIDE_DECEL := 1260.0
const BOUNCE := 0.55
const FRICTION_CUT := 1.4
const CAREFUL_SCALE := 0.3
const RELAX_AFTER := 2.5
const LAUNCH_CHECK_ERR := 0.05
const SAFETY_SKIN := 4.0
const SKIN_Y := 3.0
const SKIN := 2.0
const HIT_NONE := 0
const HIT_LAND := 1
const HIT_BUMP := 2
const HAZARD_PAD := 12.0
const HIGH_WEIGHT := 1.0

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
var _extra_skin := 0.0
var aborts := 0
var thoughts := 0
var last_choice := ""
var predicted_end := Vector2.ZERO

var _down := {}
var _pulses := {}
var _solid := PackedByteArray()
var _cols := 0
var _rows := 0
var _nodes: Array[Vector2] = []
var _node_at := PackedInt32Array()
var _redges: Array = []
var _graph_todo: Array[int] = []
var _graph_ctx := {}
var _graph_done := false
var _graph_usable := false
var _gdist := PackedInt32Array()
var _goal_node := -1
var _haz := PackedByteArray()
var _dyn_spikes: Array[Rect2] = []
var _traps: Array[Rect2] = []
var _gravity := 1400.0
var _damp := 0.1
var _clock := 0.0
var _history: Array = []
var _think_cd := 0.3
var _queue: Array = []
var _results: Array = []
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
	foe = brawl.opponent_of(ball)
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 1400.0))
	_damp = float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.1))
	_build_map()
	_build_nodes()
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
	_think_cd = 0.25


func _physics_process(delta: float) -> void:
	if brawl == null or ball == null:
		return
	_graph_step()
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
		"prep":
			_delay_frames -= 1
			if _delay_frames <= 0:
				phase = "charge"
				_start_charge()
		"charge":
			_hold_frames -= 1
			if _hold_frames <= 0:
				if ball.on_ground or _hold_frames < -6:
					_jump_now()
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
	for r in range(floori((p.y - rad) / TILE), floori((p.y + rad) / TILE) + 1):
		if r < 0 or r >= _rows:
			continue
		for c in range(floori((p.x - rad) / TILE), floori((p.x + rad) / TILE) + 1):
			if c < 0 or c >= _cols:
				continue
			var kind := _haz[r * _cols + c]
			if kind == 0:
				continue
			var x := c * TILE
			var y := r * TILE
			if kind == 2:
				if _circle_hits(p, rad, Rect2(x, y, TILE, TILE)):
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


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 16.0)
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		if _is_solid(floori(p.y / TILE), floori(p.x / TILE)):
			return false
	return true


func _build_nodes() -> void:
	_node_at.resize(_cols * _rows)
	_node_at.fill(-1)
	var base_radius := ball.radius / ball.size_factor
	for r in range(1, _rows):
		for c in range(1, _cols - 1):
			if not _is_solid(r, c) or _is_solid(r - 1, c) or _haz[(r - 1) * _cols + c] != 0:
				continue
			_node_at[r * _cols + c] = _nodes.size()
			_nodes.append(Vector2((c + 0.5) * TILE, r * TILE - base_radius))
	for i in _nodes.size():
		_redges.append([])
		_graph_todo.append(i)
	_graph_ctx = {"me_pos": Vector2.ZERO, "me_vel": Vector2.ZERO, "g_me": _gravity, "foe_pos": Vector2.ZERO, "foe_vel": Vector2.ZERO,
		"g_foe": _gravity, "foe_on": false, "foe_invuln": 0.0, "my_invuln": 0.0, "ice": false, "box_pos": Vector2.INF, "t_contact": 0.0, "margin": 0.0}


func _graph_step() -> void:
	if _graph_todo.is_empty():
		_graph_done = true
		return
	for n in GRAPH_NODES_PER_FRAME:
		if _graph_todo.is_empty():
			break
		_expand_node(_graph_todo.pop_front())
	if _graph_todo.is_empty():
		_graph_done = true


func _expand_node(i: int) -> void:
	_graph_ctx["me_pos"] = _nodes[i]
	var cands: Array = [[0, 0.5]]
	for dir in [-1, 1]:
		for amount in GRAPH_CHARGES:
			cands.append([dir, amount])
	for cand in cands:
		var res := _evaluate(cand[0], cand[1], false, _graph_ctx)
		if res["dead"] or not res["landed"] or res["spring"]:
			continue
		var j := _node_index_at(res["end"])
		if j >= 0 and j != i and not _redges[j].has(i):
			_redges[j].append(i)


func _node_index_at(p: Vector2) -> int:
	var c := floori(p.x / TILE)
	var r := floori((p.y + ball.radius + 2.0) / TILE)
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
	var c: Dictionary = ctx if not ctx.is_empty() else _ctx
	var me := SimBody.new()
	me.pos = c["me_pos"]
	me.vel = c["me_vel"]
	me.rad = ball.radius
	var op := SimBody.new()
	op.pos = c["foe_pos"]
	op.vel = c["foe_vel"]
	op.rad = foe.radius
	var g_me: float = c["g_me"]
	var g_foe: float = c["g_foe"]
	var foe_on: bool = c["foe_on"]
	var wait := charge < 0.0
	var hold_s := 0.0 if (wait or dir == 0 or immediate) else charge * ball.charge_time
	var launch_at := 0.0 if wait else maxf(hold_s + FRAME, float(c["t_contact"]) - LAND_LEAD)
	var res := {"dead": false, "stomp_opp": -1.0, "stomp_me": -1.0, "bump": false, "min_gap": 9999.0, "box": false,
		"trap": false, "spring": false, "edge": false, "bonk": false, "landed": false, "end": me.pos, "end_opp": op.pos, "t_end": 0.0, "delay": launch_at - hold_s}
	var launched := false
	var landed := false
	var land_t := 0.0
	var vx_land := 0.0
	var t := 0.0
	for i in MAX_SIM_STEPS:
		t += DT
		if not launched:
			if me.air:
				_advance(me, g_me)
			if not wait and t >= launch_at:
				me.vel = ball.jump_velocity(dir, charge)
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
		if foe_on and op.air:
			_advance(op, g_foe)
		var danger := _danger_at(me.pos, me.rad)
		if me.pos.y + me.rad + HAZARD_PAD >= float(c.get("hazard", INF)) - brawl.sudden_death_speed * t:
			danger |= 1
		if danger & 1 != 0:
			res["dead"] = true
			break
		if danger & 2 != 0:
			res["spring"] = true
		if danger & 4 != 0:
			res["trap"] = true
		var box_pos: Vector2 = c["box_pos"]
		if box_pos.is_finite() and me.pos.distance_to(box_pos) <= me.rad + BrawlItems.PICK_REACH - 2.0:
			res["box"] = true
		if foe_on:
			var d := me.pos - op.pos
			var dist := maxf(d.length(), 0.01)
			var gap := dist - me.rad - op.rad
			res["min_gap"] = minf(res["min_gap"], gap)
			if gap <= 1.0:
				var above := -d.y / dist
				if above > 0.6 and me.air and me.vel.y >= ball.stomp_speed:
					if float(c["foe_invuln"]) <= t:
						res["stomp_opp"] = t
					break
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
	res["t_end"] = t
	res["end"] = me.pos
	res["end_opp"] = op.pos
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
		for off in [-m, 0.0, m]:
			if not _ground_ok(end.x + off, end.y, me.rad):
				res["edge"] = true
	return res


func _score(res: Dictionary) -> float:
	if res["dead"]:
		return -1000.0
	var s := 0.0
	var e: Vector2 = res["end"]
	var o: Vector2 = res["end_opp"]
	var bold: bool = brawl.stall_active
	if brawl.sudden_death_active:
		s -= HIGH_WEIGHT * e.y
	if res["stomp_opp"] >= 0.0:
		s += (750.0 if bold else 500.0) - 30.0 * res["stomp_opp"]
	if res["stomp_me"] >= 0.0:
		s -= 180.0 if bold else 450.0
	if res["trap"]:
		s -= 350.0
	if res["spring"]:
		s -= 400.0
	if res["edge"]:
		s -= 120.0
	if res["bonk"]:
		s -= 100.0
	if res["box"] and brawl.items.held[player_index] == "":
		s += 260.0 if mode == "get_box" else 120.0
	match mode:
		"flee":
			s += minf(e.distance_to(o), 520.0)
			s -= 150.0 * clampf((110.0 - minf(e.x, _cols * TILE - e.x)) / 110.0, 0.0, 1.0)
			if res["bump"] or res["min_gap"] <= 3.0:
				s -= 250.0
		"pass_bomb":
			s -= e.distance_to(o)
			if res["bump"] or res["min_gap"] <= 3.0:
				s += 350.0
		"get_box":
			s -= _path_cost(e, e.distance_to(_box_pos))
		_:
			var dy := e.y - o.y
			s -= _path_cost(e, 0.7 * absf(absf(e.x - o.x) - 80.0) + 0.9 * (absf(dy) + maxf(dy, 0.0)))
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
	if _graph_done and (mode == "chase" or mode == "get_box"):
		var goal_pos: Vector2 = _box_pos if mode == "get_box" else foe_pos
		var g := _high_goal() if brawl.sudden_death_active else _node_below(goal_pos)
		if g >= 0:
			if g != _goal_node:
				_goal_node = g
				_gdist = _goal_hops(g)
			_graph_usable = true
	_queue =[[0, -1.0], [0, 0.5]]
	for dir in [-1, 1]:
		for amount in CANDIDATE_CHARGES:
			_queue.append([dir, amount])
	_results.clear()
	_think_frames = 0
	phase = "think"
	thoughts += 1


func _snapshot() -> void:
	var view := _foe_view()
	var foe_pos: Vector2 = view[1]
	_dyn_spikes.clear()
	for s in brawl.stall_spikes:
		if is_instance_valid(s):
			_dyn_spikes.append(Rect2(s.position.x - SPIKE_W / 2.0, s.position.y - SPIKE_H, SPIKE_W, SPIKE_H))
	for col in brawl.upcoming_stall_columns(2):
		_dyn_spikes.append(Rect2(col * TILE + (TILE - SPIKE_W) / 2.0, (brawl.floor_row() + 1) * TILE - SPIKE_H, SPIKE_W, SPIKE_H))
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
	}
	_ctx["t_contact"] = _time_to_contact()


func _time_to_contact() -> float:
	var b := SimBody.new()
	b.pos = ball.global_position
	b.vel = ball.linear_velocity
	b.rad = ball.radius
	var g: float = _ctx["g_me"]
	for i in 90:
		if _advance(b, g) == HIT_LAND:
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
		var best := 560.0
		for box in brawl.items.boxes:
			if not is_instance_valid(box):
				continue
			var d: float = box.position.distance_to(ball.global_position)
			if d < best and box.position.distance_to(foe_pos) > 120.0:
				best = d
				_box_pos = box.position
		if _box_pos.is_finite():
			return "get_box"
	return "chase"


func _think_step() -> void:
	_think_frames += 1
	for n in EVALS_PER_FRAME:
		if _queue.is_empty():
			break
		var cand: Array = _queue.pop_front()
		var res := _evaluate(cand[0], cand[1])
		_results.append({"dir": cand[0], "charge": cand[1], "res": res, "score": _score(res)})
	if _queue.is_empty():
		_choose()


func _choose() -> void:
	var wait_res: Dictionary = _results[0]["res"]
	_threat = wait_res["stomp_me"] >= 0.0
	if _threat and mode == "chase":
		mode = "dodge"
	var noise := (1.5 - skill) * 18.0
	var ranked: Array = []
	for r in _results:
		var is_hop: bool = r["charge"] >= 0.0
		ranked.append([float(r["score"]) + randf_range(-noise, noise) - (6.0 if is_hop else 0.0), r])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if randf() < (1.0 - skill) * 0.06:
		var pick: Array = ranked[randi() % ranked.size()]
		if pick[1]["charge"] >= 0.0 and not pick[1]["res"]["dead"]:
			ranked.push_front(pick)
	if _celebrate:
		_celebrate = false
		ranked.push_front([0.0, _results[1]])
	var strict := _since_hop < RELAX_AFTER and not brawl.stall_active
	var sigma := (0.02 + 0.12 * (1.0 - skill)) * (1.0 if strict else CAREFUL_SCALE)
	var best: Dictionary = _results[0]
	var checks := 0
	for item in ranked:
		var r: Dictionary = item[1]
		if r["charge"] < 0.0:
			best = r
			break
		if r["res"]["dead"]:
			continue
		if r["dir"] == 0:
			best = r
			break
		if checks >= 6:
			continue
		checks += 1
		if _robust(r["dir"], r["charge"], 1.5 * _jump_sigma(sigma, r["charge"]), strict):
			best = r
			break
	_think_cd = lerpf(0.30, 0.03, skill)
	phase = "idle"
	if best["charge"] < 0.0:
		last_choice = "wait score=%d mode=%s" % [best.get("score", 0), mode]
		return
	var dir: int = best["dir"]
	var amount: float = best["charge"]
	if dir != 0:
		var s := _jump_sigma(sigma, amount)
		amount = clampf(amount + clampf(randfn(0.0, s), -1.5 * s, 1.5 * s), 0.0, 1.0)
	_plan_end = best["res"]["end"]
	last_choice = "dir=%d charge=%.2f score=%d mode=%s" % [dir, amount, best["score"], mode]
	_plan_dir = dir
	_hold_frames = 0 if dir == 0 else maxi(1, roundi(amount * ball.charge_time * 60.0))
	var res: Dictionary = best["res"]
	_delay_frames = maxi(0, roundi(float(res["delay"]) * 60.0) - _think_frames)
	phase = "prep"


func _jump_sigma(sigma: float, charge: float) -> float:
	return sigma * (0.3 + charge)


func _robust(dir: int, charge: float, err: float, strict := true) -> bool:
	_extra_skin = SAFETY_SKIN
	var safe := true
	for amount in [maxf(0.0, charge - err), charge, minf(1.0, charge + err)]:
		var res := _evaluate(dir, amount)
		if res["dead"] or res["spring"] or (strict and res["edge"]):
			safe = false
			break
	_extra_skin = 0.0
	return safe


func _start_charge() -> void:
	if _plan_dir == 0:
		_jump_now()
		return
	_press(_key(_plan_dir))


func _launch_is_safe() -> bool:
	_snapshot()
	var real_dir := ball.charge_dir if _plan_dir != 0 else 0
	var amount := ball.charge if real_dir != 0 else ball.straight_jump
	_extra_skin = SAFETY_SKIN
	var safe := true
	for delta in [-LAUNCH_CHECK_ERR, 0.0, LAUNCH_CHECK_ERR]:
		var res := _evaluate(real_dir, clampf(amount + delta, 0.0, 1.0), true)
		if res["dead"] or res["spring"] or (res["bonk"] and res["edge"]):
			safe = false
			break
	_extra_skin = 0.0
	return safe


func _jump_now() -> void:
	if not _launch_is_safe():
		for key in [_act("left"), _act("right")]:
			_release(key)
		aborts += 1
		phase = "idle"
		_think_cd = 0.0
		return
	for key in [_act("left"), _act("right")]:
		if _down.has(key):
			_pulses[key] = 3
	_pulse(_act("jump"))
	predicted_end = _plan_end
	last_jump = "from=%s plan_dir=%d real_dir=%d rev=%s charge=%.2f pred=%s vel=%s ground=%s" % [ball.global_position.round(), _plan_dir, ball.charge_dir, ball.reverse_controls, ball.charge, _plan_end.round(), ball.linear_velocity.round(), ball.on_ground]
	_launched = false
	_launch_wait = 40
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
