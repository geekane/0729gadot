extends Node2D

const Coin = preload("res://scripts/objects/Coin.gd")
const Enemy = preload("res://scripts/enemies/Enemy.gd")
const Player = preload("res://scripts/Player.gd")
const FlyEnemy = preload("res://scripts/enemies/FlyEnemy.gd")
const Hazard = preload("res://scripts/objects/Hazard.gd")
const MovingPlatform = preload("res://scripts/objects/MovingPlatform.gd")
const Boss = preload("res://scripts/enemies/Boss.gd")
const PixelConfig = preload("res://scripts/lib/pixel_config.gd")
const PixelBackground = preload("res://scripts/lib/pixel_background.gd")
const GothamBgLayers = preload("res://scripts/lib/gotham_bg_layers.gd")
const BgSingle = preload("res://scripts/lib/bg_single.gd")
const PixelLib = preload("res://scripts/lib/pixel_lib.gd")
const ItemDrop = preload("res://scripts/objects/ItemDrop.gd")

func _spawn_item_drop(world_pos: Vector2):
	"""敌人被击败时触发：随机掉落恢复血瓶 ❤️ 或高分水晶 💎"""
	var rand_val = randf()
	if rand_val < 0.45:
		# 45% 概率掉落恢复血瓶
		var drop = ItemDrop.new()
		drop.item_type = "health"
		drop.position = world_pos
		add_child(drop)
	elif rand_val < 0.80:
		# 35% 概率掉落高分水晶
		var drop = ItemDrop.new()
		drop.item_type = "score"
		drop.position = world_pos
		add_child(drop)

enum GameState { MENU, PLAYING, WON, GAME_OVER }

var state = GameState.MENU
var score = 0
var high_score = 0
var lives = 3
var god_mode_enabled = false # 🛡️ 无敌调试模式 (生命无限，方便自主测验)
var is_paused = false
var boss_arena_locked = false
var camera_fixed_boss_arena = false
var _boss_portrait_tween = null  # Boss 肖像脉冲动画引用，用于击败后清理

# 5 关关卡系统配置
var current_level = 1
const MAX_LEVEL = 5

const GROUND_Y = 550

var player_node = null
var camera = null
var score_label = null
var lives_label = null
var high_score_label = null
var level_label = null

var overlay = null
var overlay_label = null
var overlay_hint = null
var pause_overlay = null

var blink_timer = 0.0
var blink_visible = true
var anim_time = 0.0

