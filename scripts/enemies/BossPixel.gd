# 像素化 Boss 渲染器 — 80×60 canvas, 帧缓存
# 骷髅×小丑融合头 + 低饱和度暗黑色调

const PixelLib = preload("res://scripts/lib/pixel_lib.gd")
const PW = 80
const PH = 60
const CX = 40.0
const CY = 30.0

# ═══════════════════════════════════════════════════
# 调色板 (低饱和度暗黑版)
# ═══════════════════════════════════════════════════
const C_CEPH   = Color(0.18,0.10,0.24)
const C_CEPH_E = Color(0.45,0.08,0.14)
const C_ABDO   = Color(0.20,0.08,0.26)
const C_ABDO_E = Color(0.46,0.06,0.14)
const C_ABDO_HL= Color(0.35,0.14,0.40,0.20)
const C_ABDO_SH= Color(0.10,0.04,0.14,0.30)
const C_HOUR   = Color(0.78,0.12,0.08)
const C_HOUR_E = Color(0.85,0.28,0.10)
const C_HOUR_GL= Color(0.82,0.14,0.10,0.15)
const C_LEG    = Color(0.14,0.06,0.20)
const C_LEG_E  = Color(0.55,0.06,0.10)
const C_LEG_HL = Color(0.28,0.10,0.36,0.22)
const C_JNT    = Color(0.42,0.08,0.58)
const C_JNT_E  = Color(0.80,0.14,0.14)
const C_CLAW   = Color(0.78,0.08,0.14)
const C_SPINE  = Color(0.24,0.08,0.32,0.40)
const C_FACE   = Color(0.78,0.70,0.60)   # 骨色
const C_FACE_S = Color(0.60,0.52,0.42,0.35)# 骨阴影
const C_SOCKET = Color(0.06,0.04,0.06)   # 眼窝深黑
const C_EYE_GL = Color(0.72,0.10,0.06,0.50)# 眼窝红光
const C_EYE_E  = Color(0.90,0.08,0.04,0.60)# 怒红光
const C_PUPIL  = Color(0.90,0.85,0.80)   # 瞳孔小点
const C_CHEEK  = Color(0.60,0.20,0.22,0.25)# 小丑腮红 (低饱和)
const C_CHEEK_E= Color(0.72,0.28,0.22,0.30)
const C_SPOT   = Color(0.70,0.08,0.10)
const C_NOSE   = Color(0.65,0.10,0.12)   # 小丑红鼻
const C_NOSE_HL= Color(0.80,0.30,0.28,0.35)
const C_SMILE  = Color(0.50,0.04,0.06)   # 小丑笑纹
const C_MOUTH  = Color(0.14,0.02,0.04)   # 口腔
const C_GUM    = Color(0.72,0.06,0.08)
const C_TOOTH  = Color(0.85,0.74,0.55)   # 骨色牙
const C_FANG   = Color(0.80,0.70,0.58)
const C_HAIR   = Color(0.08,0.60,0.16)   # 绿毛 (稍暗)
const C_HAIR_S = Color(0.05,0.42,0.12,0.35)
const C_HAT    = Color(0.50,0.06,0.08)   # 小丑帽条纹
const C_HAT2   = Color(0.14,0.12,0.10)
const C_WEB    = Color(0.70,0.78,0.85,0.35)
const C_AURA   = Color(0.28,0.06,0.36,0.05)
const C_AURA_E = Color(0.72,0.06,0.58,0.08)
const C_AURA_S = Color(0.85,0.70,0.06,0.12)
const C_SHADOW = Color(0.00,0.00,0.00,0.08)

var _cache: Dictionary = {}
var _last_key: String = ""
var _last_tex: Texture2D = null

func reset_cache():
	_cache.clear()
	_last_key = ""
	_last_tex = null

