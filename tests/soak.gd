extends Node

var rng := RandomNumberGenerator.new()
var _hold := 0
var _dir := "right"


func _ready() -> void:
	Game.save_enabled = false
	rng.seed = 12345
	for run in 6:
		var e: Node = load("res://scenes/endless.tscn").instantiate()
		add_child(e)
		await _frames(20)
		var stuck_x: float = e.ball.global_position.x
		var stuck_frames := 0
		var deaths_fast := 0
		var last_lives: int = e.lives
		var last_death_frame := -1000
		for f in 6000:
			_bot_input(0.9)
			await _frames(1)
			if e._over:
				break
			if e.lives < last_lives:
				if f - last_death_frame < 110:
					deaths_fast += 1
				last_death_frame = f
			last_lives = e.lives
			var p: Vector2 = e.ball.global_position
			if is_nan(p.x) or p.y < -1500.0:
				print("ANOMALY endless run %d: ball out of bounds %s" % [run, p])
				break
			if absf(p.x - stuck_x) > 64.0:
				stuck_x = p.x
				stuck_frames = 0
			else:
				stuck_frames += 1
		_release_all()
		print("endless run %d: score %d, segments %d, boss arenas %d, lives %d, chunks %d, chain deaths %d" % [
			run, int(e.score), e.segments_passed, e.boss_arenas_built, e.lives, e.chunks.size(), deaths_fast])
		if deaths_fast > 0:
			print("ANOMALY endless run %d: died again right after respawning %d time(s)" % [run, deaths_fast])
		e.queue_free()
		await _frames(3)

	for i in LevelData.LEVELS.size():
		Game.level_index = i
		var play: Node = load("res://scenes/play.tscn").instantiate()
		add_child(play)
		await _frames(20)
		var best_x := 0.0
		var chain := 0
		var last_lives2: int = play.lives
		var last_death := -1000
		var deaths := 0
		for f in 4000:
			play.lives = maxi(play.lives, 50)
			_bot_input(0.8)
			await _frames(1)
			if play._busy and play.hud._panel != null:
				break
			if play.lives < last_lives2:
				deaths += 1
				if f - last_death < 110:
					chain += 1
				last_death = f
			last_lives2 = play.lives
			var p: Vector2 = play.ball.global_position
			best_x = maxf(best_x, p.x)
			if is_nan(p.x) or p.x < -64.0 or p.x > play.level.size.x + 64.0 or p.y < -1500.0:
				print("ANOMALY level %d: ball out of bounds %s" % [i + 1, p])
				break
		_release_all()
		print("level %d: reached x=%.0f of %.0f, deaths %d, chain deaths %d, finished %s" % [
			i + 1, best_x, play.level.size.x, deaths, chain, play.hud._panel != null])
		if chain > 0:
			print("ANOMALY level %d: died again right after respawning %d time(s)" % [i + 1, chain])
		play.queue_free()
		await _frames(3)
	print("SOAK DONE")
	get_tree().quit()


func _bot_input(right_bias: float) -> void:
	Input.action_release("jump")
	Input.action_release("shoot")
	if _hold > 0:
		_hold -= 1
		if _hold == 0:
			Input.action_press("jump")
			await get_tree().physics_frame
			Input.action_release(_dir)
		return
	if rng.randf() < 0.15:
		_dir = "right" if rng.randf() < right_bias else "left"
		Input.action_press(_dir)
		_hold = rng.randi_range(4, 40)
	if rng.randf() < 0.05:
		Input.action_press("shoot")


func _release_all() -> void:
	for a in ["left", "right", "jump", "shoot"]:
		Input.action_release(a)
	_hold = 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
