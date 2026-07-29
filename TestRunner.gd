extends SceneTree

const Game = preload("res://Game.gd")

var game_instance = null
var frame_count = 0

# 性能与游玩采样数据
var fps_samples: Array[float] = []
var process_time_samples: Array[float] = []
var physics_time_samples: Array[float] = []
var spike_count = 0
var total_test_frames = 800  # 增加到 800 帧以提高白闪捕获概率

# 延迟保存截图字典，避免主线程磁盘 I/O 阻塞游玩测试
var pending_captures = {}

# ─── 白闪诊断专用变量 ───────────────────────────────
var white_flash_events: Array[Dictionary] = []  # 记录所有白闪事件
var prev_camera_pos = Vector2.ZERO               # 上一帧镜头位置
var prev_delta = 0.016                            # 上一帧 delta
var prev_node_count = 0                           # 上一帧节点数
var delta_spike_log: Array[Dictionary] = []       # delta 尖峰日志
var camera_jump_log: Array[Dictionary] = []       # 镜头跳变日志
var ghost_frame_log: Array[Dictionary] = []       # 幽灵帧日志 (节点骤减)
var polygon_degenerate_log: Array[Dictionary] = [] # 多边形退化日志

# 像素采样白闪检测阈值
const WHITE_THRESHOLD = 0.88   # RGB 任一通道 > 此值且三通道均值 > 0.85 视为异常白
const WHITE_AVG_THRESHOLD = 0.82
# 采样网格 (在视口中均匀采样 25 个点)
const SAMPLE_COLS = 5
const SAMPLE_ROWS = 5

func _initialize():
	print("============================================================")
	print("[TestRunner] 🔬 启动 800 帧白闪诊断深度分析测试...")
	print("[TestRunner] 诊断模块: 像素采样 | Delta Spike | Camera 跳变 | 幽灵帧 | 多边形退化")
	print("============================================================")
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	game_instance = Game.new()
	root.add_child(game_instance)
	
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	
	# 基础性能采样 (120 帧后稳定运行期)
	var current_fps = Engine.get_frames_per_second()
	var proc_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var current_delta = 1.0 / max(current_fps, 1.0)
	var current_node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	
	if frame_count > 120:
		fps_samples.append(current_fps)
		process_time_samples.append(proc_time)
		physics_time_samples.append(phys_time)
		if proc_time > 20.0 and current_fps < 50:
			spike_count += 1

	# ─── 1. 菜单阶段 (Frame 5) ──────────────────────
	if frame_count == 5:
		_queue_capture("screenshot_01_menu.png")
		print("[TestRunner] 模拟空格键按下 -> 触发开始游戏 (Level 1)")
		game_instance._start_game()
		if game_instance.camera:
			prev_camera_pos = game_instance.camera.position

	# ─── 2. 游戏内模拟激进游玩与跨关加载 ──────────────
	elif frame_count > 5 and frame_count < total_test_frames:
		# 在 Frame 250 模拟通关第 1 关，跳转进入 Level 2
		if frame_count == 250:
			print("[TestRunner] 模拟到达 Level 1 终点 -> 触发通关跳转 Level 2")
			game_instance._win_game()
			game_instance._go_back_menu()
		# 在 Frame 500 模拟通关，直接跳转体验终极 Level 5 (5000px 终极关卡)
		elif frame_count == 500:
			print("[TestRunner] 模拟跨关挑战 -> 加载 Level 5 (5000px 终极关卡)")
			game_instance._start_level(5)
			
		var p = game_instance.player_node
		if p and is_instance_valid(p) and not p.is_dead:
			# 持续向右平滑快速推进，探索 5000px 超长地图
			var move_dir = 1.0 if (int(frame_count / 30) % 4 != 0) else -1.0
			p.velocity.x = move_dir * p.SPEED
			p.facing_right = (move_dir > 0)
			
			if frame_count % 25 == 0 and p.is_on_floor():
				p.velocity.y = p.JUMP_VELOCITY
				
			# 模拟频繁发送鼠标左键点击事件 (测试鼠标左键与 J 键通道)
			if frame_count % 20 == 0:
				var mb = InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT
				mb.pressed = true
				mb.position = Vector2(p.position.x + 100.0 * (1.0 if p.facing_right else -1.0), p.position.y)
				p._input(mb)

	# ─── 3. 白闪诊断：多维度检测 (仅在游戏运行期 Frame 10+) ──
	if frame_count >= 10 and frame_count < total_test_frames:
		_diagnose_delta_spike(current_delta, proc_time)
		_diagnose_camera_jump()
		_diagnose_ghost_frame(current_node_count)
		_diagnose_polygon_degenerate()
		_diagnose_pixel_sampling()

	prev_delta = current_delta
	prev_node_count = current_node_count

	# 捕获关键帧快照
	if frame_count == 60:
		_queue_capture("screenshot_02_gameplay.png")
	elif frame_count == 80:
		_queue_capture("screenshot_03_jumping.png")

	# ─── 4. 完成测试：输出分析报告 ────────────────────
	if frame_count >= total_test_frames:
		_save_all_pending_captures()
		_finish_test_and_report()
		quit(0)

