extends Area2D

# 地刺陷阱节点 (Spike Hazard)
var spike_width = 40.0
var spike_height = 20.0
var spike_count = 3

func _ready():
	add_to_group("hazards")
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	# 碰撞体
	var shape = RectangleShape2D.new()
	shape.size = Vector2(spike_width, spike_height * 0.8)
	var col = CollisionShape2D.new()
	col.shape = shape
	# 偏移到地刺中心
	col.position = Vector2(0, -spike_height * 0.4)
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _draw():
	# 矢量绘制锯齿尖刺金属阵列
	var start_x = -spike_width / 2.0
	var single_w = spike_width / float(spike_count)
	
	for i in range(spike_count):
		var x1 = start_x + i * single_w
		var x2 = x1 + single_w / 2.0
		var x3 = x1 + single_w
		
		# 金属阴影底座
		var shadow_triangle = PackedVector2Array([
			Vector2(x1, 0), Vector2(x2, -spike_height), Vector2(x3, 0)
		])
		draw_polygon(shadow_triangle, PackedColorArray([Color(0.2, 0.22, 0.28)]))
		
		# 高光主体
		var main_triangle = PackedVector2Array([
			Vector2(x1 + 1.0, 0), Vector2(x2, -spike_height + 2.0), Vector2(x3 - 1.0, 0)
		])
		draw_polygon(main_triangle, PackedColorArray([Color(0.55, 0.6, 0.68)]))
		
		# 尖端危险红光提示
		draw_line(Vector2(x2 - 1.0, -spike_height + 3.0), Vector2(x2, -spike_height + 1.0), Color(0.9, 0.2, 0.2), 2.0)

func _on_body_entered(body):
	if body.is_in_group("player"):
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)
