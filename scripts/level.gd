class_name Level                       # tên lớp để đồ vật gọi Level.of(...)
extends Node2D                         # màn chơi là một node 2D chứa mọi thứ
## Dựng màn chơi từ bản đồ chữ (xem scripts/level_data.gd) và vẽ địa hình.
## Mỗi ký tự là một ô 32 x 32 pixel. Bảng ký tự nằm ở đầu file level_data.gd.
## Level cũng là "trạm trung chuyển": đồ vật gọi các hàm ở đây (nhặt sao, cắm cờ, đè nút...),
## Level phát tín hiệu để play.gd và cửa nghe.

signal star_collected                  # nhặt được một ngôi sao
signal star_collected_by(ball: Ball)   # nhặt được một ngôi sao, kèm quả bóng nhặt (null nếu không rõ)
signal checkpoint_reached(pos: Vector2)   # chạm cờ lưu, kèm vị trí hồi sinh
signal finished                        # chạm đích: qua màn
signal channel_changed(channel: String, on: bool)   # một kênh nút/cửa vừa mở hoặc đóng
signal heart_collected                 # nhặt trái tim: play/endless +1 mạng
signal boss_started(boss: Node)        # boss bắt đầu đánh: hiện thanh máu
signal boss_defeated(boss: Node)       # boss chết: ẩn thanh máu, mở cổng G

const TILE := 32.0                     # kích thước một ô (pixel)
const ENEMY := preload("res://scenes/objects/enemy.tscn")             # cảnh quái đi tuần
const CRATE := preload("res://scenes/objects/crate.tscn")             # cảnh thùng gỗ
const SPIKES := preload("res://scenes/objects/spikes.tscn")           # cảnh bẫy gai
const BUTTON := preload("res://scenes/objects/pressure_button.tscn")  # cảnh nút đè
const DOOR := preload("res://scenes/objects/door.tscn")               # cảnh cánh cửa
const PLATFORM := preload("res://scenes/objects/moving_platform.tscn")   # cảnh bệ di chuyển
const SEESAW := preload("res://scenes/objects/seesaw.tscn")           # cảnh bập bênh
const PICKUP := preload("res://scenes/objects/pickup.tscn")           # cảnh vật nhặt (sao, cờ, tim...)
const BOSS := preload("res://scenes/objects/boss.tscn")               # cảnh boss

const BUTTON_CHARS := "abd"           # nút a, b, d
const DOOR_CHARS := "ABD"             # cửa A, B, D (mở bởi nút cùng chữ thường)
# ký tự trên bản đồ -> loại vật nhặt tương ứng
const PICKUP_KINDS := {"*": "star", "K": "checkpoint", "F": "finish", "T": "trampoline",
	"+": "heart", "h": "shield", "g": "gun", "j": "jump_boost"}
const BOSS_GATE := "G"                 # cổng chặn đường, mở khi boss chết

## Dốc (mặt đất nghiêng). Mỗi dốc là một đa giác trong ô, tọa độ tính theo ô (0..1, y hướng xuống).
## Ghép các dốc với # để tạo đồi, thung lũng uốn lượn.
##   /  dốc đứng đi lên (sang phải cao dần)     \  dốc đứng đi xuống
##   1  nửa dưới dốc thoải đi lên               2  nửa trên dốc thoải đi lên (đặt 1 rồi 2 liền nhau)
##   3  nửa trên dốc thoải đi xuống             4  nửa dưới dốc thoải đi xuống (đặt 3 rồi 4 liền nhau)
const SLOPES := {
	# hai điểm đầu của mỗi đa giác luôn là mép trái và mép phải của mặt dốc
	"/": [Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)],
	"\\": [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)],
	"1": [Vector2(0, 1), Vector2(1, 0.5), Vector2(1, 1)],
	"2": [Vector2(0, 0.5), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	"3": [Vector2(0, 0), Vector2(1, 0.5), Vector2(1, 1), Vector2(0, 1)],
	"4": [Vector2(0, 0.5), Vector2(1, 1), Vector2(0, 1)],
}
## Màu lớp cỏ trên mặt dốc (lấy theo màu cỏ của bộ gạch).
const SLOPE_GRASS := Color("#7fc241")        # màu cỏ chính
const SLOPE_GRASS_LIGHT := Color("#b7e36a")  # màu viền sáng phía trên
const SLOPE_GRASS_DARK := Color("#3f6b2a")   # màu viền tối phía dưới

