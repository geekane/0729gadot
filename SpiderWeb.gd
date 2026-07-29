extends Area2D

# 蜘蛛网弹幕 (Spider Web Projectile)
# 沿 Vector2 单位向量直指蝙蝠侠当前位置飞行，击中玩家时减速，支持近战弹反

const SPEED = 220.0
const MAX_LIFETIME = 4.0

var fly_direction = Vector2(-1.0, 0.0)  # 🎯 视线瞄准单位向量
var lifetime = 0.0
var deflected = false

func _ready():
	add_to_group("enemy_projectiles")
	collision_layer = 0
	collision_mask = 1  # 只检测玩家（层1）
	monitoring = true
	monitorable = false
	
	# 圆形碰撞体
	var shape = CircleShape2D.new()
	shape.radius = 7.0
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	lifetime += delta
	if lifetime > MAX_LIFETIME:
		_fade_out()
		return
	
	position += fly_direction * SPEED * delta
	queue_redraw()

func _draw():
	"""绘制蛛网：半透明白色圆形 + 辐射线"""
	var alpha = 1.0 if not deflected else 0.6
	var web_color = Color(0.85, 0.85, 0.92, 0.6 * alpha)
	var web_bright = Color(0.95, 0.95, 1.0, 0.8 * alpha)
	var web_dim = Color(0.7, 0.7, 0.8, 0.3 * alpha)
	
	# 外圈
	draw_circle(Vector2.ZERO, 7.0, web_dim)
	draw_circle(Vector2.ZERO, 5.0, web_color)
	draw_circle(Vector2.ZERO, 3.0, web_bright)
	
	# 辐射蛛丝线
	for i in range(6):
		var angle = float(i) / 6.0 * PI * 2.0 + lifetime * 2.0
		var outer = Vector2(cos(angle), sin(angle)) * 7.0
		draw_line(Vector2.ZERO, outer, web_color, 1.0)
	
	# 螺旋蛛丝 (装饰)
	var spiral_color = Color(0.9, 0.9, 0.95, 0.5 * alpha)
	for i in range(3):
		var t = float(i + 1) / 4.0
		var r = t * 7.0
		var ang = lifetime * 3.0 + float(i) * PI * 0.5
		draw_circle(Vector2(cos(ang), sin(ang)) * r, 1.0, spiral_color)

func _on_area_entered(area):
	if deflected:
		return
	if area.is_in_group("enemies"):
		_hit_enemy(area)

func _on_body_entered(body):
	if deflected:
		return
	if body.is_in_group("player"):
		_hit_player(body)

func _hit_player(player):
	"""击中玩家：减速"""
	if player.has_method("apply_web_slow"):
		player.apply_web_slow(1.5)
	_destroy()

func _hit_enemy(enemy):
	"""弹反后击中敌人"""
	if enemy.has_method("hit_by_batarang"):
		enemy.hit_by_batarang()
	_destroy()

func deflect():
	"""近战弹反：反向飞回"""
	fly_direction *= -1.0
	deflected = true
	collision_mask = 0  # 不再伤害玩家
	modulate = Color(0.4, 0.9, 1.0)  # 青蓝友方色

func _fade_out():
	"""渐隐消失"""
	set_physics_process(false)
	monitoring = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)

func _destroy():
	set_physics_process(false)
	monitoring = false
	
	# 爆裂粒子
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(0.8, 0.8, 0.9))
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
