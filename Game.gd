extends Node2D

const Coin = preload("res://Coin.gd")
const Enemy = preload("res://Enemy.gd")
const Player = preload("res://Player.gd")
const FlyEnemy = preload("res://FlyEnemy.gd")
const Hazard = preload("res://Hazard.gd")
const MovingPlatform = preload("res://MovingPlatform.gd")

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
	RenderingServer.set_default_clear_color(Color(0.08, 0.1, 0.2, 1.0))
	_load_high_score()
	_create_menu()

func _process(delta):
	match state:
		GameState.MENU:
			_blink_step(delta)
			if Input.is_action_just_pressed("ui_accept"):
				_start_game()
		GameState.PLAYING:
			# 镜头平滑跟随玩家 (使用 lerp 插值)
			if camera and player_node and is_instance_valid(camera) and is_instance_valid(player_node):
				var weight = clamp(12.0 * delta, 0.0, 1.0)
				camera.position = camera.position.lerp(player_node.position, weight)
				# 掉落死亡判定
				if player_node.position.y > GROUND_Y + 100:
					_on_player_hit(player_node)
		GameState.WON, GameState.GAME_OVER:
			_blink_step(delta)
			if Input.is_action_just_pressed("ui_accept"):
				_go_back_menu()

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
	for i in range(40):
		var star = ColorRect.new()
		star.color = Color(1.0, 1.0, 1.0, randf_range(0.2, 0.6))
		var s = randf_range(2.0, 5.0)
		star.size = Vector2(s, s)
		star.position = Vector2(randf_range(0, 1152), randf_range(0, 648))
		stars.add_child(star)
	add_child(stars)
	
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.28, 0.9)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_size = 14
	style.shadow_color = Color(0, 0, 0, 0.45)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(246, 80)
	panel.size = Vector2(660, 480)
	panel.name = "MenuPanel"
	add_child(panel)
	
	var title = Label.new()
	title.text = "🦇 哥谭大冒险：蝙蝠侠出击"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 0.95))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 25)
	title.size = Vector2(660, 55)
	panel.add_child(title)

	# 战术控制指南面板
	var instr_box = Panel.new()
	var ib_style = StyleBoxFlat.new()
	ib_style.bg_color = Color(0.06, 0.08, 0.16, 0.65)
	ib_style.corner_radius_top_left = 10
	ib_style.corner_radius_top_right = 10
	ib_style.corner_radius_bottom_left = 10
	ib_style.corner_radius_bottom_right = 10
	ib_style.border_width_left = 1
	ib_style.border_width_right = 1
	ib_style.border_width_top = 1
	ib_style.border_width_bottom = 1
	ib_style.border_color = Color(0.3, 0.4, 0.6, 0.4)
	instr_box.add_theme_stylebox_override("panel", ib_style)
	instr_box.position = Vector2(50, 100)
	instr_box.size = Vector2(560, 200)
	panel.add_child(instr_box)
	
	var instr = Label.new()
	instr.text = "【 🎮 全新操控指令与战术手册 】\n\n• A / D 键：左右移动（蝙蝠战衣平滑巡航）\n• Space 空格键：高跳 / 跃上平台\n• 鼠标左键：发射蝙蝠飞镖 (Batarang)\n• ESC 键：暂停菜单 | 第一关为手把手教学试炼"
	instr.add_theme_font_size_override("font_size", 16)
	instr.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.9))
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.position = Vector2(15, 15)
	instr.size = Vector2(530, 170)
	instr_box.add_child(instr)
	
	# 交互式开始游戏按钮
	var start_btn = Button.new()
	start_btn.text = "🚀  开始游戏  (进入 Level 1 教学关)"
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.28, 0.48, 0.9)
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	btn_style.shadow_size = 6
	start_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.28, 0.42, 0.68, 0.95)
	btn_hover.corner_radius_top_left = 12
	btn_hover.corner_radius_top_right = 12
	btn_hover.corner_radius_bottom_left = 12
	btn_hover.corner_radius_bottom_right = 12
	start_btn.add_theme_stylebox_override("hover", btn_hover)
	
	start_btn.position = Vector2(100, 330)
	start_btn.size = Vector2(460, 55)
	start_btn.pressed.connect(func(): _start_game())
	panel.add_child(start_btn)
	
	overlay = CanvasLayer.new()
	overlay.name = "Overlay"
	overlay_label = Label.new()
	overlay_label.text = "按 空格键 或 点击上方按钮 开始出击"
	overlay_label.add_theme_font_size_override("font_size", 22)
	overlay_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 0.9))
	overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	overlay_label.add_theme_constant_override("outline_size", 3)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.position = Vector2(246, 500)
	overlay_label.size = Vector2(660, 35)
	overlay.add_child(overlay_label)
	add_child(overlay)
	overlay_hint = overlay_label

