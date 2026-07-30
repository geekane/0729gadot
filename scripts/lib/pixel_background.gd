extends Node

# 哥谭暗夜守护者 16-Bit 漫画风格背景绘制库 (Gotham Night Pixel Background Generator)
# 根据用户提供的 16-Bit 像素艺术原图近乎完美地重构

static func create_grass_texture(width: int, height: int = 8) -> ImageTexture:
	"""生成地表草皮顶边像素纹理"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var c_top = Color(0.22, 0.78, 0.48)
	var c_bot = Color(0.12, 0.45, 0.28)
	for y in range(height):
		var t = float(y) / float(height)
		var c = c_top.lerp(c_bot, t)
		for x in range(width):
			if (x * 7 + y * 13) % 5 == 0:
				img.set_pixel(x, y, Color(0.35, 0.90, 0.55))
			else:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

static func create_gotham_sky_texture(width: int = 800, height: int = 450) -> ImageTexture:
	"""生成 Layer 0 夜空背景：暮紫渐变夜空 + 璀璨十字星空 + 硕大金黄明月 + 蝙蝠探照灯斜向光束 + 蝙蝠徽标剪影 + 夜云"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	# 1. 暮紫夜空渐变 (Sky Gradient)
	var sky_top = Color(0.08, 0.06, 0.14)   # #140f24
	var sky_bot = Color(0.18, 0.13, 0.25)   # #2e2140
	for y in range(height):
		var t = float(y) / float(height)
		var c = sky_top.lerp(sky_bot, t)
		for x in range(width):
			img.set_pixel(x, y, c)
			
	# 2. 十字星空与闪耀星光 (Cross Stars)
	var rng = RandomNumberGenerator.new()
	rng.seed = 10086
	for i in range(45):
		var sx = rng.randi_range(10, width - 10)
		var sy = rng.randi_range(5, int(height * 0.55))
		var star_color = Color(1.0, 0.92, 0.65) if rng.randf() > 0.3 else Color(1.0, 1.0, 1.0)
		img.set_pixel(sx, sy, star_color)
		# 十字延伸
		if rng.randf() > 0.5:
			if sx > 0: img.set_pixel(sx - 1, sy, Color(star_color.r, star_color.g, star_color.b, 0.6))
			if sx < width - 1: img.set_pixel(sx + 1, sy, Color(star_color.r, star_color.g, star_color.b, 0.6))
			if sy > 0: img.set_pixel(sx, sy - 1, Color(star_color.r, star_color.g, star_color.b, 0.6))
			if sy < height - 1: img.set_pixel(sx, sy + 1, Color(star_color.r, star_color.g, star_color.b, 0.6))

	# 3. 硕大金黄明月 (Golden Full Moon - Vector2(230, 120), Radius 52px)
	var moon_cx = 230
	var moon_cy = 120
	var moon_r = 52.0
	
	# 月晕外辉
	for y in range(moon_cy - int(moon_r) - 15, moon_cy + int(moon_r) + 15):
		for x in range(moon_cx - int(moon_r) - 15, moon_cx + int(moon_r) + 15):
			if x >= 0 and x < width and y >= 0 and y < height:
				var dist = Vector2(x, y).distance_to(Vector2(moon_cx, moon_cy))
				if dist <= moon_r + 14.0:
					if dist > moon_r:
						var halo_a = (1.0 - (dist - moon_r) / 14.0) * 0.35
						var old_c = img.get_pixel(x, y)
						var halo_c = Color(1.0, 0.95, 0.75, halo_a)
						img.set_pixel(x, y, old_c.blend(halo_c))
					else:
						# 月面基底 (Golden Moon Surface)
						var nx = (float(x - moon_cx) / moon_r)
						var ny = (float(y - moon_cy) / moon_r)
						var surface_t = sqrt(max(0.0, 1.0 - nx*nx - ny*ny))
						
						# 月海坑纹 (Moon Craters)
						var is_crater = false
						var c1 = Vector2(x, y).distance_to(Vector2(moon_cx - 14, moon_cy + 10)) < 16.0
						var c2 = Vector2(x, y).distance_to(Vector2(moon_cx + 18, moon_cy - 12)) < 12.0
						var c3 = Vector2(x, y).distance_to(Vector2(moon_cx + 8, moon_cy + 22)) < 14.0
						if c1 or c2 or c3:
							is_crater = true
							
						var m_color = Color(1.0, 0.90, 0.55) # 亮黄基调 #ffe58f
						if surface_t > 0.6:
							m_color = Color(1.0, 0.96, 0.70) # 核心高光 #fff3b0
						if is_crater:
							m_color = Color(0.86, 0.68, 0.30) # 暗金月海 #d49b38
							
						img.set_pixel(x, y, m_color)

	# 4. 蝙蝠探照灯斜向光束 (Bat Signal Beam: 右下 (720, 420) -> 左上 (240, 20))
	# 绘制光束梯形多边形
	var p_origin = Vector2(680, 400)
	var p_target = Vector2(360, 40)
	var beam_dir = (p_target - p_origin).normalized()
	var perp_dir = Vector2(-beam_dir.y, beam_dir.x)
	
	for y in range(height):
		for x in range(width):
			var pt = Vector2(x, y)
			var vec = pt - p_origin
			var proj_along = vec.dot(beam_dir)
			if proj_along > 0 and proj_along < 650.0:
				var proj_perp = abs(vec.dot(perp_dir))
				var width_at_dist = 12.0 + (proj_along / 650.0) * 110.0
				if proj_perp <= width_at_dist:
					var edge_fade = 1.0 - (proj_perp / width_at_dist)
					edge_fade = pow(edge_fade, 1.2)
					var alpha = edge_fade * 0.48 * (1.0 - (proj_along / 650.0) * 0.3)
					var beam_c = Color(1.0, 0.95, 0.72, alpha) # 奶油金光束
					var old_c = img.get_pixel(x, y)
					img.set_pixel(x, y, old_c.blend(beam_c))

	# 5. 探照灯光束内的经典蝙蝠徽标剪影 (Bat Signal Logo in Beam)
	var bat_cx = 450
	var bat_cy = 135
	var bat_color = Color(0.10, 0.08, 0.16, 0.92) # 黑色蝙蝠剪影
	
	# 像素化蝙蝠图案 (Bat Logo Matrix 24x14)
	var bat_matrix = [
		".....#..........#.....",
		"....###........###....",
		"...#####......#####...",
		"..#################..",
		".###################.",
		"#####################",
		"#####################",
		"#####################",
		".###################.",
		"..#################..",
		"......#########......",
		"........#####........"
	]
	var bm_h = bat_matrix.size()
	var bm_w = 22
	for by in range(bm_h):
		var row_str = bat_matrix[by]
		for bx in range(row_str.length()):
			if row_str.substr(bx, 1) == "#":
				var px = bat_cx - bm_w + bx * 2
				var py = bat_cy - bm_h + by * 2
				for dx in range(2):
					for dy in range(2):
						if px + dx >= 0 and px + dx < width and py + dy >= 0 and py + dy < height:
							var old_c = img.get_pixel(px + dx, py + dy)
							img.set_pixel(px + dx, py + dy, old_c.blend(bat_color))

	# 6. 夜间波浪云彩 (Volumetric Night Clouds)
	var cloud_color1 = Color(0.26, 0.32, 0.38, 0.55) # #425260
	var cloud_color2 = Color(0.18, 0.23, 0.28, 0.65) # #2e3b47
	for y in range(40, 180):
		for x in range(width):
			var wave = sin(float(x) * 0.02) * 15.0 + cos(float(x) * 0.04) * 8.0
			var cy = float(y) - wave
			if cy > 70 and cy < 130:
				var c_alpha = (1.0 - abs(cy - 100.0) / 30.0) * 0.45
				var c_col = cloud_color1 if cy < 100 else cloud_color2
				c_col.a = c_alpha
				var old_c = img.get_pixel(x, y)
				img.set_pixel(x, y, old_c.blend(c_col))

	return ImageTexture.create_from_image(img)

