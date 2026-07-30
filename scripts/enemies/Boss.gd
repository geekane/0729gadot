extends Area2D

# 🕷️ 八脚血盆大口蜘蛛小丑大 Boss (Spider-Joker Nightmare Monster Boss)
# 0.7 倍体型尺寸、恐怖表情过场演出、1/10 飞镖刮痧/10点近战重创、砸地眩晕暴露弱点破防

const JokerCard = preload("res://scripts/projectiles/JokerCard.gd")
const SpiderWeb = preload("res://scripts/projectiles/SpiderWeb.gd")
const BossPixel = preload("res://scripts/enemies/BossPixel.gd")
const BPW = 80
const BPH = 60

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

var pixel_mode = true
var _pixel_sprite: Sprite2D = null
var _boss_pixel: BossPixel = null  # utility instance, not a node
var _anim_sprite: AnimatedSprite2D = null  # 🎬 主流 AnimatedSprite2D 关键帧动画节点

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
	
	# 📐 巨型 Boss 体型巨大化升级 (1.75x → 2.6x 超强压迫感)
	scale = Vector2(2.6, 2.6)
	
	# 碰撞体 (80x80)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 80)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	# 🎬 1. 初始化 Godot 标配 AnimatedSprite2D 关键帧动画系统 (Keyframe Animation)
	_setup_keyframe_animation()

	# 像素精灵 (已禁用以使用纯净关键帧 AnimatedSprite2D)
	_pixel_sprite = Sprite2D.new()
	_pixel_sprite.name = "PixelSprite"
	_pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pixel_sprite.centered = false
	_pixel_sprite.position = Vector2(-BPW / 2, -BPH / 2)
	_pixel_sprite.visible = false
	add_child(_pixel_sprite)
	
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
		
	if Input.is_action_just_pressed("toggle_pixel"):
		pixel_mode = not pixel_mode
		_pixel_sprite.visible = pixel_mode
		_boss_pixel.reset_cache()
		var g = get_tree().current_scene
		if g and g.has_method("_spawn_floating_text"):
			var msg = "🟦 PIXEL MODE" if pixel_mode else "⬜ VECTOR MODE"
			g._spawn_floating_text(global_position + Vector2(0, -70), msg, Color(0.3, 0.9, 1.0) if pixel_mode else Color(0.9, 0.9, 0.9))
		
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
	
	if pixel_mode and _pixel_sprite and _boss_pixel:
		var state_info = {
			"enraged": hp <= 50,
			"dormant": current_state == BossState.DORMANT,
			"stunned": current_state == BossState.STUNNED,
			"jaw": jaw_open_amount,
			"t": anim_timer,
			"dir": facing_dir,
			"state": _state_name(current_state),
			"sky_drop_warn": current_state == BossState.SKY_DROP_CRASH and sky_drop_warn_timer > 0
		}
		_pixel_sprite.texture = _boss_pixel.generate(state_info)
	
	# 🎬 驱动 AnimatedSprite2D 关键帧动画系统 (Keyframe Animation Update)
	_update_keyframe_animation()

	queue_redraw()

func _setup_keyframe_animation():
	"""动态构建与初始化 SpriteFrames 关键帧动画序列 (Keyframe Animation)"""
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.name = "BossAnimatedSprite"
	_anim_sprite.centered = true
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var sf = SpriteFrames.new()
	var anim_config = {
		"idle": {"speed": 8.0, "count": 4},
		"attack": {"speed": 10.0, "count": 4},
		"stunned": {"speed": 6.0, "count": 4},
		"enraged": {"speed": 10.0, "count": 4}
	}
	
	for anim_name in anim_config.keys():
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, anim_config[anim_name]["speed"])
		sf.set_animation_loop(anim_name, true)
		for i in range(anim_config[anim_name]["count"]):
			var frame_path = "res://assets/boss_anim/%s_%d.png" % [anim_name, i]
			if ResourceLoader.exists(frame_path):
				var tex = load(frame_path)
				sf.add_frame(anim_name, tex)
				
	_anim_sprite.sprite_frames = sf
	_anim_sprite.scale = Vector2(1.15, 1.15)
	# 🎯 节点位置 Y 偏移：确保 2.6x 巨大化小丑的 8 条蛛腿脚爪紧贴地面 Physical Ground Line
	_anim_sprite.position = Vector2(0, -52.0)
	_anim_sprite.play("idle")
	add_child(_anim_sprite)

