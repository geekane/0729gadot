extends SceneTree

const Game = preload("res://scripts/Game.gd")

var game_instance = null
var frame_count = 0

const ARTIFACT_DIR = "C:/Users/Administrator/.gemini/antigravity-ide/brain/0005c68b-4f37-4941-b049-8a813d3a8a4c"

func _initialize():
	print("[OverlayPreview] 启动通关/战败界面 UI 自动化精准渲染与截屏...")
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	game_instance = Game.new()
	root.add_child(game_instance)
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	
	if frame_count == 3:
		print("[OverlayPreview] 模拟开始游戏 (Level 1)...")
		game_instance._start_game()
		
	elif frame_count == 10:
		print("[OverlayPreview] 触发 Level 1 通关 (2星/3星 模拟)...")
		game_instance.lives = 4.0
		game_instance.score = 35
		game_instance._win_game()
		
	elif frame_count == 30:
		# 等待 20 帧让 Panel 和星级 Tween 动画播放完毕
		print("[OverlayPreview] 截取通关界面 (screenshot_overlay_win.png)...")
		_save_screen("screenshots/screenshot_overlay_win.png", "overlay_win_preview.png")
		
	elif frame_count == 35:
		print("[OverlayPreview] 触发 游戏结束 (战败界面 模拟)...")
		game_instance.lives = 0
		game_instance._game_over()
		
	elif frame_count == 55:
		# 等待 20 帧让 Panel 动画完成
		print("[OverlayPreview] 截取战败界面 (screenshot_overlay_gameover.png)...")
		_save_screen("screenshots/screenshot_overlay_gameover.png", "overlay_gameover_preview.png")
		
	elif frame_count == 60:
		print("[OverlayPreview] 自动化 UI 截屏测试完成！")
		quit()

func _save_screen(filepath: String, artifact_name: String = ""):
	var img = root.get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(filepath)
		print("[OverlayPreview] 截屏已成功保存至: ", filepath)
		
		if artifact_name != "":
			var art_path = ARTIFACT_DIR + "/" + artifact_name
			img.save_png(art_path)
			print("[OverlayPreview] 镜像同步至 Artifact: ", art_path)
	else:
		print("[OverlayPreview] Warning: 视口图像为空，可能处于虚拟渲染状态")
