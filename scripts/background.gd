extends Node2D

const SKY_TOP := Color("#0b0e18")
const SKY_BOTTOM := Color("#1d3140")
const LAYERS := [
	[0.10, 0.62, 120.0, 46.0, Color("#16242f")],
	[0.25, 0.74, 150.0, 58.0, Color("#111b24")],
	[0.45, 0.88, 190.0, 74.0, Color("#0b1118")],
]
const FIREFLY := Color("#c8f56a")

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	var cam_x := cam.get_screen_center_position().x if cam else _time * 20.0
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	var moon := Vector2(view.x * 0.9, view.y * 0.2)
	draw_circle(moon, 40.0, Color("#d9e6c8", 0.08))
	draw_circle(moon, 24.0, Color("#e9f2dc", 0.8))
	for i in LAYERS.size():
		var l: Array = LAYERS[i]
		_forest(view, cam_x * l[0], view.y * l[1], l[2], l[3], l[4], i)
		var mist_y: float = view.y * l[1] - 10.0
		draw_rect(Rect2(0, mist_y, view.x, 40), Color("#5d7a86", 0.05))
	_fireflies(view, cam_x)


func _forest(view: Vector2, offset: float, base_y: float, tree_h: float, gap: float, color: Color, seed_: int) -> void:
	draw_rect(Rect2(0, base_y, view.x, view.y - base_y), color)
	var first := floori(offset / gap) - 1
	var count := int(view.x / gap) + 3
	for k in count:
		var i := first + k
		var x := i * gap - offset
		var h := tree_h * (0.7 + 0.3 * absf(sin(i * 12.9898 + seed_ * 3.1)))
		var w := h * 0.42
		for tier in 3:
			var top := base_y - h + tier * h * 0.22
			var half := w * (0.55 + tier * 0.22)
			draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x - half, top + h * 0.42), Vector2(x + half, top + h * 0.42)]), color)


func _fireflies(view: Vector2, cam_x: float) -> void:
	for i in 26:
		var fx := fposmod(i * 197.0 - cam_x * 0.6 + sin(_time * 0.7 + i) * 30.0, view.x)
		var fy := view.y * (0.45 + 0.4 * fposmod(i * 0.618, 1.0)) + sin(_time * 1.3 + i * 2.0) * 12.0
		var glow := 0.35 + 0.65 * maxf(0.0, sin(_time * 2.0 + i * 1.7))
		draw_circle(Vector2(fx, fy), 4.0, Color(FIREFLY, 0.12 * glow))
		draw_circle(Vector2(fx, fy), 1.5, Color(FIREFLY, 0.9 * glow))
