extends Node
## Autoload "Game" (gọi được từ mọi script bằng tên Game).
## Cài phím, chuyển giữa menu / màn thường / chế độ vô tận, và LƯU tiến độ vào máy:
## điểm cao nhất chế độ vô tận, tổng số sao đã gom (giống "xu" của Subway Surfers), số sao tốt nhất mỗi màn.

const MENU_SCENE := "res://scenes/menu.tscn"
const PLAY_SCENE := "res://scenes/play.tscn"
const ENDLESS_SCENE := "res://scenes/endless.tscn"
const SAVE_PATH := "user://bouncing_ball.cfg"   # file lưu (nằm trong thư mục dữ liệu của Godot trên máy)

## Phím điều khiển. Muốn đổi phím thì sửa ở đây (KEY_A, KEY_SPACE, KEY_LEFT...).
## Giữ A/← hoặc D/→ để nghiêng và tích lực; bấm Space / W / ↑ để nhảy.
const KEYS := {
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"shoot": [KEY_F, KEY_J],    # bắn (khi đã nhặt súng)
	"restart": [KEY_R],        # tự nổ, về cờ lưu / đầu đoạn
	"back": [KEY_ESCAPE],      # về menu
}

var level_index := 0       # màn thường đang chơi (0 = màn đầu trong LevelData.LEVELS)
var best_stars := {}       # số sao nhiều nhất từng màn thường: {chỉ số màn: số sao}
var best_score := 0        # điểm cao nhất chế độ vô tận
var total_stars := 0       # tổng số sao đã gom qua mọi lượt chơi
var save_enabled := true   # bài test tắt đi để không ghi đè kỷ lục thật


## Godot gọi một lần khi mở game: cài phím, đọc file lưu.
func _ready() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)          # tạo hành động, ví dụ "jump"
		InputMap.action_erase_events(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key            # gán phím vật lý cho hành động
			InputMap.action_add_event(action, ev)
	load_progress()


## Vào chơi màn thường số `index`.
func start_level(index: int) -> void:
	level_index = index
	get_tree().change_scene_to_file(PLAY_SCENE)


## Vào chế độ vô tận.
func start_endless() -> void:
	get_tree().change_scene_to_file(ENDLESS_SCENE)


## Sang màn kế tiếp. Trả về false nếu đã là màn cuối.
func next_level() -> bool:
	if level_index + 1 >= LevelData.LEVELS.size():
		return false
	start_level(level_index + 1)
	return true


## Ghi lại số sao nếu nhiều hơn lần trước (màn thường), cộng vào tổng sao.
func record_stars(index: int, stars: int) -> void:
	best_stars[index] = maxi(stars, best_stars.get(index, 0))
	total_stars += stars
	save_progress()


## Kết thúc một lượt vô tận: cộng sao, cập nhật kỷ lục. Trả về true nếu phá kỷ lục.
func record_endless(score: int, stars: int) -> bool:
	total_stars += stars
	var new_best := score > best_score
	best_score = maxi(best_score, score)
	save_progress()
	return new_best


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


## Lưu tiến độ ra file.
func save_progress() -> void:
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "total_stars", total_stars)
	cfg.set_value("progress", "best_stars", best_stars)
	cfg.save(SAVE_PATH)


## Đọc tiến độ từ file (lần đầu chơi chưa có file thì giữ giá trị 0).
func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_score = cfg.get_value("progress", "best_score", 0)
	total_stars = cfg.get_value("progress", "total_stars", 0)
	best_stars = cfg.get_value("progress", "best_stars", {})
