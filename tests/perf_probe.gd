extends Node

const WARMUP := 2.0
const SAMPLE := 4.0

var _modes := [
	["menu", func(): Game.go_to_menu()],
	["level 1", func(): Game.start_level(0)],
	["level 3 boss", func(): Game.start_level(2)],
	["endless", func(): Game.start_endless()],
	["brawl vs bot", func(): Game.start_brawl(true)],
	["chained 1", func(): Game.start_chained(0)],
	["chained 3", func(): Game.start_chained(2)],
]


func _ready() -> void:
	Game.save_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var probe := self
	get_parent().remove_child.call_deferred(probe)
	get_tree().root.add_child.call_deferred(probe)
	await get_tree().process_frame
	await get_tree().process_frame
	for m in _modes:
		m[1].call()
		await get_tree().create_timer(WARMUP).timeout
		await _measure(m[0])
		if "--nobg" in OS.get_cmdline_user_args():
			for n in get_tree().root.find_children("*", "Node2D", true, false):
				if n.get_script() and String(n.get_script().resource_path).ends_with("background.gd"):
					n.visible = false
					n.set_process(false)
			await _measure(m[0] + " nobg")
	get_tree().quit()


func _measure(label: String) -> void:
	var frames := 0
	var proc := 0.0
	var phys := 0.0
	var draws := 0
	var worst := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < SAMPLE * 1e6:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("%-14s fps %6.0f | process %5.2f ms | physics %5.2f ms | draw calls %5d | nodes %5d | worst frame %5.1f ms" % [
		label, frames / SAMPLE, proc / frames * 1000.0, phys / frames * 1000.0, draws / frames,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), worst])
