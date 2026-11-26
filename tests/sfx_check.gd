extends Node

const TMP_SAVE := "user://sfx_check_save.cfg"
const SFX_DIR := "res://assets/sfx"
const MAX_TOTAL_BYTES := 1500000
const MAX_SECONDS := 2.0

var failures := 0


func _expect(cond: bool, what: String) -> void:
	if cond:
		print("ok   - %s" % what)
	else:
		failures += 1
		print("FAIL - %s" % what)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + "/" + d))
	return out


func _played_names(code: String, bare_play: bool) -> Dictionary:
	var found := {}
	var keys := ["Sfx.play("]
	if bare_play:
		keys.append("\tplay(")
	for key in keys:
		var from := 0
		while true:
			var at: int = code.find(key, from)
			if at == -1:
				break
			var i: int = at + key.length()
			var depth := 1
			var start: int = i
			while i < code.length() and depth > 0:
				var ch: String = code[i]
				if ch == "\"":
					i = code.find("\"", i + 1)
					if i == -1:
						break
				elif ch == "(":
					depth += 1
				elif ch == ")":
					depth -= 1
				i += 1
			var call := code.substr(start, maxi(0, i - start))
			var rx := RegEx.create_from_string("\"([^\"]*)\"")
			for m in rx.search_all(call):
				found[m.get_string(1)] = int(found.get(m.get_string(1), 0)) + 1
			from = at + key.length()
	return found


