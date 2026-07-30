extends SceneTree

func _initialize():
	print("1: preload")
	var BP = preload("res://scripts/enemies/BossPixel.gd")
	print("2: new")
	var bp = BP.new()
	print("3: new done")

	var state = {
		"state": "SKITTER", "t": 0.0, "jaw": 0.0, "dir": -1.0,
		"enraged": false, "stunned": false, "dormant": false,
		"sky_drop_warn": false,
	}

	print("4: render_image")
	var img = bp.render_image(state)
	print("5: render_image returned, img valid=" + str(img != null))

	if img:
		print("6: save")
		var out_dir = "D:/0708ribao/analysis_output/boss_preview"
		DirAccess.make_dir_recursive_absolute(out_dir)
		var buf = img.save_png_to_buffer()
		print("7: buf size=" + str(buf.size()))
		var f = FileAccess.open(out_dir + "/boss_skitter.png", FileAccess.WRITE)
		if f:
			f.store_buffer(buf); f.close()
			print("8: saved OK")
		else:
			print("8: FileAccess FAILED")

	print("9: DONE")
	quit()
