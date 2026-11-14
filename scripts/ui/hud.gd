class_name Hud
extends Control

signal next_pressed
signal retry_pressed
signal menu_pressed

var _lives := 3
var _max_lives := 3
var _stars := 0
var _star_total := 0
var _title: Label
var _message: Label
var _panel: PanelContainer
var _frame: StyleBoxTexture
var _endless := false
var _score_label: Label
var _mult_label: Label
var _ammo := 0
var _shield := false
var _boss: Node = null
var _boss_hp := 0
var _boss_max := 0
var _boost := 0.0
var _boost_full := 10.0

const HEART_TEX := preload("res://assets/items/heart.png")
const SHIELD_TEX := preload("res://assets/items/shield.png")
const BOOST_TEX := preload("res://assets/items/jump_boost.png")

const HEART := ["0110110", "1111111", "1111111", "1111111", "0111110", "0011100", "0001000"]
const STAR := ["0001000", "0011100", "1111111", "0111110", "0011100", "0110110", "0100010"]
const ICON_PX := 4.0


func setup(level_name: String, lives: int, star_total: int) -> void:
	theme = UiTheme.make()
	_max_lives = lives
	_lives = lives
	_star_total = star_total
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 12
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var spin_l := SpinnerIcon.new()
	spin_l.pixel_scale = 2.0
	top.add_child(spin_l)
	_title = Label.new()
	_title.text = level_name.to_upper()
	_title.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	_title.add_theme_color_override("font_color", UiTheme.CYAN)
	top.add_child(_title)
	var spin_r := SpinnerIcon.new()
	spin_r.pixel_scale = 2.0
	top.add_child(spin_r)

	_message = Label.new()
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 8)
	add_child(_message)

	var hint := Label.new()
	hint.text = "R: back to checkpoint (-1 life)   Esc: menu"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position -= Vector2(420, 38)
	hint.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	hint.add_theme_color_override("font_color", UiTheme.DIM)
	add_child(hint)
	queue_redraw()


func setup_endless(lives: int) -> void:
	setup("Endless Run", lives, 0)
	_endless = true
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 44
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -6)
	add_child(box)
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	_score_label.add_theme_color_override("font_color", UiTheme.TEXT)
	box.add_child(_score_label)
	_mult_label = Label.new()
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mult_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	_mult_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(_mult_label)


func set_score(score: int, mult: int) -> void:
	_score_label.text = "%07d" % score
	_mult_label.text = "x%d" % mult


func flash(text: String, seconds := 0.9) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", UiTheme.ACCENT)
	_message.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_message, "modulate:a", 0.0, 0.5)


func show_game_over(score: int, best: int, new_best: bool, stars: int, total_stars: int) -> void:
	_message.text = ""
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var lines := [
		["GAME OVER", UiTheme.FONT_LARGE, UiTheme.ACCENT],
		["Score  %d" % score, UiTheme.FONT_MEDIUM, UiTheme.TEXT],
		["NEW BEST!" if new_best else "Best  %d" % best, UiTheme.FONT_MEDIUM, Color("#f7d046") if new_best else UiTheme.DIM],
		["Stars  +%d   (total %d)" % [stars, total_stars], UiTheme.FONT_SMALL, UiTheme.TEXT],
	]
	for l in lines:
		var lab := Label.new()
		lab.text = l[0]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", l[1])
		lab.add_theme_color_override("font_color", l[2])
		box.add_child(lab)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for item in [["Menu", menu_pressed], ["Play again", retry_pressed]]:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1].emit)
		row.add_child(b)
	row.get_child(1).grab_focus()


