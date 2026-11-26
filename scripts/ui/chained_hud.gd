class_name ChainedHud
extends Control

signal next_pressed
signal retry_pressed
signal menu_pressed

const PLAYER_COLORS := [Color("#e8455a"), Color("#4da3ff")]
const BOX_SIZE := Vector2(214, 64)
const MARGIN := 16.0
const STAR_PX := 4.0
const HEART_TEX := preload("res://assets/items/heart.png")
const HEART_SIZE := 28.0
const HEART_GAP := 4.0
const PANEL_KEY_DELAY := 0.6
const RESTART_BAR := Vector2(240, 14)
const RESTART_BAR_BOTTOM := 118.0

var level_name := ""
var max_lives := 5
var lives := 5
var counts := Vector2i.ZERO
var message_label: Label
var result_panel: PanelContainer
var result_title: Label
var result_p1: Label
var result_p2: Label
var result_totals: Label
var result_piggyback: Label
var result_overall: Label
var quit_label: Label
var next_button: Button
var retry_button: Button
var menu_button: Button
var panel_keys_ready := false
var restart_hold := 0.0
var _frame: StyleBoxTexture
var _flash_tween: Tween
var _piggyback_banner := false
var _quit_tween: Tween


func setup(title: String, lives_max: int) -> void:
	theme = UiTheme.make()
	level_name = title.to_upper()
	max_lives = lives_max
	lives = lives_max
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.position.y = 132
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 10)
	message_label.modulate.a = 0.0
	add_child(message_label)

	_add_hint("P1: A / D + W / SPACE, S: anchor", Control.PRESET_BOTTOM_LEFT, PLAYER_COLORS[0].lightened(0.35))
	_add_hint("P2: LEFT / RIGHT + UP, DOWN: anchor", Control.PRESET_BOTTOM_RIGHT, PLAYER_COLORS[1].lightened(0.35))
	_add_hint("Hold R: back to checkpoint (-1 life)    Esc twice: menu", Control.PRESET_CENTER_BOTTOM, UiTheme.DIM)

	quit_label = Label.new()
	quit_label.text = "PRESS ESC AGAIN TO QUIT"
	quit_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	quit_label.add_theme_color_override("font_color", Color("#ffb020"))
	quit_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quit_label.add_theme_constant_override("outline_size", 8)
	quit_label.visible = false
	add_child(quit_label)
	quit_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 56)
	queue_redraw()


func _add_hint(text: String, preset: int, color: Color) -> void:
	var hint := Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	hint.add_theme_color_override("font_color", color)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)


func set_lives(n: int) -> void:
	lives = n
	queue_redraw()


func set_counts(p1: int, p2: int) -> void:
	if counts == Vector2i(p1, p2):
		return
	counts = Vector2i(p1, p2)
	queue_redraw()


func flash(text: String, seconds := 0.9, color := UiTheme.ACCENT) -> void:
	if message_label == null:
		return
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.modulate.a = 1.0
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(seconds)
	_flash_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


func show_quit_prompt(seconds := 2.0) -> void:
	if quit_label == null:
		return
	quit_label.visible = true
	if _quit_tween:
		_quit_tween.kill()
	_quit_tween = create_tween()
	_quit_tween.tween_interval(seconds)
	_quit_tween.tween_callback(hide_quit_prompt)


func hide_quit_prompt() -> void:
	if _quit_tween:
		_quit_tween.kill()
	if quit_label != null:
		quit_label.visible = false


