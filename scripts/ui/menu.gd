extends Control

const BALL_SCENE := preload("res://scenes/ball.tscn")
const LOGO := preload("res://assets/ui/logo.png")
const LOGO_SIZE := Vector2(410, 150)

@onready var title: Label = $Center/Box/Title
@onready var level_grid: GridContainer = $Center/Box/LevelGrid
@onready var help: Label = $Center/Box/Help
@onready var quit_button: Button = $Center/Box/QuitButton

var brawl_button: Button
var bot_button: Button
var chained_button: Button
var brawl_row: HBoxContainer
var _demo_ball: Ball
var _demo_start := Vector2.ZERO
var _howto: PanelContainer
var howto_page := 0
var howto_next: Button
var howto_back: Button
var howto_close: Button
var two_player_hint: Label

const PAGE_TITLES := ["SINGLE PLAYER", "2 PLAYERS"]

const HOW_TO_PLAY := [
	["MOVE & JUMP", [
		"Hold A / D (or LEFT / RIGHT) to tilt and charge, then press SPACE / W / UP to jump.",
		"The longer you charge, the farther you jump. Let go of A / D without jumping to cancel.",
		"Press jump without A / D to jump straight up."]],
	["SHOOT", [
		"Pick up a gun (grey gun icon) to get 15 bullets. Your ammo shows under your hearts.",
		"Press F or J to shoot straight ahead. Hold A / D while shooting to aim up diagonally.",
		"Bullets kill slimes and hurt the boss."]],
	["BOSS", [
		"It only rolls along the ground. Touching its side hurts you.",
		"When a red ! appears it stops and shakes, then charges at you: jump over it!",
		"After it hits a wall it is dizzy. Shoot it, or jump on its head. Every hit = 1 damage."]],
	["ITEMS", [
		"Heart: +1 life.   Shield: blocks one hit.   Green arrow: higher jumps for 10 seconds.",
		"Star: points.   R: back to checkpoint (-1 life).   Esc twice: menu.   M: mute."]],
]


