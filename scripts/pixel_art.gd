class_name PixelArt
## Hình pixel vẽ bằng code: mỗi hình là một mảng chuỗi, mỗi ký tự là một điểm ảnh, tra màu trong PALETTE.
## "." là trong suốt. Vẽ phóng to bằng tham số `px` (ví dụ px = 4: mỗi điểm thành ô 4 x 4).
## Muốn sửa hình: sửa trực tiếp các chuỗi dưới đây (giữ mọi dòng của một hình dài bằng nhau).
## Khi có ảnh PNG thật thì thay bằng Sprite2D trong scene tương ứng và tắt show_placeholder.

const PALETTE := {
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
}

const HEART := [
	".rr.rr.",
	"rwrrrrr",
	"rrrrrrR",
	"rrrrrrR",
	".rrrrR.",
	"..rrR..",
	"...R...",
]

const SHIELD := [
	".kkkkk.",
	"kcwccCk",
	"kcccCCk",
	"kcccCCk",
	".kccCk.",
	"..kCk..",
	"...k...",
]

const GUN := [
	"kkkkkkkkk",
	"kgggggggk",
	"kGGkkkkkk",
	"kGk......",
	"kkk......",
]

const BULLET := [
	"oyyw",
	"oyyw",
]

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


## Vẽ hình `pattern` lên `ci` tại góc trên trái `pos`, mỗi điểm to `px`. `tint` nhân thêm màu (đỏ lên khi bị đánh...).
static func draw(ci: CanvasItem, pattern: Array, pos: Vector2, px: float, tint := Color.WHITE) -> void:
	for y in pattern.size():
		var row: String = pattern[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), PALETTE.get(ch, Color.MAGENTA) * tint)


## Vẽ hình với tâm ở `center`.
static func draw_centered(ci: CanvasItem, pattern: Array, center: Vector2, px: float, tint := Color.WHITE) -> void:
	draw(ci, pattern, center - size_of(pattern, px) / 2.0, px, tint)


## Kích thước hình (pixel màn hình) khi vẽ với `px`.
static func size_of(pattern: Array, px: float) -> Vector2:
	return Vector2(String(pattern[0]).length(), pattern.size()) * px
