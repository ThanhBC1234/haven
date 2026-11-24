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
	_expect(menu.level_grid.get_child_count() == LevelData.LEVELS.size() + 1, "menu grid has Endless + one button per level (BRAWL 2P is its own wide row below the grid)")
	_expect(menu.brawl_button != null and menu.brawl_button.text == "BRAWL 2P" and menu.brawl_button.get_parent() == menu.level_grid.get_parent(), "menu has the BRAWL 2P button")
	var menu_rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var brawl_rect: Rect2 = menu.brawl_button.get_global_rect()
	var tidy := menu_rect.encloses(brawl_rect) and not brawl_rect.intersects(menu.level_grid.get_global_rect()) and not brawl_rect.intersects(menu.help.get_global_rect()) and menu_rect.encloses(menu.quit_button.get_global_rect())
	_expect(tidy, "BRAWL 2P fits the 1280x720 screen and does not overlap the level grid, the help line or Quit (%s)" % brawl_rect)
	_expect(menu.brawl_button.pressed.get_connections().size() >= 1 and Game.has_method("start_brawl") and not Game.brawl_vs_bot, "BRAWL 2P is wired to Game.start_brawl (vs_bot defaults to false)")
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
	b.teleport(boss.global_position + Vector2(0, -110))   # thả người chơi rơi lên đầu boss
	boss.state = Boss.State.DIZZY
	boss._timer = 5.0
	await _frames(3)                              # chờ bóng rời khỏi thân boss rồi mới bỏ miễn sát thương
	b.invuln = 0.0
	hurts = 0
	var hp1 := boss.hp
	await _frames(30)
	_expect(boss.hp == hp1 - 1 and hurts == 0, "stomping the boss's head damages it without hurting the player (hp %d -> %d, hurts %d)" % [hp1, boss.hp, hurts])
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
	_first(arena.level, Boss).queue_free()        # boss bị xóa mà chưa bị hạ (vô tận: đoạn đường phía sau bị dọn)
	await _frames(3)
	_expect(arena.hud._boss_max == 0, "boss health bar disappears when the boss is removed")
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

	# --- Dịch chuyển (hồi sinh) băng qua vực và đất: bóng phải đứng yên ở chỗ mới, không bị kéo ngược về mép vực ---
	lv = _make_level("#..............#\n#..............#\n#..O...........#\n#####....#######\n#####....#######")
	b = _make_ball(lv, Vector2(7 * 32, 0))
	await _frames(25)                             # đang rơi nhanh trong vực
	b.teleport(lv.start_position)
	await _frames(40)
	_expect(b.global_position.distance_to(lv.start_position) < 6.0 and b.on_ground, "teleport across a pit keeps the ball at the target (%s)" % b.global_position)
	lv.queue_free()
	await _frames(2)

	# --- Đứng trên gai khi đang miễn sát thương: hết miễn thì vẫn bị thương ---
	hurts = 0
	lv = _make_level("#.....#\n#..O..#\n#..^..#\n#######")
	b = _make_ball(lv, lv.start_position)
	b.invuln = 0.6
	await _frames(25)
	_expect(hurts == 0, "invulnerable ball is not hurt by spikes")
	await _frames(40)
	_expect(hurts > 0, "spikes hurt a ball still standing on them after invulnerability ends")
	lv.queue_free()
	await _frames(2)

	# --- Quái quay đầu trước gai (không đi xuyên qua bãi gai) ---
	lv = _make_level("#............#\n#.^...e...^..#\n##############")
	var walker: Enemy = _first(lv, Enemy)
	var walk_min := walker.global_position.x
	var walk_max := walker.global_position.x
	for k in 600:
		await _frames(1)
		walk_min = minf(walk_min, walker.global_position.x)
		walk_max = maxf(walk_max, walker.global_position.x)
	_expect(walk_min > 2.5 * 32 and walk_max < 10.5 * 32 and walk_max - walk_min > 64.0, "enemy turns around at spikes (%.0f..%.0f)" % [walk_min, walk_max])
	lv.queue_free()
	await _frames(2)

	# --- Màn 2: nhảy vòng qua cờ lưu vẫn lưu; rơi vực sau cờ thì hồi sinh ở cờ và đứng yên, không rơi tiếp ---
	Game.level_index = 1
	var play2: Node = load("res://scenes/play.tscn").instantiate()
	add_child(play2)
	await _frames(30)
	var flag_x := 0.0
	for c in play2.level.get_children():
		if c is Pickup and c.kind == "checkpoint":
			flag_x = c.global_position.x
	play2.ball.teleport(Vector2(flag_x - 96, 496 - 128))   # bay ngang qua phía trên cờ, cao 4 ô
	await _frames(2)
	play2.ball.linear_velocity = Vector2(420, -150)
	await _frames(40)
	_expect(absf(play2.respawn_position.x - flag_x) < 1.0, "jumping over a checkpoint flag still activates it")
	play2.ball.teleport(Vector2(flag_x + 6 * 32, 520))    # rơi xuống vực ngay sau cờ
	await _frames(240)
	_expect(play2.lives == 2 and not play2.ball.dead, "falling into the pit costs exactly one life")
	_expect(play2.ball.global_position.distance_to(play2.respawn_position) < 6.0 and play2.ball.on_ground,
		"ball respawns on the checkpoint and stays there (%s)" % play2.ball.global_position)
	play2.hud.flash("test", 0.1)
	await _frames(60)
	play2.hud.show_message("Out of lives! Restarting...")
	await _frames(2)
	_expect(play2.hud._message.modulate.a == 1.0, "a message shown after a faded flash is visible")
	play2.queue_free()
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

	await _two_player_checks()                     # nền tảng cho chế độ 2 người chơi
	await _brawl_checks()                          # chế độ đấu 2 người (Bounce Brawl)
	await _brawl_event_checks()                    # sự kiện ngẫu nhiên của chế độ đấu (roulette, 6 sự kiện)

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


## Thả mọi phím (kể cả phím riêng của người chơi 1 và 2) để mục kiểm tra sau không bị dính phím.
func _release_all_keys() -> void:
	for action in Game.KEYS:                          # duyệt mọi hành động đã cài
		Input.action_release(action)                  # thả phím