func _ready() -> void:
	theme = UiTheme.make()
	_build_ground()
	$Center.offset_bottom = -110

	title.hide()
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = LOGO_SIZE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.pivot_offset = LOGO_SIZE / 2.0
	var box := title.get_parent()
	box.add_theme_constant_override("separation", 8)
	box.add_child(logo)
	box.move_child(logo, title.get_index())
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

	help.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	help.add_theme_color_override("font_color", UiTheme.DIM)
	var endless := Button.new()
	endless.text = "ENDLESS RUN   best %d" % Game.best_score
	endless.custom_minimum_size = Vector2(380, 60)
	endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	endless.pressed.connect(Game.start_endless)
	level_grid.add_child(endless)
	var star_icon := _star_texture()
	for i in LevelData.LEVELS.size():
		var b := Button.new()
		var stars: int = Game.best_stars.get(i, 0)
		b.text = "%d. %s   %d" % [i + 1, LevelData.LEVELS[i]["name"], stars]
		b.icon = star_icon
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.expand_icon = false
		b.custom_minimum_size = Vector2(380, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Game.start_level.bind(i))
		level_grid.add_child(b)
	var bank := HBoxContainer.new()
	bank.alignment = BoxContainer.ALIGNMENT_CENTER
	var bank_icon := TextureRect.new()
	bank_icon.texture = star_icon
	bank_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	bank.add_child(bank_icon)
	var bank_text := Label.new()
	bank_text.text = "%d / %d stars collected" % [Game.story_stars(), Game.story_star_total()]
	if Game.endless_stars > 0:
		bank_text.text += "   +%d endless" % Game.endless_stars
	bank_text.add_theme_color_override("font_color", Color("#f7d046"))
	bank.add_child(bank_text)
	brawl_row = HBoxContainer.new()
	brawl_row.add_theme_constant_override("separation", 12)
	brawl_button = Button.new()
	brawl_button.text = "BRAWL 2P"
	brawl_button.custom_minimum_size = Vector2(296, 56)
	brawl_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brawl_button.add_theme_color_override("font_color", Color("#ff8e9c"))
	brawl_button.pressed.connect(Game.start_brawl.bind(false))
	brawl_row.add_child(brawl_button)
	bot_button = Button.new()
	bot_button.text = "BRAWL VS BOT"
	bot_button.custom_minimum_size = Vector2(296, 56)
	bot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_button.add_theme_color_override("font_color", Color("#8ec9ff"))
	bot_button.pressed.connect(Game.start_brawl.bind(true))
	brawl_row.add_child(bot_button)
	chained_button = Button.new()
	chained_button.text = "CHAINED 2P"
	chained_button.custom_minimum_size = Vector2(296, 56)
	chained_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chained_button.add_theme_color_override("font_color", Color("#f7d046"))
	chained_button.pressed.connect(Game.start_chained.bind(0))
	brawl_row.add_child(chained_button)
	level_grid.get_parent().add_child(brawl_row)
	level_grid.get_parent().move_child(brawl_row, level_grid.get_index() + 1)
	brawl_button.focus_neighbor_left = brawl_button.get_path()
	brawl_button.focus_neighbor_right = bot_button.get_path()
	bot_button.focus_neighbor_left = brawl_button.get_path()
	bot_button.focus_neighbor_right = chained_button.get_path()
	chained_button.focus_neighbor_left = bot_button.get_path()
	chained_button.focus_neighbor_right = chained_button.get_path()
	two_player_hint = Label.new()
	two_player_hint.text = "Alone? Try BRAWL VS BOT.  Two players share one keyboard."
	two_player_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	two_player_hint.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	two_player_hint.add_theme_color_override("font_color", UiTheme.DIM)
	level_grid.get_parent().add_child(two_player_hint)
	level_grid.get_parent().move_child(two_player_hint, brawl_row.get_index() + 1)
	level_grid.get_parent().add_child(bank)
	level_grid.get_parent().move_child(bank, two_player_hint.get_index() + 1)
	level_grid.columns = 2
	level_grid.custom_minimum_size = Vector2(912, 0)
	level_grid.add_theme_constant_override("h_separation", 12)
	var cell := 0.0
	for b in level_grid.get_children():
		cell = maxf(cell, b.get_combined_minimum_size().x)
	cell = maxf(cell, (level_grid.custom_minimum_size.x - level_grid.get_theme_constant("h_separation")) / 2.0)
	for b in level_grid.get_children():
		b.custom_minimum_size.x = cell
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 12)
	quit_button.get_parent().add_child(bottom_row)
	quit_button.get_parent().move_child(bottom_row, quit_button.get_index())
	var howto_button := Button.new()
	howto_button.text = "HOW TO PLAY"
	howto_button.custom_minimum_size = Vector2(240, 52)
	howto_button.pressed.connect(_show_howto)
	bottom_row.add_child(howto_button)
	quit_button.reparent(bottom_row)
	help.text = "Hold A / D to aim, SPACE to jump, F / J to shoot.  Open HOW TO PLAY for everything else."
	quit_button.custom_minimum_size = Vector2(160, 52)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web")
	for b: Button in $Center.find_children("*", "Button", true, false):
		Hud.guard_panel_button(b)
	_focus_default()


func _focus_default() -> void:
	var first: Control = level_grid.get_child(1) if level_grid.get_child_count() > 1 else level_grid.get_child(0)
	first.grab_focus()


func _star_texture() -> ImageTexture:
	const PX := 3
	var pattern: Array = Hud.STAR
	var img := Image.create(7 * PX, 7 * PX, false, Image.FORMAT_RGBA8)
	for y in pattern.size():
		for x in pattern[y].length():
			if pattern[y][x] == "1":
				img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), Color("#f7d046"))
	return ImageTexture.create_from_image(img)


func _build_ground() -> void:
	var rows := []
	for r in 23:
		rows.append(".".repeat(40))
	rows[18] = ".".repeat(30) + "####" + ".".repeat(6)
	rows[19] = "....O" + ".".repeat(25) + "####" + ".".repeat(6)
	for r in range(20, 23):
		rows[r] = "#".repeat(40)
	var level := Level.new()
	add_child(level)
	move_child(level, 1)
	level.build("\n".join(rows))
	_demo_start = level.start_position
	_demo_ball = BALL_SCENE.instantiate()
	_demo_ball.position = _demo_start
	level.add_child(_demo_ball)