func set_restart_hold(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	if is_equal_approx(f, restart_hold):
		return
	restart_hold = f
	queue_redraw()


func message_active() -> bool:
	return message_label != null and message_label.modulate.a > 0.01


func clear_message() -> void:
	if _flash_tween:
		_flash_tween.kill()
	if message_label != null:
		message_label.modulate.a = 0.0


static func winner_of(result: Vector2i) -> int:
	if result.x == result.y:
		return 0
	return 1 if result.x > result.y else 2


func show_result(result: Vector2i, totals: Array, has_next: bool) -> void:
	if result_panel != null:
		return
	if _flash_tween:
		_flash_tween.kill()
	message_label.modulate.a = 0.0
	result_panel = PanelContainer.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	result_panel.add_child(box)
	var win := winner_of(result)
	result_title = Label.new()
	result_title.text = "IT'S A TIE!" if win == 0 else "PLAYER %d WINS THE LEVEL!" % win
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	result_title.add_theme_color_override("font_color", UiTheme.ACCENT if win == 0 else PLAYER_COLORS[win - 1])
	box.add_child(result_title)
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 24)
	box.add_child(stars_row)
	result_p1 = _result_label("P1  %d" % result.x, PLAYER_COLORS[0], UiTheme.FONT_LARGE)
	stars_row.add_child(result_p1)
	stars_row.add_child(_result_label("STARS", UiTheme.DIM, UiTheme.FONT_MEDIUM))
	result_p2 = _result_label("%d  P2" % result.y, PLAYER_COLORS[1], UiTheme.FONT_LARGE)
	stars_row.add_child(result_p2)
	result_totals = _result_label("TOTAL   P1 %d  -  %d P2" % [totals[0], totals[1]], UiTheme.TEXT, UiTheme.FONT_MEDIUM)
	box.add_child(result_totals)
	if not has_next:
		var overall := winner_of(Vector2i(totals[0], totals[1]))
		result_overall = _result_label("THE RUN IS A TIE!" if overall == 0 else "PLAYER %d WINS THE RUN!" % overall, UiTheme.ACCENT if overall == 0 else PLAYER_COLORS[overall - 1], UiTheme.FONT_LARGE)
		box.add_child(result_overall)
	if win != 0 and has_next:
		result_piggyback = _result_label("P%d MUST CARRY P%d NEXT ROUND!" % [3 - win, win], PLAYER_COLORS[2 - win], UiTheme.FONT_MEDIUM)
		box.add_child(result_piggyback)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	if has_next:
		next_button = Button.new()
		next_button.text = "Next level"
		next_button.pressed.connect(next_pressed.emit)
		row.add_child(next_button)
	retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.pressed.connect(retry_pressed.emit)
	row.add_child(retry_button)
	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.pressed.connect(menu_pressed.emit)
	row.add_child(menu_button)
	var buttons: Array = [retry_button, menu_button]
	if next_button != null:
		buttons.push_front(next_button)
	for b: Button in buttons:
		Hud.guard_panel_button(b)
	_arm_panel_keys(buttons, next_button if next_button != null else retry_button)


func _arm_panel_keys(buttons: Array, first: Button) -> void:
	panel_keys_ready = false
	for b: Button in buttons:
		b.focus_mode = Control.FOCUS_NONE
	var wait := create_tween()
	wait.tween_interval(PANEL_KEY_DELAY)
	wait.tween_callback(func() -> void:
		if not is_instance_valid(first):
			return
		for b: Button in buttons:
			b.focus_mode = Control.FOCUS_ALL
		panel_keys_ready = true
		first.grab_focus())


func _result_label(text: String, color: Color, font_size: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", color)
	return lab


func _draw() -> void:
	if _frame == null:
		return
	var font := get_theme_default_font()
	for i in 2:
		var x := MARGIN if i == 0 else size.x - MARGIN - BOX_SIZE.x
		var box := Rect2(Vector2(x, 12), BOX_SIZE)
		draw_style_box(_frame, box)
		var col: Color = PLAYER_COLORS[i]
		draw_string(font, box.position + Vector2(22, 44), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, col)
		_draw_star(box.position + Vector2(86, 17))
		var number := str(counts.x if i == 0 else counts.y)
		draw_string(font, box.position + Vector2(126, 50), number, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE, col.lightened(0.2))
	var mid := size.x / 2.0
	draw_string(font, Vector2(mid - 200, 34), level_name, HORIZONTAL_ALIGNMENT_CENTER, 400, UiTheme.FONT_MEDIUM, UiTheme.CYAN)
	var total_w := max_lives * HEART_SIZE + (max_lives - 1) * HEART_GAP
	for i in max_lives:
		var tint := Color.WHITE if i < lives else Color(1, 1, 1, 0.2)
		var pos := Vector2(mid - total_w / 2.0 + i * (HEART_SIZE + HEART_GAP), 46)
		draw_texture_rect(HEART_TEX, Rect2(pos, Vector2(HEART_SIZE, HEART_SIZE)), false, tint)
	if event_state != "":
		_draw_event_banner(font, mid)
	if restart_hold > 0.0:
		var bar := Rect2(Vector2(mid - RESTART_BAR.x / 2.0, size.y - RESTART_BAR_BOTTOM - RESTART_BAR.y), RESTART_BAR)
		draw_string(font, Vector2(mid - 200.0, bar.position.y - 8), "HOLD R: BACK TO CHECKPOINT", HORIZONTAL_ALIGNMENT_CENTER, 400.0, UiTheme.FONT_SMALL, Color("#ff9a5d"))
		draw_rect(bar.grow(2), Color("#05080c"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * restart_hold, bar.size.y)), Color("#ff9a5d"))


func _draw_star(pos: Vector2) -> void:
	var pattern: Array = Hud.STAR
	for y in pattern.size():
		var row: String = pattern[y]
		for x in row.length():
			if row[x] == "1":
				var c := Color("#ffe27a") if y == 1 else Color("#f7d046")
				draw_rect(Rect2(pos + Vector2(x, y) * STAR_PX, Vector2.ONE * STAR_PX), c)


const EVENT_Y := 190.0
const EVENT_SIZE_ROLL := Vector2(520, 112)
const EVENT_SIZE_ACTIVE := Vector2(460, 62)
const EVENT_ACTIVE_Y := 84.0
const MESSAGE_Y := 132.0
const MESSAGE_Y_EVENT := 156.0
const MESSAGE_Y_PIGGYBACK := 180.0
const ROULETTE_TICKS := 18

