class_name UiTheme

const TEXT := Color("#d8f3ef")
const ACCENT := Color("#a3e05a")
const CYAN := Color("#8ac6c8")
const DIM := Color("#7d9aa0")

const FRAME_NORMAL := "res://assets/ui/frame_4.png"
const FRAME_HOVER := "res://assets/ui/frame_1.png"
const FRAME_PRESSED := "res://assets/ui/frame_3.png"
const FRAME_PANEL := "res://assets/ui/frame_2.png"
const FRAME_MARGIN := 24.0

const FONT_PATH := "res://assets/fonts/PeaberryBase.ttf"
const FONT_SMALL := 16
const FONT_MEDIUM := 32
const FONT_LARGE := 48


static func main_font() -> FontFile:
	var f: FontFile = load(FONT_PATH)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if f.fallbacks.is_empty():
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI", "Arial"])
		f.fallbacks = [sys]
	return f


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = main_font()
	t.default_font_size = FONT_SMALL
	t.set_font_size("font_size", "Button", FONT_MEDIUM)
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
