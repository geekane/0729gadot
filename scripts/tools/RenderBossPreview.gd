extends SceneTree

# 独立脚本：渲染全新 16-Bit 哥谭夜景像素背景在 PLAYING 局内战场的视觉快照 (隐藏 Menu Overlay)

const Game = preload("res://scripts/Game.gd")

var frame_count = 0
var game_instance: Game = null

func _initialize():
	print("[GameplayBGPreview] 🚀 启动 16-Bit 哥谭夜景局内无 UI 背景渲染快照...")
	
	game_instance = Game.new()
	root.add_child(game_instance)
	
	# 启动并强行移除菜单与 HUD 弹窗以获得极清背景快照
	game_instance._start_game()
	
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	if frame_count == 8:
		# 清理菜单覆盖层
		var menu = game_instance.get_node_or_null("MenuLayer")
		if menu: menu.hide(); menu.queue_free()
		var overlay = game_instance.get_node_or_null("Overlay")
		if overlay: overlay.hide(); overlay.queue_free()
		
	if frame_count == 14:
		var img = root.get_texture().get_image()
		if img:
			var buffer = img.save_png_to_buffer()
			var p1 = "C:/Users/Administrator/.gemini/antigravity-ide/brain/16f04402-6073-4cd7-a54c-1a0431e3897f/media__gotham_gameplay_bg_preview.png"
			var f = FileAccess.open(p1, FileAccess.WRITE)
			if f:
				f.store_buffer(buffer)
				f.close()
				print("[GameplayBGPreview] 💾 局内无 UI 背景快照写入成功: %s (%d bytes)" % [p1, buffer.size()])
		quit()
