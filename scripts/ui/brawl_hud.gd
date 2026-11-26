class_name BrawlHud
extends Control

signal rematch_pressed
signal menu_pressed

const PLAYER_COLORS := [Color("#e8455a"), Color("#4da3ff")]
const BOX_SIZE := Vector2(236, 76)
const MARGIN := 16.0
const CROWN_PX := 3.0
const EVENT_SIZE_ROLL := Vector2(560, 76)
const EVENT_SIZE_ACTIVE := Vector2(560, 68)
const EVENT_ACTIVE_Y := 12.0
const ROULETTE_TICKS := 18
const SLOT_SIZE := Vector2(88, 76)
const SLOT_GAP := 6.0
const FADE_ALPHA := 0.3
const FADE_SPEED := 8.0
const QUIT_PROMPT_COLOR := Color("#ffd23a")
const PANEL_KEY_DELAY := 0.6
const PANEL_JUMP_ACTIONS := ["jump", "p1_jump", "p2_jump", "solo_jump"]

var win_score := 5
var vs_bot := false
var win_panel: PanelContainer
var rematch_button: Button
var menu_button: Button
var panel_keys_ready := false
var message_label: Label
var item_ids := ["", ""]
var _item_ammo := [0, 0]
var cover_rects: Array[Rect2] = []
var quit_prompt_label: Label
var quit_prompt_panel: PanelContainer
var _panel_alpha := {}
var _quit_tween: Tween
var _scores := [0, 0]
var _frame: StyleBoxTexture
var _flash_tween: Tween
var event_state := ""
var event_text := ""
var event_fraction := 0.0
var _event_color := Color.WHITE
var _event_time := 0.0
var _event_seconds := 1.0
var _roulette_ticks: Array = []
var _roulette_total := 0.0
var _roulette_sfx := 0


func setup(target_score: int, with_bot := false) -> void:
	theme = UiTheme.make()
	win_score = target_score
	vs_bot = with_bot
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)
	set_process(true)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.position.y = 118
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 10)
	message_label.modulate.a = 0.0
	add_child(message_label)

	quit_prompt_panel = PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.02, 0.03, 0.05, 0.88)
	backing.border_color = QUIT_PROMPT_COLOR.darkened(0.3)
	backing.set_border_width_all(2)
	backing.set_content_margin_all(8)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	quit_prompt_panel.add_theme_stylebox_override("panel", backing)
	quit_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quit_prompt_label = Label.new()
	quit_prompt_label.text = "PRESS ESC AGAIN TO QUIT"
	quit_prompt_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	quit_prompt_label.add_theme_color_override("font_color", QUIT_PROMPT_COLOR)
	quit_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quit_prompt_label.add_theme_constant_override("outline_size", 8)
	quit_prompt_panel.add_child(quit_prompt_label)
	add_child(quit_prompt_panel)
	quit_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	quit_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	quit_prompt_panel.position.y = EVENT_ACTIVE_Y + (EVENT_SIZE_ROLL.y - quit_prompt_panel.get_combined_minimum_size().y) / 2.0
	quit_prompt_label.visible = false
	quit_prompt_panel.visible = false

	if vs_bot:
		_add_hint("YOU: A / D or ARROWS to aim, W / SPACE / UP to jump, S / DOWN / F / J: use item", Control.PRESET_BOTTOM_LEFT, PLAYER_COLORS[0].lightened(0.35))
		_add_hint("Esc twice: menu", Control.PRESET_BOTTOM_RIGHT, UiTheme.DIM)
	else:
		_add_hint("P1:  A / D + W / SPACE     S: use item", Control.PRESET_BOTTOM_LEFT, PLAYER_COLORS[0].lightened(0.35))
		_add_hint("P2:  LEFT / RIGHT + UP     DOWN: use item", Control.PRESET_BOTTOM_RIGHT, PLAYER_COLORS[1].lightened(0.35))
		_add_hint("Esc twice: menu", Control.PRESET_CENTER_BOTTOM, UiTheme.DIM)
	queue_redraw()


func _add_hint(text: String, preset: int, color: Color) -> void:
	var hint := Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	hint.add_theme_color_override("font_color", color)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)


func set_score(player_id: int, value: int) -> void:
	_scores[player_id - 1] = value
	queue_redraw()


func set_scores(p1: int, p2: int) -> void:
	_scores = [p1, p2]
	queue_redraw()


func set_item(player_id: int, id: String, ammo := 0) -> void:
	item_ids[player_id - 1] = id
	_item_ammo[player_id - 1] = ammo
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
	if quit_prompt_label == null:
		return
	quit_prompt_label.visible = true
	quit_prompt_panel.visible = true
	if _quit_tween:
		_quit_tween.kill()
	_quit_tween = create_tween()
	_quit_tween.tween_interval(seconds)
	_quit_tween.tween_callback(func() -> void:
		quit_prompt_label.visible = false
		quit_prompt_panel.visible = false)


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
	_roulette_sfx = 0
	event_text = _roulette_ticks[0][1]
	queue_redraw()


