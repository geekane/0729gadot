extends SceneTree

const Game = preload("res://scripts/Game.gd")

var game_instance = null
var frame_count = 0

const ARTIFACT_DIR = "C:/Users/Administrator/.gemini/antigravity-ide/brain/0005c68b-4f37-4941-b049-8a813d3a8a4c"

func _initialize():
	print("[HitTextPreview] 🎯 启动屏幕中央'命中/暴击'艺术字弹跳测试...")
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	game_instance = Game.new()
	root.add_child(game_instance)
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	
	if frame_count == 3:
		game_instance._start_level(1)
		
	elif frame_count == 10:
		print("[HitTextPreview] 💥 触发屏幕中央 '🎯 命中！' 艺术字...")
		game_instance._spawn_center_hit_text("HIT")
		
	elif frame_count == 14:
		print("[HitTextPreview] 📸 截取屏幕中央命中画面 (preview_06_center_hit.png)...")
		_save_screen("screenshots/preview_06_center_hit.png", "preview_06_center_hit.png")
		
	elif frame_count == 20:
		print("[HitTextPreview] 💥 触发屏幕中央 '💥 暴击！' 艺术字...")
		game_instance._spawn_center_hit_text("CRIT")
		
	elif frame_count == 24:
		print("[HitTextPreview] 📸 截取屏幕中央暴击画面 (preview_07_center_crit.png)...")
		_save_screen("screenshots/preview_07_center_crit.png", "preview_07_center_crit.png")
		
	elif frame_count == 30:
		print("[HitTextPreview] 🎉 打击提示文字自动化截屏完成！退出。")
		quit()

func _save_screen(filepath: String, artifact_name: String = ""):
	var img = root.get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(filepath)
		print("[HitTextPreview] SUCCESS: 已保存至: ", filepath)
		
		if artifact_name != "":
			var art_path = ARTIFACT_DIR + "/" + artifact_name
			img.save_png(art_path)
			print("[HitTextPreview] SYNC: 镜像同步至 Artifact: ", art_path)
	else:
		print("[HitTextPreview] WARNING: 视口图像为空")