func _update_keyframe_animation():
	"""根据 Boss 当前战斗状态控制 Keyframe 关键帧动画播放"""
	if not _anim_sprite or not is_instance_valid(_anim_sprite):
		return
		
	# 🎯 左右方向朝向翻转：关键帧素材默认朝右，玩家在左侧(facing_dir < 0)时需翻转朝左正对蝙蝠侠
	_anim_sprite.flip_h = (facing_dir < 0.0)
	
	var target_anim = "idle"
	if current_state == BossState.STUNNED:
		target_anim = "stunned"
	elif current_state == BossState.POUNCE or current_state == BossState.INITIAL_POUNCE or current_state == BossState.COUNTER_SWIPE:
		target_anim = "attack"
	elif hp <= 50:
		target_anim = "enraged"
	else:
		target_anim = "idle"
		
	if _anim_sprite.animation != target_anim:
		_anim_sprite.play(target_anim)

func _enter_stunned_state():
	"""进入砸地眩晕破防状态"""
	current_state = BossState.STUNNED
	stun_timer = 1.8
	SoundManager.play("melee_hit", -2.0)
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
	SoundManager.play("boss_roar", -2.0)
	
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
	SoundManager.play("boss_roar", -4.0)
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
	
	SoundManager.play("boss_roar", -10.0, randf_range(0.9, 1.1))
	
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
		
	SoundManager.play("boss_roar", -6.0)
	
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

func _state_name(st: BossState) -> String:
	match st:
		BossState.DORMANT: return "DORMANT"
		BossState.INITIAL_POUNCE: return "INITIAL_POUNCE"
		BossState.SKITTER: return "SKITTER"
		BossState.CEILING_HANG: return "CEILING_HANG"
		BossState.POUNCE: return "POUNCE"
		BossState.SKY_LEAP_UP: return "SKY_LEAP_UP"
		BossState.SKY_DROP_CRASH: return "SKY_DROP_CRASH"
		BossState.STUNNED: return "STUNNED"
		BossState.COUNTER_SWIPE: return "COUNTER_SWIPE"
	return "UNKNOWN"

func _draw():
	if not alive:
		return
		
	# 1. 绘制 Boss 头顶动态血条与状态 Prompt (以关键帧 AnimatedSprite2D 为核心)
	_draw_boss_health_bar()

	# 2. 静止沉睡/倒挂状态下的天花板蛛丝
	if current_state == BossState.DORMANT or current_state == BossState.CEILING_HANG:
		draw_line(Vector2(0, -30), Vector2(0, -200), Color(0.9, 0.95, 1.0, 0.8), 3.0)

	# 3. 从天而降预警锁定圈
	if current_state == BossState.SKY_DROP_CRASH and sky_drop_warn_timer > 0:
		var reticle_pos = Vector2(sky_drop_target_x - position.x, ground_y - position.y)
		var pulse_r = 32.0 + sin(anim_timer * 22.0) * 6.0
		draw_circle(reticle_pos, pulse_r, Color(1.0, 0.1, 0.1, 0.35))
		draw_arc(reticle_pos, pulse_r + 4.0, 0.0, PI * 2.0, 24, Color(1.0, 0.9, 0.2, 0.9), 3.0)
		draw_line(reticle_pos + Vector2(-40, 0), reticle_pos + Vector2(40, 0), Color(1.0, 0.2, 0.2, 0.9), 2.5)
		draw_line(reticle_pos + Vector2(0, -40), reticle_pos + Vector2(0, 40), Color(1.0, 0.2, 0.2, 0.9), 2.5)

	# 4. 眩晕破防状态下头顶悬浮 3 颗旋转金星芒
	if current_state == BossState.STUNNED:
		_draw_stun_stars(Vector2(0, -50))

	# 5. 极速扫击反击风暴状态下绘制红闪电电弧
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