# 5 关阶梯难度与长度数据表 (所有地面区域均配备 y=465 登高登台，杜绝地面死胡同)
const LEVEL_CONFIGS = {
	1: {
		"name": "教学关：哥谭试炼",
		"width": 1632,
		"platforms": [
			[300, 480, 120, 16], [750, 460, 120, 16], [1200, 450, 120, 16]
		],
		"moving_platforms": [],
		"hazards": [],
		"coins": [
			Vector2(180, 520), Vector2(300, 440), Vector2(500, 520), Vector2(750, 420),
			Vector2(1000, 520), Vector2(1200, 410), Vector2(1450, 520)
		],
		"ground_enemies": [
			{"pos": Vector2(850, 538), "range": 120}
		],
		"fly_enemies": [
			{"pos": Vector2(1150, 260), "range": 80.0}
		]
	},
	2: {
		"name": "兵工厂突袭",
		"width": 2400,
		"platforms": [
			[300, 440, 110, 16], [600, 465, 110, 16], [880, 410, 110, 16], [1150, 465, 110, 16],
			[1450, 410, 110, 16], [1750, 465, 110, 16], [2050, 410, 110, 16], [2250, 350, 110, 16]
		],
		"moving_platforms": [
			{"pos": Vector2(600, 360), "dist": 90.0, "speed": 1.8, "vertical": false},
			{"pos": Vector2(1150, 350), "dist": 75.0, "speed": 1.6, "vertical": true},
			{"pos": Vector2(1450, 330), "dist": 90.0, "speed": 1.8, "vertical": false},
			{"pos": Vector2(1850, 340), "dist": 70.0, "speed": 2.0, "vertical": true}
		],
		"hazards": [Vector2(450, 550), Vector2(920, 550), Vector2(1420, 550), Vector2(1950, 550)],
		"coins": [
			Vector2(200, 410), Vector2(300, 390), Vector2(450, 470), Vector2(600, 310), Vector2(750, 400),
			Vector2(880, 360), Vector2(1000, 450), Vector2(1150, 290), Vector2(1300, 400), Vector2(1450, 280),
			Vector2(1600, 450), Vector2(1750, 410), Vector2(1850, 280), Vector2(2050, 360), Vector2(2250, 300)
		],
		"ground_enemies": [
			{"pos": Vector2(300, 538), "range": 160}, {"pos": Vector2(750, 538), "range": 180},
			{"pos": Vector2(1200, 538), "range": 200}, {"pos": Vector2(1650, 538), "range": 180}, {"pos": Vector2(2100, 538), "range": 180}
		],
		"fly_enemies": [
			{"pos": Vector2(500, 260), "range": 110.0}, {"pos": Vector2(950, 220), "range": 130.0},
			{"pos": Vector2(1450, 240), "range": 120.0}, {"pos": Vector2(1900, 210), "range": 140.0}
		]
	},
	3: {
		"name": "阿卡姆边缘",
		"width": 3200,
		"platforms": [
			[300, 450, 100, 16], [550, 465, 100, 16], [800, 410, 100, 16], [1050, 465, 100, 16],
			[1350, 400, 100, 16], [1650, 465, 100, 16], [1950, 400, 100, 16], [2250, 465, 100, 16],
			[2550, 400, 100, 16], [2850, 465, 100, 16], [3050, 360, 100, 16]
		],
		"moving_platforms": [
			{"pos": Vector2(550, 360), "dist": 100.0, "speed": 2.0, "vertical": false},
			{"pos": Vector2(1050, 350), "dist": 80.0, "speed": 1.8, "vertical": true},
			{"pos": Vector2(1650, 340), "dist": 110.0, "speed": 2.0, "vertical": false},
			{"pos": Vector2(2250, 350), "dist": 80.0, "speed": 2.2, "vertical": true},
			{"pos": Vector2(2850, 340), "dist": 100.0, "speed": 2.0, "vertical": false}
		],
		"hazards": [
			Vector2(420, 550), Vector2(920, 550), Vector2(1450, 550), Vector2(2050, 550),
			Vector2(2650, 550)
		],
		"coins": [
			Vector2(150, 420), Vector2(300, 400), Vector2(420, 470), Vector2(550, 310), Vector2(680, 400),
			Vector2(800, 360), Vector2(920, 470), Vector2(1050, 290), Vector2(1200, 400), Vector2(1350, 340),
			Vector2(1500, 450), Vector2(1650, 280), Vector2(1800, 400), Vector2(1950, 340), Vector2(2100, 450),
			Vector2(2250, 290), Vector2(2400, 400), Vector2(2550, 340), Vector2(2700, 450), Vector2(2850, 280)
		],
		"ground_enemies": [
			{"pos": Vector2(250, 538), "range": 150}, {"pos": Vector2(600, 538), "range": 160},
			{"pos": Vector2(980, 538), "range": 180}, {"pos": Vector2(1350, 538), "range": 180},
			{"pos": Vector2(1750, 538), "range": 190}, {"pos": Vector2(2150, 538), "range": 190},
			{"pos": Vector2(2550, 538), "range": 200}, {"pos": Vector2(2950, 538), "range": 200}
		],
		"fly_enemies": [
			{"pos": Vector2(350, 260), "range": 120.0}, {"pos": Vector2(750, 210), "range": 130.0},
			{"pos": Vector2(1150, 230), "range": 140.0}, {"pos": Vector2(1550, 200), "range": 150.0},
			{"pos": Vector2(1950, 220), "range": 130.0}, {"pos": Vector2(2350, 190), "range": 160.0},
			{"pos": Vector2(2750, 210), "range": 140.0}, {"pos": Vector2(3050, 180), "range": 150.0}
		]
	},
	4: {
		"name": "钟楼决战",
		"width": 4000,
		"platforms": [
			[250, 450, 100, 16], [500, 465, 100, 16], [750, 410, 100, 16], [1000, 465, 100, 16],
			[1300, 400, 100, 16], [1600, 465, 100, 16], [1900, 400, 100, 16], [2200, 465, 100, 16],
			[2500, 400, 100, 16], [2800, 465, 100, 16], [3100, 400, 100, 16], [3400, 465, 100, 16],
			[3750, 360, 100, 16]
		],
		"moving_platforms": [
			{"pos": Vector2(500, 360), "dist": 110.0, "speed": 2.2, "vertical": false},
			{"pos": Vector2(1000, 350), "dist": 90.0, "speed": 2.0, "vertical": true},
			{"pos": Vector2(1600, 340), "dist": 120.0, "speed": 2.2, "vertical": false},
			{"pos": Vector2(2200, 350), "dist": 90.0, "speed": 2.2, "vertical": true},
			{"pos": Vector2(2800, 330), "dist": 120.0, "speed": 2.4, "vertical": false},
			{"pos": Vector2(3400, 350), "dist": 90.0, "speed": 2.2, "vertical": true}
		],
		"hazards": [
			Vector2(380, 550), Vector2(880, 550), Vector2(1450, 550), Vector2(2050, 550),
			Vector2(2650, 550), Vector2(3250, 550), Vector2(3750, 550)
		],
		"coins": [
			Vector2(150, 420), Vector2(250, 400), Vector2(380, 470), Vector2(500, 310), Vector2(620, 400),
			Vector2(750, 360), Vector2(880, 470), Vector2(1000, 290), Vector2(1150, 400), Vector2(1300, 340),
			Vector2(1450, 450), Vector2(1600, 280), Vector2(1750, 400), Vector2(1900, 340), Vector2(2050, 450),
			Vector2(2200, 290), Vector2(2350, 400), Vector2(2500, 340), Vector2(2650, 450), Vector2(2800, 270),
			Vector2(2950, 400), Vector2(3100, 340), Vector2(3250, 450), Vector2(3400, 290), Vector2(3750, 300)
		],
		"ground_enemies": [
			{"pos": Vector2(200, 538), "range": 140}, {"pos": Vector2(550, 538), "range": 150},
			{"pos": Vector2(900, 538), "range": 160}, {"pos": Vector2(1300, 538), "range": 170},
			{"pos": Vector2(1700, 538), "range": 180}, {"pos": Vector2(2100, 538), "range": 180},
			{"pos": Vector2(2500, 538), "range": 180}, {"pos": Vector2(2900, 538), "range": 190},
			{"pos": Vector2(3300, 538), "range": 190}, {"pos": Vector2(3700, 538), "range": 200}
		],
		"fly_enemies": [
			{"pos": Vector2(300, 250), "range": 130.0}, {"pos": Vector2(650, 200), "range": 140.0},
			{"pos": Vector2(1050, 220), "range": 150.0}, {"pos": Vector2(1450, 190), "range": 150.0},
			{"pos": Vector2(1850, 210), "range": 140.0}, {"pos": Vector2(2250, 180), "range": 160.0},
			{"pos": Vector2(2650, 200), "range": 150.0}, {"pos": Vector2(3050, 170), "range": 160.0},
			{"pos": Vector2(3450, 190), "range": 150.0}, {"pos": Vector2(3800, 180), "range": 160.0}
		]
	},
	5: {
		"name": "哥谭守护者",
		"width": 5000,
		"platforms": [
			[250, 450, 100, 16], [500, 465, 100, 16], [750, 410, 100, 16], [1000, 465, 100, 16],
			[1300, 400, 100, 16], [1600, 465, 100, 16], [1900, 400, 100, 16], [2200, 465, 100, 16],
			[2500, 400, 100, 16], [2800, 465, 100, 16], [3100, 400, 100, 16], [3400, 465, 100, 16],
			[3700, 400, 100, 16], [3950, 465, 100, 16]
		],
		"moving_platforms": [
			{"pos": Vector2(500, 360), "dist": 120.0, "speed": 2.4, "vertical": false},
			{"pos": Vector2(1000, 350), "dist": 90.0, "speed": 2.2, "vertical": true},
			{"pos": Vector2(1600, 340), "dist": 130.0, "speed": 2.5, "vertical": false},
			{"pos": Vector2(2200, 350), "dist": 90.0, "speed": 2.4, "vertical": true},
			{"pos": Vector2(2800, 330), "dist": 140.0, "speed": 2.6, "vertical": false},
			{"pos": Vector2(3400, 350), "dist": 90.0, "speed": 2.4, "vertical": true}
		],
		"hazards": [
			Vector2(380, 550), Vector2(880, 550), Vector2(1450, 550), Vector2(2050, 550),
			Vector2(2650, 550), Vector2(3250, 550), Vector2(3850, 550)
		],
		"coins": [
			Vector2(120, 420), Vector2(250, 400), Vector2(380, 470), Vector2(500, 310), Vector2(620, 400),
			Vector2(750, 360), Vector2(880, 470), Vector2(1000, 290), Vector2(1150, 400), Vector2(1300, 340),
			Vector2(1450, 450), Vector2(1600, 280), Vector2(1750, 400), Vector2(1900, 340), Vector2(2050, 450),
			Vector2(2200, 290), Vector2(2350, 400), Vector2(2500, 340), Vector2(2650, 450), Vector2(2800, 270),
			Vector2(2950, 400), Vector2(3100, 340), Vector2(3250, 450), Vector2(3400, 290), Vector2(3550, 400),
			Vector2(3700, 340), Vector2(3850, 450)
		],
		"ground_enemies": [
			{"pos": Vector2(180, 538), "range": 130}, {"pos": Vector2(550, 538), "range": 140},
			{"pos": Vector2(950, 538), "range": 150}, {"pos": Vector2(1350, 538), "range": 160},
			{"pos": Vector2(1750, 538), "range": 160}, {"pos": Vector2(2150, 538), "range": 170},
			{"pos": Vector2(2550, 538), "range": 170}, {"pos": Vector2(2950, 538), "range": 180},
			{"pos": Vector2(3350, 538), "range": 150}
		],
		"fly_enemies": [
			{"pos": Vector2(300, 250), "range": 120.0}, {"pos": Vector2(650, 200), "range": 130.0},
			{"pos": Vector2(1050, 220), "range": 140.0}, {"pos": Vector2(1450, 190), "range": 140.0},
			{"pos": Vector2(1850, 210), "range": 150.0}, {"pos": Vector2(2250, 180), "range": 150.0},
			{"pos": Vector2(2650, 200), "range": 140.0}, {"pos": Vector2(3050, 170), "range": 160.0},
			{"pos": Vector2(3450, 190), "range": 130.0}
		]
	}
}

# ─── 状态管理 ──────────────────────────────────────

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 像素风渲染设置（NEAREST 滤波）
	PixelConfig.apply(get_viewport())
	RenderingServer.set_default_clear_color(Color(0.08, 0.1, 0.2, 1.0))
	_load_high_score()
	_create_menu()

var shake_intensity = 0.0
var shake_timer = 0.0

func add_camera_shake(intensity: float, duration: float = 0.15):
	shake_intensity = max(shake_intensity, intensity)
	shake_timer = max(shake_timer, duration)

func trigger_hit_stop(duration: float = 0.05):
	Engine.time_scale = 0.05
	var timer = get_tree().create_timer(duration * 0.05, true, false, true)
	timer.timeout.connect(_on_hit_stop_timer_end)

func _on_hit_stop_timer_end():
	Engine.time_scale = 1.0

func _process(delta):
	anim_time += delta
	_update_bg_effects(delta)
	match state:
		GameState.MENU:
			_blink_step(delta)
			var logo = find_child("MenuLogo", true, false)
			if logo and is_instance_valid(logo):
				logo.position.y = 35.0 + sin(anim_time * 2.0) * 4.0
			if Input.is_action_just_pressed("ui_accept"):
				_start_game()
		GameState.PLAYING:
			# 镜头平滑跟随玩家 (使用 lerp 插值 + Trauma 衰减震动偏移)
			if camera and player_node and is_instance_valid(camera) and is_instance_valid(player_node):
				var weight = clamp(12.0 * delta, 0.0, 1.0)
				var target_pos = Vector2(4550, 324) if camera_fixed_boss_arena else player_node.position
				
				if shake_timer > 0:
					shake_timer -= delta
					var shake_offset = Vector2(
						randf_range(-shake_intensity, shake_intensity),
						randf_range(-shake_intensity, shake_intensity)
					)
					target_pos += shake_offset
					shake_intensity = move_toward(shake_intensity, 0.0, delta * 30.0)
				else:
					shake_intensity = 0.0
					
				camera.position = camera.position.lerp(target_pos, weight)
				
				# Level 5 决战竞技场早触发 (x >= 4050 看到 Boss 一角即触发电影级运镜)
				if current_level == 5 and not boss_arena_locked and player_node.position.x >= 4050:
					_lock_boss_arena()
					
				# 掉落死亡判定
				if player_node.position.y > GROUND_Y + 100:
					_on_player_hit(player_node)
		GameState.WON, GameState.GAME_OVER:
			_blink_step(delta)
			if Input.is_action_just_pressed("ui_accept"):
				_go_back_menu()