# ════════════════════════════════════════════════════
# 白闪诊断模块 1: Delta Spike 检测 (Camera lerp 跳变风险)
# ════════════════════════════════════════════════════
func _diagnose_delta_spike(current_delta: float, proc_time: float):
	# 正常 delta ≈ 0.016s (60FPS)，超过 0.025s (40FPS) 视为异常
	if current_delta > 0.025:
		var entry = {
			"frame": frame_count,
			"delta": snappedf(current_delta, 0.001),
			"proc_ms": snappedf(proc_time, 0.1),
			"ratio_to_normal": snappedf(current_delta / 0.0167, 0.01)
		}
		delta_spike_log.append(entry)
		print("[⚠ DELTA SPIKE] 帧 %d: delta=%.4fs (正常值的 %.1fx), Process=%.2fms" % [
			frame_count, current_delta, current_delta / 0.0167, proc_time])

# ════════════════════════════════════════════════════
# 白闪诊断模块 2: Camera 镜头跳变检测 (背景撕裂风险)
# ════════════════════════════════════════════════════
func _diagnose_camera_jump():
	if not game_instance.camera or not is_instance_valid(game_instance.camera):
		return
	var cam_pos = game_instance.camera.position
	var jump_dist = cam_pos.distance_to(prev_camera_pos)
	# 正常 lerp 跟随每帧移动 < 15px，超过 30px 视为异常跳变
	if jump_dist > 30.0 and frame_count > 10:
		var entry = {
			"frame": frame_count,
			"prev_pos": [snappedf(prev_camera_pos.x, 0.1), snappedf(prev_camera_pos.y, 0.1)],
			"curr_pos": [snappedf(cam_pos.x, 0.1), snappedf(cam_pos.y, 0.1)],
			"jump_dist": snappedf(jump_dist, 0.1)
		}
		camera_jump_log.append(entry)
		print("[⚠ CAMERA JUMP] 帧 %d: 镜头跳变 %.1fpx (%s → %s)" % [
			frame_count, jump_dist, str(prev_camera_pos), str(cam_pos)])
	prev_camera_pos = cam_pos

# ════════════════════════════════════════════════════
# 白闪诊断模块 3: 幽灵帧检测 (queue_free 前最后一帧绘制)
# ════════════════════════════════════════════════════
func _diagnose_ghost_frame(current_count: int):
	# 节点数突然减少 >= 2 表明有节点被 queue_free，可能产生幽灵帧
	var diff = prev_node_count - current_count
	if diff >= 2 and frame_count > 10:
		# 检查是否有金币/敌人刚被释放
		var coins_alive = 0
		var enemies_alive = 0
		for node in game_instance.get_children():
			if node.is_in_group("coins"):
				coins_alive += 1
			elif node.is_in_group("enemies"):
				enemies_alive += 1
		var entry = {
			"frame": frame_count,
			"nodes_freed": diff,
			"prev_count": prev_node_count,
			"curr_count": current_count,
			"coins_alive": coins_alive,
			"enemies_alive": enemies_alive
		}
		ghost_frame_log.append(entry)
		print("[⚠ GHOST FRAME] 帧 %d: 节点骤减 %d 个 (从 %d → %d), 剩余金币=%d 敌人=%d" % [
			frame_count, diff, prev_node_count, current_count, coins_alive, enemies_alive])
		# 在幽灵帧发生时自动截图取证
		_queue_capture("screenshot_ghost_frame_%d.png" % frame_count)