func _draw_boss_health_bar():
	"""绘制 Boss 头顶动态血条与战斗状态 UI (Boss Health Bar & State Banner)"""
	if current_state == BossState.DORMANT:
		return # 沉睡过场时不显示血条
		
	var bar_w = 120.0
	var bar_h = 10.0
	var bar_pos = Vector2(-bar_w / 2.0, -118.0)
	
	# 1. 阴影底衬
	draw_rect(Rect2(bar_pos + Vector2(2, 2), Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.5))
	# 2. 暗色面板背景
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.08, 0.1, 0.16, 0.9))
	
	# 3. 动态血量百分比
	var hp_ratio = clamp(float(hp) / float(MAX_HP), 0.0, 1.0)
	var fill_w = max(0.0, (bar_w - 2.0) * hp_ratio)
	
	var fill_color = Color(0.9, 0.2, 0.25)
	if current_state == BossState.STUNNED:
		fill_color = Color(1.0, 0.9, 0.15) # 破防耀眼金
	elif hp <= 50:
		var pulse = sin(anim_timer * 14.0) * 0.15
		fill_color = Color(1.0, 0.05 + pulse, 0.05) # 狂暴血红脉冲
	else:
		fill_color = Color(0.85, 0.15, 0.45) # 亮紫红
		
	draw_rect(Rect2(bar_pos + Vector2(1, 1), Vector2(fill_w, bar_h - 2.0)), fill_color)
	# 4. 血条顶层亮光
	if fill_w > 2:
		draw_line(bar_pos + Vector2(1, 2), bar_pos + Vector2(fill_w, 2), Color(1.0, 1.0, 1.0, 0.45), 1.0)
		
	# 5. 边框 (破防时亮黄，狂暴时金红，平时亮青)
	var border_c = Color(1.0, 0.9, 0.2, 0.95) if current_state == BossState.STUNNED else (Color(1.0, 0.2, 0.1, 0.9) if hp <= 50 else Color(0.3, 0.85, 1.0, 0.75))
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2.0, bar_h + 2.0)), border_c, false, 1.5)

	# 6. 破防 / 狂暴 状态指示标志 (Vulnerable / Enraged Indicator)
	if current_state == BossState.STUNNED:
		var v_pos = Vector2(0, -135.0 + sin(anim_timer * 15.0) * 2.5)
		draw_circle(v_pos + Vector2(-32, 0), 3.5, Color(1.0, 0.9, 0.1))
		draw_circle(v_pos + Vector2(32, 0), 3.5, Color(1.0, 0.9, 0.1))
		draw_line(v_pos + Vector2(-28, 0), v_pos + Vector2(-15, 0), Color(1.0, 0.9, 0.2, 0.8), 2.0)
		draw_line(v_pos + Vector2(15, 0), v_pos + Vector2(28, 0), Color(1.0, 0.9, 0.2, 0.8), 2.0)
	elif hp <= 50:
		var e_pos = Vector2(0, -95.0)
		draw_circle(e_pos + Vector2(-34, 0), 3.0, Color(1.0, 0.2, 0.1))
		draw_circle(e_pos + Vector2(34, 0), 3.0, Color(1.0, 0.2, 0.1))

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
	
	SoundManager.play("boss_hit", -6.0)
	
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
	
	SoundManager.play("melee_hit", -2.0)
	SoundManager.play("boss_hit", -4.0)
	
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
	SoundManager.play("menu_hover", -3.0)
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
	
	SoundManager.play("boss_death")
	
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
	tween.chain().tween_callback(queue_free)