func show_event(event_name: String, seconds: float, color := UiTheme.ACCENT) -> void:
	event_state = "active"
	event_text = event_name
	_event_color = color
	_event_seconds = maxf(seconds, 0.01)
	_event_time = 0.0
	event_fraction = 1.0
	queue_redraw()


func hide_event() -> void:
	event_state = ""
	event_text = ""
	event_fraction = 0.0
	_roulette_ticks.clear()
	queue_redraw()


func _process(delta: float) -> void:
	var changed := _update_fade(delta)
	if event_state != "":
		_event_time += delta
		if event_state == "roulette":
			var passed := 0
			for tick in _roulette_ticks:
				if tick[0] <= _event_time:
					event_text = tick[1]
					passed += 1
			if passed > _roulette_sfx:
				_roulette_sfx = passed
				Sfx.play("roulette_stop" if passed >= _roulette_ticks.size() else "tick")
		else:
			event_fraction = clampf(1.0 - _event_time / _event_seconds, 0.0, 1.0)
		changed = true
	if changed:
		queue_redraw()


func panel_rects() -> Dictionary:
	var mid := size.x / 2.0
	var rects := {}
	for i in 2:
		var box := _score_box(i)
		rects["score%d" % (i + 1)] = box
		rects["item%d" % (i + 1)] = _slot_rect(i, box)
	if event_state == "roulette":
		rects["event"] = Rect2(Vector2(mid - EVENT_SIZE_ROLL.x / 2.0, EVENT_ACTIVE_Y), EVENT_SIZE_ROLL)
	elif event_state == "active":
		rects["event"] = Rect2(Vector2(mid - EVENT_SIZE_ACTIVE.x / 2.0, EVENT_ACTIVE_Y), EVENT_SIZE_ACTIVE)
	else:
		rects["event"] = Rect2(Vector2(mid - 100.0, 14.0), Vector2(200.0, 64.0))
	return rects


func panel_alpha(panel_name: String) -> float:
	return _panel_alpha.get(panel_name, 1.0)


func _update_fade(delta: float) -> bool:
	var changed := false
	var rects := panel_rects()
	for key in rects:
		var want := 1.0
		for cover in cover_rects:
			if (rects[key] as Rect2).intersects(cover):
				want = FADE_ALPHA
				break
		var now: float = _panel_alpha.get(key, 1.0)
		if not is_equal_approx(now, want):
			_panel_alpha[key] = move_toward(now, want, FADE_SPEED * delta)
			changed = true
	return changed


func show_win(winner_id: int, final_scores: Array) -> void:
	if win_panel != null:
		return
	if _flash_tween:
		_flash_tween.kill()
	message_label.modulate.a = 0.0
	win_panel = PanelContainer.new()
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	win_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(win_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	win_panel.add_child(box)
	var title := Label.new()
	if vs_bot:
		title.text = "BOT WINS!" if winner_id == 2 else "YOU WIN!"
	else:
		title.text = "PLAYER %d WINS!" % winner_id
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiTheme.FONT_LARGE)
	title.add_theme_color_override("font_color", PLAYER_COLORS[winner_id - 1])
	box.add_child(title)
	var score_label := Label.new()
	score_label.text = "%d  -  %d" % [final_scores[0], final_scores[1]]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", UiTheme.FONT_MEDIUM)
	box.add_child(score_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	rematch_button = Button.new()
	rematch_button.text = "Rematch"
	rematch_button.pressed.connect(rematch_pressed.emit)
	row.add_child(rematch_button)
	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.pressed.connect(menu_pressed.emit)
	row.add_child(menu_button)
	_arm_panel_keys([rematch_button, menu_button], rematch_button)


func _input(event: InputEvent) -> void:
	if win_panel == null or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] or key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		return
	for action in PANEL_JUMP_ACTIONS:
		if InputMap.has_action(action) and event.is_action(action):
			get_viewport().set_input_as_handled()
			return


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


