extends Node

const MATCH_LIMIT := 60 * 600
const IDLE_LIMIT := 95.0
const MATCHES := [
	[0, 0.6, 0.6], [1, 0.6, 0.6], [0, 0.6, 0.6], [1, 0.6, 0.6], [0, 0.6, 0.6], [1, 0.6, 0.6],
	[0, 0.3, 0.9], [1, 0.9, 0.3], [0, 0.2, 0.9], [1, 0.9, 0.2],
]

var anomalies := 0
var _totals := {}
var _item_totals := {}
var _event_totals := {}
var _wins := [0, 0]
var _skill_wins := {}


func _ready() -> void:
	Game.save_enabled = false
	var total_seconds := 0.0
	var finished := 0
	for m in MATCHES.size():
		var cfg: Array = MATCHES[m]
		var result := await _play_match(m, cfg[0], cfg[1], cfg[2])
		if result["finished"]:
			finished += 1
			total_seconds += result["seconds"]
	var avg := total_seconds / maxf(1.0, finished)
	print("---- summary ----")
	print("matches %d, finished %d, bot P1 wins %d, bot P2 wins %d, average duration %.1f s" % [MATCHES.size(), finished, _wins[0], _wins[1], avg])
	print("points by cause: %s" % str(_totals))
	print("items used: %s" % str(_item_totals))
	print("events seen: %s" % str(_event_totals))
	print("wins by skill: %s" % str(_skill_wins))
	print("anomalies: %d" % anomalies)
	print("BRAWL SOAK DONE")
	get_tree().quit()


func _play_match(index: int, arena: int, skill1: float, skill2: float) -> Dictionary:
	Game.brawl_vs_bot = true
	var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
	br.arena_index = arena
	br.intro_seconds = 0.3
	br.win_panel_delay = 0.2
	add_child(br)
	var bot2: BrawlBot = br.bot
	bot2.skill = skill2
	var bot1 := BrawlBot.new()
	bot1.name = "Bot1"
	bot1.player_index = 0
	bot1.skill = skill1
	br.add_child(bot1)
	var causes := {}
	var events_seen := {}
	var items_used := {}
	br.point_scored.connect(func(_s: Ball, _v: Ball, cause: String) -> void: causes[cause] = causes.get(cause, 0) + 1)
	br.events.event_started.connect(func(id: String) -> void: events_seen[id] = events_seen.get(id, 0) + 1)
	br.items.item_used.connect(func(_b: Ball, id: String) -> void: items_used[id] = items_used.get(id, 0) + 1)
	var frames := 0
	var last_change := 0
	var last_total := 0
	var max_gap := 0
	var outside := 0
	while frames < MATCH_LIMIT:
		await get_tree().physics_frame
		frames += 1
		if br.winner != null:
			break
		if not br.match_running:
			last_change = frames
			continue
		var total: int = br.scores[0] + br.scores[1]
		if total != last_total:
			last_total = total
			max_gap = maxi(max_gap, frames - last_change)
			last_change = frames
		for ball in br.balls:
			var p := ball.global_position
			if not ball.dead and (p.x < -20.0 or p.x > br.arena_rect.size.x + 20.0 or p.y < -60.0 or p.y > br.arena_rect.size.y + 120.0):
				outside += 1
	max_gap = maxi(max_gap, frames - last_change)
	var finished := br.winner != null
	var seconds := frames / 60.0
	var tag := "match %d (%s, skill %.1f vs %.1f)" % [index + 1, br.arena_name, skill1, skill2]
	if finished:
		var wi := br.balls.find(br.winner)
		_wins[wi] += 1
		var key := "%.1f" % (skill1 if wi == 0 else skill2)
		_skill_wins[key] = _skill_wins.get(key, 0) + 1
		print("%s: winner P%d, score %d-%d, %.1f s (longest quiet %.0f s), points by cause %s, items used %s, events %s" % [
			tag, wi + 1, br.scores[0], br.scores[1], seconds, max_gap / 60.0, str(causes), str(items_used), str(events_seen)])
	else:
		print("%s: DID NOT FINISH after %.0f s, score %d-%d" % [tag, seconds, br.scores[0], br.scores[1]])
		print("ANOMALY %s: match did not finish" % tag)
		anomalies += 1
	if outside > 0:
		print("ANOMALY %s: a live ball was outside the arena for %d frames" % [tag, outside])
		anomalies += 1
	if max_gap > int(IDLE_LIMIT * 60.0):
		print("ANOMALY %s: no score change for %.0f s (a player stuck alive?)" % [tag, max_gap / 60.0])
		anomalies += 1
	if not bot1.held_actions().is_empty() or not bot2.held_actions().is_empty():
		print("ANOMALY %s: a bot still holds keys after the match: %s %s" % [tag, bot1.held_actions(), bot2.held_actions()])
		anomalies += 1
	for k in causes:
		_totals[k] = _totals.get(k, 0) + causes[k]
	for k in items_used:
		_item_totals[k] = _item_totals.get(k, 0) + items_used[k]
	for k in events_seen:
		_event_totals[k] = _event_totals.get(k, 0) + events_seen[k]
	br.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return {"finished": finished, "seconds": seconds}
