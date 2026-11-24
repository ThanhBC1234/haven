extends Node
## Chụp chế độ đấu 2 người. Chạy có cửa sổ: godot --path . res://tests/brawl_preview.tscn -- --shots=<thư mục>
## Ảnh: từng đấu trường lúc bắt đầu (READY...), giữa trận có điểm (người bị dẫm đang dẹt), gai chống câu giờ, bảng thắng,
## sự kiện ngẫu nhiên, vật phẩm troll (hộp, từng món trong tay, chuối, bẫy lò xo), vương miện người dẫn điểm, câu châm chọc dài nhất.

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	Game.save_enabled = false                       # không ghi đè file lưu thật
	if OS.get_cmdline_user_args().has("--only-bot"):   # chỉ chụp phần đấu với máy cho nhanh (godot ... -- --shots=<thư mục> --only-bot)
		await _bot_shots()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--only-sudden"):   # chỉ chụp SUDDEN DEATH (godot ... -- --shots=<thư mục> --only-sudden)
		for i in BrawlData.ARENAS.size():
			await _sudden_shots(i)
		get_tree().quit()
		return
	for i in BrawlData.ARENAS.size():
		var brawl := await _start(i)
		brawl.events.enabled = false                 # các ảnh dưới đây không có sự kiện ngẫu nhiên chen vào
		await _frames(20)
		await _shot("arena%d_start" % i)             # đang READY...
		await _wait_match(brawl)
		Input.action_press("p1_right")               # người chơi 1 giữ D: hiện mũi tên lực nhảy
		await _frames(25)
		brawl.kill(brawl.balls[1], "pit")            # người chơi 2 rơi xuống vực: P1 có điểm
		await _frames(100)                           # người chơi 2 đã hồi sinh (nhấp nháy)
		Input.action_release("p1_right")
		var b := brawl.balls[1]
		brawl.scores[0] = 2
		brawl.hud.set_scores(2, 1)
		b.teleport(brawl.balls[0].global_position + Vector2(180, -120))   # người chơi 2 rơi xuống gần người chơi 1
		await _frames(30)
		await _shot("arena%d_mid" % i)               # giữa trận, điểm 2 - 1
		brawl.kill(brawl.balls[1], "stomp")          # dẫm: người chơi 2 dẹt như bánh
		await _frames(18)
		await _shot("arena%d_pancake" % i)
		brawl.stall_timeout = 0.1                    # gai chống câu giờ mọc nhanh để chụp
		brawl.stall_step = 0.1
		brawl._stall_time = 0.0
		await _frames(110)                           # chờ hồi sinh + gai mọc vài ô
		await _shot("arena%d_stall_spikes" % i)
		brawl.scores[0] = Brawl.WIN_SCORE - 1
		brawl.kill(brawl.balls[1], "spikes")         # điểm thứ 5: thắng
		await _frames(110)
		await _shot("arena%d_win" % i)
		brawl.queue_free()
		await _frames(3)
		await _event_shots(i)                        # banner roulette, sự kiện đang chạy (sàn băng), bom HOT POTATO
		await _item_shots(i)                         # vật phẩm troll, vương miện, câu châm chọc
	await _bot_shots()                               # menu có nút BRAWL VS BOT, trận đấu với máy (ghi BOT), bảng "BOT WINS!"
	get_tree().quit()