func _update_bg_effects(delta):
	# 1. 探照灯与云层蝙蝠徽标 Projection 动态摇摆
	var bat_signal = find_child("BatSignalBeam", true, false)
	if bat_signal and is_instance_valid(bat_signal):
		bat_signal.set_meta("sweep_angle", anim_time * 0.5)
		bat_signal.set_meta("flicker", 0.85 + sin(anim_time * 5.0) * 0.15)
		bat_signal.queue_redraw()
		
			
	# 3. 漂移云层平移
	var cloud_nodes = get_tree().get_nodes_in_group("drifting_clouds")
	for c in cloud_nodes:
		if is_instance_valid(c):
			c.position.x += 12.0 * delta
			if c.position.x > 5500:
				c.position.x = -300

func _unhandled_input(event):
	if state == GameState.PLAYING:
		if event.is_action_pressed("ui_cancel"):
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif is_paused and event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R:
				_toggle_pause()
				_start_level(current_level)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_M:
				_toggle_pause()
				_go_back_menu()
				get_viewport().set_input_as_handled()

func _blink_step(delta):
	if not overlay_hint or not is_instance_valid(overlay_hint):
		return
	blink_timer += delta
	if blink_timer > 0.6:
		blink_timer = 0.0
		blink_visible = not blink_visible
		overlay_hint.modulate.a = 0.95 if blink_visible else 0.35

# ─── 本地最高分存储 ────────────────────────────────

func _load_high_score():
	var config = ConfigFile.new()
	if config.load("user://high_score.cfg") == OK:
		high_score = config.get_value("game", "high_score", 0)
	else:
		high_score = 0

func _save_high_score():
	var config = ConfigFile.new()
	config.set_value("game", "high_score", high_score)
	config.save("user://high_score.cfg")

# ─── 菜单 ──────────────────────────────────────────

static func _create_vector_icon(type: String, custom_size: Vector2 = Vector2(24, 24)) -> Control:
	var icon = Control.new()
	icon.custom_minimum_size = custom_size
	icon.size = custom_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("icon_type", type)
	icon.draw.connect(func():
		var t = icon.get_meta("icon_type")
		match t:
			"heart_full":
				var pts = PackedVector2Array([
					Vector2(12, 20), Vector2(3, 11), Vector2(3, 6), Vector2(7, 3),
					Vector2(12, 7), Vector2(17, 3), Vector2(21, 6), Vector2(21, 11)
				])
				icon.draw_polygon(pts, PackedColorArray([Color(0.95, 0.15, 0.25)]))
				icon.draw_polyline(pts, Color(0.6, 0.05, 0.1), 1.5)
			"heart_empty":
				var pts = PackedVector2Array([
					Vector2(12, 20), Vector2(3, 11), Vector2(3, 6), Vector2(7, 3),
					Vector2(12, 7), Vector2(17, 3), Vector2(21, 6), Vector2(21, 11)
				])
				icon.draw_polygon(pts, PackedColorArray([Color(0.2, 0.22, 0.28, 0.8)]))
				icon.draw_polyline(pts, Color(0.4, 0.45, 0.55), 1.5)
			"coin":
				icon.draw_circle(Vector2(12, 12), 10.0, Color(1.0, 0.85, 0.1))
				icon.draw_circle(Vector2(12, 12), 7.5, Color(0.9, 0.7, 0.0))
				icon.draw_rect(Rect2(10, 8, 4, 8), Color(1.0, 0.95, 0.4))
			"crown":
				var pts = PackedVector2Array([
					Vector2(3, 18), Vector2(3, 8), Vector2(8, 13), Vector2(12, 5),
					Vector2(16, 13), Vector2(21, 8), Vector2(21, 18)
				])
				icon.draw_polygon(pts, PackedColorArray([Color(1.0, 0.8, 0.1)]))
				icon.draw_polyline(pts, Color(0.8, 0.6, 0.0), 1.5)
				icon.draw_circle(Vector2(12, 5), 2.0, Color(1.0, 0.95, 0.8))
			"bat":
				icon.draw_circle(Vector2(12, 12), 10.0, Color(1.0, 0.85, 0.1))
				var wings = PackedVector2Array([
					Vector2(5, 11), Vector2(8, 9), Vector2(12, 12), Vector2(16, 9), Vector2(19, 11),
					Vector2(17, 15), Vector2(12, 16), Vector2(7, 15)
				])
				icon.draw_polygon(wings, PackedColorArray([Color(0.1, 0.1, 0.15)]))
			"flag":
				icon.draw_line(Vector2(5, 4), Vector2(5, 21), Color(0.8, 0.85, 0.9), 2.5)
				var flag_pts = PackedVector2Array([Vector2(6, 4), Vector2(19, 8), Vector2(6, 13)])
				icon.draw_polygon(flag_pts, PackedColorArray([Color(0.15, 0.85, 0.35)]))
	)
	return icon

static func _create_pixel_icon(type: String, custom_size: Vector2 = Vector2(24, 24)) -> TextureRect:
	"""用像素图替代矢量 Icon，返回 TextureRect"""
	var tr = TextureRect.new()
	tr.custom_minimum_size = custom_size
	tr.size = custom_size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 放大纹理以适应控件大小，同时保持 NEAREST 滤波
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 调色板定义
	var heart_pal = { "R": Color(0.95, 0.15, 0.25), ".": Color.TRANSPARENT }
	var heart_empty_pal = { "L": Color(0.4, 0.45, 0.55), "D": Color(0.2, 0.22, 0.28), ".": Color.TRANSPARENT }
	var gold_pal = { "Y": Color(1.0, 0.85, 0.1), ".": Color.TRANSPARENT }
	var circle_pal = { "C": Color(1.0, 0.85, 0.1), ".": Color.TRANSPARENT }
	var bat_pal = { "C": Color(1.0, 0.85, 0.1), "B": Color(0.1, 0.1, 0.15), ".": Color.TRANSPARENT }
	var flag_pal = { "F": Color(0.15, 0.85, 0.35), "P": Color(0.8, 0.85, 0.9), ".": Color.TRANSPARENT }

	var pixels: Array[String] = []
	var palette: Dictionary = {}

	match type:
		"heart_full":
			palette = heart_pal
			pixels = [
				"............",
				"............",
				"...RR..RR...",
				"..RRRRRRRR..",
				"..RRRRRRRR..",
				"..RRRRRRRR..",
				"...RRRRRR...",
				"....RRRR....",
				".....RR.....",
				"......R.....",
				"............",
				"............"
			]
		"heart_empty":
			palette = heart_empty_pal
			pixels = [
				"............",
				"............",
				"...LL..LL...",
				"..LDDDLDDL..",
				"..LDDDDDDL..",
				"..LDDDDDDL..",
				"...LDDDDL...",
				"....LDDL....",
				".....LL.....",
				"......L.....",
				"............",
				"............"
			]
		"coin":
			palette = circle_pal
			pixels = [
				"............",
				"....CCC.....",
				"...CCCCC....",
				"..CCCCCCC...",
				"..CCCCCCCC..",
				".CCCCCCCCC..",
				".CCCCCCCCC..",
				"..CCCCCCCC..",
				"..CCCCCCCC..",
				"...CCCCC....",
				"....CCC.....",
				"............"
			]
		"crown":
			palette = gold_pal
			pixels = [
				"............",
				"..Y.....Y...",
				".YYY...YYY..",
				"YYYYYYYYYYYY",
				"YYYYYYYYYYYY",
				"YYYYYYYYYYYY",
				".YYYYYYYYYY.",
				"..YYYYYYYY..",
				"...YYYYYY...",
				"....YYYY....",
				"....YYYY....",
				"............"
			]
		"bat":
			palette = bat_pal
			pixels = [
				"............",
				"....CCC.....",
				"...CCCCC....",
				"..CCCCCCC...",
				"..CCBBCCC...",
				".CCBBBBBC...",
				".CBBBBBBBC..",
				"..CBBBBBBC..",
				"..CCBBCCC...",
				"...CCBCC....",
				"....CCC.....",
				"............"
			]
		"flag":
			palette = flag_pal
			pixels = [
				"............",
				"..P..F......",
				"..P..FF.....",
				"..P..FFF....",
				"..P..F......",
				"..P.........",
				"..P.........",
				"..P.........",
				"..P.........",
				"..P.........",
				"............",
				"............"
			]

	var tex = PixelLib.create_texture(12, 12, pixels, palette)
	tr.texture = tex
	return tr

