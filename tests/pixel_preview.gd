extends Node
## Chụp mọi hình trong PixelArt (cũ và mới) để kiểm tra bằng mắt.
## Chạy có cửa sổ (không --headless): godot --path . res://tests/pixel_preview.tscn -- --shots=<thư mục>

const PX := 6.0                                 # mỗi điểm ảnh vẽ thành ô 6 x 6
const CELL := Vector2(170, 150)                 # ô lưới cho mỗi hình (rộng x cao)
const COLS := 6                                 # số cột trong lưới
const ORIGIN := Vector2(20, 20)                 # lề trên trái
const BG := Color("#1b1626")                    # màu nền tối

# Danh sách mọi hình: [tên, mảng chuỗi]
var items := [
	["HEART", PixelArt.HEART],
	["SHIELD", PixelArt.SHIELD],
	["GUN", PixelArt.GUN],
	["BULLET", PixelArt.BULLET],
	["EXCLAIM", PixelArt.EXCLAIM],
	["BOSS", PixelArt.BOSS],
	["CROWN", PixelArt.CROWN],
	["BANANA", PixelArt.BANANA],
	["BOMB", PixelArt.BOMB],
	["SWAP", PixelArt.SWAP],
	["SPRING", PixelArt.SPRING],
	["ANCHOR", PixelArt.ANCHOR],
]


func _ready() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	var board := Node2D.new()
	add_child(board)
	board.draw.connect(_draw_board.bind(board))     # vẽ hình bằng PixelArt.draw khi board được vẽ
	for i in items.size():
		var cell_origin := _cell_origin(i)
		var label := Label.new()                    # tên hình nằm dưới mỗi hình
		label.text = items[i][0]
		label.position = cell_origin + Vector2(0, 118)
		label.size = Vector2(CELL.x, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		board.add_child(label)
	for k in 20:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("pixel_icons.png"))
	get_tree().quit()


## Góc trên trái của ô thứ `i` trong lưới.
func _cell_origin(i: int) -> Vector2:
	var col: int = i % COLS
	var row: int = i / COLS
	return ORIGIN + Vector2(col * CELL.x, row * CELL.y)


## Vẽ nền tối rồi từng hình, căn giữa trong phần trên của ô (cao 110 điểm ảnh).
func _draw_board(board: Node2D) -> void:
	board.draw_rect(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size), BG)
	for i in items.size():
		var pattern: Array = items[i][1]
		var psize := PixelArt.size_of(pattern, PX)
		var top_left := _cell_origin(i) + Vector2((CELL.x - psize.x) / 2.0, 110.0 - psize.y)
		PixelArt.draw(board, pattern, top_left, PX)