## Hình địa hình (gói Dark Fantasia Forest). Mỗi ô gốc 16 x 16, vẽ phóng to gấp 2 thành 32 x 32.
const TILES := preload("res://assets/forest/forest_tiles.png")         # ảnh bộ gạch đất
const DECOR := preload("res://assets/forest/forest_decorations.png")   # ảnh đồ trang trí
const SRC_TILE := 16.0                       # kích thước ô trong ảnh gốc (pixel)
## Đồ trang trí lấy từ forest_decorations.png (vùng hình tính bằng pixel gốc). Thêm/bớt vùng ở đây.
const DECOR_KINDS := [
	Rect2(64, 192, 32, 32),     # nấm đỏ
	Rect2(96, 160, 32, 32),     # cụm nấm xanh
]
## Không dùng bụi gai khô (0, 128) và bụi lá nhọn (96, 192): trông giống bẫy gai, dễ làm người chơi hiểu nhầm.

@export var decorate := true          # rải nấm, hoa trang trí lên mặt cỏ

var rows: PackedStringArray = []      # các hàng của bản đồ chữ
var cols := 0                         # số cột
var size := Vector2.ZERO              # kích thước màn tính bằng pixel
var start_position := Vector2.ZERO    # chỗ bóng xuất hiện (ký tự O)
var star_total := 0                   # tổng số sao trong màn
var _pressed := {}                    # kênh -> các nút đang bị đè ở kênh đó
var _open := {}                       # kênh -> đang mở hay không


## Tìm Level chứa một node bất kỳ (đồ vật dùng để gọi Level).
static func of(node: Node) -> Level:
	var n := node                         # bắt đầu từ chính node đó
	while n and not n is Level:           # chưa gặp Level thì đi tiếp lên trên
		n = n.get_parent()                # leo lên node cha
	return n as Level                     # trả về Level tìm được (hoặc null)


## Màu của từng kênh nút/cửa: a đỏ, b xanh dương, d tím.
static func channel_color(channel: String) -> Color:
	# tra màu theo tên kênh; kênh lạ thì dùng màu trắng
	return {"a": Color("#ff5d5d"), "b": Color("#4da3ff"), "d": Color("#b46bff"), "boss": Color("#e8455a")}.get(channel, Color.WHITE)


## Đọc bản đồ chữ và tạo mọi thứ.
func build(map: String) -> void:
	for line in map.strip_edges(false, true).split("\n"):   # cắt bản đồ thành từng dòng
		if line.strip_edges() != "":                # bỏ qua dòng trống
			rows.append(line)                       # lưu dòng vào danh sách hàng
	for r in rows:                                  # duyệt từng hàng
		cols = maxi(cols, r.length())               # số cột = độ dài hàng dài nhất
	for i in rows.size():                           # duyệt chỉ số từng hàng
		rows[i] = rows[i].rpad(cols, ".")          # hàng ngắn thì thêm ô trống cho đủ
	size = Vector2(cols, rows.size()) * TILE        # tính kích thước màn ra pixel

	_build_terrain()                                # tạo va chạm cho đất và dốc
	_build_doors()                                  # tạo các cánh cửa
	_build_platforms()                              # tạo các bệ di chuyển
	for r in rows.size():                           # duyệt từng hàng
		for c in cols:                              # duyệt từng cột
			_place(rows[r][c], r, c)                # đặt vật theo ký tự ở ô này
	queue_redraw()                                  # vẽ lại địa hình


