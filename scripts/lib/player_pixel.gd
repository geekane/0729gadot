# 像素化蝙蝠侠渲染器 — 24×36 canvas, 带帧缓存
# 所有坐标使用 Center-Relative: (CX + ox, CY + oy)
# 匹配 Player.gd 碰撞体 24×36

const PixelLib = preload("res://scripts/lib/pixel_lib.gd")
const PW = 24
const PH = 36
const CX = 12.0
const CY = 18.0

var _cache: Dictionary = {}
var _last_key: String = ""
var _last_tex: Texture2D = null

func reset_cache():
	_cache.clear()
	_last_key = ""
	_last_tex = null

func generate(state: Dictionary) -> Texture2D:
	var st = state.get("state", "idle")
	var t_q = int(state.get("t", 0.0) * 6) % 12
	var inv = state.get("invincible", false)
	var key = "%s_T%d%s%s" % [st, t_q, "I" if inv else "", "R" if state.get("rolling", false) else ""]
	if _last_key == key and _last_tex:
		return _last_tex
	if _cache.has(key):
		_last_key = key
		_last_tex = _cache[key]
		return _last_tex

	var tex = _render(state)
	if _cache.size() > 60:
		_cache.clear()
	_cache[key] = tex
	_last_key = key
	_last_tex = tex
	return tex

func _render(state: Dictionary) -> Texture2D:
	var img = Image.create(PW, PH, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var t = state.get("t", 0.0)
	var dir = state.get("dir", 1.0)
	var st = state.get("state", "idle")
	var rolling = state.get("rolling", false)
	var invincible = state.get("invincible", false)

	if rolling:
		_draw_roll(img, t, dir)
	else:
		_draw_cape(img, t, st, dir)
		_draw_legs(img, t, st, dir)
		_draw_torso(img, t, st, dir)
		_draw_head(img, t, dir)

	var tex = ImageTexture.create_from_image(img)
	if invincible:
		var alpha = 0.5 if int(t * 10) % 2 == 0 else 1.0
		tex = _apply_alpha_modulate(tex, alpha)
	return tex

func _apply_alpha_modulate(tex: Texture2D, alpha: float) -> Texture2D:
	var img = tex.get_image()
	if not img: return tex
	var w = img.get_width()
	var h = img.get_height()
	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			if c.a > 0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * alpha))
	return ImageTexture.create_from_image(img)

# ─── 颜色 ──────────────────────────────────────────
var C_CAPE = Color(0.06, 0.06, 0.10)
var C_SUIT = Color(0.16, 0.18, 0.24)
var C_SUIT_DARK = Color(0.12, 0.14, 0.20)
var C_BELT = Color(1.0, 0.80, 0.10)
var C_BELT_BUCKLE = Color(0.9, 0.70, 0.0)
var C_EYE = Color(1.0, 1.0, 0.95)
var C_EYE_HURT = Color(1.0, 0.3, 0.3)
var C_SKIN = Color(0.95, 0.78, 0.65)
var C_BOOT = Color(0.08, 0.08, 0.12)
var C_BAT_SYMBOL = Color(0.10, 0.10, 0.14)
var C_BAT_BG = Color(1.0, 0.85, 0.10)
var C_GAUNTLET = Color(0.10, 0.10, 0.14)
var C_GLOVE = Color(0.16, 0.18, 0.24)

# ─── 原语 ──────────────────────────────────────────
func _sp(img: Image, x: int, y: int, c: Color):
	if x >= 0 and x < PW and y >= 0 and y < PH:
		img.set_pixel(x, y, c)

func _fc(img: Image, ox: float, oy: float, r: float, c: Color):
	PixelLib.fill_circle(img, CX + ox, CY + oy, r, c)

func _fr(img: Image, ox: int, oy: int, w: int, h: int, c: Color):
	var rx = int(CX) + ox
	var ry = int(CY) + oy
	PixelLib.fill_rect(img, rx, ry, w, h, c)

