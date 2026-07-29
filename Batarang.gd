extends Area2D

# 蝙蝠飞镖 (Batarang Projectile)
# 高速飞行、纯矢量绘制自旋双翼蝙蝠镖，击中敌人时触发爆裂并消除敌人

const SPEED = 650.0
const MAX_RANGE = 550.0

var direction = 1.0  # 1.0 = 向右, -1.0 = 向左
var distance_traveled = 0.0
var rotation_angle = 0.0

func _ready():
	add_to_group("batarangs")
	collision_layer = 0   # 不主动阻挡其他物体
	collision_mask = 1    # 碰撞检测 Layer 1 上的敌人/地面
	monitoring = true
	monitorable = false
	
	# 碰撞体 (20x12 椭圆/矩形)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 12)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta):
	var move_amount = SPEED * delta
	position.x += direction * move_amount
	distance_traveled += move_amount
	
	# 自旋动画 (35 rad/s)
	rotation_angle += 35.0 * delta * direction
	queue_redraw()
	
	# 超过最大射程自动隐去
	if distance_traveled >= MAX_RANGE:
		_destroy_with_effect(false)

func _draw():
	# 绘制旋转状态下的蝙蝠飞镖 (Rotated Bat Emblem Batarang)
	draw_set_transform(Vector2.ZERO, rotation_angle, Vector2(1.0, 1.0))
	
	# 蝙蝠镖双翼 (黑色主体)
	var bat_wings = PackedVector2Array([
		Vector2(0, -2), Vector2(4, -7), Vector2(10, -5), Vector2(6, 0),
		Vector2(10, 5), Vector2(4, 7), Vector2(0, 2), Vector2(-4, 7),
		Vector2(-10, 5), Vector2(-6, 0), Vector2(-10, -5), Vector2(-4, -7)
	])
	draw_polygon(bat_wings, PackedColorArray([Color(0.1, 0.12, 0.18)]))
	
	# 金色锋利刃边 (High-Tech Gold Edge)
	var edge_lines = [
		[Vector2(4, -7), Vector2(10, -5)], [Vector2(10, -5), Vector2(6, 0)],
		[Vector2(6, 0), Vector2(10, 5)], [Vector2(-4, -7), Vector2(-10, -5)],
		[Vector2(-10, -5), Vector2(-6, 0)], [Vector2(-6, 0), Vector2(-10, 5)]
	]
	for line in edge_lines:
		draw_line(line[0], line[1], Color(1.0, 0.85, 0.2), 1.5)
		
	# 中心发光蝙蝠头 (Center Bat Head Glow)
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.9, 0.3))

func _on_area_entered(area):
	if area.is_in_group("enemies") or area.is_in_group("fly_enemies") or area.is_in_group("enemy_projectiles"):
		_hit_enemy(area)

func _on_body_entered(body):
	# 击中墙壁/地面
	if body is StaticBody2D and not body.is_in_group("player"):
		_destroy_with_effect(true)

func _hit_enemy(enemy_node):
	var game = get_tree().current_scene
	if enemy_node.has_method("hit_by_batarang"):
		enemy_node.hit_by_batarang(1)
	elif enemy_node.has_method("queue_free"):
		if game and game.has_method("_on_enemy_stomped"):
			game._on_enemy_stomped(enemy_node)
		enemy_node.hide()
		enemy_node.queue_free()
		
	_destroy_with_effect(true)

func _destroy_with_effect(hit_something: bool):
	set_physics_process(false)
	set_deferred("monitoring", false)  # 使用 deferred 避免信号内阻塞
	
	var game = get_tree().current_scene
	if hit_something and game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(position, Color(1.0, 0.85, 0.2))
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