## Ký tự ở ô (r, c); ngoài bản đồ thì coi là ô trống.
func char_at(r: int, c: int) -> String:
	if r < 0 or r >= rows.size() or c < 0 or c >= cols:   # ô nằm ngoài bản đồ
		return "."                                  # coi là ô trống
	return rows[r][c]                               # trả về ký tự thật


## Tạo một vật theo ký tự. Vị trí "chân" của ô = giữa cạnh dưới ô.
func _place(ch: String, r: int, c: int) -> void:
	var foot := Vector2((c + 0.5) * TILE, (r + 1) * TILE)   # điểm giữa đáy ô
	match ch:                                       # xem ký tự là gì
		"O":
			start_position = foot + Vector2(0, -16)     # chỗ bóng xuất hiện, cao hơn đáy ô nửa thân
		"e":
			var e: Node2D = ENEMY.instantiate()         # tạo một con quái
			e.position = foot + Vector2(0, -Enemy.HALF.y)    # tâm quái cao hơn mặt đất nửa thân
			add_child(e)                                # thêm quái vào màn
		"x":
			var x: Node2D = CRATE.instantiate()         # tạo một thùng gỗ
			x.position = foot + Vector2(0, -Crate.SIZE / 2.0 - 1.0)   # đặt thùng ngồi trên đáy ô
			add_child(x)                                # thêm thùng vào màn
		"^", "v":
			var s: Node2D = SPIKES.instantiate()        # tạo bẫy gai
			if ch == "v":                               # gai chĩa xuống
				s.position = Vector2((c + 0.5) * TILE, r * TILE)   # gắn ở cạnh trên ô
				s.rotation = PI                       # gai treo ngược trên trần
			else:
				s.position = foot                       # gai chĩa lên đặt ở đáy ô
			add_child(s)                                # thêm gai vào màn
		"S":
			var w: Node2D = SEESAW.instantiate()        # tạo bập bênh
			w.position = Vector2((c + 0.5) * TILE, (r + 0.5) * TILE)   # đặt ở giữa ô
			add_child(w)                                # thêm bập bênh vào màn
		"M":
			var boss: Node2D = BOSS.instantiate()       # tạo boss
			boss.position = foot + Vector2(0, -30)        # boss nằm trên mặt đất của ô này (bán kính 30)
			add_child(boss)                             # thêm boss vào màn
		_:
			if ch in PICKUP_KINDS:                      # ký tự là một vật nhặt
				var p: Pickup = PICKUP.instantiate()    # tạo vật nhặt
				p.kind = PICKUP_KINDS[ch]               # chọn loại theo ký tự
				p.position = foot                       # đặt ở đáy ô
				add_child(p)                            # thêm vào màn
				if ch == "*":                           # là ngôi sao
					star_total += 1                     # đếm tổng số sao
			elif ch != "" and ch in BUTTON_CHARS:       # ký tự là nút đè
				var b: PressureButton = BUTTON.instantiate()   # tạo nút
				b.channel = ch                          # kênh của nút = chữ cái
				b.position = foot                       # đặt ở đáy ô
				add_child(b)                            # thêm nút vào màn