## Ảnh SUDDEN DEATH: lúc vừa bắt đầu (banner, hàng gai ở đáy) và giữa chừng khi hàng gai đã dâng qua sàn gai. Hai người đứng bệ cao, miễn sát thương cho tới khi chụp xong.
func _sudden_shots(index: int) -> void:
	var brawl := await _start(index)
	brawl.events.enabled = false
	brawl.items.enabled = false
	await _wait_match(brawl)
	await _frames(40)
	brawl.stall_timeout = 0.2                        # rút ngắn để chụp: gai sàn mọc kín nhanh, hàng gai dâng 120 pixel/giây
	brawl.stall_step = 0.05
	brawl.sudden_death_delay = 0.5
	brawl.sudden_death_speed = 120.0
	brawl._reset_stall()
	var tops := {0: Vector2(640, 340), 1: Vector2(640, 250)}   # bệ cao nhất của từng đấu trường (ở giữa)
	brawl.balls[0].teleport(tops[index] + Vector2(-60, 0))
	brawl.balls[1].teleport(tops[index] + Vector2(60, 0))
	for ball in brawl.balls:
		ball.invuln = 9999.0                         # không chết vì gai sàn hay hàng gai trong lúc chụp
	while not brawl.sudden_death_active:
		await _frames(1)
	await _frames(20)
	await _shot("arena%d_sudden_start" % index)      # banner SUDDEN DEATH!, hàng gai vừa nhô lên ở đáy
	while brawl.hazard_y() > 470.0:
		await _frames(1)
	await _shot("arena%d_sudden_midrise" % index)    # hàng gai đang dâng giữa chừng, đè lên đất và bệ
	brawl.queue_free()
	await _frames(3)


## Ảnh chế độ đấu với máy: menu mới (hai nút Brawl), trận đang chơi (HUD ghi BOT, không có dòng phím của P2), câu châm chọc nhắc BOT, bảng thắng.
func _bot_shots() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(8)
	await _shot("menu_brawl_buttons")
	menu.queue_free()
	await _frames(3)
	Game.brawl_vs_bot = true
	var brawl := await _start(0)
	brawl.events.enabled = false
	brawl.items.enabled = false
	await _wait_match(brawl)
	await _frames(20)
	await _shot("bot_ready_bounce")                  # vừa vào trận
	await _frames(60 * 9)                            # để bot chơi một lúc
	brawl.items.give(brawl.balls[1], "gun")          # bot cầm súng: ô vật phẩm bên phải hiện súng
	await _frames(20)
	await _shot("bot_match_in_progress")
	brawl.kill(brawl.balls[1], "pit")                # bot rơi xuống vực: câu châm chọc ghi BOT
	await _frames(12)
	await _shot("bot_taunt")
	brawl.scores[1] = Brawl.WIN_SCORE - 1
	brawl.hud.set_scores(brawl.scores[0], brawl.scores[1])
	await _frames(100)
	brawl.kill(brawl.balls[0], "stomp")              # bot ghi điểm thứ 5
	await _frames(110)
	await _shot("bot_wins")
	brawl.queue_free()
	await _frames(3)
	Game.brawl_vs_bot = false


## Ảnh sự kiện ngẫu nhiên: roulette đang quay, ICE FLOOR đang chạy (thanh đếm ngược + màu băng), bom HOT POTATO (lúc đầu và lúc sắp nổ).
func _event_shots(index: int) -> void:
	var brawl := await _start(index)
	var ev := brawl.events
	ev.enabled = true                                # để bộ đếm giờ tự bốc thăm: roulette bắt đầu 0,2 giây sau khi trận bắt đầu
	ev.first_delay = 0.2
	ev.roulette_seconds = 2.4
	ev.ice_floor_seconds = 4.0
	await _wait_match(brawl)
	await _frames(60)                                # 0,8 giây sau khi roulette bắt đầu: đang quay
	await _shot("arena%d_event_roulette" % index)
	ev.enabled = false
	await _frames(20)
	await _shot("arena%d_event_roulette2" % index)   # chụp thêm một khung nữa, tên khác đang hiện
	ev.start_event("ice_floor")                      # bỏ qua roulette, vào thẳng sàn băng
	await _frames(70)
	await _shot("arena%d_event_ice" % index)
	ev.hot_potato_seconds = 5.0
	ev.start_event("hot_potato")                     # bom bốc ngẫu nhiên cho một người
	await _frames(45)
	await _shot("arena%d_event_bomb" % index)
	ev.time_left = 2.0                               # ngòi sắp hết: nhấp nháy nhanh, số vàng
	await _frames(25)
	await _shot("arena%d_event_bomb_late" % index)
	await _frames(4)
	await _shot("arena%d_event_bomb_late2" % index)  # vài khung sau: bắt được nhịp "đỏ" của nhấp nháy
	await _frames(4)
	await _shot("arena%d_event_bomb_late3" % index)
	ev.start_event("reversed_keys")                  # banner sự kiện khác (màu cam)
	await _frames(40)
	await _shot("arena%d_event_reversed" % index)
	brawl.queue_free()
	await _frames(3)


