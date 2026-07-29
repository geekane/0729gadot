extends Area2D

# 🕷️ 八脚血盆大口蜘蛛小丑大 Boss (Spider-Joker Nightmare Monster Boss)
# 0.7 倍体型尺寸、恐怖表情过场演出、1/10 飞镖刮痧/10点近战重创、砸地眩晕暴露弱点破防

const JokerCard = preload("res://JokerCard.gd")
const SpiderWeb = preload("res://SpiderWeb.gd")

const MAX_HP = 100

# 9 大 AI 战斗与过场状态
enum BossState {
	DORMANT,         # 偶遇静止沉睡 (无声悬挂右侧高处)
	INITIAL_POUNCE,  # 狂暴醒来直扑主角 (逼迫玩家瞬间跳跃闪躲)
	SKITTER,         # 8 腿急速扒行追击 (护甲防空，弹刀 0 伤害)
	CEILING_HANG,    # 天花板蛛丝倒挂 (护甲防空，弹刀 0 伤害)
	POUNCE,          # 弧线飞扑咬杀 (护甲防空，弹刀 0 伤害)
	SKY_LEAP_UP,     # 跃入云霄隐匿
	SKY_DROP_CRASH,  # 从天而降轰炸地表
	STUNNED,         # 砸地重伤眩晕破防 (暴露弱点！仅在此时受击扣血 1.8s)
	COUNTER_SWIPE    # 眩晕恢复即刻极速风暴扫击 (秒杀贪刀玩家)
}

var hp = 100
var invincible_timer = 0.0
var shoot_timer = 0.0
var anim_timer = 0.0
var state_timer = 0.0
var stun_timer = 0.0
var counter_swipe_timer = 0.0

var current_state = BossState.DORMANT
var jaw_open_amount = 0.0  # 血盆大口张开度 0.0 ~ 1.0
var sky_drop_target_x = 0.0
var sky_drop_warn_timer = 0.0

var start_x = 0.0
var start_y = 0.0
var arena_min_x = 4060.0
var arena_max_x = 4980.0
var ground_y = 508.0

var velocity = Vector2.ZERO
var facing_dir = -1.0
var alive = true

func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	start_x = position.x
	start_y = position.y
	arena_min_x = 4060.0
	arena_max_x = 4980.0
	ground_y = 508.0
	
	# 📐 尺寸缩小至 0.7 倍 (2.5 → 1.75)
	scale = Vector2(1.75, 1.75)
	
	# 碰撞体 (80x80)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	current_state = BossState.DORMANT
	body_entered.connect(_on_body_entered)

func awaken_and_pounce(target_pos: Vector2):
	"""狂暴醒来：以极高弧线与速度直接朝蝙蝠侠当前站位突袭飞扑 (逼迫玩家跳跃闪躲)"""
	current_state = BossState.INITIAL_POUNCE
	jaw_open_amount = 1.0
	
	var dx = target_pos.x - position.x
	velocity.x = clamp(dx * 2.2, -620.0, 620.0)
	velocity.y = -500.0
	
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_floating_text"):
		game._spawn_floating_text(global_position + Vector2(0, -50), "👄 AWAKEN! DODGE NOW! ⚠️", Color(1.0, 0.1, 0.1))
	if game and game.has_method("add_camera_shake"):
		game.add_camera_shake(20.0, 0.4)
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(1.0, 0.1, 0.1))
		game._spawn_particle_burst(global_position, Color(0.9, 0.9, 0.1))

