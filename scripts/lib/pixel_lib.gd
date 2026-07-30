# 纯代码像素图生成工具库
#
# 用法：
#   const PALETTE = { "R": Color(1,0,0), ".": Color.TRANSPARENT }
#   var tex = PixelLib.create_texture(16, 16, frame_data, PALETTE)
#   sprite.texture = tex

static func create_texture(width: int, height: int,
		pixels: Array, palette: Dictionary) -> Texture2D:
	"""从字符串数组生成像素纹理
	
	参数:
		width, height: 像素图尺寸
		pixels: 每行一个字符串的数组, '.'=透明, 其他字符=调色板key
		palette: 字符→Color 映射字典
	返回:
		NEAREST 滤波的 ImageTexture
	"""
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	assert(pixels.size() == height,
			"像素行数 %d 必须等于高度 %d" % [pixels.size(), height])
	for y in range(height):
		var row = pixels[y]
		for x in range(min(row.length(), width)):
			var ch = row[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)


static func create_anim_textures(frames_data: Array[Array],
		palette: Dictionary, frame_w: int, frame_h: int) -> Array[Texture2D]:
	"""批量生成动画多帧纹理"""
	var textures: Array[Texture2D] = []
	for data in frames_data:
		textures.append(create_texture(frame_w, frame_h, data, palette))
	return textures


static func setup_animated_sprite(anim_sprite: AnimatedSprite2D,
		animations: Dictionary, palette: Dictionary) -> void:
	"""根据动画配置自动填充 AnimatedSprite2D
	
	animations 格式:
	{
		"idle": {
			"frames": [[字符串数组], ...],   # 每帧的像素数据
			"speed": 5.0,
			"loop": true,
			"frame_w": 12,
			"frame_h": 18
		},
		"run": { ... }
	}
	"""
	var sf = SpriteFrames.new()
	for anim_name in animations:
		var cfg = animations[anim_name]
		var fw = cfg.get("frame_w", 12)
		var fh = cfg.get("frame_h", 18)
		var speed = cfg.get("speed", 5.0)
		var loop = cfg.get("loop", true)
		var frame_data = cfg["frames"]
		
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, speed)
		sf.set_animation_loop(anim_name, loop)
		
		for data in frame_data:
			var tex = create_texture(fw, fh, data, palette)
			sf.add_frame(anim_name, tex)
	
	anim_sprite.sprite_frames = sf


# ─── 像素基础形状库 ──────────────────────────────────

static func fill_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	"""在 Image 上画实心圆"""
	var w = img.get_width()
	var h = img.get_height()
	for y in range(max(0, int(cy - r)), min(h, int(cy + r + 1))):
		for x in range(max(0, int(cx - r)), min(w, int(cx + r + 1))):
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, color)


static func fill_rect(img: Image, rx: int, ry: int, rw: int, rh: int, color: Color) -> void:
	"""在 Image 上画实心矩形（使用优化的 blit_rect 替代逐像素 set_pixel）"""
	var img_w = img.get_width()
	var img_h = img.get_height()
	# 裁剪到图像边界
	var dx = rx
	var dy = ry
	var sx = 0
	var sy = 0
	var cw = rw
	var ch = rh
	if dx < 0: sx -= dx; cw += dx; dx = 0
	if dy < 0: sy -= dy; ch += dy; dy = 0
	if dx + cw > img_w: cw = img_w - dx
	if dy + ch > img_h: ch = img_h - dy
	if cw <= 0 or ch <= 0: return
	# 单色填充通过临时 Image + blit_rect 实现 (C++ 级)
	var fill = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	fill.fill(color)
	img.blit_rect(fill, Rect2i(sx, sy, cw, ch), Vector2i(dx, dy))
