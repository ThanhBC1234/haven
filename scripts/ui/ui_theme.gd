class_name UiTheme
## Giao diện dùng chung (menu, HUD, bảng qua màn), theo bộ khung SHADOW Series (assets/ui/).
## Khung viền được cắt kiểu "9 phần" (StyleBoxTexture): 4 góc giữ nguyên, các cạnh và giữa co giãn theo nút.
## Đổi màu chữ, font ở các hằng số dưới; đổi khung bằng cách sửa đường dẫn FRAME_*.

const TEXT := Color("#d8f3ef")          # chữ thường (trắng ngả xanh)
const ACCENT := Color("#a3e05a")        # màu nhấn: xanh rêu như cỏ trong bộ gạch
const CYAN := Color("#8ac6c8")          # màu viền khung SHADOW
const DIM := Color("#7d9aa0")           # chữ phụ

const FRAME_NORMAL := "res://assets/ui/frame_4.png"    # nút bình thường
const FRAME_HOVER := "res://assets/ui/frame_1.png"     # nút khi rê chuột / đang chọn
const FRAME_PRESSED := "res://assets/ui/frame_3.png"   # nút khi bấm
const FRAME_PANEL := "res://assets/ui/frame_2.png"     # bảng (bảng qua màn, ô HUD)
const FRAME_MARGIN := 24.0                             # độ dày phần góc/viền không bị co giãn (pixel)


## Tạo bộ giao diện.
static func make() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "Noto Sans"])   # font gọn, hợp kiểu công nghệ
	font.font_weight = 600
	t.default_font = font
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color("#05080c"))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "Button", frame(FRAME_NORMAL, 34, 14))
	t.set_stylebox("hover", "Button", frame(FRAME_HOVER, 34, 14))
	t.set_stylebox("focus", "Button", frame(FRAME_HOVER, 34, 14))
	t.set_stylebox("pressed", "Button", frame(FRAME_PRESSED, 34, 14))
	t.set_stylebox("hover_pressed", "Button", frame(FRAME_PRESSED, 34, 14))
	t.set_stylebox("panel", "PanelContainer", frame(FRAME_PANEL, 48, 30))
	return t


## Khung 9 phần từ một file ảnh. `pad_x`, `pad_y`: khoảng cách từ viền tới chữ bên trong.
static func frame(path: String, pad_x: float, pad_y: float) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(path)
	s.texture_margin_left = FRAME_MARGIN
	s.texture_margin_right = FRAME_MARGIN
	s.texture_margin_top = FRAME_MARGIN
	s.texture_margin_bottom = FRAME_MARGIN
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s