func _create_menu():
	state = GameState.MENU
	is_paused = false
	get_tree().paused = false
	blink_timer = 0.0
	blink_visible = true
	
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.22, 1.0)
	bg.size = Vector2(2400, 1600)
	bg.position = Vector2(-400, -300)
	bg.name = "MenuBG"
	add_child(bg)
	
	var stars = Node2D.new()
	stars.name = "Stars"
	for i in range(50):
		var star = ColorRect.new()
		star.color = Color(1.0, 1.0, 1.0, randf_range(0.25, 0.75))
		var s = randf_range(2.0, 4.5)
		star.size = Vector2(s, s)
		star.position = Vector2(randf_range(0, 1152), randf_range(0, 648))
		stars.add_child(star)
	add_child(stars)

	# 🌆 下一层级：抽象少色块哥谭夜景底图 (Abstract Min-Color Background)
	if ResourceLoader.exists("res://assets/menu_bg_abstract.png"):
		var bg_tex = load("res://assets/menu_bg_abstract.png")
		var bg_tr = TextureRect.new()
		bg_tr.texture = bg_tex
		bg_tr.size = Vector2(1152, 648)
		bg_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tr.stretch_mode = TextureRect.STRETCH_SCALE
		bg_tr.modulate = Color(0.85, 0.9, 1.0, 0.88)
		add_child(bg_tr)

	# 哥谭菜单背景探照灯 (Bat-Signal Beam & Projected Emblem)
	var menu_bat_signal = Node2D.new()
	menu_bat_signal.name = "BatSignalBeam"
	menu_bat_signal.set_meta("sweep_angle", 0.0)
	menu_bat_signal.set_meta("flicker", 1.0)
	menu_bat_signal.draw.connect(func():
		var angle = menu_bat_signal.get_meta("sweep_angle")
		var flk = menu_bat_signal.get_meta("flicker")
		var base_pos = Vector2(576, 620)
		var top_center = Vector2(576 + sin(angle) * 250.0, 80)
		
		# 光束
		var beam_pts = PackedVector2Array([
			base_pos + Vector2(-20, 0),
			top_center + Vector2(-110, 0),
			top_center + Vector2(110, 0),
			base_pos + Vector2(20, 0)
		])
		menu_bat_signal.draw_polygon(beam_pts, PackedColorArray([Color(1.0, 0.9, 0.3, 0.09 * flk)]))
		
		# 云层发光黄晕
		menu_bat_signal.draw_circle(top_center, 55.0, Color(1.0, 0.88, 0.25, 0.45 * flk))
		menu_bat_signal.draw_circle(top_center, 40.0, Color(1.0, 0.95, 0.5, 0.7 * flk))
	)
	add_child(menu_bat_signal)
	
	# 🦇 顶部悬浮全中文标题 Logo (chinese_title_logo.png)
	if ResourceLoader.exists("res://assets/ui/chinese_title_logo.png"):
		var logo_tex = load("res://assets/ui/chinese_title_logo.png")
		var logo_tr = TextureRect.new()
		logo_tr.texture = logo_tex
		logo_tr.name = "MenuLogo"
		logo_tr.custom_minimum_size = Vector2(460, 140)
		logo_tr.size = Vector2(460, 140)
		logo_tr.position = Vector2(346, 30)
		logo_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(logo_tr)
	else:
		var title_lbl = Label.new()
		title_lbl.text = "蝙蝠侠：哥谭出击"
		title_lbl.add_theme_font_size_override("font_size", 36)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
		title_lbl.position = Vector2(346, 60)
		add_child(title_lbl)

	# 全中文艺术按钮配置 (绑定切片出的中文 TextureButton 元素)
	var texture_btn_configs = [
		{"tex_path": "res://assets/ui/chinese_btn_start.png", "pos": Vector2(416, 190), "action": func(): _start_game()},
		{"tex_path": "res://assets/ui/chinese_btn_level.png", "pos": Vector2(416, 270), "action": func(): _show_level_select_dialog()},
		{"tex_path": "res://assets/ui/chinese_btn_controls.png", "pos": Vector2(416, 350), "action": func(): _show_controls_dialog()},
		{"tex_path": "res://assets/ui/chinese_btn_scores.png", "pos": Vector2(416, 430), "action": func(): _show_high_score_dialog()},
		{"tex_path": "res://assets/ui/chinese_btn_exit.png", "pos": Vector2(416, 510), "action": func(): get_tree().quit()}
	]
	
	for cfg in texture_btn_configs:
		var btn = TextureButton.new()
		var btn_w = 320.0
		var btn_h = 68.0
		
		if ResourceLoader.exists(cfg["tex_path"]):
			var tex = load(cfg["tex_path"])
			btn.texture_normal = tex
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_SCALE
		
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.size = Vector2(btn_w, btn_h)
		btn.position = cfg["pos"]
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
		# 🎯 极其关键：设置 Pivoted Offset 在中央，保证按钮以中心为原点平滑放大缩小 (NO Offset Drift)
		btn.pivot_offset = Vector2(btn_w / 2.0, btn_h / 2.0)
		
		# 悬停放大 1.15x 与缩回 1.0x 的动态 Tween 动画
		btn.mouse_entered.connect(func():
			_play_sound("menu_hover")
			var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15)
		)
		btn.mouse_exited.connect(func():
			var tween = create_tween().set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
		)
		
		# 按压弹跳 + 页面跳转
		var action_func = cfg["action"]
		btn.pressed.connect(func():
			_play_sound("menu_click")
			var press_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			press_tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
			press_tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.08)
			press_tween.chain().tween_callback(func(): action_func.call())
		)
		
		add_child(btn)

	overlay = CanvasLayer.new()
	overlay.name = "Overlay"
	overlay_label = Label.new()
	overlay_label.text = "点击上方艺术按钮 或 按 空格键 开启出击"
	overlay_label.add_theme_font_size_override("font_size", 18)
	overlay_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 0.9))
	overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	overlay_label.add_theme_constant_override("outline_size", 3)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.position = Vector2(246, 595)
	overlay_label.size = Vector2(660, 35)
	overlay.add_child(overlay_label)
	add_child(overlay)
	overlay_hint = overlay_label

func _show_controls_dialog():
	var dialog = CanvasLayer.new()
	dialog.name = "ControlsDialog"
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(2400, 1600)
	bg.position = Vector2(-400, -300)
	dialog.add_child(bg)
	
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.28, 0.96)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.75, 1.0, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(326, 120)
	panel.size = Vector2(500, 400)
	dialog.add_child(panel)
	
	var title = Label.new()
	title.text = "☰  战术控制手册 (Controls)"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(500, 40)
	panel.add_child(title)
	
	var instr = Label.new()
	instr.text = "• A / D 键 或 左右方向键：左右平滑巡航\n• Space 空格键 或 W / 上方向键：高跳 / 跃上平台\n• 鼠标左键 或 J / K 键：朝方向发射蝙蝠飞镖 (Batarang)\n• ESC 键：打开暂停菜单 (按 R 键重试，M 键返回主菜单)\n• 土狼时间 (0.12s)：走出平台边缘短时间内仍可按跳跃键"
	instr.add_theme_font_size_override("font_size", 16)
	instr.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.95))
	instr.autowrap_mode = TextServer.AUTOWRAP_WORD
	instr.position = Vector2(30, 80)
	instr.size = Vector2(440, 240)
	panel.add_child(instr)
	
	var close_btn = Button.new()
	close_btn.text = "我知道了"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.position = Vector2(190, 335)
	close_btn.size = Vector2(120, 42)
	close_btn.pressed.connect(func(): dialog.queue_free())
	panel.add_child(close_btn)
	
	add_child(dialog)