func _physics_process(delta):
	if not alive:
		return
		
	anim_timer += delta
	
	if invincible_timer > 0:
		invincible_timer -= delta
		
	var is_enraged = hp <= 50
	var speed_mult = 1.6 if is_enraged else 1.0
	
	# 寻找玩家
	var player = get_tree().get_first_node_in_group("player")
	var player_pos = player.global_position if is_instance_valid(player) else Vector2(start_x, ground_y)
	
	# 朝向控制 (非眩晕、非沉睡状态下锁定玩家)
	if is_instance_valid(player) and current_state != BossState.STUNNED and current_state != BossState.DORMANT:
		facing_dir = -1.0 if player_pos.x < global_position.x else 1.0
		
	# 状态机行为
	match current_state:
		BossState.DORMANT:
			# 🎭 恐怖过场演出：8 腿伸展抖动、血盆大口剧烈张合、复眼红光脉冲
			position.y = 180.0
			jaw_open_amount = 0.5 + sin(anim_timer * 12.0) * 0.45

		BossState.INITIAL_POUNCE:
			# 醒来突袭飞扑状态：直扑蝙蝠侠
			jaw_open_amount = 1.0
			position += velocity * delta
			velocity.y += 980.0 * delta
			position.x = clamp(position.x, arena_min_x, arena_max_x)
			
			if position.y >= ground_y:
				position.y = ground_y
				# 着地重伤眩晕，暴露弱点破防
				_enter_stunned_state()

		BossState.SKITTER:
			# 8 腿急速扒行追击 (常态护甲装甲，弹刀 0 伤害)
			state_timer -= delta
			jaw_open_amount = move_toward(jaw_open_amount, 0.2 + sin(anim_timer * 8.0) * 0.15, delta * 3.0)
			var target_x = player_pos.x
			var move_dir = -1.0 if target_x < position.x else 1.0
			position.x += move_dir * 160.0 * speed_mult * delta
			position.y = move_toward(position.y, ground_y, delta * 200.0)
			
			position.x = clamp(position.x, arena_min_x, arena_max_x)
			
			# 状态转换：定时飞扑、倒挂或【从天而降】
			if state_timer <= 0:
				state_timer = randf_range(3.0, 4.5)
				var roll = randf()
				if roll < 0.35:
					_start_pounce(player_pos)
				elif roll < 0.7:
					_start_sky_leap()
				else:
					_start_ceiling_hang()
					
		BossState.CEILING_HANG:
			# 天花板倒挂悬丝 (y=140px)
			state_timer -= delta
			jaw_open_amount = move_toward(jaw_open_amount, 0.75, delta * 4.0)
			position.y = move_toward(position.y, 140.0, delta * 350.0)
			position.x += sin(anim_timer * 2.5) * 110.0 * delta
			position.x = clamp(position.x, arena_min_x, arena_max_x)
			
			if state_timer <= 0:
				state_timer = randf_range(3.0, 4.5)
				if randf() < 0.6:
					_start_sky_leap()
				else:
					_start_pounce(player_pos)
				
		BossState.POUNCE:
			# 弧线飞扑咬杀状态
			jaw_open_amount = move_toward(jaw_open_amount, 1.0, delta * 6.0)
			position += velocity * delta
			velocity.y += 950.0 * delta
			position.x = clamp(position.x, arena_min_x, arena_max_x)
			
			if position.y >= ground_y:
				position.y = ground_y
				current_state = BossState.SKITTER
				state_timer = randf_range(2.5, 4.0)
				_on_impact_land()
				
		BossState.SKY_LEAP_UP:
			# 跃入云霄隐匿状态
			jaw_open_amount = 1.0
			position.y -= 800.0 * delta
			if position.y <= -350.0:
				current_state = BossState.SKY_DROP_CRASH
				sky_drop_warn_timer = 0.8
				if is_instance_valid(player):
					sky_drop_target_x = clamp(player.global_position.x, arena_min_x, arena_max_x)
				else:
					sky_drop_target_x = (arena_min_x + arena_max_x) / 2.0
					
		BossState.SKY_DROP_CRASH:
			if sky_drop_warn_timer > 0:
				sky_drop_warn_timer -= delta
				if is_instance_valid(player):
					sky_drop_target_x = clamp(player.global_position.x, arena_min_x, arena_max_x)
			else:
				position.x = sky_drop_target_x
				position.y += 1900.0 * delta
				if position.y >= ground_y:
					position.y = ground_y
					_enter_stunned_state()
					
		BossState.STUNNED:
			# 💫 砸地重伤眩晕破防 (1.8 秒暴露弱点受击窗口)
			stun_timer -= delta
			jaw_open_amount = move_toward(jaw_open_amount, 0.9, delta * 3.0)
			position.x = clamp(position.x + sin(anim_timer * 20.0) * 1.5, arena_min_x, arena_max_x)
			
			if stun_timer <= 0:
				var dist_to_player = global_position.distance_to(player_pos)
				if is_instance_valid(player) and dist_to_player <= 160.0:
					_start_counter_swipe(player)
				else:
					current_state = BossState.SKITTER
					state_timer = randf_range(3.0, 4.0)

		BossState.COUNTER_SWIPE:
			# ⚡ 贪刀即死反击：无前摇扫击电弧
			counter_swipe_timer -= delta
			jaw_open_amount = 1.0
			if counter_swipe_timer <= 0:
				current_state = BossState.SKITTER
				state_timer = randf_range(2.5, 4.0)

	# 约束范围防消失
	if current_state != BossState.SKY_LEAP_UP and current_state != BossState.SKY_DROP_CRASH and current_state != BossState.DORMANT:
		position.x = clamp(position.x, arena_min_x, arena_max_x)
		position.y = clamp(position.y, 120.0, ground_y)

	# 仅在非眩晕、非沉睡、非反击状态下发射弹幕
	if current_state != BossState.DORMANT and current_state != BossState.STUNNED and current_state != BossState.COUNTER_SWIPE and current_state != BossState.INITIAL_POUNCE:
		shoot_timer += delta
		var shoot_cd = 0.9 if is_enraged else 1.7
		if shoot_timer >= shoot_cd:
			shoot_timer = 0.0
			if current_state == BossState.CEILING_HANG:
				_shoot_3way_cards()
				_shoot_web()
			elif current_state == BossState.SKITTER:
				if randf() < 0.65:
					_shoot_joker_card()
				else:
					_shoot_web()
					
	queue_redraw()

