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

var player_node = null
var camera = null
var score_label = null
var lives_label = null
var high_score_label = null

var overlay = null
var overlay_label = null
var overlay_hint = null
var pause_overlay = null

# 用于 blink 动画的计时器，避免 set_loops tween 导致未响应
var blink_timer = 0.0
var blink_visible = true

const LEVEL_WIDTH = 1632
const GROUND_Y = 550

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
			# 镜头平滑跟随玩家 (使用 lerp 插值，消除原内置 Smoothing 强刷引发的画面抖动/掉帧)
			if camera and player_node and is_instance_valid(camera) and is_instance_valid(player_node):
				var weight = clamp(12.0 * delta, 0.0, 1.0)
				camera.position = camera.position.lerp(player_node.position, weight)
				# 掉落死亡：玩家掉出关卡底部（防物理bug软锁）
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
				_start_game()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_M:
				_toggle_pause()
				_go_back_menu()
				get_viewport().set_input_as_handled()


# 安全的闪烁效果（用 timer 替代 infinite tween）
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
	
	# 深色绚丽渐变背景
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.22, 1.0)
	bg.size = Vector2(2400, 1600)
	bg.position = Vector2(-400, -300)
	bg.name = "MenuBG"
	add_child(bg)
	
	# 背景装饰点阵/星光
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
	
	# 主卡片面板
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.28, 0.85)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.4)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(276, 100)
	panel.size = Vector2(600, 440)
	panel.name = "MenuPanel"
	add_child(panel)
	
	# 标题
	var title = Label.new()
	title.text = "🦇 哥谭大冒险：蝙蝠侠出击"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 0.95))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(600, 60)
	panel.add_child(title)

	# 操作说明卡片
	var instr_box = Panel.new()
	var ib_style = StyleBoxFlat.new()
	ib_style.bg_color = Color(0.06, 0.08, 0.16, 0.6)
	ib_style.corner_radius_top_left = 10
	ib_style.corner_radius_top_right = 10
	ib_style.corner_radius_bottom_left = 10
	ib_style.corner_radius_bottom_right = 10
	instr_box.add_theme_stylebox_override("panel", ib_style)
	instr_box.position = Vector2(50, 150)
	instr_box.size = Vector2(500, 140)
	panel.add_child(instr_box)
	
	var instr = Label.new()
	instr.text = "【蝙蝠侠战术操作】\n\n• A / D  或  ← → 键：蝙蝠战衣平滑巡航\n• Space / W / ↑ 键：蝙蝠披风高跳 / 跃上平台\n• ESC 键：暂停战术菜单  |  踩在怪物头顶将其制裁"
	instr.add_theme_font_size_override("font_size", 16)
	instr.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.85))
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.position = Vector2(10, 12)
	instr.size = Vector2(480, 116)
	instr_box.add_child(instr)
	
	# 开始提示
	overlay = CanvasLayer.new()
	overlay.name = "Overlay"
	overlay_label = Label.new()
	overlay_label.text = "按 空格键 扮演蝙蝠侠出击"
	overlay_label.add_theme_font_size_override("font_size", 28)
	overlay_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 0.95))
	overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	overlay_label.add_theme_constant_override("outline_size", 4)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.position = Vector2(276, 420)
	overlay_label.size = Vector2(600, 45)
	overlay.add_child(overlay_label)
	add_child(overlay)
	overlay_hint = overlay_label

func _start_game():
	state = GameState.PLAYING
	score = 0
	lives = 3
	is_paused = false
	get_tree().paused = false
	blink_timer = 0.0
	
	_overlay = null
	overlay = null
	overlay_label = null
	overlay_hint = null
	pause_overlay = null
	
	# 安全删除所有菜单子节点
	var kids = get_children()
	for c in kids:
		if c.name in ["MenuBG", "Stars", "MenuPanel", "Overlay"]:
			c.queue_free()
	
	_create_world()
	_create_player()
	_create_hud()
	
	# 镜头初始化直接贴合玩家位置
	if camera and player_node:
		camera.position = player_node.position

func _go_back_menu():
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
	is_paused = false
	get_tree().paused = false
	
	var kids = get_children()
	for c in kids:
		c.queue_free()
	
	_create_menu()

# ─── 世界构建 ──────────────────────────────────────