## Nền tảng 2 người chơi: phím riêng, đảo phím, va chạm bóng-bóng, dẫm, hất, đổi kích thước, dẹt, đạn đẩy lùi, ai nhặt sao.
func _two_player_checks() -> void:
	var flat := "#..........................#\n#..........................#\n#..........................#\n#..O.......................#\n############################"
	var tall := "#......................#\n".repeat(9) + "#..O...................#\n#######################"

	# --- Phím riêng của từng người chơi đã được cài ---
	var all_keys := true
	for action in ["p1_left", "p1_right", "p1_jump", "p1_use", "p2_left", "p2_right", "p2_jump", "p2_use"]:
		all_keys = all_keys and InputMap.has_action(action)
	_expect(all_keys and InputMap.has_action("left") and InputMap.has_action("shoot"), "per-player key actions exist next to the old ones")

	# --- Hai bóng nghe phím riêng, độc lập nhau ---
	var lv := _make_level(flat)
	var a := _make_ball(lv, lv.start_position)
	var b := _make_ball(lv, lv.start_position + Vector2(400, 0))
	a.set_player(1)
	b.set_player(2)
	_expect(a.player_id == 1 and a.action_prefix == "p1_" and b.player_id == 2 and b.action_prefix == "p2_", "set_player sets player_id and the key prefix")
	var s1: Node2D = a.get_node("Sprite")
	var s2: Node2D = b.get_node("Sprite")
	_expect(s1.material == null and s2.material != null and a.modulate.a == 1.0, "player 2 is tinted through the Sprite child, player 1 keeps the original colours")
	await _frames(60)
	var a_x := a.global_position.x
	var b_x := b.global_position.x
	Input.action_press("right")                    # phím đơn: không được điều khiển bóng có tiền tố
	Input.action_press("left")
	await _frames(15)
	_expect(a.charge_dir == 0 and b.charge_dir == 0, "plain left/right do not drive balls that use player keys")
	_release_all_keys()
	await _frames(3)
	Input.action_press("p1_right")
	await _frames(20)
	_expect(a.charge_dir == 1 and a.charge > 0.3 and b.charge_dir == 0, "P1 key charges only ball 1 (%d, %d)" % [a.charge_dir, b.charge_dir])
	Input.action_press("p2_left")
	await _frames(20)
	_expect(a.charge_dir == 1 and b.charge_dir == -1, "P2 key charges ball 2 independently of ball 1")
	Input.action_press("p1_jump")
	await _frames(1)
	Input.action_release("p1_jump")
	Input.action_release("p1_right")
	await _frames(8)
	_expect(a.global_position.x > a_x + 15 and a.linear_velocity.y < 0.0, "P1 jump launches ball 1 up-right")
	_expect(b.on_ground and absf(b.global_position.x - b_x) < 3.0 and b.charge_dir == -1, "ball 2 is unaffected by P1 keys")
	Input.action_press("p2_jump")
	await _frames(1)
	Input.action_release("p2_jump")
	Input.action_release("p2_left")
	await _frames(8)
	_expect(b.global_position.x < b_x - 15 and b.linear_velocity.y < 0.0, "P2 jump launches ball 2 up-left")
	_release_all_keys()
	lv.queue_free()
	await _frames(2)

	# --- Phím "use": chỉ phát tín hiệu, không tự bắn ---
	lv = _make_level(flat)
	a = _make_ball(lv, lv.start_position)
	b = _make_ball(lv, lv.start_position + Vector2(400, 0))
	a.set_player(1)
	a.ammo = 5
	var uses := [0]
	a.use_pressed.connect(func() -> void: uses[0] += 1)
	b.use_pressed.connect(func() -> void: uses[0] += 100)
	b.ammo = 5
	await _frames(30)
	Input.action_press("p1_use")
	await _frames(3)
	_expect(uses[0] == 1 and a.is_use_held() and not b.is_use_held(), "P1 use key emits use_pressed once and is_use_held reports it (%d)" % uses[0])
	_expect(a.ammo == 5, "a ball with player keys does not shoot on its own")
	Input.action_release("p1_use")
	await _frames(3)
	_expect(not a.is_use_held(), "is_use_held is false after release")
	Input.action_press("p2_use")                   # bóng 2 chưa gọi set_player: không phản ứng
	Input.action_press("shoot")                    # bóng 1 có tiền tố: phím bắn đơn không bắn
	await _frames(3)
	_expect(uses[0] == 1 and a.ammo == 5, "use_pressed ignores other players' keys; the plain shoot key does not fire a prefixed ball")
	_release_all_keys()
	b.facing = 1                                   # bóng không tiền tố vẫn bắn bằng phím "shoot" như cũ
	Input.action_press("shoot")
	await _frames(2)
	_expect(b.ammo == 4, "a ball without prefix still shoots with the shoot key")
	_release_all_keys()
	lv.queue_free()
	await _frames(2)

	# --- Đảo phím ---
	lv = _make_level(flat)
	a = _make_ball(lv, lv.start_position)
	await _frames(60)
	a.reverse_controls = true
	Input.action_press("right")
	await _frames(15)
	_expect(a.charge_dir == -1 and a.charge > 0.2, "reverse_controls: holding right charges left")
	a_x = a.global_position.x
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	Input.action_release("right")
	await _frames(10)
	_expect(a.global_position.x < a_x - 15, "reverse_controls: right then jump goes left")
	await _frames(90)
	Input.action_press("left")
	await _frames(10)
	_expect(a.charge_dir == 1, "reverse_controls: holding left charges right")
	_release_all_keys()
	a.reverse_controls = false
	await _frames(3)
	Input.action_press("left")
	await _frames(10)
	_expect(a.charge_dir == -1, "reverse_controls off: left is left again")
	_release_all_keys()
	lv.queue_free()
	await _frames(2)

	# --- Hoán đổi tiền tố phím lúc đang chơi: không kẹt lực tích ---
	lv = _make_level(flat)
	a = _make_ball(lv, lv.start_position)
	b = _make_ball(lv, lv.start_position + Vector2(400, 0))
	a.set_player(1)
	b.set_player(2)
	await _frames(60)
	Input.action_press("p1_right")
	await _frames(20)
	_expect(a.charge_dir == 1 and a.charge > 0.3, "before the swap ball 1 is charging")
	var pa := a.action_prefix
	a.action_prefix = b.action_prefix
	b.action_prefix = pa
	_expect(a.action_prefix == "p2_" and b.action_prefix == "p1_" and a.charge_dir == 0 and a.charge == 0.0, "swapping prefixes drops the old charge at once")
	await _frames(5)
	_expect(a.charge_dir == 0 and b.charge_dir == 1, "after the swap the held P1 key drives the other ball (%d, %d)" % [a.charge_dir, b.charge_dir])
	Input.action_release("p1_right")
	await _frames(5)
	_expect(a.charge_dir == 0 and b.charge_dir == 0, "after releasing nothing is stuck charging")
	a_x = a.global_position.x
	Input.action_press("p2_jump")
	await _frames(1)
	Input.action_release("p2_jump")
	await _frames(6)
	_expect(a.linear_velocity.y < 0.0 and b.on_ground, "after the swap the P2 jump key jumps ball 1")
	_release_all_keys()
	lv.queue_free()
	await _frames(2)

	# --- Bóng chỉ va chạm nhau khi bật ---
	for enabled in [false, true]:
		lv = _make_level(flat)
		a = _make_ball(lv, lv.start_position)
		b = _make_ball(lv, lv.start_position + Vector2(100, 0))
		a.set_collide_with_balls(enabled)
		b.set_collide_with_balls(enabled)
		await _frames(60)
		a.teleport(b.global_position + Vector2(-50, -20))   # bóng 1 lơ lửng bên trái bóng 2, cùng tầm
		await _frames(2)
		a.linear_velocity = Vector2(700, 0)        # rồi lao ngang vào bóng 2 (đang bay nên ma sát đất chưa làm chậm)
		await _frames(30)
		if enabled:
			_expect(a.global_position.x < b.global_position.x, "balls block each other when ball collision is on (%.0f < %.0f)" % [a.global_position.x, b.global_position.x])
		else:
			_expect(a.global_position.x > b.global_position.x + 20.0, "balls pass through each other by default (%.0f > %.0f)" % [a.global_position.x, b.global_position.x])
		lv.queue_free()
		await _frames(2)
	a = load("res://scenes/ball.tscn").instantiate()
	_expect(a.collision_mask == 9, "single-player ball keeps its original collision mask")
	a.set_collide_with_balls(true)
	_expect(a.collision_mask == 11, "set_collide_with_balls(true) adds only the ball layer")
	a.set_collide_with_balls(false)
	_expect(a.collision_mask == 9, "set_collide_with_balls(false) restores the mask")
	a.free()

	# --- Dẫm đầu: stomped phát đúng một lần mỗi lần đáp, đúng nạn nhân ---
	hurts = 0
	lv = _make_level(tall)
	var ground := lv.size.y - 32.0 - 15.0
	b = _make_ball(lv, Vector2(400, ground))
	a = _make_ball(lv, Vector2(404, ground - 160.0))   # lệch vài pixel để không đứng cân bằng trên đỉnh đầu
	a.set_collide_with_balls(true)
	b.set_collide_with_balls(true)
	var stomps: Array[Ball] = []                   # nạn nhân của từng cú dẫm của bóng 1
	var stomps_b := [0]                            # số lần bóng 2 phát stomped
	a.stomped.connect(func(victim: Ball) -> void: stomps.append(victim))
	b.stomped.connect(func(_victim: Ball) -> void: stomps_b[0] += 1)
	await _frames(40)
	_expect(stomps.size() == 1 and stomps[0] == b and stomps_b[0] == 0, "falling onto another ball emits stomped once, naming the victim (%d)" % stomps.size())
	await _frames(240)
	_expect(stomps.size() == 1 and stomps_b[0] == 0, "resting or sliding off the head does not spam stomped (%d)" % stomps.size())
	_expect(hurts == 0, "stomping a ball does not hurt anybody by itself")
	lv.queue_free()
	await _frames(2)
	lv = _make_level(tall)                         # chạm nhẹ (không phải rơi) thì không tính là dẫm
	b = _make_ball(lv, Vector2(400, ground))
	a = _make_ball(lv, Vector2(404, ground - 40.0))
	a.set_collide_with_balls(true)
	b.set_collide_with_balls(true)
	stomps.clear()
	a.stomped.connect(func(victim: Ball) -> void: stomps.append(victim))
	await _frames(120)
	_expect(stomps.size() == 0, "a short drop onto another ball is below the stomp speed threshold")
	lv.queue_free()
	await _frames(2)
	lv = _make_level(tall)                         # bóng bị dẫm từ phía dưới / bên cạnh không phải là dẫm
	b = _make_ball(lv, Vector2(300, ground))
	a = _make_ball(lv, Vector2(364, ground))
	a.set_collide_with_balls(true)
	b.set_collide_with_balls(true)
	await _frames(40)
	stomps.clear()
	a.stomped.connect(func(victim: Ball) -> void: stomps.append(victim))
	b.stomped.connect(func(victim: Ball) -> void: stomps.append(victim))
	b.linear_velocity = Vector2(300, 0)            # hai bóng đụng ngang nhau
	await _frames(40)
	_expect(stomps.size() == 0, "bumping sideways is not a stomp")
	lv.queue_free()
	await _frames(2)

	# --- Hất ---
	lv = _make_level(flat)
	a = _make_ball(lv, lv.start_position)
	await _frames(60)
	a_x = a.global_position.x
	a.knockback(Vector2(300, -200))
	await _frames(12)
	_expect(a.global_position.x > a_x + 20.0 and a.global_position.y < lv.size.y - 32.0 - 15.0 - 5.0, "knockback kicks the ball (x +%.0f)" % (a.global_position.x - a_x))
	await _frames(120)
	a_x = a.global_position.x
	a.knockback(Vector2(300, -200))
	a.teleport(a.global_position)                  # teleport xoá cú hất đang chờ
	await _frames(20)
	_expect(absf(a.global_position.x - a_x) < 4.0 and a.on_ground, "teleport clears a pending knockback")
	lv.queue_free()
	await _frames(2)

	# --- Đổi kích thước: to, nhỏ, về 1.0; bóng vẫn đứng trên đất ---
	lv = _make_level(flat)
	a = _make_ball(lv, lv.start_position)
	b = _make_ball(lv, lv.start_position + Vector2(300, 0))
	var floor_y := lv.size.y - 32.0
	await _frames(60)
	var shape_a: CircleShape2D = a.get_node("Shape").shape
	var shape_b: CircleShape2D = b.get_node("Shape").shape
	_expect(shape_a == shape_b, "balls start with the shared collision shape from the scene")
	a.set_size(2.0)
	await _frames(90)
	shape_a = a.get_node("Shape").shape
	_expect(shape_a != shape_b and shape_a.radius == 30.0 and shape_b.radius == 15.0 and b.radius == 15.0, "set_size duplicates the collision shape (the other ball is untouched)")
	_expect(a.radius == 30.0 and absf(a.mass - 4.0) < 0.001 and absf(a.size_factor - 2.0) < 0.001, "set_size(2): radius 30 and mass x4 (mass %.2f)" % a.mass)
	_expect(a.on_ground and absf(a.global_position.y - (floor_y - 30.0)) < 3.0, "big ball rests on the ground (y=%.1f, want %.1f)" % [a.global_position.y, floor_y - 30.0])
	_expect(absf(_sprite_scale(a) - 4.0) < 0.01 and absf(a.get_node("Sprite").position.y - 30.0) < 0.01, "sprite is scaled with the ball and its feet follow the new radius")
	a.set_size(0.5)
	await _frames(90)
	_expect(a.radius == 7.5 and a.on_ground and absf(a.global_position.y - (floor_y - 7.5)) < 3.0, "small ball falls to and rests on the ground (y=%.1f, want %.1f)" % [a.global_position.y, floor_y - 7.5])
	a.set_size(1.0)
	await _frames(90)
	_expect(a.radius == 15.0 and a.get_node("Shape").shape.radius == 15.0 and a.mass == 1.0 and absf(_sprite_scale(a) - 2.0) < 0.001, "set_size(1.0) restores radius, shape, mass and sprite exactly")
	_expect(a.on_ground and absf(a.global_position.y - (floor_y - 15.0)) < 3.0, "restored ball rests on the ground (y=%.1f, want %.1f)" % [a.global_position.y, floor_y - 15.0])
	a.set_size(3.0)                                # to ra giữa không trung rồi rơi xuống: không xuyên đất
	a.teleport(Vector2(200, 40))
	await _frames(120)
	_expect(a.on_ground and absf(a.global_position.y - (floor_y - 45.0)) < 3.0, "a 3x ball dropped from above stays on the ground (y=%.1f, want %.1f)" % [a.global_position.y, floor_y - 45.0])
	a.set_size(1.0)
	lv.queue_free()
	await _frames(2)

	# --- Đổi kích thước ngay trong tín hiệu của vật nhặt (đang xử lý vật lý) ---
	lv = _make_level("#.....#\n#..O..#\n#..*..#\n#.....#\n#######")
	a = _make_ball(lv, lv.start_position)
	lv.star_collected_by.connect(func(by: Ball) -> void: by.set_size(1.5))
	await _frames(150)
	_expect(is_equal_approx(a.radius, 22.5) and a.on_ground and absf(a.global_position.y - (lv.size.y - 32.0 - 22.5)) < 3.0, "set_size works inside a pickup callback (radius %.1f, y %.1f)" % [a.radius, a.global_position.y])
	lv.queue_free()
	await _frames(2)

	# --- Dẹt như bánh ---
	lv = _make_level(flat)
	a = _make_ball(lv, lv.start_position)
	await _frames(60)
	var spr: Node2D = a.get_node("Sprite")
	var base_scale := spr.scale
	a.flatten(0.5)
	await _frames(15)
	_expect(spr.scale.y < base_scale.y * 0.4 and spr.scale.x > base_scale.x * 1.4, "flatten squashes the character flat (%s)" % spr.scale)
	await _frames(40)                              # hết 0.5 giây: bật lại
	await _frames(60)
	_expect(spr.scale.is_equal_approx(base_scale) or (absf(spr.scale.x - base_scale.x) < 0.05 and absf(spr.scale.y - base_scale.y) < 0.05), "flatten springs back to normal (%s)" % spr.scale)
	_expect(a.on_ground, "flatten does not change the physics")
	a.set_size(2.0)                                # dẹt kết hợp với kích thước
	a.flatten(0.2)
	await _frames(60)
	_expect(absf(spr.scale.x - 4.0) < 0.1 and absf(spr.scale.y - 4.0) < 0.1, "flatten and set_size combine and settle back (%s)" % spr.scale)
	lv.queue_free()
	await _frames(2)

	# --- Đạn đẩy lùi ---
	lv = _make_level(flat)
	a = _make_ball(lv, lv.start_position)
	b = _make_ball(lv, lv.start_position + Vector2(200, 0))
	await _frames(60)
	a_x = a.global_position.x
	b_x = b.global_position.x
	hurts = 0
	a.ammo = 5
	a.facing = 1
	a.shoot()                                      # đạn thường (bullet_knockback = 0): xuyên qua bóng 2, không hất
	await _frames(40)
	_expect(absf(b.global_position.x - b_x) < 3.0 and absf(a.global_position.x - a_x) < 3.0, "a normal bullet does not push balls")
	await _frames(40)
	a.bullet_knockback = 500.0
	a.shoot()
	await _frames(30)
	_expect(b.global_position.x > b_x + 30.0, "a knockback bullet pushes the other ball (x +%.0f)" % (b.global_position.x - b_x))
	_expect(absf(a.global_position.x - a_x) < 3.0, "the shooter is not pushed")
	_expect(hurts == 0 and not b.dead, "the knockback bullet does no damage")
	await _frames(100)
	var shot: Area2D = load("res://scenes/objects/player_bullet.tscn").instantiate()   # đạn đặt ngay trên người bắn: phải bỏ qua
	_expect(shot.collision_mask == 37, "a normal bullet keeps its original collision mask")
	shot.direction = Vector2.RIGHT
	shot.shooter = a
	shot.knockback = 500.0
	shot.position = a.position
	_expect(shot.collision_mask == 39, "a knockback bullet also collides with balls")
	lv.add_child(shot)
	a_x = a.global_position.x
	await _frames(3)
	_expect(is_instance_valid(shot) and not shot.is_queued_for_deletion() and absf(a.global_position.x - a_x) < 3.0 and a.linear_velocity.length() < 50.0, "a knockback bullet ignores its own shooter")
	lv.queue_free()
	await _frames(2)

	# --- Ai nhặt sao ---
	lv = _make_level("#.......#\n#..O....#\n#..*....#\n#.......#\n#########")
	var star_log := []                             # người nhặt từng ngôi sao
	var old_count := [0]
	lv.star_collected_by.connect(func(by: Ball) -> void: star_log.append(by))
	lv.star_collected.connect(func() -> void: old_count[0] += 1)
	a = _make_ball(lv, lv.start_position + Vector2(128, 0))   # bóng 1 đứng xa ngôi sao
	b = _make_ball(lv, lv.start_position)                     # bóng 2 rơi trúng ngôi sao
	a.set_player(1)
	b.set_player(2)
	await _frames(60)
	_expect(star_log.size() == 1 and star_log[0] == b and old_count[0] == 1, "star_collected_by names the ball that took the star, star_collected still fires")
	lv.collect_star()                              # gọi kiểu cũ, không kèm bóng
	_expect(star_log.size() == 2 and star_log[1] == null and old_count[0] == 2, "collect_star() without a ball still works (collector is null)")
	lv.queue_free()
	await _frames(2)


