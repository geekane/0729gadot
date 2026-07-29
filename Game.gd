extends Node2D

const Coin = preload("res://Coin.gd")
const Enemy = preload("res://Enemy.gd")
const Player = preload("res://Player.gd")
const FlyEnemy = preload("res://FlyEnemy.gd")
const Hazard = preload("res://Hazard.gd")
const MovingPlatform = preload("res://MovingPlatform.gd")
const Boss = preload("res://Boss.gd")
const PixelConfig = preload("res://pixel_config.gd")
const PixelBackground = preload("res://pixel_background.gd")

enum GameState { MENU, PLAYING, WON, GAME_OVER }

var state = GameState.MENU
var score = 0
var high_score = 0
var lives = 3
var is_paused = false

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
			[3700, 400, 100, 16], [4000, 465, 100, 16], [4300, 400, 100, 16], [4700, 360, 100, 16]
		],
		"moving_platforms": [
			{"pos": Vector2(500, 360), "dist": 120.0, "speed": 2.4, "vertical": false},
			{"pos": Vector2(1000, 350), "dist": 90.0, "speed": 2.2, "vertical": true},
			{"pos": Vector2(1600, 340), "dist": 130.0, "speed": 2.5, "vertical": false},
			{"pos": Vector2(2200, 350), "dist": 90.0, "speed": 2.4, "vertical": true},
			{"pos": Vector2(2800, 330), "dist": 140.0, "speed": 2.6, "vertical": false},
			{"pos": Vector2(3400, 350), "dist": 90.0, "speed": 2.4, "vertical": true},
			{"pos": Vector2(4000, 330), "dist": 150.0, "speed": 2.7, "vertical": false}
		],
		"hazards": [
			Vector2(380, 550), Vector2(880, 550), Vector2(1450, 550), Vector2(2050, 550),
			Vector2(2650, 550), Vector2(3250, 550), Vector2(3850, 550), Vector2(4450, 550)
		],
		"coins": [
			Vector2(120, 420), Vector2(250, 400), Vector2(380, 470), Vector2(500, 310), Vector2(620, 400),
			Vector2(750, 360), Vector2(880, 470), Vector2(1000, 290), Vector2(1150, 400), Vector2(1300, 340),
			Vector2(1450, 450), Vector2(1600, 280), Vector2(1750, 400), Vector2(1900, 340), Vector2(2050, 450),
			Vector2(2200, 290), Vector2(2350, 400), Vector2(2500, 340), Vector2(2650, 450), Vector2(2800, 270),
			Vector2(2950, 400), Vector2(3100, 340), Vector2(3250, 450), Vector2(3400, 290), Vector2(3550, 400),
			Vector2(3700, 340), Vector2(3850, 450), Vector2(4000, 270), Vector2(4300, 340), Vector2(4700, 300)
		],
		"ground_enemies": [
			{"pos": Vector2(180, 538), "range": 130}, {"pos": Vector2(550, 538), "range": 140},
			{"pos": Vector2(950, 538), "range": 150}, {"pos": Vector2(1350, 538), "range": 160},
			{"pos": Vector2(1750, 538), "range": 160}, {"pos": Vector2(2150, 538), "range": 170},
			{"pos": Vector2(2550, 538), "range": 170}, {"pos": Vector2(2950, 538), "range": 180},
			{"pos": Vector2(3350, 538), "range": 180}, {"pos": Vector2(3750, 538), "range": 190},
			{"pos": Vector2(4150, 538), "range": 190}, {"pos": Vector2(4550, 538), "range": 200}
		],
		"fly_enemies": [
			{"pos": Vector2(300, 250), "range": 120.0}, {"pos": Vector2(650, 200), "range": 130.0},
			{"pos": Vector2(1050, 220), "range": 140.0}, {"pos": Vector2(1450, 190), "range": 140.0},
			{"pos": Vector2(1850, 210), "range": 150.0}, {"pos": Vector2(2250, 180), "range": 150.0},
			{"pos": Vector2(2650, 200), "range": 140.0}, {"pos": Vector2(3050, 170), "range": 160.0},
			{"pos": Vector2(3450, 190), "range": 150.0}, {"pos": Vector2(3850, 170), "range": 160.0},
			{"pos": Vector2(4250, 190), "range": 150.0}, {"pos": Vector2(4650, 180), "range": 160.0}
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
	timer.timeout.connect(func(): Engine.time_scale = 1.0)

func _process(delta):
	anim_time += delta
	_update_bg_effects(delta)
	match state:
		GameState.MENU:
			_blink_step(delta)
			if Input.is_action_just_pressed("ui_accept"):
				_start_game()
		GameState.PLAYING:
			# 镜头平滑跟随玩家 (使用 lerp 插值 + Trauma 衰减震动偏移)
			if camera and player_node and is_instance_valid(camera) and is_instance_valid(player_node):
				var weight = clamp(12.0 * delta, 0.0, 1.0)
				var target_pos = player_node.position
				
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
		
		# 蝙蝠徽标 Bat Silhouette
		var bx = top_center.x
		var by = top_center.y
		var bat_pts = PackedVector2Array([
			Vector2(bx - 26, by - 4), Vector2(bx - 15, by - 12), Vector2(bx, by - 5),
			Vector2(bx + 15, by - 12), Vector2(bx + 26, by - 4), Vector2(bx + 22, by + 9),
			Vector2(bx + 11, by + 14), Vector2(bx, by + 7), Vector2(bx - 11, by + 14),
			Vector2(bx - 22, by + 9)
		])
		menu_bat_signal.draw_polygon(bat_pts, PackedColorArray([Color(0.08, 0.08, 0.14, 0.95 * flk)]))
		menu_bat_signal.draw_polygon(PackedVector2Array([Vector2(bx - 5, by - 5), Vector2(bx - 2, by - 14), Vector2(bx, by - 5)]), PackedColorArray([Color(0.08, 0.08, 0.14, 0.95)]))
		menu_bat_signal.draw_polygon(PackedVector2Array([Vector2(bx, by - 5), Vector2(bx + 2, by - 14), Vector2(bx + 5, by - 5)]), PackedColorArray([Color(0.08, 0.08, 0.14, 0.95)]))
	)
	add_child(menu_bat_signal)
	
	# 主界面 Panel 容器
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.26, 0.92)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2, 0.75)
	style.shadow_size = 18
	style.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(306, 75)
	panel.size = Vector2(540, 480)
	panel.name = "MenuPanel"
	add_child(panel)
	
	# 顶端标题 Header
	var title_vbox = VBoxContainer.new()
	title_vbox.position = Vector2(20, 22)
	title_vbox.size = Vector2(500, 95)
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(title_vbox)
	
	var icon_box = HBoxContainer.new()
	icon_box.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_box.add_child(_create_vector_icon("bat", Vector2(42, 42)))
	title_vbox.add_child(icon_box)
	
	var title = Label.new()
	title.text = "蝙蝠侠：哥谭暗夜守护者"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 0.95))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "GOTHAM ADVENTURE: BATMAN STRIKES"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(subtitle)

	# 垂直功能按钮组容器 (排版干净大气)
	var btn_vbox = VBoxContainer.new()
	btn_vbox.position = Vector2(70, 135)
	btn_vbox.size = Vector2(400, 320)
	btn_vbox.add_theme_constant_override("separation", 14)
	panel.add_child(btn_vbox)
	
	var btn_configs = [
		{"text": "🚀  开始出击 (Level 1 教学关)", "color": Color(1.0, 0.92, 0.3), "action": func(): _start_game()},
		{"text": "📖  战役关卡选择 (Level 1 ~ 5)", "color": Color(0.9, 0.95, 1.0), "action": func(): _show_level_select_dialog()},
		{"text": "🏆  荣誉排行榜 (High Scores)", "color": Color(1.0, 0.8, 0.2), "action": func(): _show_high_score_dialog()},
		{"text": "⚙️  操作指南 (Controls)", "color": Color(0.7, 0.85, 1.0), "action": func(): _show_controls_dialog()},
		{"text": "🚪  退出游戏 (Quit Game)", "color": Color(1.0, 0.45, 0.45), "action": func(): get_tree().quit()}
	]
	
	for bd in btn_configs:
		var btn = Button.new()
		btn.text = bd["text"]
		btn.add_theme_font_size_override("font_size", 17)
		btn.add_theme_color_override("font_color", bd["color"])
		btn.custom_minimum_size = Vector2(400, 46)
		
		var bstyle = StyleBoxFlat.new()
		bstyle.bg_color = Color(0.16, 0.24, 0.42, 0.92)
		bstyle.corner_radius_top_left = 10
		bstyle.corner_radius_top_right = 10
		bstyle.corner_radius_bottom_left = 10
		bstyle.corner_radius_bottom_right = 10
		bstyle.border_width_left = 1
		bstyle.border_width_right = 1
		bstyle.border_width_top = 1
		bstyle.border_width_bottom = 1
		bstyle.border_color = Color(0.35, 0.48, 0.75, 0.5)
		btn.add_theme_stylebox_override("normal", bstyle)
		
		var bhover = StyleBoxFlat.new()
		bhover.bg_color = Color(0.26, 0.40, 0.68, 0.98)
		bhover.corner_radius_top_left = 10
		bhover.corner_radius_top_right = 10
		bhover.corner_radius_bottom_left = 10
		bhover.corner_radius_bottom_right = 10
		bhover.border_width_left = 2
		bhover.border_width_right = 2
		bhover.border_width_top = 2
		bhover.border_width_bottom = 2
		bhover.border_color = Color(1.0, 0.85, 0.2, 0.9)
		btn.add_theme_stylebox_override("hover", bhover)
		btn.pressed.connect(bd["action"])
		btn_vbox.add_child(btn)
		
	overlay = CanvasLayer.new()
	overlay.name = "Overlay"
	overlay_label = Label.new()
	overlay_label.text = "按 空格键 或 点击上方按钮 开始出击"
	overlay_label.add_theme_font_size_override("font_size", 18)
	overlay_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 0.9))
	overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	overlay_label.add_theme_constant_override("outline_size", 3)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.position = Vector2(246, 580)
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
	title.text = "⚙️  战术控制手册 (Controls)"
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
	title.text = "🏆  哥谭英雄荣誉榜"
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
	hs_box.add_child(_create_vector_icon("crown", Vector2(36, 36)))
	
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
	title.text = "📖  选择战役关卡"
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
	_start_level(current_level)