func _create_world():
	# 1. 哥谭夜空底板 (适度调浅明度为 Color(0.12, 0.16, 0.28)，使暗色蝙蝠侠轮廓清晰突出)
	var sky_bg = ColorRect.new()
	sky_bg.color = Color(0.12, 0.16, 0.28, 1.0)
	sky_bg.size = Vector2(LEVEL_WIDTH + 800, 1400)
	sky_bg.position = Vector2(-400, -400)
	sky_bg.name = "WorldSkyBG"
	add_child(sky_bg)

	# 2. 哥谭明月 (Glowing Round Moon)
	var moon = ColorRect.new()
	moon.color = Color(1.0, 0.95, 0.7, 0.9)
	moon.size = Vector2(65, 65)
	moon.position = Vector2(1320, 20)
	add_child(moon)
	
	# 3. 哥谭夜空柔和浮云 (Gotham Night Clouds)
	var clouds_data = [
		[100, 20, 180, 50],
		[450, -30, 220, 60],
		[850, 10, 200, 55],
		[1200, -40, 260, 70],
		[1500, 30, 190, 50]
	]
	for cd in clouds_data:
		var cloud = ColorRect.new()
		cloud.color = Color(0.22, 0.28, 0.42, 0.45)
		cloud.size = Vector2(cd[2], cd[3])
		cloud.position = Vector2(cd[0], cd[1])
		add_child(cloud)

	# 4. 极淡蝙蝠探照信号灯束 (Subtle Bat-Signal Spotlight Beam)
	var bat_signal = Polygon2D.new()
	bat_signal.color = Color(1.0, 0.9, 0.3, 0.08)
	bat_signal.polygon = PackedVector2Array([
		Vector2(1150, 480), Vector2(1050, -150), Vector2(1300, -150)
	])
	add_child(bat_signal)

	# 5. 哥谭摩天大楼天际线 (低节点开销，精简视觉效果)
	var buildings_data = [
		[-100, 140, 200], [70, 120, 240], [210, 150, 180], [380, 140, 260],
		[540, 130, 210], [700, 160, 190], [890, 140, 250], [1050, 150, 220],
		[1220, 130, 270], [1380, 160, 200], [1560, 150, 230]
	]
	for b in buildings_data:
		var bx = b[0]
		var bw = b[1]
		var bh = b[2]
		var building = ColorRect.new()
		building.color = Color(0.16, 0.2, 0.32, 0.95)
		building.size = Vector2(bw, bh)
		building.position = Vector2(bx, GROUND_Y - bh + 25)
		add_child(building)
		
		# 少数几扇柔和窗口，避免节点过度膨胀
		var win1 = ColorRect.new()
		win1.color = Color(1.0, 0.88, 0.35, 0.35)
		win1.size = Vector2(10, 14)
		win1.position = Vector2(bx + 20, GROUND_Y - bh + 50)
		add_child(win1)
		
		var win2 = ColorRect.new()
		win2.color = Color(0.4, 0.85, 1.0, 0.3)
		win2.size = Vector2(10, 14)
		win2.position = Vector2(bx + bw - 30, GROUND_Y - bh + 90)
		add_child(win2)

	var cam = Camera2D.new()
	cam.name = "Camera2D"
	cam.enabled = true
	cam.position_smoothing_enabled = false
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH
	cam.limit_top = -200
	cam.limit_bottom = 600
	add_child(cam)
	camera = cam



	
	# 地面
	_add_static_rect(LEVEL_WIDTH / 2, GROUND_Y + 25, LEVEL_WIDTH, 50, Color(0.28, 0.22, 0.16))
	
	# 草地装饰线
	var grass = ColorRect.new()
	grass.color = Color(0.25, 0.65, 0.2)
	grass.size = Vector2(LEVEL_WIDTH, 6)
	grass.position = Vector2(0, GROUND_Y - 2)
	add_child(grass)
	
	# 浮空平台（静态 + 动态移动平台）
	var platform_data = [
		[400, 428, 120, 16],
		[900, 338, 120, 16],
		[1150, 293, 120, 16],
		[1400, 248, 120, 16],
		[300, 488, 100, 16],
		[750, 458, 100, 16],
	]
	for pd in platform_data:
		_add_static_rect(pd[0], pd[1], pd[2], pd[3], Color(0.32, 0.2, 0.1), 2)
		
	# 动态移动单向平台 (Moving Platforms)
	var mp1 = MovingPlatform.new()
	mp1.position = Vector2(650, 380)
	mp1.move_distance = 110.0
	mp1.move_speed = 2.0
	add_child(mp1)
	
	var mp2 = MovingPlatform.new()
	mp2.position = Vector2(1050, 400)
	mp2.move_distance = 90.0
	mp2.move_speed = 1.6
	mp2.is_vertical = true
	add_child(mp2)

	# 地刺陷阱 (Hazard Spikes)
	var h1 = Hazard.new()
	h1.position = Vector2(520, GROUND_Y)
	add_child(h1)
	
	var h2 = Hazard.new()
	h2.position = Vector2(1020, GROUND_Y)
	add_child(h2)

	# 金币
	var coin_positions = [
		Vector2(200, 410),
		Vector2(400, 408),
		Vector2(550, 470),
		Vector2(650, 320),
		Vector2(750, 440),
		Vector2(900, 318),
		Vector2(1050, 330),
		Vector2(1100, 388),
		Vector2(1150, 273),
		Vector2(1400, 228),
	]
	for pos in coin_positions:
		var coin = Coin.new()
		coin.position = pos
		add_child(coin)
	
	# 地面追击敌人 (Ground Chasing Enemies)
	var e1 = Enemy.new()
	e1.position = Vector2(300, GROUND_Y - 12)
	e1.patrol_range = 200
	add_child(e1)
	
	var e2 = Enemy.new()
	e2.position = Vector2(800, GROUND_Y - 12)
	e2.patrol_range = 250
	add_child(e2)
	
	var e3 = Enemy.new()
	e3.position = Vector2(1300, GROUND_Y - 12)
	e3.patrol_range = 180
	add_child(e3)
	
	# 飞行小丑无人机敌人 (Fly Drone Enemies)
	var fe1 = FlyEnemy.new()
	fe1.position = Vector2(700, 260)
	fe1.patrol_range = 140.0
	add_child(fe1)
	
	var fe2 = FlyEnemy.new()
	fe2.position = Vector2(1250, 210)
	fe2.patrol_range = 120.0
	add_child(fe2)
	
	_create_finish()