func _show_high_score_dialog():
	var dialog = CanvasLayer.new()
	dialog.name = "HighScoreDialog"
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(2400, 1600)
	bg.position = Vector2(-400, -300)
	dialog.add_child(bg)
	
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.28, 0.96)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(346, 130)
	panel.size = Vector2(460, 360)
	dialog.add_child(panel)
	
	var title = Label.new()
	title.text = "♛  哥谭英雄荣誉榜"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(460, 40)
	panel.add_child(title)
	
	var hs_box = HBoxContainer.new()
	hs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hs_box.position = Vector2(40, 90)
	hs_box.size = Vector2(380, 50)
	hs_box.add_child(_create_pixel_icon("crown", Vector2(36, 36)))
	
	var hs_val = Label.new()
	hs_val.text = " 历史最高分:  %d" % high_score
	hs_val.add_theme_font_size_override("font_size", 22)
	hs_val.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	hs_box.add_child(hs_val)
	panel.add_child(hs_box)
	
	var desc = Label.new()
	desc.text = "• 守护哥谭的英雄功勋已被自动存入本地存储\n• 击败小丑 Boss (Joker) 获得 +50 额外功勋勋章！"
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(35, 170)
	desc.size = Vector2(390, 100)
	panel.add_child(desc)
	
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.position = Vector2(170, 290)
	close_btn.size = Vector2(120, 40)
	close_btn.pressed.connect(func(): dialog.queue_free())
	panel.add_child(close_btn)
	
	add_child(dialog)

func _show_level_select_dialog():
	var dialog = CanvasLayer.new()
	dialog.name = "LevelSelectDialog"
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(2400, 1600)
	bg.position = Vector2(-400, -300)
	dialog.add_child(bg)
	
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.28, 0.96)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(346, 100)
	panel.size = Vector2(460, 440)
	dialog.add_child(panel)
	
	var title = Label.new()
	title.text = "≡  选择战役关卡"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(460, 40)
	panel.add_child(title)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(40, 75)
	vbox.size = Vector2(380, 300)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	for lvl in range(1, MAX_LEVEL + 1):
		var cfg = LEVEL_CONFIGS[lvl]
		var btn = Button.new()
		btn.text = "Level %d: %s (%dpx)" % [lvl, cfg["name"], cfg["width"]]
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(380, 45)
		
		var bstyle = StyleBoxFlat.new()
		bstyle.bg_color = Color(0.18, 0.26, 0.44, 0.9)
		bstyle.corner_radius_top_left = 8
		bstyle.corner_radius_top_right = 8
		bstyle.corner_radius_bottom_left = 8
		bstyle.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", bstyle)
		
		var bhover = StyleBoxFlat.new()
		bhover.bg_color = Color(0.28, 0.42, 0.68, 0.95)
		bhover.corner_radius_top_left = 8
		bhover.corner_radius_top_right = 8
		bhover.corner_radius_bottom_left = 8
		bhover.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("hover", bhover)
		
		var target_lvl = lvl
		btn.pressed.connect(func():
			dialog.queue_free()
			_start_level(target_lvl)
		)
		vbox.add_child(btn)
		
	var close_btn = Button.new()
	close_btn.text = "返回"
	close_btn.position = Vector2(180, 390)
	close_btn.size = Vector2(100, 35)
	close_btn.pressed.connect(func(): dialog.queue_free())
	panel.add_child(close_btn)
	
	add_child(dialog)

func _start_game():
	current_level = 1
	score = 0
	lives = 3
	_play_sound("menu_confirm")
	_start_level(current_level)

func _start_level(level_idx: int):
	state = GameState.PLAYING
	current_level = level_idx
	is_paused = false
	boss_arena_locked = false
	camera_fixed_boss_arena = false
	if get_tree():
		get_tree().paused = false
	blink_timer = 0.0
	
	_overlay = null
	overlay = null
	overlay_label = null
	overlay_hint = null
	pause_overlay = null
	_boss_portrait_tween = null
	
	var kids = get_children()
	for c in kids:
		c.queue_free()
	
	_create_world()
	_create_player()
	_create_hud()
	
	if camera and player_node:
		camera.position = player_node.position

func _go_back_menu():
	# 若处于通关界面且未满 5 关，空格键进入下一关
	if state == GameState.WON and current_level < MAX_LEVEL:
		current_level += 1
		_start_level(current_level)
		return
		
	# 返回主菜单重置
	current_level = 1
	_overlay = null
	overlay = null
	overlay_label = null
	overlay_hint = null
	pause_overlay = null
	_boss_portrait_tween = null
	player_node = null
	camera = null
	score_label = null
	lives_label = null
	high_score_label = null
	level_label = null
	is_paused = false
	get_tree().paused = false
	
	var kids = get_children()
	for c in kids:
		c.queue_free()
	
	_create_menu()

# ─── 世界构建 ──────────────────────────────────────

func _create_world():
	var level_cfg = LEVEL_CONFIGS.get(current_level, LEVEL_CONFIGS[1])
	var cur_width = level_cfg["width"]
	
	# ─── 单张 bg.jpg 视差背景 (替换4层程序化生成) ───
	var vp = get_viewport_rect().size
	var pb = BgSingle.create(vp.x, vp.y)
	if pb:
		add_child(pb)

	# 6. 相机极限范围
	var cam = Camera2D.new()
	cam.name = "Camera2D"
	cam.enabled = true
	cam.position_smoothing_enabled = false
	cam.limit_left = 0
	cam.limit_right = cur_width
	cam.limit_top = -200
	cam.limit_bottom = 600
	add_child(cam)
	camera = cam

	# 7. 地面物理 (扩展 +800px 覆盖全图与 Boss 战场右侧，彻底杜绝右侧地表缝隙)
	var ground_w = cur_width + 800.0
	_add_static_rect(ground_w / 2.0 - 200.0, GROUND_Y + 25, ground_w, 50, Color(0.28, 0.22, 0.16))
	
	var grass_spr = Sprite2D.new()
	grass_spr.texture = PixelBackground.create_grass_texture(int(ground_w), 8)
	grass_spr.position = Vector2(ground_w / 2.0 - 200.0, GROUND_Y - 2 + 4)
	add_child(grass_spr)
	
	# 8. 静态平台
	for pd in level_cfg["platforms"]:
		_add_static_rect(pd[0], pd[1], pd[2], pd[3], Color(0.32, 0.2, 0.1), 2)
		
	# 9. 动态移动平台
	for mpd in level_cfg["moving_platforms"]:
		var mp = MovingPlatform.new()
		mp.position = mpd["pos"]
		mp.move_distance = mpd["dist"]
		mp.move_speed = mpd["speed"]
		mp.is_vertical = mpd["vertical"]
		add_child(mp)

	# 10. 地刺陷阱
	for hz_pos in level_cfg["hazards"]:
		var h = Hazard.new()
		h.position = hz_pos
		add_child(h)

	# 11. 金币
	for coin_pos in level_cfg["coins"]:
		var coin = Coin.new()
		coin.position = coin_pos
		add_child(coin)
	
	# 12. 地面敌人
	for ge_cfg in level_cfg["ground_enemies"]:
		var e = Enemy.new()
		e.position = ge_cfg["pos"]
		e.patrol_range = ge_cfg["range"]
		add_child(e)
	
	# 13. 飞行敌人
	for fe_cfg in level_cfg["fly_enemies"]:
		var fe = FlyEnemy.new()
		fe.position = fe_cfg["pos"]
		fe.patrol_range = fe_cfg["range"]
		add_child(fe)
		
	# 14. 终极关卡 Boss (Level 5 小丑大 Boss 决战)
	if current_level == 5:
		var boss = Boss.new()
		boss.position = Vector2(4820, 180) # 右侧高处天花板静止沉睡构图
		add_child(boss)
	
	_create_finish()
	
	# 第 1 关教学关：创建现场实况教学提示标牌
	if current_level == 1:
		_create_tutorial_hints()