# ════════════════════════════════════════════════════
# 白闪诊断模块 4: 多边形退化检测 (斗篷/护臂 winding order 翻转)
# ════════════════════════════════════════════════════
func _diagnose_polygon_degenerate():
	var p = game_instance.player_node
	if not p or not is_instance_valid(p) or p.is_dead:
		return
	
	var flip = 1.0 if p.facing_right else -1.0
	var is_moving = abs(p.velocity.x) > 10.0
	var is_airborne = not p.is_on_floor()
	
	# 模拟斗篷多边形顶点计算 (与 Player.gd _draw 相同逻辑)
	var breath_y = sin(p.anim_time * 3.5) * 1.0 if (not is_moving and not is_airborne) else 0.0
	var torso_y = -7 + breath_y
	var cape_wave = sin(p.anim_time * 12.0) * 4.0 if is_moving else sin(p.anim_time * 2.5) * 1.5
	
	var cape_points: PackedVector2Array
	if is_airborne:
		cape_points = PackedVector2Array([
			Vector2(-4 * flip, torso_y - 4), Vector2(-26 * flip, torso_y - 6),
			Vector2(-30 * flip, torso_y + 16), Vector2(-18 * flip, torso_y + 24),
			Vector2(-6 * flip, torso_y + 18), Vector2(4 * flip, torso_y + 8)
		])
	elif is_moving:
		cape_points = PackedVector2Array([
			Vector2(-4 * flip, torso_y - 4), Vector2(-20 * flip + cape_wave, torso_y + 4),
			Vector2(-26 * flip + cape_wave, torso_y + 18 + cape_wave),
			Vector2(-14 * flip, torso_y + 20), Vector2(-4 * flip, torso_y + 14),
			Vector2(2 * flip, torso_y + 10)
		])
	else:
		cape_points = PackedVector2Array([
			Vector2(-4 * flip, torso_y - 4), Vector2(-14 * flip + cape_wave, torso_y + 6),
			Vector2(-18 * flip + cape_wave, torso_y + 22),
			Vector2(-10 * flip, torso_y + 22), Vector2(-4 * flip, torso_y + 14),
			Vector2(2 * flip, torso_y + 10)
		])
	
	# 计算多边形面积 (Shoelace formula)，面积为负表示 winding order 翻转
	var area = _polygon_signed_area(cape_points)
	var min_edge = _polygon_min_edge_length(cape_points)
	
	if abs(area) < 5.0 or min_edge < 1.5:
		var entry = {
			"frame": frame_count,
			"facing_right": p.facing_right,
			"is_moving": is_moving,
			"is_airborne": is_airborne,
			"cape_wave": snappedf(cape_wave, 0.01),
			"signed_area": snappedf(area, 0.01),
			"min_edge_length": snappedf(min_edge, 0.01),
			"anim_time": snappedf(p.anim_time, 0.001)
		}
		polygon_degenerate_log.append(entry)
		print("[⚠ POLYGON DEGENERATE] 帧 %d: 斗篷多边形退化! 面积=%.2f 最短边=%.2fpx 朝向=%s 状态=%s cape_wave=%.2f" % [
			frame_count, area, min_edge,
			"右" if p.facing_right else "左",
			"空中" if is_airborne else ("奔跑" if is_moving else "待机"),
			cape_wave])
		_queue_capture("screenshot_polygon_degenerate_%d.png" % frame_count)
	
	# 额外检测护臂刺刺三角形退化
	var leg_swing = sin(p.anim_time * 16.0) * 5.0 if (is_moving and not is_airborne) else 0.0
	var arm_swing = -leg_swing * 0.8
	var left_arm_y = torso_y + 2 + arm_swing
	var right_arm_y = torso_y + 2 - arm_swing
	
	# 左护臂三角形
	var left_gauntlet = PackedVector2Array([
		Vector2(-12, left_arm_y + 3), Vector2(-15 * flip, left_arm_y + 5), Vector2(-12, left_arm_y + 7)
	])
	var lg_area = abs(_polygon_signed_area(left_gauntlet))
	if lg_area < 2.0:
		print("[⚠ GAUNTLET DEGENERATE] 帧 %d: 左护臂三角形退化! 面积=%.2f flip=%.1f" % [frame_count, lg_area, flip])

