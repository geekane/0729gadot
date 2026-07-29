extends SceneTree

const Game = preload("res://Game.gd")

var game_instance = null
var frame_count = 0

func _initialize():
	print("[TestRunner] 捕获蝙蝠侠与哥谭夜景画面...")
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
		
	game_instance = Game.new()
	root.add_child(game_instance)
	
	process_frame.connect(_on_process_frame)

func _on_process_frame():
	frame_count += 1
	
	if frame_count == 5:
		_capture("screenshot_01_menu.png")
		game_instance._start_game()
		
	elif frame_count > 5 and frame_count < 60:
		if game_instance.player_node and is_instance_valid(game_instance.player_node):
			game_instance.player_node.velocity.x = 300.0
			game_instance.player_node.facing_right = true

	elif frame_count == 60:
		_capture("screenshot_02_gameplay.png")
		if game_instance.player_node and is_instance_valid(game_instance.player_node):
			game_instance.player_node.velocity.y = -530.0
			
	elif frame_count == 80:
		_capture("screenshot_03_jumping.png")
		
	elif frame_count == 100:
		print("[TestRunner] ✅ 画面截取全部完成！")
		quit(0)

func _capture(filename: String):
	var img = root.get_texture().get_image()
	if img:
		var path = "res://screenshots/" + filename
		img.save_png(path)
		print("[TestRunner] 已截取画面: %s" % [path])
