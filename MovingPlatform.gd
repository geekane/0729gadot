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
	
	# 视觉结构
	var vis = ColorRect.new()
	vis.color = Color(0.22, 0.35, 0.52) # 蓝灰色哥谭科技风格
	vis.size = Vector2(width, height)
	vis.position = Vector2(-width / 2.0, -height / 2.0)
	add_child(vis)
	
	# 平台顶部防滑光带
	var top_stripe = ColorRect.new()
	top_stripe.color = Color(0.4, 0.8, 1.0)
	top_stripe.size = Vector2(width, 3.0)
	top_stripe.position = Vector2(-width / 2.0, -height / 2.0)
	add_child(top_stripe)

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