## Dựng cảnh đấu 2 người với đấu trường số `arena`, rút ngắn mọi thời gian chờ để test chạy nhanh (chưa chờ hết phần giới thiệu).
func _make_brawl(arena := 0, intro := 0.2, with_events := false) -> Brawl:
	var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
	br.arena_index = arena                          # chọn đấu trường cố định cho dễ đặt bóng
	br.intro_seconds = intro                        # giới thiệu ngắn
	br.respawn_delay = 0.3                          # hồi sinh nhanh
	br.win_panel_delay = 0.2                        # bảng thắng hiện nhanh
	add_child(br)
	br.events.enabled = with_events                 # sự kiện ngẫu nhiên tắt trừ khi bài test cần (các bài khác không bị sự kiện chen ngang)
	await _frames(2)
	return br


## Chờ hết phần giới thiệu và cho hai bóng đáp xuống đất.
func _brawl_ready(br: Brawl) -> void:
	for i in 200:                                   # tối đa 200 khung
		if br.match_running:
			break
		await _frames(1)
	await _frames(45)                               # cho hai bóng ổn định trên đất


## Chế độ đấu 2 người: dựng cảnh, các đường ghi điểm (dẫm, vực, gai), miễn sát thương, thắng cuộc, gai chống câu giờ, va chạm nảy.
func _brawl_checks() -> void:
	for c in get_children():                         # dọn cảnh chơi một mình còn sót lại (cùng một thế giới vật lý, đất của nó sẽ cản bóng)
		c.queue_free()
	await _frames(3)

	# --- Đấu trường hợp lệ: vừa một màn hình, tường bao, đối xứng, O và P đúng một lần ---
	for i in BrawlData.ARENAS.size():
		var rows: PackedStringArray = []
		for line in String(BrawlData.ARENAS[i]["map"]).split("\n"):
			if line.strip_edges() != "":
				rows.append(line)
		var ok := rows.size() == BrawlData.ROWS
		var mirrored := true
		var walls := true
		var spawns := 0
		var bottom_ground := true
		for r in rows.size():
			ok = ok and rows[r].length() == BrawlData.COLS
			walls = walls and rows[r][0] == "#" and rows[r][rows[r].length() - 1] == "#"
			for c in rows[r].length():
				var ch := rows[r][c]
				var mirror := rows[r][rows[r].length() - 1 - c]
				if ch == "O":
					spawns += 1
					mirrored = mirrored and mirror == "P"
				elif ch == "P":
					spawns += 1
					mirrored = mirrored and mirror == "O"
				else:
					mirrored = mirrored and mirror == ch
		for c in [1, 2, 3, 36, 37, 38]:               # chỗ hai người đứng có đất ở hai hàng cuối
			bottom_ground = bottom_ground and rows[rows.size() - 1][c] == "#" and rows[rows.size() - 2][c] == "#"
		_expect(ok and walls and mirrored and spawns == 2 and bottom_ground, "arena '%s': 40x22, walls, mirrored, one O and one P, ground under the spawns" % BrawlData.ARENAS[i]["name"])
		var has_pit := false
		var has_spikes: bool = "^" in String(BrawlData.ARENAS[i]["map"])
		for c in range(1, 39):
			has_pit = has_pit or rows[rows.size() - 1][c] == "."
		_expect(has_pit and has_spikes, "arena '%s' has a pit and spikes" % BrawlData.ARENAS[i]["name"])

	# --- Cảnh dựng được: hai bóng đúng chỗ, khác phím, đứng yên lúc giới thiệu ---
	var br := await _make_brawl(0, 0.6)
	var started := [0]
	br.match_started.connect(func() -> void: started[0] += 1)
	var a := br.balls[0]
	var b := br.balls[1]
	_expect(br.balls.size() == 2 and br.scores == [0, 0] and not br.match_running, "brawl scene loads: two balls, score 0-0, match not running during the intro")
	_expect(a.player_id == 1 and b.player_id == 2 and a.action_prefix == "p1_" and b.action_prefix == "p2_", "the two balls use different keys (P1 / P2)")
	_expect(a.collision_mask & 2 != 0 and b.collision_mask & 2 != 0 and b.get_node("Sprite").material != null and a.get_node("Sprite").material == null, "balls collide with each other and P2 is blue")
	_expect(a.global_position.distance_to(br.spawn_points[0]) < 4.0 and b.global_position.distance_to(br.spawn_points[1]) < 4.0 and br.spawn_points[0].x < br.spawn_points[1].x, "balls start on their own spawn points (P1 left, P2 right)")
	_expect(br.arena_rect.size == Vector2(1280, 704) and br.level.size == br.arena_rect.size, "arena is one screen (1280 x 704) with a fixed camera")
	Input.action_press("p1_right")
	Input.action_press("p2_left")
	await _frames(12)
	_expect(a.charge_dir == 0 and b.charge_dir == 0, "players cannot move during the READY... intro")
	br.kill(b, "pit")                               # lúc giới thiệu không ghi điểm
	_expect(br.scores == [0, 0] and b.visible, "kill() is ignored while the match is not running")
	_release_all_keys()
	await _brawl_ready(br)
	_expect(br.match_running and started[0] == 1 and not a.dead and not b.dead and a.on_ground and b.on_ground, "after the intro the match starts (match_started once) and both balls are on the ground")
	Input.action_press("p1_right")
	Input.action_press("p2_left")
	await _frames(15)
	_expect(a.charge_dir == 1 and b.charge_dir == -1, "after BOUNCE! both players can charge with their own keys")
	_release_all_keys()
	br.queue_free()
	await _frames(2)

	# --- Dẫm đầu: người dẫm ghi điểm, nạn nhân dẹt rồi hồi sinh sống ở chỗ của mình ---
	br = await _make_brawl(0)
	a = br.balls[0]
	b = br.balls[1]
	var events := []                                 # mỗi điểm: [người ghi, nạn nhân, nguyên nhân]
	br.point_scored.connect(func(scorer: Ball, victim: Ball, cause: String) -> void: events.append([scorer, victim, cause]))
	await _brawl_ready(br)
	var b_spawn := br.spawn_points[1]
	a.teleport(b.global_position + Vector2(3, -170))   # bóng 1 rơi xuống đầu bóng 2
	await _frames(45)
	_expect(br.scores == [1, 0] and events.size() == 1 and events[0][0] == a and events[0][1] == b and events[0][2] == "stomp", "stomping the opponent's head scores for the stomper (%s)" % str(br.scores))
	_expect(b.dead and b.visible, "the stomped player is still on screen as a pancake")
	var spr: Node2D = b.get_node("Sprite")
	_expect(spr.scale.y < spr.scale.x * 0.55, "the stomped player is flattened like a pancake (%s)" % spr.scale)
	_expect(not a.dead and br.scores[1] == 0, "the stomper stays alive and the victim scores nothing")
	await _frames(70)                                # dẹt 0.6 giây + hồi sinh 0.3 giây
	_expect(not b.dead and b.visible and b.collision_layer == 2 and b.global_position.distance_to(b_spawn) < 40.0, "the victim respawns alive at its own spawn point (%.0f px away)" % b.global_position.distance_to(b_spawn))
	_expect(b.invuln > 0.0 and events.size() == 1, "the respawned player is briefly invulnerable and no extra point was given")
	# người vừa hồi sinh (đang miễn sát thương) không bị dẫm lấy điểm
	a.teleport(b.global_position + Vector2(3, -170))
	await _frames(45)
	_expect(br.scores == [1, 0] and not b.dead and events.size() == 1, "an invulnerable player cannot be stomped for a point (%s)" % str(br.scores))
	br.queue_free()
	await _frames(2)

	# --- Rơi xuống vực: đối thủ ghi điểm ---
	br = await _make_brawl(0)
	a = br.balls[0]
	b = br.balls[1]
	events = []
	br.point_scored.connect(func(scorer: Ball, victim: Ball, cause: String) -> void: events.append([scorer, victim, cause]))
	await _brawl_ready(br)
	a.teleport(Vector2(640, 450))                    # giữa vực
	await _frames(70)
	_expect(br.scores == [0, 1] and events.size() == 1 and events[0][0] == b and events[0][1] == a and events[0][2] == "pit", "falling into the pit scores for the opponent (%s)" % str(br.scores))
	await _frames(50)
	_expect(not a.dead and a.visible and a.global_position.distance_to(br.spawn_points[0]) < 40.0 and br.scores == [0, 1], "the player who fell respawns at its own spawn point and nothing else scores")
	br.queue_free()
	await _frames(2)

	# --- Chạm gai: đối thủ ghi điểm; đang miễn sát thương thì không sao ---
	br = await _make_brawl(0)
	a = br.balls[0]
	b = br.balls[1]
	events = []
	br.point_scored.connect(func(scorer: Ball, victim: Ball, cause: String) -> void: events.append([scorer, victim, cause]))
	await _brawl_ready(br)
	b.invuln = 3.0                                   # miễn sát thương: gai không giết
	b.teleport(Vector2(416, 540))                    # rơi xuống hai ô gai ở cột 12-13
	await _frames(40)
	_expect(br.scores == [0, 0] and not b.dead, "an invulnerable player is not killed by spikes")
	b.invuln = 0.0
	b.teleport(Vector2(1168, 600))                   # bóng 2 đi chỗ khác, khỏi dính gai khi hết miễn sát thương
	await _frames(20)
	a.teleport(Vector2(416, 540))                    # bóng 1 rơi xuống gai
	await _frames(40)
	_expect(br.scores == [0, 1] and events.size() == 1 and events[0][0] == b and events[0][1] == a and events[0][2] == "spikes", "touching spikes scores for the opponent (%s)" % str(br.scores))
	br.queue_free()
	await _frames(2)

	# --- Đạt WIN_SCORE: hết trận, bảng thắng, không ghi thêm điểm ---
	for winner_index in [0, 1]:
		br = await _make_brawl(1)
		a = br.balls[0]
		b = br.balls[1]
		var winner := br.balls[winner_index]
		var loser := br.balls[1 - winner_index]
		var overs := []
		br.match_over.connect(func(w: Ball) -> void: overs.append(w))
		await _brawl_ready(br)
		br.scores[winner_index] = Brawl.WIN_SCORE - 1
		br.kill(loser, "pit")
		_expect(br.scores[winner_index] == Brawl.WIN_SCORE and not br.match_running and overs.size() == 1 and overs[0] == winner and br.winner == winner, "player %d reaching WIN_SCORE ends the match and emits match_over(winner)" % (winner_index + 1))
		await _frames(40)
		var texts := []
		if br.hud.win_panel != null:
			for n in br.hud.win_panel.find_children("*", "Label", true, false):
				texts.append(n.text)
		_expect(br.hud.win_panel != null and br.hud.win_panel.visible and ("PLAYER %d WINS!" % (winner_index + 1)) in texts, "the win panel shows PLAYER %d WINS! (%s)" % [winner_index + 1, str(texts)])
		_expect(br.hud.rematch_button != null and br.hud.rematch_button.text == "Rematch" and br.hud.menu_button != null and br.hud.menu_button.text == "Menu", "the win panel has Rematch and Menu buttons")
		var before: Array[int] = br.scores.duplicate()
		br.kill(winner, "pit")                       # trận đã hết: không ghi thêm
		winner.teleport(Vector2(640, 450))
		await _frames(100)                           # người thắng rơi xuống vực cũng không ai ghi điểm
		_expect(br.scores == before and overs.size() == 1, "no more points are scored after the match is over (%s)" % str(br.scores))
		br.queue_free()
		await _frames(2)

	# --- Gai chống câu giờ: hết giờ thì mọc từ hai bên vào giữa, có điểm thì mất ---
	br = await _make_brawl(0)
	br.stall_timeout = 0.5                           # rút ngắn từ 30 giây
	br.stall_step = 0.25
	await _brawl_ready(br)
	br.kill(br.balls[1], "pit")                      # có điểm: tính lại giờ ngay bây giờ
	await _frames(2)
	var base_spikes := _count(br.level, Spikes)
	_expect(br.stall_spikes.is_empty() and not br.stall_active, "no stall spikes before the timeout")
	await _frames(33)                                # 0.5 giây hết giờ: gai đầu tiên mọc ở hai đầu
	var xs: Array[float] = []
	for s in br.stall_spikes:
		xs.append(s.global_position.x)
	_expect(br.stall_active and br.stall_spikes.size() >= 2 and xs.min() < 320.0 and xs.max() > 960.0 and _count(br.level, Spikes) == base_spikes + br.stall_spikes.size(), "stall spikes appear on both ends of the floor after the timeout (%d spikes)" % br.stall_spikes.size())
	var first_count := br.stall_spikes.size()
	await _frames(15)                                # nhịp thứ hai (0.75 giây); nhịp thứ ba (cột 3 và 36, chỗ hai người đứng) chưa tới
	_expect(br.stall_spikes.size() > first_count, "more stall spikes creep in over time (%d -> %d)" % [first_count, br.stall_spikes.size()])
	br.kill(br.balls[1] if not br.balls[1].dead else br.balls[0], "pit")   # có điểm: gai biến mất
	await _frames(3)
	_expect(br.stall_spikes.is_empty() and not br.stall_active and _count(br.level, Spikes) == base_spikes, "scoring a point removes the stall spikes")
	await _frames(20)
	_expect(br.stall_spikes.is_empty(), "the stall timer restarts after a point (no spikes 0.3 s later)")
	await _frames(25)
	_expect(not br.stall_spikes.is_empty(), "...and the spikes start again after another quiet timeout")
	br.queue_free()
	await _frames(2)

	# --- Va chạm giữa hai bóng nảy và thô bạo hơn bình thường ---
	br = await _make_brawl(0)
	a = br.balls[0]
	b = br.balls[1]
	await _brawl_ready(br)
	b.teleport(Vector2(250, 600))                    # bóng 2 đứng trên mặt đất bên trái
	await _frames(30)
	a.teleport(b.global_position + Vector2(-50, -20))
	await _frames(2)
	a.linear_velocity = Vector2(500, 0)              # bóng 1 lao vào bóng 2
	var peak_b := 0.0
	var min_a := 0.0
	for i in 20:
		await _frames(1)
		peak_b = maxf(peak_b, b.linear_velocity.x)
		min_a = minf(min_a, a.linear_velocity.x)
	print("    (shove test: victim peak vx %.0f, attacker min vx %.0f)" % [peak_b, min_a])
	_expect(peak_b > 300.0 and min_a < -100.0, "bumping is shove-y: the bumped ball flies off (%.0f) and the attacker rebounds backwards (%.0f, plain physics leaves it going forward)" % [peak_b, min_a])
	br.queue_free()
	await _frames(2)


