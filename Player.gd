extends CharacterBody2D

const SPEED = 300.0
const MAX_RUN_SPEED = 460.0      # 最大奔跑速度（按住方向键逐渐加速）
const RUN_ACCEL = 500.0           # 奔跑加速度（/秒）
const JUMP_VELOCITY = -530.0
const GRAVITY = 1100.0
# 动态关卡宽度，由 Game.gd 在创建玩家后赋值
var level_width = 5000

var invincible_timer = 0.0
var is_dead = false
var input_disabled = false
# 刚生成时禁止输入，防止开局的 Space 键带到游戏中触发自动跳跃
var just_spawned = true
var current_run_speed = SPEED    # 当前实际奔跑速度（逐渐递增）
# 上一帧位置，用于踩怪判定
var prev_position_y = 0.0

const Batarang = preload("res://Batarang.gd")
const PixelLib = preload("res://pixel_lib.gd")

# Coyote Time (土狼时间) & Jump Buffer (跳跃预输入)
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var batarang_cooldown_timer = 0.0
const BATARANG_COOLDOWN = 0.3  # 0.3s 冷却时间

# 右键近战武器 (Melee Slash)
var melee_cooldown_timer = 0.0
const MELEE_COOLDOWN = 0.35      # 冷却 0.35s
var is_melee_attacking = false   # 正在攻击中（用于绘制）
var melee_anim_timer = 0.0       # 攻击动画计时
const MELEE_ANIM_DURATION = 0.22 # 攻击动画持续 0.22s (使斜向大月牙弧光更震撼明显)
const MELEE_RANGE = 115.0        # 攻击有效距离 (扩大至 115px 覆盖前方/头顶/脚下)

# 动态动画变量 (Animation Parameters)
var anim_time = 0.0
var facing_right = true
var col_shape: CollisionShape2D = null

