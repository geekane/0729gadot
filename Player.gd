extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -530.0
const GRAVITY = 1100.0
# 动态关卡宽度，由 Game.gd 在创建玩家后赋值
var level_width = 5000

var invincible_timer = 0.0
var is_dead = false
var input_disabled = false
# 刚生成时禁止输入，防止开局的 Space 键带到游戏中触发自动跳跃
var just_spawned = true
# 上一帧位置，用于踩怪判定
var prev_position_y = 0.0

const Batarang = preload("res://Batarang.gd")

# Coyote Time (土狼时间) & Jump Buffer (跳跃预输入)
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var batarang_cooldown_timer = 0.0
const BATARANG_COOLDOWN = 0.3  # 0.3s 冷却时间

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
	
	# 整体 Y 轴向上抬高 9px，确保鞋底正好压在 Y = +18 碰撞底线上，不嵌入地面
	var torso_y = -7.0 + breath_y
	var leg_y = 7.0 + breath_y
	var head_y = -16.0 + breath_y
	
	# 1. 动态蝙蝠斗篷 (Dynamic Bat Cape)
	var cape_color = Color(0.06, 0.06, 0.1)
	var cape_points = PackedVector2Array()
	var wave_dir = cape_wave * flip
	
	if is_airborne:
		# 空中/跳跃状态：蝙蝠滑翔翼式张开斗篷
		cape_points = PackedVector2Array([
			Vector2(-4.0 * flip, torso_y - 4.0),
			Vector2(-26.0 * flip, torso_y - 6.0),
			Vector2(-30.0 * flip, torso_y + 16.0),
			Vector2(-18.0 * flip, torso_y + 24.0),
			Vector2(-6.0 * flip, torso_y + 18.0),
			Vector2(4.0 * flip, torso_y + 8.0)
		])
	elif is_moving:
		# 奔跑状态：斗篷向后迎风剧烈摆动
		cape_points = PackedVector2Array([
			Vector2(-4.0 * flip, torso_y - 4.0),
			Vector2(-20.0 * flip - wave_dir, torso_y + 4.0),
			Vector2(-26.0 * flip - wave_dir, torso_y + 18.0 + cape_wave),
			Vector2(-14.0 * flip, torso_y + 20.0),
			Vector2(-4.0 * flip, torso_y + 14.0),
			Vector2(2.0 * flip, torso_y + 10.0)
		])
	else:
		# 待机状态：斗篷顺垂背后微动
		cape_points = PackedVector2Array([
			Vector2(-4.0 * flip, torso_y - 4.0),
			Vector2(-14.0 * flip - wave_dir, torso_y + 6.0),
			Vector2(-18.0 * flip - wave_dir, torso_y + 22.0),
			Vector2(-10.0 * flip, torso_y + 22.0),
			Vector2(-4.0 * flip, torso_y + 14.0),
			Vector2(2.0 * flip, torso_y + 10.0)
		])
	
	# 关键修正：镜像翻转 (flip = -1) 会反转顶点绕行方向 (Winding Order)，
	# 须将数组反转确保 draw_polygon 接收到的永远是逆时针正向顶点，防止 GPU 产生退化白像素
	if not facing_right:
		cape_points.reverse()
	draw_polygon(cape_points, PackedColorArray([cape_color]))
	
	# 2. 腿部与暗影战靴 (Legs & Boots - 鞋底精确压在 Y = +18 碰撞底端)
	var left_leg_x = -8.0 + (leg_swing if not is_airborne else 2.0)
	var right_leg_x = 2.0 - (leg_swing if not is_airborne else 2.0)
	
	draw_rect(Rect2(left_leg_x, leg_y, 6.0, 8.0), Color(0.15, 0.16, 0.22))
	draw_rect(Rect2(right_leg_x, leg_y, 6.0, 8.0), Color(0.15, 0.16, 0.22))
	
	var shoe_offset = 1.0 * flip
	draw_rect(Rect2(left_leg_x - 1.0 + shoe_offset, leg_y + 6.0, 7.0, 5.0), Color(0.08, 0.08, 0.12))
	draw_rect(Rect2(right_leg_x - 1.0 + shoe_offset, leg_y + 6.0, 7.0, 5.0), Color(0.08, 0.08, 0.12))
	
	# 3. 躯干战衣 (Torso Armor)
	draw_rect(Rect2(-8.0, torso_y, 16.0, 14.0), Color(0.2, 0.22, 0.28))
	draw_rect(Rect2(-6.0, torso_y, 12.0, 12.0), Color(0.16, 0.18, 0.24))
	
	# 4. 黄色蝙蝠图标胸章 (Bat Symbol Emblem)
	draw_circle(Vector2(0, torso_y + 5.0), 5.0, Color(1.0, 0.85, 0.1)) # 黄底
	var bat_wings = PackedVector2Array([
		Vector2(-4.0, torso_y + 4.0), Vector2(-2.0, torso_y + 3.0), Vector2(0.0, torso_y + 5.0), Vector2(2.0, torso_y + 3.0), Vector2(4.0, torso_y + 4.0),
		Vector2(3.0, torso_y + 6.0), Vector2(0.0, torso_y + 7.0), Vector2(-3.0, torso_y + 6.0)
	])
	draw_polygon(bat_wings, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	
	# 5. 金黄色战术腰带 (Yellow Utility Belt)
	draw_rect(Rect2(-8.0, torso_y + 11.0, 16.0, 3.0), Color(1.0, 0.8, 0.1))
	draw_rect(Rect2(-2.0, torso_y + 10.0, 4.0, 5.0), Color(0.9, 0.7, 0.0)) # 腰带扣
	
	# 6. 手臂与护臂刺刺 (Arms & Gauntlets)
	var arm_swing = -leg_swing * 0.8
	var left_arm_y = torso_y + 2.0 + arm_swing
	var right_arm_y = torso_y + 2.0 - arm_swing
	
	draw_rect(Rect2(-12.0, left_arm_y, 5.0, 10.0), Color(0.16, 0.18, 0.24))
	draw_rect(Rect2(7.0, right_arm_y, 5.0, 10.0), Color(0.16, 0.18, 0.24))
	
	# 修正护臂利刃突起：左侧手臂(x=-12)刺向左(-15)，右侧手臂(x=7)刺向右(+15)，避免乘 flip 导致穿透身体
	var left_gauntlet = PackedVector2Array([Vector2(-12.0, left_arm_y + 3.0), Vector2(-15.0, left_arm_y + 5.0), Vector2(-12.0, left_arm_y + 7.0)])
	var right_gauntlet = PackedVector2Array([Vector2(12.0, right_arm_y + 3.0), Vector2(15.0, right_arm_y + 5.0), Vector2(12.0, right_arm_y + 7.0)])
	draw_polygon(left_gauntlet, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	draw_polygon(right_gauntlet, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	
	# 7. 蝙蝠头盔 (Cowl) & 尖角耳 (Bat Ears)
	draw_circle(Vector2(0, head_y), 9.0, Color(0.1, 0.1, 0.14))
	var left_ear = PackedVector2Array([Vector2(-8.0, head_y - 3.0), Vector2(-4.0, head_y - 3.0), Vector2(-7.0, head_y - 15.0)])
	draw_polygon(left_ear, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	var right_ear = PackedVector2Array([Vector2(4.0, head_y - 3.0), Vector2(8.0, head_y - 3.0), Vector2(7.0, head_y - 15.0)])
	draw_polygon(right_ear, PackedColorArray([Color(0.1, 0.1, 0.14)]))
	
	# 8. 露脸下巴 (Jaw Cutout)
	draw_rect(Rect2(-4.0, head_y + 2.0, 8.0, 5.0), Color(0.95, 0.78, 0.65))
	draw_line(Vector2(-3.0, head_y + 5.0), Vector2(3.0, head_y + 5.0), Color(0.4, 0.2, 0.1), 1.5) # 嘴唇
	
	# 9. 蝙蝠侠发光白眼 (Glowing White Eyes)
	var eye_y = head_y - 2.0
	var eye_offset_x = 2.0 * flip
	var left_eye = PackedVector2Array([Vector2(-6.0 + eye_offset_x, eye_y - 1.0), Vector2(-1.0 + eye_offset_x, eye_y), Vector2(-5.0 + eye_offset_x, eye_y + 2.0)])
	var right_eye = PackedVector2Array([Vector2(1.0 + eye_offset_x, eye_y), Vector2(6.0 + eye_offset_x, eye_y - 1.0), Vector2(5.0 + eye_offset_x, eye_y + 2.0)])
	
	var eye_color = Color(1.0, 1.0, 0.95) if invincible_timer <= 0 else Color(1.0, 0.3, 0.3)
	draw_polygon(left_eye, PackedColorArray([eye_color]))
	draw_polygon(right_eye, PackedColorArray([eye_color]))

func _unhandled_input(event):
	if is_dead or input_disabled or just_spawned:
		return
	
	# 跳跃输入触发与 Jump Buffer 预输入缓冲 (0.12s) - 支持 Space 空格键 / W 键 / ↑ 键
	if event.is_action_pressed("ui_accept") or \
	   (event is InputEventKey and event.pressed and not event.echo and \
	    (event.keycode == KEY_SPACE or event.keycode == KEY_W or event.keycode == KEY_UP)):
		jump_buffer_timer = 0.12
		get_viewport().set_input_as_handled()
		
	# 提前松开跳跃键进行微调跳跃高度 (Variable Jump Height)
	if event.is_action_released("ui_accept") or \
	   (event is InputEventKey and not event.pressed and \
	    (event.keycode == KEY_SPACE or event.keycode == KEY_W or event.keycode == KEY_UP)):
		if velocity.y < -150.0:
			velocity.y *= 0.45
			
	# 鼠标左键 或 J 键 / K 键 发射蝙蝠飞镖 (Batarang Attack)
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
	   (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_J or event.keycode == KEY_K)):
		shoot_batarang()
		get_viewport().set_input_as_handled()

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
		
	if batarang_cooldown_timer > 0:
		batarang_cooldown_timer -= delta
		
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
	
	# 水平移动 (支持 A / D 键、← / → 键 与 Godot Action 轴)
	var dir = Input.get_axis("ui_left", "ui_right")
	if dir == 0.0:
		var left = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
		var right = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
		if left and not right:
			dir = -1.0
		elif right and not left:
			dir = 1.0

	if dir != 0.0:
		velocity.x = dir * SPEED
		var new_facing = dir > 0
		if new_facing != facing_right:
			facing_right = new_facing
			needs_redraw = true
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 8 * delta)
	
	move_and_slide()
	
	# 边界限制
	position.x = clamp(position.x, 12.0, level_width - 12.0)
	
	# 控制动画刷新频率：按需刷新或每 2 物理帧刷新一次 (30FPS 动画帧率，大降 Process CPU 开销)
	if needs_redraw or ((abs(velocity.x) > 10.0 or not is_on_floor()) and Engine.get_physics_frames() % 2 == 0):
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

func shoot_batarang():
	"""发射蝙蝠飞镖"""
	if is_dead or input_disabled or batarang_cooldown_timer > 0:
		return
		
	batarang_cooldown_timer = BATARANG_COOLDOWN
	
	var parent_world = get_parent()
	if not parent_world:
		return
		
	var batarang = Batarang.new()
	var dir_factor = 1.0 if facing_right else -1.0
	# 飞镖从蝙蝠侠胸口位置发射
	batarang.position = position + Vector2(16.0 * dir_factor, -4.0)
	batarang.direction = dir_factor
	parent_world.add_child(batarang)
	
	# 粒子特效
	if parent_world.has_method("_spawn_particle_burst"):
		parent_world._spawn_particle_burst(batarang.position, Color(1.0, 0.85, 0.2))
		
	queue_redraw()