func _ready() -> void:
	Game.save_enabled = false
	await get_tree().process_frame
	var all_names := {}
	var calls := 0
	for path in _gd_files("res://scripts"):
		var code := FileAccess.get_file_as_string(path)
		var names := _played_names(code, path.ends_with("/sfx.gd"))
		for n in names:
			all_names[n] = int(all_names.get(n, 0)) + int(names[n])
			calls += int(names[n])
	_expect(calls >= 40, "found the Sfx.play calls in scripts/ (%d names)" % calls)
	for n in all_names:
		_expect(Sfx.SOUNDS.has(n), "Sfx.play(\"%s\") names a sound that exists in Sfx.SOUNDS" % n)
	for n in Sfx.SOUNDS:
		_expect(all_names.has(n), "sound \"%s\" is played somewhere in scripts/ (no dead entries)" % n)

	var used_files := {}
	for n in Sfx.SOUNDS:
		for f in Sfx.files_of(n):
			used_files[f] = true
			var path := "%s/%s.ogg" % [SFX_DIR, f]
			var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
			_expect(stream != null, "%s loads as an audio stream" % path)
			if stream != null:
				var secs := stream.get_length()
				_expect(secs > 0.0 and secs <= MAX_SECONDS, "%s is short (%.2f s)" % [path, secs])
	var total := 0
	for f in DirAccess.get_files_at(SFX_DIR):
		if f.ends_with(".ogg"):
			total += FileAccess.get_file_as_bytes("%s/%s" % [SFX_DIR, f]).size()
			_expect(used_files.has(f.get_basename()), "%s is used by a sound (no stray files)" % f)
	_expect(total > 0 and total <= MAX_TOTAL_BYTES, "assets/sfx/ stays small for the web build (%d bytes)" % total)
	_expect(FileAccess.file_exists(SFX_DIR + "/LICENSE-retro.txt"), "assets/sfx/LICENSE-retro.txt exists")
	_expect(Sfx._streams.size() == used_files.size(), "Sfx preloaded every file (%d of %d)" % [Sfx._streams.size(), used_files.size()])
	_expect(AudioServer.get_bus_index("SFX") != -1, "the SFX bus exists")

	Sfx.set_muted(false)
	Sfx.reset_cooldowns()
	_expect(Sfx.play("bounce"), "first bounce plays")
	_expect(not Sfx.play("bounce"), "second bounce right away is blocked by the cooldown")
	_expect(Sfx.play("jump"), "a different sound is not blocked by the bounce cooldown")
	OS.delay_msec(int(float(Sfx.SOUNDS["bounce"]["cd"]) * 1000.0) + 30)
	_expect(Sfx.play("bounce"), "bounce plays again after its cooldown")
	Sfx.reset_cooldowns()
	var before := Sfx.plays
	var played := 0
	for i in 40:
		if Sfx.play("star"):
			played += 1
	_expect(played == 1 and Sfx.plays == before + 1, "40 star sounds in one frame -> exactly 1 plays (%d)" % played)
	_expect(not Sfx.play("no_such_sound"), "an unknown name is ignored without an error")
	Sfx.reset_cooldowns()
	for n in Sfx.SOUNDS:
		Sfx.play(n)
	_expect(Sfx.plays > before + 1, "every sound can play back to back through the 8-player pool")
	_expect(Sfx._pool.size() == Sfx.POOL_SIZE, "the player pool has %d members" % Sfx.POOL_SIZE)

	Sfx.reset_cooldowns()
	seed(12345)
	var a := randi()
	seed(12345)
	Sfx.play("jump")
	var b := randi()
	_expect(a == b, "Sfx.play does not consume the game's random numbers")

	Sfx.reset_cooldowns()
	Sfx.set_muted(true)
	_expect(Game.sfx_muted and Sfx.muted, "set_muted(true) updates Game.sfx_muted")
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "muting mutes the SFX bus")
	_expect(not Sfx.play("jump"), "nothing plays while muted")
	Game.save_enabled = true
	Game.save_progress(TMP_SAVE)
	Game.save_enabled = false
	Game.sfx_muted = false
	Sfx.sync_from_game()
	_expect(not Sfx.muted, "after reset the sound is on")
	Game.load_progress(TMP_SAVE)
	Sfx.sync_from_game()
	_expect(Game.sfx_muted and Sfx.muted, "mute persists through the save file")
	_expect(not Sfx.play("jump"), "and stays silent after reloading the save")
	var old := ConfigFile.new()
	old.set_value("progress", "best_score", 120)
	old.set_value("progress", "total_stars", 3)
	old.save(TMP_SAVE)
	Game.load_progress(TMP_SAVE)
	Sfx.sync_from_game()
	_expect(not Game.sfx_muted and not Sfx.muted and Game.best_score == 120, "an old save without the mute key loads fine (sound on, score %d)" % Game.best_score)
	var bad := ConfigFile.new()
	bad.set_value("progress", "best_score", 77)
	bad.set_value("settings", "sfx_muted", "yes")
	bad.save(TMP_SAVE)
	Game.load_progress(TMP_SAVE)
	_expect(not Game.sfx_muted and Game.best_score == 77, "a mute key of the wrong type is ignored without breaking the other keys")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	Sfx.set_muted(false)
	_key(KEY_M, true)
	await get_tree().process_frame
	_key(KEY_M, false)
	await get_tree().process_frame
	_expect(Sfx.muted and Game.sfx_muted, "pressing M mutes")
	_key(KEY_M, true)
	await get_tree().process_frame
	_key(KEY_M, false)
	await get_tree().process_frame
	_expect(not Sfx.muted and not Game.sfx_muted, "pressing M again unmutes")
	Sfx.reset_cooldowns()

	var scene: PackedScene = load("res://scenes/ball.tscn")
	var ball1: Ball = scene.instantiate()
	var ball2: Ball = scene.instantiate()
	add_child(ball1)
	add_child(ball2)
	ball1.freeze = true
	ball2.freeze = true
	before = Sfx.plays
	ball1._play_land_sfx(80.0)
	_expect(Sfx.plays == before, "a tiny bounce is silent")
	ball1._play_land_sfx(300.0)
	_expect(Sfx.plays == before + 1 and Sfx.last_played == "bounce", "a normal bounce plays 'bounce'")
	var soft_db := Sfx.last_volume_db
	Sfx.reset_cooldowns()
	ball1._play_land_sfx(300.0)
	_expect(Sfx.plays == before + 1, "the same ball cannot bounce twice within 0.08 s")
	ball2._play_land_sfx(300.0)
	_expect(Sfx.plays == before + 2, "another ball is not blocked by the first ball's timer")
	ball1._land_sfx_msec = -1000
	Sfx.reset_cooldowns()
	ball2._land_sfx_msec = -1000
	ball1._play_land_sfx(620.0)
	var hard_db := Sfx.last_volume_db
	_expect(hard_db > soft_db + 3.0, "a harder landing is louder (%.1f dB vs %.1f dB)" % [hard_db, soft_db])
	ball1._land_sfx_msec = -1000
	Sfx.reset_cooldowns()
	ball1._play_land_sfx(900.0)
	_expect(Sfx.last_played == "land_hard", "a very hard landing plays 'land_hard'")
	Sfx.reset_cooldowns()
	ball1._land_sfx_msec = -1000
	ball2._land_sfx_msec = -1000
	before = Sfx.plays
	ball1._play_land_sfx(400.0)
	ball2._play_land_sfx(400.0)
	_expect(Sfx.plays == before + 1, "two balls bouncing at the same moment make one sound, not two")
	ball1.dead = true
	ball1._land_sfx_msec = -1000
	Sfx.reset_cooldowns()
	before = Sfx.plays
	ball1._play_land_sfx(500.0)
	_expect(Sfx.plays == before, "a dead (hidden) ball makes no sound")
	ball1.queue_free()
	ball2.queue_free()

	var b1 := Button.new()
	var b2 := Button.new()
	add_child(b1)
	add_child(b2)
	await get_tree().process_frame
	_expect(b1.has_meta("sfx_wired") and b2.has_meta("sfx_wired"), "new buttons get sounds automatically")
	Sfx.reset_cooldowns()
	before = Sfx.plays
	b1.pressed.emit()
	_expect(Sfx.plays == before + 1 and Sfx.last_played == "ui_click", "pressing a button plays ui_click")
	Sfx.reset_cooldowns()
	before = Sfx.plays
	b1.grab_focus()
	_expect(Sfx.plays == before, "the first focus right after a panel appears is silent")
	OS.delay_msec(Sfx.UI_FOCUS_QUIET_MSEC + 30)
	b2.grab_focus()
	_expect(Sfx.plays == before + 1 and Sfx.last_played == "ui_focus", "moving focus later plays a very quiet ui_focus")
	_expect(Sfx.last_volume_db <= -15.0, "ui_focus is very quiet (%.1f dB)" % Sfx.last_volume_db)
	b1.queue_free()
	b2.queue_free()

	print("RESULT: %s" % ("ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)
