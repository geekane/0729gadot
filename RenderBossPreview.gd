extends SceneTree

# 独立脚本：落盘 0.7 倍尺寸 Spider-Joker Boss 与恐怖演出画面到 Artifacts 目录

const Boss = preload("res://Boss.gd")
const Player = preload("res://Player.gd")

var frame_count = 0

func _initialize():
	print("[BossPreview] 🚀 启动 0.7 倍 Boss 与恐怖演出构图渲染预览...")
	
	# 深色哥谭背景
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.position = Vector2(0, 0)
	bg.color = Color(0.08, 0.1, 0.18)
	root.add_child(bg)
	
	# 绘制哥谭地面
	var ground = ColorRect.new()
	ground.size = Vector2(1152, 120)
	ground.position = Vector2(0, 528)
	ground.color = Color(0.18, 0.14, 0.22)
	root.add_child(ground)
	
	# ── 1. 左侧蝙蝠侠 ──
	var player = Player.new()
	player.position = Vector2(250, 495)
	player.facing_right = true
	root.add_child(player)
	
	# ── 2. 右侧 0.7 倍体型尺寸小丑 Boss ──
	var boss = Boss.new()
	boss.position = Vector2(880, 180) # 画面右侧倒挂高处
	boss.current_state = boss.BossState.DORMANT # 展示 0.7 倍沉睡演出状态
	root.add_child(boss)
	
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	if frame_count == 10:
		var img = root.get_texture().get_image()
		if img:
			var buffer = img.save_png_to_buffer()
			var p1 = "C:/Users/Administrator/.gemini/antigravity-ide/brain/16f04402-6073-4cd7-a54c-1a0431e3897f/media__boss_07x_preview.png"
			var f = FileAccess.open(p1, FileAccess.WRITE)
			if f:
				f.store_buffer(buffer)
				f.close()
				print("[BossPreview] 💾 0.7 倍体型尺寸预览写入成功: %s (%d bytes)" % [p1, buffer.size()])
		quit()