# 动效相关变量 (Run Dust, Skid Sparks, Hit Impact)
var run_dust_timer = 0.0
const RUN_DUST_INTERVAL = 0.12
var prev_dir_sign = 0.0
var melee_hit_impact_timer = 0.0
var melee_hit_impact_dir = 1.0
# 蛛网减速效果 (Web Slow)
var web_slow_timer = 0.0

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
	
	# 11. 空中急速下坠气流线 (Fast Fall Speed Lines)
	if not is_on_floor() and velocity.y > 300.0:
		var fall_alpha = clamp((velocity.y - 300.0) / 600.0, 0.0, 0.7)
		var line_color = Color(0.6, 0.85, 1.0, fall_alpha)
		var line_count = 3
		for i in range(line_count):
			var x_offset = (-12.0 + float(i) * 16.0) * flip
			var ly = -4.0 + sin(anim_time * 18.0 + float(i) * 2.5) * 6.0
			var ll = 8.0 + sin(anim_time * 14.0 + float(i) * 1.7) * 4.0
			draw_line(Vector2(x_offset, ly), Vector2(x_offset, ly + ll), line_color, 1.5)
	
	# 12. 斜向大弧度近战闪光特效 (Diagonal Electric Crescent Light Slash)
	if is_melee_attacking:
		var raw_t = 1.0 - (melee_anim_timer / MELEE_ANIM_DURATION)  # 0→1
		# 非线性缓出 (Ease-out cubic)：先快后慢模拟真实挥砍的蓄力释放感
		var slash_progress = 1.0 - pow(1.0 - raw_t, 2.8)
		var outer_r = 78.0
		var inner_r = 18.0
		var start_angle = -PI * 0.85 * flip  # 从身后蓄势切入
		var end_angle = PI * 0.55 * flip     # 大幅扫过前方与头顶脚下
		var sweep_progress = min(slash_progress * 1.35, 1.0)
		var sweep_angle = start_angle + (end_angle - start_angle) * sweep_progress
		var alpha = 1.0 - min(pow(raw_t, 1.6) * 1.2, 1.0)  # 尾部缓出淡出
		
		# 10a. 三重残影拖尾 (Ghost Trail — 每层延时叠加以制造动感加速残影)
		for ghost_layer in [0, 1, 2]:
			var ghost_offset = 0.05 * float(ghost_layer + 1)  # 每层 0.05s 延时
			var ghost_t = max(raw_t - ghost_offset, 0.0)
			if ghost_t <= 0.0:
				continue
			var ghost_prog = 1.0 - pow(1.0 - ghost_t, 2.8)
			var ghost_sweep = min(ghost_prog * 1.35, 1.0)
			var ghost_angle = start_angle + (end_angle - start_angle) * ghost_sweep
			var ghost_alpha = (1.0 - min(pow(ghost_t, 1.6) * 1.2, 1.0)) * 0.25 * (1.0 - ghost_layer * 0.3)
			
			# 残影月牙
			var g_outer_pts = PackedVector2Array()
			var g_inner_pts = PackedVector2Array()
			for i in range(8):
				var t = float(i) / 8.0
				var ang = start_angle + (ghost_angle - start_angle) * t
				g_outer_pts.append(Vector2(cos(ang), sin(ang)) * outer_r)
				g_inner_pts.append(Vector2(cos(ang), sin(ang)) * (inner_r + t * 12.0))
			var g_poly = PackedVector2Array()
			for p in g_outer_pts: g_poly.append(p)
			for i in range(g_inner_pts.size() - 1, -1, -1): g_poly.append(g_inner_pts[i])
			draw_polygon(g_poly, PackedColorArray([Color(0.3, 0.7, 1.0, 0.35 * ghost_alpha)]))
		
		# 10b. 主月牙多边形 (Main Crescent Glow Polygon)
		var outer_pts = PackedVector2Array()
		var inner_pts = PackedVector2Array()
		var steps = 16
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var ang = start_angle + (sweep_angle - start_angle) * t
			outer_pts.append(Vector2(cos(ang), sin(ang)) * outer_r)
			inner_pts.append(Vector2(cos(ang), sin(ang)) * (inner_r + t * 18.0))
			
		var crescent_poly = PackedVector2Array()
		for p in outer_pts:
			crescent_poly.append(p)
		for i in range(inner_pts.size() - 1, -1, -1):
			crescent_poly.append(inner_pts[i])
			
		# 外层青蓝电光气场
		draw_polygon(crescent_poly, PackedColorArray([Color(0.15, 0.85, 1.0, 0.55 * alpha)]))
		
		# 10c. 核心刀光闪白 + 金色刃辉 (Core White Flash + Gold Edge)
		var prev_outer = Vector2.ZERO
		var prev_core = Vector2.ZERO
		for i in range(steps + 1):
			var t = float(i) / float(steps)
			var ang = start_angle + (sweep_angle - start_angle) * t
			var core_pt = Vector2(cos(ang), sin(ang)) * (outer_r * 0.82)
			var outer_pt = Vector2(cos(ang), sin(ang)) * outer_r
			if i > 0:
				draw_line(prev_outer, outer_pt, Color(0.3, 0.9, 1.0, 0.85 * alpha), 6.0)
				draw_line(prev_core, core_pt, Color(1.0, 1.0, 1.0, 1.0 * alpha), 3.5)
				# 金色刃辉勾勒
				draw_line(prev_core, core_pt, Color(1.0, 0.85, 0.15, 0.7 * alpha), 1.5)
			prev_outer = outer_pt
			prev_core = core_pt
	
	# 13. 近战命中冲击线与扩散圆 (Hit Impact Line & Shockwave)
	if melee_hit_impact_timer > 0:
		var impact_raw = 1.0 - (melee_hit_impact_timer / 0.1)
		var impact_alpha = 1.0 - impact_raw
		
		var im_dir = melee_hit_impact_dir
		# 斜向斩击白痕冲击线
		var start_pt = Vector2(-15.0 * im_dir, -18.0)
		var end_pt = Vector2(35.0 * im_dir, -4.0)
		draw_line(start_pt, end_pt, Color(1.0, 1.0, 1.0, impact_alpha * 0.9), 3.0)
		draw_line(start_pt, end_pt, Color(0.3, 0.9, 1.0, impact_alpha * 0.5), 6.0)
		
		# 扩散冲击圆 (Expanding Shockwave)
		var shock_r = 4.0 + impact_raw * 28.0
		var shock_center = Vector2(28.0 * im_dir, -10.0)
		draw_circle(shock_center, shock_r, Color(1.0, 1.0, 1.0, impact_alpha * 0.15))
		draw_arc(shock_center, shock_r, 0.0, PI * 2.0, 16, Color(0.3, 0.9, 1.0, impact_alpha * 0.5), 2.0)

func _input(event):
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
	
	# 鼠标右键 近战劈砍 (Melee Slash) — 劈砍头顶的飞行敌人
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		melee_attack()
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.flush_buffered_events()

