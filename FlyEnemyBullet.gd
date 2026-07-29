extends Area2D

# 飞行小丑无人机能量子弹 (FlyEnemy Bullet)

var speed = 230.0
var direction = Vector2.DOWN
var lifetime = 3.0
var deflected = false  # 是否被近战弹反（改变视觉颜色）

func _ready():
	add_to_group("enemy_projectiles")
	collision_layer = 1
	collision_mask = 1
	# 添加圆形碰撞体（需要碰撞体 Area2D 才能检测 `body_entered` 信号）
	var shape = CircleShape2D.new()
	shape.radius = 6.0
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)

func hit_by_batarang():
	_spawn_burst()
	queue_free()

func deflect():
	"""被近战弹反：反弹回敌人方向"""
	direction *= -1.0
	# 弹反后变为友方蓝色，不再伤害玩家
	collision_mask = 0
	lifetime = 1.5
	# 视觉变色：弹反后变青蓝色
	queue_redraw()
	# 调整绘制颜色（通过画图属性不好立即改，加个标记用 _draw）
	deflected = true

func _physics_process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _draw():
	if deflected:
		# 弹反后：青蓝色友方弹幕
		draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.85, 1.0, 0.4))
		draw_circle(Vector2.ZERO, 4.0, Color(0.6, 1.0, 1.0))
		draw_rect(Rect2(-2, -2, 4, 4), Color(1.0, 1.0, 0.9))
	else:
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