func _create_tutorial_hints():
	var hints = [
		{"pos": Vector2(100, 360), "title": "【1. 移动试炼】", "desc": "按 A / D 键 控制蝙蝠侠左右移动"},
		{"pos": Vector2(360, 320), "title": "【2. 跳跃试炼】", "desc": "按 Space 空格键 跃上上方平台"},
		{"pos": Vector2(750, 340), "title": "【3. 战斗试炼】", "desc": "点击 鼠标左键 发射蝙蝠飞镖击落敌人！"},
		{"pos": Vector2(1300, 360), "title": "【4. 顺利毕业】", "desc": "触碰绿旗通关，开启第 2 关正式战役！"}
	]
	for h in hints:
		var panel = Panel.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.15, 0.28, 0.88)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 0.85, 0.2, 0.85)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.shadow_size = 4
		panel.add_theme_stylebox_override("panel", style)
		panel.position = h["pos"]
		panel.size = Vector2(250, 60)
		
		var title_lbl = Label.new()
		title_lbl.text = h["title"]
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		title_lbl.position = Vector2(10, 6)
		panel.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = h["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		desc_lbl.position = Vector2(10, 28)
		panel.add_child(desc_lbl)
		
		add_child(panel)

func _add_static_rect(x, y, w, h, color, collision_layer := 1):
	var body = StaticBody2D.new()
	body.collision_layer = collision_layer
	var shape = RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col = CollisionShape2D.new()
	col.shape = shape
	# 图层2 = 单向平台：必须开启 one_way_collision 使玩家从下方可以穿过
	if collision_layer == 2:
		col.one_way_collision = true
	body.add_child(col)
	body.position = Vector2(x, y)
	add_child(body)
	
	var vis = ColorRect.new()
	vis.color = color
	vis.size = Vector2(w, h)
	vis.position = Vector2(-w/2.0, -h/2.0)
	body.add_child(vis)

func _add_invisible_barrier(x: float, y: float, w: float, h: float):
	"""创建完全隐形的物理阻挡墙 (无紫色或线条绘制，视觉干净干净)"""
	var body = StaticBody2D.new()
	body.collision_layer = 1
	var shape = RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	body.position = Vector2(x, y)
	add_child(body)

func _lock_boss_arena():
	"""触发 Level 5 Boss 电影级过场：平滑运镜居中、恐怖姿态演出、进入战斗场景 1 秒后解锁 Player 操控"""
	if boss_arena_locked:
		return
	boss_arena_locked = true
	camera_fixed_boss_arena = true # 🔒 镜头平滑运镜居中至 Vector2(4520, 324)
	
	if camera and is_instance_valid(camera):
		camera.limit_left = 4040
		camera.limit_right = 5010
		
	# 封闭左右隐形物理阻挡墙 (无任何紫色或画线，画面干净极简)
	_add_invisible_barrier(4040, GROUND_Y - 250, 30, 600)
	_add_invisible_barrier(5010, GROUND_Y - 250, 30, 600)
	
	# 🌆 哥谭夜幕血色降临：Boss 战场动态红色基调叠加层 (在电影级过场中渐变浮现)
	var boss_overlay = ColorRect.new()
	boss_overlay.name = "BossArenaOverlay"
	boss_overlay.color = Color(0.35, 0.0, 0.04, 0.0)  # 保持完全透明初始
	boss_overlay.size = Vector2(1000, 800)
	boss_overlay.position = Vector2(4040, -200)
	boss_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_overlay)
	
	# 🎭 Boss 肖像背景层 (boss.jpg 处理为 192x288 像素纹理，作为 Boss 区宏大背景)
	var boss_portrait = Sprite2D.new()
	boss_portrait.name = "BossPortrait"
	boss_portrait.texture = preload("res://scripts/lib/gotham_bg_layers.gd").create_boss_portrait_texture()
	boss_portrait.scale = Vector2(2.5, 2.5)  # 放大至 480x720
	boss_portrait.position = Vector2(4520, 100)  # 居中于 Boss 战场
	boss_portrait.modulate = Color(1, 1, 1, 0.0)  # 从完全透明开始
	boss_portrait.z_index = -1  # 在玩家和地面之后
	add_child(boss_portrait)
	
	# 渐入 + 脉冲呼吸动画 (1.5s 内从透明到血色)
	var overlay_tween = create_tween().set_parallel(true)
	overlay_tween.tween_property(boss_overlay, "color:a", 0.22, 1.5).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_property(boss_overlay, "color:r", 0.45, 1.5).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_property(boss_overlay, "color:g", 0.02, 1.5).set_ease(Tween.EASE_OUT)
	overlay_tween.tween_property(boss_portrait, "modulate:a", 0.25, 1.5).set_ease(Tween.EASE_OUT)
	# 持续脉冲动画 - 血色微弱呼吸
	var pulse_tween = create_tween().set_loops().set_parallel(true)
	pulse_tween.tween_property(boss_overlay, "color:a", 0.28, 3.2).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(boss_overlay, "color:a", 0.18, 3.2).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(boss_overlay, "color:r", 0.5, 3.2).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(boss_overlay, "color:r", 0.4, 3.2).set_ease(Tween.EASE_IN_OUT)
	# 肖像呼吸 (alpha 0.20~0.30)
	pulse_tween.tween_property(boss_portrait, "modulate:a", 0.30, 4.0).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(boss_portrait, "modulate:a", 0.20, 4.0).set_ease(Tween.EASE_IN_OUT)
	_boss_portrait_tween = pulse_tween  # 保存引用用于击败后清理
	
	# 🧹 彻底动态清理 Boss 战场及周边区域 (x >= 3500) 的所有普通小怪与飞行无人机
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.is_in_group("bosses"):
			if e.global_position.x >= 3500.0:
				e.hide()
				e.queue_free()
	
	# 🎬 电影级过场：平滑冻结玩家操控，展示恐怖演出【左侧蝙蝠侠 VS 右侧天花板静止沉睡 Boss】
	if player_node and is_instance_valid(player_node):
		player_node.input_disabled = true
		player_node.velocity = Vector2.ZERO
		
	# 2.0s 电影级过度：镜头拉至中心，展示恐怖演出
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(_on_boss_cinematic_timeout)

func _on_boss_cinematic_timeout():
	var p_pos = player_node.global_position if (player_node and is_instance_valid(player_node)) else Vector2(4220, GROUND_Y)
	var bosses = get_tree().get_nodes_in_group("bosses")
	for b in bosses:
		if is_instance_valid(b) and b.has_method("awaken_and_pounce"):
			b.awaken_and_pounce(p_pos)
			
	add_camera_shake(20.0, 0.5)
	_spawn_floating_text(Vector2(4520, 240), "👄 MUAHAHAHA! GOTHAM WILL FALL!", Color(1.0, 0.15, 0.2))
	
	# ⏱️ 精确：进入战斗场景 0.3 秒后解锁 Player 操控
	var unlock_timer = get_tree().create_timer(0.3)
	unlock_timer.timeout.connect(_on_boss_unlock_timeout)

func _on_boss_unlock_timeout():
	if player_node and is_instance_valid(player_node):
		player_node.input_disabled = false
		_spawn_floating_text(player_node.global_position + Vector2(0, -50), "⚠️ DODGE NOW! JUMP! ⚠️", Color(1.0, 0.9, 0.1))

func _create_finish():
	if current_level == 5:
		return # 🏆 第 5 关决战战场彻底取消右侧终点旗！唯一获胜条件即为击败小丑 Boss！
		
	var level_cfg = LEVEL_CONFIGS.get(current_level, LEVEL_CONFIGS[1])
	var cur_width = level_cfg["width"]
	var finish = Area2D.new()
	finish.name = "Finish"
	finish.collision_mask = 1
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 100)
	var col = CollisionShape2D.new()
	col.shape = shape
	finish.add_child(col)
	finish.position = Vector2(cur_width - 72, GROUND_Y - 50)
	finish.body_entered.connect(_on_finish_entered)
	add_child(finish)
	
	var pole = ColorRect.new()
	pole.color = Color(0.8, 0.8, 0.85)
	pole.size = Vector2(6, 100)
	pole.position = Vector2(-3, -50)
	finish.add_child(pole)
	
	var flag = ColorRect.new()
	flag.color = Color(0.1, 0.85, 0.3)
	flag.size = Vector2(28, 18)
	flag.position = Vector2(3, -45)
	finish.add_child(flag)

func _create_player():
	var level_cfg = LEVEL_CONFIGS.get(current_level, LEVEL_CONFIGS[1])
	player_node = Player.new()
	player_node.name = "Player"
	player_node.position = Vector2(80, GROUND_Y - 18)
	# 将当前关卡宽度传递给玩家，用于 x 轴边界限制
	player_node.level_width = level_cfg["width"]
	add_child(player_node)

