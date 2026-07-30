extends SceneTree

func _initialize():
	print("[MINIMAL] Hello from headless script!")
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	print("[MINIMAL] Image created: " + str(img.get_width()) + "x" + str(img.get_height()))
	var buf = img.save_png_to_buffer()
	print("[MINIMAL] PNG buffer: " + str(buf.size()) + " bytes")
	quit()