func _enter_stunned_state():
	"""进入砸地眩晕破防状态"""
	current_state = BossState.STUNNED
	stun_timer = 1.8
	_on_impact_land()
	
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_floating_text"):
		game._spawn_floating_text(global_position + Vector2(0, -60), "💫 VULNERABLE! STRIKE NOW!", Color(1.0, 0.9, 0.2))
	if game and game.has_method("add_camera_shake"):
		game.add_camera_shake(18.0, 0.3)

func _start_counter_swipe(player_node):
	"""极速秒杀级反击风暴 (惩罚贪刀玩家)"""
	current_state = BossState.COUNTER_SWIPE
	counter_swipe_timer = 0.45
	
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_floating_text"):
		game._spawn_floating_text(global_position + Vector2(0, -65), "☠️ COUNTER STRIKE!", Color(1.0, 0.1, 0.1))
	if game and game.has_method("add_camera_shake"):
		game.add_camera_shake(25.0, 0.4)
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(1.0, 0.1, 0.1))
		game._spawn_particle_burst(global_position, Color(0.9, 0.9, 0.1))
		
	if is_instance_valid(player_node) and game and game.has_method("_on_player_hit"):
		game._on_player_hit(player_node)
		game._on_player_hit(player_node)

func _start_pounce(target_pos: Vector2):
	current_state = BossState.POUNCE
	state_timer = 2.0
	var dx = target_pos.x - position.x
	velocity.x = clamp(dx * 2.0, -450.0, 450.0)
	velocity.y = -480.0

func _start_ceiling_hang():
	current_state = BossState.CEILING_HANG
	state_timer = 4.0

func _start_sky_leap():
	current_state = BossState.SKY_LEAP_UP
	state_timer = 3.0

func _on_impact_land():
	"""着地砸坑震屏"""
	var game = get_tree().current_scene
	if game and game.has_method("add_camera_shake"):
		game.add_camera_shake(15.0, 0.25)
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position + Vector2(0, 20), Color(0.9, 0.1, 0.2))
		game._spawn_particle_burst(global_position + Vector2(0, 20), Color(0.4, 0.1, 0.6))

func _shoot_joker_card():
	var parent_world = get_parent()
	if not parent_world or not alive:
		return
	var player = get_tree().get_first_node_in_group("player")
	var player_pos = player.global_position if is_instance_valid(player) else (global_position + Vector2(-200, 200))
	var spawn_pos = global_position + Vector2(28.0 * facing_dir, 10.0)
	
	var card = JokerCard.new()
	card.position = spawn_pos
	var target_dir = (player_pos - spawn_pos).normalized()
	if target_dir == Vector2.ZERO:
		target_dir = Vector2(facing_dir, 0.0)
	card.fly_direction = target_dir
	parent_world.add_child(card)

