extends AnimatableBody2D

# 动态移动单向平台节点 (Moving One-Way Platform - AnimatableBody2D)
var move_distance = 140.0
var move_speed = 1.8
var is_vertical = false

var start_pos = Vector2.ZERO
var time_counter = 0.0
var width = 120.0
var height = 16.0

func _ready():
	sync_to_physics = true  # 开启物理同步，使 CharacterBody2D 能完美跟随左右移动与上下升降
	collision_layer = 2     # 单向平台物理图层
	collision_mask = 0      # 不检测其他物体，避免干扰
	start_pos = position
	
	# 碰撞体：必须 one_way_collision 让玩家从下方穿过
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	var col = CollisionShape2D.new()
	col.shape = shape
	col.one_way_collision = true
	col.one_way_collision_margin = 4.0  # 给 4px 容差，防止高速移动时脱离平台
	add_child(col)
	queue_redraw()

func _draw():
	# 🎨 蝙蝠战术科技金蓝悬浮平台 (Batman Tech Golden-Navy Floating Platform)
	var hw = width / 2.0
	var hh = height / 2.0
	
	# 1. 底层深钢蓝主体框架 (Dark Steel Navy Body)
	var body_rect = Rect2(-hw, -hh, width, height)
	draw_rect(body_rect, Color(0.14, 0.18, 0.32), true)
	
	# 2. 金黄色防滑警示边框 (Tactical Gold Edge)
	draw_rect(body_rect, Color(1.0, 0.85, 0.2), false, 2.0)
	
	# 3. 顶部强力天蓝荧光防滑面 (High-Visibility Cyan Top Edge)
	draw_line(Vector2(-hw, -hh), Vector2(hw, -hh), Color(0.3, 0.92, 1.0), 3.0)
	
	# 4. 顶面金色战术警示斜纹
	var stripe_count = 5
	var step_x = width / (stripe_count + 1)
	for i in range(stripe_count):
		var sx = -hw + (i + 1) * step_x
		draw_line(Vector2(sx - 4, -hh + 3), Vector2(sx + 4, -hh + 7), Color(1.0, 0.85, 0.2, 0.9), 2.0)
		
	# 5. 底部两侧天蓝离子推进喷气核 (Dual Cyan Energy Thrusters)
	var left_thruster = Vector2(-hw + 14, hh + 2)
	var right_thruster = Vector2(hw - 14, hh + 2)
	draw_circle(left_thruster, 4.0, Color(0.2, 0.9, 1.0, 0.9))
	draw_circle(left_thruster, 2.0, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(right_thruster, 4.0, Color(0.2, 0.9, 1.0, 0.9))
	draw_circle(right_thruster, 2.0, Color(1.0, 1.0, 1.0, 0.95))

func _physics_process(delta):
	time_counter += delta * move_speed
	var offset = sin(time_counter) * move_distance
	
	# 不直接赋值 position，而是增量移动，让 AnimatableBody2D 正确计算速度矢量
	if is_vertical:
		var target_y = start_pos.y + offset
		position.y = target_y
	else:
		var target_x = start_pos.x + offset
		position.x = target_x
