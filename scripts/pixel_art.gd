class_name PixelArt                     # tên lớp: nơi khác gọi PixelArt.draw(...)
## Hình pixel vẽ bằng code: mỗi hình là một mảng chuỗi, mỗi ký tự là một điểm ảnh, tra màu trong PALETTE.
## "." là trong suốt. Vẽ phóng to bằng tham số `px` (ví dụ px = 4: mỗi điểm thành ô 4 x 4).
## Muốn sửa hình: sửa trực tiếp các chuỗi dưới đây (giữ mọi dòng của một hình dài bằng nhau).
## Khi có ảnh PNG thật thì thay bằng Sprite2D trong scene tương ứng và tắt show_placeholder.

const PALETTE := {                      # bảng màu: ký tự -> màu
	"k": Color("#14101c"),   # viền tối
	"w": Color("#f4f1e8"),   # trắng
	"r": Color("#e8455a"),   # đỏ
	"R": Color("#9c2235"),   # đỏ tối
	"p": Color("#6b3fa0"),   # tím
	"l": Color("#a678e0"),   # tím sáng
	"g": Color("#b8c0c8"),   # xám sáng
	"G": Color("#5d6670"),   # xám tối
	"c": Color("#7fd6e0"),   # xanh ngọc
	"C": Color("#3c8ea0"),   # xanh ngọc tối
	"y": Color("#f7d046"),   # vàng
	"o": Color("#e8892b"),   # cam
	"Y": Color("#b8861b"),   # vàng sẫm (mép vàng, bóng của vương miện)
	"b": Color("#6e4b1a"),   # nâu (cuống chuối, ngòi cháy)
}

# Trái tim 7 x 7.
const HEART := [
	".rr.rr.",
	"rwrrrrr",
	"rrrrrrR",
	"rrrrrrR",
	".rrrrR.",
	"..rrR..",
	"...R...",
]

# Khiên 7 x 7.
const SHIELD := [
	".kkkkk.",
	"kcwccCk",
	"kcccCCk",
	"kcccCCk",
	".kccCk.",
	"..kCk..",
	"...k...",
]

# Khẩu súng 9 x 5 (hiện ở ô đạn trên HUD).
const GUN := [
	"kkkkkkkkk",
	"kgggggggk",
	"kGGkkkkkk",
	"kGk......",
	"kkk......",
]

# Viên đạn 4 x 2.
const BULLET := [
	"oyyw",
	"oyyw",
]

# Dấu chấm than đỏ 3 x 7 (báo boss sắp lao tới).
const EXCLAIM := [
	".r.",
	"rrr",
	"rrr",
	".r.",
	".r.",
	"...",
	".r.",
]

## Boss: quả cầu quái vật tròn (lăn được), 16 x 16 điểm.
const BOSS := [
	".....kkkkkk.....",
	"...kkppppppkk...",
	"..kppppllppppk..",
	".kppllppppllppk.",
	".kpwwwppppwwwpk.",
	"kppwrrwppwrrwppk",
	"kppwwwwppwwwwppk",
	"kppppppppppppppk",
	"kppkkkkkkkkkkppk",
	"kppkwkwkwkwkwppk",
	"kpppkkkkkkkkpppk",
	"kppppppppppppppk",
	".kppllppppllppk.",
	".kppppppppppppk.",
	"...kkppppppkk...",
	".....kkkkkk.....",
]


# Vương miện vàng 11 x 7 (3 nhọn, đá đỏ ở giữa, đá xanh hai bên).
const CROWN := [
	".k...k...k.",
	"kyk.kyk.kyk",
	"kyyyyyyyyyk",
	"kcYyyryyYck",
	"kYyyyyyyyYk",
	"kYYYYYYYYYk",
	"kkkkkkkkkkk",
]

