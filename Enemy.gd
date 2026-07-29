extends Area2D

const SPEED = 70.0
var patrol_range = 100.0

var direction = -1
var start_x = 0.0
var alive = true
var anim_timer = 0.0

const STEPS = 12
static var UNIT_CIRCLE: PackedVector2Array = []

static func _static_init():
	UNIT_CIRCLE = PackedVector2Array()
	for i in range(STEPS):
		var angle = i * 2.0 * PI / STEPS
		UNIT_CIRCLE.append(Vector2(cos(angle), sin(angle)))

func _ready():
	add_to_group("enemies")
	start_x = position.x
	collision_mask = 1  # 检测玩家所在图层
	# 碰撞体
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 24)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _draw():
	if not alive:
		return
	
	# 阴影
	draw_ellipse_fast(Vector2(0, 10), 14.0, 4.0, Color(0, 0, 0, 0.25))
	
	# 身体（圆角红头菇怪物外观）
	draw_rect(Rect2(-14, -10, 28, 20), Color(0.9, 0.2, 0.15))
	draw_circle(Vector2(0, -10), 14, Color(0.9, 0.2, 0.15))
	
	# 背后刺角
	var flip = 1.0 if direction > 0 else -1.0
	draw_rect(Rect2(-16 * flip, -4, 5, 5), Color(0.6, 0.1, 0.05))
	
	# 大白眼眶
	draw_circle(Vector2(-5, -4), 4.5, Color.WHITE)
	draw_circle(Vector2(5, -4), 4.5, Color.WHITE)
	
	# 黑瞳孔（随移动方向注视）
	var eye_offset = 2.0 * flip
	draw_circle(Vector2(-5 + eye_offset, -4), 2.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(5 + eye_offset, -4), 2.0, Color(0.1, 0.1, 0.1))
	
	# 愤怒小眉毛
	draw_line(Vector2(-9, -10), Vector2(-2, -7), Color(0.3, 0.05, 0.0), 2.0)
	draw_line(Vector2(9, -10), Vector2(2, -7), Color(0.3, 0.05, 0.0), 2.0)

func draw_ellipse_fast(pos: Vector2, rx: float, ry: float, color: Color):
	rx = max(abs(rx), 1.0)
	ry = max(abs(ry), 1.0)
	var points = PackedVector2Array()
	points.resize(STEPS)
	for i in range(STEPS):
		var p = UNIT_CIRCLE[i]
		points[i] = pos + Vector2(p.x * rx, p.y * ry)
	draw_polygon(points, PackedColorArray([color]))

func _physics_process(delta):
	if not alive:
		return
	position.x += SPEED * direction * delta
	
	var changed_dir = false
	if position.x >= start_x + patrol_range:
		direction = -1
		changed_dir = true
	elif position.x <= start_x - patrol_range:
		direction = 1
		changed_dir = true
		
	if changed_dir:
		queue_redraw()

func _on_body_entered(body):
	if not alive:
		return
	if body.is_in_group("player"):
		var player_bottom = body.position.y + 18       # 玩家碰撞体底部
		var prev_player_bottom = body.prev_position_y + 18  # 玩家上一帧底部
		var enemy_top = position.y - 12                # 敌人碰撞体顶部
		
		# 踩头判定：
		#   a) 玩家正下落（velocity.y >= 0）且底部在敌人顶部之上（容差16px）
		#   b) 玩家上一帧在敌人顶部附近
		var stomp_from_fall = body.velocity.y >= 0 and player_bottom <= enemy_top + 16
		var stomp_from_above = prev_player_bottom <= enemy_top + 4
		
		if stomp_from_fall or stomp_from_above:
			body.velocity.y = -380  # 弹跳更高
			var game = get_tree().current_scene
			if game and game.has_method("_on_enemy_stomped"):
				game._on_enemy_stomped(self)
			stomp()
		else:
			var game = get_tree().current_scene
			if game and game.has_method("_on_player_hit"):
				game._on_player_hit(body)

func stomp():
	"""玩家踩到敌人头顶"""
	alive = false
	# 延时安全禁用物理碰撞，避免物理刷新警告
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	queue_redraw()
	
	# 压扁 + 消失动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 0.15), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "modulate", Color(0.5, 0.2, 0.05), 0.2)
	tween.chain().tween_callback(func(): queue_free())