## Đất (#): gộp các ô # liền nhau trên cùng một hàng thành một hình chữ nhật va chạm,
## để bóng lăn êm không bị vấp ở chỗ nối giữa các ô.
func _build_terrain() -> void:
	var body := StaticBody2D.new()                  # thân đứng yên chứa mọi va chạm của đất
	body.name = "Terrain"                           # đặt tên để dễ tìm
	body.collision_layer = 1                        # đất nằm ở lớp va chạm 1
	body.collision_mask = 0                         # đất không cần dò va chạm với ai
	var mat := PhysicsMaterial.new()                # vật liệu vật lý cho đất
	mat.friction = 1.0                              # ma sát cao để bóng lăn bám
	body.physics_material_override = mat            # gán vật liệu cho đất
	add_child(body)                                 # thêm đất vào màn
	for r in rows.size():                           # duyệt từng hàng
		var c := 0                                  # bắt đầu từ cột 0
		while c < cols:                             # quét hết hàng
			if rows[r][c] != "#":                   # không phải đất
				c += 1                              # sang ô kế
				continue
			var start := c                          # nhớ cột bắt đầu dải đất
			while c < cols and rows[r][c] == "#":   # đi tiếp khi còn là đất
				c += 1                              # mở rộng dải đất
			var shape := CollisionShape2D.new()     # tạo hình va chạm
			var rect := RectangleShape2D.new()      # hình chữ nhật
			rect.size = Vector2((c - start) * TILE, TILE)   # rộng bằng cả dải, cao 1 ô
			shape.shape = rect                      # gán hình chữ nhật
			shape.position = Vector2(start * TILE, r * TILE) + rect.size / 2.0   # đặt tâm giữa dải
			body.add_child(shape)                   # gắn vào thân đất
	# Dốc: mỗi ô dốc là một đa giác va chạm riêng.
	for r in rows.size():                           # duyệt từng hàng
		for c in cols:                              # duyệt từng cột
			var ch := rows[r][c]                    # ký tự ở ô
			if not SLOPES.has(ch):                  # không phải dốc thì bỏ qua
				continue
			var shape := CollisionShape2D.new()     # tạo hình va chạm
			var poly := ConvexPolygonShape2D.new()  # hình đa giác lồi
			var pts := PackedVector2Array()         # danh sách đỉnh
			for v in SLOPES[ch]:                    # từng đỉnh của dốc
				pts.append(Vector2(v) * TILE)       # đổi từ đơn vị ô ra pixel
			poly.points = pts                       # gán các đỉnh
			shape.shape = poly                      # gán đa giác
			shape.position = Vector2(c, r) * TILE   # đặt ở góc trên trái ô
			body.add_child(shape)                   # gắn vào thân đất


## Cửa (A, B, D): mỗi cột chữ liền nhau thành một cánh cửa. Cổng G mở khi boss chết (kênh "boss").
func _build_doors() -> void:
	for c in cols:                                  # duyệt từng cột
		var r := 0                                  # bắt đầu từ hàng 0
		while r < rows.size():                      # quét xuống hết cột
			var ch := rows[r][c]                    # ký tự ở ô
			if not (ch in DOOR_CHARS or ch == BOSS_GATE):   # không phải cửa
				r += 1                              # xuống ô kế
				continue
			var start := r                          # nhớ hàng bắt đầu cửa
			while r < rows.size() and rows[r][c] == ch:   # đi xuống khi còn cùng chữ
				r += 1                              # cửa cao thêm một ô
			var d: Door = DOOR.instantiate()        # tạo cánh cửa
			d.channel = "boss" if ch == BOSS_GATE else ch.to_lower()   # kênh mở cửa (chữ thường hoặc boss)
			d.height_tiles = r - start              # chiều cao cửa tính bằng ô
			d.position = Vector2(c, start) * TILE   # đặt ở ô trên cùng
			add_child(d)                            # thêm cửa vào màn


