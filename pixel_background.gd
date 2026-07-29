# 像素风背景元素生成器
#
# 用 Image.create() 生成所有场景背景的像素纹理
# 替换原 _create_world() 中的 ColorRect 背景

const PixelLib = preload("res://pixel_lib.gd")

const TILE_SIZE = 8  # 像素块大小（每个"像素"=8×8实际像素）

# ─── 像素月亮 ──────────────────────────────────────

static func create_pixel_moon(size: int = 80) -> Texture2D:
	"""生成 8-bit 风格月亮纹理"""
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var cx = size / 2.0
	var cy = size / 2.0
	var r = size / 2.0 - 2
	
	# 用块状像素风格画月亮
	for y in range(0, size, 4):
		for x in range(0, size, 4):
			var dx = (x + 2) - cx
			var dy = (y + 2) - cy
			if dx * dx + dy * dy <= r * r:
				var brightness = 0.92 + (randf() * 0.08)
				img.set_pixel(x, y, Color(1.0, brightness * 0.95, brightness * 0.7, 0.92))
				if x + 1 < size: img.set_pixel(x+1, y, Color(1.0, brightness * 0.92, brightness * 0.68, 0.9))
				if y + 1 < size: img.set_pixel(x, y+1, Color(1.0, brightness * 0.9, brightness * 0.65, 0.88))
				if x + 1 < size and y + 1 < size:
					img.set_pixel(x+1, y+1, Color(1.0, brightness * 0.88, brightness * 0.62, 0.85))
	
	# 画几个像素陨石坑（暗斑）
	for _i in range(3):
		var cr = 2 + randi() % 4
		var acx = randi() % (size - 10) + 5
		var acy = randi() % (size - 10) + 5
		for py in range(acy - cr, acy + cr + 1):
			for px in range(acx - cr, acx + cr + 1):
				var dx = px - acx
				var dy = py - acy
				if dx * dx + dy * dy <= cr * cr and px >= 0 and px < size and py >= 0 and py < size:
					var pc = img.get_pixel(px, py)
					if pc.a > 0:
						img.set_pixel(px, py, Color(pc.r * 0.75, pc.g * 0.7, pc.b * 0.6, pc.a))
	
	return ImageTexture.create_from_image(img)


# ─── 像素大楼（生成完整大楼纹理）───────────────────

static func _draw_pixel_block(img: Image, bx: int, by: int, bw: int, bh: int, color: Color) -> void:
	"""画一个像素块"""
	PixelLib.fill_rect(img, bx, by, bw, bh, color)


static func create_building_texture(width: int, height: int,
		base_color: Color, window_color: Color, seed_val: int) -> Texture2D:
	"""生成一栋像素大楼纹理
	
	使用 TILE_SIZE 作为像素块单位，产生明显的像素风格
	"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.set_seed(seed_val)
	
	# 墙体 — 用水平条纹制造像素感
	for strip_y in range(0, height, TILE_SIZE * 2):
		var strip_h = min(TILE_SIZE, height - strip_y)
		var lighter = Color(
			min(base_color.r + 0.03, 1.0),
			min(base_color.g + 0.03, 1.0),
			min(base_color.b + 0.03, 1.0),
			base_color.a
		)
		PixelLib.fill_rect(img, 0, strip_y, width, strip_h, lighter)
		if strip_y + TILE_SIZE < height:
			PixelLib.fill_rect(img, 0, strip_y + TILE_SIZE,
				min(TILE_SIZE * 2, height - strip_y - TILE_SIZE),
				width, base_color)
	
	# 哥特风格屋顶装饰 (哥特尖塔 / 木质水塔 / 红光电波塔)
	var rooftop_style = rng.randi() % 4
	if rooftop_style == 1:
		# 哥特尖塔 (Gothic Spire)
		var cx = width / 2
		PixelLib.fill_rect(img, cx - 1, 0, 2, 16, Color(0.7, 0.75, 0.85, 0.9))
		PixelLib.fill_rect(img, cx - 4, 16, 8, 12, base_color)
		PixelLib.fill_rect(img, cx - 8, 28, 16, 8, base_color)
	elif rooftop_style == 2:
		# 哥谭天台木质水塔 (Wooden Water Tower on Stilts)
		var cx = width / 2
		# 金属支撑腿
		PixelLib.fill_rect(img, cx - 14, 16, 3, 20, Color(0.3, 0.35, 0.45, 0.9))
		PixelLib.fill_rect(img, cx + 11, 16, 3, 20, Color(0.3, 0.35, 0.45, 0.9))
		# 木桶主体
		PixelLib.fill_rect(img, cx - 16, 0, 32, 16, Color(0.45, 0.28, 0.18, 0.95))
		# 金属箍环
		PixelLib.fill_rect(img, cx - 16, 4, 32, 2, Color(0.7, 0.75, 0.85, 0.9))
		PixelLib.fill_rect(img, cx - 16, 10, 32, 2, Color(0.7, 0.75, 0.85, 0.9))
	elif rooftop_style == 3:
		# 电波避雷塔带红光 (Radio Tower with Pulsing Red Beacon)
		var cx = width / 2
		PixelLib.fill_rect(img, cx - 1, 4, 2, 24, Color(0.65, 0.7, 0.8, 0.85))
		PixelLib.fill_rect(img, cx - 2, 0, 4, 4, Color(1.0, 0.15, 0.2, 0.95)) # 顶部闪烁红光
	
	# 窗户 — 像素网格排列，随机亮灯
	for wy in range(TILE_SIZE * 4, height - TILE_SIZE, TILE_SIZE * 3):
		for wx in range(TILE_SIZE, width - TILE_SIZE, TILE_SIZE * 3):
			if rng.randi() % 5 != 0:  # 80% 亮灯
				PixelLib.fill_rect(img, wx, wy, 4, 4, window_color)
				# 窗户边框（暗色）
				img.set_pixel(wx - 1, wy - 1, Color(0.05, 0.05, 0.1, 0.5))
				img.set_pixel(wx + 4, wy - 1, Color(0.05, 0.05, 0.1, 0.5))
				img.set_pixel(wx - 1, wy + 4, Color(0.05, 0.05, 0.1, 0.5))
				img.set_pixel(wx + 4, wy + 4, Color(0.05, 0.05, 0.1, 0.5))
	
	return ImageTexture.create_from_image(img)

static func create_clock_tower_texture(width: int, height: int) -> Texture2D:
	"""生成 DC 漫画哥谭标志性大钟楼 (Gotham Clock Tower) 纹理"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var base_col = Color(0.12, 0.15, 0.26, 0.95)
	img.fill(base_col)
	
	# 顶端哥特尖屋顶
	var cx = width / 2
	PixelLib.fill_rect(img, cx - 2, 0, 4, 20, Color(0.7, 0.75, 0.85, 0.9))
	
	# 钟楼大表盘 (Gotham Illuminated Clock Face)
	var clock_r = 24
	var cy = 55
	for y in range(cy - clock_r, cy + clock_r + 1):
		for x in range(cx - clock_r, cx + clock_r + 1):
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy <= clock_r * clock_r:
				img.set_pixel(x, y, Color(1.0, 0.92, 0.5, 0.9)) # 发光淡黄色表盘
				if dx * dx + dy * dy >= (clock_r - 3) * (clock_r - 3):
					img.set_pixel(x, y, Color(0.1, 0.1, 0.15, 0.95)) # 黑色外边框
	
	# 钟表指针 (Clock Hands)
	PixelLib.fill_rect(img, cx, cy - 14, 3, 14, Color(0.1, 0.1, 0.15, 0.95))
	PixelLib.fill_rect(img, cx, cy, 10, 3, Color(0.1, 0.1, 0.15, 0.95))
	
	return ImageTexture.create_from_image(img)


