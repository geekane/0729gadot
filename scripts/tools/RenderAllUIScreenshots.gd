extends SceneTree

const Game = preload("res://scripts/Game.gd")

var game_instance = null
var frame_count = 0

const ARTIFACT_DIR = "C:/Users/Administrator/.gemini/antigravity-ide/brain/0005c68b-4f37-4941-b049-8a813d3a8a4c"

func _initialize():
	print("[RenderAllUI] 🚀 启动全场景 UI 自动化截屏与渲染打磨系统...")
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	game_instance = Game.new()
	root.add_child(game_instance)
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	
	# 场景 1: 主菜单 (Frame 10)
	if frame_count == 10:
		print("[RenderAllUI] 📸 截取 1. 主菜单 UI (preview_01_menu.png)...")
		_save_screen("screenshots/preview_01_menu.png", "preview_01_menu.png")
		
	# 场景 2: 3 星通关 (Frame 20 切换 Level，Frame 25 弹出通关)
	elif frame_count == 20:
		print("[RenderAllUI] 🧹 清理主菜单并准备通关场景...")
		game_instance._clear_menu_ui()
		game_instance._start_level(1)
		
	elif frame_count == 25:
		print("[RenderAllUI] 📸 触发 2. 3星完美通关 UI...")
		game_instance.lives = 5.0
		game_instance.score = 60
		game_instance._win_game()
		
	elif frame_count == 45:
		print("[RenderAllUI] 📸 截取 2. 3星完美通关 UI (preview_02_win_3stars.png)...")
		_save_screen("screenshots/preview_02_win_3stars.png", "preview_02_win_3stars.png")
		
	# 场景 3: 1 星勉强通关 (Frame 55)
	elif frame_count == 55:
		print("[RenderAllUI] 📸 触发 3. 1星勉强通关 UI...")
		game_instance.lives = 1.0
		game_instance.score = 5
		game_instance.current_level = 2
		game_instance._win_game()
		
	elif frame_count == 75:
		print("[RenderAllUI] 📸 截取 3. 1星勉强通关 UI (preview_03_win_1star.png)...")
		_save_screen("screenshots/preview_03_win_1star.png", "preview_03_win_1star.png")

	# 场景 4: 战败界面 (Frame 85)
	elif frame_count == 85:
		print("[RenderAllUI] 📸 触发 4. 战败界面 UI...")
		game_instance.lives = 0
		game_instance._game_over()

	elif frame_count == 105:
		print("[RenderAllUI] 📸 截取 4. 战败界面 UI (preview_04_gameover.png)...")
		_save_screen("screenshots/preview_04_gameover.png", "preview_04_gameover.png")

	# 场景 5: 暂停界面 (Frame 115)
	elif frame_count == 115:
		print("[RenderAllUI] 📸 触发 5. 游戏暂停 UI...")
		game_instance._start_level(1)
		game_instance._toggle_pause()

	elif frame_count == 135:
		print("[RenderAllUI] 📸 截取 5. 游戏暂停 UI (preview_05_pause.png)...")
		_save_screen("screenshots/preview_05_pause.png", "preview_05_pause.png")

	elif frame_count == 145:
		print("[RenderAllUI] 🎉 全部场景 UI 截屏捕获完成！自动退出。")
		quit()

func _save_screen(filepath: String, artifact_name: String = ""):
	var img = root.get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(filepath)
		print("[RenderAllUI] SUCCESS: 已保存至: ", filepath)
		
		if artifact_name != "":
			var art_path = ARTIFACT_DIR + "/" + artifact_name
			img.save_png(art_path)
			print("[RenderAllUI] SYNC: 镜像同步至 Artifact: ", art_path)
	else:
		print("[RenderAllUI] WARNING: 视口图像为空")