## Bệ di chuyển (===): tìm dấu > cùng hàng (đi ngang) hoặc | cùng cột ô đầu (đi dọc).
func _build_platforms() -> void:
	for r in rows.size():                           # duyệt từng hàng
		var c := 0                                  # bắt đầu từ cột 0
		while c < cols:                             # quét hết hàng
			if rows[r][c] != "=":                   # không phải bệ
				c += 1                              # sang ô kế
				continue
			var start := c                          # nhớ cột bắt đầu bệ
			while c < cols and rows[r][c] == "=":   # đi tiếp khi còn là bệ
				c += 1                              # bệ dài thêm một ô
			var p: MovingPlatform = PLATFORM.instantiate()   # tạo bệ di chuyển
			p.width_tiles = c - start               # bệ rộng bao nhiêu ô
			p.from = Vector2(start, r) * TILE       # điểm xuất phát
			p.to = p.from                           # mặc định đứng yên
			var right := rows[r].find(">", c)       # tìm dấu > ở phía phải
			if right != -1:                         # có dấu >
				p.to = Vector2(right, r) * TILE                # ô đầu của bệ sẽ tới cột của dấu >
			else:
				for rr in rows.size():              # tìm dấu | trong cùng cột
					if rows[rr][start] == "|":      # gặp dấu |
						p.to = Vector2(start, rr) * TILE      # bệ đi dọc tới hàng của dấu |
			add_child(p)                            # thêm bệ vào màn


# ---- Đồ vật gọi các hàm dưới đây ----

## Đặt mọi thùng về chỗ cũ (play.gd gọi khi bóng hồi sinh).
func reset_crates() -> void:
	for c in get_children():                        # duyệt mọi node con của màn
		if c is Crate:                              # là thùng gỗ
			c.reset()                               # đưa thùng về chỗ cũ


## Nhặt một sao; `by` là quả bóng nhặt (không bắt buộc).
func collect_star(by: Ball = null) -> void:
	star_collected.emit()                           # báo đã nhặt một sao (người nghe cũ vẫn chạy)
	star_collected_by.emit(by)                      # báo thêm ai là người nhặt


func collect_heart() -> void:
	heart_collected.emit()                          # báo đã nhặt trái tim


## Boss gọi khi bắt đầu đánh.
func start_boss(boss: Node) -> void:
	boss_started.emit(boss)                         # báo bắt đầu đấu boss (hiện thanh máu)


## Boss gọi khi chết: mở cổng G.
func defeat_boss(boss: Node) -> void:
	boss_defeated.emit(boss)                        # báo đã thắng boss
	_open["boss"] = true                            # ghi nhớ kênh boss đang mở
	channel_changed.emit("boss", true)              # báo cổng G mở ra


func reach_checkpoint(pos: Vector2) -> void:
	checkpoint_reached.emit(pos)                    # báo chỗ hồi sinh mới


func finish() -> void:
	finished.emit()                                 # báo qua màn


## Nút báo bị đè / thả. Kênh mở khi có ít nhất một nút của kênh đó đang bị đè.
func set_button(channel: String, button: Node, is_pressed: bool) -> void:
	var set_: Dictionary = _pressed.get_or_add(channel, {})   # tập nút đang bị đè của kênh (tạo mới nếu chưa có)
	if is_pressed:                                  # nút bị đè
		set_[button] = true                         # thêm nút vào tập
	else:
		set_.erase(button)                          # nút được thả: bỏ khỏi tập
	var now := not set_.is_empty()                  # còn nút nào bị đè thì kênh mở
	if now != _open.get(channel, false):            # trạng thái kênh vừa thay đổi
		_open[channel] = now                        # lưu trạng thái mới
		channel_changed.emit(channel, now)          # báo cho cửa biết để mở/đóng


