class_name PixelArt

const PALETTE := {
	"k": Color("#14101c"),
	"w": Color("#f4f1e8"),
	"r": Color("#e8455a"),
	"R": Color("#9c2235"),
	"p": Color("#6b3fa0"),
	"l": Color("#a678e0"),
	"g": Color("#b8c0c8"),
	"G": Color("#5d6670"),
	"c": Color("#7fd6e0"),
	"C": Color("#3c8ea0"),
	"y": Color("#f7d046"),
	"o": Color("#e8892b"),
	"Y": Color("#b8861b"),
	"b": Color("#6e4b1a"),
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


const CROWN := [
	".k...k...k.",
	"kyk.kyk.kyk",
	"kyyyyyyyyyk",
	"kcYyyryyYck",
	"kYyyyyyyyYk",
	"kYYYYYYYYYk",
	"kkkkkkkkkkk",
]

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


static func draw(ci: CanvasItem, pattern: Array, pos: Vector2, px: float, tint := Color.WHITE) -> void:
	for y in pattern.size():
		var row: String = pattern[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), PALETTE.get(ch, Color.MAGENTA) * tint)


static func draw_centered(ci: CanvasItem, pattern: Array, center: Vector2, px: float, tint := Color.WHITE) -> void:
	draw(ci, pattern, center - size_of(pattern, px) / 2.0, px, tint)


static func size_of(pattern: Array, px: float) -> Vector2:
	return Vector2(String(pattern[0]).length(), pattern.size()) * px