# ════════════════════════════════════════════════════
# 白闪诊断模块 5: 逐帧像素采样白闪检测
# ════════════════════════════════════════════════════
func _diagnose_pixel_sampling():
	# 每 3 帧采样一次 (避免每帧 get_image 的性能开销)
	if frame_count % 3 != 0:
		return
	
	var img = root.get_texture().get_image()
	if not img:
		return
	
	var vw = img.get_width()
	var vh = img.get_height()
	if vw == 0 or vh == 0:
		return
	
	var white_pixels: Array[Dictionary] = []
	
	# 在视口中均匀采样 5x5 = 25 个点
	for row in range(SAMPLE_ROWS):
		for col in range(SAMPLE_COLS):
			var sx = int((col + 0.5) * vw / SAMPLE_COLS)
			var sy = int((row + 0.5) * vh / SAMPLE_ROWS)
			sx = clampi(sx, 0, vw - 1)
			sy = clampi(sy, 0, vh - 1)
			var pixel = img.get_pixel(sx, sy)
			var avg = (pixel.r + pixel.g + pixel.b) / 3.0
			
			# 检测异常白色像素 (游戏背景为暗色 0.12~0.28，正常不应出现大面积高亮白)
			# 排除已知的合法亮色：金币(黄) 眼睛(白但很小) 腰带(黄) 月亮(暖黄)
			if pixel.r > WHITE_THRESHOLD and pixel.g > WHITE_THRESHOLD and pixel.b > WHITE_THRESHOLD and avg > WHITE_AVG_THRESHOLD:
				white_pixels.append({
					"x": sx, "y": sy,
					"r": snappedf(pixel.r, 0.01),
					"g": snappedf(pixel.g, 0.01),
					"b": snappedf(pixel.b, 0.01),
					"a": snappedf(pixel.a, 0.01)
				})
	
	# 如果检测到 3 个以上异常白色采样点，大概率是白闪
	if white_pixels.size() >= 3:
		var p = game_instance.player_node
		var player_info = {}
		if p and is_instance_valid(p):
			player_info = {
				"pos": [snappedf(p.position.x, 0.1), snappedf(p.position.y, 0.1)],
				"vel": [snappedf(p.velocity.x, 0.1), snappedf(p.velocity.y, 0.1)],
				"facing_right": p.facing_right,
				"is_on_floor": p.is_on_floor(),
				"invincible": p.invincible_timer > 0,
				"anim_time": snappedf(p.anim_time, 0.001),
				"modulate_a": snappedf(p.modulate.a, 0.01)
			}
		
		var cam_info = {}
		if game_instance.camera and is_instance_valid(game_instance.camera):
			cam_info = {
				"pos": [snappedf(game_instance.camera.position.x, 0.1), snappedf(game_instance.camera.position.y, 0.1)]
			}
		
		var event = {
			"frame": frame_count,
			"white_pixel_count": white_pixels.size(),
			"white_pixels": white_pixels,
			"player": player_info,
			"camera": cam_info,
			"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"fps": Engine.get_frames_per_second()
		}
		white_flash_events.append(event)
		
		print("[🔴 WHITE FLASH DETECTED] 帧 %d: 检测到 %d 个异常白色像素!" % [frame_count, white_pixels.size()])
		for wp in white_pixels:
			print("    像素 (%d, %d): R=%.2f G=%.2f B=%.2f A=%.2f" % [wp.x, wp.y, wp.r, wp.g, wp.b, wp.a])
		if player_info.size() > 0:
			print("    玩家: pos=%s vel=%s 朝向=%s 地面=%s 无敌=%s anim=%.3f alpha=%.2f" % [
				str(player_info.pos), str(player_info.vel),
				"右" if player_info.facing_right else "左",
				"是" if player_info.is_on_floor else "否",
				"是" if player_info.invincible else "否",
				player_info.anim_time, player_info.modulate_a])
		
		# 白闪帧截图取证
		_queue_capture("screenshot_WHITE_FLASH_frame_%d.png" % frame_count)