func _ln(img: Image, x1: float, y1: float, x2: float, y2: float, c: Color, th: int = 1):
	var dx = x2 - x1
	var dy = y2 - y1
	var stp = max(abs(dx), abs(dy), 1.0)
	for i in range(int(stp) + 1):
		var p = i / stp
		var ix = int(CX + x1 + dx * p)
		var iy = int(CY + y1 + dy * p)
		if ix < 0 or ix >= PW or iy < 0 or iy >= PH: continue
		img.set_pixel(ix, iy, c)
		if th > 1:
			for ox in range(-th + 1, th):
				for oy in range(-th + 1, th):
					_sp(img, ix + ox, iy + oy, c)

func _scan_tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color):
	var pts = [a, b, c]
	var my0 = max(0, int(CY + min(a.y, b.y, c.y)))
	var my1 = min(PH - 1, int(CY + max(a.y, b.y, c.y)))
	for y in range(my0, my1 + 1):
		var ly = y - CY
		var xs: Array[float] = []
		for i in range(3):
			var p1 = pts[i]
			var p2 = pts[(i + 1) % 3]
			if p1.y == p2.y: continue
			if (ly < p1.y and ly < p2.y) or (ly > p1.y and ly > p2.y): continue
			xs.append(CX + p1.x + (ly - p1.y) * (p2.x - p1.x) / (p2.y - p1.y))
		if xs.size() >= 2:
			xs.sort()
			for x in range(max(0, int(xs[0])), min(PW, int(xs[xs.size() - 1]) + 1)):
				img.set_pixel(x, y, col)

# ─── 绘制部件 ──────────────────────────────────────

func _draw_cape(img: Image, t: float, state: String, dir: float):
	"""蝙蝠斗篷 — 根据状态动态形状"""
	var is_air = state in ["jump_up", "jump_fall"]
	var is_run = state == "run"
	var cw = abs(sin(t * 3.0)) * 3.0 if is_air else 0.0  # 空中斗篷展开
	var wave = sin(t * 12.0) * 3.0 if is_run else sin(t * 2.5) * 1.5

	if is_air:
		# 空中滑翔翼式张开
		_scan_tri(img, Vector2(-2*dir, -6), Vector2(-14*dir - cw, -4), Vector2(-12*dir, 18), C_CAPE)
		_scan_tri(img, Vector2(-2*dir, -6), Vector2(-12*dir, 18), Vector2(-3*dir, 8), C_CAPE)
	else:
		# 地面：斗篷顺垂或迎风摆动
		_scan_tri(img, Vector2(-2*dir, -6), Vector2(-10*dir - wave, 2), Vector2(-12*dir - wave, 18), C_CAPE)
		_scan_tri(img, Vector2(-2*dir, -6), Vector2(-12*dir - wave, 18), Vector2(-3*dir, 8), C_CAPE)

func _draw_legs(img: Image, t: float, state: String, dir: float):
	"""腿部 & 战靴"""
	var is_move = state == "run"
	var swing = sin(t * 16.0) * 3.0 if is_move else 0.0
	var leg_y = 6  # leg_y = 7 vs CY+7 = pixel row 25

	var lx = int(CX - 6 + swing)
	var rx = int(CX + 1 - swing)
	var ly = int(CY + leg_y)

	# 左腿
	for y in range(ly, ly + 6):
		for x in range(lx, lx + 4):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, Color(0.15, 0.16, 0.22))
	# 右腿
	for y in range(ly, ly + 6):
		for x in range(rx, rx + 4):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, Color(0.15, 0.16, 0.22))

	# 战靴 (鞋底)
	var sho = int(1 * dir)
	for y in range(ly + 5, ly + 8):
		for x in range(lx - 1 + sho, lx + 4 + sho):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_BOOT)
	for y in range(ly + 5, ly + 8):
		for x in range(rx - 1 + sho, rx + 4 + sho):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_BOOT)