## Các thông số vật lý / điều khiển mà sự kiện có thể đổi của một quả bóng: [trọng lực, độ nảy, ma sát, đảo phím],
## ba số đầu nhân 1000 và làm tròn thành số nguyên (Godot lưu float 32 bit nên so sánh số thực trực tiếp sẽ lệch).
func _ev_props(ball: Ball) -> Array:
	var m := ball.physics_material_override
	return [roundi(ball.gravity_scale * 1000.0), roundi(m.bounce * 1000.0), roundi(m.friction * 1000.0), ball.reverse_controls]


## Số quả bom (BombMarker) đang nổi trên đầu `ball` (không tính cái đã bị xoá).
func _bomb_markers(ball: Ball) -> int:
	var n := 0
	for c in ball.get_children():
		if c is BrawlEvents.BombMarker and not c.is_queued_for_deletion():
			n += 1
	return n


## Đặt bóng về chỗ xuất phát và chờ đứng yên.
func _ev_reset_ball(br: Brawl, ball: Ball) -> void:
	ball.teleport(br.spawn_of(ball))
	await _frames(50)


## Nhảy thẳng lên (độ mạnh 0.5): trả về độ cao đỉnh nhảy (pixel) so với lúc đứng.
func _ev_apex(br: Brawl, ball: Ball) -> float:
	await _ev_reset_ball(br, ball)
	var start_y := ball.global_position.y
	var min_y := start_y
	ball.jump(0, 0.5)
	for i in 260:
		await _frames(1)
		min_y = minf(min_y, ball.global_position.y)
	return start_y - min_y


