extends Area2D

# 飞行敌人：小丑无人机 (Joker Drone)
const SPEED = 110.0
var patrol_range = 160.0

var direction = 1
var start_pos = Vector2.ZERO
var alive = true
var anim_time = 0.0

const STEPS = 12
static var UNIT_CIRCLE: PackedVector2Array = []

static func _static_init():
	UNIT_CIRCLE = PackedVector2Array()
	for i in range(STEPS):
		var angle = i * 2.0 * PI / STEPS
		UNIT_CIRCLE.append(Vector2(cos(angle), sin(angle)))

func _ready():
	add_to_group("enemies")
	start_pos = position
	collision_mask = 1  # 检测玩家图层
	
	# 碰撞体 (圆形浮空)
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta):
	if not alive:
		return
		
	anim_time += delta * 6.0
	
	# 水平往复 + 垂直波浪运动
	position.x += SPEED * direction * delta
	position.y = start_pos.y + sin(anim_time * 0.8) * 18.0
	
	if position.x >= start_pos.x + patrol_range:
		direction = -1
		queue_redraw()
	elif position.x <= start_pos.x - patrol_range:
		direction = 1
		queue_redraw()
		
	# 控制动画重绘频率
	queue_redraw()

func _draw():
	if not alive:
		return
		
	var flip = 1.0 if direction > 0 else -1.0
	
	# 1. 顶部旋转螺旋桨 blades
	var blade_w = sin(anim_time * 4.0) * 18.0
	draw_line(Vector2(-blade_w, -14), Vector2(blade_w, -14), Color(0.8, 0.8, 0.85, 0.9), 2.5)
	draw_line(Vector2(0, -14), Vector2(0, -10), Color(0.3, 0.3, 0.35), 2.0)
	
	# 2. 小丑无人机球形紫暗色机身
	draw_circle(Vector2.ZERO, 14.0, Color(0.35, 0.12, 0.38))
	draw_circle(Vector2.ZERO, 11.0, Color(0.5, 0.15, 0.55))
	
	# 3. 紫红色机械单眼
	var eye_offset = Vector2(4.0 * flip, -1.0)
	draw_circle(eye_offset, 5.5, Color(0.1, 0.05, 0.15))
	draw_circle(eye_offset, 3.5, Color(1.0, 0.2, 0.25))
	draw_circle(eye_offset + Vector2(1.0 * flip, -1.0), 1.2, Color.WHITE) # 单眼高光
	
	# 4. 底部小丑尖角下巴
	var jaw_pts = PackedVector2Array([
		Vector2(-6, 8), Vector2(0, 15), Vector2(6, 8)
	])
	draw_polygon(jaw_pts, PackedColorArray([Color(0.85, 0.15, 0.2)]))

func _on_body_entered(body):
	if not alive:
		return
	if body.is_in_group("player"):
		var player_bottom = body.position.y + 18
		var prev_player_bottom = body.prev_position_y + 18
		var drone_top = position.y - 14
		
		# 踩头判定：从上方落向无人机
		var stomp_from_fall = body.velocity.y >= 0 and player_bottom <= drone_top + 16
		var stomp_from_above = prev_player_bottom <= drone_top + 4
		
		if stomp_from_fall or stomp_from_above:
			body.velocity.y = -400.0  # 弹跳更高
			var game = get_tree().current_scene
			if game and game.has_method("_on_enemy_stomped"):
				game._on_enemy_stomped(self)
			stomp()
		else:
			var game = get_tree().current_scene
			if game and game.has_method("_on_player_hit"):
				game._on_player_hit(body)

func stomp():
	alive = false
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	queue_redraw()
	
	# 爆炸掉落销毁动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.3, 0.2), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(func(): hide(); queue_free())

func hit_by_batarang():
	if not alive:
		return
	alive = false
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
			
	var game = get_tree().current_scene
	if game and game.has_method("_on_enemy_stomped"):
		game._on_enemy_stomped(self)
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func(): hide(); queue_free())