var event_state := ""
var event_text := ""
var event_fraction := 0.0
var _event_color := Color.WHITE
var _event_time := 0.0
var _event_seconds := 1.0
var _roulette_ticks: Array = []
var _roulette_total := 0.0


func show_event_roulette(names: Array, chosen: String, seconds := 2.0, color := UiTheme.ACCENT) -> void:
	if names.is_empty():
		return
	_roulette_ticks.clear()
	var chosen_index := maxi(0, names.find(chosen))
	for i in ROULETTE_TICKS:
		var t := seconds * 0.72 * pow(float(i) / (ROULETTE_TICKS - 1), 1.8)
		var shown: String = names[posmod(chosen_index - (ROULETTE_TICKS - 1 - i), names.size())]
		_roulette_ticks.append([t, shown])
	_roulette_total = _roulette_ticks[-1][0]
	_event_seconds = maxf(seconds, 0.1)
	_event_time = 0.0
	_event_color = color
	event_state = "roulette"
	event_text = _roulette_ticks[0][1]
	_apply_message_y()
	set_process(true)
	queue_redraw()


func show_event(event_name: String, seconds: float, color := UiTheme.ACCENT) -> void:
	event_state = "active"
	event_text = event_name
	_event_color = color
	_event_seconds = maxf(seconds, 0.01)
	_event_time = 0.0
	event_fraction = 1.0
	_apply_message_y()
	set_process(true)
	queue_redraw()


func update_event(event_name: String, color := UiTheme.ACCENT) -> void:
	if event_state != "active":
		return
	event_text = event_name
	_event_color = color
	queue_redraw()


func hide_event() -> void:
	event_state = ""
	event_text = ""
	event_fraction = 0.0
	_roulette_ticks.clear()
	_apply_message_y()
	set_process(false)
	queue_redraw()


func set_piggyback_banner(on: bool) -> void:
	_piggyback_banner = on
	_apply_message_y()


func _apply_message_y() -> void:
	if message_label == null:
		return
	var y := MESSAGE_Y
	if event_state == "active":
		y = maxf(y, MESSAGE_Y_EVENT)
	if _piggyback_banner:
		y = maxf(y, MESSAGE_Y_PIGGYBACK)
	message_label.position.y = y


func _process(delta: float) -> void:
	if event_state == "":
		set_process(false)
		return
	_event_time += delta
	if event_state == "roulette":
		for tick in _roulette_ticks:
			if tick[0] <= _event_time:
				event_text = tick[1]
	else:
		event_fraction = clampf(1.0 - _event_time / _event_seconds, 0.0, 1.0)
	queue_redraw()


func _draw_event_banner(font: Font, mid: float) -> void:
	if event_state == "roulette":
		var box := Rect2(Vector2(mid - EVENT_SIZE_ROLL.x / 2.0, EVENT_Y), EVENT_SIZE_ROLL)
		draw_style_box(_frame, box)
		draw_string(font, Vector2(box.position.x, box.position.y + 40), "RANDOM EVENT", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_SMALL, UiTheme.DIM)
		var landed := _event_time >= _roulette_total
		var col := UiTheme.TEXT
		if landed:
			col = _event_color if int(_event_time * 8.0) % 2 == 0 else Color.WHITE
		draw_string_outline(font, Vector2(box.position.x, box.position.y + 90), event_text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_LARGE, 8, Color.BLACK)
		draw_string(font, Vector2(box.position.x, box.position.y + 90), event_text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_LARGE, col)
		var arrow := UiTheme.ACCENT if landed else UiTheme.DIM
		var cy := box.position.y + box.size.y / 2.0 + 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(box.position.x + 40, cy - 12), Vector2(box.position.x + 40, cy + 12), Vector2(box.position.x + 58, cy)]), arrow)
		draw_colored_polygon(PackedVector2Array([Vector2(box.end.x - 40, cy - 12), Vector2(box.end.x - 40, cy + 12), Vector2(box.end.x - 58, cy)]), arrow)
		return
	var panel := Rect2(Vector2(mid - EVENT_SIZE_ACTIVE.x / 2.0, EVENT_ACTIVE_Y), EVENT_SIZE_ACTIVE)
	draw_style_box(_frame, panel)
	draw_string_outline(font, Vector2(panel.position.x, panel.position.y + 36), event_text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, UiTheme.FONT_MEDIUM, 6, Color.BLACK)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 36), event_text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, UiTheme.FONT_MEDIUM, _event_color)
	var bar := Rect2(Vector2(panel.position.x + 60, panel.position.y + 44), Vector2(panel.size.x - 120, 8))
	draw_rect(bar.grow(2), Color("#05080c"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * event_fraction, bar.size.y)), _event_color if event_fraction > 0.25 or int(_event_time * 6.0) % 2 == 0 else Color.WHITE)
