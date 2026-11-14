extends Node2D

const BALL_SCENE := preload("res://scenes/ball.tscn")
const LIVES := 3
const RESPAWN_DELAY := 0.8
const FALL_MARGIN := 160.0

@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD/Hud

var level: Level
var ball: Ball
var lives := LIVES
var stars := 0
var respawn_position := Vector2.ZERO
var _busy := false


func _ready() -> void:
	var data: Dictionary = LevelData.LEVELS[Game.level_index]
	level = Level.new()
	add_child(level)
	move_child(level, 0)
	level.build(data["map"])

	ball = BALL_SCENE.instantiate()
	ball.position = level.start_position
	level.add_child(ball)
	respawn_position = level.start_position

	ball.hurt.connect(_on_ball_hurt)
	level.star_collected.connect(_on_star)
	level.checkpoint_reached.connect(func(pos: Vector2) -> void: respawn_position = pos)
	level.finished.connect(_on_finished)

	camera.limit_left = 0
	camera.limit_top = mini(-int(TILE_MARGIN), int(level.size.y) - 720)
	camera.limit_right = int(level.size.x)
	camera.limit_bottom = int(level.size.y)
	camera.global_position = ball.global_position
	camera.reset_smoothing()

	hud.setup(data["name"], LIVES, level.star_total)
	hud.next_pressed.connect(_on_next)
	hud.retry_pressed.connect(func() -> void: Game.start_level(Game.level_index))
	hud.menu_pressed.connect(Game.go_to_menu)
	hud.watch_ball(ball)
	hud.watch_level(level)
	level.heart_collected.connect(_on_heart)

const TILE_MARGIN := 64.0


func _physics_process(_delta: float) -> void:
	if not ball.dead:
		camera.global_position = ball.global_position + Vector2(ball.linear_velocity.x * 0.25, -40)
		if ball.global_position.y > level.size.y + FALL_MARGIN:
			_on_ball_hurt()
	if Input.is_action_just_pressed("restart") and not _busy:
		_on_ball_hurt()
	if Input.is_action_just_pressed("back"):
		Game.go_to_menu()


func _on_ball_hurt() -> void:
	if _busy:
		return
	_busy = true
	lives -= 1
	hud.set_lives(lives)
	_pop_effect(ball.global_position)
	ball.dead = true
	ball.hide()
	ball.teleport(respawn_position)
	if lives <= 0:
		hud.show_message("Out of lives! Restarting...")
		await get_tree().create_timer(1.4).timeout
		Game.start_level(Game.level_index)
		return
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	ball.teleport(respawn_position)
	level.reset_crates()
	camera.global_position = respawn_position
	ball.dead = false
	ball.invuln = 1.0
	ball.show()
	_busy = false


func _on_heart() -> void:
	lives = mini(LIVES, lives + 1)
	hud.set_lives(lives)


func _on_star() -> void:
	stars += 1
	hud.set_stars(stars)


func _on_finished() -> void:
	if _busy:
		return
	_busy = true
	ball.dead = true
	Game.record_stars(Game.level_index, stars)
	var has_next := Game.level_index + 1 < LevelData.LEVELS.size()
	hud.show_complete(stars, level.star_total, has_next)


func _on_next() -> void:
	if not Game.next_level():
		Game.go_to_menu()


func _pop_effect(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color("#ffb020")
	p.position = pos
	level.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