func watch_ball(ball: Ball) -> void:
	ball.ammo_changed.connect(func(n: int) -> void:
		if _ammo == 0 and n > 0:
			flash("GOT A GUN!
Press F or J to shoot", 1.8)
		_ammo = n
		queue_redraw())
	ball.shield_changed.connect(func(on: bool) -> void:
		_shield = on
		queue_redraw())
	_boost_full = ball.boost_duration
	ball.boost_changed.connect(func(t: float) -> void:
		if _boost == 0.0 and t > 0.0:
			flash("JUMP BOOST!\nJumps are higher for %d seconds" % int(ball.boost_duration), 1.4)
		_boost = t
		queue_redraw())


func watch_level(level: Level) -> void:
	level.boss_started.connect(_on_boss_started)
	level.boss_defeated.connect(_on_boss_defeated)


func _on_boss_started(boss: Node) -> void:
	_boss = boss
	_boss_max = boss.max_hp
	_boss_hp = boss.hp
	boss.hp_changed.connect(func(hp: int, max_hp: int) -> void:
		_boss_hp = hp
		_boss_max = max_hp
		queue_redraw())
	flash("%s APPEARS!
Shoot it (F / J) or jump on its head.
When it shows a red ! - jump over its charge!" % boss.boss_name, 2.6)
	queue_redraw()


func _on_boss_defeated(_boss_node: Node) -> void:
	_boss = null
	_boss_max = 0
	flash("BOSS DEFEATED!")
	queue_redraw()


func set_lives(n: int) -> void:
	_lives = n
	queue_redraw()


func set_stars(n: int) -> void:
	_stars = n
	queue_redraw()


func show_message(text: String) -> void:
	_message.text = text


func show_complete(stars: int, total: int, has_next: bool) -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Level complete!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title)
	var star_label := Label.new()
	star_label.text = "Stars: %d / %d" % [stars, total]
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	box.add_child(star_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var buttons := [["Menu", menu_pressed], ["Retry", retry_pressed]]
	if has_next:
		buttons.append(["Next level", next_pressed])
	for item in buttons:
		var b := Button.new()
		b.text = item[0]
		b.pressed.connect(item[1].emit)
		row.add_child(b)
	row.get_child(row.get_child_count() - 1).grab_focus()


func _draw() -> void:
	if _frame == null:
		return
	var left_box := Rect2(16, 12, 40 + _max_lives * 38 + (38 if _shield else 0), 58)
	draw_style_box(_frame, left_box)
	for i in _max_lives:
		var col := Color.WHITE if i < _lives else Color(1, 1, 1, 0.2)
		draw_texture_rect(HEART_TEX, Rect2(Vector2(34 + i * 38, 25), Vector2(32, 32)), false, col)
	if _shield:
		draw_texture_rect(SHIELD_TEX, Rect2(Vector2(34 + _max_lives * 38, 25), Vector2(32, 32)), false)
	if _boost > 0.0:
		var by := 74.0 + (78.0 if _ammo > 0 else 0.0)
		var boost_box := Rect2(16, by, 150, 52)
		draw_style_box(_frame, boost_box)
		draw_texture_rect(BOOST_TEX, Rect2(boost_box.position + Vector2(14, 10), Vector2(32, 32)), false)
		var bar := Rect2(boost_box.position + Vector2(56, 22), Vector2(78, 10))
		draw_rect(bar, Color("#123018"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_boost / _boost_full, 0.0, 1.0), bar.size.y)), Color("#22b14c"))
	if _ammo > 0:
		var ammo_box := Rect2(16, 74, 150, 52)
		draw_style_box(_frame, ammo_box)
		PixelArt.draw(self, PixelArt.GUN, ammo_box.position + Vector2(20, 16), 3.0)
		draw_string(get_theme_default_font(), ammo_box.position + Vector2(64, 35), "x %d" % _ammo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, UiTheme.TEXT)
		draw_string(get_theme_default_font(), ammo_box.position + Vector2(14, 74), "Shoot: F / J   (hold A / D to aim up)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.DIM)
	if _boss_max > 0:
		_draw_boss_bar()

	var right_box := Rect2(size.x - 196, 12, 180, 58)
	draw_style_box(_frame, right_box)
	_pixel_icon(STAR, right_box.position + Vector2(22, 15), Color("#f7d046"))
	var star_text := str(_stars) if _endless else "%d / %d" % [_stars, _star_total]
	draw_string(get_theme_default_font(), right_box.position + Vector2(66, 40), star_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, UiTheme.TEXT)


func _pixel_icon(pattern: Array, pos: Vector2, col: Color) -> void:
	for y in pattern.size():
		var row: String = pattern[y]
		for x in row.length():
			if row[x] == "1":
				var c := col.lightened(0.35) if y == 1 and col.a > 0.5 else col
				draw_rect(Rect2(pos + Vector2(x, y) * ICON_PX, Vector2.ONE * ICON_PX), c)


func _draw_boss_bar() -> void:
	var w := 520.0
	var y := 128.0 if _endless else 64.0
	var bar := Rect2((size.x - w) / 2.0, y, w, 46)
	draw_style_box(_frame, bar)
	var font := get_theme_default_font()
	var title := "%s   %d / %d" % [_boss.boss_name if _boss else "BOSS", _boss_hp, _boss_max]
	draw_string(font, Vector2(bar.position.x, y - 6), title, HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.FONT_SMALL, Color("#f2a0aa"))
	var inner := bar.grow(-14)
	var seg_w := inner.size.x / float(_boss_max)
	draw_string(font, Vector2(bar.position.x, y + 66), "Shoot: F / J    Stomp its head    Jump over it when it charges",
		HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.FONT_SMALL, UiTheme.DIM)
	var phase2 := _boss_hp <= _boss_max / 2
	for i in _boss_max:
		var r := Rect2(inner.position.x + i * seg_w, inner.position.y, seg_w - 2.0, inner.size.y)
		var col := Color("#3a1620")
		if i < _boss_hp:
			col = Color("#ff5d6d") if phase2 else Color("#e8455a")
		draw_rect(r, col)
		if i < _boss_hp:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("#ffb3bb"))
