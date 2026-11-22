extends Node
## Chụp menu. Chạy có cửa sổ: godot --path . res://tests/menu_preview.tscn -- --shots=<thư mục>

func _ready() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	add_child(load("res://scenes/menu.tscn").instantiate())
	for k in 40:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("menu2.png"))
	get_tree().quit()
