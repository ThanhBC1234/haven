class_name Pickup
extends Area2D

@export_enum("star", "checkpoint", "finish", "trampoline", "heart", "shield", "gun", "jump_boost") var kind := "star"
@export var trampoline_speed := 920.0
@export var gun_ammo := 15
@export var respawn_time := 8.0
@export var show_placeholder := true

const ITEM_TEXTURES := {
	"heart": preload("res://assets/items/heart.png"),
	"shield": preload("res://assets/items/shield.png"),
	"jump_boost": preload("res://assets/items/jump_boost.png"),
}

const CHECKPOINT_HEIGHT := 320.0

var used := false
var _time := 0.0
var _squash := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if kind == "checkpoint":
		var tall := RectangleShape2D.new()
		tall.size = Vector2(32, CHECKPOINT_HEIGHT)
		$Shape.shape = tall
		$Shape.position = Vector2(0, -CHECKPOINT_HEIGHT / 2.0)


func _process(delta: float) -> void:
	_time += delta
	_squash = maxf(0.0, _squash - delta * 4.0)
	if show_placeholder:
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body is Ball or body.dead:
		return
	var level := Level.of(self)
	match kind:
		"star":
			if used:
				return
			used = true
			level.collect_star(body)
			queue_free()
		"checkpoint":
			if used:
				return
			used = true
			level.reach_checkpoint(global_position + Vector2(0, -16))
		"finish":
			if used:
				return
			used = true
			level.finish()
		"trampoline":
			body.bounce_up(trampoline_speed)
			_squash = 1.0
		"heart":
			if used:
				return
			used = true
			level.collect_heart()
			queue_free()
		"shield":
			if used:
				return
			used = true
			body.give_shield()
			queue_free()
		"jump_boost":
			if used:
				return
			used = true
			body.give_jump_boost()
			queue_free()
		"gun":
			if used:
				return
			used = true
			body.add_ammo(gun_ammo)
			hide()
			await get_tree().create_timer(respawn_time).timeout
			if is_inside_tree():
				used = false
				show()


func _draw() -> void:
	if not show_placeholder:
		return
	match kind:
		"star":
			var c := Vector2(0, -16 + sin(_time * 3.0) * 3.0)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 5.0))
			draw_colored_polygon(pts, Color("#ffd23f"))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#b8860b"), 1.0)
		"checkpoint", "finish":
			var pole_h := 56.0 if kind == "finish" else 44.0
			draw_line(Vector2(-8, 0), Vector2(-8, -pole_h), Color("#e8e8e8"), 3.0)
			var flag := Color("#4dd27a") if (used or kind == "finish") else Color("#9aa3b5")
			if kind == "finish":
				flag = Color("#ff5d8f")
			var top := -pole_h
			draw_colored_polygon(PackedVector2Array([Vector2(-7, top), Vector2(14, top + 7), Vector2(-7, top + 14)]), flag)
		"trampoline":
			var h := 10.0 - _squash * 5.0
			draw_rect(Rect2(-14, -4, 28, 4), Color("#555b6e"))
			for x in [-10.0, 0.0, 10.0]:
				draw_line(Vector2(x, -4), Vector2(x, -h), Color("#aab2c5"), 2.0)
			draw_rect(Rect2(-15, -h - 4, 30, 4), Color("#ff6b6b"))
		"heart", "shield", "gun", "jump_boost":
			var c := Vector2(0, -16 + sin(_time * 3.0) * 3.0)
			var glow: Color = {"heart": Color("#e8455a"), "shield": Color("#00a2e8"), "gun": Color("#f7d046"), "jump_boost": Color("#22b14c")}[kind]
			draw_circle(c, 17.0, Color(glow, 0.18 + 0.08 * sin(_time * 5.0)))
			if ITEM_TEXTURES.has(kind):
				draw_texture_rect(ITEM_TEXTURES[kind], Rect2(c - Vector2(16, 16), Vector2(32, 32)), false)
			else:
				PixelArt.draw_centered(self, PixelArt.GUN, c, 3.0)
