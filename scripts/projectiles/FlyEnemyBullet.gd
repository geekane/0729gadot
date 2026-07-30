extends Area2D

# 飞行小丑无人机能量子弹 (FlyEnemy Bullet)

var speed = 230.0
var direction = Vector2.DOWN
var lifetime = 3.0
var deflected = false  # 是否被近战弹反（改变视觉颜色）

var col_shape: CollisionShape2D = null

func _ready():
	add_to_group("enemy_projectiles")
	collision_layer = 1
	collision_mask = 1
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	col_shape = CollisionShape2D.new()
	col_shape.shape = shape
	add_child(col_shape)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func hit_by_batarang():
	_spawn_burst()
	queue_free()

func deflect():
	"""被近战弹反：反弹回敌人方向，宽容判定+一击必杀！"""
	direction *= -1.0
	speed *= 2.5
	lifetime = 2.0
	deflected = true
	
	# 🎯 极其宽容的 32px 碰撞半径
	if col_shape and col_shape.shape is CircleShape2D:
		col_shape.shape.radius = 32.0
		
	var game = get_tree().current_scene
	if game and game.has_method("add_camera_shake"):
		game.add_camera_shake(12.0, 0.2)
		game._spawn_center_hit_text("DEFLECT")
		
	queue_redraw()

func _physics_process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _draw():
	if deflected:
		# 🎯 弹反后：强烈发光青光大能量团
		draw_circle(Vector2.ZERO, 16.0, Color(0.2, 0.9, 1.0, 0.4))
		draw_circle(Vector2.ZERO, 10.0, Color(0.6, 1.0, 1.0, 0.8))
		draw_rect(Rect2(-5, -5, 10, 10), Color(1.0, 1.0, 0.9))
	else:
		# 绘制发光红橙色能量子弹
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.25, 0.15, 0.4))
		draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.85, 0.2))
		draw_rect(Rect2(-2, -2, 4, 4), Color(1.0, 0.95, 0.8))

func _on_body_entered(body):
	# 弹反后不伤害玩家
	if body.is_in_group("player") and not deflected:
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)
		_spawn_burst()
		queue_free()
	elif deflected and (body.is_in_group("enemies") or body.is_in_group("bosses")):
		_execute_deflect_kill(body)

func _on_area_entered(area):
	# 🎯 弹反后触碰敌人 Area2D 触发一击致命爆炸！
	if deflected:
		if area.is_in_group("enemies") or area.is_in_group("bosses"):
			_execute_deflect_kill(area)

func _execute_deflect_kill(target: Node):
	"""执行反弹子弹一击必杀！"""
	var game = get_tree().current_scene
	if game:
		if game.has_method("add_camera_shake"):
			game.add_camera_shake(16.0, 0.25)
		if game.has_method("_spawn_particle_burst"):
			game._spawn_particle_burst(global_position, Color(0.2, 1.0, 0.9))
			game._spawn_particle_burst(global_position, Color(1.0, 0.8, 0.2))
	
	if target.has_method("_on_stomped"):
		target._on_stomped()
	elif target.has_method("hit_by_batarang"):
		target.hit_by_batarang()
	elif target.has_method("take_damage"):
		target.take_damage(3)
		
	_spawn_burst()
	queue_free()

func _spawn_burst():
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(1.0, 0.3, 0.1))
