extends Area2D

const PixelLib = preload("res://pixel_lib.gd")

# === 像素蘑菇精灵数据 ===
const PALETTE = {
	"R": Color(0.9, 0.2, 0.15),  # 蘑菇红
	"D": Color(0.6, 0.1, 0.05),  # 深红刺角
	"W": Color.WHITE,             # 眼白
	"B": Color(0.1, 0.1, 0.1),   # 黑瞳孔
	"E": Color(0.3, 0.05, 0.0),  # 愤怒眉毛
	"S": Color(0, 0, 0, 0.25),   # 阴影
	".": Color.TRANSPARENT,       # 透明
}

const MUSHROOM_DATA = [
	".....DDD......",
	"....DRRRRD....",
	"...RRRRRRRR...",
	"..RRRRRRRRRR..",
	"..RRRRRRRRRR..",
	"..RDRRRRRRDR..",
	"..RRRWWWWWRR..",
	"..RRRWBBWWRR..",
	"..RRRWBBWWRR..",
	"..REEEEEEEER..",
	"...RRRRRRRR...",
	"....SSSSS.....",
]

const BASE_PATROL_SPEED = 115.0
const CHASE_SPEED = 185.0  # 大幅加快追击速度，逼迫玩家使用蝙蝠飞镖攻击

var patrol_range = 100.0
var direction = -1
var start_x = 0.0
var alive = true
var anim_timer = 0.0
var player_node = null
var _sprite: Sprite2D

func _ready():
	add_to_group("enemies")
	start_x = position.x
	collision_mask = 1  # 检测玩家所在图层
	# 碰撞体（放大1.5倍适配更大视觉）
	var shape = RectangleShape2D.new()
	shape.size = Vector2(42, 36)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	# 像素精灵（放大1.5倍: 2.0 → 3.0）
	var tex = PixelLib.create_texture(14, 12, MUSHROOM_DATA, PALETTE)
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(3.0, 3.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.flip_h = direction < 0
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta):
	if not alive:
		return
		
	# 寻找玩家节点
	if not player_node or not is_instance_valid(player_node):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_node = players[0]
			
	var current_speed = BASE_PATROL_SPEED
	var new_dir = direction
	
	# 智能追踪 AI：当玩家在感知范围内时加速向玩家追击
	if player_node and is_instance_valid(player_node) and not player_node.is_dead:
		var dist_x = player_node.position.x - position.x
		var dist_y = abs(player_node.position.y - position.y)
		# 侦测范围：水平 450px，垂直 220px
		if abs(dist_x) < 450.0 and dist_y < 220.0 and abs(dist_x) > 4.0:
			current_speed = CHASE_SPEED
			new_dir = 1 if dist_x > 0 else -1
		else:
			# 超出追击范围时在初始点附近巡逻
			if position.x >= start_x + patrol_range:
				new_dir = -1
			elif position.x <= start_x - patrol_range:
				new_dir = 1
	else:
		if position.x >= start_x + patrol_range:
			new_dir = -1
		elif position.x <= start_x - patrol_range:
			new_dir = 1
			
	if new_dir != direction:
		direction = new_dir
		if _sprite:
			_sprite.flip_h = direction < 0
		
	position.x += current_speed * direction * delta
	position.x = clamp(position.x, 10.0, 1620.0)

func _on_body_entered(body):
	if not alive:
		return
	if body.is_in_group("player"):
		var player_bottom = body.position.y + 18       # 玩家碰撞体底部
		var prev_player_bottom = body.prev_position_y + 18  # 玩家上一帧底部
		var enemy_top = position.y - 18                # 敌人碰撞体顶部（42×36 半高=18）
		
		# 踩头判定：
		#   a) 玩家正下落（velocity.y >= 0）且底部在敌人顶部之上（容差16px）
		#   b) 玩家上一帧在敌人顶部附近
		var stomp_from_fall = body.velocity.y >= 0 and player_bottom <= enemy_top + 16
		var stomp_from_above = prev_player_bottom <= enemy_top + 4
		
		if stomp_from_fall or stomp_from_above:
			body.velocity.y = -380  # 弹跳更高
			var game = get_tree().current_scene
			if game and game.has_method("_on_enemy_stomped"):
				game._on_enemy_stomped(self)
			stomp()
		else:
			var game = get_tree().current_scene
			if game and game.has_method("_on_player_hit"):
				game._on_player_hit(body)

func stomp():
	"""玩家踩到敌人头顶"""
	alive = false
	# 延时安全禁用物理碰撞，避免物理刷新警告
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	
	# 压扁 + 消失动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 0.15), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "modulate", Color(0.5, 0.2, 0.05), 0.2)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)

func hit_by_batarang():
	"""被蝙蝠飞镖击中"""
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
