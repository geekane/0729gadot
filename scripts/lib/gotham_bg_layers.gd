# 哥谭暗夜守护者 4层视差背景加载器 (256x172 tileable)
# 从 bg_tileable.png 拆分，水平条带+alpha渐变，贪心矩形合并(tol=12)
# 共11686个矩形，637KB
# Game.gd 用法: GothamBgLayers.create_sky_texture() → Sprite2D.texture + motion_mirroring
extends Node

const PixelLib = preload("res://scripts/lib/pixel_lib.gd")

static func create_sky_texture() -> ImageTexture:
	"""Layer 0 - 夜空 (水平条带 y=-5~40) (1398 rects)"""
	return preload("res://scripts/lib/bg_layers/layer_0_sky.gd").create_texture()

static func create_far_buildings_texture() -> ImageTexture:
	"""Layer 1 - 远景楼群 (水平条带 y=25~75) (2820 rects)"""
	return preload("res://scripts/lib/bg_layers/layer_1_far_buildings.gd").create_texture()

static func create_mid_buildings_texture() -> ImageTexture:
	"""Layer 2 - 中景主城区 (水平条带 y=60~135) (4667 rects)"""
	return preload("res://scripts/lib/bg_layers/layer_2_mid_buildings.gd").create_texture()

static func create_foreground_texture() -> ImageTexture:
	"""Layer 3 - 近景地面 (水平条带 y=120~177) (2801 rects)"""
	return preload("res://scripts/lib/bg_layers/layer_3_foreground.gd").create_texture()

static func create_boss_portrait_texture() -> ImageTexture:
	"""Boss 肖像 (boss.jpg@192x288 tol32) (3188 rects)"""
	return preload("res://scripts/lib/bg_layers/layer_boss_portrait.gd").create_texture()