static func create_gotham_far_buildings_texture(width: int = 800, height: int = 400) -> ImageTexture:
	"""生成 Layer 1 远景楼群：暗紫暗青色摩天大楼天际线剪影与远端微弱灯火"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 20086
	
	var b_color = Color(0.11, 0.09, 0.17, 0.95)   # #1c172b
	var b_edge = Color(0.18, 0.14, 0.26, 0.95)    # #2e2442
	var win_color = Color(0.9, 0.5, 0.15, 0.7)    # 远端暗橙色像素窗
	
	var cur_x = 0
	while cur_x < width:
		var bw = rng.randi_range(40, 80)
		var bh = rng.randi_range(160, 280)
		var bx = cur_x
		var by = height - bh
		
		# 楼体
		for y in range(by, height):
			for x in range(bx, min(bx + bw, width)):
				if x == bx or x == bx + bw - 1 or y == by:
					img.set_pixel(x, y, b_edge)
				else:
					img.set_pixel(x, y, b_color)
					
		# 避雷针与尖顶
		if rng.randf() > 0.4:
			var spire_x = bx + int(bw / 2)
			for sy in range(max(0, by - 30), by):
				if spire_x >= 0 and spire_x < width:
					img.set_pixel(spire_x, sy, b_edge)
					
		# 远端点点灯光
		for wy in range(by + 20, height - 20, 14):
			for wx in range(bx + 8, bx + bw - 8, 10):
				if rng.randf() > 0.55 and wx >= 0 and wx + 2 < width and wy + 2 < height:
					for dx in range(2):
						for dy in range(2):
							img.set_pixel(wx + dx, wy + dy, win_color)
							
		cur_x += bw - 6
		
	return ImageTexture.create_from_image(img)

static func create_gotham_mid_buildings_texture(width: int = 800, height: int = 450) -> ImageTexture:
	"""生成 Layer 2 中景哥特摩天大楼群：帝国大厦/克莱斯勒尖顶主塔楼 + 密集的暖黄/金橙亮灯窗口格点"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var b_main = Color(0.09, 0.07, 0.14)   # #171224
	var b_side = Color(0.14, 0.11, 0.20)   # #241c33
	var b_highlight = Color(0.25, 0.20, 0.34) # #403357 边缘高光
	
	var win_amber = Color(1.0, 0.65, 0.20)  # #ffaa33 暖金
	var win_orange = Color(1.0, 0.45, 0.10) # #ff731a 亮橙
	var win_bright = Color(1.0, 0.90, 0.50) # #ffe680 高亮白黄
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 30086
	
	# 绘制 1 栋震撼的哥特克莱斯勒主塔楼 (Central Gotham Gothic Spire)
	var main_cx = 240
	var main_by = 50 # 顶端从 y=50 开始
	
	# 1a. 顶端哥特多级阶梯与避雷针
	for sy in range(10, 50):
		img.set_pixel(main_cx, sy, b_highlight)
		img.set_pixel(main_cx - 1, sy, b_main)
		img.set_pixel(main_cx + 1, sy, b_main)
		
	# 1b. 阶梯金字塔结构
	var steps_data = [
		[main_cx - 12, main_cx + 12, 50, 80],
		[main_cx - 24, main_cx + 24, 80, 120],
		[main_cx - 40, main_cx + 40, 120, 200],
		[main_cx - 65, main_cx + 65, 200, 450]
	]
	for step in steps_data:
		var x1 = step[0]
		var x2 = step[1]
		var y1 = step[2]
		var y2 = step[3]
		for y in range(y1, y2):
			for x in range(x1, x2):
				if x >= 0 and x < width and y >= 0 and y < height:
					if x == x1 or x == x2 - 1 or y == y1:
						img.set_pixel(x, y, b_highlight)
					else:
						img.set_pixel(x, y, b_main if x < main_cx else b_side)
						
	# 1c. 主塔楼上的密集暖橙窗格网格 (Glow Windows Grid)
	for wy in range(90, 430, 12):
		for wx in range(main_cx - 55, main_cx + 55, 9):
			if abs(wx - main_cx) > 6 and rng.randf() > 0.22:
				var w_col = win_amber if rng.randf() > 0.3 else (win_orange if rng.randf() > 0.5 else win_bright)
				for dx in range(5):
					for dy in range(6):
						var px = wx + dx
						var py = wy + dy
						if px >= 0 and px < width and py >= 0 and py < height:
							img.set_pixel(px, py, w_col)

	# 2. 绘制两侧连绵的摩天楼群与丰富窗格 (Flanking Skyscrapers)
	var cur_x = 0
	while cur_x < width:
		if abs(cur_x - main_cx) < 70:
			cur_x += 130
			continue
			
		var bw = rng.randi_range(65, 110)
		var bh = rng.randi_range(200, 340)
		var bx = cur_x
		var by = height - bh
		
		# 楼体
		for y in range(by, height):
			for x in range(bx, min(bx + bw, width)):
				if x == bx or y == by:
					img.set_pixel(x, y, b_highlight)
				else:
					img.set_pixel(x, y, b_main if (x - bx) < bw/2 else b_side)
					
		# 窗格
		for wy in range(by + 16, height - 20, 14):
			for wx in range(bx + 8, bx + bw - 8, 11):
				if rng.randf() > 0.35 and wx + 5 < width and wy + 6 < height:
					var w_col = win_amber if rng.randf() > 0.3 else win_orange
					for dx in range(6):
						for dy in range(6):
							img.set_pixel(wx + dx, wy + dy, w_col)
							
		cur_x += bw - 8

	return ImageTexture.create_from_image(img)