# 直接渲染到 Image (无需 Texture, 供预览脚本用)
func render_image(state: Dictionary) -> Image:
	var img = Image.create(PW, PH, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_draw_on_image(img, state)
	img.flip_y()
	return img

func _draw_on_image(img: Image, state: Dictionary) -> void:
	var e = state.get("enraged", false)
	var d = state.get("dormant", false)
	var s = state.get("stunned", false)
	var j = state.get("jaw", 0.0)
	var t = state.get("t", 0.0)
	var dir = state.get("dir", -1.0)
	var st = state.get("state", "SKITTER")
	var warn = state.get("sky_drop_warn", false)

	if d or st == "CEILING_HANG": _web(img, t)
	_shadow(img)
	_abdo(img, e)
	_hourglass(img, e, t)
	_cephalo(img, e)
	_legs(img, t, st, d, s, e)
	if not d: _aura(img, s, e, t)
	_face(img, s, e, d, j, t, dir)
	if s: _stars(img, t)
	if st == "COUNTER_SWIPE": _bolt(img, t)
	if warn: _reticle(img, t)

func generate(state: Dictionary) -> Texture2D:
	var jaw_q = clampi(int(state.get("jaw", 0.0) * 6), 0, 5)
	var t_q = int(state.get("t", 0.0) * 5) % 16
	var key = "%s_J%d_T%d%s%s" % [
		state.get("state", "?"), jaw_q, t_q,
		"E" if state.get("enraged", false) else "",
		"S" if state.get("stunned", false) else "",
	]
	if _last_key == key and _last_tex: return _last_tex
	if _cache.has(key):
		_last_key = key; _last_tex = _cache[key]; return _last_tex
	var img = Image.create(PW, PH, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	_draw_on_image(img, state)
	var tex = ImageTexture.create_from_image(img)
	if _cache.size() > 80: _cache.clear()
	_cache[key] = tex; _last_key = key; _last_tex = tex
	return tex

# ═══════════════════════════════════════════════════
# 原语
# ═══════════════════════════════════════════════════
func _sp(img: Image, x: int, y: int, c: Color):
	if x >= 0 and x < PW and y >= 0 and y < PH: img.set_pixel(x, y, c)

func _fc(img: Image, ox: float, oy: float, r: float, c: Color):
	PixelLib.fill_circle(img, CX + ox, CY + oy, r, c)

func _fr(img: Image, ox: int, oy: int, w: int, h: int, c: Color):
	PixelLib.fill_rect(img, int(CX)+ox, int(CY)+oy, w, h, c)

func _ln(img: Image, x1: float, y1: float, x2: float, y2: float, c: Color, th: int = 1):
	var dx = x2-x1; var dy = y2-y1; var stp = max(abs(dx),abs(dy),1.0)
	for i in range(int(stp)+1):
		var p = i/stp; var ix = int(CX+x1+dx*p); var iy = int(CY+y1+dy*p)
		if ix<0 or ix>=PW or iy<0 or iy>=PH: continue
		img.set_pixel(ix,iy,c)
		if th==2:
			for ox in [-1,0,1]: for oy in [-1,0,1]:
				if ox==0 and oy==0: continue
				_sp(img,ix+ox,iy+oy,c)

func _tri(img: Image, a:Vector2, b:Vector2, c:Vector2, col:Color):
	var pts=[a,b,c]; var my0=max(0,int(CY+min(a.y,b.y,c.y)))
	var my1=min(PH-1,int(CY+max(a.y,b.y,c.y)))
	for y in range(my0,my1+1):
		var ly=y-CY; var xs:Array[float]=[]
		for i in 3:
			var p1=pts[i]; var p2=pts[(i+1)%3]
			if p1.y==p2.y: continue
			if (ly<p1.y and ly<p2.y) or (ly>p1.y and ly>p2.y): continue
			xs.append(CX+p1.x+(ly-p1.y)*(p2.x-p1.x)/(p2.y-p1.y))
		if xs.size()>=2:
			xs.sort()
			for x in range(max(0,int(xs[0])),min(PW,int(xs[xs.size()-1])+1)):
				img.set_pixel(x,y,col)

func _blend(img:Image, x:int, y:int, c:Color):
	if x<0 or x>=PW or y<0 or y>=PH: return
	var o=img.get_pixel(x,y); var a=c.a
	img.set_pixel(x,y,Color(c.r*a+o.r*(1-a),c.g*a+o.g*(1-a),c.b*a+o.b*(1-a),max(o.a,a)))

func _ellipse(img:Image, ox:float, oy:float, rx:float, ry:float, col:Color):
	var cx=int(CX+ox); var cy=int(CY+oy)
	for y in range(max(0,cy-int(ry)),min(PH,cy+int(ry)+1)):
		for x in range(max(0,cx-int(rx)),min(PW,cx+int(rx)+1)):
			if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1.0: img.set_pixel(x,y,col)

func _ellipse_blend(img:Image, ox:float, oy:float, rx:float, ry:float, col:Color):
	var cx=int(CX+ox); var cy=int(CY+oy)
	for y in range(max(0,cy-int(ry)),min(PH,cy+int(ry)+1)):
		for x in range(max(0,cx-int(rx)),min(PW,cx+int(rx)+1)):
			if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1.0: _blend(img,x,y,col)

func _a(c:Color, a:float)->Color: return Color(c.r,c.g,c.b,a)

# ═══════════════════════════════════════════════════
# 阴影 & 蛛丝
# ═══════════════════════════════════════════════════
func _shadow(img:Image):
	_ellipse_blend(img,0,28,20,4,C_SHADOW)
	_ellipse_blend(img,0,29,14,2,Color(0,0,0,0.06))

func _web(img:Image, t:float):
	for i in 4:
		var wx=-8+i*5; var wy=-28+i*2; var sw=sin(t*0.5+i*1.2)*1
		_ln(img,wx+sw,wy,wx+sw,wy-30,_a(C_WEB,0.30),1)
		_ln(img,wx-3+sw,wy-8,wx+3+sw,wy-8,_a(C_WEB,0.18),1)

# ═══════════════════════════════════════════════════
# 身体
# ═══════════════════════════════════════════════════
func _cephalo(img:Image, enraged:bool):
	var c=C_CEPH_E if enraged else C_CEPH
	_ellipse(img,0,-5,10,8,c)
	_ellipse_blend(img,-3,-8,5,3,Color(0.38,0.10,0.46,0.18))
	for x in range(-5,6):
		for y in range(2,5):
			var dx=x/5.0; var mx=c.lerp(C_ABDO_E if enraged else C_ABDO,abs(dx))
			_sp(img,int(CX+x),int(CY+y),mx)

func _abdo(img:Image, enraged:bool):
	var c=C_ABDO_E if enraged else C_ABDO
	_fc(img,0,14,14,c)
	_fc(img,-5,8,6,_a(C_ABDO_HL,0.18))
	_fc(img,-3,6,3,Color(0.42,0.16,0.44,0.12))
	_fc(img,0,23,7,_a(C_ABDO_SH,0.28))
	_fc(img,0,26,4,Color(0.06,0.02,0.08,0.25))
	var px = int(CX); var py = int(CY+14); var r=14
	for dy in range(-r,r+1): for dx in range(-r,r+1):
		if dx*dx+dy*dy>r*r: continue
		if (abs(dx)+abs(dy))%6==0 and abs(dy)<r-2:
			_blend(img,px+dx,py+dy,Color(0.32,0.10,0.40,0.18))

func _hourglass(img:Image, enraged:bool, t:float):
	var h=C_HOUR_E if enraged else C_HOUR
	var pulse=1.0+sin(t*3.0)*0.3
	_fc(img,0,14,8*pulse,_a(C_HOUR_GL,C_HOUR_GL.a*pulse))
	_tri(img,Vector2(-6,6),Vector2(6,6),Vector2(0,14),h)
	_tri(img,Vector2(-6,22),Vector2(6,22),Vector2(0,14),h)
	for yb in [7,23]: for dx in [-2,0,2]:
		_sp(img,int(CX+dx),int(CY+yb),Color(0.85,0.40,0.16,0.35))

# ═══════════════════════════════════════════════════
# 腿
# ═══════════════════════════════════════════════════
func _legs(img:Image, t:float, st:String, dormant:bool, stunned:bool, enraged:bool):
	var lc=C_LEG_E if enraged else C_LEG; var jc=C_JNT_E if enraged else C_JNT
	for i in 8:
		var right=i>=4; var s=1.0 if right else -1.0; var idx=i%4
		var ph=t*12.0+i*1.57; var hip_x=10*s; var hip_y=-6.0+idx*6
		var lift=max(0.0,sin(ph))*(8.0 if st=="SKITTER" else 3.0)
		var reach=cos(ph)*5.0
		var seg=_leg_pos(idx,hip_x,hip_y,ph,lift,reach,st,dormant,stunned,s)
		_leg_seg(img,hip_x,hip_y,seg.kx,seg.ky,lc,3)
		_leg_seg(img,seg.kx,seg.ky,seg.tx,seg.ty,lc,2)
		_leg_seg(img,seg.tx,seg.ty,seg.cx,seg.cy,lc,1)
		_fc(img,seg.kx,seg.ky,3,jc); _fc(img,seg.kx,seg.ky,1.2,Color(0.62,0.30,0.72,0.25))
		_fc(img,seg.tx,seg.ty,2.5,jc); _fc(img,seg.tx,seg.ty,1,Color(0.66,0.34,0.74,0.20))
		_ln(img,hip_x,hip_y,seg.kx,seg.ky,_a(C_LEG_HL,0.18),1)
		_fc(img,seg.cx,seg.cy,2.5,C_CLAW); _fc(img,seg.cx-s*1.5,seg.cy-0.5,1.2,Color(0.85,0.25,0.28,0.25))
		if not dormant and not stunned:
			for spi in 2:
				var sx=(hip_x+seg.kx)*0.5+spi*0.3*(seg.kx-hip_x)
				var sy=(hip_y+seg.ky)*0.5+spi*0.3*(seg.ky-hip_y)
				var sd=-s*(1 if spi==0 else -1)
				_ln(img,sx,sy,sx+sd*4,sy-2+spi*3,_a(C_SPINE,0.30),1)

func _leg_pos(idx:int, hx:float, hy:float, ph:float, lift:float, reach:float, st:String, d:bool, stun:bool, s:float)->Dictionary:
	var kx:float; var ky:float; var tx:float; var ty:float; var cx:float; var cy:float
	if d:
		var flex=sin(ph*0.8+idx)*4.0
		kx=hx+(14+idx*3+flex)*s; ky=hy-18-flex
		tx=hx+(24+idx*4)*s; ty=hy-32
		cx=hx+(30+idx*4)*s; cy=hy-42
	elif stun:
		kx=hx+(15+idx*3)*s; ky=hy+8+sin(ph*0.8+idx)*3.0
		tx=hx+(24+idx*4)*s; ty=hy+22
		cx=hx+(30+idx*5)*s; cy=hy+28
	elif st in ["POUNCE","INITIAL_POUNCE","SKY_LEAP_UP"]:
		kx=hx+(22+idx*4)*s; ky=hy-26
		tx=hx+(36+idx*5)*s; ty=hy-8
		cx=hx+(44+idx*5)*s; cy=hy+16
	elif st=="CEILING_HANG":
		kx=hx+(18+idx*3)*s; ky=hy-22
		tx=hx+(28+idx*4)*s; ty=hy-42
		cx=hx+(36+idx*4)*s; cy=hy-56
	else:
		kx=hx+(16+idx*4+reach)*s; ky=hy-20-lift
		tx=hx+(28+idx*5+reach*0.75)*s; ty=hy-6-lift*0.3
		cx=hx+(38+idx*5+reach*0.5)*s; cy=hy+18-lift*0.1
	return {"kx":kx,"ky":ky,"tx":tx,"ty":ty,"cx":cx,"cy":cy}

func _leg_seg(img:Image,x1:float,y1:float,x2:float,y2:float,c:Color,th:int):
	var dx=x2-x1; var dy=y2-y1; var stp=max(abs(dx),abs(dy),1.0)
	for i in range(int(stp)+1):
		var p=i/stp; var ix=int(CX+x1+dx*p); var iy=int(CY+y1+dy*p)
		if ix<0 or ix>=PW or iy<0 or iy>=PH: continue
		for ox in range(-th+1,th): for oy in range(-th+1,th):
			if abs(ox)+abs(oy)<th: _sp(img,ix+ox,iy+oy,c)

# ═══════════════════════════════════════════════════
# 骷髅×小丑脸
# ═══════════════════════════════════════════════════
func _face(img:Image, stunned:bool, enraged:bool, dormant:bool, jaw:float, t:float, dir:float):
	var d=dir; var is_e=enraged or stunned

	if dormant:
		# 休眠 → 简化骷髅闭眼
		_skull_base(img, false)
		_fc(img,-6*d,-10,4,Color(0.08,0.06,0.10))
		_fc(img, 6*d,-10,4,Color(0.08,0.06,0.10))
		_mouth_sleep(img)
		return

	# 骷髅基底
	_skull_base(img, is_e)
	# 小丑妆容覆盖
	_makeup(img, is_e, d)
	# 眼窝
	_sockets(img, stunned, enraged, d, t)
	# 嘴
	if stunned: _mouth_stun(img, t)
	else: _mouth(img, jaw, t)
	# 面廓
	_skull_outline(img)
	# 小丑帽/绿发
	_jester_hair(img, t)
	# 触肢
	if not stunned:
		for side in [-1,1]:
			var px=-8*side; var py=10; var pxx=-14*side; var pyy=18+sin(t*4.0+side)*2
			_ln(img,px,py,pxx,pyy,C_LEG,1); _fc(img,pxx,pyy,1.5,C_CLAW)

# 骷髅基底
func _skull_base(img:Image, intense:bool):
	# 主颅骨 — 椭圆
	_ellipse(img,0,-7,17,13,C_FACE)
	# 颧骨 (略宽)
	for side in [-1,1]:
		_fc(img,12*side,-2,5,C_FACE)
		_fc(img,13*side,1,3.5,C_FACE)
	# 下颌骨
	_fc(img,0,6,7,C_FACE)
	# 骨阴影 (太阳穴/下颚)
	_ellipse_blend(img,-12,-5,4,6,_a(C_FACE_S,0.40))
	_ellipse_blend(img,12,-5,4,6,_a(C_FACE_S,0.40))
	_fc(img,0,10,5,_a(C_FACE_S,0.50))

# 小丑妆容
func _makeup(img:Image, intense:bool, dir:float):
	var blush=C_CHEEK_E if intense else C_CHEEK
	# 腮红圆
	_fc(img,-10,-2,5,blush); _fc(img,10,-2,5,blush)
	# 前额菱形
	_fc(img,0,-15,3,_a(blush,0.35))
	_sp(img,int(CX),int(CY-15),C_SOCKET)
	# 鼻梁白线
	for dy in range(-8,-2):
		_sp(img,int(CX),int(CY+dy),Color(0.88,0.82,0.72))

# 眼窝
func _sockets(img:Image, stunned:bool, enraged:bool, dir:float, t:float):
	var d=dir
	if stunned:
		# 眩晕 X 眼窝
		_ellipse(img,-6*d,-10,5,4,C_SOCKET)
		_ellipse(img, 6*d,-10,5,4,C_SOCKET)
		# X 眼
		_ln(img,-6*d-3,-13,-6*d+3,-7,Color(0.85,0.72,0.08),1)
		_ln(img,-6*d-3,-7,-6*d+3,-13,Color(0.85,0.72,0.08),1)
		_ln(img,6*d-3,-13,6*d+3,-7,Color(0.85,0.72,0.08),1)
		_ln(img,6*d-3,-7,6*d+3,-13,Color(0.85,0.72,0.08),1)
	else:
		# 骷髅眼窝
		var glow=C_EYE_E if enraged else C_EYE_GL
		_ellipse(img,-6*d,-10,5,4.5,C_SOCKET)
		_ellipse(img, 6*d,-10,5,4.5,C_SOCKET)
		# 深红光
		_ellipse_blend(img,-6*d,-10,3.5,3,_a(glow,0.40))
		_ellipse_blend(img, 6*d,-10,3.5,3,_a(glow,0.40))
		# 瞳孔小光点 (跟踪玩家)
		_fc(img,-6*d+d*2,-10,1.2,C_PUPIL)
		_fc(img, 6*d+d*2,-10,1.2,C_PUPIL)
		# 高光
		_fc(img,-6*d+d*0.5,-11,0.8,Color(0.95,0.92,0.88))
		_fc(img, 6*d+d*0.5,-11,0.8,Color(0.95,0.92,0.88))
	# 小丑红鼻
	_fc(img,0,-4,3,C_NOSE)
	_fc(img,0,-5,1.5,_a(C_NOSE_HL,0.30))

# 嘴 — 小丑笑纹+骷髅牙
func _mouth(img:Image, jaw:float, t:float):
	var my=5; var mh=3+jaw*18; var mw=22
	# 小丑笑纹 (宽弧)
	var smile_a=_a(C_SMILE,0.60+jaw*0.30)
	var arc=3+sin(t*2.0)*0.5
	# 上弧
	for x in range(-int(mw/2),int(mw/2)+1):
		var sy=my+arc*sin(PI*x/mw)
		_sp(img,int(CX+x),int(CY+int(sy)),smile_a)
		_sp(img,int(CX+x),int(CY+int(sy)+1),_a(C_SMILE,0.30))
	# 下弧 (张嘴时露出)
	if jaw>0.1:
		for lx in range(-int(mw/2),int(mw/2)+1):
			var sy=my+mh-arc*sin(PI*lx/mw)
			_sp(img,int(CX+lx),int(CY+int(sy)),smile_a)

	# 牙龈
	_fr(img,-mw/2,3,mw+1,int(mh)+2,C_GUM)
	var mx0=int(CX-mw/2); var mx1=mx0+mw
	var my0=int(CY+3); var my1=min(PH-1,int(CY+3+mh))

	# 口腔黑洞
	for x in range(mx0,mx1): for y in range(my0,my1):
		_sp(img,x,y,C_MOUTH)

	# 上排骷髅牙
	var th=min(int(mh*0.35),4)
	for ti in 7:
		var tx=int(CX-mw/2+1+ti*3.0)
		for y in range(my0,min(PH-1,my0+th)):
			_sp(img,tx,y+1,C_TOOTH); _sp(img,tx+1,y,C_TOOTH)

	# 下排牙
	var bmy=int(CY+3+mh)-th
	for ti in 6:
		var tx=int(CX-mw/2+2+ti*3.2)
		for y in range(bmy,min(PH-1,int(CY+3+mh))):
			_sp(img,tx,y-1,C_TOOTH); _sp(img,tx+1,y,C_TOOTH)

	# 獠牙
	if jaw>0.25:
		var dy=int(CY+3+mh)
		for fi in 2:
			var fx=int(CX-mw/3+fi*int(mw*0.66))+(1 if fi==0 else -1)
			var fy=dy+int(sin(t*16.0+fi*3.14)*2)
			_sp(img,fx,fy,C_FANG); _sp(img,fx+1,fy,C_FANG)
			_sp(img,fx,fy+1,C_FANG); _sp(img,fx+1,fy+1,C_FANG)

func _mouth_sleep(img:Image):
	for x in range(int(CX-4),int(CX+5)):
		_sp(img,x,int(CY+4),Color(0.08,0.06,0.10))

func _mouth_stun(img:Image, t:float):
	var mw=20; var mh=10+sin(t*6.0)*4
	_fr(img,-mw/2,3,mw,int(mh),C_GUM)
	var mx0=int(CX-mw/2); var mx1=mx0+mw; var my0=int(CY+3); var my1=min(PH-1,int(CY+3+mh))
	for x in range(mx0,mx1): for y in range(my0,my1): _sp(img,x,y,C_MOUTH)
	var dx=int(CX+sin(t*5.0)*3)
	for dy in range(0,int(mh)+6): _blend(img,dx,int(CY+3+mh+dy),Color(0.60,0.78,0.85,0.30))

func _skull_outline(img:Image):
	# 颅骨顶轮廓
	for x in range(-16,17):
		var top_y=-7-13*sqrt(maxf(0.0, 1.0-(x/16.0)**2))
		_sp(img,int(CX+x),int(CY+int(top_y)),Color(0.50,0.40,0.30,0.20))


# 小丑帽 + 绿发
func _jester_hair(img:Image, t:float):
	# 小丑帽条纹 (前额)
	for x in range(-12,13):
		if abs(x)%4<2:
			_sp(img,int(CX+x),int(CY-18),C_HAT)
		else:
			_sp(img,int(CX+x),int(CY-18),C_HAT2)

	# 绿毛 (6+6 束)
	for hi in 6:
		var hx=-18+hi*7; var sway=sin(t*3.0+hi*0.8)*3
		var hy=-20+sway
		_ln(img,hx,-12,hx+sway*0.5,hy,C_HAIR,1)
		_ln(img,hx-1,-12,hx+sway*0.5-1,hy-1,_a(C_HAIR_S,0.25),1)
	for hi in 6:
		var hx=18-hi*7; var sway=cos(t*3.0+hi*0.8)*3
		var hy=-20+sway
		_ln(img,hx,-12,hx+sway*0.5,hy,C_HAIR,1)
		_ln(img,hx+1,-12,hx+sway*0.5+1,hy-1,_a(C_HAIR_S,0.25),1)
	# 顶毛团
	_fc(img,0,-16,6,C_HAIR)
	_fc(img,0,-14,4,_a(C_HAIR_S,0.20))
	_fc(img,0,-13,3.5,C_FACE)

# ═══════════════════════════════════════════════════
# 光环 & 特效
# ═══════════════════════════════════════════════════
func _aura(img:Image, stunned:bool, enraged:bool, t:float):
	var r=30 if enraged else 24; var col=C_AURA_S if stunned else (C_AURA_E if enraged else C_AURA)
	var cx=int(CX); var cy=int(CY)
	for y in range(max(0,cy-r),min(PH,cy+r+1)):
		for x in range(max(0,cx-r),min(PW,cx+r+1)):
			if (x-cx)**2+(y-cy)**2<=r*r: _blend(img,x,y,col)
	if enraged:
		var r2=32+sin(t*6.0)*4; var pulse=Color(0.80,0.06,0.65,0.05)
		for y in range(max(0,cy-int(r2)),min(PH,cy+int(r2)+1)):
			for x in range(max(0,cx-int(r2)),min(PW,cx+int(r2)+1)):
				var d2=(x-cx)**2+(y-cy)**2
				if d2<=r2*r2 and d2>(r2-4)**2: _blend(img,x,y,pulse)

func _stars(img:Image, t:float):
	for i in 3:
		var a=t*8.0+i*2.094; var sx=cos(a)*16; var sy=-20+sin(a)*6
		_fc(img,sx,sy,3,Color(0.85,0.80,0.18)); _fc(img,sx,sy,1.2,Color(0.85,0.85,0.78))

func _bolt(img:Image, t:float):
	for k in 3:
		var o1=sin(t*20.0+k*2.0)*38; var o2=sin(t*20.0+k*2.0+3.0)*38
		_ln(img,o1,-28,o2,2,Color(0.85,0.18,0.10,0.85),1)

func _reticle(img:Image, t:float):
	var r=22+sin(t*22.0)*4; var col=Color(0.85,0.08,0.08,0.12)
	var cx=int(CX); var cy=int(CY)
	for y in range(max(0,cy-r),min(PH,cy+r+1)):
		for x in range(max(0,cx-r),min(PW,cx+r+1)):
			if (x-cx)**2+(y-cy)**2<=r*r: _blend(img,x,y,col)
	_ln(img,-r-6,0,r+6,0,Color(0.85,0.18,0.18,0.85),1)
	_ln(img,0,-r-6,0,r+6,Color(0.85,0.18,0.18,0.85),1)