## Vẽ địa hình bằng bộ gạch rừng (assets/forest/forest_tiles.png, mỗi ô gốc 16 x 16, vẽ phóng to gấp 2).
## Mỗi ô đất được ghép từ 4 góc nhỏ 8 x 8. Mỗi góc chọn hình theo 2 ô hàng xóm sát nó:
## lộ thiên phía trên thì lấy hình có cỏ, lộ thiên bên trái thì lấy hình mép trái, v.v.
## Nhờ vậy đất tự có mép đẹp với mọi hình dạng bạn vẽ trong bản đồ chữ.
func _draw() -> void:
	for r in rows.size():                           # duyệt từng hàng
		for c in cols:                              # duyệt từng cột
			if rows[r][c] != "#":                   # chỉ vẽ ô đất
				continue
			var up := _solid(r - 1, c)              # ô trên có phải đất không
			var down := _solid(r + 1, c)            # ô dưới có phải đất không
			var left := _solid(r, c - 1)            # ô trái có phải đất không
			var right := _solid(r, c + 1)           # ô phải có phải đất không
			var v := (r * 7 + c * 13) % 4                    # chọn ngẫu nhiên (cố định) 1 trong 4 biến thể cho đỡ lặp
			var cell := Vector2(c, r) * TILE        # góc trên trái của ô trên màn
			_quad(cell, 0, 0, _pick(up, left, Vector2i(0, 0), Vector2i(1 + v, 0), Vector2i(0, 1 + v), v))      # góc trên trái
			_quad(cell, 1, 0, _pick(up, right, Vector2i(5, 0), Vector2i(1 + v, 0), Vector2i(5, 1 + v), v))     # góc trên phải
			_quad(cell, 0, 1, _pick(down, left, Vector2i(0, 5), Vector2i(1 + v, 5), Vector2i(0, 1 + v), v))    # góc dưới trái
			_quad(cell, 1, 1, _pick(down, right, Vector2i(5, 5), Vector2i(1 + v, 5), Vector2i(5, 1 + v), v))   # góc dưới phải
	_draw_slopes()                                  # vẽ các ô dốc
	if decorate:                                    # có bật trang trí
		_draw_decorations()                         # rải nấm lên mặt cỏ


## Vẽ dốc: ruột đất lấy hoa văn ô đất trong bộ gạch, mặt trên là một dải cỏ chạy theo độ nghiêng.
func _draw_slopes() -> void:
	var tex_size := Vector2(TILES.get_width(), TILES.get_height())   # kích thước ảnh gạch (để tính UV)
	for r in rows.size():                           # duyệt từng hàng
		for c in cols:                              # duyệt từng cột
			var ch := rows[r][c]                    # ký tự ở ô
			if not SLOPES.has(ch):                  # không phải dốc thì bỏ qua
				continue
			var cell := Vector2(c, r) * TILE        # góc trên trái của ô
			var pts := PackedVector2Array()         # các đỉnh trên màn
			var uvs := PackedVector2Array()         # vị trí tương ứng trong ảnh gạch
			for v in SLOPES[ch]:                    # từng đỉnh của dốc
				pts.append(cell + Vector2(v) * TILE)   # đỉnh tính ra pixel trên màn
				uvs.append((Vector2(16, 16) + Vector2(v) * SRC_TILE) / tex_size)   # dùng ô ruột đất (1, 1)
			draw_colored_polygon(pts, Color.WHITE, uvs, TILES)   # tô đa giác bằng hoa văn đất
			var a: Vector2 = cell + Vector2(SLOPES[ch][0]) * TILE      # điểm trái của mặt dốc
			var b: Vector2 = cell + Vector2(SLOPES[ch][1]) * TILE      # điểm phải của mặt dốc
			# dải cỏ dày 10 pixel chạy dọc mặt dốc
			draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 10), a + Vector2(0, 10)]), SLOPE_GRASS)
			draw_line(a + Vector2(0, 1), b + Vector2(0, 1), SLOPE_GRASS_LIGHT, 2.0)     # viền sáng mép trên cỏ
			draw_line(a + Vector2(0, 11), b + Vector2(0, 11), SLOPE_GRASS_DARK, 2.0)    # viền tối mép dưới cỏ


## Ô (r, c) có phải đất không. Ngoài bản đồ cũng coi là đất, để mép màn không bị vẽ viền.
func _solid(r: int, c: int) -> bool:
	if r < 0 or r >= rows.size() or c < 0 or c >= cols:   # ô ngoài bản đồ
		return true                                 # coi là đất
	return rows[r][c] == "#" or SLOPES.has(rows[r][c])   # đất hoặc dốc đều tính là đất