func _start_level(level_idx: int):
	state = GameState.PLAYING
	current_level = level_idx
	is_paused = false
	if get_tree():
		get_tree().paused = false
	blink_timer = 0.0
	
	_overlay = null
	overlay = null
	overlay_label = null
	overlay_hint = null
	pause_overlay = null
	
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
	
	# ─── 视差滚屏背景系统 (Parallax Background System) ───
	var pb = ParallaxBackground.new()
	pb.name = "ParallaxBG"
	
	# Layer 0: 夜空底板、哥谭明月与摇摆蝙蝠探照灯 (固定比 0.0, 0.0)
	var layer0 = ParallaxLayer.new()
	layer0.motion_scale = Vector2(0.0, 0.0)
	var sky_bg = ColorRect.new()
	sky_bg.color = Color(0.06, 0.09, 0.18, 1.0)
	sky_bg.size = Vector2(cur_width + 1600, 1400)
	sky_bg.position = Vector2(-600, -400)
	layer0.add_child(sky_bg)
	
	var moon_spr = Sprite2D.new()
	moon_spr.texture = PixelBackground.create_pixel_moon(80)
	moon_spr.position = Vector2(890, 60)
	moon_spr.scale = Vector2(1, 1)
	layer0.add_child(moon_spr)
	
	# 动态摇摆探照灯与云层蝙蝠徽标 Projection
	var bat_signal = Node2D.new()
	bat_signal.name = "BatSignalBeam"
	bat_signal.set_meta("sweep_angle", 0.0)
	bat_signal.set_meta("flicker", 1.0)
	bat_signal.draw.connect(func():
		var angle = bat_signal.get_meta("sweep_angle")
		var flk = bat_signal.get_meta("flicker")
		var base_pos = Vector2(850, 520)
		var top_center = Vector2(850 + sin(angle) * 220.0, 50)
		
		# 探照灯光束
		var beam_pts = PackedVector2Array([
			base_pos + Vector2(-15, 0),
			top_center + Vector2(-90, 0),
			top_center + Vector2(90, 0),
			base_pos + Vector2(15, 0)
		])
		bat_signal.draw_polygon(beam_pts, PackedColorArray([Color(1.0, 0.9, 0.3, 0.085 * flk)]))
		
		# 云层黄色光晕
		bat_signal.draw_circle(top_center, 48.0, Color(1.0, 0.88, 0.25, 0.45 * flk))
		bat_signal.draw_circle(top_center, 34.0, Color(1.0, 0.95, 0.5, 0.7 * flk))
		
		# 蝙蝠徽标 Bat Silhouette
		var bx = top_center.x
		var by = top_center.y
		var bat_pts = PackedVector2Array([
			Vector2(bx - 24, by - 4), Vector2(bx - 14, by - 10), Vector2(bx, by - 4),
			Vector2(bx + 14, by - 10), Vector2(bx + 24, by - 4), Vector2(bx + 20, by + 8),
			Vector2(bx + 10, by + 13), Vector2(bx, by + 6), Vector2(bx - 10, by + 13),
			Vector2(bx - 20, by + 8)
		])
		bat_signal.draw_polygon(bat_pts, PackedColorArray([Color(0.08, 0.08, 0.14, 0.95 * flk)]))
		bat_signal.draw_polygon(PackedVector2Array([Vector2(bx - 5, by - 4), Vector2(bx - 2, by - 13), Vector2(bx, by - 4)]), PackedColorArray([Color(0.08, 0.08, 0.14, 0.95)]))
		bat_signal.draw_polygon(PackedVector2Array([Vector2(bx, by - 4), Vector2(bx + 2, by - 13), Vector2(bx + 5, by - 4)]), PackedColorArray([Color(0.08, 0.08, 0.14, 0.95)]))
	)
	layer0.add_child(bat_signal)
	pb.add_child(layer0)
	
	# Layer 1: 远景像素摩天大楼 (视差比 0.08, 0.02, Roguelike 循环复用 1600px)
	var layer1 = ParallaxLayer.new()
	layer1.motion_scale = Vector2(0.08, 0.02)
	layer1.motion_mirroring = Vector2(1600, 0) # 开启 1600px 无缝无尽拼贴
	var b_x1 = -100.0
	var b_id1 = 0
	while b_x1 < 1500: # 固定只生成 1600px 长度的基础块 (约 11 栋)
		var bw = 120.0
		var bh = 240.0 + (b_id1 % 3) * 60.0
		var building_tex = PixelBackground.create_building_texture(
			int(bw), int(bh),
			Color(0.10, 0.13, 0.22, 0.88),
			Color(1.0, 0.88, 0.35, 0.35),
			b_id1 * 31 + 7
		)
		var b_spr = Sprite2D.new()
		b_spr.texture = building_tex
		b_spr.position = Vector2(b_x1, GROUND_Y - bh / 2.0 + 20)
		layer1.add_child(b_spr)
		b_x1 += bw + 16.0
		b_id1 += 1
	pb.add_child(layer1)
	
	# Layer 2: 中景像素哥谭大楼与漂移云层 (视差比 0.22, 0.05, Roguelike 循环复用 1600px)
	var layer2 = ParallaxLayer.new()
	layer2.motion_scale = Vector2(0.22, 0.05)
	layer2.motion_mirroring = Vector2(1600, 0) # 开启 1600px 无缝无尽拼贴
	var b_x2 = -80.0
	var b_id2 = 0
	while b_x2 < 1520: # 固定只生成 1600px 长度的基础块 (约 10 栋)
		var bw = 140.0
		var bh = 200.0 + (b_id2 % 3) * 40.0
		var building_tex = PixelBackground.create_building_texture(
			int(bw), int(bh),
			Color(0.14, 0.18, 0.30, 0.95),
			Color(0.4, 0.9, 1.0, 0.35),
			b_id2 * 17 + 107
		)
		var b_spr = Sprite2D.new()
		b_spr.texture = building_tex
		b_spr.position = Vector2(b_x2, GROUND_Y - bh / 2.0 + 25)
		layer2.add_child(b_spr)
		b_x2 += bw + 20.0
		b_id2 += 1
	
	# 像素浮云 (循环模式)
	var clouds_data = [
		[100, 30, 180, 50], [450, -20, 220, 60], [850, 20, 200, 55],
		[1200, -30, 260, 70], [1500, 40, 190, 50]
	]
	for cd in clouds_data:
		var cloud_tex = PixelBackground.create_cloud_texture(cd[2], cd[3])
		var cloud_spr = Sprite2D.new()
		cloud_spr.texture = cloud_tex
		cloud_spr.position = Vector2(cd[0] + cd[2]/2.0, cd[1] + cd[3]/2.0)
		cloud_spr.add_to_group("drifting_clouds")
		layer2.add_child(cloud_spr)
	pb.add_child(layer2)
	
	# Layer 3: 近景像素管道与护栏 (视差比 0.55, 0.10, Roguelike 循环复用 1600px)
	var layer3 = ParallaxLayer.new()
	layer3.motion_scale = Vector2(0.55, 0.10)
	layer3.motion_mirroring = Vector2(1600, 0)
	var pipe_tex = PixelBackground.create_pipe_texture()
	for bx in range(-100, 1500, 320):
		var pipe_spr = Sprite2D.new()
		pipe_spr.texture = pipe_tex
		pipe_spr.position = Vector2(bx + 6, GROUND_Y - 70)
		layer3.add_child(pipe_spr)
	pb.add_child(layer3)
	
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

	# 7. 地面物理
	_add_static_rect(cur_width / 2.0, GROUND_Y + 25, cur_width, 50, Color(0.28, 0.22, 0.16))
	
	var grass_spr = Sprite2D.new()
	grass_spr.texture = PixelBackground.create_grass_texture(int(cur_width), 8)
	grass_spr.position = Vector2(cur_width / 2.0, GROUND_Y - 2 + 4)
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
		boss.position = Vector2(4650, GROUND_Y - 35)
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
	# 单向平台 (图层2): 只从上方站住，从下方和侧面均可穿过
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

