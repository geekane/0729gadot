extends Area2D

# 小丑狂笑扑克牌弹幕 (Joker Card Projectile)
# 由 Boss 发射的自旋狂笑扑克牌，飞行方向沿 Vector2 直指蝙蝠侠当前位置！
# 抵消机制：近战斩击 1 次切碎，远程飞镖需要命中 5 次抵消！

const SPEED = 480.0
const MAX_RANGE = 800.0

var fly_direction = Vector2(-1.0, 0.0)  # 🎯 视线瞄准单位向量
var distance_traveled = 0.0
var rotation_angle = 0.0
var hp = 5  # 耐久度 = 5 (需要 5 发远程飞镖或 1 发近战斩击抵消)

func _ready():
	add_to_group("enemy_projectiles")
	collision_layer = 1
	collision_mask = 1  # 检测 Layer 1
	monitoring = true
	monitorable = true
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(18, 24)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta):
	var move_amount = SPEED * delta
	position += fly_direction * move_amount
	distance_traveled += move_amount
	
	rotation_angle += 22.0 * delta
	queue_redraw()
	
	if distance_traveled >= MAX_RANGE:
		_destroy()

func _draw():
	# 绘制扑克牌：主视角旋转 45% 混合指向角与自旋
	draw_set_transform(Vector2.ZERO, rotation_angle + fly_direction.angle(), Vector2(1.0, 1.0))
	
	# 扑克牌白色边框与紫色背景 (Joker Card Frame)
	draw_rect(Rect2(-9, -12, 18, 24), Color(0.95, 0.95, 0.95))
	draw_rect(Rect2(-7, -10, 14, 20), Color(0.4, 0.1, 0.5))
	draw_line(Vector2(-4, -1), Vector2(4, -1), Color(1.0, 0.9, 0.2), 1.5)
	
	# 狂笑红唇 (Joker Smile)
	draw_circle(Vector2(0, 2), 3.5, Color(0.9, 0.1, 0.1))

func _on_body_entered(body):
	if body.is_in_group("player"):
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)
		_destroy()
	elif body is StaticBody2D:
		_destroy()

func hit_by_batarang(damage: int = 1):
	"""被远程蝙蝠飞镖击中 (消耗 1 点耐久，5 发飞镖可抵消扑克牌)"""
	hp -= damage
	
	modulate = Color(3.0, 3.0, 3.0)
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_floating_text"):
		game._spawn_floating_text(global_position, "-1 🎴", Color(1.0, 0.9, 0.2))
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(1.0, 0.85, 0.2))
		
	if hp <= 0:
		slice_destroy()

func slice_destroy():
	"""被玩家右键近战斩击切碎粉碎，或 5 发飞镖抵消粉碎"""
	var parent_world = get_parent()
	if parent_world and parent_world.has_method("_spawn_particle_burst"):
		parent_world._spawn_particle_burst(global_position, Color(1.0, 0.9, 0.2))
		parent_world._spawn_particle_burst(global_position, Color(0.9, 0.1, 0.1))
	_destroy()

func deflect():
	"""已废弃原弹反逻辑：调用 slice_destroy 仅切碎斩灭"""
	slice_destroy()

func _destroy():
	set_physics_process(false)
	set_deferred("monitoring", false)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