func _two_player_help() -> Array:
	return [
		["KEYS", [
			"P1: A / D + W or SPACE, S = item / anchor.   P2: LEFT / RIGHT + UP, DOWN = item / anchor.",
			"VS BOT: A/D or Left/Right tilt, W/Space/Up jump, S/Down or F/J item.",
			"Hold left / right to tilt and charge, press jump to launch."]],
		["BOUNCE BRAWL", [
			"Stomp their head, or knock them into pits and spikes. First to %d wins." % Brawl.WIN_SCORE,
			"Random events and item boxes keep it wild.",
			"Playing alone? Pick BRAWL VS BOT."]],
		["CHAINED", [
			"You are tied by a rope. Stars on the rope slide to whoever is LOWER.",
			"At the finish each star counts for whoever is closer to it. Most stars wins.",
			"Hold S / DOWN to anchor and slingshot your partner. Stomp your partner to steal a star.",
			"The loser carries the winner on their head next round.",
			"Hold R to restart from the checkpoint (costs a shared life). Press Esc twice to quit."]],
	]


func _show_howto() -> void:
	if _howto:
		return
	$Center.hide()
	_howto = PanelContainer.new()
	_howto.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_howto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_howto.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_howto)
	_show_howto_page(0)


func _show_howto_page(page: int) -> void:
	if _howto == null:
		return
	howto_page = clampi(page, 0, PAGE_TITLES.size() - 1)
	for old in _howto.get_children():
		_howto.remove_child(old)
		old.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_howto.add_child(box)
	var title_label := Label.new()
	title_label.text = "%s   (%d / %d)" % [PAGE_TITLES[howto_page], howto_page + 1, PAGE_TITLES.size()]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	title_label.add_theme_color_override("font_color", UiTheme.CYAN)
	box.add_child(title_label)
	var sections: Array = HOW_TO_PLAY if howto_page == 0 else _two_player_help()
	for section in sections:
		var head := Label.new()
		head.text = section[0]
		head.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
		head.add_theme_color_override("font_color", UiTheme.ACCENT)
		box.add_child(head)
		for line in section[1]:
			var l := Label.new()
			l.text = "  " + line
			l.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
			box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	howto_back = Button.new()
	howto_back.text = "Back"
	howto_back.disabled = howto_page == 0
	howto_back.focus_mode = Control.FOCUS_NONE if howto_back.disabled else Control.FOCUS_ALL
	howto_back.pressed.connect(_show_howto_page.bind(howto_page - 1))
	row.add_child(howto_back)
	howto_close = Button.new()
	howto_close.text = "Close"
	howto_close.pressed.connect(_hide_howto)
	row.add_child(howto_close)
	howto_next = Button.new()
	howto_next.text = "Next"
	howto_next.disabled = howto_page >= PAGE_TITLES.size() - 1
	howto_next.focus_mode = Control.FOCUS_NONE if howto_next.disabled else Control.FOCUS_ALL
	howto_next.pressed.connect(_show_howto_page.bind(howto_page + 1))
	row.add_child(howto_next)
	for b: Button in [howto_back, howto_close, howto_next]:
		Hud.guard_panel_button(b)
	(howto_close if howto_next.disabled else howto_next).grab_focus()


func _hide_howto() -> void:
	if _howto:
		_howto.queue_free()
		_howto = null
		howto_next = null
		howto_back = null
		howto_close = null
		$Center.show()
		_focus_default()


func _unhandled_input(event: InputEvent) -> void:
	if _howto and event.is_action_pressed("back"):
		_hide_howto()


func _physics_process(_delta: float) -> void:
	if _demo_ball and (_demo_ball.global_position.x < -40 or _demo_ball.global_position.x > 1320 or _demo_ball.global_position.y > 800):
		_demo_ball.teleport(_demo_start)
