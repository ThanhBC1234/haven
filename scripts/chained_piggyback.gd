class_name ChainedPiggyback
extends Node2D

signal piggyback_started
signal piggyback_ended

const DEFAULT_SECONDS := 10.0
const HEAD_REACH := 49.0
const SIT_OVERLAP := 5.0
const MOUNT_TIME := 0.4
const MOUNT_ARC := 40.0
const RISE_SPEED := 500.0
const WORLD_MASK := 9
const HOP_VEL := Vector2(70.0, -300.0)
const HOP_SAMPLES := [60.0, 110.0, 160.0]
const SAFE_DROP := 130.0
const HAZARD_CHARS := "^vTeM"
const SWEAT := [
	".w.",
	".c.",
	"ccc",
	"cCc",
	".C.",
]
const HINT_DELAY := 0.5
const KEY_TEXT := {
	"p1_": ["A / D", "W / SPACE"],
	"p2_": ["LEFT / RIGHT", "UP"],
}

static var _font: Font = null

var chained: Chained
var piggyback_active := false
var piggyback_rider: Ball
var piggyback_carrier: Ball
var seconds_left := 0.0
var duration := DEFAULT_SECONDS
var _queued := 0
var _elapsed := 0.0
var _mount_from := Vector2.ZERO
var _lift := 0.0
var _saved_freeze := false
var _finishing := false
var _probe: CircleShape2D
var _banner: Banner
var _layer: CanvasLayer


func _ready() -> void:
	set_process(false)


func is_queued() -> bool:
	return _queued != 0


func setup(chained_node: Chained) -> void:
	chained = chained_node
	_queued = Game.chained_piggyback
	Game.chained_piggyback = 0
	Game.chained_switching = false
	process_physics_priority = -1
	chained.level_started.connect(_on_level_started)
	chained.level_finished.connect(_on_level_finished)
	chained.players_died.connect(_on_players_died)


func record_result(result: Vector2i) -> void:
	Game.chained_piggyback = ChainedHud.winner_of(result)


func start_piggyback(rider: Ball, carrier: Ball, seconds := DEFAULT_SECONDS) -> void:
	if rider == null or carrier == null or rider == carrier or rider.dead or carrier.dead:
		return
	if piggyback_active:
		_end(false)
	piggyback_rider = rider
	piggyback_carrier = carrier
	duration = maxf(seconds, 0.01)
	seconds_left = duration
	_elapsed = 0.0
	_finishing = false
	_mount_from = rider.global_position - carrier.global_position
	_lift = _head_height(carrier, rider)
	rider.begin_carried()
	carrier.jump_locked = true
	_saved_freeze = chained.rope.freeze_beads
	chained.rope.freeze_beads = true
	piggyback_active = true
	_make_banner()
	set_process(true)
	piggyback_started.emit()


func stop_piggyback() -> void:
	if piggyback_active:
		_end(true)


func _end(hop: bool) -> void:
	if not piggyback_active:
		return
	piggyback_active = false
	_finishing = false
	var rider := piggyback_rider
	var carrier := piggyback_carrier
	if is_instance_valid(carrier):
		carrier.jump_locked = false
	if is_instance_valid(rider):
		if hop and is_instance_valid(carrier) and rider.is_inside_tree() and carrier.is_inside_tree():
			var side := _pick_hop_side()
			var start := _hop_start(side)
			rider.end_carried(start, Vector2(HOP_VEL.x * side, HOP_VEL.y))
		else:
			rider.end_carried()
	if is_instance_valid(chained) and is_instance_valid(chained.rope) and not chained.finished:
		chained.rope.freeze_beads = _saved_freeze
	_free_banner()
	set_process(false)
	queue_redraw()
	piggyback_ended.emit()
	piggyback_rider = null
	piggyback_carrier = null


func _on_level_started() -> void:
	if _queued == 0:
		return
	var rider_index := _queued - 1
	_queued = 0
	start_piggyback(chained.balls[rider_index], chained.balls[1 - rider_index])


func _on_level_finished(_counts: Vector2i) -> void:
	_finishing = true
	_end.call_deferred(true)


func _on_players_died(_cause: String) -> void:
	_end(false)


func _exit_tree() -> void:
	if piggyback_active:
		_end(false)
	if not Game.chained_switching:
		Game.chained_piggyback = 0


