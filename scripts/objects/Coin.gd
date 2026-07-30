extends Area2D

const PixelLib = preload("res://scripts/lib/pixel_lib.gd")

var collected = false
var anim_time = 0.0
var base_y = 0.0
var col_shape: CollisionShape2D = null
var sprite: Sprite2D = null
var coin_textures = []

const COIN_PALETTE = {
	".": Color.TRANSPARENT,
	"R": Color(1.0, 0.84, 0.0),
	"Y": Color(1.0, 0.92, 0.3),
	"D": Color(0.85, 0.6, 0.0),
}

const COIN_FRAMES = [
	# Frame 0 — full face
	["..RR..",
	 ".RYYR.",
	 "RYYYYR",
	 "RYYDYR",
	 "RYYDYR",
	 "RYYYYR",
	 ".RYYR.",
	 "..RR.."],
	# Frame 1 — slight rotate
	["..RR..",
	 ".RYYR.",
	 "RYYYYR",
	 "RYYDYR",
	 "RYYDYR",
	 "RYYYYR",
	 ".RYYR.",
	 "..RR.."],
	# Frame 2 — narrower
	["..RR..",
	 ".R..R.",
	 "R.Y.R.",
	 "RYDYR.",
	 "RYDYR.",
	 "R.Y.R.",
	 ".R..R.",
	 "..RR.."],
	# Frame 3 — edge-on
	["..RR..",
	 ".R..R.",
	 "R....R",
	 "R.D.R.",
	 "R.D.R.",
	 "R....R",
	 ".R..R.",
	 "..RR.."],
	# Frame 4 — narrowest (same as 3)
	["..RR..",
	 ".R..R.",
	 "R....R",
	 "R.D.R.",
	 "R.D.R.",
	 "R....R",
	 ".R..R.",
	 "..RR.."],
	# Frame 5 (same as 3)
	["..RR..",
	 ".R..R.",
	 "R....R",
	 "R.D.R.",
	 "R.D.R.",
	 "R....R",
	 ".R..R.",
	 "..RR.."],
	# Frame 6 (same as 2)
	["..RR..",
	 ".R..R.",
	 "R.Y.R.",
	 "RYDYR.",
	 "RYDYR.",
	 "R.Y.R.",
	 ".R..R.",
	 "..RR.."],
	# Frame 7 (same as 1)
	["..RR..",
	 ".RYYR.",
	 "RYYYYR",
	 "RYYDYR",
	 "RYYDYR",
	 "RYYYYR",
	 ".RYYR.",
	 "..RR.."],
]

func _ready():
	add_to_group("coins")
	collision_layer = 1
	collision_mask = 1  # 检测玩家所在图层 (Layer 1)
	monitoring = true
	monitorable = true
	base_y = position.y
	# 随机打乱初始动画相位
	anim_time = randf() * 6.28
	
	# 碰撞体（扩大幅值至 16px 确保碰撞灵敏度）
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	col_shape = CollisionShape2D.new()
	col_shape.shape = shape
	add_child(col_shape)
	
	body_entered.connect(_on_body_entered)
	
	# 创建像素精灵（8×8 像素金币纹章，8 帧旋转动画）
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(4.0, 4.0)
	add_child(sprite)
	
	# 生成 8 帧旋转动画纹理
	for frame_data in COIN_FRAMES:
		coin_textures.append(
			PixelLib.create_texture(8, 8, frame_data, COIN_PALETTE)
		)
	sprite.texture = coin_textures[0]

func _physics_process(delta):
	if collected:
		return
	anim_time += delta * 4.0
	# 物理帧驱动金币上下浮动 (Bobbing)，确保 Physics Server 碰撞体同步
	position.y = base_y + sin(anim_time) * 3.5
	
	# 像素精灵纹理循环（8 帧旋转动画，使用 posmod 防越界）
	var tex_count = coin_textures.size()
	if tex_count > 0:
		sprite.texture = coin_textures[posmod(int(anim_time * 2), tex_count)]
		
	# 双重防漏判定：在物理帧检测重叠对象，防止高速移动下错过信号
	var bodies = get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("player"):
			_collect(b)
			return


func _on_body_entered(body):
	if body.is_in_group("player"):
		_collect(body)

func _collect(body):
	if collected:
		return
	collected = true
	
	# 立即安全禁用碰撞体，防止二次触发
	if col_shape and is_instance_valid(col_shape):
		col_shape.set_deferred("disabled", true)
	
	var game = get_tree().current_scene
	if game and game.has_method("_on_coin_collected"):
		game._on_coin_collected(self)
	
	# 收集动画：放大、向上飞出并淡出
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30.0, 0.22)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)
