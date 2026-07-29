extends Area2D

const PixelLib = preload("res://pixel_lib.gd")

# ── 小丑无人机像素调色板 ──
const PALETTE: Dictionary = {
	"P": Color(0.5, 0.15, 0.55),
	"D": Color(0.35, 0.12, 0.38),
	"R": Color(1.0, 0.2, 0.25),
	"J": Color(0.85, 0.15, 0.2),
	"W": Color.WHITE,
	"B": Color(0.1, 0.05, 0.15),
	"G": Color(0.8, 0.8, 0.85),
	"K": Color(0.3, 0.3, 0.35),
	".": Color.TRANSPARENT,
}

# ── 4帧螺旋桨旋转动画（16×16） ──
const DRONE_FRAMES: Array[Array] = [
	# 帧0：螺旋桨水平
	[
		"....GGGGGGGG....",
		"....GGGGGGGG....",
		"......KK........",
		"......KK........",
		"...DDDDDDDD.....",
		"..DDPDPDPDDD....",
		"..DPPPDPPPPD....",
		"..DPPPBPPPDD....",
		"..DPPBRBPPDP....",
		"..DPPBPPPPPDP...",
		"..DDPPJPPPJPD...",
		"...DPPPPPPPPD...",
		"....DJ...JJ.....",
		"....DD...DD.....",
		".......KK.......",
		".......KK.......",
	],
	# 帧1：螺旋桨斜45°
	[
		"......GG........",
		".....GG.........",
		"....GG..KK......",
		"...GG...KK......",
		"...DDDDDDDD.....",
		"..DDPDPDPDDD....",
		"..DPPPDPPPPD....",
		"..DPPPBPPPDD....",
		"..DPPBRBPPDP....",
		"..DPPBPPPPPDP...",
		"..DDPPJPPPJPD...",
		"...DPPPPPPPPD...",
		"....DJ...JJ.....",
		"....DD...DD.....",
		".......KK.......",
		".......KK.......",
	],
	# 帧2：螺旋桨垂直
	[
		"......G.........",
		"......G.........",
		"......G.........",
		"......G.........",
		"...DDKKDDDD.....",
		"..DDPDPDPDDD....",
		"..DPPPDPPPPD....",
		"..DPPPBPPPDD....",
		"..DPPBRBPPDP....",
		"..DPPBPPPPPDP...",
		"..DDPPJPPPJPD...",
		"...DPPPPPPPPD...",
		"....DJ...JJ.....",
		"....DD...DD.....",
		".......G........",
		".......G........",
	],
	# 帧3：同帧1（对称斜45°）
	[
		"......GG........",
		".....GG.........",
		"....GG..KK......",
		"...GG...KK......",
		"...DDDDDDDD.....",
		"..DDPDPDPDDD....",
		"..DPPPDPPPPD....",
		"..DPPPBPPPDD....",
		"..DPPBRBPPDP....",
		"..DPPBPPPPPDP...",
		"..DDPPJPPPJPD...",
		"...DPPPPPPPPD...",
		"....DJ...JJ.....",
		"....DD...DD.....",
		".......KK.......",
		".......KK.......",
	],
]

# 飞行敌人：小丑无人机 (Joker Drone)
const SPEED = 110.0
var patrol_range = 160.0

const FlyEnemyBullet = preload("res://FlyEnemyBullet.gd")

var direction = 1
var start_pos = Vector2.ZERO
var alive = true
var anim_time = 0.0
var shoot_timer = 0.0
var sprite: Sprite2D
var drone_textures = []

func _ready():
	add_to_group("enemies")
	start_pos = position
	collision_mask = 1  # 检测玩家图层
	shoot_timer = randf_range(0.0, 1.5) # 错开发射时间
	
	# 碰撞体 (圆形浮空，放大1.5倍: radius 16→24)
	var shape = CircleShape2D.new()
	shape.radius = 24.0
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	# 像素螺旋桨无人机精灵
	for frame_data in DRONE_FRAMES:
		drone_textures.append(PixelLib.create_texture(16, 16, frame_data, PALETTE))
	
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = drone_textures[0] if drone_textures.size() > 0 else null
	sprite.flip_h = direction < 0
	sprite.scale = Vector2(3.0, 3.0)
	add_child(sprite)
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if not alive:
		return
		
	anim_time += delta * 6.0
	shoot_timer += delta
	
	# 水平往复 + 垂直波浪运动
	position.x += SPEED * direction * delta
	position.y = start_pos.y + sin(anim_time * 0.8) * 18.0
	
	if position.x >= start_pos.x + patrol_range:
		direction = -1
		sprite.flip_h = true
	elif position.x <= start_pos.x - patrol_range:
		direction = 1
		sprite.flip_h = false
		
	# 更新螺旋桨动画帧
	var d_size = drone_textures.size()
	if d_size > 0:
		sprite.texture = drone_textures[posmod(int(anim_time * 4), d_size)]
	
	# 远程子弹发射控制 (当玩家在 420px 范围内时发射)
	if shoot_timer >= 2.2:
		shoot_timer = 0.0
		_shoot_bullet_at_player()

func _shoot_bullet_at_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	var player = players[0]
	if not is_instance_valid(player) or player.is_dead:
		return
		
	var dist = global_position.distance_to(player.global_position)
	if dist <= 420.0:
		var bullet = FlyEnemyBullet.new()
		bullet.global_position = global_position + Vector2(0, 10)
		bullet.direction = (player.global_position - global_position).normalized()
		get_parent().add_child(bullet)

func _on_body_entered(body):
	if not alive:
		return
	if body.is_in_group("player"):
		var player_bottom = body.position.y + 18
		var prev_player_bottom = body.prev_position_y + 18
		var drone_top = position.y - 22
		
		# 踩头判定：从上方落向无人机
		var stomp_from_fall = body.velocity.y >= 0 and player_bottom <= drone_top + 16
		var stomp_from_above = prev_player_bottom <= drone_top + 4
		
		if stomp_from_fall or stomp_from_above:
			body.velocity.y = -400.0  # 弹跳更高
			var game = get_tree().current_scene
			if game and game.has_method("_on_enemy_stomped"):
				game._on_enemy_stomped(self)
			stomp()
		else:
			var game = get_tree().current_scene
			if game and game.has_method("_on_player_hit"):
				game._on_player_hit(body)

func stomp():
	alive = false
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	
	# 爆炸掉落销毁动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.3, 0.2), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
	
func hit_by_batarang():
	if not alive:
		return
	alive = false
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
			
	var game = get_tree().current_scene
	if game and game.has_method("_on_enemy_stomped"):
		game._on_enemy_stomped(self)
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