func _create_finish():
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
	coin_box.add_child(_create_vector_icon("coin", Vector2(24, 24)))
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
	level_label.text = "🚩 Level %d/5" % current_level
	level_label.position = Vector2(215, 12)
	level_label.add_theme_font_size_override("font_size", 17)
	level_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	panel.add_child(level_label)
	
	# 最高分
	high_score_label = Label.new()
	high_score_label.name = "HighScoreLabel"
	high_score_label.text = "👑 " + str(high_score)
	high_score_label.position = Vector2(345, 12)
	high_score_label.add_theme_font_size_override("font_size", 16)
	high_score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	panel.add_child(high_score_label)
	
	# 蝙蝠飞镖技能按键提示
	var skill_label = Label.new()
	skill_label.name = "SkillLabel"
	skill_label.text = "🦇 鼠标左键: 飞镖"
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
		
	for i in range(3):
		var heart_type = "heart_full" if i < lives else "heart_empty"
		hearts_box.add_child(_create_vector_icon(heart_type, Vector2(24, 24)))

# ─── 飘字得分特效 (Floating Text Effect) ───────────────

func _spawn_floating_text(world_pos: Vector2, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.position = world_pos + Vector2(-15, -25)
	add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(func(): label.hide(); label.queue_free())

func _on_boss_defeated(boss_node):
	"""小丑大 Boss 被击败后触发"""
	score += 50
	if score_label and is_instance_valid(score_label):
		score_label.text = "💰 " + str(score)
	_spawn_floating_text(boss_node.global_position, "+50 👑 BOSS DOWN!", Color(1.0, 0.85, 0.2))
	_spawn_particle_burst(boss_node.global_position, Color(1.0, 0.85, 0.1))
	_spawn_particle_burst(boss_node.global_position + Vector2(-30, -20), Color(0.9, 0.2, 0.9))
	_spawn_particle_burst(boss_node.global_position + Vector2(30, -20), Color(0.2, 0.9, 0.9))
	add_camera_shake(18.0, 0.5)
	trigger_hit_stop(0.08)

# ─── 暂停菜单 ──────────────────────────────────────

func _toggle_pause():
	is_paused = not is_paused
	get_tree().paused = is_paused
	Input.flush_buffered_events()  # 清空暂停状态切换时的按键事件缓存
	
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
		p_title.text = "⏸️ 游戏暂停 (Level %d)" % current_level
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

# ─── 粒子爆裂特效 (Particle Burst Effect) ─────────────

func _spawn_particle_burst(world_pos: Vector2, color: Color):
	var node = Node2D.new()
	node.position = world_pos
	add_child(node)
	
	var count = 8
	var particles = []
	for i in range(count):
		var p = ColorRect.new()
		p.color = color
		var sz = randf_range(3.0, 6.0)
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
	tween.chain().tween_callback(func(): node.hide(); node.queue_free())

# ─── 游戏事件 ──────────────────────────────────────

func _on_coin_collected(coin):
	if state != GameState.PLAYING:
		return
	score += 1
	if score_label and is_instance_valid(score_label):
		score_label.text = "💰 " + str(score)
	if coin:
		_spawn_floating_text(coin.position, "+1", Color(1.0, 0.9, 0.2))
		_spawn_particle_burst(coin.position, Color(1.0, 0.85, 0.2))

func _on_enemy_stomped(enemy):
	if state != GameState.PLAYING:
		return
	score += 2
	if score_label and is_instance_valid(score_label):
		score_label.text = "💰 " + str(score)
	if enemy:
		_spawn_floating_text(enemy.position, "+2", Color(0.3, 1.0, 0.4))
		_spawn_particle_burst(enemy.position, Color(0.9, 0.2, 0.15))

func _player_hurt(body):
	if body is Player:
		if body.hit():
			lives -= 1
			_update_lives_hud()
			_spawn_floating_text(body.position, "-1 ❤️", Color(1.0, 0.2, 0.2))
			_spawn_particle_burst(body.position, Color(1.0, 0.3, 0.3))
			if lives <= 0:
				body.die()
				var timer = get_tree().create_timer(0.4)
				timer.timeout.connect(func(): _game_over())

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
	score_info.text = "累计得分: " + str(score) + ("  (🎉 刷新最高纪录!)" if is_new_record else "  (最高: " + str(high_score) + ")")
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
	if player_node:
		player_node.input_disabled = true
	if current_level < MAX_LEVEL:
		_show_overlay("🎉  第 %d 关 通 关  🎉" % current_level, Color(0.35, 1.0, 0.4), "按 空格键 挑战第 %d 关" % (current_level + 1))
	else:
		_show_overlay("🏆  哥 谭 守 护 者  🏆", Color(1.0, 0.85, 0.2), "🎉 全 关 卡 通 关！按 空格键 返回主菜单")

func _game_over():
	state = GameState.GAME_OVER
	if player_node:
		player_node.input_disabled = true
	_show_overlay("💀  游 戏 结 束  💀", Color(1.0, 0.35, 0.35), "按 空格键 返回主菜单")