## Chọn ô gốc cho một góc: hai phía đều lộ -> ô góc; chỉ phía trên/dưới lộ -> ô cỏ/đáy;
## chỉ phía bên lộ -> ô mép bên; không phía nào lộ -> ô ruột đất.
func _pick(vert: bool, side: bool, corner: Vector2i, edge_v: Vector2i, edge_s: Vector2i, v: int) -> Vector2i:
	if not vert and not side:                       # cả trên/dưới và bên đều trống
		return corner                               # dùng hình góc
	if not vert:                                    # chỉ trên/dưới trống
		return edge_v                               # dùng hình mép cỏ / đáy
	if not side:                                    # chỉ bên cạnh trống
		return edge_s                               # dùng hình mép bên
	return Vector2i(1 + v, 1 + (v + 1) % 4)         # bị bao kín: dùng hình ruột đất (có biến thể)


## Vẽ một góc 8 x 8 (qx, qy là 0 hoặc 1) lấy từ ô gốc `src` lên ô màn tại `cell`.
func _quad(cell: Vector2, qx: int, qy: int, src: Vector2i) -> void:
	# vùng 8x8 cần cắt trong ảnh gạch gốc
	var src_rect := Rect2(Vector2(src) * SRC_TILE + Vector2(qx, qy) * SRC_TILE / 2.0, Vector2.ONE * SRC_TILE / 2.0)
	var dst_rect := Rect2(cell + Vector2(qx, qy) * TILE / 2.0, Vector2.ONE * TILE / 2.0)   # vùng 16x16 trên màn
	draw_texture_rect_region(TILES, dst_rect, src_rect)   # cắt ảnh và vẽ phóng to


## Rải nấm, hoa, cây lên mặt cỏ cho sinh động. Chỉ để trang trí: không va chạm, không ảnh hưởng lối chơi.
## Đặt ở ô đất có cỏ, phía trên trống 2 ô và không có đồ vật, cách nhau ít nhất 5 ô.
func _draw_decorations() -> void:
	var last_c := -100                              # cột vừa đặt trang trí (bắt đầu ở rất xa)
	for c in cols:                                  # duyệt từng cột
		for r in range(2, rows.size()):             # duyệt từng hàng, bỏ 2 hàng trên cùng
			# phải là đất có cỏ, 2 ô phía trên đều trống
			if rows[r][c] != "#" or _solid(r - 1, c) or char_at(r - 1, c) != "." or char_at(r - 2, c) != ".":
				continue
			if char_at(r - 1, c - 1) != "." or char_at(r - 1, c + 1) != ".":   # hai bên phía trên có đồ vật
				continue                                  # sát đồ vật khác: bỏ qua cho đỡ rối
			if not (_solid(r, c - 2) and _solid(r, c + 2)) or _solid(r - 1, c - 2) or _solid(r - 1, c + 2):   # nền không đủ rộng và phẳng
				continue                                  # chỉ mọc trên nền đất rộng, không mọc trên cột hẹp / mô đất nhỏ
			var h := (c * 31 + r * 17) % 11         # số "ngẫu nhiên" cố định theo vị trí
			if h > 2 or c - last_c < 5:             # chỉ mọc ở vài chỗ và cách nhau ít nhất 5 ô
				continue
			var d: Rect2 = DECOR_KINDS[(c * 7 + r) % DECOR_KINDS.size()]   # chọn một loại trang trí
			var size_px := d.size * 2.0                   # phóng to gấp 2 như gạch
			var foot := Vector2((c + 0.5) * TILE, r * TILE)   # điểm giữa mặt trên của ô đất
			draw_texture_rect_region(DECOR, Rect2(foot - Vector2(size_px.x / 2.0, size_px.y), size_px), d)   # vẽ đứng trên mặt cỏ
			last_c = c                              # nhớ cột vừa đặt