func _shoot_3way_cards():
	var parent_world = get_parent()
	if not parent_world or not alive:
		return
	var player = get_tree().get_first_node_in_group("player")
	var player_pos = player.global_position if is_instance_valid(player) else (global_position + Vector2(0, 300))
	var spawn_pos = global_position + Vector2(0, 20.0)
	var base_dir = (player_pos - spawn_pos).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2(0.0, 1.0)
		
	# 🎯 3 向散弹扑克牌：主向量直指玩家位置，左右各偏转 20 度扇形发射！
	for angle_offset in [-0.35, 0.0, 0.35]:
		var card = JokerCard.new()
		card.position = spawn_pos
		card.fly_direction = base_dir.rotated(angle_offset)
		parent_world.add_child(card)

func _shoot_web():
	var parent_world = get_parent()
	if not parent_world or not alive:
		return
	var player = get_tree().get_first_node_in_group("player")
	var player_pos = player.global_position if is_instance_valid(player) else (global_position + Vector2(-200, 200))
	var spawn_pos = global_position + Vector2(24.0 * facing_dir, 10.0)
	
	var web = SpiderWeb.new()
	web.position = spawn_pos
	var target_dir = (player_pos - spawn_pos).normalized()
	if target_dir == Vector2.ZERO:
		target_dir = Vector2(facing_dir, 0.0)
	web.fly_direction = target_dir
	parent_world.add_child(web)

