extends Node


func _ready() -> void:
	var rows := []
	for i in 12:
		rows.append("#" + ".".repeat(150) + "#")
	rows[10] = "#..O" + ".".repeat(147) + "#"
	rows.append("#".repeat(152))
	rows.append("#".repeat(152))
	var level := Level.new()
	add_child(level)
	level.build("\n".join(rows))
	var ball: Ball = load("res://scenes/ball.tscn").instantiate()
	ball.position = level.start_position
	level.add_child(ball)
	await _frames(90)
	var ground_y := ball.global_position.y
	for amount in [0.0, 0.25, 0.5, 0.75, 1.0]:
		ball.teleport(Vector2(200, ground_y))
		await _frames(30)
		ball.jump(1, amount)
		await _frames(3)
		var top := ground_y
		var first_land_x := -1.0
		var bounces: Array[String] = []
		var prev_vy := 0.0
		var peak := ground_y
		for n in 360:
			await _frames(1)
			var y := ball.global_position.y
			top = minf(top, y)
			peak = minf(peak, y)
			if first_land_x < 0.0 and ball.on_ground:
				first_land_x = ball.global_position.x
			if prev_vy < 0.0 and ball.linear_velocity.y >= 0.0 and first_land_x >= 0.0:
				bounces.append("%.1f" % ((ground_y - peak) / 32.0))
			if ball.linear_velocity.y > 0.0 and prev_vy <= 0.0:
				peak = y
			prev_vy = ball.linear_velocity.y
		print("do manh %.2f: cao %.1f o, xa %.1f o, nay lai: %s, dung o x=%.1f o" % [
			amount, (ground_y - top) / 32.0, (first_land_x - 200.0) / 32.0, ", ".join(bounces), (ball.global_position.x - 200.0) / 32.0])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
