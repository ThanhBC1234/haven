extends Node

const OUT_PATH := "res://scripts/brawl_graphs.gd"


func _ready() -> void:
	Game.save_enabled = false
	BrawlBot.use_prebuilt = false
	BrawlBot._graph_cache.clear()
	var lines: Array[String] = []
	for arena in BrawlData.ARENAS.size():
		var packed := await build(self, arena)
		lines.append("\t%s: [" % JSON.stringify(packed[0]))
		for row in packed[1]:
			lines.append("\t\t%s," % JSON.stringify(row))
		lines.append("\t],")
		print("arena %d: %d nodes" % [arena, (packed[1] as Array).size()])
	var head := FileAccess.get_file_as_string(OUT_PATH)
	head = head.substr(0, head.find("const GRAPHS"))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(head + "const GRAPHS := {\n" + "\n".join(lines) + "\n}\n")
	f.close()
	print("wrote %s" % OUT_PATH)
	BrawlBot.use_prebuilt = true
	get_tree().quit()


static func build(host: Node, arena: int) -> Array:
	var keep := BrawlBot.use_prebuilt
	BrawlBot.use_prebuilt = false
	BrawlBot._graph_cache.clear()
	Game.brawl_vs_bot = true
	var br: Brawl = load("res://scenes/brawl.tscn").instantiate()
	br.arena_index = arena
	br.intro_seconds = 0.05
	host.add_child(br)
	Game.brawl_vs_bot = false
	var bot: BrawlBot = br.bot
	bot.set_physics_process(false)
	while not bot._graph_done:
		bot._graph_step(-1)
	var out := [bot._graph_key(), bot.pack_graph()]
	for k in 20:
		await host.get_tree().physics_frame
	br.queue_free()
	await host.get_tree().physics_frame
	BrawlBot._graph_cache.clear()
	BrawlBot.use_prebuilt = keep
	return out
