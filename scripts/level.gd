class_name Level
extends Node2D

signal star_collected
signal star_collected_by(ball: Ball)
signal checkpoint_reached(pos: Vector2)
signal finished
signal channel_changed(channel: String, on: bool)
signal heart_collected
signal boss_started(boss: Node)
signal boss_defeated(boss: Node)

const TILE := 32.0
const ENEMY := preload("res://scenes/objects/enemy.tscn")
const CRATE := preload("res://scenes/objects/crate.tscn")
const SPIKES := preload("res://scenes/objects/spikes.tscn")
const BUTTON := preload("res://scenes/objects/pressure_button.tscn")
const DOOR := preload("res://scenes/objects/door.tscn")
const PLATFORM := preload("res://scenes/objects/moving_platform.tscn")
const SEESAW := preload("res://scenes/objects/seesaw.tscn")
const PICKUP := preload("res://scenes/objects/pickup.tscn")
const BOSS := preload("res://scenes/objects/boss.tscn")

const BUTTON_CHARS := "abd"
const DOOR_CHARS := "ABD"
const PICKUP_KINDS := {"*": "star", "K": "checkpoint", "F": "finish", "T": "trampoline",
	"+": "heart", "h": "shield", "g": "gun", "j": "jump_boost"}
const BOSS_GATE := "G"

const SLOPES := {
	"/": [Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)],
	"\\": [Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)],
	"1": [Vector2(0, 1), Vector2(1, 0.5), Vector2(1, 1)],
	"2": [Vector2(0, 0.5), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	"3": [Vector2(0, 0), Vector2(1, 0.5), Vector2(1, 1), Vector2(0, 1)],
	"4": [Vector2(0, 0.5), Vector2(1, 1), Vector2(0, 1)],
}
const SLOPE_GRASS := Color("#7fc241")
const SLOPE_GRASS_LIGHT := Color("#b7e36a")
const SLOPE_GRASS_DARK := Color("#3f6b2a")

const TILES := preload("res://assets/forest/forest_tiles.png")
const DECOR := preload("res://assets/forest/forest_decorations.png")
const SRC_TILE := 16.0
const DECOR_KINDS := [
	Rect2(64, 192, 32, 32),
	Rect2(96, 160, 32, 32),
]

@export var decorate := true

var rows: PackedStringArray = []
var cols := 0
var size := Vector2.ZERO
var start_position := Vector2.ZERO
var star_total := 0
var heart_gate := Callable()
var _pressed := {}
var _open := {}


static func of(node: Node) -> Level:
	var n := node
	while n and not n is Level:
		n = n.get_parent()
	return n as Level


static func channel_color(channel: String) -> Color:
	return {"a": Color("#ff5d5d"), "b": Color("#4da3ff"), "d": Color("#b46bff"), "boss": Color("#e8455a")}.get(channel, Color.WHITE)


func build(map: String) -> void:
	map = map.replace("\r", "")
	for line in map.strip_edges(false, true).split("\n"):
		if line.strip_edges() != "":
			rows.append(line)
	for r in rows:
		cols = maxi(cols, r.length())
	for i in rows.size():
		rows[i] = rows[i].rpad(cols, ".")
	size = Vector2(cols, rows.size()) * TILE

	_build_terrain()
	_build_doors()
	_build_platforms()
	for r in rows.size():
		for c in cols:
			_place(rows[r][c], r, c)
	queue_redraw()


func char_at(r: int, c: int) -> String:
	if r < 0 or r >= rows.size() or c < 0 or c >= cols:
		return "."
	return rows[r][c]