func _draw() -> void:
	if _frame == null:
		return
	var font := get_theme_default_font()
	for i in 2:
		var box := _score_box(i)
		var a := panel_alpha("score%d" % (i + 1))
		_frame.modulate_color = Color(1, 1, 1, a)
		draw_style_box(_frame, box)
		var col: Color = PLAYER_COLORS[i]
		col.a = a
		var label := "BOT" if vs_bot and i == 1 else "P%d" % (i + 1)
		draw_string(font, box.position + Vector2(20 if label == "BOT" else 34, 50), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_MEDIUM, col)
		draw_string(font, box.position + Vector2(112, 56), str(_scores[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_LARGE, col.lightened(0.2))
		draw_string(font, box.position + Vector2(160, 56), "/ %d" % win_score, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, _fade(UiTheme.DIM, a))
		_draw_item_slot(font, i, box)
	var mid := size.x / 2.0
	var ea := panel_alpha("event")
	if event_state == "":
		PixelArt.draw_centered(self, PixelArt.CROWN, Vector2(mid, 34), CROWN_PX, Color(1, 1, 1, ea))
		draw_string(font, Vector2(mid - 100, 70), "FIRST TO %d WINS" % win_score, HORIZONTAL_ALIGNMENT_CENTER, 200, UiTheme.FONT_SMALL, _fade(UiTheme.TEXT, ea))
	else:
		_draw_event_banner(font, mid, ea)
	_frame.modulate_color = Color.WHITE


func _score_box(i: int) -> Rect2:
	var x := MARGIN if i == 0 else size.x - MARGIN - BOX_SIZE.x
	return Rect2(Vector2(x, 12), BOX_SIZE)


func _slot_rect(i: int, score_box: Rect2) -> Rect2:
	var x := score_box.end.x + SLOT_GAP if i == 0 else score_box.position.x - SLOT_GAP - SLOT_SIZE.x
	return Rect2(Vector2(x, score_box.position.y), SLOT_SIZE)


func _fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func _draw_item_slot(font: Font, i: int, score_box: Rect2) -> void:
	var slot := _slot_rect(i, score_box)
	var a := panel_alpha("item%d" % (i + 1))
	_frame.modulate_color = Color(1, 1, 1, a)
	draw_style_box(_frame, slot)
	var id: String = item_ids[i]
	var col: Color = PLAYER_COLORS[i]
	if id == "":
		draw_string(font, Vector2(slot.position.x, slot.position.y + 46), "ITEM", HORIZONTAL_ALIGNMENT_CENTER, slot.size.x, UiTheme.FONT_SMALL, _fade(UiTheme.DIM, a))
		return
	var pattern: Array = BrawlItems.ITEM_ICONS[id]
	var px := floorf(minf(60.0 / String(pattern[0]).length(), 34.0 / pattern.size()))
	PixelArt.draw_centered(self, pattern, slot.position + Vector2(slot.size.x / 2.0, 30.0), px, Color(1, 1, 1, a))
	var label: String = BrawlItems.ITEM_NAMES[id]
	if id == "gun":
		label += " x%d" % _item_ammo[i]
	draw_string(font, Vector2(slot.position.x, slot.position.y + 62), label, HORIZONTAL_ALIGNMENT_CENTER, slot.size.x, UiTheme.FONT_SMALL, _fade(col.lightened(0.35), a))


func _draw_event_banner(font: Font, mid: float, ea: float) -> void:
	_frame.modulate_color = Color(1, 1, 1, ea)
	var outline := Color(0, 0, 0, ea)
	if event_state == "roulette":
		var box := Rect2(Vector2(mid - EVENT_SIZE_ROLL.x / 2.0, EVENT_ACTIVE_Y), EVENT_SIZE_ROLL)
		draw_style_box(_frame, box)
		draw_string(font, Vector2(box.position.x, box.position.y + 25), "RANDOM EVENT", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_SMALL, _fade(UiTheme.DIM, ea))
		var landed := _event_time >= _roulette_total
		var col := UiTheme.TEXT
		if landed:
			col = _event_color if int(_event_time * 8.0) % 2 == 0 else Color.WHITE
		draw_string_outline(font, Vector2(box.position.x, box.position.y + 64), event_text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_LARGE, 8, outline)
		draw_string(font, Vector2(box.position.x, box.position.y + 64), event_text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_LARGE, _fade(col, ea))
		var arrow := _fade(UiTheme.ACCENT if landed else UiTheme.DIM, ea)
		var cy := box.position.y + box.size.y / 2.0 + 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(box.position.x + 40, cy - 12), Vector2(box.position.x + 40, cy + 12), Vector2(box.position.x + 58, cy)]), arrow)
		draw_colored_polygon(PackedVector2Array([Vector2(box.end.x - 40, cy - 12), Vector2(box.end.x - 40, cy + 12), Vector2(box.end.x - 58, cy)]), arrow)
		return
	var panel := Rect2(Vector2(mid - EVENT_SIZE_ACTIVE.x / 2.0, EVENT_ACTIVE_Y), EVENT_SIZE_ACTIVE)
	draw_style_box(_frame, panel)
	draw_string_outline(font, Vector2(panel.position.x, panel.position.y + 38), event_text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, UiTheme.FONT_MEDIUM, 6, outline)
	draw_string(font, Vector2(panel.position.x, panel.position.y + 38), event_text, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, UiTheme.FONT_MEDIUM, _fade(_event_color, ea))
	var bar := Rect2(Vector2(panel.position.x + 60, panel.position.y + 46), Vector2(panel.size.x - 120, 8))
	draw_rect(bar.grow(2), Color(0.02, 0.03, 0.05, ea))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * event_fraction, bar.size.y)), _fade(_event_color if event_fraction > 0.25 or int(_event_time * 6.0) % 2 == 0 else Color.WHITE, ea))