func _physics_process(delta: float) -> void:
	if not piggyback_active:
		return
	var rider := piggyback_rider
	var carrier := piggyback_carrier
	if not is_instance_valid(rider) or not is_instance_valid(carrier) or rider.dead or carrier.dead:
		_end(_finishing)
		return
	_elapsed += delta
	seconds_left = maxf(0.0, seconds_left - delta)
	if Input.is_action_just_pressed(rider.action_prefix + "jump"):
		carrier.jump_with_charge()
	var rel := _rider_offset(rider, carrier, delta)
	var carrier_vel: Vector2 = PhysicsServer2D.body_get_state(carrier.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	rider.carry_to(carrier.global_position + rel, carrier_vel)
	if seconds_left <= 0.0:
		_end(true)


func _rider_offset(rider: Ball, carrier: Ball, delta: float) -> Vector2:
	var want := _head_height(carrier, rider)
	var cap := _ceiling_cap(carrier, rider, want)
	_lift = minf(cap, move_toward(_lift, want, RISE_SPEED * delta))
	var final := Vector2(0.0, -_lift)
	if _elapsed >= MOUNT_TIME:
		return final
	var t := _elapsed / MOUNT_TIME
	var e := t * t * (3.0 - 2.0 * t)
	return _mount_from.lerp(final, e) + Vector2(0.0, -sin(PI * t) * MOUNT_ARC)


func _head_height(carrier: Ball, rider: Ball) -> float:
	return HEAD_REACH * carrier.size_factor + rider.radius - SIT_OVERLAP


func _ceiling_cap(carrier: Ball, rider: Ball, want: float) -> float:
	var probe_r := rider.radius * 0.8
	var head := HEAD_REACH * rider.size_factor
	var travel := want + head - probe_r
	if travel <= 0.0:
		return want
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _probe_shape(probe_r)
	params.transform = Transform2D(0.0, carrier.global_position)
	params.motion = Vector2(0.0, -travel)
	params.collision_mask = WORLD_MASK
	var result := get_world_2d().direct_space_state.cast_motion(params)
	if result.size() < 2 or result[0] >= 1.0:
		return want
	return clampf(result[0] * travel + probe_r - head, 0.0, want)


func _probe_shape(r: float) -> CircleShape2D:
	if _probe == null:
		_probe = CircleShape2D.new()
	_probe.radius = r
	return _probe


func _hop_start(side: int) -> Vector2:
	var carrier := piggyback_carrier
	var rider := piggyback_rider
	return carrier.global_position + Vector2(side * (carrier.radius + rider.radius * 0.75), -(carrier.radius + rider.radius * 2.2))


func _pick_hop_side() -> int:
	var first: int = piggyback_carrier.facing if piggyback_carrier.facing != 0 else 1
	var p_first := _hop_penalty(first)
	var p_other := _hop_penalty(-first)
	if p_other < p_first:
		return -first
	return first


func _hop_penalty(side: int) -> float:
	var carrier := piggyback_carrier
	var rider := piggyback_rider
	var start := _hop_start(side)
	var penalty := 0.0
	if _solid_at(start, rider.radius * 0.9):
		penalty += 500.0
	for dist: float in HOP_SAMPLES:
		var x := carrier.global_position.x + side * dist
		if _solid_at(Vector2(x, start.y), 10.0):
			penalty += 40.0
			continue
		var query := PhysicsRayQueryParameters2D.create(Vector2(x, start.y), Vector2(x, start.y + 420.0), WORLD_MASK)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			penalty += 1000.0
			continue
		var point: Vector2 = hit["position"]
		if point.y - carrier.global_position.y > SAFE_DROP:
			penalty += 200.0
		if _hazard_near(point):
			penalty += 300.0
	return penalty


func _solid_at(pos: Vector2, r: float) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _probe_shape(r)
	params.transform = Transform2D(0.0, pos)
	params.collision_mask = WORLD_MASK
	return not get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


func _hazard_near(point: Vector2) -> bool:
	var level := chained.level
	if level == null:
		return false
	var col := int(floor(point.x / Level.TILE))
	var row := int(floor(point.y / Level.TILE)) - 1
	for r in [row, row - 1]:
		for c in [col - 1, col, col + 1]:
			if HAZARD_CHARS.contains(level.char_at(r, c)):
				return true
	return false


func _make_banner() -> void:
	_free_banner()
	_layer = CanvasLayer.new()
	add_child(_layer)
	_banner = Banner.new()
	_banner.pb = self
	_layer.add_child(_banner)


func _free_banner() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
		_banner = null


func _process(_delta: float) -> void:
	queue_redraw()
	if _banner != null:
		_banner.queue_redraw()


static func _get_font() -> Font:
	if _font == null:
		_font = UiTheme.main_font()
	return _font


func _draw() -> void:
	if not piggyback_active or not is_instance_valid(piggyback_rider) or not is_instance_valid(piggyback_carrier):
		return
	var rider := piggyback_rider
	var carrier := piggyback_carrier
	var t := _elapsed
	var top := rider.global_position + Vector2(0.0, -HEAD_REACH * rider.size_factor)
	var bob := sin(t * 9.0) * 2.0
	PixelArt.draw_centered(self, PixelArt.CROWN, (top + Vector2(0.0, -9.0 + bob)).snapped(Vector2(2.0, 2.0)), 3.0)
	var cheer := "WHEEE!" if carrier.linear_velocity.y < -120.0 else "WHEE!"
	var font := _get_font()
	var text_pos := (top + Vector2(-60.0 + sin(t * 6.0) * 3.0, -26.0 + bob)).snapped(Vector2(2.0, 2.0))
	draw_string_outline(font, text_pos, cheer, HORIZONTAL_ALIGNMENT_CENTER, 120.0, UiTheme.FONT_SMALL, 6, Color("#05080c"))
	draw_string(font, text_pos, cheer, HORIZONTAL_ALIGNMENT_CENTER, 120.0, UiTheme.FONT_SMALL, Color("#ffe27a"))
	var drops := 4 if carrier.charge_dir != 0 else 2
	for i in drops:
		var phase := fposmod(t * 1.7 + i * 0.27, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := carrier.global_position + Vector2(side * (21.0 + phase * 8.0), -34.0 + phase * 26.0) * carrier.size_factor
		PixelArt.draw_centered(self, SWEAT, p.snapped(Vector2(2.0, 2.0)), 3.0, Color(1.0, 1.0, 1.0, 1.0 - phase * phase))


class Banner extends Control:
	const BOX := Vector2(440, 62)
	const TOP := 82.0

	var pb: ChainedPiggyback
	var _frame: StyleBoxTexture

	func _ready() -> void:
		theme = UiTheme.make()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_frame = UiTheme.frame(UiTheme.FRAME_NORMAL, 0, 0)

	func _draw() -> void:
		if pb == null or not pb.piggyback_active or not is_instance_valid(pb.piggyback_rider) or not is_instance_valid(pb.piggyback_carrier):
			return
		var font := get_theme_default_font()
		var box := Rect2(Vector2(size.x / 2.0 - BOX.x / 2.0, TOP), BOX)
		draw_style_box(_frame, box)
		var rider_id := pb.piggyback_rider.player_id
		var carrier_id := pb.piggyback_carrier.player_id
		var col: Color = ChainedHud.PLAYER_COLORS[carrier_id - 1] if carrier_id == 1 or carrier_id == 2 else UiTheme.ACCENT
		var title := "P%d CARRIES P%d!" % [carrier_id, rider_id]
		draw_string_outline(font, Vector2(box.position.x, box.position.y + 30), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_MEDIUM, 8, Color.BLACK)
		draw_string(font, Vector2(box.position.x, box.position.y + 30), title, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_MEDIUM, col.lightened(0.25))
		var fraction := clampf(pb.seconds_left / pb.duration, 0.0, 1.0)
		var bar := Rect2(Vector2(box.position.x + 40, box.position.y + 40), Vector2(box.size.x - 80, 8))
		draw_rect(bar.grow(2), Color("#05080c"))
		var flash := fraction > 0.25 or int(pb._elapsed * 6.0) % 2 == 0
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), UiTheme.ACCENT if flash else Color.WHITE)
		if pb._elapsed < HINT_DELAY:
			return
		var rider_keys: Array = KEY_TEXT.get(pb.piggyback_rider.action_prefix, ["", ""])
		var carrier_keys: Array = KEY_TEXT.get(pb.piggyback_carrier.action_prefix, ["", ""])
		var hint := "P%d JUMPS (%s)    P%d TILTS (%s)" % [rider_id, rider_keys[1], carrier_id, carrier_keys[0]]
		draw_string_outline(font, Vector2(box.position.x, box.end.y + 18), hint, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_SMALL, 6, Color.BLACK)
		draw_string(font, Vector2(box.position.x, box.end.y + 18), hint, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, UiTheme.FONT_SMALL, UiTheme.TEXT)