# Vỏ chuối 10 x 9 (vỏ vàng cong, cuống nâu, mép tối).
const BANANA := [
	".....kbk..",
	"...kyyyyk.",
	"..kyyYk...",
	".kyyYk....",
	".kyyyYk...",
	".kyyYk....",
	"..kyyYk...",
	"...kyyYk..",
	".....kbk..",
]

# Bom đen 10 x 11 (thân tròn, ngòi cháy nâu, tia lửa vàng và trắng).
const BOMB := [
	"........y.",
	".......ywy",
	"......bby.",
	"...kkkk...",
	"..kgGGGk..",
	".kgGGGGk..",
	".kgGGGGGk.",
	".kGGGGGGk.",
	".kGGGGGGk.",
	"..kGGGGk..",
	"...kkkk...",
]

# Hai mũi tên ngược chiều 11 x 9 (trên chỉ phải, dưới chỉ trái; biểu tượng đổi chỗ).
const SWAP := [
	".......kk..",
	"kkkkkkkkck.",
	"kccccccccck",
	"kkkkkkkkck.",
	".......kk..",
	"...........",
	"..kk.......",
	".kckkkkkkkk",
	"kccccccccck",
	".kckkkkkkkk",
	"..kk.......",
]

# Bẫy lò xo nhún 10 x 8 (bệ đỏ trên, lò xo zigzag bạc ở giữa, đế xám tối dưới).
const SPRING := [
	".kkkkkkkk.",
	"krrrrrrrrk",
	"...gg.....",
	"....gg....",
	"...gg.....",
	"....gg....",
	"...gg.....",
	"kGGGGGGGGk",
]

# Hộp vật phẩm bí ẩn 11 x 11 (khối vàng viền tối, dấu "?" tối ở giữa).
const ITEM_BOX := [
	"kkkkkkkkkkk",
	"kwyyyyyyyYk",
	"kyyykkkyyYk",
	"kyykyyykyYk",
	"kyyyyyykyYk",
	"kyyyykkyyYk",
	"kyyyykyyyYk",
	"kyyyyyyyyYk",
	"kyyyykyyyYk",
	"kYYYYYYYYYk",
	"kkkkkkkkkkk",
]

# Neo tàu 9 x 11 (vòng trên, thân dọc, xà ngang, đáy cong lên hai mỏ nhọn).
const ANCHOR := [
	"...kkk...",
	"..kg.gk..",
	"..kkgkk..",
	".kkkgkkk.",
	".kgggggk.",
	".kkkgkkk.",
	"...kgk...",
	"kk.kgk.kk",
	"kgkkgkkgk",
	"kgggggggk",
	".kkkkkkk.",
]


## Vẽ hình `pattern` lên `ci` tại góc trên trái `pos`, mỗi điểm to `px`. `tint` nhân thêm màu (đỏ lên khi bị đánh...).
static func draw(ci: CanvasItem, pattern: Array, pos: Vector2, px: float, tint := Color.WHITE) -> void:
	for y in pattern.size():                    # duyệt từng hàng
		var row: String = pattern[y]            # chuỗi của hàng y
		for x in row.length():                  # duyệt từng ký tự trong hàng
			var ch := row[x]                    # ký tự = màu của điểm này
			if ch == ".":                       # dấu chấm = trong suốt
				continue                        # bỏ qua, không vẽ
			# tô ô vuông; ký tự lạ thì tô hồng tím (MAGENTA) để dễ thấy lỗi
			ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), PALETTE.get(ch, Color.MAGENTA) * tint)


## Vẽ hình với tâm ở `center`.
static func draw_centered(ci: CanvasItem, pattern: Array, center: Vector2, px: float, tint := Color.WHITE) -> void:
	draw(ci, pattern, center - size_of(pattern, px) / 2.0, px, tint)   # lùi nửa kích thước để tâm hình nằm ở center


## Kích thước hình (pixel màn hình) khi vẽ với `px`.
static func size_of(pattern: Array, px: float) -> Vector2:
	return Vector2(String(pattern[0]).length(), pattern.size()) * px   # rộng = số ký tự một hàng, cao = số hàng