# ─── HUD 现代化升级 ─────────────────────────────────

func _create_hud():
	var layer = CanvasLayer.new()
	layer.name = "HUD"
	
	var panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不吸收鼠标事件，保证游戏内左键攻击畅通
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.14, 0.24, 0.75)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(16, 16)
	panel.size = Vector2(570, 52)
	layer.add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.position = Vector2(12, 12)
	hbox.size = Vector2(546, 28)
	hbox.add_theme_constant_override("separation", 18)
	panel.add_child(hbox)
	
	# 1. 金币区域 (矢量 Icon + Label)
	var coin_box = HBoxContainer.new()
	coin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_box.add_child(_create_pixel_icon("coin", Vector2(24, 24)))
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = str(score)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	score_label.add_theme_constant_override("outline_size", 2)
	coin_box.add_child(score_label)
	hbox.add_child(coin_box)

	# 2. 生命值区域 (矢量 Heart Icons 容器)
	var hearts_box = HBoxContainer.new()
	hearts_box.name = "HeartsContainer"
	hearts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts_box.add_theme_constant_override("separation", 2)
	lives_label = Label.new() # 占位引用
	lives_label.name = "LivesLabel"
	lives_label.visible = false
	panel.add_child(lives_label)
	hbox.add_child(hearts_box)
	_update_lives_hud()
	# 关卡进度
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Level %d/5" % current_level
	level_label.position = Vector2(215, 12)
	level_label.add_theme_font_size_override("font_size", 17)
	level_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	panel.add_child(level_label)
	
	# 最高分（像素皇冠图标 + 数字）
	var hs_box = HBoxContainer.new()
	hs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hs_box.position = Vector2(345, 12)
	hs_box.size = Vector2(180, 28)
	hs_box.add_theme_constant_override("separation", 4)
	hs_box.add_child(_create_pixel_icon("crown", Vector2(16, 16)))
	high_score_label = Label.new()
	high_score_label.name = "HighScoreLabel"
	high_score_label.text = str(high_score)
	high_score_label.add_theme_font_size_override("font_size", 16)
	high_score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hs_box.add_child(high_score_label)
	panel.add_child(hs_box)
	
	# 蝙蝠飞镖技能按键提示
	var skill_label = Label.new()
	skill_label.name = "SkillLabel"
	skill_label.text = "左键: 飞镖"
	skill_label.position = Vector2(430, 12)
	skill_label.add_theme_font_size_override("font_size", 16)
	skill_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	skill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	skill_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(skill_label)
	
	add_child(layer)

func _update_lives_hud():
	var hud_layer = get_node_or_null("HUD")
	if not hud_layer:
		return
	var hearts_box = hud_layer.find_child("HeartsContainer", true, false)
	if not hearts_box:
		return
		
	for child in hearts_box.get_children():
		child.queue_free()
		
	if god_mode_enabled:
		var god_label = Label.new()
		god_label.text = "🛡️ ♾️ 无敌调试模式 (GOD MODE)"
		god_label.add_theme_font_size_override("font_size", 16)
		god_label.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
		god_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		god_label.add_theme_constant_override("outline_size", 3)
		hearts_box.add_child(god_label)
		return
		
	for i in range(3):
		var heart_type = "heart_full" if i < lives else "heart_empty"
		hearts_box.add_child(_create_pixel_icon(heart_type, Vector2(24, 24)))

# ─── 飘字得分特效 (Floating Text Effect) ───────────────