func _start_game():
	current_level = 1
	score = 0
	lives = 3
	_start_level(current_level)

func _start_level(level_idx: int):
	state = GameState.PLAYING
	current_level = level_idx
	is_paused = false
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
	
	# 1. 哥谭夜空底板
	var sky_bg = ColorRect.new()
	sky_bg.color = Color(0.12, 0.16, 0.28, 1.0)
	sky_bg.size = Vector2(cur_width + 800, 1400)
	sky_bg.position = Vector2(-400, -400)
	sky_bg.name = "WorldSkyBG"
	add_child(sky_bg)

	# 2. 哥谭明月
	var moon = ColorRect.new()
	moon.color = Color(1.0, 0.95, 0.7, 0.9)
	moon.size = Vector2(65, 65)
	moon.position = Vector2(cur_width - 310, 20)
	add_child(moon)
	
	# 3. 哥谭夜空柔和浮云
	var clouds_data = [
		[100, 20, 180, 50], [450, -30, 220, 60], [850, 10, 200, 55],
		[1200, -40, 260, 70], [1600, 30, 190, 50], [2100, -20, 240, 60],
		[2600, 10, 210, 55], [3200, -30, 250, 65], [3800, 20, 200, 50], [4400, -10, 230, 60]
	]
	for cd in clouds_data:
		if cd[0] < cur_width + 200:
			var cloud = ColorRect.new()
			cloud.color = Color(0.22, 0.28, 0.42, 0.45)
			cloud.size = Vector2(cd[2], cd[3])
			cloud.position = Vector2(cd[0], cd[1])
			add_child(cloud)

	# 4. 探照灯
	var bat_signal = Polygon2D.new()
	bat_signal.color = Color(1.0, 0.9, 0.3, 0.08)
	bat_signal.polygon = PackedVector2Array([
		Vector2(cur_width - 480, 480), Vector2(cur_width - 580, -150), Vector2(cur_width - 330, -150)
	])
	add_child(bat_signal)

	# 5. 哥谭摩天大楼天际线
	for bx in range(-100, cur_width + 100, 180):
		var bw = 140.0
		var bh = 220.0
		var building = ColorRect.new()
		building.color = Color(0.16, 0.2, 0.32, 0.95)
		building.size = Vector2(bw, bh)
		building.position = Vector2(bx, GROUND_Y - bh + 25)
		add_child(building)
		
		var win1 = ColorRect.new()
		win1.color = Color(1.0, 0.88, 0.35, 0.35)
		win1.size = Vector2(10, 14)
		win1.position = Vector2(bx + 20, GROUND_Y - bh + 50)
		add_child(win1)

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
	
	var grass = ColorRect.new()
	grass.color = Color(0.25, 0.65, 0.2)
	grass.size = Vector2(cur_width, 6)
	grass.position = Vector2(0, GROUND_Y - 2)
	add_child(grass)
	
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
	panel.size = Vector2(560, 52)
	layer.add_child(panel)
	
	# 金币文本
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "💰 " + str(score)
	score_label.position = Vector2(14, 12)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	score_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(score_label)

	# 生命文本 (爱心)
	lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = "❤️ ❤️ ❤️"
	lives_label.position = Vector2(105, 12)
	lives_label.add_theme_font_size_override("font_size", 18)
	lives_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	lives_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lives_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(lives_label)
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
	if not lives_label or not is_instance_valid(lives_label):
		return
	var heart_str = ""
	for i in range(3):
		if i < lives:
			heart_str += "❤️ "
		else:
			heart_str += "🖤 "
	lives_label.text = heart_str.strip_edges()

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

# ─── 暂停菜单 ──────────────────────────────────────

func _toggle_pause():
	is_paused = not is_paused
	get_tree().paused = is_paused
	
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