func _add_static_rect(x, y, w, h, color, collision_layer := 1):
	var body = StaticBody2D.new()
	body.collision_layer = collision_layer
	var shape = RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var col = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	body.position = Vector2(x, y)
	add_child(body)
	
	var vis = ColorRect.new()
	vis.color = color
	vis.size = Vector2(w, h)
	vis.position = Vector2(-w/2, -h/2)
	body.add_child(vis)

func _create_finish():
	var finish = Area2D.new()
	finish.name = "Finish"
	finish.collision_mask = 1
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 100)
	var col = CollisionShape2D.new()
	col.shape = shape
	finish.add_child(col)
	finish.position = Vector2(1560, GROUND_Y - 50)
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
	player_node = Player.new()
	player_node.name = "Player"
	player_node.position = Vector2(80, GROUND_Y - 18)
	add_child(player_node)

# ─── HUD 现代化升级 ─────────────────────────────────

func _create_hud():
	var layer = CanvasLayer.new()
	layer.name = "HUD"
	
	# HUD 主背景容器
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
	panel.size = Vector2(320, 52)
	layer.add_child(panel)
	
	# 金币文本
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "💰 金币: 0"
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
	lives_label.position = Vector2(140, 12)
	lives_label.add_theme_font_size_override("font_size", 18)
	lives_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	lives_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lives_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(lives_label)
	
	# 最高分
	high_score_label = Label.new()
	high_score_label.name = "HighScoreLabel"
	high_score_label.text = "👑 " + str(high_score)
	high_score_label.position = Vector2(250, 12)
	high_score_label.add_theme_font_size_override("font_size", 16)
	high_score_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	panel.add_child(high_score_label)
	
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
		p_title.text = "⏸️ 游戏暂停"
		p_title.add_theme_font_size_override("font_size", 32)
		p_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_title.position = Vector2(0, 30)
		p_title.size = Vector2(352, 45)
		panel.add_child(p_title)
		
		var p_hint = Label.new()
		p_hint.text = "按 ESC 键恢复游戏\n按 R 键重新开始\n按 M 键返回主菜单"
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
		score_label.text = "💰 金币: " + str(score)
	if coin:
		_spawn_floating_text(coin.position, "+1", Color(1.0, 0.9, 0.2))
		_spawn_particle_burst(coin.position, Color(1.0, 0.85, 0.2))

func _on_enemy_stomped(enemy):
	if state != GameState.PLAYING:
		return
	score += 2
	if score_label and is_instance_valid(score_label):
		score_label.text = "💰 金币: " + str(score)
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
				# 延迟弹出 Game Over 界面，等死亡动画显示
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
	overlay_label.add_theme_font_size_override("font_size", 42)
	overlay_label.add_theme_color_override("font_color", title_color)
	overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	overlay_label.add_theme_constant_override("outline_size", 5)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_label.position = Vector2(0, 25)
	overlay_label.size = Vector2(500, 60)
	panel.add_child(overlay_label)
	
	# 最高分突破判断与展示
	var is_new_record = false
	if score > high_score:
		high_score = score
		_save_high_score()
		is_new_record = true
	
	var score_info = Label.new()
	score_info.text = "本次得分: " + str(score) + ("  (🎉 刷新最高纪录!)" if is_new_record else "  (最高: " + str(high_score) + ")")
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
	
	# 重置 blink 状态，下一帧 _process 开始闪烁
	blink_timer = 0.0
	blink_visible = true
	overlay_hint.modulate.a = 0.95

func _win_game():
	state = GameState.WON
	if player_node:
		player_node.input_disabled = true
	_show_overlay("🎉  关 卡 通 关  🎉", Color(0.35, 1.0, 0.4), "按 空格键 返回主菜单")

func _game_over():
	state = GameState.GAME_OVER
	if player_node:
		player_node.input_disabled = true
	_show_overlay("💀  游 戏 结 束  💀", Color(1.0, 0.35, 0.35), "按 空格键 返回主菜单")

