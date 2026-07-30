# BgSingle — 用 bg.jpg 单张纹理替代 4 层视差背景
# 保持 ParallaxBackground 结构，单层慢速视差

const BG_PATH = "res://assets/bg.jpg"
const BG_W = 1168
const BG_H = 784

static func create(viewport_w: float, viewport_h: float) -> ParallaxBackground:
	var pb = ParallaxBackground.new()
	pb.name = "ParallaxBG"

	var layer = ParallaxLayer.new()
	layer.motion_scale = Vector2(0.03, 0.01)

	var spr = Sprite2D.new()
	var tex = _load_texture()
	if tex == null:
		return pb
	spr.texture = tex
	spr.centered = false

	# 等比缩放覆盖视口 (crop 顶部底部)
	var scale = viewport_w / BG_W
	spr.scale = Vector2(scale, scale)

	# 居中对齐顶部
	spr.position = Vector2(0, 0)

	layer.add_child(spr)
	pb.add_child(layer)
	return pb

static func _load_texture() -> Texture2D:
	var tex = ResourceLoader.load(BG_PATH)
	if tex == null:
		push_error("BgSingle: failed to load ", BG_PATH)
		return null
	return tex
