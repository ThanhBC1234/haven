extends Node
## Kiểm tra tự động các cơ chế. Chạy trong thư mục project:
##   godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
## Không dùng --headless và thêm `-- --shots=<thư mục>` để lưu ảnh toàn cảnh từng màn.

var failures := 0
var shots_dir := ""
var hurts := 0
var bot_seed_offset := 0                # cộng vào hạt giống của các mục bot (godot ... -- --bot-seed=N): thử xem mục nào mong manh với hạt giống khác


## Chạy lần lượt các kiểm tra; in "ok" hoặc "FAIL" cho từng mục.
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.trim_prefix("--shots=")
		if a.begins_with("--bot-seed="):
			bot_seed_offset = int(a.trim_prefix("--bot-seed="))
	Game.save_enabled = false                      # không ghi đè file lưu thật của người chơi
	if OS.get_cmdline_user_args().has("--only-items"):   # lúc đang làm vật phẩm: chạy riêng phần này cho nhanh (godot ... -- --only-items)
		await _brawl_item_checks()
		print("RESULT: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures))
		get_tree().quit(1 if failures > 0 else 0)
		return

	if OS.get_cmdline_user_args().has("--only-chained"):   # lúc đang làm chế độ Chained: chạy riêng phần này cho nhanh (godot ... -- --only-chained)
		await _chained_checks()
		print("RESULT: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures))
		get_tree().quit(1 if failures > 0 else 0)
		return

	if OS.get_cmdline_user_args().has("--only-bot"):     # lúc đang làm bot: chạy riêng phần này cho nhanh (godot ... -- --only-bot)
		await _brawl_bot_checks()
		print("RESULT: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures))
		get_tree().quit(1 if failures > 0 else 0)
		return

	# --- Menu ---
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(3)
	_expect(menu.level_grid.get_child_count() == LevelData.LEVELS.size() + 1, "menu grid has Endless + one button per level (BRAWL 2P is its own wide row below the grid)")
	_expect(menu.brawl_button != null and menu.brawl_button.text == "BRAWL 2P" and menu.brawl_button.get_parent() == menu.brawl_row and menu.brawl_row.get_parent() == menu.level_grid.get_parent(), "menu has the BRAWL 2P button (in the Brawl row under the level grid)")
	_expect(menu.bot_button != null and menu.bot_button.text == "BRAWL VS BOT" and menu.bot_button.get_parent() == menu.brawl_row, "menu has the BRAWL VS BOT button next to BRAWL 2P in the same row")
	var menu_rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var brawl_rect: Rect2 = menu.brawl_row.get_global_rect()
	var two_rect: Rect2 = menu.brawl_button.get_global_rect()
	var bot_rect: Rect2 = menu.bot_button.get_global_rect()
	var tidy := menu_rect.encloses(brawl_rect) and not brawl_rect.intersects(menu.level_grid.get_global_rect()) and not brawl_rect.intersects(menu.help.get_global_rect()) and menu_rect.encloses(menu.quit_button.get_global_rect())
	_expect(tidy, "the Brawl row fits the 1280x720 screen and does not overlap the level grid, the help line or Quit (%s)" % brawl_rect)
	_expect(brawl_rect.encloses(two_rect) and brawl_rect.encloses(bot_rect) and not two_rect.intersects(bot_rect) and two_rect.position.x < bot_rect.position.x and absf(two_rect.size.x - bot_rect.size.x) < 2.0, "BRAWL 2P (left) and BRAWL VS BOT (right) sit side by side, equal width, inside the row (%s | %s)" % [two_rect, bot_rect])
	_expect(menu.brawl_button.pressed.get_connections().size() >= 1 and menu.bot_button.pressed.get_connections().size() >= 1 and Game.has_method("start_brawl") and not Game.brawl_vs_bot, "both Brawl buttons are wired to Game.start_brawl (vs_bot defaults to false)")
	var chained_rect: Rect2 = menu.chained_button.get_global_rect()
	_expect(menu.chained_button != null and menu.chained_button.text == "CHAINED 2P" and menu.chained_button.get_parent() == menu.brawl_row, "menu has the CHAINED 2P button in the same row as the Brawl buttons")
	_expect(brawl_rect.encloses(chained_rect) and not chained_rect.intersects(bot_rect) and not chained_rect.intersects(two_rect) and chained_rect.position.x > bot_rect.position.x and absf(chained_rect.size.x - bot_rect.size.x) < 2.0 and menu_rect.encloses(chained_rect), "CHAINED 2P sits to the right of BRAWL VS BOT, equal width, inside the row and the screen (%s)" % chained_rect)
	_expect(menu.chained_button.pressed.get_connections().size() >= 1 and Game.has_method("start_chained"), "CHAINED 2P is wired to Game.start_chained")
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
	await _brawl_sudden_death_checks()             # SUDDEN DEATH: hàng gai dâng khi sàn đã kín gai mà vẫn chưa ai ghi điểm
	await _brawl_event_checks()                    # sự kiện ngẫu nhiên của chế độ đấu (roulette, 6 sự kiện)
	await _brawl_item_checks()                     # vật phẩm troll, vương miện người dẫn điểm, câu châm chọc
	await _brawl_bot_checks()                      # máy (bot) chơi thay người chơi 2
	await _chained_checks()                        # chế độ Chained: hai người bị trói bằng dây, sao xâu trên dây

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
func _make_brawl(arena := 0, intro := 0.2, with_events := false, with_items := false) -> Brawl:
	var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
	br.arena_index = arena                          # chọn đấu trường cố định cho dễ đặt bóng
	br.intro_seconds = intro                        # giới thiệu ngắn
	br.respawn_delay = 0.3                          # hồi sinh nhanh
	br.win_panel_delay = 0.2                        # bảng thắng hiện nhanh
	add_child(br)
	br.events.enabled = with_events                 # sự kiện ngẫu nhiên tắt trừ khi bài test cần (các bài khác không bị sự kiện chen ngang)
	br.items.enabled = with_items                   # hộp vật phẩm tự sinh cũng tắt trừ khi bài test cần (give / spawn_box gọi tay vẫn dùng được)
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
	_expect(br.hud.message_label.text in _taunt_options("bomb", scorer.player_id, victim.player_id), "HOT POTATO: the point message is one of the bomb taunts ('%s')" % br.hud.message_label.text)
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


## Các câu châm chọc có thể hiện cho nguyên nhân `cause` khi người ghi điểm là P`s` và nạn nhân là P`v` (đã thay tên).
func _taunt_options(cause: String, s: int, v: int) -> Array:
	var out := []
	for line in BrawlData.TAUNTS.get(cause, BrawlData.TAUNTS["default"]):
		out.append(String(line).format({"s": "P%d" % s, "v": "P%d" % v}))
	return out


## Lý do một chỗ đặt hộp `pos` không hợp lệ (đọc thẳng bản đồ chữ, không dùng hàm của BrawlItems); "" = hợp lệ.
func _spot_problem(br: Brawl, pos: Vector2) -> String:
	var rows := br.level.rows
	var floor_y := pos.y + BrawlItems.BOX_LIFT
	var r := roundi(floor_y / 32.0)
	var c := int(pos.x / 32.0)
	if absf(floor_y - r * 32.0) > 1.0 or r < 2 or r >= rows.size():
		return "feet are not on a tile top"
	if rows[r][c] != "#":
		return "no ground below (pit or air)"
	if rows[r - 1][c] != "." or rows[r - 2][c] != ".":
		return "cell not free (terrain / spawn / spikes) at %d,%d" % [r - 1, c]
	for dc in [-1, 0, 1]:
		if rows[r - 1][c + dc] in "^T":
			return "next to spikes or a trampoline"
	return ""


## Xoá mọi hộp đang có (không qua nhặt).
func _items_clear_boxes(it: BrawlItems) -> void:
	for bx in it.boxes.duplicate():
		it.boxes.erase(bx)
		bx.queue_free()


## Đặt bóng ở `pos` và chờ nó đứng yên.
func _item_place(ball: Ball, pos: Vector2, frames := 30) -> void:
	ball.teleport(pos)
	await _frames(frames)


## Vật phẩm troll, vương miện người dẫn điểm, câu châm chọc.
func _brawl_item_checks() -> void:
	var ground := 640.0                              # mặt đất của cả hai đấu trường (hàng 20)
	var gy := ground - 15.0                          # độ cao tâm bóng đứng trên đất

	# --- Cơ bản + không có gì lúc giới thiệu ---
	var br := await _make_brawl(0, 0.6, false, true)
	var it := br.items
	var a := br.balls[0]
	var b := br.balls[1]
	_expect(it != null and it.get_parent() == br and BrawlItems.ITEM_IDS.size() == 4 and it.held == ["", ""] and it.boxes.is_empty() and it.traps.is_empty(), "brawl.items exists with four items, empty hands and no boxes")
	_expect(it.spawn_interval == 6.0 and it.max_boxes == 2 and it.enabled and it.spring_life_seconds == 12.0 and it.banana_seconds == 3.0, "defaults: a box every 6 s, at most 2 boxes, banana 3 s, spring trap lives 12 s")
	it.first_delay = 0.05
	await _frames(30)
	_expect(not br.match_running and it.boxes.is_empty() and it.spawn_box() == null, "no box spawns during the READY... intro (timer and spawn_box)")
	it.give(a, "gun")
	_expect(it.held[0] == "" and a.ammo == 0, "give() does nothing before the match starts")
	await _brawl_ready(br)
	_expect(it.boxes.size() == 1, "the first box appears right after the match starts (%d)" % it.boxes.size())
	var first_box = it.boxes[0]
	_expect(it.is_valid_spot(first_box.position) and _spot_problem(br, first_box.position) == "" and BrawlItems.ITEM_IDS.has(first_box.item_id), "the automatic box is on a valid spot and holds a real item (%s)" % first_box.item_id)
	# giới hạn 2 hộp: sinh nhanh, không bao giờ vượt 2
	it.spawn_interval = 0.1
	it._next_in = 0.0                                # hộp đầu đã mọc: bỏ phần giờ đang đếm dở của khoảng 6 giây cũ
	var most := 0
	for i in 70:
		await _frames(1)
		most = maxi(most, it.boxes.size())
	_expect(most == 2 and it.boxes.size() == 2, "at most max_boxes (2) boxes are on the field (peak %d)" % most)
	var ids_seen := {}
	for bx in it.boxes:
		ids_seen[bx.item_id] = true
	# nhặt một hộp thì hộp mới mọc lại
	var picks := []
	it.item_picked.connect(func(ball: Ball, id: String) -> void: picks.append([ball, id]))
	var target_box = it.boxes[0]
	var target_id: String = target_box.item_id
	a.teleport(target_box.position + Vector2(0, 7))
	await _frames(3)
	_expect(it.held[0] == target_id and picks.size() == 1 and picks[0][0] == a and picks[0][1] == target_id and not it.boxes.has(target_box) and br.hud.item_ids[0] == target_id, "touching a box with an empty hand picks the item up (%s), the HUD slot shows it" % target_id)
	await _frames(30)
	_expect(it.boxes.size() == 2, "a new box appears after one was picked (%d boxes)" % it.boxes.size())
	it.enabled = false
	_items_clear_boxes(it)
	br.queue_free()
	await _frames(2)

	# --- Hộp: chỗ đặt hợp lệ ở cả hai đấu trường, nhiều lần ---
	for arena in BrawlData.ARENAS.size():
		br = await _item_br(arena)
		it = br.items
		a = br.balls[0]
		b = br.balls[1]
		var bad := []
		var spots := {}
		var high := 0
		var count_ok := 0
		for i in 80:
			var bx = it.spawn_box()
			if bx == null:
				bad.append("no spot found")
				continue
			var problem := _spot_problem(br, bx.position)
			if problem != "":
				bad.append(problem)
			if not it.is_valid_spot(bx.position):
				bad.append("is_valid_spot disagrees")
			if a.global_position.distance_to(bx.position) < 100.0 or b.global_position.distance_to(bx.position) < 100.0:
				bad.append("on top of a player")
			if bx.position.y < ground - 100.0:
				high += 1
			spots[bx.position] = true
			count_ok += 1
			_items_clear_boxes(it)
		_expect(bad.is_empty() and count_ok == 80, "arena %d: 80 random box spots are all on ground / platforms, never in terrain, over a pit, on spikes / trampolines, on a spawn or on a player (%s)" % [arena, str(bad.slice(0, 3))])
		_expect(spots.size() >= 12 and high > 0, "arena %d: spots vary (%d different, %d on platforms)" % [arena, spots.size(), high])
		# chỗ xấu bị từ chối
		var rows := br.level.rows
		var bad_ok := true
		var bad_where := ""
		for r in rows.size():
			for c in range(1, rows[r].length() - 1):
				if r < 2:
					continue
				var pos := Vector2((c + 0.5) * 32.0, r * 32.0 - BrawlItems.BOX_LIFT)
				var mine := it.is_valid_spot(pos)
				var theirs := _spot_problem(br, pos) == ""
				if mine != theirs:
					bad_ok = false
					bad_where = "%d,%d" % [r, c]
		_expect(bad_ok, "arena %d: is_valid_spot agrees with the map on every cell (%s)" % [arena, bad_where])
		_expect(not it.is_valid_spot(Vector2(640, 600)) and not it.is_valid_spot(br.spawn_points[0]) and not it.is_valid_spot(Vector2(100, 100)), "arena %d: a pit, a spawn cell and mid-air are rejected" % arena)
		br.queue_free()
		await _frames(2)

	# --- Hộp không nằm trên gai chống câu giờ ---
	br = await _item_br(0)
	it = br.items
	var near_spike := Vector2(112.0, 640.0 - BrawlItems.BOX_LIFT)   # cột 3 hàng 19 là chỗ xuất phát: dùng cột 5
	near_spike = Vector2(5.5 * 32.0, 640.0 - BrawlItems.BOX_LIFT)
	_expect(it.is_valid_spot(near_spike), "a floor spot is fine before the stall spikes grow")
	br._add_stall_spike(5)
	_expect(not it.is_valid_spot(near_spike), "a spot on a stall spike is rejected")
	var doomed = it.spawn_box("gun", near_spike + Vector2(-64, 0))
	br._add_stall_spike(4)
	await _frames(3)
	_expect(not it.boxes.has(doomed), "a box that ends up on a fresh stall spike is removed")
	for s in br.stall_spikes:
		s.queue_free()
	br.queue_free()
	await _frames(2)

	# --- Nhặt: chỉ khi tay trống; người kia nhặt được ---
	br = await _item_br(0)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	it.give(a, "banana")
	var full_box = it.spawn_box("swap", a.global_position + Vector2(0, -7))
	await _frames(5)
	_expect(it.held[0] == "banana" and it.boxes.has(full_box), "a full hand cannot pick up another item (box stays)")
	var theirs_box = it.spawn_box("spring", b.global_position + Vector2(0, -7))
	await _frames(5)
	_expect(it.held[1] == "spring" and not it.boxes.has(theirs_box) and it.held[0] == "banana", "the other player (empty hand) picks up their own box")
	a.dead = true
	it.held[0] = ""
	await _frames(3)
	_expect(it.held[0] == "" and it.boxes.has(full_box), "a dead ball cannot pick up a box")
	a.dead = false
	await _frames(3)
	_expect(it.held[0] == "swap", "...and picks it up as soon as it is alive and empty-handed again")
	br.queue_free()
	await _frames(2)

	# --- GUN: 3 phát, đạn đẩy đối thủ chứ không đẩy người bắn, không gây sát thương ---
	br = await _item_br(0)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	var used := []
	it.item_used.connect(func(ball: Ball, id: String) -> void: used.append([ball, id]))
	it.give(a, "gun")
	_expect(it.held[0] == "gun" and a.ammo == 3 and a.bullet_knockback > 0.0 and br.hud.item_ids[0] == "gun", "GUN: 3 shots of pushing bullets, shown on the HUD")
	await _item_place(a, Vector2(60, gy))
	await _item_place(b, Vector2(100, gy))
	a.facing = 1
	var a_x0 := a.global_position.x
	var b_x0 := b.global_position.x
	var peak_vx := 0.0
	var a_peak := 0.0
	it.use(a)
	_expect(a.ammo == 2 and it.held[0] == "gun" and used.size() == 1, "GUN: one press fires one shot (2 left)")
	it.use(a)                                        # bấm lại ngay: súng đang chờ giữa hai phát
	_expect(a.ammo == 2, "GUN: pressing again during the cooldown does not waste a shot")
	for i in 60:
		await _frames(1)
		peak_vx = maxf(peak_vx, b.linear_velocity.x)
		a_peak = maxf(a_peak, absf(a.linear_velocity.x))
	var shoved := b.global_position.x - b_x0
	print("    (gun: victim peak vx %.0f, shoved %.0f px, shooter moved %.1f px, peak vx %.0f)" % [peak_vx, shoved, a.global_position.x - a_x0, a_peak])
	_expect(peak_vx > 450.0 and shoved > 120.0, "GUN: the bullet shoves the opponent hard (peak vx %.0f, moved %.0f px)" % [peak_vx, shoved])
	_expect(absf(a.global_position.x - a_x0) < 6.0 and a_peak < 60.0, "GUN: the shooter is not pushed")
	_expect(br.scores == [0, 0] and not b.dead and not a.dead, "GUN: a hit never hurts anyone (score %s)" % str(br.scores))
	a.facing = -1                                   # hai phát sau bắn vào tường bên trái, khỏi đẩy b vào gai
	await _item_place(b, Vector2(100, gy))
	it.use(a)
	await _frames(14)
	it.use(a)
	_expect(a.ammo == 0 and it.held[0] == "" and a.bullet_knockback == 0.0 and used.size() == 3 and br.hud.item_ids[0] == "", "GUN: the third shot empties the hand and the gun mode is gone (used %d times)" % used.size())
	await _frames(14)
	it.use(a)
	_expect(used.size() == 3 and a.ammo == 0, "GUN: no fourth shot")
	# đạn đẩy xuống vực khi đứng sát mép
	await _item_place(b, Vector2(720, gy))
	await _item_place(a, Vector2(752, gy))
	a.facing = -1
	it.give(a, "gun")
	var kills := []
	br.point_scored.connect(func(scorer: Ball, victim: Ball, cause: String) -> void: kills.append([scorer, victim, cause]))
	it.use(a)
	await _frames(100)
	print("    (gun at the edge: %s)" % str(kills))
	_expect(kills.size() == 1 and kills[0][1] == b and kills[0][2] == "pit" and br.scores == [1, 0], "GUN: a hit near a pit edge can push the opponent into the pit (score %s)" % str(br.scores))
	br.queue_free()
	await _frames(2)

	# --- BANANA: đối thủ bị đảo phím có thời hạn, có hình báo hiệu, dọn sạch ---
	br = await _item_br(0)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	it.banana_seconds = 0.6
	it.give(a, "banana")
	it.use(a)
	await _frames(2)
	_expect(b.reverse_controls and not a.reverse_controls and it.held[0] == "" and _count_children(b, BrawlItems.BananaMark) == 1 and _count_children(a, BrawlItems.BananaMark) == 0, "BANANA: the opponent is reversed (the thrower is not) and wears a banana mark")
	_expect(br.hud.message_label.text.begins_with("BANANA!") and br.hud.message_label.modulate.a > 0.5, "BANANA: the HUD announces it ('%s')" % br.hud.message_label.text)
	Input.action_press("p2_left")
	await _frames(12)
	_expect(b.charge_dir == 1, "BANANA: the victim holding LEFT charges RIGHT (%d)" % b.charge_dir)
	_release_all_keys()
	await _frames(45)                                # 0.6 giây hết giờ
	_expect(not b.reverse_controls and _count_children(b, BrawlItems.BananaMark) == 0, "BANANA: ends by itself, the keys are normal and the mark is gone")
	Input.action_press("p2_left")
	await _frames(12)
	_expect(b.charge_dir == -1, "BANANA: after it ends LEFT charges left again")
	_release_all_keys()
	# đối thủ đang chết: không ném được, chuối còn trong tay
	await _frames(5)
	it.give(a, "banana")
	b.dead = true
	it.use(a)
	_expect(it.held[0] == "banana" and not b.reverse_controls, "BANANA: cannot be thrown at a dead opponent (item kept)")
	b.dead = false
	br.queue_free()
	await _frames(2)

	# --- CHUỐI + sự kiện REVERSED KEYS: hai thứ tự, cái nào hết trước cũng đúng ---
	br = await _item_br(0, 0.3, false, true)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	var ev := br.events
	ev.reversed_keys_seconds = 30.0
	# thứ tự 1: sự kiện trước, chuối sau; sự kiện hết trước
	ev.start_event("reversed_keys")
	it.banana_seconds = 1.0
	it.give(a, "banana")
	it.use(a)
	await _frames(2)
	_expect(a.reverse_controls and b.reverse_controls, "REVERSED KEYS then BANANA: both reversed")
	ev.stop_event()
	await _frames(2)
	_expect(b.reverse_controls and not a.reverse_controls, "...the event ends first: only the banana victim stays reversed")
	await _frames(70)
	_expect(not a.reverse_controls and not b.reverse_controls and _count_children(b, BrawlItems.BananaMark) == 0, "...then the banana ends: nobody is reversed")
	# thứ tự 2: chuối trước, sự kiện sau; chuối hết trước
	it.banana_seconds = 1.0
	it.give(a, "banana")
	it.use(a)
	await _frames(2)
	ev.start_event("reversed_keys")
	await _frames(2)
	_expect(a.reverse_controls and b.reverse_controls, "BANANA then REVERSED KEYS: both reversed")
	await _frames(70)
	_expect(a.reverse_controls and b.reverse_controls, "...the banana ends first: both are still reversed by the event (the victim is not un-reversed)")
	ev.stop_event()
	await _frames(2)
	_expect(not a.reverse_controls and not b.reverse_controls, "...the event ends: nobody is stuck reversed")
	# thứ tự 3: chuối trước, sự kiện bắt đầu và hết trong lúc chuối còn
	it.banana_seconds = 1.5
	it.give(a, "banana")
	it.use(a)
	ev.start_event("reversed_keys")
	await _frames(2)
	ev.stop_event()
	await _frames(2)
	_expect(b.reverse_controls and not a.reverse_controls, "BANANA, event starts and ends meanwhile: the victim is still reversed by the banana, the other is normal")
	await _frames(110)
	_expect(not b.reverse_controls and not a.reverse_controls, "...and the banana ending leaves everyone normal")
	# nạn nhân chết giữa chuối + sự kiện
	it.banana_seconds = 5.0
	it.give(a, "banana")
	it.use(a)
	ev.start_event("reversed_keys")
	await _frames(2)
	br.kill(b, "pit")                                # b chết: hết chuối, nhưng sự kiện vẫn đang chạy
	await _frames(2)
	_expect(_count_children(b, BrawlItems.BananaMark) == 0 and b.reverse_controls, "the victim dying ends the banana, the event still reverses it")
	await _frames(50)
	_expect(not b.dead and b.reverse_controls and a.reverse_controls, "the respawned victim is reversed by the event only")
	ev.stop_event()
	await _frames(2)
	_expect(not a.reverse_controls and not b.reverse_controls, "everything is back to normal when the event ends")
	br.queue_free()
	await _frames(2)

	# --- SWAP: đổi chỗ và vận tốc ---
	br = await _item_br(0)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	a.teleport(Vector2(300, 300))
	b.teleport(Vector2(900, 250))
	await _frames(3)
	a.linear_velocity = Vector2(120, 0)
	b.linear_velocity = Vector2(-60, 0)
	await _frames(1)
	var pa := a.global_position
	var pb := b.global_position
	var va := a.linear_velocity.x
	var vb := b.linear_velocity.x
	it.give(b, "swap")
	it.use(b)
	await _frames(4)
	_expect(a.global_position.distance_to(pb) < 40.0 and b.global_position.distance_to(pa) < 40.0, "SWAP: the two players traded places (P1 %s -> %s)" % [pa.round(), a.global_position.round()])
	_expect(absf(a.linear_velocity.x - vb) < 25.0 and absf(b.linear_velocity.x - va) < 25.0 and it.held[1] == "", "SWAP: velocities traded too, the item is used up")
	b.dead = true
	it.give(a, "swap")
	it.use(a)
	_expect(it.held[0] == "swap", "SWAP: not usable while the opponent is dead (item kept)")
	b.dead = false
	br.queue_free()
	await _frames(2)

	# --- SPRING TRAP ---
	br = await _item_br(0)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	it.give(a, "spring")
	await _item_place(a, Vector2(150, gy))
	it.use(a)
	_expect(it.held[0] == "" and it.traps.size() == 1, "SPRING: using it drops one trap and empties the hand")
	var trap = it.traps[0]
	_expect(absf(trap.position.x - a.global_position.x) < 4.0 and absf(trap.position.y - ground) < 2.0 and not trap.armed, "SPRING: the trap lies at the user's feet on the ground and is not armed yet (%s)" % trap.position)
	await _frames(15)                                # 0,25 giây, chưa lên cò: bóng đứng trên bẫy vẫn đứng yên
	_expect(a.global_position.y > gy - 3.0 and it.traps.size() == 1 and not trap.armed, "SPRING: an unarmed trap does nothing")
	a.teleport(Vector2(220, gy))                     # chủ bước ra xa trước khi lên cò
	await _frames(25)
	_expect(trap.armed and it.traps.size() == 1, "SPRING: the trap arms after about half a second")
	var sprung := []
	it.trap_sprung.connect(func(ball: Ball) -> void: sprung.append(ball))
	await _item_place(b, Vector2(trap.position.x, gy), 1)   # đối thủ giẫm lên
	var apex := gy
	for i in 80:
		await _frames(1)
		apex = minf(apex, b.global_position.y)
	print("    (spring: launched %.0f px high)" % (gy - apex))
	_expect(sprung.size() == 1 and sprung[0] == b and gy - apex > 400.0, "SPRING: the armed trap launches whoever touches it high into the air (%.0f px)" % (gy - apex))
	_expect(it.traps.is_empty() and (not is_instance_valid(trap) or trap.get_parent() == null), "SPRING: the trap disappears after it fired")
	print("    (a normal full jump rises about %.0f px)" % (pow(a.max_speed, 2) / (2.0 * 1400.0)))
	# chủ cũng bị bắn
	await _item_place(b, Vector2(1000, gy))
	await _item_place(a, Vector2(100, gy))
	it.give(a, "spring")
	it.use(a)
	await _frames(26)                                # a vẫn đứng ngay trên bẫy; lên cò sau 30 khung
	apex = gy
	for i in 60:
		await _frames(1)
		apex = minf(apex, a.global_position.y)
	_expect(sprung.size() == 2 and sprung[1] == a and gy - apex > 400.0, "SPRING: the owner is launched too when still standing on it (%.0f px)" % (gy - apex))
	# tự biến mất
	await _item_place(b, Vector2(1000, gy))
	await _item_place(a, Vector2(300, gy))
	await _frames(100)                               # chờ chủ rơi xuống lại
	it.spring_life_seconds = 1.0
	await _item_place(a, Vector2(150, gy))
	it.give(a, "spring")
	it.use(a)
	await _item_place(a, Vector2(260, gy), 1)
	_expect(it.traps.size() == 1, "SPRING: a trap is waiting (life 1 s for the test)")
	await _frames(80)
	_expect(it.traps.is_empty() and sprung.size() == 2, "SPRING: an untouched trap disappears on its own after its lifetime")
	# không có đất dưới chân: không thả được
	it.give(a, "spring")
	a.teleport(Vector2(640, 500))                    # giữa vực, dưới bệ giữa
	await _frames(2)
	it.use(a)
	_expect(it.held[0] == "spring" and it.traps.is_empty(), "SPRING: cannot be dropped over a pit (item kept)")
	br.queue_free()
	await _frames(2)

	# --- Mất vật phẩm khi chết, hiệu ứng dọn khi chết và hồi sinh ---
	br = await _item_br(0, 0.3, false, true)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	it.give(a, "gun")
	it.give(b, "spring")
	it.banana_seconds = 5.0
	var thrower_item := "banana"
	it.give(a, thrower_item)                         # a cầm chuối thay súng
	_expect(a.ammo == 0 and a.bullet_knockback == 0.0, "replacing a gun with another item drops the gun's ammo")
	it.use(a)                                        # b bị chuối
	it.give(a, "gun")
	await _frames(2)
	_expect(b.reverse_controls and it.held[1] == "spring" and it.held[0] == "gun", "(setup) P2 is bananaed and holds a spring, P1 holds a gun")
	br.kill(b, "pit")
	await _frames(2)
	_expect(it.held[1] == "" and not b.reverse_controls and _count_children(b, BrawlItems.BananaMark) == 0 and br.hud.item_ids[1] == "", "dying loses the held item and ends the banana at once")
	_expect(it.held[0] == "gun" and a.ammo == 3, "the other player keeps their gun")
	await _frames(50)
	_expect(not b.dead and it.held[1] == "" and not b.reverse_controls and b.ammo == 0, "after the respawn nothing is left over")
	br.kill(a, "pit")
	await _frames(2)
	_expect(it.held[0] == "" and a.ammo == 0 and a.bullet_knockback == 0.0 and br.hud.item_ids[0] == "", "a dead gun owner loses the gun and its ammo")
	await _frames(50)
	br.queue_free()
	await _frames(2)

	# --- Hết trận: dọn hộp, bẫy, vật phẩm, hiệu ứng; không sinh gì thêm ---
	br = await _item_br(0, 0.3, false, true)
	it = br.items
	a = br.balls[0]
	b = br.balls[1]
	it.banana_seconds = 20.0
	it.give(b, "banana")
	it.use(b)                                        # a bị chuối
	it.give(b, "gun")
	await _item_place(a, Vector2(150, gy), 1)
	it.give(a, "spring")
	it.use(a)
	it.spawn_box("swap")
	it.spawn_box("gun")
	await _frames(2)
	_expect(it.boxes.size() == 2 and it.traps.size() == 1 and a.reverse_controls and it.held[1] == "gun", "(setup) boxes, a trap, a banana and a held gun exist")
	br.scores[1] = Brawl.WIN_SCORE - 1
	br.kill(a, "pit")
	await _frames(3)
	_expect(not br.match_running and it.boxes.is_empty() and it.traps.is_empty() and it.held == ["", ""] and not a.reverse_controls and b.ammo == 0 and b.bullet_knockback == 0.0 and _count_children(a, BrawlItems.BananaMark) == 0 and br.hud.item_ids == ["", ""], "match end clears boxes, traps, held items and every effect")
	it.enabled = true
	it.first_delay = 0.0
	it.give(b, "gun")
	await _frames(40)
	_expect(it.spawn_box() == null and it.boxes.is_empty() and it.held == ["", ""], "after the match nothing spawns and nothing can be given")
	br.queue_free()
	await _frames(2)

	# --- Vương miện người dẫn điểm ---
	br = await _item_br(0)
	a = br.balls[0]
	b = br.balls[1]
	_expect(br.leader == null and a.size_factor == 1.0 and b.size_factor == 1.0 and _count_children(a, Brawl.CrownMarker) == 0, "crown: 0-0 means nobody is the leader")
	br.kill(b, "pit")
	await _frames(3)
	_expect(br.leader == a and is_equal_approx(a.size_factor, 1.25) and is_equal_approx(a.radius, 18.75) and _count_children(a, Brawl.CrownMarker) == 1 and _count_children(b, Brawl.CrownMarker) == 0 and b.size_factor == 1.0, "crown: the player with more points wears it and is 25% bigger")
	_expect(is_equal_approx((a.get_node("Shape") as CollisionShape2D).shape.radius, 18.75), "crown: the collision circle grew too")
	var crown: Node2D = a.find_children("*", "Node2D", false, false).filter(func(n: Node) -> bool: return n is Brawl.CrownMarker)[0]
	_expect(crown.position.y < -50.0 and crown.visible, "crown: it floats over the leader's head (y %.0f)" % crown.position.y)
	await _frames(50)                                # b hồi sinh
	br.kill(a, "pit")                                # 1-1: hoà
	await _frames(3)
	_expect(br.leader == null and a.size_factor == 1.0 and b.size_factor == 1.0 and _count_children(a, Brawl.CrownMarker) == 0 and _count_children(b, Brawl.CrownMarker) == 0, "crown: a tie means nobody has the crown or the size")
	await _frames(50)
	br.kill(a, "pit")                                # 1-2: b dẫn
	await _frames(3)
	_expect(br.leader == b and is_equal_approx(b.size_factor, 1.25) and a.size_factor == 1.0 and _count_children(b, Brawl.CrownMarker) == 1 and _count_children(a, Brawl.CrownMarker) == 0, "crown: when the lead changes the crown moves to the new leader")
	await _frames(50)
	# lãnh đạo chết mà vẫn dẫn: hồi sinh to và đội vương miện, đứng vững trên đất
	br.scores[1] = 3
	await _frames(2)
	br.kill(b, "pit")                                # P1 ghi: điểm [2,3], b vẫn dẫn
	await _frames(2)
	_expect(br.leader == b and b.dead, "crown: the leader dying while still ahead keeps the crown (scores %s)" % str(br.scores))
	await _frames(80)
	var top := 9999.0
	var bot := -9999.0
	for i in 40:
		await _frames(1)
		top = minf(top, b.global_position.y)
		bot = maxf(bot, b.global_position.y)
	_expect(not b.dead and br.leader == b and is_equal_approx(b.size_factor, 1.25) and _count_children(b, Brawl.CrownMarker) == 1 and b.visible, "crown: the leader respawns still big and crowned")
	_expect(absf(top - (ground - 18.75)) < 3.0 and absf(bot - (ground - 18.75)) < 3.0, "crown: the respawned big leader stands on the ground, no sinking or popping (y %.1f..%.1f, expected %.1f)" % [top, bot, ground - 18.75])
	# cùng sự kiện SUPER BOUNCE, SWAP!, HOT POTATO
	br.events.start_event("super_bounce")
	await _frames(30)
	_expect(br.leader == b and is_equal_approx(b.size_factor, 1.25) and b.physics_material_override.bounce > 0.9 and _count_children(b, Brawl.CrownMarker) == 1, "crown: SUPER BOUNCE leaves the size and crown alone")
	br.events.stop_event()
	await _frames(30)
	var pos_b := b.global_position
	var pos_a := a.global_position
	br.events.start_event("swap")
	var min_y := 9999.0
	for i in 45:
		await _frames(1)
		min_y = minf(min_y, b.global_position.y)
		min_y = minf(min_y, a.global_position.y)
	_expect(b.global_position.distance_to(pos_a) < 50.0 and a.global_position.distance_to(pos_b) < 50.0 and min_y > ground - 40.0 and b.on_ground and a.on_ground, "crown: SWAP! with a big leader: both land on the ground without sinking or popping up (min y %.0f)" % min_y)
	br.events.hot_potato_seconds = 10.0
	br.events.start_event("hot_potato")
	await _frames(3)
	var carrier := br.events.bomb_carrier
	var crown_y := -9999.0
	for cm in br.leader.get_children():
		if cm is Brawl.CrownMarker:
			crown_y = cm.position.y
	if carrier == br.leader:
		_expect(crown_y < -110.0, "crown: the leader carrying the HOT POTATO bomb wears the crown above the bomb (y %.0f)" % crown_y)
	else:
		_expect(crown_y > -90.0, "crown: the leader not carrying the bomb keeps the crown on the head (y %.0f)" % crown_y)
	br.events.stop_event()
	# hết trận: bỏ vương miện và cỡ
	br.scores[0] = Brawl.WIN_SCORE - 1
	br.scores[1] = 0
	await _frames(2)
	br.kill(b, "pit")
	await _frames(3)
	_expect(not br.match_running and br.leader == null and a.size_factor == 1.0 and b.size_factor == 1.0 and _count_children(a, Brawl.CrownMarker) == 0 and _count_children(b, Brawl.CrownMarker) == 0, "crown: cleared at match end (both back to normal size)")
	br.queue_free()
	await _frames(2)

	# --- Câu châm chọc ---
	var font := UiTheme.main_font()
	var widest := 0.0
	var widest_line := ""
	var all_ok := true
	var short_ok := true
	for cause in ["stomp", "pit", "spikes", "bomb", "default"]:
		var pool: Array = BrawlData.TAUNTS[cause]
		var distinct := {}
		for line in pool:
			distinct[line] = true
			for pair in [[1, 2], [2, 1]]:
				var text := String(line).format({"s": "P%d" % pair[0], "v": "P%d" % pair[1]})
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE).x
				if w > widest:
					widest = w
					widest_line = text
				if w > 1000.0 or text.contains("{") or text != text.to_ascii_buffer().get_string_from_ascii() or text.length() > 40:
					short_ok = false
		_expect(pool.size() >= 5 and distinct.size() == pool.size(), "taunts '%s': %d different lines (>= 5)" % [cause, pool.size()])
	_expect(short_ok, "taunts: every line (with P1 / P2) is ASCII and fits in 1000 px at FONT_LARGE on one line (widest %.0f px: '%s')" % [widest, widest_line])
	br = await _item_br(0)
	a = br.balls[0]
	b = br.balls[1]
	for cause in ["stomp", "pit", "spikes", "bomb", "other"]:
		var seen := {}
		var repeat := false
		var last := ""
		for i in 300:
			var text := br._point_text(a if i % 2 == 0 else b, b if i % 2 == 0 else a, cause)
			var s_id := 1 if i % 2 == 0 else 2
			if text == last:
				repeat = true
			last = text
			seen[text] = true
			if not text in _taunt_options(cause, s_id, 3 - s_id):
				repeat = true
		var expected_total: int = BrawlData.TAUNTS.get(cause, BrawlData.TAUNTS["default"]).size() * 2
		_expect(not repeat and seen.size() >= expected_total - 2, "taunts '%s': 300 picks never repeat back to back, use the right names and cover the pool (%d of %d texts)" % [cause, seen.size(), expected_total])
	await _frames(50)
	br.kill(b, "pit")
	_expect(br.hud.message_label.text in _taunt_options("pit", 1, 2), "taunts: a real pit point shows one of the pit lines ('%s')" % br.hud.message_label.text)
	await _frames(50)
	br.kill(a, "spikes")
	_expect(br.hud.message_label.text in _taunt_options("spikes", 2, 1), "taunts: a real spikes point shows one of the spikes lines ('%s')" % br.hud.message_label.text)
	br.queue_free()
	await _frames(2)


## Rút ngắn mọi giờ chờ của SUDDEN DEATH và coi như sàn không còn cột nào để mọc gai (xoá danh sách cột): hàng gai dâng bắt đầu chừng 0,3 giây sau, dâng `speed` pixel/giây.
func _sd_fast(br: Brawl, speed: float) -> void:
	br.stall_timeout = 0.2
	br.sudden_death_delay = 0.1
	br.sudden_death_speed = speed
	br._reset_stall()                                # tính giờ lại từ bây giờ
	br._stall_left.clear()                           # không còn cột sàn nào để mọc gai
	br._stall_right.clear()


## Số hình hàng gai dâng (Brawl.HazardRow) đang nằm trong màn.
func _hazard_rows(br: Brawl) -> int:
	var n := 0
	for child in br.level.get_children():
		if child is Brawl.HazardRow:
			n += 1
	return n


## SUDDEN DEATH (hàng gai dâng khi sàn đã kín gai mà vẫn chưa ai ghi điểm): giá trị mặc định, thời điểm bắt đầu, dâng lên, giết người đứng sàn,
## bệ cao nhất sống tới khi gai chạm, có điểm thì dọn sạch và tính giờ lại, hồi sinh không rơi vào gai, không chạy trước / sau trận.
func _brawl_sudden_death_checks() -> void:
	for c in get_children():                         # dọn cảnh còn sót lại
		c.queue_free()
	await _frames(3)

	# --- Giá trị mặc định: đủ chậm để phản ứng, đủ nhanh để tới bệ cao nhất trong ~25 giây ---
	var probe: Brawl = load("res://scenes/brawl.tscn").instantiate()   # chưa thêm vào cảnh: chỉ để đọc giá trị mặc định
	var def_speed: float = probe.sudden_death_speed
	_expect(probe.sudden_death_delay >= 2.0 and probe.sudden_death_delay <= 8.0 and def_speed >= 25.0 and def_speed <= 45.0 and not probe.sudden_death_active and probe.hazard_y() == INF, "sudden death defaults: delay %.1f s, speed %.0f px/s, inactive, hazard_y() is INF" % [probe.sudden_death_delay, def_speed])
	probe.free()
	for i in BrawlData.ARENAS.size():
		var rows: PackedStringArray = []
		for line in String(BrawlData.ARENAS[i]["map"]).split("\n"):
			if line.strip_edges() != "":
				rows.append(line)
		var top_row := rows.size()                   # hàng của bệ cao nhất (hàng đầu tiên có đất ở giữa)
		for r in rows.size():
			for c in range(1, rows[r].length() - 1):
				if rows[r][c] == "#":
					top_row = mini(top_row, r)
		var to_top := (rows.size() - top_row) * Level.TILE / def_speed   # từ đáy tới mặt bệ cao nhất
		var to_ceiling := (rows.size() * Level.TILE + 16.0) / def_speed  # từ đáy tới trần
		_expect(to_top >= 8.0 and to_top <= 25.0 and to_ceiling <= 25.0, "arena %d: the rising spikes need %.1f s to reach the highest platform (reaction time >= 8 s) and %.1f s to reach the ceiling (<= 25 s)" % [i, to_top, to_ceiling])

	# --- Bắt đầu sau khi sàn kín gai (và chờ đủ giờ), hàng gai dâng, người miễn sát thương không bị giết, có điểm thì dọn sạch và tính giờ lại ---
	var br := await _make_brawl(0)
	await _brawl_ready(br)
	br.stall_timeout = 0.3
	br.stall_step = 0.05
	br.sudden_death_delay = 0.5
	br.sudden_death_speed = 120.0
	br._reset_stall()
	var a := br.balls[0]
	var b := br.balls[1]
	a.invuln = 9999.0                                # đứng giữa gai sàn mà không chết, để thử riêng hàng gai dâng
	b.invuln = 9999.0
	var full_frames := 0                             # số khung từ lúc sàn kín tới lúc bắt đầu
	for i in 600:
		await _frames(1)
		if br.sudden_death_active:
			break
		if br._stall_left.is_empty() and br._stall_right.is_empty():
			full_frames += 1
	_expect(br.sudden_death_active and br.stall_spikes.size() >= 10 and br._stall_left.is_empty() and br._stall_right.is_empty(), "sudden death starts only after the floor is full of stall spikes (%d spikes)" % br.stall_spikes.size())
	_expect(full_frames >= 28 and full_frames <= 34, "...and after the configured delay (%d frames for 0.5 s)" % full_frames)
	_expect(absf(br.hazard_y() - br.level.size.y) < 5.0 and br.hud.message_label.text == "SUDDEN DEATH!" and _hazard_rows(br) == 1, "the hazard starts at the bottom of the arena (y=%.0f), flashes SUDDEN DEATH! and draws one spike row" % br.hazard_y())
	var y1 := br.hazard_y()
	await _frames(30)
	var y2 := br.hazard_y()
	_expect(absf((y1 - y2) - 60.0) < 3.0, "the hazard rises at sudden_death_speed (%.1f px in 0.5 s, expected 60)" % (y1 - y2))
	await _frames(20)
	_expect(br.hazard_y() < a.global_position.y and br.scores == [0, 0] and not a.dead and not b.dead, "players with spawn protection are ignored by the hazard (it is above them and nobody died)")
	br.kill(b, "pit")                                # có điểm: dọn sạch
	await _frames(2)
	_expect(not br.sudden_death_active and br.hazard_y() == INF and br.stall_spikes.is_empty() and not br.stall_active and _hazard_rows(br) == 0 and br._stall_time < 0.2, "a point clears the hazard and the stall spikes and restarts the timer")
	await _frames(12)                                # chưa tới 0,3 giây
	_expect(not br.stall_active and not br.sudden_death_active and br.hazard_y() == INF, "nothing restarts before the stall timeout has passed again")
	await _frames(30)
	b.invuln = 9999.0                                # P2 đã hồi sinh: đứng giữa gai sàn không chết
	var again := false
	for i in 600:
		await _frames(1)
		if br.sudden_death_active:
			again = true
			break
	_expect(again and _hazard_rows(br) == 1, "...and sudden death comes back after another full quiet period")
	await _free_brawl(br)

	# --- Người đứng sàn chết, đối thủ (đứng bệ cao) được điểm ---
	br = await _make_brawl(0)
	await _brawl_ready(br)
	a = br.balls[0]
	b = br.balls[1]
	var causes: Array[String] = []
	br.point_scored.connect(func(_s: Ball, _v: Ball, cause: String) -> void: causes.append(cause))
	b.teleport(Vector2(640, 340))                    # P2 lên bệ cao nhất ở giữa, P1 đứng ở chỗ xuất phát trên sàn
	_sd_fast(br, 150.0)
	await _frames(8)
	_expect(a.global_position.y > 600.0 and not a.dead and br.scores == [0, 0] and not br.sudden_death_active, "P1 stands on the floor, P2 on the top platform, nothing has happened yet")
	for i in 300:
		await _frames(1)
		if br.scores[0] + br.scores[1] > 0:
			break
	_expect(br.scores == [0, 1] and causes == ["spikes"] and not b.dead, "the player on the floor dies to the rising spikes and the opponent gets the point (scores %s, causes %s)" % [str(br.scores), str(causes)])
	_expect(not br.sudden_death_active and br.hazard_y() == INF and _hazard_rows(br) == 0, "the hazard is removed after the kill")
	await _free_brawl(br)

	# --- Người đứng bệ cao nhất sống tới khi gai tới chân, rồi chết ---
	br = await _make_brawl(0)
	await _brawl_ready(br)
	a = br.balls[0]
	b = br.balls[1]
	a.teleport(Vector2(560, 340))                    # cả hai lên bệ cao nhất (mặt bệ y = 384); P2 miễn sát thương để chỉ xét P1
	b.teleport(Vector2(720, 340))
	b.invuln = 9999.0
	await _frames(60)
	var feet := a.global_position.y + a.radius
	_expect(absf(feet - 384.0) < 4.0, "P1 stands on the highest platform (feet at y=%.1f, platform top 384)" % feet)
	_sd_fast(br, 120.0)
	var prev_y := INF
	var prev_feet := 0.0
	var seen_above := false                          # đã thấy hàng gai dâng qua đất mà P1 vẫn sống
	var died := false
	for i in 600:
		prev_y = br.hazard_y()
		prev_feet = a.global_position.y + a.radius
		await _frames(1)
		if br.scores[1] > 0:
			died = true
			break
		if prev_y < INF and prev_y > prev_feet + 20.0 and prev_y < 600.0:
			seen_above = true
	_expect(seen_above and died and br.scores == [0, 1], "the hazard passes through the floor and lower platforms; P1 on the highest platform survives while it is below")
	_expect(prev_y - prev_feet < 120.0 / 60.0 + 3.0 and prev_y - prev_feet > -3.0 and prev_y < 400.0, "...and dies exactly when the spike line reaches its feet (line at y=%.1f, feet at y=%.1f)" % [prev_y, prev_feet])
	await _free_brawl(br)

	# --- Hồi sinh lúc đang SUDDEN DEATH không rơi vào gai ---
	br = await _make_brawl(0)
	await _brawl_ready(br)
	a = br.balls[0]
	b = br.balls[1]
	br.respawn_delay = 2.0                           # chờ lâu: hàng gai kịp dâng cao hơn chỗ hồi sinh
	br.kill(a, "pit")                                # P2 được điểm; P1 vỡ, sắp hồi sinh
	_sd_fast(br, 300.0)                              # (kill vừa tính lại giờ; đặt lại sau nó)
	b.invuln = 9999.0                                # P2 không bị hàng gai giết (không làm điểm mới xoá hàng gai)
	var respawned := false
	for i in 400:
		await _frames(1)
		if a.visible and not a.dead:
			respawned = true
			break
	_expect(respawned and br.sudden_death_active, "P1 respawns while sudden death is active (hazard y=%.1f)" % br.hazard_y())
	_expect(br.hazard_y() > a.global_position.y + a.radius + 30.0 and a.invuln > 0.0, "respawn rule: the hazard is lowered under the respawn point (hazard y=%.1f, feet y=%.1f)" % [br.hazard_y(), a.global_position.y + a.radius])
	await _frames(60)                                # cả khoảng miễn sát thương: hàng gai giữ yên, P1 không chết
	_expect(not a.dead and br.scores == [0, 1] and br.hazard_y() > a.global_position.y + a.radius, "...and the respawned player is not killed by the hazard afterwards (scores %s)" % str(br.scores))
	await _free_brawl(br)

	# --- Không chạy trước trận (đang READY...) ---
	br = await _make_brawl(0, 1.0)                   # giới thiệu 1 giây
	br.stall_timeout = 0.01
	br.stall_step = 0.01
	br.sudden_death_delay = 0.01
	await _frames(30)
	_expect(not br.match_running and not br.stall_active and not br.sudden_death_active and br.hazard_y() == INF and _hazard_rows(br) == 0, "nothing happens before the match starts (intro)")
	await _free_brawl(br)

	# --- Không chạy sau khi hết trận; hết trận giữa lúc đang dâng thì dọn hàng gai ---
	br = await _make_brawl(0)
	await _brawl_ready(br)
	a = br.balls[0]
	b = br.balls[1]
	a.invuln = 9999.0
	b.invuln = 9999.0
	_sd_fast(br, 120.0)
	for i in 300:
		await _frames(1)
		if br.sudden_death_active:
			break
	_expect(br.sudden_death_active and _hazard_rows(br) == 1, "sudden death is running before the match ends")
	br.scores[0] = Brawl.WIN_SCORE - 1
	br.kill(b, "pit")                                # điểm thứ 5: hết trận
	await _frames(2)
	_expect(not br.match_running and not br.sudden_death_active and br.hazard_y() == INF and _hazard_rows(br) == 0 and br.stall_spikes.is_empty(), "the hazard and stall spikes are removed when the match ends")
	await _frames(120)                               # giờ vẫn rút ngắn: nếu còn chạy thì đã bắt đầu lại
	_expect(not br.stall_active and not br.sudden_death_active and br.hazard_y() == INF and _hazard_rows(br) == 0, "nothing restarts after the match is over")
	await _free_brawl(br)


## Dựng một trận đấu với máy ở đấu trường `arena`, đã hết giới thiệu, không có sự kiện / hộp tự sinh. Đặt lại hạt giống ngẫu nhiên (`rng_seed`)
## để mỗi mục kiểm tra chạy y hệt nhau mọi lần, không phụ thuộc mục trước. Cờ Game.brawl_vs_bot được trả về false ngay sau khi dựng.
func _bot_br(arena: int, rng_seed: int) -> Brawl:
	seed(rng_seed + bot_seed_offset)                 # bot dùng randf / randi / randfn toàn cục
	Game.brawl_vs_bot = true
	var br := await _make_brawl(arena, 0.2)          # sự kiện và hộp tự sinh đã tắt
	Game.brawl_vs_bot = false                        # các bài sau không bị dính cờ
	await _brawl_ready(br)
	return br


## Xoá cảnh đấu sau khi các hẹn giờ của nó chạy hết. Xoá ngay sau một cú giết thì cảnh dẹt / hồi sinh / bảng thắng (await hẹn giờ) bị bỏ dở,
## hẹn giờ và hàm chờ rò rỉ tới lúc thoát chương trình ("ObjectDB instances leaked", "resources still in use").
func _free_brawl(br: Brawl) -> void:
	if br.bot != null:
		br.bot.enabled = false                       # bot ngừng chơi: không có cú giết mới nào mở thêm hẹn giờ trong lúc chờ
	await _frames(150)                               # 2,5 giây: dài hơn mọi hẹn giờ trong cảnh (dẹt 0,6 + hồi sinh 0,3, bảng thắng, hạt 1,2)
	br.queue_free()
	await _frames(2)


## Tóm tắt trạng thái bot để in kèm khi một mục kiểm tra thất bại.
func _bot_state(bot: BrawlBot) -> String:
	return "[bot at %s dead=%s phase=%s mode=%s hops=%d aborts=%d thoughts=%d last='%s' jump='%s']" % [bot.ball.global_position.round(), bot.ball.dead, bot.phase, bot.mode, bot.hops, bot.aborts, bot.thoughts, bot.last_choice, bot.last_jump]


## Có phím nào của người chơi `prefix` ("p1_" / "p2_") đang bị giữ không.
func _any_pressed(prefix: String) -> bool:
	for action in ["left", "right", "jump", "use"]:
		if Input.is_action_pressed(prefix + action):
			return true
	return false


## Máy (bot) chơi thay người chơi 2: chỉ có khi chơi với máy, chỉ bấm phím p2_*, nhả hết phím khi hết trận / bị xoá, đi về phía người chơi,
## không nhảy vào vực, nhặt hộp, dùng vật phẩm, ghi được điểm vào mục tiêu đứng yên.
func _brawl_bot_checks() -> void:
	for c in get_children():                         # dọn cảnh còn sót lại
		c.queue_free()
	await _frames(3)
	_release_all_keys()

	# --- Chỉ tạo bot khi chơi với máy; điều khiển người chơi 2; HUD và câu châm chọc ghi BOT ---
	Game.brawl_vs_bot = false
	var br := await _make_brawl(0, 0.2)
	_expect(br.bot == null and not br.vs_bot and br.player_name(br.balls[1]) == "P2", "2-player Brawl has no bot (brawl.bot is null, names stay P1 / P2)")
	await _free_brawl(br)                            # chờ hết phần giới thiệu (hẹn giờ) rồi mới xoá, không thì hẹn giờ bị bỏ dở và rò rỉ
	br = await _bot_br(0, 101)
	var bot: BrawlBot = br.bot
	var a := br.balls[0]
	var b := br.balls[1]
	_expect(bot != null and bot.get_parent() == br and br.vs_bot and bot.ball == b and bot.foe == a and bot.player_index == 1 and bot.skill > 0.0 and bot.skill < 1.0, "vs-bot Brawl creates a BrawlBot that controls player 2 (default skill %.2f)" % bot.skill)
	_expect(br.player_name(b) == "BOT" and br.player_name(a) == "P1" and br.hud.vs_bot, "the right-hand player is named BOT in bot mode (HUD flag set)")
	br.kill(b, "pit")
	_expect("BOT" in br.hud.message_label.text and not "P2" in br.hud.message_label.text, "taunts name the bot BOT, never P2 ('%s')" % br.hud.message_label.text)
	await _frames(60)
	br.kill(a, "pit")
	_expect(not "P2" in br.hud.message_label.text, "taunts about P1 never say P2 either ('%s')" % br.hud.message_label.text)
	await _frames(60)
	# --- Chỉ bấm phím p2_*, không bao giờ động tới phím p1_* ---
	var p1_pressed := 0
	var p2_pressed := 0
	var heard_launch := [0]
	b.launched.connect(func() -> void: heard_launch[0] += 1)
	for i in 240:
		await _frames(1)
		if _any_pressed("p1_"):
			p1_pressed += 1
		if _any_pressed("p2_"):
			p2_pressed += 1
	_expect(p1_pressed == 0 and p2_pressed > 0, "the bot presses only player 2's actions, never player 1's (p1 frames %d, p2 frames %d)" % [p1_pressed, p2_pressed])
	_expect(heard_launch[0] >= 1 and bot.hops >= 1, "the bot's real key presses make its ball jump (%d launches)" % heard_launch[0])
	# --- Nhả hết phím khi hết trận ---
	var waited := 0
	while bot.held_actions().is_empty() and waited < 600:   # đợi tới lúc bot đang giữ phím
		await _frames(1)
		waited += 1
	_expect(not bot.held_actions().is_empty(), "the bot is holding a key before the match ends %s" % _bot_state(bot))
	br.scores[1] = Brawl.WIN_SCORE - 1
	br.kill(a, "pit")                                 # điểm thắng: hết trận
	await _frames(2)
	_expect(not br.match_running and bot.held_actions().is_empty() and not _any_pressed("p2_") and bot.phase == "idle", "all the bot's keys are released when the match ends")
	await _free_brawl(br)

	# --- Nhả hết phím khi bot bị xoá giữa chừng ---
	br = await _bot_br(1, 102)
	bot = br.bot
	waited = 0
	while bot.held_actions().is_empty() and waited < 600:
		await _frames(1)
		waited += 1
	_expect(_any_pressed("p2_"), "the bot holds a real p2 action (Input sees it)")
	bot.free()                                        # xoá ngay giữa lúc đang giữ phím
	_expect(not _any_pressed("p2_"), "all keys are released when the bot node is freed")
	await _free_brawl(br)

	# --- Chết thì nhả hết phím ---
	br = await _bot_br(1, 103)
	bot = br.bot
	waited = 0
	while bot.held_actions().is_empty() and waited < 600:
		await _frames(1)
		waited += 1
	br.kill(br.balls[1], "pit")
	await _frames(2)
	_expect(bot.held_actions().is_empty() and not _any_pressed("p2_"), "the bot lets go of every key when its ball dies")
	await _free_brawl(br)

	# --- Đi / nhảy về phía người chơi ---
	br = await _bot_br(0, 104)
	bot = br.bot
	a = br.balls[0]
	b = br.balls[1]
	a.teleport(Vector2(60, 625))                      # người chơi 1 đứng yên ở góc trái
	b.teleport(Vector2(330, 625))                     # bot cùng bên, trước dãy gai: đường tới người chơi 1 là mặt đất phẳng
	await _frames(40)
	var start_gap := absf(b.global_position.x - a.global_position.x)
	var closest := start_gap                          # khoảng cách ngang gần nhất tới người chơi 1 trong 5 giây
	for i in 60 * 5:
		await _frames(1)
		closest = minf(closest, absf(b.global_position.x - a.global_position.x))
	_expect(bot.hops >= 2 and closest < start_gap - 100.0, "the bot hops toward the player (gap %.0f px -> closest %.0f px in 5 s, %d hops, now at %s)" % [start_gap, closest, bot.hops, b.global_position.round()])
	await _free_brawl(br)

	# --- Gần mép vực, mục tiêu không với tới: bot không tự nhảy xuống vực ---
	br = await _bot_br(0, 105)
	bot = br.bot
	a = br.balls[0]
	b = br.balls[1]
	a.teleport(Vector2(640, 150))                     # người chơi 1 lơ lửng cao trên vực, đứng yên (không ai với tới)
	await _frames(2)
	a.freeze = true
	b.teleport(Vector2(548, 625))                     # bot đứng sát mép vực giữa (vực từ x = 576 tới 704)
	var pit_deaths := [0]
	var death_info := [""]
	br.point_scored.connect(func(_s: Ball, v: Ball, cause: String) -> void:
		if v == b:
			pit_deaths[0] += 1
			death_info[0] = "%s at %s after '%s'" % [cause, v.global_position.round(), bot.last_jump])
	await _frames(60 * 12)
	_expect(pit_deaths[0] == 0 and br.scores[0] == 0 and not b.dead, "the bot never jumps into the pit or spikes while the target is out of reach (12 s, deaths %d, %d hops, aborts %d) %s" % [pit_deaths[0], bot.hops, bot.aborts, death_info[0]])
	a.freeze = false
	await _free_brawl(br)

	# --- Nhặt hộp gần, rồi dùng vật phẩm ---
	br = await _bot_br(0, 106)
	bot = br.bot
	a = br.balls[0]
	b = br.balls[1]
	b.teleport(Vector2(1000, 625))
	a.teleport(Vector2(60, 625))
	await _frames(40)
	var picked := []
	br.items.item_picked.connect(func(ball: Ball, id: String) -> void: picked.append([ball, id]))
	var box := br.items.spawn_box("banana", Vector2(1000 + 150, 640.0 - BrawlItems.BOX_LIFT))
	_expect(box != null and br.items.boxes.size() == 1, "a box was placed 150 px from the bot")
	await _frames(60 * 6)
	_expect(picked.any(func(p: Array) -> bool: return p[0] == b), "the bot walks to a nearby box and picks it up (%d picks)" % picked.size())
	# vật phẩm: cho chuối, đưa cả hai về chỗ gần nhau trên mặt đất; người chơi 1 miễn sát thương để bot không dẫm chết nó giữa chừng
	br.items.give(b, "banana")
	a.teleport(Vector2(760, 625))
	b.teleport(Vector2(1000, 625))
	a.invuln = 1000.0
	var used := []
	br.items.item_used.connect(func(ball: Ball, id: String) -> void: used.append([ball, id]))
	await _frames(60 * 4)
	_expect(used.any(func(p: Array) -> bool: return p[0] == b) and bot.items_used >= 1, "the bot uses an item it holds (%s; held '%s', bot %s dead=%s phase=%s mode=%s, P1 %s dead=%s)" % [str(used.map(func(p: Array) -> String: return p[1])), br.items.held[1], b.global_position.round(), b.dead, bot.phase, bot.mode, a.global_position.round(), a.dead])
	await _free_brawl(br)

	# --- Ghi điểm vào mục tiêu đứng yên trong thời gian hợp lý ---
	br = await _bot_br(0, 107)
	bot = br.bot
	a = br.balls[0]
	b = br.balls[1]
	a.teleport(Vector2(100, 625))                     # người chơi 1 đứng yên ở bên trái
	b.teleport(Vector2(340, 625))                     # bot cùng bên, trước dãy gai
	var frames_to_point := 0
	while br.scores[1] == 0 and frames_to_point < 60 * 30:
		await _frames(1)
		frames_to_point += 1
	_expect(br.scores[1] >= 1, "the bot scores at least one point against a standing target within 30 s (%.1f s) %s" % [frames_to_point / 60.0, _bot_state(bot)])
	await _free_brawl(br)
	_release_all_keys()


## Chế độ đấu có sẵn: dựng, chờ hết giới thiệu (hộp vật phẩm tự sinh tắt trừ khi `with_items`).
func _item_br(arena := 0, intro := 0.3, with_items := false, with_events := false) -> Brawl:
	var br := await _make_brawl(arena, intro, with_events, with_items)
	await _brawl_ready(br)
	return br


## Số node con của `node` thuộc lớp `type` (không tính cái đang chờ xoá).
func _count_children(node: Node, type: Variant) -> int:
	var n := 0
	for c in node.get_children():
		if is_instance_of(c, type) and not c.is_queued_for_deletion():
			n += 1
	return n


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


# ====================================================================================================================
# Chế độ Chained: dây đàn hồi, neo, súng cao su, hạt (sao xâu trên dây), chết chung, về đích, màn 1 qua được.
# ====================================================================================================================

## Vị trí tâm bóng đứng trên mặt ô (cột, hàng) của bản đồ (cùng công thức Chained._find_spawn; cột 63.5 = giữa ô cột 63).
func _cpos(col: float, row: float) -> Vector2:
	return Vector2(col * 32.0, (row + 1.0) * 32.0 - 16.0)


## Bản đồ phẳng `cols` cột x 15 hàng: phần trên trống, 3 hàng cuối là đất (mặt đất ở y = 384, tâm bóng đứng ở y = 369).
func _chained_flat_map(cols := 80, pillar_from := -1, pillar_to := -1) -> String:
	var rows: PackedStringArray = []
	for r in 12:                                       # 12 hàng trên: trống, có tường hai bên
		var row := "#" + ".".repeat(cols - 2) + "#"
		if pillar_from > 0 and r >= 9:                 # cột đất cao 3 ô (hàng 9..11) từ cột pillar_from tới pillar_to
			row = row.substr(0, pillar_from) + "#".repeat(pillar_to - pillar_from + 1) + row.substr(pillar_to + 1)
		rows.append(row)
	for r in 3:                                        # 3 hàng đất
		rows.append("#".repeat(cols))
	return "\n".join(rows)


## Bản đồ có hố không đáy: 24 hàng, mặt đất ở hàng 12 (y = 384), hố ở các cột pit_from..pit_to (bờ trái, bờ phải là đất tới tận đáy).
func _chained_pit_map(cols: int, pit_from: int, pit_to: int) -> String:
	var rows: PackedStringArray = []
	for r in 12:
		rows.append("#" + ".".repeat(cols - 2) + "#")
	for r in 12:
		rows.append("#".repeat(pit_from) + ".".repeat(pit_to - pit_from + 1) + "#".repeat(cols - 1 - pit_to))
	return "\n".join(rows)


## Hai bóng (người chơi 1 ở x1, người chơi 2 ở x2, cùng tầm y) nối bằng một Rope trong bản đồ `map`; chờ cho đứng yên. Trả về [màn, bóng 1, bóng 2, dây].
func _rope_rig(map: String, x1: float, x2: float, y: float, with_rope := true) -> Array:
	var lv := _make_level(map)
	var a := _make_ball(lv, Vector2(x1, y))
	var b := _make_ball(lv, Vector2(x2, y))
	a.set_player(1)
	b.set_player(2)
	a.set_collide_with_balls(true)
	b.set_collide_with_balls(true)
	var rope: Rope = null
	if with_rope:
		rope = Rope.new()
		lv.add_child(rope)
		rope.setup(a, b)
	await _frames(50)
	return [lv, a, b, rope]


## Giữ hướng `dir` ("right" / "left") của người chơi `prefix` ("p1_" / "p2_") `charge` khung rồi bấm nhảy một khung: nhảy đầy lực nếu charge >= 42.
func _chained_jump(prefix: String, dir: String, charge := 50) -> void:
	Input.action_press(prefix + dir)
	await _frames(charge)
	Input.action_press(prefix + "jump")
	await _frames(1)
	Input.action_release(prefix + "jump")
	Input.action_release(prefix + dir)


## Đợi `ball` rời đất rồi chạm đất lần đầu: trả về x lúc chạm đất, hoặc -1 nếu quá `max_frames` khung (rơi vực...).
func _await_landing(ball: Ball, max_frames := 300) -> float:
	var airborne := false
	for f in max_frames:
		await _frames(1)
		if not ball.on_ground:
			airborne = true
		if airborne and ball.on_ground and f > 8:
			return ball.global_position.x
	return -1.0


## Đặt các hạt của `rope` đúng ở các vị trí `values` (không tách hạt chồng nhau, để bài test kiểm tra số liệu chính xác).
func _set_beads(rope: Rope, values: Array) -> void:
	rope.beads.clear()
	for v in values:
		var bd := Rope.Bead.new()
		bd.t = v
		rope.beads.append(bd)


## Dịch cả hai người chơi cùng lúc tới `pos_a` / `pos_b` (dịch một người đi xa thì dây giật cả hai rất mạnh) rồi chờ vài khung.
func _chained_move(ch: Chained, pos_a: Vector2, pos_b: Vector2, frames := 3) -> void:
	ch.balls[0].teleport(pos_a)
	ch.balls[1].teleport(pos_b)
	await _frames(frames)


## Dựng cảnh Chained ở màn `index` (rút ngắn mọi thời gian chờ, không đổi cảnh thật khi hết mạng). `ready` = chờ hết giới thiệu và cho hai bóng ổn định.
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


## Xoá cảnh Chained sau khi các hẹn giờ của nó chạy hết (xoá ngay thì hẹn giờ bị bỏ dở và rò rỉ tới lúc thoát chương trình).
func _free_chained(ch: Chained) -> void:
	_release_all_keys()
	await _frames(150)
	ch.queue_free()
	await _frames(2)


## Mọi kiểm tra của chế độ Chained.
func _chained_checks() -> void:
	for c in get_children():                           # dọn mọi cảnh còn sót (cùng một thế giới vật lý)
		c.queue_free()
	await _frames(3)
	_release_all_keys()
	await _chained_rope_checks()
	await _chained_anchor_checks()
	await _chained_slingshot_checks()
	await _chained_bead_checks()
	await _chained_mode_checks()
	await _chained_death_checks()
	await _chained_finish_checks()
	await _chained_level_checks()


## Dây: không lực dưới độ dài chùng, kéo khi căng, không vượt quá độ dài tối đa, đứt thì tắt, chỉnh được lúc đang chạy.
func _chained_rope_checks() -> void:
	var map := _chained_flat_map(80)
	var rig := await _rope_rig(map, 600.0, 700.0, 369.0)
	var lv: Level = rig[0]
	var a: Ball = rig[1]
	var b: Ball = rig[2]
	var rope: Rope = rig[3]
	_expect(rope.rest_length == 160.0 and rope.max_length == 320.0 and rope.stiffness > 0.0 and rope.damping > 0.0 and not rope.cut, "rope defaults: rest 160 (5 tiles), max 320 (10 tiles), public stiffness / damping, not cut (stiffness %.0f, damping %.1f)" % [rope.stiffness, rope.damping])
	var ax := a.global_position.x
	var bx := b.global_position.x
	await _frames(60)
	_expect(rope.tension() == 0.0 and absf(a.global_position.x - ax) < 1.0 and absf(b.global_position.x - bx) < 1.0, "rope: no force while the balls are closer than rest_length (%.0f px apart)" % rope.current_length())

	a.teleport(Vector2(500.0, 369.0))                  # kéo giãn: cách 290 pixel
	b.teleport(Vector2(790.0, 369.0))
	await _frames(3)
	var d0 := rope.current_length()
	await _frames(20)
	_expect(rope.tension() > 0.0 and rope.current_length() < d0 - 20.0 and a.global_position.x > 505.0 and b.global_position.x < 785.0, "rope: pulls both balls together when stretched (%.0f -> %.0f px, tension %.0f)" % [d0, rope.current_length(), rope.tension()])
	_expect(a.linear_velocity.x > 0.0 and b.linear_velocity.x < 0.0, "rope: the pull is applied as velocity through knockback (a %.0f, b %.0f px/s)" % [a.linear_velocity.x, b.linear_velocity.x])

	rope.cut = true                                    # đứt: không lực
	a.teleport(Vector2(500.0, 369.0))
	b.teleport(Vector2(790.0, 369.0))
	await _frames(3)
	await _frames(30)
	_expect(rope.tension() == 0.0 and absf(rope.current_length() - 290.0) < 3.0, "rope: cut applies no force (%.0f px apart, tension %.0f)" % [rope.current_length(), rope.tension()])
	rope.cut = false                                   # nối lại
	await _frames(5)
	_expect(rope.tension() > 0.0, "rope: not cut any more pulls again (tension %.0f)" % rope.tension())

	rope.rest_length = 400.0                           # chỉnh lúc đang chạy: dây dài hơn thì hết căng
	rope.max_length = 600.0
	a.teleport(Vector2(500.0, 369.0))
	b.teleport(Vector2(790.0, 369.0))
	await _frames(20)
	_expect(rope.tension() == 0.0 and absf(rope.current_length() - 290.0) < 3.0, "rope: rest_length / max_length can be changed at run time (a longer rope is slack at 290 px)")
	lv.queue_free()
	await _frames(3)

	# --- Đẩy mạnh một bóng ra xa: dây giữ không cho vượt quá max_length nhiều ---
	rig = await _rope_rig(map, 600.0, 660.0, 369.0)
	lv = rig[0]
	a = rig[1]
	b = rig[2]
	rope = rig[3]
	var longest := 0.0
	for f in 300:
		if f < 30:
			b.knockback(Vector2(150.0, 0.0))           # đẩy b ra xa liên tục nửa giây
		await _frames(1)
		longest = maxf(longest, rope.current_length())
	_expect(longest < rope.max_length + 64.0, "rope: a ball pushed away hard never gets more than 2 tiles past max_length (longest %.0f px, max %.0f)" % [longest, rope.max_length])
	_expect(longest > rope.rest_length, "rope: ... and the push did stretch it (longest %.0f px)" % longest)
	lv.queue_free()
	await _frames(3)


## Neo: giữ phím use lúc đứng đất. Không trượt, nặng hơn, ma sát cao, giữ được bạn lơ lửng trên hố; thả ra là trả lại đúng như cũ.
func _chained_anchor_checks() -> void:
	var map := _chained_pit_map(70, 25, 44)            # hố từ cột 25 tới 44, sâu 12 ô
	var rig := await _rope_rig(map, 23.5 * 32.0, 21.0 * 32.0, 369.0)
	var lv: Level = rig[0]
	var a: Ball = rig[1]
	var b: Ball = rig[2]
	var rope: Rope = rig[3]
	var mass0 := a.mass
	var mat0 := a.physics_material_override
	var friction0: float = mat0.friction
	_expect(not rope.is_anchored(a) and not rope.is_anchored(b), "anchor: nobody is anchored by default")
	Input.action_press("p1_use")
	await _frames(6)
	_expect(rope.is_anchored(a) and not rope.is_anchored(b), "anchor: holding the use key on the ground anchors only that player")
	_expect(a.mass > mass0 * 2.0 and a.physics_material_override != mat0 and a.physics_material_override.friction >= 2.0, "anchor: the anchored ball is heavier and has a much higher friction (mass %.1f -> %.1f, friction %.1f -> %.1f)" % [mass0, a.mass, friction0, a.physics_material_override.friction])
	_expect(mat0.friction == friction0 and is_equal_approx(mat0.bounce, 0.55), "anchor: the shared scene material is not modified (duplicated for the anchor)")
	var x0 := a.global_position.x

	b.teleport(Vector2(29.5 * 32.0, 250.0))            # người chơi 2 thả vào hố
	var lowest := 0.0
	var hung := 0
	for f in 300:                                      # 5 giây
		await _frames(1)
		lowest = maxf(lowest, b.global_position.y)
		if f > 120 and b.global_position.y > 420.0 and rope.current_length() < rope.max_length + 48.0:
			hung += 1
	var pit_bottom := lv.size.y
	_expect(absf(a.global_position.x - x0) < 3.0 and a.on_ground, "anchor: the anchored player holds still while the partner hangs over the pit (moved %.1f px)" % absf(a.global_position.x - x0))
	_expect(lowest < pit_bottom - 16.0 and hung >= 170, "anchor: the partner stays held above the pit bottom for 5 seconds (lowest y %.0f, pit bottom %.0f, hanging frames %d/180)" % [lowest, pit_bottom, hung])
	_expect(b.global_position.y > 420.0 and rope.current_length() < rope.max_length + 48.0 and rope.tension() > 1000.0, "anchor: the dangling partner hangs at the end of the stretched rope (y %.0f, %.0f px from the anchor, tension %.0f)" % [b.global_position.y, rope.current_length(), rope.tension()])
	Input.action_release("p1_use")
	await _frames(4)
	_expect(not rope.is_anchored(a) and a.mass == mass0 and a.physics_material_override == mat0 and a.physics_material_override.friction == friction0, "anchor: letting go restores the mass and the very same friction material (mass %.1f, same material %s)" % [a.mass, str(a.physics_material_override == mat0)])
	lv.queue_free()
	await _frames(3)

	# --- Điểm cố định: dây căng ngang kéo người không neo đi, còn người đang neo thì đứng yên (bạn kia cũng neo để dây giữ căng) ---
	var drag := {}
	for anchored in [false, true]:
		rig = await _rope_rig(_chained_flat_map(80), 1000.0, 1100.0, 369.0)
		lv = rig[0]
		a = rig[1]
		b = rig[2]
		rope = rig[3]
		Input.action_press("p2_use")                   # người chơi 2 neo: dây căng 290 pixel mà bạn kia bị kéo, còn người neo thì không
		if anchored:
			Input.action_press("p1_use")
		await _frames(5)
		b.teleport(Vector2(1290.0, 369.0))             # kéo giãn dây ra 290 pixel
		await _frames(8)
		x0 = a.global_position.x
		await _frames(60)
		drag[anchored] = a.global_position.x - x0
		_release_all_keys()
		lv.queue_free()
		await _frames(3)
	_expect(drag[true] < 3.0 and drag[false] > 30.0, "anchor: a stretched rope drags a normal ball along (%.0f px) but not an anchored one (%.1f px)" % [drag[false], drag[true]])

	# --- Không trượt: bị hất ngang thì anchored dừng nhanh hơn không anchored ---
	var slide := {}
	for anchored in [false, true]:
		rig = await _rope_rig(_chained_flat_map(80), 1000.0, 900.0, 369.0)
		lv = rig[0]
		a = rig[1]
		if anchored:
			Input.action_press("p1_use")
			await _frames(5)
		x0 = a.global_position.x
		a.knockback(Vector2(500.0, 0.0))
		await _frames(60)
		slide[anchored] = a.global_position.x - x0
		_release_all_keys()
		lv.queue_free()
		await _frames(3)
	_expect(slide[true] < 45.0 and slide[false] > slide[true] + 25.0, "anchor: a shoved anchored ball does not slide (%.0f px) while a normal one does (%.0f px)" % [slide[true], slide[false]])

	# --- Neo cần đang đứng đất; nhảy thì thả neo; đáp xuống lại neo, không bị dây kéo đi ---
	rig = await _rope_rig(_chained_flat_map(80), 1000.0, 1100.0, 369.0)
	lv = rig[0]
	a = rig[1]
	b = rig[2]
	rope = rig[3]
	a.teleport(Vector2(1000.0, 150.0))
	await _frames(4)
	Input.action_press("p1_use")
	await _frames(4)
	_expect(not rope.is_anchored(a) and not a.on_ground, "anchor: needs the ground, an airborne player holding use is not anchored")
	await _frames(150)
	_expect(rope.is_anchored(a) and absf(a.linear_velocity.x) < 5.0 and a.on_ground, "anchor: ... and anchors as soon as the player lands")
	Input.action_press("p1_right")
	await _frames(50)
	Input.action_press("p1_jump")
	await _frames(1)
	Input.action_release("p1_jump")
	Input.action_release("p1_right")
	await _frames(5)
	_expect(not rope.is_anchored(a) and a.linear_velocity.y < -100.0 and a.mass == mass0, "anchor: jumping releases the anchor (still holding use; mass back to %.1f)" % a.mass)
	var landed := await _await_landing(a)
	await _frames(90)
	_expect(landed > 1100.0 and rope.is_anchored(a) and absf(a.linear_velocity.x) < 5.0, "anchor: landing with the key still held anchors again and stays put (landed x %.0f, speed %.1f)" % [landed, a.linear_velocity.x])
	_release_all_keys()
	lv.queue_free()
	await _frames(3)


## Súng cao su: một người neo, người kia lùi ra cho dây căng rồi nhảy về phía người neo thì bị hất qua đầu, xa hơn hẳn một cú nhảy thường lúc đang bị trói.
func _chained_slingshot_checks() -> void:
	var map := _chained_flat_map(140)
	# nhảy đầy lực không bị trói (để so): bóng kia ở rất xa
	var rig := await _rope_rig(map, 1000.0, 300.0, 369.0, false)
	var lv: Level = rig[0]
	var a: Ball = rig[1]
	var x_free := a.global_position.x
	await _chained_jump("p1_", "right")
	var land_free := await _await_landing(a)
	var free_px := land_free - x_free
	lv.queue_free()
	await _frames(3)
	# nhảy đầy lực lúc đang bị trói, bạn đứng sau lưng (không neo): bị dây giật lại và kéo bạn theo
	rig = await _rope_rig(map, 1000.0, 936.0, 369.0)
	lv = rig[0]
	a = rig[1]
	var rope: Rope = rig[3]
	var x_tied := a.global_position.x
	await _chained_jump("p1_", "right")
	var land_tied := await _await_landing(a)
	var tied_px := land_tied - x_tied
	_release_all_keys()
	lv.queue_free()
	await _frames(3)
	# súng cao su: người chơi 1 neo ở x = 1500, người chơi 2 đứng sau cách 290 pixel, cũng giữ neo, rồi nhảy
	rig = await _rope_rig(map, 1500.0, 1210.0, 369.0)
	lv = rig[0]
	a = rig[1]
	var b: Ball = rig[2]
	rope = rig[3]
	Input.action_press("p1_use")
	Input.action_press("p2_use")
	a.teleport(Vector2(1500.0, 369.0))
	b.teleport(Vector2(1500.0 - 290.0, 369.0))
	await _frames(25)
	var stretched := rope.current_length()
	var anchored_both := rope.is_anchored(a) and rope.is_anchored(b)
	var x_sling := b.global_position.x
	await _chained_jump("p2_", "right")
	var land_sling := await _await_landing(b)
	var sling_px := land_sling - x_sling
	await _frames(60)
	print("  slingshot: %.0f px (%.1f tiles) from the take-off to the landing; a normal full jump while tied: %.0f px (%.1f tiles); full jump with no rope: %.0f px (%.1f tiles)" % [sling_px, sling_px / 32.0, tied_px, tied_px / 32.0, free_px, free_px / 32.0])
	_expect(anchored_both and stretched > 270.0, "slingshot: both players are anchored with the rope stretched (%.0f px) before the jump" % stretched)
	_expect(tied_px > 0.0 and free_px > 500.0, "slingshot: reference jumps measured (tied %.0f px, untied %.0f px)" % [tied_px, free_px])
	_expect(sling_px > tied_px * 1.8, "slingshot: flings the player %.1f times farther than a normal full jump while tied (%.0f px vs %.0f px)" % [sling_px / maxf(tied_px, 1.0), sling_px, tied_px])
	_expect(sling_px > free_px * 0.9, "slingshot: reaches about as far as an untied full jump (%.0f px vs %.0f px) - past the anchor by %.0f px" % [sling_px, free_px, land_sling - a.global_position.x])
	_expect(land_sling > a.global_position.x + 200.0 and absf(b.global_position.x - land_sling) < 40.0, "slingshot: the thrown player lands well past the anchor (x %.0f vs anchor %.0f) and the anchor keeps him there (drift %.0f px)" % [land_sling, a.global_position.x, absf(b.global_position.x - land_sling)])
	_expect(absf(a.global_position.x - 1500.0) < 8.0, "slingshot: the anchor did not budge (%.1f px)" % absf(a.global_position.x - 1500.0))
	_release_all_keys()
	lv.queue_free()
	await _frames(3)


## Hạt xâu trên dây: nhặt sao thêm hạt ở giữa, hạt trượt về người đứng thấp, giữ khoảng cách, dừng ở hai đầu, cướp sao, hạt rơi, bead_counts.
func _chained_bead_checks() -> void:
	var map := _chained_flat_map(80, 10, 14)           # có một cột đất cao 3 ô ở cột 10..14
	var rig := await _rope_rig(map, 9.0 * 32.0, 9.0 * 32.0 - 56.0, 369.0)
	var lv: Level = rig[0]
	var a: Ball = rig[1]
	var b: Ball = rig[2]
	var rope: Rope = rig[3]
	var added := [0]
	var dropped := [0]
	rope.bead_added.connect(func() -> void: added[0] += 1)
	rope.beads_dropped.connect(func(n: int) -> void: dropped[0] += n)
	_expect(rope.beads.is_empty() and rope.bead_counts() == Vector2i.ZERO, "beads: none to begin with")
	var bead := rope.add_bead()
	_expect(rope.beads.size() == 1 and is_equal_approx(bead.t, 0.5) and added[0] == 1, "beads: a new bead starts in the middle of the rope (t = %.3f) and bead_added fires" % bead.t)
	await _frames(40)
	_expect(is_equal_approx(rope.beads[0].t, 0.5) and rope.bead_counts() == Vector2i.ZERO, "beads: players at the same height leave it where it is (t = %.3f), and a bead exactly in the middle counts for nobody" % rope.beads[0].t)
	# người chơi 1 đứng lên cột cao: hạt trượt về phía người chơi 2 (thấp hơn)
	a.teleport(_cpos(12.5, 8))                         # trên đỉnh cột đất (hàng 9 là mặt đất của cột)
	await _frames(90)
	_expect(a.global_position.y < b.global_position.y - 60.0, "beads: test setup, player 1 stands 3 tiles higher (%.0f vs %.0f)" % [a.global_position.y, b.global_position.y])
	_expect(rope.beads[0].t > 0.9 and rope.bead_counts() == Vector2i(0, 1), "beads: slide toward the LOWER player, here player 2 (t = %.3f, counts %s)" % [rope.beads[0].t, str(rope.bead_counts())])
	# đổi chỗ: người chơi 2 lên cột, người chơi 1 xuống: hạt chạy về phía người chơi 1
	b.teleport(_cpos(12.5, 8))
	a.teleport(_cpos(8.5, 11))
	await _frames(150)
	_expect(rope.beads[0].t < 0.1 and rope.bead_counts() == Vector2i(1, 0), "beads: ... and back toward player 1 when the players swap heights (t = %.3f, counts %s)" % [rope.beads[0].t, str(rope.bead_counts())])
	# nhiều hạt: giữ khoảng cách, nằm trong dây, đúng thứ tự
	rope.remove_bead(rope.beads[0])
	for i in 4:
		rope.add_bead()
		await _frames(6)
	await _frames(150)
	var ts: Array[float] = []
	for bd in rope.beads:
		ts.append(bd.t)
	ts.sort()
	var min_gap := 1.0
	for i in range(1, ts.size()):
		min_gap = minf(min_gap, ts[i] - ts[i - 1])
	_expect(rope.beads.size() == 4 and added[0] == 5 and ts[0] >= 0.0 and ts[3] <= 1.0 and ts[0] < 0.2, "beads: four beads all end up at player 1's end, inside the rope (t %s)" % str(ts))
	_expect(min_gap > 0.03 and min_gap * rope.current_length() > 10.0, "beads: neighbours keep a small gap and do not overlap (min gap %.3f of the rope = %.0f px)" % [min_gap, min_gap * rope.current_length()])
	_expect(rope.bead_counts() == Vector2i(4, 0), "beads: bead_counts counts each side (%s)" % str(rope.bead_counts()))

	# --- bead_counts và hạt đúng giữa dây, rồi cướp sao, rồi hạt rơi (đóng băng để hạt không trượt) ---
	rope.freeze_beads = true
	await _frames(2)
	_set_beads(rope, [0.5])
	var odd: Rope.Bead = rope.beads[0]
	_expect(rope.bead_counts() == Vector2i.ZERO, "beads: t = 0.5 exactly counts for nobody")
	odd.t = 0.499
	_expect(rope.bead_counts() == Vector2i(1, 0), "beads: t < 0.5 counts for player 1")
	odd.t = 0.501
	_expect(rope.bead_counts() == Vector2i(0, 1), "beads: t > 0.5 counts for player 2")
	_set_beads(rope, [0.1, 0.25, 0.4, 0.7])
	_expect(rope.steal_bead(b, a), "beads: steal_bead works when there are beads")
	var tmax := 0.0
	var tmin := 1.0
	for bd in rope.beads:
		tmax = maxf(tmax, bd.t)
		tmin = minf(tmin, bd.t)
	_expect(tmax > 0.95 and tmin > 0.2 and rope.bead_counts() == Vector2i(2, 2), "beads: stealing moves the bead nearest the victim (player 1) to the thief's end (player 2) (max t %.2f, min t %.2f, counts %s)" % [tmax, tmin, str(rope.bead_counts())])
	var locked := 0
	for bd in rope.beads:
		if bd.lock > 0.0:
			locked += 1
	_expect(locked == 1, "beads: the stolen bead is locked for a moment so it cannot slide straight back")
	rope.beads.clear()
	_expect(not rope.steal_bead(b, a), "beads: nothing to steal from an empty rope")
	_set_beads(rope, [0.1, 0.2, 0.3, 0.4, 0.6])
	var n_drop := rope.drop_beads(1)
	var left: Array[float] = []
	for bd in rope.beads:
		left.append(snappedf(bd.t, 0.01))
	left.sort()
	_expect(n_drop == 2 and dropped[0] == 2 and left == [0.3, 0.4, 0.6], "beads: half (rounded up) of the beads on player 1's side drop off, the ones nearest his end first (dropped %d, left %s)" % [n_drop, str(left)])
	n_drop = rope.drop_beads(2)
	_expect(n_drop == 1 and dropped[0] == 3 and rope.beads.size() == 2, "beads: half of one bead rounds up to one (dropped %d, %d beads left)" % [n_drop, rope.beads.size()])
	_expect(rope.drop_beads(2) == 0 and rope.beads.size() == 2, "beads: nothing drops from an empty side")
	lv.queue_free()
	await _frames(3)


## Cảnh Chained: màn dựng được, hai người chơi khác phím, camera, giới thiệu, nhặt sao thành hạt, cướp sao khi dẫm đầu.
func _chained_mode_checks() -> void:
	_expect(Game.has_method("start_chained") and Game.chained_totals.size() == 2 and Game.chained_index == 0 and load(Game.CHAINED_SCENE) != null, "Game: start_chained, chained_index, chained_totals and the scene exist")
	for i in ChainedData.LEVELS.size():
		var rows: PackedStringArray = []
		for line in String(ChainedData.LEVELS[i]["map"]).split("\n"):
			if line.strip_edges() != "":
				rows.append(line)
		var same := true
		var walls := true
		var found := {"O": 0, "P": 0, "F": 0, "*": 0, "K": 0}
		for r in rows.size():
			same = same and rows[r].length() == rows[0].length()
			walls = walls and rows[r][0] == "#" and rows[r][rows[r].length() - 1] == "#"
			for key in found:
				found[key] += rows[r].count(key)
		_expect(same and walls and found["O"] == 1 and found["P"] == 1 and found["F"] == 1 and found["*"] >= 10 and found["K"] >= 2 and found["K"] <= 4 and rows.size() >= 18 and rows.size() <= 24 and rows[0].length() >= 100 and rows[0].length() <= 140, "chained level '%s': %dx%d, equal rows, walls, one O / P / F, %d stars, %d checkpoints" % [ChainedData.LEVELS[i]["name"], rows[0].length(), rows.size(), found["*"], found["K"]])

	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	var ch := await _make_chained(0, false)
	var a := ch.balls[0]
	var b := ch.balls[1]
	var started := [0]
	ch.level_started.connect(func() -> void: started[0] += 1)
	_expect(ch.level_name == "Tied Together" and ch.balls.size() == 2 and ch.rope != null and ch.rope.ball_a == a and ch.rope.ball_b == b and ch.lives == Chained.LIVES and Chained.LIVES == 5, "chained: level 1 builds with two balls, the rope between them and %d shared lives" % ch.lives)
	_expect(a.player_id == 1 and b.player_id == 2 and a.action_prefix == "p1_" and b.action_prefix == "p2_" and a != b, "chained: the two balls use different keys (%s / %s)" % [a.action_prefix, b.action_prefix])
	_expect(a.get_collision_mask_value(2) and b.get_collision_mask_value(2), "chained: both balls collide with each other")
	_expect(ch.spawn_points.size() == 2 and ch.spawn_points[0] == ch.level.start_position and ch.spawn_points[1].x > ch.spawn_points[0].x + 64.0 and ch.spawn_points[1].x < ch.spawn_points[0].x + 200.0 and is_equal_approx(ch.spawn_points[0].y, ch.spawn_points[1].y), "chained: P2 spawns a couple of tiles right of O (%s, %s)" % [str(ch.spawn_points[0]), str(ch.spawn_points[1])])
	var stars := 0
	var kinds := {}
	for n in ch.level.get_children():
		if n is Pickup:
			kinds[n.kind] = kinds.get(n.kind, 0) + 1
	stars = kinds.get("star", 0)
	_expect(ch.level.star_total == stars and stars >= 10 and kinds.get("finish", 0) == 1 and kinds.get("checkpoint", 0) >= 2 and kinds.get("heart", 0) >= 1, "chained: level 1 has %d stars, a finish, %d checkpoints and %d hearts" % [stars, kinds.get("checkpoint", 0), kinds.get("heart", 0)])
	_expect(not ch.match_running and a.dead and b.dead, "chained: nobody can move during the READY intro")
	ch.kill_both("pit", a)
	_expect(ch.lives == Chained.LIVES, "chained: nothing can kill the players during the intro")
	await _frames(25)
	_expect(ch.match_running and not a.dead and not b.dead and started[0] == 1, "chained: after the intro the players can move and level_started fires once")
	await _frames(45)
	_expect(a.on_ground and b.on_ground, "chained: both balls stand on the ground at the start")
	_expect(ch.hud.message_label.text == "GO!" or ch.hud.message_label.text == "READY...", "chained: the HUD says READY... / GO!")

	# --- camera: giữa hai người, zoom ra xa khi dây căng ---
	_expect(is_equal_approx(ch.zoom_for_separation(0.0), 1.0) and is_equal_approx(ch.zoom_for_separation(ch.rope.rest_length), 1.0) and is_equal_approx(ch.zoom_for_separation(ch.rope.max_length), Chained.MIN_ZOOM) and ch.zoom_for_separation((ch.rope.rest_length + ch.rope.max_length) / 2.0) < 0.95, "chained camera: zoom is 1.0 up to rest_length and falls to %.2f at max_length" % Chained.MIN_ZOOM)
	var mid := (a.global_position + b.global_position) / 2.0
	_expect(ch.camera.global_position.distance_to(mid + Vector2(0.0, -40.0)) < 6.0 and ch.camera.zoom.x > 0.97, "chained camera: starts centred between the two players at zoom %.2f" % ch.camera.zoom.x)
	Input.action_press("p1_use")
	Input.action_press("p2_use")
	await _chained_move(ch, _cpos(3.5, 15), _cpos(3.5, 15) + Vector2(300.0, 0.0), 25)
	await _frames(150)
	mid = (a.global_position + b.global_position) / 2.0
	_expect(ch.camera.zoom.x < 0.8 and ch.camera.zoom.x >= Chained.MIN_ZOOM - 0.001 and absf(ch.camera.global_position.x - mid.x) < 12.0, "chained camera: zooms out smoothly as the rope stretches (zoom %.2f at %.0f px) and follows the midpoint" % [ch.camera.zoom.x, ch.rope.current_length()])
	_release_all_keys()
	await _chained_move(ch, a.global_position, a.global_position + Vector2(64.0, 0.0), 3)
	await _frames(240)
	_expect(ch.camera.zoom.x > 0.97, "chained camera: zooms back in when the players come together (%.2f)" % ch.camera.zoom.x)

	# --- nhặt sao: thêm hạt ở giữa dây; nhặt tim: +1 mạng (tối đa 5) ---
	var got := [0]
	ch.rope.bead_added.connect(func() -> void: got[0] += 1)
	ch.level.collect_star(a)
	await _frames(2)
	_expect(ch.rope.beads.size() == 1 and got[0] == 1 and is_equal_approx(ch.rope.beads[0].t, 0.5), "chained: touching a star puts a bead in the middle of the rope")
	ch.lives = 3
	ch.level.collect_heart()
	ch.level.collect_heart()
	ch.level.collect_heart()
	_expect(ch.lives == Chained.LIVES, "chained: hearts give +1 life up to the maximum (%d)" % ch.lives)
	var star_node: Pickup = null
	for n in ch.level.get_children():                  # ngôi sao gần người chơi 1 nhất
		if n is Pickup and n.kind == "star" and (star_node == null or n.global_position.distance_to(a.global_position) < star_node.global_position.distance_to(a.global_position)):
			star_node = n
	await _chained_move(ch, a.global_position, star_node.global_position + Vector2(0.0, -16.0), 4)   # chạm một ngôi sao thật bằng người chơi 2
	_expect(ch.rope.beads.size() == 2 and not is_instance_valid(star_node), "chained: either player touching a real star adds a bead and removes the star (%d beads)" % ch.rope.beads.size())
	var cp_pos := _cpos(35.5, 15)
	var cp_node: Pickup = null
	for n in ch.level.get_children():
		if n is Pickup and n.kind == "checkpoint" and absf(n.global_position.x - cp_pos.x) < 4.0:
			cp_node = n
	await _chained_move(ch, cp_node.global_position + Vector2(-40.0, -16.0), cp_node.global_position + Vector2(0.0, -16.0), 4)
	_expect(cp_node.used and ch.respawn_position.distance_to(cp_node.global_position + Vector2(0.0, -16.0)) < 1.0 and ch.respawn_points[0].x < ch.respawn_position.x and ch.respawn_points[1].x > ch.respawn_position.x, "chained: either player touching a checkpoint sets it for both (respawn %s)" % str(ch.respawn_position))

	# --- dẫm đầu bạn: hạt gần đầu nạn nhân nhảy sang đầu kẻ dẫm ---
	ch.rope.freeze_beads = true
	_set_beads(ch.rope, [0.2, 0.45, 0.6, 0.8])
	await _chained_move(ch, _cpos(30.5, 15), _cpos(32.5, 15), 40)
	a.teleport(Vector2(b.global_position.x + 4.0, b.global_position.y - 160.0))   # người chơi 1 rơi xuống đầu người chơi 2
	await _frames(40)
	var tmax := 0.0
	var tmin := 1.0
	for bd in ch.rope.beads:
		tmax = maxf(tmax, bd.t)
		tmin = minf(tmin, bd.t)
	_expect(ch.rope.beads.size() == 4 and tmin < 0.06 and tmax < 0.8 and ch.rope.bead_counts() == Vector2i(3, 1) and ch.hud.message_label.text.contains("STEALS"), "chained: P1 stomping P2's head moves the bead nearest P2 to P1's end with a message (counts %s, '%s')" % [str(ch.rope.bead_counts()), ch.hud.message_label.text])
	_expect(ch.lives == Chained.LIVES, "chained: stomping the partner costs nobody a life")
	await _free_chained(ch)


## Chết chung: cả hai hồi sinh ở cờ lưu, mất 1 mạng, miễn sát thương, một nửa sao phía người chết rơi ra đất và nhặt lại được, hết mạng thì chơi lại.
func _chained_death_checks() -> void:
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	var rope := ch.rope
	var died: Array[String] = []
	var back := [0]
	ch.players_died.connect(func(cause: String) -> void: died.append(cause))
	ch.players_respawned.connect(func() -> void: back[0] += 1)
	var cp: Pickup = null
	for n in ch.level.get_children():
		if n is Pickup and n.kind == "checkpoint" and absf(n.global_position.x - _cpos(35.5, 15).x) < 4.0:
			cp = n
			break
	await _chained_move(ch, cp.global_position + Vector2(0.0, -16.0), cp.global_position + Vector2(40.0, -16.0), 6)   # người chơi 1 cắm cờ ở cột 35
	var respawn_pos := ch.respawn_position
	_expect(cp.used and respawn_pos.distance_to(cp.global_position + Vector2(0.0, -16.0)) < 1.0, "death: player 1 touching the checkpoint activates it for both")
	# người chơi 1 có 4 hạt, người chơi 2 có 2 hạt
	rope.freeze_beads = true
	_set_beads(rope, [0.1, 0.2, 0.3, 0.4, 0.7, 0.8])
	_expect(rope.bead_counts() == Vector2i(4, 2), "death: test setup, 4 beads on player 1's half and 2 on player 2's")
	await _chained_move(ch, _cpos(25.5, 15), _cpos(27.5, 15), 20)   # đi xa chỗ cờ để thấy hai người bị đưa về
	ch.kill_both("hurt", a)
	_expect(ch.lives == Chained.LIVES - 1 and died == ["hurt"] and a.dead and b.dead, "death: either player dying kills both and costs one shared life (lives %d)" % ch.lives)
	await _frames(2)
	_expect(not a.visible and not b.visible and not rope.visible and rope.bead_counts() == Vector2i(2, 2) and ch.hud.message_label.text.contains("P1 DROPPED 2 STARS"), "death: half (rounded up) of the dead player's half of the beads leave the rope (counts %s, '%s')" % [str(rope.bead_counts()), ch.hud.message_label.text.replace("\n", " / ")])
	ch.kill_both("pit", b)
	_expect(ch.lives == Chained.LIVES - 1 and died.size() == 1, "death: a second death while waiting to respawn is ignored")
	await _frames(40)
	_expect(back[0] == 1 and not a.dead and not b.dead and a.visible and b.visible and rope.visible, "death: both respawn alive after the delay (players_respawned x%d)" % back[0])
	_expect(a.invuln > 0.5 and b.invuln > 0.5, "death: both respawn with brief invulnerability (%.2f / %.2f s)" % [a.invuln, b.invuln])
	_expect(absf(a.global_position.x - (respawn_pos.x - Chained.RESPAWN_SPREAD)) < 6.0 and absf(b.global_position.x - (respawn_pos.x + Chained.RESPAWN_SPREAD)) < 6.0 and absf(a.global_position.y - respawn_pos.y) < 8.0, "death: both are at the checkpoint, player 1 on the left and player 2 on the right (%s / %s)" % [str(a.global_position.round()), str(b.global_position.round())])
	_expect(rope.current_length() < rope.rest_length and rope.tension() == 0.0 and not rope.is_anchored(a) and not rope.is_anchored(b), "death: the rope is slack again after the respawn (%.0f px)" % rope.current_length())
	_expect(ch.dropped_stars.size() == 2, "death: two stars scattered on the ground")
	var near_ok := true
	for s in ch.dropped_stars:
		near_ok = near_ok and is_instance_valid(s) and s.kind == "star" and absf(s.position.x - respawn_pos.x) < 260.0 and absf(s.position.x - respawn_pos.x) > 40.0 and absf(s.position.y - (respawn_pos.y + 16.0)) < 4.0
	_expect(near_ok, "death: the dropped stars lie on the ground around the respawn point, not on top of the players")
	var before := rope.beads.size()
	var star: Pickup = ch.dropped_stars[0]
	rope.freeze_beads = false
	a.teleport(star.global_position + Vector2(0.0, -16.0))     # nhặt lại
	await _frames(4)
	_expect(not is_instance_valid(star) and rope.beads.size() == before + 1, "death: a dropped star can be collected again and becomes a new bead (%d -> %d beads)" % [before, rope.beads.size()])
	# miễn sát thương: chạm gai lúc đó không mất mạng
	var lives_now := ch.lives
	b.take_hit()
	await _frames(3)
	_expect(ch.lives == lives_now and died.size() == 1, "death: while invulnerable, being hurt costs nothing")
	await _frames(100)
	# gai thật: chạm gai (take_hit sau khi hết miễn sát thương) giết cả hai
	b.take_hit()
	await _frames(3)
	_expect(ch.lives == lives_now - 1 and died.size() == 2 and died[1] == "hurt", "death: spikes / enemies (Ball.hurt) kill both with cause 'hurt' (lives %d)" % ch.lives)
	await _frames(40)
	# rơi xuống vực
	lives_now = ch.lives
	b.teleport(Vector2(b.global_position.x, ch.level.size.y + 400.0))
	await _frames(100)
	_expect(ch.lives == lives_now - 1 and died.size() == 3 and died[2] == "pit" and not a.dead and not b.dead, "death: falling below the level kills both with cause 'pit' and they come back (lives %d)" % ch.lives)
	# kill_both không có người gây ra (sự kiện): không rơi sao
	await _frames(60)
	var stars_before := ch.dropped_stars.size()
	ch.kill_both("event")
	await _frames(60)
	_expect(died.size() == 4 and died[3] == "event" and ch.dropped_stars.size() == stars_before, "death: kill_both(cause) with no culprit drops no stars (cause '%s')" % died[3])
	# hết mạng: chơi lại màn
	await _frames(60)
	var restarts := [0]
	ch.restart_requested.connect(func() -> void: restarts[0] += 1)
	var respawns_before: int = back[0]
	ch.lives = 1
	ch.kill_both("hurt", b)
	_expect(ch.lives == 0, "death: the last life is gone")
	await _frames(10)
	_expect(ch.hud.message_label.text.contains("Out of lives") and restarts[0] == 0, "death: out of lives shows a message first ('%s')" % ch.hud.message_label.text)
	await _frames(40)
	_expect(restarts[0] == 1 and back[0] == respawns_before and a.dead and b.dead, "death: out of lives restarts the level instead of respawning (restart requested x%d)" % restarts[0])
	await _free_chained(ch)


## Về đích: chỉ tính khi cả hai còn sống, chốt số sao, cộng tổng, bảng kết quả với người thắng và nút Next / Retry / Menu.
func _chained_finish_checks() -> void:
	for scenario in [[Vector2i(3, 1), "PLAYER 1 WINS THE LEVEL!"], [Vector2i(1, 2), "PLAYER 2 WINS THE LEVEL!"], [Vector2i(2, 2), "IT'S A TIE!"]]:
		Game.chained_totals[0] = 2                      # tổng sao từ các màn trước
		Game.chained_totals[1] = 3
		var want: Vector2i = scenario[0]
		var ch := await _make_chained()
		var a := ch.balls[0]
		var b := ch.balls[1]
		var finished_counts: Array[Vector2i] = []
		ch.level_finished.connect(func(c: Vector2i) -> void: finished_counts.append(c))
		ch.rope.freeze_beads = true
		var values: Array[float] = []
		for i in want.x:
			values.append(0.1 + 0.05 * i)
		for i in want.y:
			values.append(0.9 - 0.05 * i)
		values.append(0.5)                              # hạt đúng giữa dây: không tính cho ai
		_set_beads(ch.rope, values)
		var flag: Pickup = null
		for n in ch.level.get_children():
			if n is Pickup and n.kind == "finish":
				flag = n
		if scenario[1] == "PLAYER 1 WINS THE LEVEL!":   # lần đầu thử về đích lúc một người đang chết: không tính
			b.dead = true                               # (người chết thì dây không kéo, nên dịch người chơi 1 một mình tới đích được)
			a.teleport(flag.global_position + Vector2(0.0, -16.0))
			await _frames(6)
			_expect(not ch.finished and ch.match_running and finished_counts.is_empty() and not flag.used, "finish: touching the flag while the partner is dead does not finish the level (and the flag stays usable)")
			b.teleport(a.global_position + Vector2(-60.0, 0.0))
			await _frames(3)
			b.dead = false
		else:
			a.teleport(flag.global_position + Vector2(-70.0, -16.0))
		b.teleport(flag.global_position + Vector2(0.0, -16.0))    # chạm cờ đích bằng người chơi 2 (một người là đủ)
		await _frames(4)
		_expect(ch.finished and not ch.match_running and finished_counts == [want] and ch.counts() == want, "finish: either player touching F with both alive finishes the level (counts %s)" % str(ch.counts()))
		_expect(Game.chained_totals[0] == 2 + want.x and Game.chained_totals[1] == 3 + want.y, "finish: the stars are added to the running totals (%s)" % str(Game.chained_totals))
		_expect(a.dead and b.dead and ch.rope.freeze_beads and ch.hud.result_panel == null, "finish: the players are frozen and the panel is still to come")
		ch.kill_both("pit", a)
		_expect(ch.lives == Chained.LIVES, "finish: nothing can kill the players after the finish")
		await _frames(30)
		var hud := ch.hud
		_expect(hud.result_panel != null and hud.result_title.text == scenario[1], "finish: result panel says '%s' (%s)" % [scenario[1], hud.result_title.text if hud.result_title else "-"])
		_expect(hud.result_p1.text == "P1  %d" % want.x and hud.result_p2.text == "%d  P2" % want.y and hud.result_totals.text.contains(str(2 + want.x)) and hud.result_totals.text.contains(str(3 + want.y)), "finish: the panel shows the stars per player and the running totals ('%s' '%s' '%s')" % [hud.result_p1.text, hud.result_p2.text, hud.result_totals.text])
		_expect(hud.retry_button != null and hud.menu_button != null and hud.next_button == null and not ch.has_next_level(), "finish: Retry and Menu exist, and no Next level when it was the last level")
		_expect(hud.retry_pressed.get_connections().size() >= 1 and hud.menu_pressed.get_connections().size() >= 1 and hud.next_pressed.get_connections().size() >= 1, "finish: the buttons are wired up")
		_expect(ch._base_totals == [2, 3], "finish: Retry restores the totals from before the level (%s)" % str(ch._base_totals))
		await _free_chained(ch)
	# bảng kết quả có nút Next level khi còn màn sau
	var hud2 := ChainedHud.new()
	add_child(hud2)
	hud2.setup("x", 5)
	hud2.show_result(Vector2i(1, 0), [1, 0], true)
	_expect(hud2.next_button != null and hud2.retry_button != null and hud2.menu_button != null, "finish: Next level, Retry and Menu are all there when another level follows")
	hud2.queue_free()
	await _frames(2)
	Game.chained_totals[0] = 0
	Game.chained_totals[1] = 0


## Màn 1 qua được bằng hai người chơi: qua khe 7 ô bằng súng cao su (neo + dây hất), rồi người kia được kéo qua. Nhảy thường khi bị trói thì không qua được.
func _chained_level_checks() -> void:
	var ch := await _make_chained()
	var a := ch.balls[0]
	var b := ch.balls[1]
	var lv := ch.level
	# hình học dùng bên dưới: bờ trái là đất tới cột 63, khe từ cột 64 tới 70, bờ phải từ cột 71 (hàng 16 là mặt đất)
	var gap_ok := lv.char_at(16, 63) == "#" and lv.char_at(16, 64) == "." and lv.char_at(16, 70) == "." and lv.char_at(16, 71) == "#" and lv.char_at(15, 63) == "." and lv.char_at(15, 71) == "."
	_expect(gap_ok, "level 1: the wide gap is where the test expects it (columns 64..70, 7 tiles wide)")
	var far_edge := 71.0 * 32.0
	var edge := _cpos(63.5, 15)
	# người chơi 1 neo ở mép khe, người chơi 2 lùi ra sau 290 pixel cho dây căng, cũng giữ neo, rồi nhảy về phía người chơi 1
	Input.action_press("p1_use")
	Input.action_press("p2_use")
	await _chained_move(ch, edge, edge - Vector2(290.0, 0.0), 25)
	_expect(ch.rope.is_anchored(a) and ch.rope.is_anchored(b) and ch.rope.current_length() > 270.0, "level 1: both players are anchored at the gap with the rope stretched (%.0f px)" % ch.rope.current_length())
	var beads_before := ch.rope.beads.size()
	await _chained_jump("p2_", "right")
	var landed := await _await_landing(b)
	await _frames(40)
	_expect(landed > far_edge + 15.0 and b.global_position.x > far_edge + 15.0 and ch.lives == Chained.LIVES, "level 1: the slingshot lands player 2 on the far side of the 7-tile gap (landed x %.0f, far edge %.0f), nobody died" % [landed, far_edge])
	_expect(ch.rope.is_anchored(b) and absf(b.global_position.x - landed) < 40.0, "level 1: holding anchor on landing keeps player 2 on the far side instead of being dragged back (x %.0f)" % b.global_position.x)
	_expect(ch.rope.beads.size() >= beads_before + 2, "level 1: the three stars on the flight path of the slingshot are collected on the way (%d new beads)" % (ch.rope.beads.size() - beads_before))
	# người chơi 2 giữ neo bên kia khe; người chơi 1 nhả neo... không, vẫn giữ neo tới lúc nhảy; bị dây kéo qua
	await _chained_jump("p1_", "right", 45)
	var landed1 := await _await_landing(a)
	await _frames(40)
	_expect(landed1 > far_edge + 15.0 and a.global_position.x > far_edge + 15.0 and not a.dead and ch.lives == Chained.LIVES, "level 1: player 1 is pulled across by the rope from player 2's anchor (landed x %.0f)" % landed1)
	_release_all_keys()
	var all_beads := ch.rope.beads.size()
	_expect(all_beads >= 3, "level 1: the pair crossed the gap with %d stars threaded on the rope" % all_beads)
	await _free_chained(ch)

	# thung lũng (hố 4 ô có bậc thang): một người nhảy đủ lực từ đáy là lên khỏi thung lũng được
	var lv2 := _make_level(ChainedData.LEVELS[0]["map"])
	var solo := _make_ball(lv2, _cpos(47.5, 19))
	solo.set_player(1)
	await _frames(40)
	await _chained_jump("p1_", "right", 30)
	await _frames(100)
	_expect(solo.on_ground and solo.global_position.y < 520.0 and solo.global_position.x > 1700.0, "level 1: from the bottom of the valley a three-quarter jump climbs out onto the high ground (%s)" % str(solo.global_position.round()))
	_release_all_keys()
	lv2.queue_free()
	await _frames(3)

	# nhảy thường qua khe khi bị trói (không neo): dây giật người kia xuống khe, cả hai rơi
	ch = await _make_chained()
	a = ch.balls[0]
	b = ch.balls[1]
	await _chained_move(ch, _cpos(63.5, 15), _cpos(62.0, 15), 40)
	await _chained_jump("p2_", "right", 50)
	await _frames(400)
	_expect(ch.lives < Chained.LIVES, "level 1: an ordinary tied jump across the gap does not work, the partner is dragged into the pit (lives %d)" % ch.lives)
	await _free_chained(ch)