var was_on_floor = true

func _spawn_landing_dust():
	var parent_world = get_parent()
	if not parent_world:
		return
	var dust_node = Node2D.new()
	dust_node.position = position + Vector2(0, 16)
	parent_world.add_child(dust_node)
	
	# 像素尘雾纹理
	var dust_pal = { "G": Color(0.75, 0.75, 0.82), ".": Color.TRANSPARENT }
	var dust_pixels = ["....", ".GG.", "GGGG", ".GG."]
	var dust_tex = PixelLib.create_texture(4, 4, dust_pixels, dust_pal)
	
	var particles = []
	for i in range(4):
		var p = TextureRect.new()
		p.texture = dust_tex
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = Vector2(8, 8)
		p.modulate = Color(0.85, 0.85, 0.9, 0.65)
		var dir_x = -1.0 if i % 2 == 0 else 1.0
		var speed = randf_range(30.0, 70.0)
		dust_node.add_child(p)
		particles.append([p, Vector2(dir_x * speed, randf_range(-10.0, -30.0))])
		
	var tween = create_tween().set_parallel(true)
	for item in particles:
		var p = item[0]
		var vel = item[1]
		tween.tween_property(p, "position", vel * 0.2, 0.2)
		tween.tween_property(p, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func():
		if is_instance_valid(dust_node):
			dust_node.hide(); dust_node.queue_free()
	)

