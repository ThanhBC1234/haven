extends Node

const DIR := "res://assets/sfx/"
const BUS := "SFX"
const POOL_SIZE := 8
const UI_FOCUS_QUIET_MSEC := 300

const SOUNDS := {
	"jump": {"db": -9.0, "cd": 0.06},
	"bounce": {"files": ["bounce_1", "bounce_2", "bounce_3"], "db": -6.0, "cd": 0.05, "pitch": 0.9},
	"land_hard": {"db": -6.0, "cd": 0.1},
	"charge": {"db": -24.0, "cd": 0.12},
	"shoot": {"db": -13.0, "cd": 0.05},
	"shield_break": {"db": -11.0, "cd": 0.1},
	"stomp": {"db": -8.0, "cd": 0.08},
	"pop": {"db": -11.0, "cd": 0.08},
	"respawn": {"db": -11.0, "cd": 0.2},
	"star": {"db": -10.0, "cd": 0.06},
	"heart": {"db": -11.0, "cd": 0.1},
	"shield": {"db": -11.0, "cd": 0.1},
	"boost": {"db": -11.0, "cd": 0.1},
	"gun_pick": {"db": -11.0, "cd": 0.1},
	"spring": {"db": -10.0, "cd": 0.12},
	"checkpoint": {"db": -10.0, "cd": 0.3},
	"door_open": {"db": -13.0, "cd": 0.15},
	"door_close": {"db": -12.0, "cd": 0.15},
	"button_on": {"db": -14.0, "cd": 0.1},
	"button_off": {"db": -16.0, "cd": 0.1},
	"boss_hit": {"db": -8.0, "cd": 0.08},
	"explosion": {"db": -8.0, "cd": 0.2, "pitch": 0.85},
	"win": {"db": -7.0, "cd": 0.5, "jingle": true, "jitter": 0.0},
	"lose": {"db": -8.0, "cd": 0.5, "jingle": true, "jitter": 0.0},
	"win_match": {"db": -7.0, "cd": 0.5, "jingle": true, "jitter": 0.0},
	"point": {"db": -11.0, "cd": 0.2},
	"tick": {"db": -19.0, "cd": 0.02, "jitter": 0.0},
	"roulette_stop": {"db": -12.0, "cd": 0.2},
	"fuse": {"db": -18.0, "cd": 0.05, "jitter": 0.0},
	"item_pick": {"db": -12.0, "cd": 0.1},
	"item_banana": {"db": -12.0, "cd": 0.1},
	"item_swap": {"db": -13.0, "cd": 0.1},
	"item_trap": {"db": -13.0, "cd": 0.1},
	"warn": {"db": -13.0, "cd": 0.5, "jitter": 0.0},
	"rope_star": {"db": -15.0, "cd": 0.08},
	"star_steal": {"db": -11.0, "cd": 0.2},
	"anchor_on": {"db": -15.0, "cd": 0.1},
	"anchor_off": {"db": -17.0, "cd": 0.1},
	"ui_focus": {"db": -22.0, "cd": 0.04, "jitter": 0.03},
	"ui_click": {"db": -14.0, "cd": 0.05, "jitter": 0.03},
}

var muted := false
var plays := 0
var last_played := ""
var last_volume_db := 0.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _jingle: AudioStreamPlayer
var _next := 0
var _last_msec := {}
var _rng := RandomNumberGenerator.new()
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	for sound in SOUNDS:
		for f in files_of(sound):
			if not _streams.has(f):
				var s := load(DIR + f + ".ogg") as AudioStream
				if s != null:
					_streams[f] = s
	for i in POOL_SIZE:
		_pool.append(_make_player())
	_jingle = _make_player()
	sync_from_game()
	get_tree().node_added.connect(_on_node_added)


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	add_child(p)
	return p


static func files_of(sound: String) -> Array:
	var def: Dictionary = SOUNDS.get(sound, {})
	return def.get("files", [sound])


func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08) -> bool:
	var def: Dictionary = SOUNDS.get(sound, {})
	if def.is_empty():
		push_warning("Sfx: unknown sound '%s'" % sound)
		return false
	if muted:
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_msec.get(sound, -1000000)) < int(float(def.get("cd", 0.05)) * 1000.0):
		return false
	var files: Array = files_of(sound)
	var stream: AudioStream = _streams.get(files[_rng.randi() % files.size()])
	if stream == null:
		return false
	_last_msec[sound] = now
	var p: AudioStreamPlayer = _jingle if def.get("jingle", false) else _take_player()
	var jitter := float(def.get("jitter", pitch_jitter))
	p.stream = stream
	p.volume_db = float(def.get("db", -8.0)) + volume_db
	last_volume_db = p.volume_db
	p.pitch_scale = float(def.get("pitch", 1.0)) * (1.0 + _rng.randf_range(-jitter, jitter))
	p.play()
	plays += 1
	last_played = sound
	return true


func _take_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var p := _pool[(_next + i) % POOL_SIZE]
		if not p.playing:
			_next = (_next + i + 1) % POOL_SIZE
			return p
	var busy := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	return busy


func reset_cooldowns() -> void:
	_last_msec.clear()


func sync_from_game() -> void:
	muted = Game.sfx_muted
	_apply_mute()


func set_muted(on: bool) -> void:
	muted = on
	Game.sfx_muted = on
	_apply_mute()
	Game.save_progress()


func toggle_mute() -> void:
	set_muted(not muted)
	_show_toast("SOUND OFF  (M)" if muted else "SOUND ON  (M)")
	if not muted:
		play("ui_click")


func _apply_mute() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_M:
		toggle_mute()
		get_viewport().set_input_as_handled()


func _show_toast(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_toast = Label.new()
		_toast.add_theme_font_override("font", UiTheme.main_font())
		_toast.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
		_toast.add_theme_color_override("font_outline_color", Color("#05080c"))
		_toast.add_theme_constant_override("outline_size", 4)
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_toast)
	_toast.text = text
	_toast.size = Vector2.ZERO
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 8)
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _on_node_added(node: Node) -> void:
	var b := node as BaseButton
	if b == null or b.has_meta("sfx_wired"):
		return
	b.set_meta("sfx_wired", Time.get_ticks_msec())
	b.pressed.connect(_on_button_pressed)
	b.focus_entered.connect(_on_button_focus.bind(b))


func _on_button_pressed() -> void:
	play("ui_click")


func _on_button_focus(b: BaseButton) -> void:
	if Time.get_ticks_msec() - int(b.get_meta("sfx_wired", 0)) < UI_FOCUS_QUIET_MSEC:
		return
	play("ui_focus")