func _place(ch: String, r: int, c: int) -> void:
	var foot := Vector2((c + 0.5) * TILE, (r + 1) * TILE)
	match ch:
		"O":
			start_position = foot + Vector2(0, -16)
		"e":
			var e: Node2D = ENEMY.instantiate()
			e.position = foot + Vector2(0, -Enemy.HALF.y)
			add_child(e)
		"x":
			var x: Node2D = CRATE.instantiate()
			x.position = foot + Vector2(0, -Crate.SIZE / 2.0 - 1.0)
			add_child(x)
		"^", "v":
			var s: Node2D = SPIKES.instantiate()
			if ch == "v":
				s.position = Vector2((c + 0.5) * TILE, r * TILE)
				s.rotation = PI
			else:
				s.position = foot
			add_child(s)
		"S":
			var w: Node2D = SEESAW.instantiate()
			w.position = Vector2((c + 0.5) * TILE, (r + 0.5) * TILE)
			add_child(w)
		"M":
			var boss: Node2D = BOSS.instantiate()
			boss.position = foot + Vector2(0, -30)
			add_child(boss)
		_:
			if ch in PICKUP_KINDS:
				var p: Pickup = PICKUP.instantiate()
				p.kind = PICKUP_KINDS[ch]
				p.position = foot
				add_child(p)
				if ch == "*":
					star_total += 1
			elif ch != "" and ch in BUTTON_CHARS:
				var b: PressureButton = BUTTON.instantiate()
				b.channel = ch
				b.position = foot
				add_child(b)


func _build_terrain() -> void:
	var body := StaticBody2D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	body.physics_material_override = mat
	add_child(body)
	for r in rows.size():
		var c := 0
		while c < cols:
			if rows[r][c] != "#":
				c += 1
				continue
			var start := c
			while c < cols and rows[r][c] == "#":
				c += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((c - start) * TILE, TILE)
			shape.shape = rect
			shape.position = Vector2(start * TILE, r * TILE) + rect.size / 2.0
			body.add_child(shape)
	for r in rows.size():
		for c in cols:
			var ch := rows[r][c]
			if not SLOPES.has(ch):
				continue
			var shape := CollisionShape2D.new()
			var poly := ConvexPolygonShape2D.new()
			var pts := PackedVector2Array()
			for v in SLOPES[ch]:
				pts.append(Vector2(v) * TILE)
			poly.points = pts
			shape.shape = poly
			shape.position = Vector2(c, r) * TILE
			body.add_child(shape)


func _build_doors() -> void:
	for c in cols:
		var r := 0
		while r < rows.size():
			var ch := rows[r][c]
			if not (ch in DOOR_CHARS or ch == BOSS_GATE):
				r += 1
				continue
			var start := r
			while r < rows.size() and rows[r][c] == ch:
				r += 1
			var d: Door = DOOR.instantiate()
			d.channel = "boss" if ch == BOSS_GATE else ch.to_lower()
			d.height_tiles = r - start
			d.position = Vector2(c, start) * TILE
			add_child(d)


func _build_platforms() -> void:
	for r in rows.size():
		var c := 0
		while c < cols:
			if rows[r][c] != "=":
				c += 1
				continue
			var start := c
			while c < cols and rows[r][c] == "=":
				c += 1
			var p: MovingPlatform = PLATFORM.instantiate()
			p.width_tiles = c - start
			p.from = Vector2(start, r) * TILE
			p.to = p.from
			var right := rows[r].find(">", c)
			if right != -1:
				p.to = Vector2(right, r) * TILE
			else:
				for rr in rows.size():
					if rows[rr][start] == "|":
						p.to = Vector2(start, rr) * TILE
			add_child(p)


func reset_crates() -> void:
	for c in get_children():
		if c is Crate:
			c.reset()


func collect_star(by: Ball = null) -> void:
	star_collected.emit()
	star_collected_by.emit(by)


func collect_heart() -> void:
	heart_collected.emit()


func heart_wanted() -> bool:
	return not heart_gate.is_valid() or bool(heart_gate.call())


func start_boss(boss: Node) -> void:
	boss_started.emit(boss)


func defeat_boss(boss: Node) -> void:
	boss_defeated.emit(boss)
	_open["boss"] = true
	channel_changed.emit("boss", true)


func reach_checkpoint(pos: Vector2) -> void:
	checkpoint_reached.emit(pos)


func finish() -> void:
	finished.emit()


func set_button(channel: String, button: Node, is_pressed: bool) -> void:
	var set_: Dictionary = _pressed.get_or_add(channel, {})
	if is_pressed:
		set_[button] = true
	else:
		set_.erase(button)
	var now := not set_.is_empty()
	if now != _open.get(channel, false):
		_open[channel] = now
		channel_changed.emit(channel, now)