func _draw_torso(img: Image, t: float, state: String, dir: float):
	"""躯干战衣 + 蝙蝠胸章 + 腰带"""
	var is_air = state in ["jump_up", "jump_fall"]
	var breath = sin(t * 3.5) * 0.5 if state == "idle" else 0.0

	# 躯干主体
	var ty = int(CY - 7 + breath)
	for y in range(ty, ty + 11):
		for x in range(int(CX - 7), int(CX + 7)):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_SUIT)
	for y in range(ty + 1, ty + 9):
		for x in range(int(CX - 5), int(CX + 5)):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_SUIT_DARK)

	# 蝙蝠胸章 (黄底 + 黑蝙蝠)
	var sym_y = int(CY - 3 + breath)
	_fc(img, 0, 5.0, 3.5, C_BAT_BG)

	# 黑蝙蝠图标 (简化为三角形组合)
	var bt_x = int(CX)
	var bt_y = int(CY + 5 + breath)
	_scan_tri(img, Vector2(-3, 4.5), Vector2(-1, 3.5), Vector2(0, 5.5), C_BAT_SYMBOL)
	_scan_tri(img, Vector2(3, 4.5), Vector2(1, 3.5), Vector2(0, 5.5), C_BAT_SYMBOL)
	_scan_tri(img, Vector2(-2, 4.0), Vector2(2, 4.0), Vector2(0, 7.0), C_BAT_SYMBOL)

	# 腰带
	var by = int(CY + 8 + breath)
	for y in range(by, by + 2):
		for x in range(int(CX - 7), int(CX + 7)):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_BELT)
	# 腰带扣
	for y in range(by - 1, by + 3):
		for x in range(int(CX - 1), int(CX + 1)):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_BELT_BUCKLE)

	# 手臂
	var arm_sw = -sin(t * 16.0) * 2.0 if state == "run" else 0.0
	var arm_y = int(CY - 5 + breath + arm_sw)
	# 左臂
	for y in range(arm_y, arm_y + 8):
		for x in range(int(CX - 11), int(CX - 7)):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_GLOVE)
	# 右臂
	for y in range(arm_y, arm_y + 8):
		for x in range(int(CX + 7), int(CX + 11)):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_GLOVE)

func _draw_head(img: Image, t: float, dir: float):
	"""蝙蝠头盔 + 耳 + 眼 + 下巴"""
	var hd_y = int(CY - 15)

	# 头部圆形
	_fc(img, 0, -15, 6, Color(0.10, 0.10, 0.14))

	# 左耳尖
	var ear_l = Vector2(-6, -17)
	var ear_lt = Vector2(-4, -17)
	var ear_lb = Vector2(-5, -25)
	_scan_tri(img, ear_l, ear_lt, ear_lb, Color(0.10, 0.10, 0.14))

	# 右耳尖
	var ear_r = Vector2(6, -17)
	var ear_rt = Vector2(4, -17)
	var ear_rb = Vector2(5, -25)
	_scan_tri(img, ear_r, ear_rt, ear_rb, Color(0.10, 0.10, 0.14))

	# 脸/下巴 (肤色)
	for y in range(int(CY - 12), int(CY - 8)):
		for x in range(int(CX - 3), int(CX + 3)):
			if x >= 0 and x < PW and y >= 0 and y < PH:
				img.set_pixel(x, y, C_SKIN)

	# 嘴线
	for x in range(int(CX - 2), int(CX + 2)):
		var y = int(CY - 9)
		if x >= 0 and x < PW and y >= 0 and y < PH:
			img.set_pixel(x, y, Color(0.4, 0.2, 0.1))

	# 发光白眼
	var eye_off = int(1 * dir)
	_fc(img, -4 + eye_off, -17, 1.8, C_EYE)
	_fc(img, 4 + eye_off, -17, 1.8, C_EYE)

func _draw_roll(img: Image, t: float, dir: float):
	"""翻滚时的风格化像素圆环+光效"""
	# 暗色圆
	for y in range(max(0, int(CY - 10)), min(PH, int(CY + 10))):
		for x in range(max(0, int(CX - 10)), min(PW, int(CX + 10))):
			var dx = x - CX; var dy = y - CY
			if dx*dx + dy*dy <= 100:
				img.set_pixel(x, y, Color(0.06, 0.06, 0.12))
			elif dx*dx + dy*dy <= 140:
				img.set_pixel(x, y, Color(0.12, 0.16, 0.28))

	# 蓝光能量弧
	var prog = t * 2.0
	for i in range(8):
		var ang = prog + i * 0.785
		var sx = cos(ang) * 11; var sy = sin(ang) * 9
		_fc(img, sx, sy, 1.5, Color(0.3, 0.95, 1.0, 0.7))
