class_name UiTheme                      # tên lớp: nơi khác gọi UiTheme.make()
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

## Font chính: Peaberry (pixel, giấy phép SIL OFL, assets/fonts/). Sắc nét nhất ở cỡ bội số của 16.
const FONT_PATH := "res://assets/fonts/PeaberryBase.ttf"   # đường dẫn file font
const FONT_SMALL := 16      # chữ nhỏ: hướng dẫn, chú thích
const FONT_MEDIUM := 32     # chữ thường: nút, tiêu đề mục, số trên HUD
const FONT_LARGE := 48      # chữ to: điểm số, "GAME OVER"


## Font Peaberry, chỉnh cho pixel sắc nét (không làm mịn viền). Ký tự font không có (vd. ★) lấy từ font hệ thống.
static func main_font() -> FontFile:
	var f: FontFile = load(FONT_PATH)           # nạp file font
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE   # tắt làm mịn viền chữ
	f.hinting = TextServer.HINTING_NONE         # không nắn chữ theo lưới
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED   # đặt chữ đúng ô pixel, không lệch nửa ô
	if f.fallbacks.is_empty():                  # chưa có font dự phòng thì
		var sys := SystemFont.new()             # font có sẵn trong máy
		sys.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI", "Arial"])   # thử lần lượt các font này
		f.fallbacks = [sys]                     # dùng làm font dự phòng
	return f                                    # trả về font đã chỉnh


## Tạo bộ giao diện.
static func make() -> Theme:
	var t := Theme.new()                        # bộ giao diện mới
	t.default_font = main_font()                # font mặc định
	t.default_font_size = FONT_SMALL            # cỡ chữ mặc định: nhỏ
	t.set_font_size("font_size", "Button", FONT_MEDIUM)     # chữ trên nút to hơn chữ thường
	t.set_color("font_color", "Label", TEXT)    # màu chữ của Label
	t.set_color("font_outline_color", "Label", Color("#05080c"))   # màu viền chữ Label (gần đen)
	t.set_constant("outline_size", "Label", 4)   # viền chữ dày 4 pixel
	t.set_color("font_color", "Button", TEXT)   # màu chữ trên nút
	t.set_color("font_hover_color", "Button", ACCENT)   # rê chuột: chữ xanh rêu
	t.set_color("font_focus_color", "Button", ACCENT)   # đang chọn bằng phím: chữ xanh rêu
	t.set_color("font_pressed_color", "Button", Color.WHITE)   # đang bấm: chữ trắng
	t.set_stylebox("normal", "Button", frame(FRAME_NORMAL, 34, 14))   # khung nút bình thường
	t.set_stylebox("hover", "Button", frame(FRAME_HOVER, 34, 14))   # khung khi rê chuột
	t.set_stylebox("focus", "Button", frame(FRAME_HOVER, 34, 14))   # khung khi đang chọn bằng phím
	t.set_stylebox("pressed", "Button", frame(FRAME_PRESSED, 34, 14))   # khung khi bấm
	t.set_stylebox("hover_pressed", "Button", frame(FRAME_PRESSED, 34, 14))   # khung khi bấm lúc đang rê chuột
	t.set_stylebox("panel", "PanelContainer", frame(FRAME_PANEL, 48, 30))   # khung cho bảng (PanelContainer)
	return t                                    # trả về bộ giao diện


## Khung 9 phần từ một file ảnh. `pad_x`, `pad_y`: khoảng cách từ viền tới chữ bên trong.
static func frame(path: String, pad_x: float, pad_y: float) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()              # khung kiểu ảnh 9 phần
	s.texture = load(path)                      # nạp ảnh khung
	s.texture_margin_left = FRAME_MARGIN        # viền trái không co giãn
	s.texture_margin_right = FRAME_MARGIN       # viền phải không co giãn
	s.texture_margin_top = FRAME_MARGIN         # viền trên không co giãn
	s.texture_margin_bottom = FRAME_MARGIN      # viền dưới không co giãn
	s.content_margin_left = pad_x               # khoảng trống từ viền trái tới chữ
	s.content_margin_right = pad_x              # khoảng trống từ viền phải tới chữ
	s.content_margin_top = pad_y                # khoảng trống từ viền trên tới chữ
	s.content_margin_bottom = pad_y             # khoảng trống từ viền dưới tới chữ
	return s                                    # trả về khung
