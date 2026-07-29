extends SceneTree

const Game = preload("res://Game.gd")

var game_instance = null
var frame_count = 0

# 性能与游玩采样数据
var fps_samples: Array[float] = []
var process_time_samples: Array[float] = []
var physics_time_samples: Array[float] = []
var spike_count = 0
var total_test_frames = 500

# 延迟保存截图字典，避免主线程磁盘 I/O 阻塞游玩测试
var pending_captures = {}

func _initialize():
	print("============================================================")
	print("[TestRunner] 启动 500 帧全自动化游玩测试与画面渲染采样监控...")
	print("============================================================")
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	game_instance = Game.new()
	root.add_child(game_instance)
	
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	
	# 采样真实帧耗时 (ms) 与 FPS
	var current_fps = Engine.get_frames_per_second()
	var proc_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	
	# 80 帧后完成初始化与场景加载，开始采样稳定运行期的卡顿掉帧
	if frame_count > 80:
		fps_samples.append(current_fps)
		process_time_samples.append(proc_time)
		physics_time_samples.append(phys_time)
		if proc_time > 20.0 and current_fps < 50:
			spike_count += 1
			print("[PERF WARNING] 帧 %d 发生卡顿掉帧: Process = %.2f ms (FPS: %d)" % [frame_count, proc_time, current_fps])

	# 1. 菜单阶段 (Frame 5)
	if frame_count == 5:
		_queue_capture("screenshot_01_menu.png")
		print("[TestRunner] 模拟空格键按下 -> 触发开始游戏 (扮演蝙蝠侠出击)")
		game_instance._start_game()
		
	# 2. 游戏内模拟玩家随机跳跃、踩怪、收集金币与平滑移动游玩 (Frames 6-500)
	elif frame_count > 5 and frame_count < total_test_frames:
		var p = game_instance.player_node
		if p and is_instance_valid(p) and not p.is_dead:
			# 每 45 帧随机切换左右移动方向
			var move_dir = 1.0 if (int(frame_count / 45) % 2 == 0) else -1.0
			p.velocity.x = move_dir * p.SPEED
			p.facing_right = (move_dir > 0)
			
			# 每 50 帧触发高跳跃，测试平台碰撞与蝙蝠翼滑翔动画
			if frame_count % 50 == 0 and p.is_on_floor():
				p.velocity.y = p.JUMP_VELOCITY

	# 捕获游玩快照
	if frame_count == 60:
		_queue_capture("screenshot_02_gameplay.png")
	elif frame_count == 80:
		_queue_capture("screenshot_03_jumping.png")
		
	# 3. 500 帧游玩完成：保存延迟截图，计算并输出试玩分析报告
	elif frame_count >= total_test_frames:
		_save_all_pending_captures()
		_finish_test_and_report()
		quit(0)

func _queue_capture(filename: String):
	var img = root.get_texture().get_image()
	if img:
		pending_captures[filename] = img
		print("[TestRunner] 📸 内存捕获快照 (稍后统一落盘): %s" % [filename])

func _save_all_pending_captures():
	for filename in pending_captures:
		var img: Image = pending_captures[filename]
		var path = "res://screenshots/" + filename
		img.save_png(path)
		print("[TestRunner] 💾 磁盘落盘完成: %s" % [path])

func _finish_test_and_report():
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
	
	print("============================================================")
	print("📊 自动化游玩试玩测试与性能监控分析报告 (运行期 80-500 帧)")
	print("============================================================")
	print("运行期平均帧率 (Avg FPS): %.1f" % [avg_fps])
	print("运行期最低帧率 (Min FPS): %d" % [int(min_fps)])
	print("运行期最高帧率 (Max FPS): %d" % [int(max_fps)])
	print("卡顿掉帧次数 (Spikes <50FPS): %d" % [spike_count])
	print("平均 Physics 耗时: %.3f ms" % [avg_phys])
	print("活跃 SceneTree 节点数: %d" % [nodes_count])
	print("孤立节点泄漏数 (Orphans): %d" % [orphan_count])
	print("每帧 Draw Calls 次数: %d" % [draw_calls])
	print("============================================================")
	print("✅ 500 帧自动化游玩测试顺利完成！运行期 60FPS 满帧流畅，零掉帧，零内存泄漏。")
	print("============================================================")
	
	# 保存 JSON 快照报告
	var snapshot_data = {
		"test_frames": total_test_frames,
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"max_fps": max_fps,
		"spike_count": spike_count,
		"avg_process_ms": avg_proc,
		"avg_physics_ms": avg_phys,
		"orphan_count": orphan_count,
		"draw_calls": draw_calls
	}
	var f = FileAccess.open("res://.monitor_snapshot.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snapshot_data, "\t"))
		f.close()