## Dựng cảnh đấu với đấu trường số `index`, giới thiệu dài một chút để kịp chụp READY...
func _start(index: int) -> Brawl:
	var brawl: Brawl = load("res://scenes/brawl.tscn").instantiate()
	brawl.arena_index = index
	brawl.intro_seconds = 0.9
	brawl.respawn_delay = 0.4
	brawl.win_panel_delay = 0.4
	add_child(brawl)
	await _frames(2)
	return brawl


func _wait_match(brawl: Brawl) -> void:
	while not brawl.match_running:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if dir != "" and img:
		img.save_png(dir.path_join(shot_name + ".png"))


## Ảnh vật phẩm troll, vương miện người dẫn điểm và câu châm chọc dài nhất:
## hộp "?" trên sân, mỗi vật phẩm trong tay (hiện ở ô cạnh điểm), chuối trên nạn nhân, bẫy lò xo, người dẫn điểm to + vương miện, câu dài nhất.
func _item_shots(index: int) -> void:
	var brawl := await _start(index)
	brawl.events.enabled = false
	brawl.items.enabled = false                      # hộp chỉ mọc khi ta gọi spawn_box
	await _wait_match(brawl)
	await _frames(40)
	var it := brawl.items
	var a := brawl.balls[0]
	var b := brawl.balls[1]
	it.spawn_box("gun")
	it.spawn_box("banana")
	await _frames(50)
	await _shot("arena%d_items_boxes" % index)       # hai hộp "?" trên sân
	for bx in it.boxes.duplicate():
		it.boxes.erase(bx)
		bx.queue_free()
	var others := {"gun": "spring", "banana": "swap", "swap": "gun", "spring": "banana"}   # người chơi 2 cầm món khác để thấy cả hai ô
	for id in BrawlItems.ITEM_IDS:
		it.give(a, id)
		it.give(b, others[id])
		await _frames(6)
		await _shot("arena%d_item_%s" % [index, id])  # P1 cầm `id`, P2 cầm món khác
	it.give(a, "banana")
	it.give(b, "banana")
	it.banana_seconds = 6.0
	it.use(a)                                        # P2 bị chuối
	await _frames(25)
	await _shot("arena%d_item_banana_effect" % index)
	it.give(b, "spring")
	it.use(b)                                        # P2 thả bẫy lò xo (còn bị chuối)
	b.teleport(b.global_position + Vector2(-110, 0)) # bước ra khỏi bẫy
	await _frames(45)
	await _shot("arena%d_item_spring_trap" % index)  # bẫy đã lên cò
	for trap in it.traps.duplicate():                # dọn bẫy (P2 hồi sinh đúng chỗ bẫy sẽ bị bắn bay mất)
		it.traps.erase(trap)
		trap.queue_free()
	brawl.kill(b, "pit")                             # P1 ghi điểm: dẫn 1-0, to hơn và đội vương miện
	await _frames(90)                                # P2 hồi sinh
	await _shot("arena%d_crown_leader" % index)
	var font := UiTheme.main_font()                  # tìm câu châm chọc dài nhất (khi đã thay tên P1 / P2)
	var widest := ""
	var widest_w := 0.0
	for cause in BrawlData.TAUNTS:
		for line in BrawlData.TAUNTS[cause]:
			for pair in [[1, 2], [2, 1]]:
				var text := String(line).format({"s": "P%d" % pair[0], "v": "P%d" % pair[1]})
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE).x
				if w > widest_w:
					widest_w = w
					widest = text
	print("longest taunt: '%s' %.0f px at FONT_LARGE" % [widest, widest_w])
	brawl.hud.flash(widest, 6.0, BrawlHud.PLAYER_COLORS[0])
	await _frames(5)
	await _shot("arena%d_taunt_longest" % index)
	brawl.queue_free()
	await _frames(3)
