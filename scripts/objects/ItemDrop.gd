extends Area2D

# 掉落物类型："health" (血瓶恢复) 或 "score" (高分水晶)
var item_type = "health"
var base_y = 0.0
var anim_time = 0.0
var collected = false

var col_shape: CollisionShape2D = null

func _ready():
	add_to_group("items")
	collision_layer = 1
	collision_mask = 1
	
	base_y = position.y
	anim_time = randf_range(0.0, 3.14)
	
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	col_shape = CollisionShape2D.new()
	col_shape.shape = shape
	add_child(col_shape)
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if collected:
		return
		
	# 缓和上下浮动动画 (Bobbing Animation)
	anim_time += delta * 4.0
	position.y = base_y + sin(anim_time) * 4.0
	queue_redraw()
	
	# 双重安全防护：碰撞体主动检测重叠 Body
	var bodies = get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("player"):
			_collect(b)
			return

func _on_body_entered(body):
	if collected:
		return
	if body.is_in_group("player"):
		_collect(body)

func _collect(player):
	if collected:
		return
	collected = true
	
	if col_shape and is_instance_valid(col_shape):
		col_shape.set_deferred("disabled", true)
		
	var game = get_tree().current_scene
	if item_type == "health":
		# 恢复生命值
		if game and "lives" in game:
			game.lives = min(game.lives + 1, 3)
			if game.has_method("_update_lives_hud"):
				game._update_lives_hud()
			if game.has_method("_spawn_floating_text"):
				game._spawn_floating_text(global_position + Vector2(0, -20), "+1 ❤️ RECOVER!", Color(1.0, 0.2, 0.3))
			if game.has_method("_spawn_particle_burst"):
				game._spawn_particle_burst(global_position, Color(1.0, 0.3, 0.4))
	else:
		# 获得高分奖励 (+500 pts)
		if game and "score" in game:
			game.score += 500
			if game.has_method("_update_score_hud"):
				game._update_score_hud()
			if game.has_method("_spawn_floating_text"):
				game._spawn_floating_text(global_position + Vector2(0, -20), "+500 💎 BONUS!", Color(0.3, 0.95, 1.0))
			if game.has_method("_spawn_particle_burst"):
				game._spawn_particle_burst(global_position, Color(0.3, 0.95, 1.0))

	# 拾取上升淡出动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30.0, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(func(): queue_free())

func _draw():
	if collected:
		return
		
	# 绘制亮丽浮动掉落物像素外廓
	if item_type == "health":
		# 恢复血瓶：暗红外圈 + 亮红红心 + 闪耀白光
		draw_circle(Vector2.ZERO, 13.0, Color(0.9, 0.15, 0.25, 0.95))
		draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.3, 0.4, 0.95))
		
		# 红心 Icon
		var pts = PackedVector2Array([
			Vector2(0, 5), Vector2(-6, -1), Vector2(-6, -5), Vector2(-3, -7),
			Vector2(0, -4), Vector2(3, -7), Vector2(6, -5), Vector2(6, -1)
		])
		draw_polygon(pts, PackedColorArray([Color(1.0, 1.0, 1.0, 0.95)]))
		draw_circle(Vector2(-2, -3), 2.0, Color(1.0, 1.0, 1.0, 0.9))
	else:
		# 高分宝石：青蓝高光菱形
		var pts = PackedVector2Array([
			Vector2(0, -12), Vector2(10, 0), Vector2(0, 12), Vector2(-10, 0)
		])
		draw_polygon(pts, PackedColorArray([Color(0.2, 0.9, 1.0, 0.95)]))
		draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.9), 1.5)
		draw_circle(Vector2(-2, -3), 3.0, Color(1.0, 1.0, 1.0, 0.95))