## Thả bóng từ cao 324 pixel: trả về độ cao nảy lên sau lần chạm đất đầu tiên (pixel, so với mặt đất).
func _ev_rebound(br: Brawl, ball: Ball) -> float:
	await _ev_reset_ball(br, ball)
	var ground_y := ball.global_position.y
	ball.teleport(Vector2(ball.global_position.x, ground_y - 324.0))
	var rising := false
	var min_y := ground_y
	for i in 160:
		await _frames(1)
		if ball.linear_velocity.y < -100.0:
			rising = true                           # đã chạm đất và đang nảy lên
		if rising:
			min_y = minf(min_y, ball.global_position.y)
	return ground_y - min_y


## Đẩy bóng sang phải 250 px/s rồi để trượt 40 khung: trả về quãng đường trượt (pixel).
func _ev_slide(br: Brawl, ball: Ball) -> float:
	await _ev_reset_ball(br, ball)
	var x0 := ball.global_position.x
	ball.linear_velocity = Vector2(250, 0)
	await _frames(40)
	return ball.global_position.x - x0


## Sự kiện ngẫu nhiên: bốc thăm không trùng, từng hiệu ứng thật sự có tác dụng và hoàn tác sạch, hồi sinh giữa sự kiện,
## bom chuyền / nổ / người cầm chết, không có sự kiện lúc giới thiệu và sau trận, bộ đếm giờ tự bốc thăm + roulette trên HUD.
func _brawl_event_checks() -> void:
	# --- Dựng cảnh; chưa bắt đầu trận thì start_event bị bỏ qua ---
	var br := await _make_brawl(0, 0.3)
	var a := br.balls[0]
	var b := br.balls[1]
	var ev := br.events
	var starts: Array[String] = []
	var ends: Array[String] = []
	ev.event_started.connect(func(id: String) -> void: starts.append(id))
	ev.event_ended.connect(func(id: String) -> void: ends.append(id))
	_expect(ev != null and ev.get_parent() == br and BrawlEvents.EVENT_IDS.size() == 6 and ev.active_event == "" and ev.rolling_event == "", "brawl.events exists with six events and nothing active")
	_expect(ev.interval == 15.0 and ev.first_delay == 10.0 and ev.roulette_seconds == 2.0 and ev.enabled == false, "defaults: first event after 10 s, then every 15 s, roulette 2 s (events switched off by the test helper)")
	ev.start_event("low_gravity")
	_expect(ev.active_event == "" and a.gravity_scale == 1.0 and starts.is_empty(), "start_event() is ignored while the match is not running (intro)")
	await _brawl_ready(br)

	# --- Bốc thăm: không bao giờ trùng sự kiện ngay trước, đủ sáu sự kiện ---
	var picks: Array[String] = []
	var seen := {}
	var never_twice := true
	for i in 400:
		var pick := ev.pick_event()
		if not picks.is_empty() and pick == picks[-1]:
			never_twice = false
		picks.append(pick)
		seen[pick] = true
	_expect(never_twice and seen.size() == 6, "pick_event(): never the same event twice in a row over 400 picks, and all 6 events come up")

	# --- Số đo gốc (trước mọi sự kiện) ---
	var base := _ev_props(a)
	var mat_a := a.physics_material_override
	var mat_b := b.physics_material_override
	_expect(base == [1000, 550, 900, false] and _ev_props(b) == base, "baseline: gravity 1, bounce 0.55, friction 0.9, normal keys (%s)" % str(base))
	var apex_normal := await _ev_apex(br, a)
	var rebound_normal := await _ev_rebound(br, a)
	var slide_normal := await _ev_slide(br, a)
	print("    (baseline: apex %.0f px, rebound %.0f px, slide %.0f px)" % [apex_normal, rebound_normal, slide_normal])

	# --- LOW GRAVITY: rơi chậm, nhảy cao hơn hẳn; hết sự kiện thì trọng lực về 1 ---
	ev.start_event("low_gravity")
	await _frames(2)
	_expect(ev.active_event == "low_gravity" and starts.back() == "low_gravity" and is_equal_approx(a.gravity_scale, ev.low_gravity_scale) and is_equal_approx(b.gravity_scale, ev.low_gravity_scale), "LOW GRAVITY: both balls get gravity x%.2f" % ev.low_gravity_scale)
	_expect(br.hud.event_state == "active" and br.hud.event_text == "LOW GRAVITY" and br.hud.event_fraction > 0.9, "LOW GRAVITY: the HUD banner shows the name and a full countdown bar")
	var apex_low := await _ev_apex(br, a)
	print("    (low gravity: apex %.0f px vs %.0f px normal)" % [apex_low, apex_normal])
	_expect(apex_low > apex_normal * 1.8, "LOW GRAVITY: the same jump goes much higher (%.0f px vs %.0f px)" % [apex_low, apex_normal])
	_expect(br.hud.event_fraction < 0.95 and ev.time_left < ev.low_gravity_seconds - 4.0, "LOW GRAVITY: the countdown bar shrinks while it runs (%.2f)" % br.hud.event_fraction)
	ev.stop_event()
	await _frames(2)
	_expect(ev.active_event == "" and ends.back() == "low_gravity" and _ev_props(a) == base and _ev_props(b) == base and br.hud.event_state == "", "LOW GRAVITY: stop_event() restores gravity and hides the banner")
	var apex_after := await _ev_apex(br, a)
	_expect(absf(apex_after - apex_normal) < 4.0, "after LOW GRAVITY the jump height is back to normal (%.0f vs %.0f px)" % [apex_after, apex_normal])

	# --- SUPER BOUNCE: nảy cao gần bằng độ cao thả ---
	ev.start_event("super_bounce")
	await _frames(2)
	_expect(ev.active_event == "super_bounce" and is_equal_approx(a.physics_material_override.bounce, ev.super_bounce_bounce) and is_equal_approx(b.physics_material_override.bounce, ev.super_bounce_bounce) and a.physics_material_override != b.physics_material_override and a.physics_material_override != mat_a, "SUPER BOUNCE: each ball gets its own material with bounce %.2f (the shared scene material is untouched: %.2f)" % [ev.super_bounce_bounce, mat_a.bounce])
	var rebound_super := await _ev_rebound(br, a)
	print("    (super bounce: rebound %.0f px of a 324 px drop; normal %.0f px)" % [rebound_super, rebound_normal])
	_expect(rebound_super > rebound_normal * 2.2 and rebound_super > 220.0, "SUPER BOUNCE: a dropped ball rebounds far higher (%.0f px vs %.0f px, drop 324 px)" % [rebound_super, rebound_normal])
	ev.stop_event()
	await _frames(2)
	_expect(_ev_props(a) == base and _ev_props(b) == base and a.physics_material_override == mat_a and b.physics_material_override == mat_b, "SUPER BOUNCE: the original material object is back on both balls")
	var rebound_after := await _ev_rebound(br, a)
	_expect(absf(rebound_after - rebound_normal) < 5.0, "after SUPER BOUNCE the rebound is back to normal (%.0f vs %.0f px)" % [rebound_after, rebound_normal])

	# --- ICE FLOOR: gần như không ma sát, trượt xa; có lớp phủ băng nhìn thấy; hết thì bỏ ---
	ev.start_event("ice_floor")
	await _frames(2)
	_expect(ev.active_event == "ice_floor" and is_equal_approx(a.physics_material_override.friction, ev.ice_friction) and is_equal_approx(b.physics_material_override.friction, ev.ice_friction) and _count(br.level, BrawlEvents.IceOverlay) == 1, "ICE FLOOR: friction %.2f on both balls and the icy overlay is on the arena" % ev.ice_friction)
	var slide_ice := await _ev_slide(br, a)
	print("    (ice: slid %.0f px vs %.0f px normal)" % [slide_ice, slide_normal])
	_expect(slide_ice > slide_normal * 3.0 and slide_ice > 100.0, "ICE FLOOR: a pushed ball slides much farther (%.0f px vs %.0f px)" % [slide_ice, slide_normal])
	ev.stop_event()
	await _frames(2)
	_expect(_ev_props(a) == base and _ev_props(b) == base and a.physics_material_override == mat_a and _count(br.level, BrawlEvents.IceOverlay) == 0, "ICE FLOOR: friction and the icy overlay are gone afterwards")
	var slide_after := await _ev_slide(br, a)
	_expect(absf(slide_after - slide_normal) < 5.0, "after ICE FLOOR the slide is back to normal (%.0f vs %.0f px)" % [slide_after, slide_normal])

	# --- REVERSED KEYS: giữ trái thì đi phải; tự hết sau thời gian đặt ---
	ev.reversed_keys_seconds = 0.6
	ev.start_event("reversed_keys")
	await _frames(2)
	_expect(a.reverse_controls and b.reverse_controls, "REVERSED KEYS: both balls have reversed controls")
	Input.action_press("p1_left")
	Input.action_press("p2_right")
	await _frames(12)
	_expect(a.charge_dir == 1 and b.charge_dir == -1, "REVERSED KEYS: holding left charges RIGHT for P1 and holding right charges LEFT for P2 (%d, %d)" % [a.charge_dir, b.charge_dir])
	_release_all_keys()
	await _frames(40)                                # 0.6 giây hết giờ
	_expect(ev.active_event == "" and ends.back() == "reversed_keys" and not a.reverse_controls and not b.reverse_controls, "REVERSED KEYS: ends by itself after its duration and the keys are normal again")
	Input.action_press("p1_left")
	Input.action_press("p2_right")
	await _frames(12)
	_expect(a.charge_dir == -1 and b.charge_dir == 1, "after REVERSED KEYS holding left charges left again")
	_release_all_keys()
	await _frames(3)
	ev.reversed_keys_seconds = 8.0

	# --- SWAP!: đổi chỗ và vận tốc, tức thì ---
	a.teleport(Vector2(300, 300))
	b.teleport(Vector2(900, 250))
	await _frames(3)
	a.linear_velocity = Vector2(120, 0)
	b.linear_velocity = Vector2(-60, 0)
	await _frames(1)
	var pos_a := a.global_position
	var pos_b := b.global_position
	var vx_a := a.linear_velocity.x
	var vx_b := b.linear_velocity.x
	var started_before := starts.size()
	ev.start_event("swap")
	_expect(ev.active_event == "" and starts.size() == started_before + 1 and starts.back() == "swap" and ends.back() == "swap", "SWAP!: instant event (started and ended at once, nothing stays active)")
	await _frames(4)
	_expect(a.global_position.distance_to(pos_b) < 40.0 and b.global_position.distance_to(pos_a) < 40.0, "SWAP!: the two players traded places (P1 %s -> %s, P2 %s -> %s)" % [pos_a.round(), a.global_position.round(), pos_b.round(), b.global_position.round()])
	_expect(absf(a.linear_velocity.x - vx_b) < 25.0 and absf(b.linear_velocity.x - vx_a) < 25.0, "SWAP!: velocities were traded too (P1 vx %.0f, P2 vx %.0f; before %.0f / %.0f)" % [a.linear_velocity.x, b.linear_velocity.x, vx_a, vx_b])
	_expect(_ev_props(a) == base and _ev_props(b) == base, "SWAP!: nothing else is left changed")
	br.hud.hide_event()

	# --- Hồi sinh giữa sự kiện: hiệu ứng được áp lại, hết sự kiện thì sạch hoàn toàn ---
	for id in ["low_gravity", "super_bounce", "ice_floor", "reversed_keys"]:
		ev.start_event(id)
		await _frames(2)
		var during := _ev_props(b)
		_expect(ev.active_event == id and during != base and _ev_props(a) == during, "%s: both players have the effect (%s)" % [id, str(during)])
		br.kill(a, "pit")                           # P1 chết giữa sự kiện, P2 ghi điểm
		await _frames(50)                           # hồi sinh sau 0.3 giây
		_expect(not a.dead and ev.active_event == id and _ev_props(a) == during, "%s: the player who respawned during the event has the effect again" % id)
		ev.stop_event()
		await _frames(2)
		_expect(_ev_props(a) == base and _ev_props(b) == base and a.physics_material_override == mat_a and b.physics_material_override == mat_b and _count(br.level, BrawlEvents.IceOverlay) == 0, "%s: after the event everything is exactly back to normal (gravity, material, keys, overlay)" % id)
	br.queue_free()
	await _frames(2)

	# --- HOT POTATO: bom nổi trên đầu, chuyền khi chạm (có thời gian chờ), nổ giết người cầm ---
	br = await _make_brawl(0)
	a = br.balls[0]
	b = br.balls[1]
	ev = br.events
	var kills := []
	br.point_scored.connect(func(scorer: Ball, victim: Ball, cause: String) -> void: kills.append([scorer, victim, cause]))
	await _brawl_ready(br)
	ev.hot_potato_seconds = 6.0
	ev.potato_pass_cooldown = 0.5
	ev.start_event("hot_potato")
	var first := ev.bomb_carrier
	var second := br.opponent_of(first)
	_expect(ev.active_event == "hot_potato" and first != null and _bomb_markers(first) == 1 and _bomb_markers(second) == 0 and br.hud.event_text == "HOT POTATO", "HOT POTATO: exactly one player carries a bomb over their head")
	await _frames(30)
	_expect(ev.bomb_carrier == first and absf(ev._bomb.fuse_left - ev.time_left) < 0.1 and ev.time_left < 5.6, "HOT POTATO: the bomb stays while the players are apart and the fuse counts down (%.1f s)" % ev.time_left)
	var toward := -31.0 if first.global_position.x > 640.0 else 31.0
	second.teleport(first.global_position + Vector2(toward, 0))
	await _frames(6)
	_expect(ev.bomb_carrier == second and _bomb_markers(second) == 1 and _bomb_markers(first) == 0, "HOT POTATO: touching the other player passes the bomb on")
	first.teleport(second.global_position + Vector2(-toward, 0))   # lập tức chạm lại: còn trong thời gian chờ
	await _frames(6)
	_expect(ev.bomb_carrier == second and _bomb_markers(second) == 1, "HOT POTATO: the pass cooldown stops the bomb pinging back at once")
	await _frames(40)
	var holder := ev.bomb_carrier
	var other_one := br.opponent_of(holder)
	other_one.teleport(holder.global_position + Vector2(-31.0 if holder.global_position.x > 640.0 else 31.0, 0))
	await _frames(6)
	_expect(ev.bomb_carrier == other_one and _bomb_markers(other_one) == 1 and _bomb_markers(holder) == 0 and kills.is_empty(), "HOT POTATO: after the cooldown it can be passed again (no points so far)")
	var victim := ev.bomb_carrier
	var scorer := br.opponent_of(victim)
	var scorer_index := br.balls.find(scorer)
	ev.time_left = 0.1                              # ngòi sắp hết
	await _frames(12)
	_expect(br.scores[scorer_index] == 1 and br.scores[1 - scorer_index] == 0 and kills.size() == 1 and kills[0][0] == scorer and kills[0][1] == victim and kills[0][2] == "bomb", "HOT POTATO: when the fuse ends the carrier is killed with cause 'bomb' and the other player scores (%s)" % str(br.scores))
	_expect(victim.dead and ev.active_event == "" and ev.bomb_carrier == null and _bomb_markers(victim) == 0 and _bomb_markers(scorer) == 0 and ends.size() > 0, "HOT POTATO: the bomb is gone and the event is over after the explosion")
	_expect(br.hud.message_label.text == "P%d WENT BOOM!" % victim.player_id, "HOT POTATO: the point message reads '%s'" % br.hud.message_label.text)
	await _frames(60)
	_expect(not victim.dead and br.scores[scorer_index] == 1 and kills.size() == 1, "HOT POTATO: the victim respawns and nothing else scores")
	br.queue_free()
	await _frames(2)

	# --- Người cầm bom chết vì lý do khác: sự kiện bom kết thúc, không thêm điểm ---
	for cause in ["pit", "stomp", "spikes"]:
		br = await _make_brawl(0)
		a = br.balls[0]
		b = br.balls[1]
		ev = br.events
		await _brawl_ready(br)
		ev.hot_potato_seconds = 2.0
		ev.start_event("hot_potato")
		var carrier := ev.bomb_carrier
		var rival := br.opponent_of(carrier)
		br.kill(carrier, cause)
		await _frames(2)
		_expect(ev.active_event == "" and ev.bomb_carrier == null and _bomb_markers(carrier) == 0 and _bomb_markers(rival) == 0 and br.hud.event_state == "", "HOT POTATO: the carrier dying by '%s' ends the bomb event" % cause)
		await _frames(170)                          # quá thời gian ngòi cũ (2 giây)
		_expect(br.scores[br.balls.find(rival)] == 1 and br.scores[br.balls.find(carrier)] == 0 and not carrier.dead, "HOT POTATO: no extra bomb point after the carrier died by '%s' (%s)" % [cause, str(br.scores)])
		br.queue_free()
		await _frames(2)

	# --- Hết trận giữa sự kiện: mọi hiệu ứng được hoàn tác, sau đó không còn sự kiện ---
	br = await _make_brawl(0)
	a = br.balls[0]
	b = br.balls[1]
	ev = br.events
	mat_a = a.physics_material_override
	await _brawl_ready(br)
	ev.start_event("ice_floor")
	await _frames(2)
	_expect(_count(br.level, BrawlEvents.IceOverlay) == 1 and a.physics_material_override != mat_a, "(match end) the ice event is running")
	br.scores[1] = Brawl.WIN_SCORE - 1
	br.kill(a, "pit")                               # P2 đạt điểm thắng: hết trận
	await _frames(3)
	_expect(not br.match_running and ev.active_event == "" and _ev_props(a) == base and _ev_props(b) == base and a.physics_material_override == mat_a and _count(br.level, BrawlEvents.IceOverlay) == 0 and br.hud.event_state == "", "the match ending removes the running event completely")
	ev.start_event("low_gravity")
	await _frames(2)
	_expect(ev.active_event == "" and a.gravity_scale == 1.0, "no event can start after the match is over")
	br.queue_free()
	await _frames(2)

	# --- Bộ đếm giờ tự bốc thăm: không có gì lúc giới thiệu; roulette; sự kiện; không trùng; tắt được ---
	br = await _make_brawl(0, 0.8, true)
	a = br.balls[0]
	b = br.balls[1]
	ev = br.events
	ev.first_delay = 0.5
	ev.interval = 1.5
	ev.roulette_seconds = 0.6
	ev.low_gravity_seconds = 0.3
	ev.super_bounce_seconds = 0.3
	ev.ice_floor_seconds = 0.3
	ev.reversed_keys_seconds = 0.3
	ev.hot_potato_seconds = 0.3
	starts = []
	ends = []
	ev.event_started.connect(func(id: String) -> void: starts.append(id))
	ev.event_ended.connect(func(id: String) -> void: ends.append(id))
	await _frames(35)                                # vẫn đang READY...
	_expect(not br.match_running and ev.active_event == "" and ev.rolling_event == "" and starts.is_empty() and br.hud.event_state == "", "no event and no roulette during the READY... intro")
	while not br.match_running:
		await _frames(1)
	await _frames(24)                                # 0.4 giây sau khi bắt đầu: chưa tới giờ (first_delay 0.5)
	_expect(starts.is_empty() and ev.rolling_event == "", "no event before first_delay has passed")
	await _frames(18)                                # 0.7 giây: roulette đang quay
	var rolled := ev.rolling_event
	_expect(rolled != "" and br.hud.event_state == "roulette" and ev.active_event == "" and starts.is_empty(), "the roulette starts at first_delay and the event waits for it to finish (rolling %s)" % rolled)
	await _frames(18)                                # 1.0 giây: roulette đã dừng ở tên được chọn nhưng chưa vào sự kiện
	_expect(ev.rolling_event == rolled and br.hud.event_text == ev.event_name(rolled), "the roulette lands on the chosen event name ('%s')" % br.hud.event_text)
	await _frames(18)                                # 1.3 giây: sự kiện đầu tiên đã bắt đầu
	_expect(starts.size() == 1 and starts[0] == rolled and ev.rolling_event == "", "the automatic timer fired exactly the event the roulette landed on (%s)" % str(starts))
	await _frames(60)                                # 2.3 giây: sự kiện đầu đã hết, đã tới giờ sự kiện thứ hai (0.5 + 1.5 = 2.0 giây)
	_expect(ends.size() >= 1 and ev.active_event == "" and (ev.rolling_event != "" or starts.size() == 2), "the second roulette starts one interval (1.5 s) after the first")
	await _frames(40)                                # 3.0 giây
	_expect(starts.size() == 2 and starts[0] != starts[1], "never the same event twice in a row from the timer (%s)" % str(starts))
	ev.enabled = false
	await _frames(80)                                # 4.3 giây: lẽ ra sự kiện thứ ba bắt đầu vào 3.5 giây
	_expect(starts.size() == 2 and ev.rolling_event == "", "enabled = false stops new events")
	ev.stop_event()
	await _frames(3)
	_expect(_ev_props(a) == base and _ev_props(b) == base and _count(br.level, BrawlEvents.IceOverlay) == 0 and _bomb_markers(a) == 0 and _bomb_markers(b) == 0, "after the automatic events everything is back to normal")
	br.queue_free()
	await _frames(2)


## Hệ số phóng của node Sprite (x), để so với pixel_scale * kích thước.
func _sprite_scale(ball: Ball) -> float:
	return (ball.get_node("Sprite") as Node2D).scale.x


func _shot(shot_name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(shots_dir.path_join(shot_name + ".png"))
