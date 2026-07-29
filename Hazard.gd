extends Area2D

const PixelLib = preload("res://pixel_lib.gd")

# 像素尖刺调色板
var PALETTE = {
	"S": Color(0.55, 0.6, 0.68),
	"D": Color(0.2, 0.22, 0.28),
	"R": Color(0.9, 0.2, 0.2),
	".": Color.TRANSPARENT,
}

# 像素尖刺数据 (20×10, 3 spikes)
var SPIKE_DATA = [
	"....R......R......R.",
	"....RR....RR....RR..",
	"...SSR...SSR...SSR..",
	"..SSSR..SSSR..SSSR..",
	".SSSSR.SSSSR.SSSSR..",
	"SSSSRRSSSSRRSSSSRR..",
	"SSSSDDSSSSDDSSSSDD..",
	".SSSD..SSSD..SSSD...",
	"..DD....DD....DD....",
	"..DD....DD....DD....",
]

# 地刺陷阱节点 (Spike Hazard)
var spike_width = 40.0
var spike_height = 20.0
var spike_count = 3

func _ready():
	add_to_group("hazards")
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	# 碰撞体
	var shape = RectangleShape2D.new()
	shape.size = Vector2(spike_width, spike_height * 0.8)
	var col = CollisionShape2D.new()
	col.shape = shape
	# 偏移到地刺中心
	col.position = Vector2(0, -spike_height * 0.4)
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	
	# 像素精灵 — 替代矢量绘制
	var tex = PixelLib.create_texture(20, 10, SPIKE_DATA, PALETTE)
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(2.0, 2.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -spike_height * 0.4)  # 对齐碰撞体中心
	add_child(sprite)

func _on_body_entered(body):
	if body.is_in_group("player"):
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)
