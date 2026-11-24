extends Node
## Autoload "Game" (gọi được từ mọi script bằng tên Game).
## Cài phím, chuyển giữa menu / màn thường / chế độ vô tận, và LƯU tiến độ vào máy:
## điểm cao nhất chế độ vô tận, tổng số sao đã gom (giống "xu" của Subway Surfers), số sao tốt nhất mỗi màn.

const MENU_SCENE := "res://scenes/menu.tscn"         # đường dẫn cảnh menu
const PLAY_SCENE := "res://scenes/play.tscn"         # đường dẫn cảnh chơi màn thường
const ENDLESS_SCENE := "res://scenes/endless.tscn"   # đường dẫn cảnh chế độ vô tận
const BRAWL_SCENE := "res://scenes/brawl.tscn"      # đường dẫn cảnh chế độ đấu 2 người (Bounce Brawl)
const SAVE_PATH :="user://bouncing_ball.cfg"   # file lưu (nằm trong thư mục dữ liệu của Godot trên máy)

## Phím điều khiển. Muốn đổi phím thì sửa ở đây (KEY_A, KEY_SPACE, KEY_LEFT...).
## Giữ A/← hoặc D/→ để nghiêng và tích lực; bấm Space / W / ↑ để nhảy.
const KEYS := {
	"left": [KEY_A, KEY_LEFT],   # sang trái
	"right": [KEY_D, KEY_RIGHT],   # sang phải
	"jump": [KEY_SPACE, KEY_W, KEY_UP],   # nhảy
	"shoot": [KEY_F, KEY_J],    # bắn (khi đã nhặt súng)
	"restart": [KEY_R],        # tự nổ, về cờ lưu / đầu đoạn
	"back": [KEY_ESCAPE],      # về menu
	# Phím riêng cho chế độ 2 người chơi (Ball.action_prefix = "p1_" hoặc "p2_")
	"p1_left": [KEY_A],        # người chơi 1: trái
	"p1_right": [KEY_D],       # người chơi 1: phải
	"p1_jump": [KEY_W],        # người chơi 1: nhảy
	"p1_use": [KEY_S],         # người chơi 1: dùng vật phẩm / kỹ năng
	"p2_left": [KEY_LEFT],     # người chơi 2: trái
	"p2_right": [KEY_RIGHT],   # người chơi 2: phải
	"p2_jump": [KEY_UP],       # người chơi 2: nhảy
	"p2_use": [KEY_DOWN],      # người chơi 2: dùng vật phẩm / kỹ năng
}

var level_index := 0       # màn thường đang chơi (0 = màn đầu trong LevelData.LEVELS)
var best_stars := {}       # số sao nhiều nhất từng màn thường: {chỉ số màn: số sao}
var best_score := 0        # điểm cao nhất chế độ vô tận
var total_stars := 0       # tổng số sao đã gom qua mọi lượt chơi
var save_enabled := true   # bài test tắt đi để không ghi đè kỷ lục thật
var brawl_vs_bot := false  # chế độ đấu 2 người: true = người chơi 2 là máy (Brawl tạo BrawlBot khi cờ này bật)


## Godot gọi một lần khi mở game: cài phím, đọc file lưu.
func _ready() -> void:
	for action in KEYS:                      # duyệt từng hành động (left, right, jump...)
		if not InputMap.has_action(action):  # hành động chưa có trong bảng phím
			InputMap.add_action(action)          # tạo hành động, ví dụ "jump"
		InputMap.action_erase_events(action) # xóa phím cũ của hành động
		for key in KEYS[action]:             # duyệt từng phím của hành động
			var ev := InputEventKey.new()    # tạo sự kiện phím mới
			ev.physical_keycode = key            # gán phím vật lý cho hành động
			InputMap.action_add_event(action, ev)   # thêm phím vào hành động
	load_progress()                          # đọc tiến độ đã lưu


## Vào chơi màn thường số `index`.
func start_level(index: int) -> void:
	level_index = index                      # nhớ màn sẽ chơi
	get_tree().change_scene_to_file(PLAY_SCENE)   # chuyển sang cảnh chơi


## Vào chế độ vô tận.
func start_endless() -> void:
	get_tree().change_scene_to_file(ENDLESS_SCENE)   # chuyển sang cảnh vô tận


## Vào chế độ đấu 2 người (Bounce Brawl). `vs_bot` = true: người chơi 2 do máy điều khiển (BrawlBot).
func start_brawl(vs_bot := false) -> void:
	brawl_vs_bot = vs_bot                    # nhớ để cảnh đấu và nút Rematch dùng lại
	get_tree().change_scene_to_file(BRAWL_SCENE)   # chuyển sang cảnh đấu 2 người


## Sang màn kế tiếp. Trả về false nếu đã là màn cuối.
func next_level() -> bool:
	if level_index + 1 >= LevelData.LEVELS.size():   # đã là màn cuối
		return false                         # báo không còn màn
	start_level(level_index + 1)             # vào màn tiếp theo
	return true                              # báo đã chuyển màn


## Ghi lại số sao nếu nhiều hơn lần trước (màn thường), cộng vào tổng sao.
func record_stars(index: int, stars: int) -> void:
	best_stars[index] = maxi(stars, best_stars.get(index, 0))   # giữ số sao cao nhất của màn
	total_stars += stars                     # cộng vào tổng sao
	save_progress()                          # lưu ra file


## Kết thúc một lượt vô tận: cộng sao, cập nhật kỷ lục. Trả về true nếu phá kỷ lục.
func record_endless(score: int, stars: int) -> bool:
	total_stars += stars                     # cộng sao lượt này vào tổng
	var new_best := score > best_score       # có phá kỷ lục không
	best_score = maxi(best_score, score)     # giữ điểm cao nhất
	save_progress()                          # lưu ra file
	return new_best                          # báo có phá kỷ lục hay không


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)   # chuyển về cảnh menu


## Lưu tiến độ ra file.
func save_progress() -> void:
	if not save_enabled:                     # đang chạy test: không lưu
		return
	var cfg := ConfigFile.new()              # tạo file cấu hình (dạng khóa = giá trị)
	cfg.set_value("progress", "best_score", best_score)     # ghi điểm cao nhất
	cfg.set_value("progress", "total_stars", total_stars)   # ghi tổng sao
	cfg.set_value("progress", "best_stars", best_stars)     # ghi sao tốt nhất từng màn
	cfg.save(SAVE_PATH)                      # ghi ra ổ đĩa


## Đọc tiến độ từ file (lần đầu chơi chưa có file thì giữ giá trị 0).
func load_progress() -> void:
	var cfg := ConfigFile.new()              # tạo đối tượng đọc file cấu hình
	if cfg.load(SAVE_PATH) != OK:            # đọc không được (chưa có file)
		return
	best_score = cfg.get_value("progress", "best_score", 0)     # đọc điểm cao nhất
	total_stars = cfg.get_value("progress", "total_stars", 0)   # đọc tổng sao
	best_stars = cfg.get_value("progress", "best_stars", {})    # đọc sao tốt nhất từng màn
