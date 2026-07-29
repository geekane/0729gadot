extends Area2D

# 飞行小丑无人机能量子弹 (FlyEnemy Bullet)

var speed = 230.0
var direction = Vector2.DOWN
var lifetime = 3.0

func _ready():
	collision_layer = 1
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _draw():
	# 绘制发光红橙色能量子弹
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.25, 0.15, 0.4))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.2))
	draw_rect(Rect2(-2, -2, 4, 4), Color(1.0, 0.95, 0.8))

func _on_body_entered(body):
	if body.is_in_group("player"):
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)
		_spawn_burst()
		queue_free()

func _spawn_burst():
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(1.0, 0.3, 0.1))
