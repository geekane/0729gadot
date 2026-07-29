extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -530.0
const GRAVITY = 1100.0
const LEVEL_WIDTH = 1632

var invincible_timer = 0.0
var is_dead = false
var input_disabled = false
# 刚生成时禁止输入，防止开局的 Space 键带到游戏中触发自动跳跃
var just_spawned = true
# 上一帧位置，用于踩怪判定
var prev_position_y = 0.0

# Coyote Time (土狼时间) & Jump Buffer (跳跃预输入)
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# 动态动画变量 (Animation Parameters)
var anim_time = 0.0
var facing_right = true
var col_shape: CollisionShape2D = null

func _ready():
	add_to_group("player")
	# 放大蝙蝠侠角色，使其看起来更加英姿飒爽
	scale = Vector2(1.25, 1.25)
	
	# 碰撞图层：图层1（地面/墙壁）+ 图层2（单向平台）
	collision_mask = 3
	# 单向平台：只从上方站住，可从下方穿过
	platform_floor_layers = 2
	# 碰撞体 (高 36px，中心点 0，底部为 +18)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 36)
	col_shape = CollisionShape2D.new()
	col_shape.shape = shape
	add_child(col_shape)
	queue_redraw()

func _draw():
	# 蝙蝠侠角色矢量姿态与动作动画 (Batman Character Vector Animation)
	var flip = 1.0 if facing_right else -1.0
	var is_moving = abs(velocity.x) > 10.0
	var is_airborne = not is_on_floor()
	
	# 动作动画相位计算
	var leg_swing = sin(anim_time * 16.0) * 5.0 if (is_moving and not is_airborne) else 0.0
	var breath_y = sin(anim_time * 3.5) * 1.0 if (not is_moving and not is_airborne) else 0.0
	var cape_wave = sin(anim_time * 12.0) * 4.0 if is_moving else sin(anim_time * 2.5) * 1.5
	
	# 整体 Y 轴向上向上抬高 9px，确保鞋底正好压在 Y = +18 碰撞底线上，不嵌入地面
	var torso_y = -7 + breath_y
	var leg_y = 7 + breath_y
	var head_y = -16 + breath_y
	
	# 1. 动态蝙蝠斗篷 (Dynamic Bat Cape)
	var cape_color = Color(0.06, 0.06, 0.1)
	var cape_points = PackedVector2Array()
	
	if is_airborne:
		# 空中/跳跃状态：蝙蝠滑翔翼式张开斗篷
		cape_points = PackedVector2Array([
			Vector2(-4 * flip, torso_y - 4),
			Vector2(-26 * flip, torso_y - 6),
			Vector2(-30 * flip, torso_y + 16),
			Vector2(-18 * flip, torso_y + 24),
			Vector2(-6 * flip, torso_y + 18),
			Vector2(4 * flip, torso_y + 8)
		])
	elif is_moving:
		# 奔跑状态：斗篷向后迎风剧烈摆动
		cape_points = PackedVector2Array([
			Vector2(-4 * flip, torso_y - 4),
			Vector2(-20 * flip + cape_wave, torso_y + 4),
			Vector2(-26 * flip + cape_wave, torso_y + 18 + cape_wave),
			Vector2(-14 * flip, torso_y + 20),
			Vector2(-4 * flip, torso_y + 14),
			Vector2(2 * flip, torso_y + 10)
		])
	else:
		# 待机状态：斗篷顺垂背后微动
		cape_points = PackedVector2Array([
			Vector2(-4 * flip, torso_y - 4),
			Vector2(-14 * flip + cape_wave, torso_y + 6),
			Vector2(-18 * flip + cape_wave, torso_y + 22),
			Vector2(-10 * flip, torso_y + 22),
			Vector2(-4 * flip, torso_y + 14),
			Vector2(2 * flip, torso_y + 10)
		])
	draw_polygon(cape_points, PackedColorArray([cape_color]))
	
	# 2. 腿部与暗影战靴 (Legs & Boots - 鞋底精确压在 Y = +18 碰撞底端)
	var left_leg_x = -8 + (leg_swing if not is_airborne else 2.0)
	var right_leg_x = 2 - (leg_swing if not is_airborne else 2.0)
	
	draw_rect(Rect2(left_leg_x, leg_y, 6, 8), Color(0.15, 0.16, 0.22))
	draw_rect(Rect2(right_leg_x, leg_y, 6, 8), Color(0.15, 0.16, 0.22))
	
	var shoe_offset = 1.0 * flip
	draw_rect(Rect2(left_leg_x - 1 + shoe_offset, leg_y + 6, 7, 5), Color(0.08, 0.08, 0.12))
	draw_rect(Rect2(right_leg_x - 1 + shoe_offset, leg_y + 6, 7, 5), Color(0.08, 0.08, 0.12))
	
	# 3. 躯干战衣 (Torso Armor)
	draw_rect(Rect2(-8, torso_y, 16, 14), Color(0.2, 0.22, 0.28))
	draw_rect(Rect2(-6, torso_y, 12, 12), Color(0.16, 0.18, 0.24))
	
	# 4. 黄色蝙蝠图标胸章 (Bat Symbol Emblem)
	draw_circle(Vector2(0, torso_y + 5), 5.0, Color(1.0, 0.85, 0.1)) # 黄底
	var bat_wings = PackedVector2Array([
		Vector2(-4, torso_y + 4), Vector2(-2, torso_y + 3), Vector2(0, torso_y + 5), Vector2(2, torso_y + 3), Vector2(4, torso_y + 4),
		Vector2(3, torso_y + 6), Vector2(0, torso_y + 7), Vector2(-3, torso_y + 6)
	])
	draw_polygon(bat_wings, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	
	# 5. 金黄色战术腰带 (Yellow Utility Belt)
	draw_rect(Rect2(-8, torso_y + 11, 16, 3), Color(1.0, 0.8, 0.1))
	draw_rect(Rect2(-2, torso_y + 10, 4, 5), Color(0.9, 0.7, 0.0)) # 腰带扣
	
	# 6. 手臂与护臂刺刺 (Arms & Gauntlets)
	var arm_swing = -leg_swing * 0.8
	var left_arm_y = torso_y + 2 + arm_swing
	var right_arm_y = torso_y + 2 - arm_swing
	
	draw_rect(Rect2(-12, left_arm_y, 5, 10), Color(0.16, 0.18, 0.24))
	draw_rect(Rect2(7, right_arm_y, 5, 10), Color(0.16, 0.18, 0.24))
	# 护臂利刃突起
	draw_polygon(PackedVector2Array([Vector2(-12, left_arm_y + 3), Vector2(-15 * flip, left_arm_y + 5), Vector2(-12, left_arm_y + 7)]), PackedColorArray([Color(0.1, 0.1, 0.14)]))
	draw_polygon(PackedVector2Array([Vector2(12, right_arm_y + 3), Vector2(15 * flip, right_arm_y + 5), Vector2(12, right_arm_y + 7)]), PackedColorArray([Color(0.1, 0.1, 0.14)]))
	
	# 7. 蝙蝠头盔 (Cowl) & 尖角耳 (Bat Ears)
	draw_circle(Vector2(0, head_y), 9.0, Color(0.1, 0.1, 0.14))
	# 左耳
	var left_ear = PackedVector2Array([Vector2(-8, head_y - 3), Vector2(-4, head_y - 3), Vector2(-7, head_y - 15)])
	draw_polygon(left_ear, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	# 右耳
	var right_ear = PackedVector2Array([Vector2(4, head_y - 3), Vector2(8, head_y - 3), Vector2(7, head_y - 15)])
	draw_polygon(right_ear, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	
	# 8. 露脸下巴 (Jaw Cutout)
	draw_rect(Rect2(-4, head_y + 2, 8, 5), Color(0.95, 0.78, 0.65))
	draw_line(Vector2(-3, head_y + 5), Vector2(3, head_y + 5), Color(0.4, 0.2, 0.1), 1.5) # 嘴唇
	
	# 9. 蝙蝠侠发光白眼 (Glowing White Eyes)
	var eye_y = head_y - 2
	var eye_offset_x = 2.0 * flip
	var left_eye = PackedVector2Array([Vector2(-6 + eye_offset_x, eye_y - 1), Vector2(-1 + eye_offset_x, eye_y), Vector2(-5 + eye_offset_x, eye_y + 2)])
	var right_eye = PackedVector2Array([Vector2(1 + eye_offset_x, eye_y), Vector2(6 + eye_offset_x, eye_y - 1), Vector2(5 + eye_offset_x, eye_y + 2)])
	
	var eye_color = Color(1.0, 1.0, 0.95) if invincible_timer <= 0 else Color(1.0, 0.3, 0.3)
	draw_polygon(left_eye, PackedColorArray([eye_color]))
	draw_polygon(right_eye, PackedColorArray([eye_color]))

func _unhandled_input(event):
	if is_dead or input_disabled or just_spawned:
		return
	
	# 跳跃输入触发与 Jump Buffer 预输入缓冲 (0.12s)
	if event.is_action_pressed("ui_accept") or \
	   (event is InputEventKey and event.pressed and not event.echo and \
	    (event.keycode == KEY_W or event.keycode == KEY_UP)):
		jump_buffer_timer = 0.12
		get_viewport().set_input_as_handled()
		
	# 提前松开跳跃键进行微调跳跃高度 (Variable Jump Height)
	if event.is_action_released("ui_accept") or \
	   (event is InputEventKey and not event.pressed and \
	    (event.keycode == KEY_W or event.keycode == KEY_UP)):
		if velocity.y < -150.0:
			velocity.y *= 0.45

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.flush_buffered_events()

func _physics_process(delta):
	if is_dead:
		velocity.y += GRAVITY * delta
		move_and_slide()
		return
		
	if input_disabled:
		return
	
	anim_time += delta
	just_spawned = false
	prev_position_y = position.y
	
	# Coyote Time & Jump Buffer
	if is_on_floor():
		coyote_timer = 0.12
	else:
		coyote_timer -= delta
		
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
	
	# 无敌闪烁
	var needs_redraw = false
	if invincible_timer > 0:
		invincible_timer -= delta
		var alpha = 0.5 if int(invincible_timer * 10) % 2 == 0 else 1.0
		if modulate.a != alpha:
			modulate.a = alpha
			needs_redraw = true
	else:
		if modulate.a != 1.0:
			modulate.a = 1.0
			needs_redraw = true
	
	# 重力
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# 水平移动
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir:
		velocity.x = dir * SPEED
		var new_facing = dir > 0
		if new_facing != facing_right:
			facing_right = new_facing
			needs_redraw = true
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 8 * delta)
	
	move_and_slide()
	
	# 边界限制
	position.x = clamp(position.x, 12.0, LEVEL_WIDTH - 12.0)
	
	# 驱动跑步/跳跃/呼吸动画的实时重绘
	if needs_redraw or abs(velocity.x) > 10.0 or not is_on_floor():
		queue_redraw()

func hit() -> bool:
	if is_dead or invincible_timer > 0:
		return false
	invincible_timer = 1.5
	velocity.y = -250.0
	velocity.x = -200.0 if velocity.x >= 0 else 200.0
	queue_redraw()
	return true

func die():
	if is_dead:
		return
	is_dead = true
	input_disabled = true
	
	if col_shape and is_instance_valid(col_shape):
		col_shape.set_deferred("disabled", true)
		
	velocity.y = -350.0
	velocity.x = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 0.6), 0.4)
	tween.chain().tween_callback(func(): hide())