func _spawn_run_dust():
	"""奔跑时脚后持续飘出土尘粒子（像素纹理）"""
	var parent_world = get_parent()
	if not parent_world:
		return
	var dust_node = Node2D.new()
	var dust_offset = -6.0 * (1.0 if facing_right else -1.0)
	dust_node.position = position + Vector2(dust_offset, 16.0)
	parent_world.add_child(dust_node)
	
	# 像素尘雾纹理
	var dust_pal = { "G": Color(0.75, 0.75, 0.82), ".": Color.TRANSPARENT }
	var dust_pixels = ["....", ".GG.", "GGGG", ".GG."]
	var dust_tex = PixelLib.create_texture(4, 4, dust_pixels, dust_pal)
	
	var particles = []
	var count = randi_range(1, 2)
	for i in range(count):
		var p = TextureRect.new()
		p.texture = dust_tex
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = Vector2(6, 6)
		p.modulate = Color(0.75, 0.75, 0.8, 0.5)
		var dir_x = -1.0 * (1.0 if facing_right else 1.0)
		var speed = randf_range(20.0, 45.0)
		dust_node.add_child(p)
		particles.append([p, Vector2(dir_x * speed, randf_range(15.0, 35.0))])
		
	var tween = create_tween().set_parallel(true)
	for item in particles:
		var p = item[0]
		var vel = item[1]
		tween.tween_property(p, "position", vel * 0.25, 0.25)
		tween.tween_property(p, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(func():
		if is_instance_valid(dust_node):
			dust_node.hide(); dust_node.queue_free()
	)

func _spawn_skid_spark():
	"""地面急停转向时摩擦火花（像素星芒纹理）"""
	var parent_world = get_parent()
	if not parent_world:
		return
	var spark_node = Node2D.new()
	spark_node.position = position + Vector2(0, 16.0)
	parent_world.add_child(spark_node)
	
	# 像素星芒纹理
	var star_pal = { "Y": Color(1.0, 0.9, 0.3), "W": Color(1.0, 1.0, 0.8), ".": Color.TRANSPARENT }
	var star_pixels = ["..Y..", ".WY.", "YWYY.", ".WY.", "..Y.."]
	var star_tex = PixelLib.create_texture(5, 5, star_pixels, star_pal)
	
	var particles = []
	var count = randi_range(2, 3)
	for i in range(count):
		var p = TextureRect.new()
		p.texture = star_tex
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = Vector2(8, 8)
		p.modulate = Color(1.0, 0.9, 0.4) if i % 2 == 0 else Color(1.0, 1.0, 0.8)
		var angle = randf_range(-PI * 0.6, PI * 0.6)
		var speed = randf_range(50.0, 100.0)
		spark_node.add_child(p)
		particles.append([p, Vector2(cos(angle), sin(angle)) * speed])
		
	var tween = create_tween().set_parallel(true)
	for item in particles:
		var p = item[0]
		var vel = item[1]
		tween.tween_property(p, "position", vel * 0.2, 0.2)
		tween.tween_property(p, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func():
		if is_instance_valid(spark_node):
			spark_node.hide(); spark_node.queue_free()
	)

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
	
	var currently_on_floor = is_on_floor()
	
	# 落地检测：触发横向挤压与落地 Dust 粒子 (Squash on Landing)
	if currently_on_floor and not was_on_floor:
		scale = Vector2(1.42, 1.08)
		_spawn_landing_dust()
		var game = get_tree().current_scene
		if game and game.has_method("add_camera_shake"):
			game.add_camera_shake(2.0, 0.08)
			
	was_on_floor = currently_on_floor
	
	# 平滑逼近标准体型 1.25x
	scale = scale.lerp(Vector2(1.25, 1.25), 14.0 * delta)
	
	# Coyote Time & Jump Buffer
	if currently_on_floor:
		coyote_timer = 0.12
	else:
		coyote_timer -= delta
		
	if batarang_cooldown_timer > 0:
		batarang_cooldown_timer -= delta
		
	if melee_cooldown_timer > 0:
		melee_cooldown_timer -= delta
		
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# 起跳检测：触发纵向拉伸 (Stretch on Jump)
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		scale = Vector2(1.08, 1.45)
	
	# 无敌闪烁 & 近战动画状态
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
			
	if is_melee_attacking:
		melee_anim_timer -= delta
		if melee_anim_timer <= 0:
			is_melee_attacking = false
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
		# 按住方向键逐渐加速奔跑 (Run Acceleration)
		current_run_speed = min(current_run_speed + RUN_ACCEL * delta, MAX_RUN_SPEED)
		velocity.x = dir * current_run_speed
		var new_facing = dir > 0
		if new_facing != facing_right:
			facing_right = new_facing
			needs_redraw = true
	else:
		# 松手立即重置为基准速度
		current_run_speed = SPEED
		velocity.x = move_toward(velocity.x, 0, SPEED * 8 * delta)
	
	# 转向急停摩擦检测 (在地面快速变向 → 摩擦火花)
	var current_dir_sign = sign(velocity.x)
	if is_on_floor() and current_dir_sign != 0.0 and prev_dir_sign != 0.0 and current_dir_sign != prev_dir_sign and abs(velocity.x) > 80.0:
		_spawn_skid_spark()
	prev_dir_sign = current_dir_sign
	
	# 蛛网减速：被蜘蛛网击中时速度减半
	if web_slow_timer > 0:
		velocity.x *= 0.92  # 每帧减速，移动迟钝如陷泥沼
	
	move_and_slide()
	
	# 奔跑烟尘：地面上高速移动时脚后持续飘出土尘
	if is_on_floor() and abs(velocity.x) > 50.0:
		run_dust_timer -= delta
		if run_dust_timer <= 0:
			run_dust_timer = RUN_DUST_INTERVAL
			_spawn_run_dust()
	else:
		run_dust_timer = 0.0
	
	# 蛛网减速计时与恢复
	if web_slow_timer > 0:
		web_slow_timer -= delta
		if web_slow_timer <= 0:
			web_slow_timer = 0.0
			# 恢复正常颜色
			if modulate == Color(0.6, 0.7, 1.0):
				modulate = Color(1.0, 1.0, 1.0)
	
	# 近战命中冲击特效计时
	if melee_hit_impact_timer > 0:
		melee_hit_impact_timer -= delta
		if melee_hit_impact_timer <= 0:
			melee_hit_impact_timer = 0.0
			needs_redraw = true
	
	# 边界限制
	position.x = clamp(position.x, 12.0, level_width - 12.0)
	
	# 控制动画刷新频率：按需刷新或每 2 物理帧刷新一次 (30FPS 动画帧率，大降 Process CPU 开销)
	if needs_redraw or ((abs(velocity.x) > 10.0 or not is_on_floor()) and Engine.get_physics_frames() % 2 == 0):
		queue_redraw()

func apply_web_slow(duration: float):
	"""被蛛网击中：减速持续 duration 秒"""
	web_slow_timer = duration
	modulate = Color(0.6, 0.7, 1.0)  # 蓝色调提示

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
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide()
	)

func shoot_batarang():
	"""发射蝙蝠飞镖"""
	if is_dead or input_disabled or batarang_cooldown_timer > 0:
		return
		
	batarang_cooldown_timer = BATARANG_COOLDOWN
	
	var parent_world = get_parent()
	if not parent_world:
		return
		
	# 根据鼠标位置自动转向 (实现指哪打哪的顺滑手感)
	var mouse_pos = get_global_mouse_position()
	if mouse_pos != Vector2.ZERO:
		var dx = mouse_pos.x - global_position.x
		if abs(dx) > 5.0:
			facing_right = (dx > 0)
		
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