func _draw():
	if not alive:
		return
		
	var is_enraged = hp <= 50
	var is_dormant = current_state == BossState.DORMANT
	var is_stunned = current_state == BossState.STUNNED
	var flip = facing_dir
	
	# 静止沉睡状态下天花板蛛丝
	if is_dormant or current_state == BossState.CEILING_HANG:
		draw_line(Vector2(0, -30), Vector2(0, -200), Color(0.9, 0.95, 1.0, 0.8), 3.0)
	
	# 【从天而降预警锁定圈】
	if current_state == BossState.SKY_DROP_CRASH and sky_drop_warn_timer > 0:
		var reticle_pos = Vector2(sky_drop_target_x - position.x, ground_y - position.y)
		var pulse_r = 32.0 + sin(anim_timer * 22.0) * 6.0
		draw_circle(reticle_pos, pulse_r, Color(1.0, 0.1, 0.1, 0.35))
		draw_arc(reticle_pos, pulse_r + 4.0, 0.0, PI * 2.0, 24, Color(1.0, 0.9, 0.2, 0.9), 3.0)
		draw_line(reticle_pos + Vector2(-40, 0), reticle_pos + Vector2(40, 0), Color(1.0, 0.2, 0.2, 0.9), 2.5)
		draw_line(reticle_pos + Vector2(0, -40), reticle_pos + Vector2(0, 40), Color(1.0, 0.2, 0.2, 0.9), 2.5)
	
	# ── 1. 8 条带刺突的真实拱形关节蛛腿 (8 Spiky Articulated Spider Legs) ──
	var leg_color = Color(0.75, 0.08, 0.18) if is_enraged else Color(0.22, 0.08, 0.32)
	var joint_color = Color(1.0, 0.2, 0.2) if is_enraged else Color(0.65, 0.1, 0.85)
	var claw_glow = Color(1.0, 0.15, 0.2)
	
	for i in range(8):
		var is_right_side = i >= 4
		var side_sign = 1.0 if is_right_side else -1.0
		var leg_idx = i % 4
		var hip = Vector2(22.0 * side_sign, -12.0 + leg_idx * 7.0)
		
		var phase = anim_timer * (8.0 if is_stunned else 12.0) + i * (PI * 0.5)
		var lift = max(0.0, sin(phase)) * (16.0 if current_state == BossState.SKITTER else 6.0)
		var reach = cos(phase) * 8.0
		
		var knee_offset = Vector2((38.0 + leg_idx * 6.0) * side_sign + reach, -42.0 - lift)
		var claw_offset = Vector2((58.0 + leg_idx * 8.0) * side_sign + reach * 1.5, 24.0 - lift * 0.4)
		
		if is_dormant:
			# 🎭 沉睡过场恐怖伸展：蛛腿随气场张开抖动
			var flex = sin(anim_timer * 10.0 + i) * 6.0
			knee_offset = Vector2((32.0 + leg_idx * 5.0) * side_sign + flex, -35.0 - flex)
			claw_offset = Vector2((48.0 + leg_idx * 6.0) * side_sign, -65.0)
		elif is_stunned:
			knee_offset = Vector2((30.0 + leg_idx * 5.0) * side_sign, 10.0 + sin(anim_timer * 10.0 + i) * 4.0)
			claw_offset = Vector2((45.0 + leg_idx * 6.0) * side_sign, 32.0)
		elif current_state == BossState.POUNCE or current_state == BossState.INITIAL_POUNCE or current_state == BossState.SKY_LEAP_UP:
			knee_offset = Vector2((52.0 + leg_idx * 6.0) * side_sign, -52.0)
			claw_offset = Vector2((78.0 + leg_idx * 8.0) * side_sign, 38.0)
		elif current_state == BossState.CEILING_HANG:
			knee_offset = Vector2((40.0 + leg_idx * 5.0) * side_sign, -48.0)
			claw_offset = Vector2((55.0 + leg_idx * 6.0) * side_sign, -85.0)
			
		var knee = hip + knee_offset
		var claw = hip + claw_offset
		
		draw_line(hip, knee, leg_color, 7.0)
		draw_circle(knee, 5.0, joint_color)
		draw_line(knee, claw, leg_color, 5.0)
		draw_circle(claw, 4.0, claw_glow)
		
		var barb_dir = Vector2(-side_sign, -1.0).normalized()
		var barb_tip = knee + barb_dir * 14.0
		draw_line(knee, barb_tip, Color(0.95, 0.1, 0.2), 3.0)

	# ── 2. 狂暴/眩晕气场晕圈 ──
	var aura_r = 42.0 if is_enraged else 34.0
	var aura_color = Color(1.0, 0.9, 0.1, 0.4) if is_stunned else (Color(0.95, 0.1, 0.8, 0.35) if is_enraged else Color(0.4, 0.1, 0.5, 0.2))
	if not is_dormant:
		draw_circle(Vector2(0, 0), aura_r, aura_color)
	else:
		draw_circle(Vector2(0, 0), 38.0 + sin(anim_timer * 14.0) * 4.0, Color(0.9, 0.1, 0.2, 0.25))

	# ── 3. 蜘蛛后腹部 (Spider Abdomen & Hourglass Insignia) ──
	var abd_color = Color(0.35, 0.08, 0.45) if not is_enraged else Color(0.65, 0.05, 0.25)
	draw_circle(Vector2(0, 18), 24.0, abd_color)
	draw_circle(Vector2(0, 18), 24.0, Color(0.15, 0.02, 0.2, 0.8), false, 3.0)
	
	var top_tri = PackedVector2Array([Vector2(-8, 8), Vector2(8, 8), Vector2(0, 18)])
	var bot_tri = PackedVector2Array([Vector2(-8, 28), Vector2(8, 28), Vector2(0, 18)])
	var hg_color = PackedColorArray([Color(0.95, 0.15, 0.1)])
	draw_polygon(top_tri, hg_color)
	draw_polygon(bot_tri, hg_color)

	# ── 4. 融合鬼魅头躯 (Terrifying Joker Monster Cephalothorax) ──
	var head_center = Vector2(0, -10)
	
	var hair_pts = PackedVector2Array([
		head_center + Vector2(-26, -10), head_center + Vector2(-22, -32),
		head_center + Vector2(-12, -38), head_center + Vector2(0, -42),
		head_center + Vector2(12, -38), head_center + Vector2(22, -32),
		head_center + Vector2(26, -10), head_center + Vector2(20, -5),
		head_center + Vector2(-20, -5)
	])
	draw_polygon(hair_pts, PackedColorArray([Color(0.1, 0.9, 0.25)]))
	
	var face_color = Color(1.0, 0.9, 0.4) if is_stunned else Color(0.95, 0.95, 0.92)
	var face_poly = PackedVector2Array([
		head_center + Vector2(-20, -12), head_center + Vector2(0, -28),
		head_center + Vector2(20, -12), head_center + Vector2(16, 12),
		head_center + Vector2(0, 20), head_center + Vector2(-16, 12)
	])
	draw_polygon(face_poly, PackedColorArray([face_color]))
	draw_polyline(face_poly, Color(0.2, 0.1, 0.25), 2.0)
	
	var eye_y = head_center.y - 12.0
	var eye_color = (Color(1.0, 0.2, 0.1) if is_stunned else Color(0.1, 0.95, 0.95))
	draw_circle(Vector2(-9.0 * flip, eye_y), 4.5, eye_color)
	draw_circle(Vector2(9.0 * flip, eye_y), 4.5, eye_color)
	draw_circle(Vector2(-9.0 * flip, eye_y), 2.0, Color(1.0, 1.0, 1.0))
	draw_circle(Vector2(9.0 * flip, eye_y), 2.0, Color(1.0, 1.0, 1.0))
	
	var spider_eye_c = Color(1.0, 0.1, 0.15)
	draw_circle(Vector2(-14.0 * flip, eye_y - 6.0), 2.5, spider_eye_c)
	draw_circle(Vector2(14.0 * flip, eye_y - 6.0), 2.5, spider_eye_c)
	draw_circle(Vector2(-4.0 * flip, eye_y - 8.0), 2.5, spider_eye_c)
	draw_circle(Vector2(4.0 * flip, eye_y - 8.0), 2.5, spider_eye_c)
	draw_circle(Vector2(-16.0 * flip, eye_y + 2.0), 2.0, spider_eye_c)
	draw_circle(Vector2(16.0 * flip, eye_y + 2.0), 2.0, spider_eye_c)

	# 💫 眩晕状态下头顶悬浮 3 颗旋转金星芒
	if is_stunned:
		_draw_stun_stars(head_center + Vector2(0, -50))

	# ── 5. 面部血盆大口与锯齿獠牙 ──
	var mouth_y = head_center.y + 4.0
	var maw_open_h = 6.0 + jaw_open_amount * 24.0
	var mouth_w = 36.0
	var mouth_rect = Rect2(-mouth_w / 2.0, mouth_y, mouth_w, maw_open_h)
	
	draw_rect(Rect2(-mouth_w / 2.0 - 2.0, mouth_y - 2.0, mouth_w + 4.0, maw_open_h + 4.0), Color(0.95, 0.05, 0.1))
	draw_rect(mouth_rect, Color(0.2, 0.02, 0.04))
	
	var teeth_count = 6
	for t in range(teeth_count):
		var tx = -mouth_w / 2.0 + 2.0 + t * 5.5
		var top_t = PackedVector2Array([Vector2(tx, mouth_y), Vector2(tx + 4.5, mouth_y), Vector2(tx + 2.25, mouth_y + min(maw_open_h * 0.45, 11.0))])
		draw_polygon(top_t, PackedColorArray([Color(1.0, 0.9, 0.2)]))
		var bot_t = PackedVector2Array([Vector2(tx, mouth_y + maw_open_h), Vector2(tx + 4.5, mouth_y + maw_open_h), Vector2(tx + 2.25, mouth_y + maw_open_h - min(maw_open_h * 0.45, 11.0))])
		draw_polygon(bot_t, PackedColorArray([Color(1.0, 0.9, 0.2)]))
		
	if jaw_open_amount > 0.2:
		var drop_y = mouth_y + maw_open_h + sin(anim_timer * 16.0) * 4.0
		draw_circle(Vector2(-mouth_w / 2.0, drop_y), 2.5, Color(0.9, 0.1, 0.15))
		draw_circle(Vector2(mouth_w / 2.0, drop_y + 3.0), 2.5, Color(0.9, 0.1, 0.15))

	# ⚡ 反击风暴状态下绘制红闪电电弧
	if current_state == BossState.COUNTER_SWIPE:
		for k in range(5):
			var a1 = randf_range(-60, 60)
			var a2 = randf_range(-60, 60)
			draw_line(Vector2(a1, -30), Vector2(a2, 30), Color(1.0, 0.2, 0.1, 0.9), 3.0)