func _draw() -> void:
	for r in rows.size():
		for c in cols:
			if rows[r][c] != "#":
				continue
			var up := _solid(r - 1, c)
			var down := _solid(r + 1, c)
			var left := _solid(r, c - 1)
			var right := _solid(r, c + 1)
			var v := (r * 7 + c * 13) % 4
			var cell := Vector2(c, r) * TILE
			_quad(cell, 0, 0, _pick(up, left, Vector2i(0, 0), Vector2i(1 + v, 0), Vector2i(0, 1 + v), v))
			_quad(cell, 1, 0, _pick(up, right, Vector2i(5, 0), Vector2i(1 + v, 0), Vector2i(5, 1 + v), v))
			_quad(cell, 0, 1, _pick(down, left, Vector2i(0, 5), Vector2i(1 + v, 5), Vector2i(0, 1 + v), v))
			_quad(cell, 1, 1, _pick(down, right, Vector2i(5, 5), Vector2i(1 + v, 5), Vector2i(5, 1 + v), v))
	_draw_slopes()
	if decorate:
		_draw_decorations()


func _draw_slopes() -> void:
	var tex_size := Vector2(TILES.get_width(), TILES.get_height())
	for r in rows.size():
		for c in cols:
			var ch := rows[r][c]
			if not SLOPES.has(ch):
				continue
			var cell := Vector2(c, r) * TILE
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for v in SLOPES[ch]:
				pts.append(cell + Vector2(v) * TILE)
				uvs.append((Vector2(16, 16) + Vector2(v) * SRC_TILE) / tex_size)
			draw_colored_polygon(pts, Color.WHITE, uvs, TILES)
			var a: Vector2 = cell + Vector2(SLOPES[ch][0]) * TILE
			var b: Vector2 = cell + Vector2(SLOPES[ch][1]) * TILE
			draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 10), a + Vector2(0, 10)]), SLOPE_GRASS)
			draw_line(a + Vector2(0, 1), b + Vector2(0, 1), SLOPE_GRASS_LIGHT, 2.0)
			draw_line(a + Vector2(0, 11), b + Vector2(0, 11), SLOPE_GRASS_DARK, 2.0)


func _solid(r: int, c: int) -> bool:
	if r < 0 or r >= rows.size() or c < 0 or c >= cols:
		return true
	return rows[r][c] == "#" or SLOPES.has(rows[r][c])


func _pick(vert: bool, side: bool, corner: Vector2i, edge_v: Vector2i, edge_s: Vector2i, v: int) -> Vector2i:
	if not vert and not side:
		return corner
	if not vert:
		return edge_v
	if not side:
		return edge_s
	return Vector2i(1 + v, 1 + (v + 1) % 4)


func _quad(cell: Vector2, qx: int, qy: int, src: Vector2i) -> void:
	var src_rect := Rect2(Vector2(src) * SRC_TILE + Vector2(qx, qy) * SRC_TILE / 2.0, Vector2.ONE * SRC_TILE / 2.0)
	var dst_rect := Rect2(cell + Vector2(qx, qy) * TILE / 2.0, Vector2.ONE * TILE / 2.0)
	draw_texture_rect_region(TILES, dst_rect, src_rect)


func _draw_decorations() -> void:
	var last_c := -100
	for c in cols:
		for r in range(2, rows.size()):
			if rows[r][c] != "#" or _solid(r - 1, c) or char_at(r - 1, c) != "." or char_at(r - 2, c) != ".":
				continue
			if char_at(r - 1, c - 1) != "." or char_at(r - 1, c + 1) != ".":
				continue
			if not (_solid(r, c - 2) and _solid(r, c + 2)) or _solid(r - 1, c - 2) or _solid(r - 1, c + 2):
				continue
			var h := (c * 31 + r * 17) % 11
			if h > 2 or c - last_c < 5:
				continue
			var d: Rect2 = DECOR_KINDS[(c * 7 + r) % DECOR_KINDS.size()]
			var size_px := d.size * 2.0
			var foot := Vector2((c + 0.5) * TILE, r * TILE)
			draw_texture_rect_region(DECOR, Rect2(foot - Vector2(size_px.x / 2.0, size_px.y), size_px), d)
			last_c = c