func _spawn_floating_text(world_pos: Vector2, text: String, color: Color):
	"""像素飘字：使用 TextureRect(图标) + Label(文字) 组合，已移除 emoji"""
	var container = Node2D.new()
	container.position = world_pos + Vector2(-15, -25)
	add_child(container)
	
	# 根据文字内容添加对应像素图标
	var icon_tex: Texture2D = null
	var label_text = text
	if text == "+1":
		icon_tex = _get_effect_texture("spark_pixel")
		label_text = "+1"
	elif text == "+2":
		icon_tex = _get_effect_texture("star_pixel")
		label_text = "+2"
	elif text.begins_with("-1"):
		icon_tex = _get_effect_texture("heart_pixel")
		label_text = "-1"
	elif text.find("BOSS") != -1:
		icon_tex = _create_pixel_icon("crown", Vector2(16, 16)).texture
		label_text = text.replace(" 👑 ", " ")
	
	var icon_node: TextureRect = null
	if icon_tex:
		icon_node = TextureRect.new()
		icon_node.texture = icon_tex
		icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_node.size = Vector2(16, 16)
		icon_node.position = Vector2(0, 2)
		icon_node.modulate = color
		container.add_child(icon_node)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(18 if icon_tex else 0, 0)
	container.add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(container, "position:y", container.position.y - 35.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	if icon_node:
		tween.tween_property(icon_node, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(func(): _free_safe(container))

func _on_boss_defeated(boss_node):
	"""小丑大 Boss 被击败后触发"""
	score += 50
	if score_label and is_instance_valid(score_label):
		score_label.text = str(score)
	_spawn_floating_text(boss_node.global_position, "+50 SPIDER-JOKER DEFEATED!", Color(1.0, 0.85, 0.2))
	_spawn_particle_burst(boss_node.global_position, Color(1.0, 0.85, 0.1))
	_spawn_particle_burst(boss_node.global_position + Vector2(-30, -20), Color(0.9, 0.2, 0.9))
	_spawn_particle_burst(boss_node.global_position + Vector2(30, -20), Color(0.2, 0.9, 0.9))
	add_camera_shake(18.0, 0.5)
	trigger_hit_stop(0.08)
	
	# 移除 Boss 战场血色覆盖层 (渐隐后删除)
	var overlay = get_node_or_null("BossArenaOverlay")
	if overlay and is_instance_valid(overlay):
		var fade_tween = create_tween()
		fade_tween.tween_property(overlay, "color:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
		fade_tween.chain().tween_callback(func(): _free_safe(overlay))
	
	# 渐隐 Boss 肖像背景层
	var portrait = get_node_or_null("BossPortrait")
	if portrait and is_instance_valid(portrait):
		if _boss_portrait_tween and is_instance_valid(_boss_portrait_tween):
			_boss_portrait_tween.kill()
			_boss_portrait_tween = null
		var pt_fade = create_tween()
		pt_fade.tween_property(portrait, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
		pt_fade.chain().tween_callback(func(): _free_safe(portrait))
	
	# 解锁镜头右边界与跟随，允许前往终点
	camera_fixed_boss_arena = false
	if camera and is_instance_valid(camera):
		camera.limit_right = 5300

# ─── 暂停菜单 ──────────────────────────────────────

func _toggle_pause():
	is_paused = not is_paused
	get_tree().paused = is_paused
	Input.flush_buffered_events()
	_play_sound("pause")
	
	if is_paused:
		pause_overlay = CanvasLayer.new()
		pause_overlay.name = "PauseOverlay"
		
		var bg = ColorRect.new()
		bg.color = Color(0, 0, 0, 0.55)
		bg.size = Vector2(2400, 1600)
		bg.position = Vector2(-400, -300)
		pause_overlay.add_child(bg)
		
		var panel = Panel.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.28, 0.95)
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		panel.add_theme_stylebox_override("panel", style)
		panel.position = Vector2(400, 200)
		panel.size = Vector2(352, 220)
		pause_overlay.add_child(panel)
		
		var p_title = Label.new()
		p_title.text = "游戏暂停 (Level %d)" % current_level
		p_title.add_theme_font_size_override("font_size", 28)
		p_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_title.position = Vector2(0, 30)
		p_title.size = Vector2(352, 45)
		panel.add_child(p_title)
		
		var p_hint = Label.new()
		p_hint.text = "按 ESC 键恢复游戏\n按 R 键重试本关\n按 M 键返回主菜单"
		p_hint.add_theme_font_size_override("font_size", 18)
		p_hint.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 0.9))
		p_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_hint.position = Vector2(0, 95)
		p_hint.size = Vector2(352, 90)
		panel.add_child(p_hint)
		
		add_child(pause_overlay)
	else:
		if pause_overlay and is_instance_valid(pause_overlay):
			pause_overlay.queue_free()
			pause_overlay = null

# ─── 像素特效纹理缓存 ──────────────────────────────

var _effect_texture_cache: Dictionary = {}

func _get_effect_texture(name: String) -> Texture2D:
	"""从缓存获取或生成像素精灵纹理（spark / dust / star / fire / heart）"""
	if _effect_texture_cache.has(name):
		return _effect_texture_cache[name]
	
	var tex: Texture2D = null
	match name:
		"spark_pixel":
			var pal = { "Y": Color(1.0, 0.85, 0.1), "W": Color(1.0, 0.95, 0.5), ".": Color.TRANSPARENT }
			var pixels = ["....", ".YW.", "WYYW", ".YW."]
			tex = PixelLib.create_texture(4, 4, pixels, pal)
		"dust_pixel":
			var pal = { "G": Color(0.75, 0.75, 0.82), ".": Color.TRANSPARENT }
			var pixels = ["....", ".GG.", "GGGG", ".GG."]
			tex = PixelLib.create_texture(4, 4, pixels, pal)
		"star_pixel":
			var pal = { "Y": Color(1.0, 0.9, 0.3), "W": Color(1.0, 1.0, 0.8), ".": Color.TRANSPARENT }
			var pixels = ["..Y..", ".WY.", "YWYY.", ".WY.", "..Y.."]
			tex = PixelLib.create_texture(5, 5, pixels, pal)
		"fire_pixel":
			var pal = { "R": Color(0.95, 0.2, 0.15), "O": Color(1.0, 0.6, 0.1), ".": Color.TRANSPARENT }
			var pixels = ["....", ".OO.", "ORRO", ".OO."]
			tex = PixelLib.create_texture(4, 4, pixels, pal)
		"heart_pixel":
			var pal = { "R": Color(0.95, 0.15, 0.25), ".": Color.TRANSPARENT }
			var pixels = ["......", "..RR..", ".RRRR.", "RRRRRR", ".RRRR.", "..RR.."]
			tex = PixelLib.create_texture(6, 6, pixels, pal)
	
	if tex:
		_effect_texture_cache[name] = tex
	return tex

# ─── 粒子爆裂特效 (Particle Burst Effect) ─────────────

func _spawn_particle_burst(world_pos: Vector2, color: Color):
	"""像素粒子爆裂特效：根据颜色选择 spark(黄/白/紫/青) 或 fire(红/橙) 纹理"""
	var node = Node2D.new()
	node.position = world_pos
	add_child(node)
	
	# 根据颜色选择纹理：红/橙色调→fire_pixel，其余→spark_pixel
	var is_red_orange = color.r > 0.7 and color.g <= 0.35 and color.b <= 0.35
	var tex_name = "fire_pixel" if is_red_orange else "spark_pixel"
	var tex = _get_effect_texture(tex_name)
	
	var count = 8
	var particles = []
	for i in range(count):
		var p = TextureRect.new()
		p.texture = tex
		p.self_modulate = color
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz = randf_range(8.0, 14.0)
		p.size = Vector2(sz, sz)
		var angle = i * 2.0 * PI / count + randf_range(-0.3, 0.3)
		var speed = randf_range(80.0, 160.0)
		var vel = Vector2(cos(angle), sin(angle)) * speed
		node.add_child(p)
		particles.append([p, vel])
		
	var tween = create_tween().set_parallel(true)
	for item in particles:
		var p = item[0]
		var vel = item[1]
		tween.tween_property(p, "position", vel * 0.35, 0.35)
		tween.tween_property(p, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(func(): _free_safe(node))

# ─── 游戏事件 ──────────────────────────────────────

func _on_coin_collected(coin):
	if state != GameState.PLAYING:
		return
	score += 1
	if score_label and is_instance_valid(score_label):
		score_label.text = str(score)
	if coin:
		_play_sound("coin")
		_spawn_floating_text(coin.position, "+1", Color(1.0, 0.9, 0.2))
		_spawn_particle_burst(coin.position, Color(1.0, 0.85, 0.2))

func _play_sound(sound_name: String):
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").call("play", sound_name)

func _on_enemy_stomped(enemy):
	if state != GameState.PLAYING:
		return
	score += 2
	if score_label and is_instance_valid(score_label):
		score_label.text = str(score)
	if enemy:
		_play_sound("enemy_stomp")
		_spawn_floating_text(enemy.position, "+2", Color(0.3, 1.0, 0.4))
		_spawn_particle_burst(enemy.position, Color(0.9, 0.2, 0.15))

func _player_hurt(body):
	if god_mode_enabled:
		_play_sound("menu_hover")
		_spawn_floating_text(body.position, "🛡️ GOD MODE BLOCKED", Color(0.3, 0.95, 1.0))
		return
		
	if body is Player:
		if body.hit():
			_play_sound("enemy_hit")
			lives -= 1
			_update_lives_hud()
			_spawn_floating_text(body.position, "-1", Color(1.0, 0.2, 0.2))
			_spawn_particle_burst(body.position, Color(1.0, 0.3, 0.3))
			if lives <= 0:
				body.die()
				var timer = get_tree().create_timer(0.4)
				timer.timeout.connect(_on_death_timer_end)

func _on_death_timer_end():
	_game_over()

func _on_player_hit(body):
	if state != GameState.PLAYING:
		return
	_player_hurt(body)

func _on_finish_entered(body):
	if state != GameState.PLAYING:
		return
	if body.is_in_group("player"):
		_win_game()

# ─── 弹出层 ────────────────────────────────────────

var _overlay = null

func _show_overlay(title_text, title_color, hint_text):
	if pause_overlay and is_instance_valid(pause_overlay):
		pause_overlay.hide()
		pause_overlay.queue_free()
		pause_overlay = null
		
	_overlay = CanvasLayer.new()
	_overlay.name = "GameOverlay"
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(2400, 1600)
	bg.position = Vector2(-400, -300)
	_overlay.add_child(bg)
	
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.24, 0.95)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(326, 170)
	panel.size = Vector2(500, 260)
	_overlay.add_child(panel)
	
	overlay_label = Label.new()
	overlay_label.text = title_text
	overlay_label.add_theme_font_size_override("font_size", 36)
	overlay_label.add_theme_color_override("font_color", title_color)
	overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	overlay_label.add_theme_constant_override("outline_size", 5)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_label.position = Vector2(0, 25)
	overlay_label.size = Vector2(500, 60)
	panel.add_child(overlay_label)
	
	var is_new_record = false
	if score > high_score:
		high_score = score
		_save_high_score()
		is_new_record = true
	
	var score_info = Label.new()
	score_info.text = "累计得分: " + str(score) + ("  (★ 刷新最高纪录!)" if is_new_record else "  (最高: " + str(high_score) + ")")
	score_info.add_theme_font_size_override("font_size", 20)
	score_info.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3) if is_new_record else Color(0.85, 0.9, 1.0))
	score_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_info.position = Vector2(0, 95)
	score_info.size = Vector2(500, 35)
	panel.add_child(score_info)
	
	overlay_hint = Label.new()
	overlay_hint.text = hint_text
	overlay_hint.add_theme_font_size_override("font_size", 22)
	overlay_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	overlay_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	overlay_hint.add_theme_constant_override("outline_size", 3)
	overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_hint.position = Vector2(0, 165)
	overlay_hint.size = Vector2(500, 40)
	panel.add_child(overlay_hint)
	
	add_child(_overlay)
	
	blink_timer = 0.0
	blink_visible = true
	overlay_hint.modulate.a = 0.95

func _win_game():
	state = GameState.WON
	_play_sound("level_complete")
	if player_node:
		player_node.input_disabled = true
	if current_level < MAX_LEVEL:
		_show_overlay("第 %d 关 通 关" % current_level, Color(0.35, 1.0, 0.4), "按 空格键 挑战第 %d 关" % (current_level + 1))
	else:
		_show_overlay("哥 谭 守 护 者", Color(1.0, 0.85, 0.2), "全 关 卡 通 关！按 空格键 返回主菜单")

func _game_over():
	state = GameState.GAME_OVER
	_play_sound("game_over")
	if player_node:
		player_node.input_disabled = true
	_show_overlay("游 戏 结 束", Color(1.0, 0.35, 0.35), "按 空格键 返回主菜单")

func _free_safe(node: Node):
	"""安全释放节点 — 替代 tween_callback(func(): ...) 防止 Lambda capture 警告"""
	if is_instance_valid(node):
		node.queue_free()