# ─── 像素浮云 ──────────────────────────────────────

static func create_cloud_texture(width: int, height: int) -> Texture2D:
	"""生成半透明像素云朵纹理"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var cx = width / 2.0
	var cy = height / 2.0
	
	# 用多个圆叠成云朵形状
	var blobs = [
		[cx - width * 0.25, cy + 2, width * 0.25],
		[cx + width * 0.25, cy + 2, width * 0.2],
		[cx, cy - 4, width * 0.22],
		[cx - width * 0.12, cy + 5, width * 0.18],
		[cx + width * 0.12, cy + 5, width * 0.16],
	]
	
	for blob in blobs:
		var bcx = blob[0]
		var bcy = blob[1]
		var br = blob[2]
		for y in range(max(0, int(bcy - br)), min(height, int(bcy + br + 1))):
			for x in range(max(0, int(bcx - br)), min(width, int(bcx + br + 1))):
				var dx = x - bcx
				var dy = y - bcy
				if dx * dx + dy * dy <= br * br:
					var existing = img.get_pixel(x, y)
					if existing.a < 0.45:
						img.set_pixel(x, y, Color(0.35, 0.42, 0.55, 0.42))
	
	return ImageTexture.create_from_image(img)


# ─── 像素草地 ──────────────────────────────────────

static func create_grass_texture(width: int, height: int = 8) -> Texture2D:
	"""生成像素草地纹理
	
	用不同深浅的绿色像素块模拟草地
	"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	
	for y in range(height):
		var shade = 0.3 - (y / float(height)) * 0.15  # 从深到浅渐变
		for x in range(0, width, 2):
			var variation = rng.randf() * 0.1
			var g = 0.55 + variation + (1.0 - y / float(height)) * 0.15
			PixelLib.fill_rect(img, x, y, 2, 1,
				Color(0.2 + shade, g, 0.15 + shade * 0.5, 1.0))
	
	return ImageTexture.create_from_image(img)


# ─── 像素管道护栏 ──────────────────────────────────

static func create_pipe_texture() -> Texture2D:
	"""生成像素管道纹理"""
	var img = Image.create(12, 140, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	
	for y in range(140):
		var shade = 0.18 + sin(y * 0.3) * 0.04
		for x in range(12):
			if x == 0 or x == 11:
				img.set_pixel(x, y, Color(shade + 0.05, shade + 0.06, shade + 0.1, 0.9))
			elif x == 1 or x == 10:
				img.set_pixel(x, y, Color(shade + 0.03, shade + 0.04, shade + 0.08, 0.9))
			else:
				img.set_pixel(x, y, Color(shade, shade + 0.02, shade + 0.05, 0.9))
		if y % 18 == 0 and y > 0:
			for x in range(12):
				img.set_pixel(x, y, Color(0.15, 0.12, 0.08, 0.95))  # 管道接口环
	
	return ImageTexture.create_from_image(img)
