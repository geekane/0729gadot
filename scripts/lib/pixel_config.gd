extends Node

# 像素风全局渲染配置
# 在 Game.gd._ready() 中调用 PixelConfig.apply(get_viewport())

static func apply(viewport: Viewport):
	# 核心：最近邻滤波，防止像素图缩放变模糊
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	# 视口缩放保持整数，避免亚像素偏移
	viewport.scaling_3d_scale = 1.0
