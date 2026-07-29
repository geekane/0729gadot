extends Area2D

var collected = false
var anim_time = 0.0
var base_y = 0.0
var col_shape: CollisionShape2D = null

const STEPS = 16
static var UNIT_CIRCLE: PackedVector2Array = []

static func _static_init():
	UNIT_CIRCLE = PackedVector2Array()
	for i in range(STEPS):
		var angle = i * 2.0 * PI / STEPS
		UNIT_CIRCLE.append(Vector2(cos(angle), sin(angle)))

func _ready():
	add_to_group("coins")
	collision_layer = 1
	collision_mask = 1  # 检测玩家所在图层 (Layer 1)
	monitoring = true
	monitorable = true
	base_y = position.y
	# 随机打乱初始动画相位
	anim_time = randf() * 6.28
	
	# 碰撞体（扩大幅值至 16px 确保碰撞灵敏度）
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	col_shape = CollisionShape2D.new()
	col_shape.shape = shape
	add_child(col_shape)
	
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta):
	if collected:
		return
	anim_time += delta * 4.0
	# 物理帧驱动金币上下浮动 (Bobbing)，确保 Physics Server 碰撞体同步
	position.y = base_y + sin(anim_time) * 3.5
	
	# 重绘控制：低频刷新，减少 Process 开销
	queue_redraw()
		
	# 双重防漏判定：在物理帧检测重叠对象，防止高速移动下错过信号
	var bodies = get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("player"):
			_collect(b)
			return

func _draw():
	if collected:
		return
	# 旋转拉伸系数 (绝对值正向，防止多边形顶角反转)
	var abs_scale_x = clamp(abs(cos(anim_time * 0.75)), 0.2, 1.0)
	
	# 外围黄色日光光晕
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.9, 0.2, 0.25))
	
	# 金币本体
	var outer_w = 11.0 * abs_scale_x
	var inner_w = 8.0 * abs_scale_x
	
	# 暗色外边框
	_draw_ellipse_fast(Vector2.ZERO, outer_w, 11.0, Color(0.85, 0.6, 0.0))
	# 主体金色
	_draw_ellipse_fast(Vector2.ZERO, max(outer_w - 1.0, 1.0), 10.0, Color(1.0, 0.84, 0.0))
	# 内部暗槽
	_draw_ellipse_fast(Vector2.ZERO, inner_w, 8.0, Color(0.9, 0.7, 0.1))
	# 核心高光星芒
	_draw_ellipse_fast(Vector2.ZERO, max(3.5 * abs_scale_x, 1.0), 4.0, Color(1.0, 1.0, 0.85))

func _draw_ellipse_fast(pos: Vector2, rx: float, ry: float, color: Color):
	rx = max(abs(rx), 1.0)
	ry = max(abs(ry), 1.0)
	var points = PackedVector2Array()
	points.resize(STEPS)
	for i in range(STEPS):
		var p = UNIT_CIRCLE[i]
		points[i] = pos + Vector2(p.x * rx, p.y * ry)
	draw_polygon(points, PackedColorArray([color]))

func _on_body_entered(body):
	if body.is_in_group("player"):
		_collect(body)

func _collect(body):
	if collected:
		return
	collected = true
	
	# 立即安全禁用碰撞体，防止二次触发
	if col_shape and is_instance_valid(col_shape):
		col_shape.set_deferred("disabled", true)
	
	var game = get_tree().current_scene
	if game and game.has_method("_on_coin_collected"):
		game._on_coin_collected(self)
	
	# 收集动画：放大、向上飞出并淡出
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30.0, 0.22)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(func(): queue_free())
