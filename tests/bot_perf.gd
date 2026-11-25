extends Node

const FIRST_FRAME := 60
const LAST_FRAME := 1200


func _ready() -> void:
	Game.save_enabled = false
	for arena in BrawlData.ARENAS.size():
		for config in [["2P", false, true], ["vs bot, no events/items", true, false], ["vs bot, events + items", true, true]]:
			await _measure(arena, config[0], config[1], config[2])
	get_tree().quit()


func _pct(sorted: Array[float], p: float) -> float:
	return sorted[mini(sorted.size() - 1, int(sorted.size() * p))]


func _measure(arena: int, tag: String, vs_bot: bool, live: bool) -> void:
	Game.brawl_vs_bot = vs_bot
	var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
	br.arena_index = arena
	add_child(br)
	Game.brawl_vs_bot = false
	br.events.enabled = live
	br.items.enabled = live
	var total_frames: Array[float] = []
	var bot_frames: Array[float] = []
	for f in LAST_FRAME:
		await get_tree().physics_frame
		if f >= FIRST_FRAME:
			total_frames.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			bot_frames.append(br.bot.last_tick_usec / 1000.0 if br.bot != null else 0.0)
	var total_sum := 0.0
	for v in total_frames:
		total_sum += v
	var bot_sum := 0.0
	for v in bot_frames:
		bot_sum += v
	total_frames.sort()
	bot_frames.sort()
	print("arena %d (%s) %-24s avg %.2f ms  median %.2f  p95 %.2f  max %.2f   [bot alone: avg %.2f  median %.2f  p95 %.2f  p99 %.2f  worst %.2f ms]" % [
		arena, br.arena_name, tag, total_sum / total_frames.size(), _pct(total_frames, 0.5), _pct(total_frames, 0.95), total_frames[-1],
		bot_sum / bot_frames.size(), _pct(bot_frames, 0.5), _pct(bot_frames, 0.95), _pct(bot_frames, 0.99), bot_frames[-1]])
	if br.bot != null:
		br.bot.release_all()
	br.queue_free()
	for i in 200:
		await get_tree().physics_frame