# ════════════════════════════════════════════════════
# 工具函数
# ════════════════════════════════════════════════════

func _polygon_signed_area(points: PackedVector2Array) -> float:
	"""用 Shoelace 公式计算多边形的有符号面积，正=逆时针，负=顺时针"""
	var area = 0.0
	var n = points.size()
	for i in range(n):
		var j = (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	return area / 2.0

func _polygon_min_edge_length(points: PackedVector2Array) -> float:
	"""计算多边形最短边长度"""
	var min_len = 99999.0
	var n = points.size()
	for i in range(n):
		var j = (i + 1) % n
		var edge_len = points[i].distance_to(points[j])
		if edge_len < min_len:
			min_len = edge_len
	return min_len

func _queue_capture(filename: String):
	var img = root.get_texture().get_image()
	if img:
		pending_captures[filename] = img
		print("[TestRunner] 📸 内存捕获快照: %s" % [filename])

func _save_all_pending_captures():
	for filename in pending_captures:
		var img: Image = pending_captures[filename]
		var path = "res://screenshots/" + filename
		img.save_png(path)
		print("[TestRunner] 💾 磁盘落盘完成: %s" % [path])

func _finish_test_and_report():
	# ─── 性能统计 ─────────────────────────────────
	var avg_fps = 0.0
	var min_fps = 999.0
	var max_fps = 0.0
	for f in fps_samples:
		avg_fps += f
		if f < min_fps: min_fps = f
		if f > max_fps: max_fps = f
	if fps_samples.size() > 0:
		avg_fps /= fps_samples.size()
	else:
		min_fps = 0.0
		
	var avg_proc = 0.0
	for p in process_time_samples: avg_proc += p
	if process_time_samples.size() > 0: avg_proc /= process_time_samples.size()
	
	var avg_phys = 0.0
	for ph in physics_time_samples: avg_phys += ph
	if physics_time_samples.size() > 0: avg_phys /= physics_time_samples.size()
	
	var nodes_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	print("")
	print("============================================================")
	print("📊 自动化游玩测试与白闪诊断分析报告 (800 帧)")
	print("============================================================")
	print("")
	print("── 性能基准 ──")
	print("  运行期平均帧率 (Avg FPS): %.1f" % [avg_fps])
	print("  运行期最低帧率 (Min FPS): %d" % [int(min_fps)])
	print("  运行期最高帧率 (Max FPS): %d" % [int(max_fps)])
	print("  卡顿掉帧次数 (Spikes <50FPS): %d" % [spike_count])
	print("  平均 Physics 耗时: %.3f ms" % [avg_phys])
	print("  活跃 SceneTree 节点数: %d" % [nodes_count])
	print("  孤立节点泄漏数 (Orphans): %d" % [orphan_count])
	print("  每帧 Draw Calls 次数: %d" % [draw_calls])
	print("")
	
	# ─── 白闪诊断汇总 ────────────────────────────────
	print("── 🔬 白闪诊断汇总 ──")
	print("")
	
	print("  [像素采样白闪事件]: %d 次" % [white_flash_events.size()])
	if white_flash_events.size() > 0:
		for evt in white_flash_events:
			print("    帧 %d: %d 个异常白像素, FPS=%d, 节点数=%d" % [
				evt.frame, evt.white_pixel_count, evt.fps, evt.node_count])
			if evt.player.size() > 0:
				print("      玩家: 朝向=%s 地面=%s 无敌=%s anim=%.3f" % [
					"右" if evt.player.facing_right else "左",
					"是" if evt.player.is_on_floor else "否",
					"是" if evt.player.invincible else "否",
					evt.player.anim_time])
	print("")
	
	print("  [Delta Spike 尖峰]: %d 次" % [delta_spike_log.size()])
	for ds in delta_spike_log:
		print("    帧 %d: delta=%.4fs (%.1fx), Process=%.2fms" % [
			ds.frame, ds.delta, ds.ratio_to_normal, ds.proc_ms])
	print("")
	
	print("  [Camera 镜头跳变]: %d 次" % [camera_jump_log.size()])
	for cj in camera_jump_log:
		print("    帧 %d: 跳变 %.1fpx" % [cj.frame, cj.jump_dist])
	print("")
	
	print("  [幽灵帧 (节点骤减)]: %d 次" % [ghost_frame_log.size()])
	for gf in ghost_frame_log:
		print("    帧 %d: 减少 %d 个节点 (%d→%d), 剩余金币=%d 敌人=%d" % [
			gf.frame, gf.nodes_freed, gf.prev_count, gf.curr_count, gf.coins_alive, gf.enemies_alive])
	print("")
	
	print("  [多边形退化]: %d 次" % [polygon_degenerate_log.size()])
	for pd in polygon_degenerate_log:
		print("    帧 %d: 面积=%.2f 最短边=%.2fpx 朝向=%s 状态=%s" % [
			pd.frame, pd.signed_area, pd.min_edge_length,
			"右" if pd.facing_right else "左",
			"空中" if pd.is_airborne else ("奔跑" if pd.is_moving else "待机")])
	print("")
	
	# ─── 根因关联分析 ────────────────────────────────
	print("── 🎯 根因关联分析 ──")
	if white_flash_events.size() == 0:
		print("  ✅ 800 帧测试中未检测到白闪事件。")
		print("  提示: 白闪可能是极低概率事件，建议增加测试帧数或更激进的操作模式。")
	else:
		# 将白闪帧与其他事件进行时序关联
		for evt in white_flash_events:
			var f = evt.frame
			var correlations = []
			for ds in delta_spike_log:
				if abs(ds.frame - f) <= 2:
					correlations.append("Delta Spike (帧 %d, %.4fs)" % [ds.frame, ds.delta])
			for cj in camera_jump_log:
				if abs(cj.frame - f) <= 2:
					correlations.append("Camera 跳变 (帧 %d, %.1fpx)" % [cj.frame, cj.jump_dist])
			for gf in ghost_frame_log:
				if abs(gf.frame - f) <= 2:
					correlations.append("幽灵帧 (帧 %d, 减少 %d 节点)" % [gf.frame, gf.nodes_freed])
			for pd in polygon_degenerate_log:
				if abs(pd.frame - f) <= 2:
					correlations.append("多边形退化 (帧 %d, 面积=%.2f)" % [pd.frame, pd.signed_area])
			
			if correlations.size() > 0:
				print("  🔴 帧 %d 白闪关联事件:" % f)
				for c in correlations:
					print("    → %s" % c)
			else:
				print("  🔴 帧 %d 白闪未找到关联事件 (可能是 GPU 驱动级渲染异常)" % f)
	
	print("")
	print("============================================================")
	
	# 保存 JSON 诊断报告
	var snapshot_data = {
		"test_frames": total_test_frames,
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"max_fps": max_fps,
		"spike_count": spike_count,
		"avg_process_ms": avg_proc,
		"avg_physics_ms": avg_phys,
		"orphan_count": orphan_count,
		"draw_calls": draw_calls,
		"white_flash_events": white_flash_events,
		"delta_spike_log": delta_spike_log,
		"camera_jump_log": camera_jump_log,
		"ghost_frame_log": ghost_frame_log,
		"polygon_degenerate_log": polygon_degenerate_log
	}
	var f = FileAccess.open("res://.monitor_snapshot.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snapshot_data, "\t"))
		f.close()
	print("[TestRunner] 📄 诊断报告已保存至 .monitor_snapshot.json")
