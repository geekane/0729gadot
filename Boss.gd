extends Area2D

# 小丑大 Boss (The Joker Boss)
# 10 点独立血量、头顶动态血条、扑克牌弹幕抛射、二阶段狂暴与击败爆裂动画

const JokerCard = preload("res://JokerCard.gd")
const PixelLib = preload("res://pixel_lib.gd")

const MAX_HP = 10

# 小丑像素调色板
const PALETTE = {
	"P": Color(0.48, 0.15, 0.58),   # 紫色身体
	"D": Color(0.38, 0.1, 0.48),    # 深紫
	"F": Color(0.95, 0.95, 0.92),   # 苍白脸
	"G": Color(0.1, 0.85, 0.25),    # 绿发
	"R": Color(0.9, 0.05, 0.1),     # 红唇
	"Y": Color(1.0, 0.85, 0.1),     # 黄领结/牙齿
	"E": Color(0.1, 0.9, 0.9),      # 青色眼睛
	"W": Color(1.0, 0.95, 0.8),     # 白色高光
	".": Color.TRANSPARENT,          # 透明
}

# 小丑像素图数据 (16×20)
const JOKER_DATA = [
	"....GGGGGGGG....",
	"...GGGGGGGGGG...",
	"..GGGFFFFFGGGG..",
	"..GFFFFFFFFFGG..",
	"..FFFFFFFFFFFF..",
	"..FFEFFFFFEFFF..",
	"..FFFFFFFFFFFF..",
	"..FFFRRRRRFFFR..",
	"..FRRRRRRRRRRF..",
	"..YFRRRRRRRRFY..",
	"....YYYYYYYY....",
	"....Y......Y....",
	"..DPPPPPPPPPD..",
	"..DPPPPPPPPPD..",
	"..DPPP....PPPD..",
	"..DPPP....PPPD..",
	"..DPPPPPPPPPD..",
	"..DPPPPPPPPPD..",
	"...DDDDDDDDDD...",
	"....DDDDDDDD....",
]

var hp = 10
var invincible_timer = 0.0
var shoot_timer = 0.0
var anim_timer = 0.0

var start_x = 0.0
var patrol_range = 280.0
var direction = -1.0
var alive = true
var joker_sprite = null

func _ready():
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	start_x = position.x
	scale = Vector2(2.2, 2.2)  # 巨型 Boss 体型
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 38)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	# 创建小丑像素精灵
	var tex = PixelLib.create_texture(16, 20, JOKER_DATA, PALETTE)
	joker_sprite = Sprite2D.new()
	joker_sprite.texture = tex
	joker_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(joker_sprite)
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if not alive:
		return
		
	anim_timer += delta
	if invincible_timer > 0:
		invincible_timer -= delta
		
	# 阶段判断: HP <= 5 进入二阶段狂暴 (速度与发射频次增加)
	var is_enraged = hp <= 5
	var speed = 170.0 if is_enraged else 105.0
	var shoot_cooldown = 1.1 if is_enraged else 1.9
	
	# 水平巡逻移动
	position.x += direction * speed * delta
	if abs(position.x - start_x) > patrol_range:
		direction *= -1.0
		position.x = clamp(position.x, start_x - patrol_range, start_x + patrol_range)
		
	# 自动抛射扑克牌弹幕
	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		_shoot_joker_card()
		
	if joker_sprite:
		joker_sprite.flip_h = direction < 0
	queue_redraw()

func _shoot_joker_card():
	var parent_world = get_parent()
	if not parent_world or not alive:
		return
		
	var card = JokerCard.new()
	var card_dir = -1.0 if direction < 0 else 1.0
	card.position = position + Vector2(18.0 * card_dir, -5.0)
	card.direction = card_dir
	parent_world.add_child(card)
	
	if parent_world.has_method("_spawn_particle_burst"):
		parent_world._spawn_particle_burst(card.position, Color(0.8, 0.2, 0.9))

func _draw():
	if not alive:
		return
		
	var is_enraged = hp <= 5
	
	# 狂暴气场紫粉光晕
	var aura_color = Color(0.9, 0.1, 0.8, 0.25) if is_enraged else Color(0.4, 0.1, 0.5, 0.15)
	draw_circle(Vector2.ZERO, 22.0, aura_color)
	
	# 头顶动态 HP 血条 (Floating HP Bar)
	var bar_w = 44.0
	var bar_h = 6.0
	var bar_pos = Vector2(-22, -34)
	
	# 血条黑底框
	draw_rect(Rect2(bar_pos.x - 1, bar_pos.y - 1, bar_w + 2, bar_h + 2), Color(0.05, 0.05, 0.1, 0.9))
	# 血条暗红底
	draw_rect(Rect2(bar_pos.x, bar_pos.y, bar_w, bar_h), Color(0.3, 0.05, 0.05))
	
	# 剩余血量绿/红条
	var hp_ratio = float(hp) / float(MAX_HP)
	var fill_w = bar_w * hp_ratio
	var fill_color = Color(0.1, 0.85, 0.3) if hp_ratio > 0.4 else Color(0.95, 0.15, 0.15)
	draw_rect(Rect2(bar_pos.x, bar_pos.y, fill_w, bar_h), fill_color)

func hit_by_batarang():
	"""受到蝙蝠飞镖攻击"""
	if not alive or invincible_timer > 0:
		return
		
	hp -= 1
	invincible_timer = 0.3
	
	# 受击闪白 (Hit Flash) & 震动停顿
	modulate = Color(2.5, 2.5, 2.5)
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	
	var game = get_tree().current_scene
	if game and game.has_method("add_camera_shake"):
		game.add_camera_shake(8.0, 0.18)
	if game and game.has_method("trigger_hit_stop"):
		game.trigger_hit_stop(0.04)
		
	if game and game.has_method("_spawn_floating_text"):
		var text = "-1 💥" if hp > 0 else "💥 BOSS DOWN!"
		game._spawn_floating_text(global_position, text, Color(1.0, 0.3, 0.2))
		
	if game and game.has_method("_spawn_particle_burst"):
		game._spawn_particle_burst(global_position, Color(1.0, 0.85, 0.1))
		
	if hp <= 0:
		_die_boss()
	else:
		queue_redraw()

func _on_body_entered(body):
	if not alive:
		return
	if body.is_in_group("player"):
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)

func _die_boss():
	alive = false
	set_physics_process(false)
	monitoring = false
	
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
			
	var game = get_tree().current_scene
	if game and game.has_method("_on_boss_defeated"):
		game._on_boss_defeated(self)
		
	# 大爆炸与销毁
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(3.5, 0.1), 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
