extends Node
## Kiểm tra tự động các cơ chế. Chạy trong thư mục project:
##   godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
## Không dùng --headless và thêm `-- --shots=<thư mục>` để lưu ảnh toàn cảnh từng màn.

var failures := 0
var shots_dir := ""
var hurts := 0


## Chạy lần lượt các kiểm tra; in "ok" hoặc "FAIL" cho từng mục.
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
	Game.save_enabled = false                      # không ghi đè file lưu thật của người chơi

	# --- Menu ---
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(3)
	_expect(menu.level_grid.get_child_count() == LevelData.LEVELS.size() + 1, "menu has Endless + one button per level")
	await _shot("00_menu")
	menu.queue_free()

	# --- Từng màn dựng được, bóng đứng trên đất, có 3 sao và đích ---
	for i in LevelData.LEVELS.size():
		var level := _make_level(LevelData.LEVELS[i]["map"])
		var ball := _make_ball(level, level.start_position)
		await _frames(40)
		_expect(ball.on_ground, "level %d: ball lands at the start" % (i + 1))
		_expect(level.star_total == 3, "level %d: has 3 stars" % (i + 1))
		var has_finish := false
		for c in level.get_children():
			if c is Pickup and c.kind == "finish":
				has_finish = true
		_expect(has_finish, "level %d: has a finish flag" % (i + 1))
		if shots_dir != "":
			var cam := Camera2D.new()
			add_child(cam)
			var z := minf(1280.0 / level.size.x, 720.0 / level.size.y)
			cam.zoom = Vector2(z, z)
			cam.global_position = level.size / 2.0
			cam.make_current()
			await _frames(30)
			await _shot("level_%d_overview" % (i + 1))
			cam.queue_free()
		level.queue_free()
		await _frames(2)

	# --- Các đoạn vô tận đúng quy tắc ghép nối ---
	for seg in [{"name": "Start", "map": SegmentData.START}] + SegmentData.SEGMENTS:
		var rows: PackedStringArray = []
		for line in String(seg["map"]).split("
"):
			if line.strip_edges() != "":
				rows.append(line)
		var ok := rows.size() == 18 and rows[15][2] == "O"
		for r in rows.size():
			for c in [0, 1, 2, 3, rows[r].length() - 4, rows[r].length() - 3, rows[r].length() - 2, rows[r].length() - 1]:
				var want := "#" if r >= 16 else "."
				if rows[r][c] != want and not (r == 15 and c == 2):
					ok = false
		var map_text: String = seg["map"]
		for bad in ["x", "a", "b", "d", "A", "B", "D", "F", "K", "M", "G"]:
			if bad in map_text:
				ok = false
		_expect(ok, "segment '%s': 18 rows, O at column 2, flat joinable ends, no crates/doors" % seg["name"])

	# --- Giữ D: nghiêng phải, bấm nhảy: nhảy lên bên phải ---
	var flat := "#..........................#\n#..........................#\n#..........................#\n#..O.......................#\n############################"
	var lv := _make_level(flat)
	var b := _make_ball(lv, lv.start_position)
	await _frames(60)
	var x0 := b.global_position.x
	Input.action_press("right")
	await _frames(20)
	_expect(b.charge_dir == 1 and b.charge > 0.3 and b.tilt > 0.1, "holding D charges and tilts right (charge %.2f)" % b.charge)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	Input.action_release("right")
	await _frames(10)
	_expect(b.global_position.x > x0 + 30 and b.linear_velocity.y < 0.0, "holding D then pressing jump jumps up-right")
	var vy_before := b.linear_velocity.y
	b.jump(1, 1.0)                              # đang bay: không nhảy thêm được
	await _frames(2)
	_expect(b.linear_velocity.y >= vy_before, "cannot jump again in mid-air")
	lv.queue_free()
	await _frames(2)

	# --- Giữ A: nhảy sang trái ---
	lv = _make_level(flat)
	b = _make_ball(lv, lv.start_position + Vector2(400, 0))
	await _frames(60)
	x0 = b.global_position.x
	Input.action_press("left")
	await _frames(15)
	Input.action_release("left")                   # thả A mà không bấm nhảy: hủy
	await _frames(20)
	_expect(b.on_ground and absf(b.global_position.x - x0) < 4.0 and b.charge_dir == 0, "letting go of A without jumping cancels the jump")
	Input.action_press("left")
	await _frames(15)
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	Input.action_release("left")
	await _frames(10)
	_expect(b.global_position.x < x0 - 20, "holding A then pressing jump jumps left")
	await _frames(90)
	x0 = b.global_position.x
	Input.action_press("jump")                     # không giữ A/D: nhảy thẳng lên
	await _frames(1)
	Input.action_release("jump")
	await _frames(10)
	_expect(b.linear_velocity.y < 0.0 and absf(b.global_position.x - x0) < 3.0, "jump without A/D goes straight up")
	lv.queue_free()
	await _frames(2)

	# --- Rơi xuống nảy như bóng thật: các lần nảy thấp dần rồi đứng yên ---
	lv = _make_level("#.....#\n" .repeat(8) + "#..O..#\n#######")
	b = _make_ball(lv, Vector2(112, 40))
	var ground := lv.size.y - 32.0 - b.radius
	var peaks: Array[float] = []
	var falling := true
	var top := 0.0
	for i in 360:
		await _frames(1)
		if falling and b.linear_velocity.y < -1.0:
			falling = false
			top = b.global_position.y
		elif not falling:
			top = minf(top, b.global_position.y)
			if b.linear_velocity.y > 1.0:
				falling = true
				peaks.append(ground - top)
	_expect(peaks.size() >= 2 and peaks[0] > peaks[1] and peaks[0] > 30.0, "landing bounces lower and lower (%s px)" % str(peaks.slice(0, 4)))
	_expect(b.on_ground and absf(b.linear_velocity.y) < 5.0, "then comes to rest")
	lv.queue_free()
	await _frames(2)

	# --- Dẫm quái từ trên: quái chết, bóng không bị thương ---
	lv = _make_level("#...........#\n#....O......#\n#...........#\n#...........#\n#....e......#\n#############")
	b = _make_ball(lv, lv.start_position)
	await _frames(60)
	_expect(hurts == 0 and _count(lv, Enemy) == 0, "stomping an enemy from above squashes it")
	lv.queue_free()
	await _frames(2)

	# --- Quái đi tới đụng ngang: bóng bị thương ---
	hurts = 0
	lv = _make_level("#..............#\n#..O.......e...#\n################")
	b = _make_ball(lv, lv.start_position)
	await _frames(420)
	_expect(hurts > 0, "walking enemy hurts the ball from the side")
	lv.queue_free()
	await _frames(2)

	# --- Gai ---
	hurts = 0
	lv = _make_level("#.....#\n#..O..#\n#.....#\n#..^..#\n#######")
	b = _make_ball(lv, lv.start_position)
	await _frames(40)
	_expect(hurts > 0, "spikes hurt the ball")
	lv.queue_free()
	await _frames(2)

	# --- Thùng rơi lên nút thì cửa mở ---
	lv = _make_level("#.........#\n#..x......#\n#.........#\n#..a...A..#\n##########")
	await _frames(60)
	var door: Door = _first(lv, Door)
	_expect(door.is_open, "crate on a button opens the matching door")
	lv.queue_free()
	await _frames(2)

	# --- Bệ di chuyển ---
	lv = _make_level("#..........#\n#.===...>..#\n#..........#")
	var plat: MovingPlatform = _first(lv, MovingPlatform)
	var px := plat.position.x
	await _frames(90)
	_expect(plat.position.x > px + 40, "moving platform travels toward its > marker")
	lv.queue_free()
	await _frames(2)

	# --- Lò xo ---
	lv = _make_level("#.....#\n#..O..#\n#.....#\n#.....#\n#..T..#\n#######")
	b = _make_ball(lv, lv.start_position)
	var lowest_vy := 0.0
	for i in 60:
		await _frames(1)
		lowest_vy = minf(lowest_vy, b.linear_velocity.y)
	_expect(lowest_vy < -800, "trampoline launches the ball high (vy=%.0f)" % lowest_vy)
	lv.queue_free()
	await _frames(2)

	# --- Bập bênh nghiêng khi bóng rơi lên một đầu ---
	lv = _make_level("#.........#\n#.....O...#\n#.........#\n#.........#\n#....S....#\n#.........#\n###########")
	b = _make_ball(lv, lv.start_position + Vector2(40, 0))
	await _frames(60)
	var saw: Seesaw = _first(lv, Seesaw)
	_expect(absf(saw.plank.rotation) > 0.15, "seesaw tilts under the ball (%.2f rad)" % saw.plank.rotation)
	_expect(absf(saw.plank.rotation) < deg_to_rad(saw.max_tilt_deg + 4.0), "seesaw stops at its max tilt (%.1f deg)" % rad_to_deg(saw.plank.rotation))
	lv.queue_free()
	await _frames(2)

	# --- Thùng về chỗ cũ khi gọi reset (dùng khi hồi sinh) ---
	lv = _make_level("#..........#
#..x.......#
############")
	await _frames(30)
	var crate: Crate = _first(lv, Crate)
	var home := crate.global_position
	crate.apply_central_impulse(Vector2(400, 0))
	await _frames(40)
	var moved := crate.global_position.distance_to(home)
	lv.reset_crates()
	await _frames(5)
	_expect(moved > 20.0 and crate.global_position.distance_to(home) < 4.0, "crates go back home on reset (moved %.0f px)" % moved)
	lv.queue_free()
	await _frames(2)

	# --- Dốc: là mặt đất thật (đáp lên được), dốc đứng thì trượt xuống ---
	hurts = 0
	lv = _make_level("#........#
#..O.....#
#........#
#..12##..#
##########")
	b = _make_ball(lv, Vector2(144, 80))            # thả nhẹ ngay trên nửa cao của dốc thoải (ô "2")
	await _frames(15)
	_expect(b.on_ground and b.global_position.y < 100.0, "a gentle slope is solid ground (y=%.0f)" % b.global_position.y)
	lv.queue_free()
	await _frames(2)
	lv = _make_level("#........#
#..O.....#
#........#
#../##...#
##########")
	b = _make_ball(lv, lv.start_position)
	await _frames(150)
	_expect(b.global_position.x < lv.start_position.x - 10.0, "ball slides down a steep slope")
	lv.queue_free()
	await _frames(2)

	# --- Trái tim, khiên ---
	var hearts := [0]
	lv = _make_level("#.....#
#..O..#
#.....#
#..+..#
#######")
	lv.heart_collected.connect(func() -> void: hearts[0] += 1)
	b = _make_ball(lv, lv.start_position)
	await _frames(40)
	_expect(hearts[0] == 1, "touching a heart sends heart_collected")
	lv.queue_free()
	await _frames(2)
	hurts = 0
	lv = _make_level("#.....#
#..O..#
#..h..#
#.....#
#.....#
#..^..#
#######")
	b = _make_ball(lv, lv.start_position)
	await _frames(50)
	_expect(hurts == 0 and not b.has_shield and b.invuln > 0.0, "shield absorbs a spike hit")
	lv.queue_free()
	await _frames(2)

	# --- Jump boost: nhặt mũi tên xanh thì nhảy cao hơn ---
	lv = _make_level("#.....#
" .repeat(10) + "#..O..#
#..j..#
#######")
	b = _make_ball(lv, lv.start_position)
	await _frames(40)
	_expect(b.boost_time > 0.0, "touching the green arrows gives jump boost")
	var boosted := b.jump_velocity(0, 0.5).length()
	b.boost_time = 0.0
	var normal := b.jump_velocity(0, 0.5).length()
	_expect(boosted > normal * 1.2, "jump boost makes jumps stronger (%.0f vs %.0f)" % [boosted, normal])
	b.give_jump_boost()
	await _frames(30)
	var y_start := b.global_position.y
	var top_y := y_start
	b.jump(0, 0.5)
	for k in 60:
		await _frames(1)
		top_y = minf(top_y, b.global_position.y)
	_expect(y_start - top_y > 160.0, "boosted straight jump goes higher than 5 tiles (%.0f px)" % (y_start - top_y))
	lv.queue_free()
	await _frames(2)

	# --- Súng: nhặt được đạn, bắn hạ quái ---
	lv = _make_level("#..............#
#..O...........#
#..g........e..#
################")
	b = _make_ball(lv, lv.start_position)
	await _frames(30)
	_expect(b.ammo == 15, "gun pickup gives 15 ammo")
	b.facing = 1
	b.shoot()
	await _frames(40)
	_expect(b.ammo == 14 and _count(lv, Enemy) == 0, "a bullet kills an enemy")
	lv.queue_free()
	await _frames(2)

	# --- Boss: chỉ lăn trên mặt đất; đụng ngang thì bị thương; dẫm đầu / bắn thì mất máu; hết máu thì cổng mở ---
	hurts = 0
	lv = _make_level("#..............................#
#..............................#
#..............................#
#..O..............M.......G....#
################################")
	var boss_events := [0, 0]
	lv.boss_started.connect(func(_x) -> void: boss_events[0] += 1)
	lv.boss_defeated.connect(func(_x) -> void: boss_events[1] += 1)
	b = _make_ball(lv, lv.start_position)
	await _frames(20)
	var boss: Boss = _first(lv, Boss)
	var ground_y := lv.size.y - 32.0
	_expect(absf(boss.global_position.y - (ground_y - boss.radius)) < 2.0, "boss sits on the ground")
	_expect(boss.state != Boss.State.SLEEP and boss_events[0] == 1, "boss wakes up when the player is near")
	var boss_ys := []
	for k in 400:
		await _frames(1)
		boss_ys.append(boss.global_position.y)
		if hurts > 0:
			break
	_expect(boss_ys.max() - boss_ys.min() < 1.0, "boss never leaves the ground (only rolls)")
	_expect(hurts > 0, "rolling into the player hurts the player")
	var hp0 := boss.hp
	var shot: Node2D = load("res://scenes/objects/player_bullet.tscn").instantiate()
	shot.direction = Vector2.RIGHT
	shot.position = boss.position - Vector2(80, 0)
	lv.add_child(shot)
	await _frames(8)
	_expect(boss.hp == hp0 - 1, "a horizontal bullet hits the boss")
	b.invuln = 0.0
	b.teleport(boss.global_position + Vector2(0, -110))   # thả người chơi rơi lên đầu boss
	boss.state = Boss.State.DIZZY
	boss._timer = 5.0
	hurts = 0
	var hp1 := boss.hp
	await _frames(30)
	_expect(boss.hp == hp1 - 1 and hurts == 0, "stomping the boss's head damages it without hurting the player")
	boss.take_damage(boss.hp)
	await _frames(30)
	var gate: Door = _first(lv, Door)
	_expect(boss_events[1] == 1 and gate.is_open and not is_instance_valid(boss), "defeating the boss opens gate G")
	lv.queue_free()
	await _frames(2)

	# --- Thanh máu boss trên HUD (màn Boss Arena) ---
	Game.level_index = LevelData.LEVELS.size() - 1
	var arena: Node = load("res://scenes/play.tscn").instantiate()
	add_child(arena)
	await _frames(10)
	arena.ball.teleport(Vector2(500, arena.level.start_position.y))
	await _frames(40)
	_expect(arena.hud._boss_max > 0, "HUD shows the boss health bar")
	await _shot("14_boss_arena")
	arena.queue_free()
	await _frames(2)

	# --- Chế độ vô tận: dựng đoạn phía trước, xóa đoạn đã qua, điểm, hệ số nhân, sao, thua ---
	var endless: Node = load("res://scenes/endless.tscn").instantiate()
	add_child(endless)
	await _frames(20)
	_expect(endless.chunks.size() >= 2 and endless._end_x > endless.ball.global_position.x + 2000.0, "endless builds segments ahead of the player")
	var first_chunk: Level = endless.chunks[0]
	for k in 7:                                    # nhảy cóc tới đầu đoạn xa nhất vài lần
		var far: Level = endless.chunks[-1]
		endless.ball.teleport(far.position + far.start_position)
		await _frames(12)
	_expect(endless.segments_passed >= 5 and endless.multiplier >= 2, "passing segments raises the multiplier (passed %d, x%d)" % [endless.segments_passed, endless.multiplier])
	_expect(endless.score > 300.0, "distance adds score (%d)" % int(endless.score))
	_expect(not is_instance_valid(first_chunk) or first_chunk.is_queued_for_deletion(), "old segments behind the player are removed")
	_expect(endless.boss_arenas_built >= 1, "a boss arena is inserted after %d segments" % endless.BOSS_EVERY)
	await _shot("12_endless")
	var score_before: float = endless.score
	endless.chunks[-1].collect_star()
	_expect(endless.stars == 1 and endless.score >= score_before + 25.0, "a star counts and adds points")
	for k in 3:
		endless._on_ball_hurt()
		await get_tree().create_timer(1.0).timeout
	_expect(endless._over and endless.hud._panel != null, "losing all lives shows game over")
	_expect(Game.best_score >= int(endless.score), "best score is recorded")
	await _shot("13_game_over")
	endless.queue_free()
	await _frames(2)

	# --- Cảnh chơi: bị thương mất mạng rồi hồi sinh; chạm đích hiện bảng qua màn ---
	Game.level_index = 0
	var play: Node = load("res://scenes/play.tscn").instantiate()
	add_child(play)
	await _frames(30)
	await _shot("10_play")
	play.ball.take_hit()
	await _frames(70)
	_expect(play.lives == 2 and not play.ball.dead, "getting hurt costs a life and respawns the ball")
	_expect(play.ball.global_position.distance_to(play.respawn_position) < 20.0, "ball respawns at the start / checkpoint")
	play.level.collect_star()
	_expect(play.stars == 1, "collecting a star counts")
	play.level.reach_checkpoint(Vector2(500, 400))
	_expect(play.respawn_position == Vector2(500, 400), "checkpoint moves the respawn point")
	play.level.finish()
	await _frames(5)
	_expect(play.hud._panel != null and play.hud._panel.visible, "finish shows the level-complete panel")
	await _shot("11_complete")

	print("RESULT: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## Dựng một màn từ bản đồ chữ.
func _make_level(map: String) -> Level:
	var level := Level.new()
	add_child(level)
	level.build(map)
	return level


## Thả bóng vào màn và đếm số lần bị thương.
func _make_ball(level: Level, pos: Vector2) -> Ball:
	var ball: Ball = load("res://scenes/ball.tscn").instantiate()
	ball.position = pos
	level.add_child(ball)
	ball.hurt.connect(func() -> void: hurts += 1)
	return ball


func _first(level: Level, type: Variant) -> Node:
	for c in level.get_children():
		if is_instance_of(c, type):
			return c
	return null


func _count(level: Level, type: Variant) -> int:
	var n := 0
	for c in level.get_children():
		if is_instance_of(c, type) and not c.is_queued_for_deletion() and not (c is Enemy and c.dead):
			n += 1
	return n


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(shots_dir.path_join(shot_name + ".png"))
