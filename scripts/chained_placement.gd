class_name ChainedPlacement
extends RefCounted

const GROUND_LAYER := 1
const OFFSET_STEP := 16.0
const OFFSET_UP := 320.0
const OFFSET_SIDE := 640.0
const EDGE_MARGIN := 10.0
const WALL_MARGIN := 48.0
const STAR_LIFT := 16.0
const CLEAR_RADIUS := 12.0
const SKIPPED_ABOVE := "^vT"

static var _offsets: Array[Vector2] = []
static var _probe: CircleShape2D = null


static func find(chained: Chained, from: Vector2, placed: Array[Vector2], fallback: Vector2, opts := {}) -> Dictionary:
	var search_range: float = opts.get("range", OFFSET_SIDE)
	var min_spacing: float = opts.get("spacing", 20.0)
	var max_drop: float = opts.get("max_drop", 100000.0)
	var avoid_list: Array = []
	if opts.has("avoid_points"):
		avoid_list.append_array(opts["avoid_points"])
	if opts.has("avoid"):
		avoid_list.append(opts["avoid"])
	var avoid_radius: float = opts.get("avoid_radius", 0.0)
	var space := chained.get_world_2d().direct_space_state
	var size := chained.level.size
	for off in _all_offsets():
		if off.length() > search_range:
			break
		var start := from + off
		if start.x < WALL_MARGIN or start.x > size.x - WALL_MARGIN or start.y < 0.0 or start.y > size.y:
			continue
		if not star_clear(chained, start):
			continue
		var ground = _ground_below(chained, space, start)
		if ground == null or ground.y - start.y > max_drop:
			continue
		var too_close := false
		for avoid: Vector2 in avoid_list:
			if absf(ground.x - avoid.x) < avoid_radius and absf(ground.y - avoid.y) < 64.0:
				too_close = true
				break
		if too_close:
			continue
		var crowded := false
		for p in placed:
			if p.distance_to(ground) < min_spacing:
				crowded = true
				break
		if crowded:
			continue
		return {"start": start, "ground": ground, "ok": true}
	return {"start": fallback, "ground": fallback, "ok": false}


static func star_clear(chained: Chained, origin: Vector2) -> bool:
	var space := chained.get_world_2d().direct_space_state
	var center := origin + Vector2(0.0, -STAR_LIFT)
	var point := PhysicsPointQueryParameters2D.new()
	point.position = center
	point.collision_mask = GROUND_LAYER
	if not space.intersect_point(point, 1).is_empty():
		return false
	if _probe == null:
		_probe = CircleShape2D.new()
		_probe.radius = CLEAR_RADIUS
	var shape := PhysicsShapeQueryParameters2D.new()
	shape.shape = _probe
	shape.transform = Transform2D(0.0, center)
	shape.collision_mask = GROUND_LAYER
	return space.intersect_shape(shape, 1).is_empty()


static func _ground_below(chained: Chained, space: PhysicsDirectSpaceState2D, start: Vector2):
	var level := chained.level
	var point := Vector2.ZERO
	for dx in [0.0, -EDGE_MARGIN, EDGE_MARGIN]:
		var query := PhysicsRayQueryParameters2D.create(Vector2(start.x + dx, start.y), Vector2(start.x + dx, level.size.y + 64.0), GROUND_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return null
		if dx == 0.0:
			point = hit["position"]
		elif absf(hit["position"].y - point.y) > Level.TILE * 0.75:
			return null
	var above := level.char_at(int(point.y / Level.TILE) - 1, int(point.x / Level.TILE))
	if SKIPPED_ABOVE.contains(above):
		return null
	if not star_clear(chained, point):
		return null
	return point


static func _all_offsets() -> Array[Vector2]:
	if _offsets.is_empty():
		var dx := -OFFSET_SIDE
		while dx <= OFFSET_SIDE:
			var dy := 0.0
			while dy <= OFFSET_UP:
				_offsets.append(Vector2(dx, -dy))
				dy += OFFSET_STEP
			dx += OFFSET_STEP
		_offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			var la := a.length_squared()
			var lb := b.length_squared()
			if la != lb:
				return la < lb
			return a.x > b.x)
	return _offsets