func melee_attack():
	"""右键斜向大弧度近战斩击：开启即得 0.35s 短暂无敌帧，宽泛判定斩击强敌与弹幕"""
	if is_dead or input_disabled or melee_cooldown_timer > 0 or is_melee_attacking:
		return
		
	melee_cooldown_timer = MELEE_COOLDOWN
	is_melee_attacking = true
	melee_anim_timer = MELEE_ANIM_DURATION
	
	# 🌟 开启即处于短时间无敌 (Invincibility Frames during melee slash)
	invincible_timer = max(invincible_timer, 0.35)
	queue_redraw()
	
	var parent_world = get_parent()
	var center = global_position
	var dir = 1.0 if facing_right else -1.0
	
	# 特效：在斩击弧线上生成多个青蓝与金光火花
	if parent_world and parent_world.has_method("_spawn_particle_burst"):
		parent_world._spawn_particle_burst(center + Vector2(40.0 * dir, -15.0), Color(0.2, 0.95, 1.0))
		parent_world._spawn_particle_burst(center + Vector2(65.0 * dir, -30.0), Color(1.0, 1.0, 0.8))
	
	# 1. 🌀 挥刀切碎弹幕 (Projectile Slicing — 130px 范围切碎扑克牌与飞行子弹)
	var projectiles = get_tree().get_nodes_in_group("enemy_projectiles")
	for proj in projectiles:
		if is_instance_valid(proj) and center.distance_to(proj.global_position) <= 130.0:
			if parent_world and parent_world.has_method("_spawn_particle_burst"):
				parent_world._spawn_particle_burst(proj.global_position, Color(1.0, 0.9, 0.2))
				parent_world._spawn_particle_burst(proj.global_position, Color(0.3, 1.0, 1.0))
			if proj.has_method("slice_destroy"):
				proj.slice_destroy()
			elif proj.has_method("deflect"):
				proj.deflect()
			elif proj.has_method("hit_by_batarang"):
				proj.hit_by_batarang()
			else:
				proj.queue_free()
	
	# 2. 宽泛判定靠近的敌人与 Boss (Broad Hitbox Detection & High Damage)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_any = false
	
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not ("alive" in e and e.alive):
			continue
			
		var e_pos = e.global_position
		var dist = center.distance_to(e_pos)
		var dx = e_pos.x - center.x
		var dy = e_pos.y - center.y
		
		# 宽泛攻击范围判定：大圆形范围 + 前方扇形 + 垂直方向大面积覆盖
		# 朝前方更宽（敌人前方更容易吃刀），向下可达 120px（跳跃时也能砍到地面敌人）
		var front_dir = dx * dir  # >0 表示敌人在角色前方
		var in_front_cone = front_dir > -20.0 and abs(dx) <= MELEE_RANGE and dy >= -100.0 and dy <= 120.0
		var is_in_range = (dist <= MELEE_RANGE) or in_front_cone
		if is_in_range:
			hit_any = true
			
			# 重创伤害：对 Boss 与敌人造成 10 点近战核心力道重创 (远程飞镖为 1 点，刚好是近战的 1/10)
			if e.has_method("hit_by_melee"):
				e.hit_by_melee(10)
			elif e.has_method("hit_by_batarang"):
				e.hit_by_batarang(1)
				
			if parent_world and parent_world.has_method("add_camera_shake"):
				parent_world.add_camera_shake(6.0, 0.1)
			if parent_world and parent_world.has_method("trigger_hit_stop"):
				parent_world.trigger_hit_stop(0.04)
			if parent_world and parent_world.has_method("_spawn_particle_burst"):
				parent_world._spawn_particle_burst(e_pos, Color(0.3, 0.95, 1.0))
				
			# 冲击特效：冲击线 + 扩散圆 (Impact Visuals)
			melee_hit_impact_timer = 0.1
			melee_hit_impact_dir = dir
			queue_redraw()
	
	# 强力打击感：卡肉停顿 + 后坐力
	if hit_any:
		velocity.x = -80.0 * dir
		if parent_world and parent_world.has_method("add_camera_shake"):
			parent_world.add_camera_shake(10.0, 0.15)