func _draw_stun_stars(center_pos: Vector2):
	"""绘制眩晕悬浮金星 (Dizzy Stars)"""
	var count = 3
	for i in range(count):
		var angle = anim_timer * 8.0 + i * (PI * 2.0 / count)
		var star_pos = center_pos + Vector2(cos(angle) * 22.0, sin(angle) * 8.0)
		draw_circle(star_pos, 3.5, Color(1.0, 0.95, 0.2))
		draw_circle(star_pos, 1.5, Color(1.0, 1.0, 0.9))

func hit_by_batarang(damage: int = 1):
	"""被远程蝙蝠飞镖击中 (造成 1 点削血伤害，刚好是近战 10 点伤害的 1/10)"""
	if not alive or current_state == BossState.DORMANT:
		return
		
	if current_state == BossState.STUNNED:
		_apply_damage(damage, "-1 💥 BATARANG")
	else:
		# 非破防状态下，飞镖进行 1 点微弱 Chip 削血
		_apply_chip_damage(damage, "-1 💥 CHIP")

func hit_by_melee(damage: int = 10):
	"""被近战斩击重创 (造成 10 点核心力道重创，为远程飞镖伤害的 10 倍)"""
	_apply_damage(damage, "-10 ⚔️ CRITICAL CRUSH!")