static func create_gotham_foreground_rail_texture(width: int = 800, height: int = 160) -> ImageTexture:
	"""生成 Layer 3 近景天台铁艺护栏与天台管道 (Rooftop Balcony Lattice Railing & Industrial Pipes)"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var rail_dark = Color(0.06, 0.05, 0.09)    # #100d17 铁艺纯黑
	var rail_metal = Color(0.14, 0.12, 0.20)   # #241f33 铁质边缘
	var pipe_color = Color(0.08, 0.07, 0.12)
	
	var rail_top_y = 60
	var rail_bot_y = 120
	
	# 1. 天台顶层横向粗扶手与底座
	for x in range(width):
		for dy in range(6):
			img.set_pixel(x, rail_top_y + dy, rail_metal if dy == 0 else rail_dark)
			img.set_pixel(x, rail_bot_y + dy, rail_metal if dy == 0 else rail_dark)
			
	# 2. 菱形网格交叉铁条 (X-Pattern Cross Bars)
	for x in range(0, width, 24):
		# 垂直粗立柱
		for y in range(rail_top_y, rail_bot_y + 20):
			for dx in range(4):
				if x + dx < width:
					img.set_pixel(x + dx, y, rail_metal if dx == 0 else rail_dark)
					
		# 斜向 X 交叉网格
		for y in range(rail_top_y + 6, rail_bot_y):
			var t = float(y - (rail_top_y + 6)) / float(rail_bot_y - rail_top_y - 6)
			var offset1 = int(t * 24.0)
			var offset2 = int((1.0 - t) * 24.0)
			
			if x + offset1 < width:
				img.set_pixel(x + offset1, y, rail_metal)
			if x + offset2 < width:
				img.set_pixel(x + offset2, y, rail_metal)

	# 3. 右侧天台工业弯头管道 (Rooftop Pipes)
	var pipe_x = width - 120
	for y in range(80, height):
		for dx in range(18):
			if pipe_x + dx < width:
				img.set_pixel(pipe_x + dx, y, rail_metal if dx == 0 or dx == 17 else pipe_color)

	return ImageTexture.create_from_image(img)