func _apply_chip_damage(damage: int, text_str: String):
	"""非破防状态下的飞镖微弱削血 (1/10 伤害)"""
	if invincible_timer > 0:
		return
	hp -= damage
	invincible_timer = 0.15
	
	modulate = Color(2.0, 2.0, 2.0)
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_floating_text"):
		var display_text = text_str if hp > 0 else "💀 SPIDER JOKER SLAIN!"
		game._spawn_floating_text(global_position, display_text, Color(0.9, 0.9, 0.9))
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(0.3, 0.8, 1.0))
		
	if hp <= 0:
		_die_boss()
	else:
		queue_redraw()

func _apply_damage(damage: int, text_str: String):
	if not alive or current_state == BossState.DORMANT:
		return
		
	# 🌟 核心魂斗罗机制：常态护甲防御，非 STUNNED 眩晕破防状态下近战会被护甲弹刀
	if current_state != BossState.STUNNED:
		_spawn_armor_block_effects()
		return
		
	if invincible_timer > 0:
		return
		
	hp -= damage
	invincible_timer = 0.2
	
	modulate = Color(3.5, 3.5, 3.5)
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.12)
	
	var game = get_tree().current_scene
	if game and game.has_method("add_camera_shake"):
		game.add_camera_shake(12.0, 0.22)
	if game and game.has_method("trigger_hit_stop"):
		game.trigger_hit_stop(0.06)
		
	if game and game.has_method("_spawn_floating_text"):
		var display_text = text_str if hp > 0 else "💀 SPIDER JOKER SLAIN!"
		game._spawn_floating_text(global_position, display_text, Color(1.0, 0.2, 0.2))
		
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(1.0, 0.9, 0.1))
		game._spawn_particle_burst(global_position, Color(0.3, 0.9, 1.0))
		
	if hp <= 0:
		_die_boss()
	else:
		queue_redraw()

func _spawn_armor_block_effects():
	"""触发金属护甲弹刀 0 伤害特效 (Armored Block Sparks)"""
	var game = get_tree().current_scene
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(0.9, 0.9, 0.95))
		game._spawn_particle_burst(global_position, Color(0.3, 0.8, 1.0))
	if game and game.has_method("_spawn_floating_text"):
		game._spawn_floating_text(global_position + Vector2(0, -35), "🛡️ ARMORED! (0 DMG)", Color(0.7, 0.8, 0.9))
	if game and game.has_method("trigger_hit_stop"):
		game.trigger_hit_stop(0.04)

func _on_body_entered(body):
	if not alive or current_state == BossState.DORMANT:
		return
	if body.is_in_group("player"):
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)

func _die_boss():
	alive = false
	set_physics_process(false)
	monitoring = false
	
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	
	var game = get_tree().current_scene
	for i in range(6):
		if game and game.has_method("_spawn_particle_burst"):
			var off = Vector2(randf_range(-40, 40), randf_range(-30, 30))
			game._spawn_particle_burst(global_position + off, Color(0.05, 0.05, 0.1))
			game._spawn_particle_burst(global_position + off, Color(0.8, 0.1, 0.2))
	
	if game and game.has_method("_on_boss_defeated"):
		game._on_boss_defeated(self)
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.5, 0.1), 0.45)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
