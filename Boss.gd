extends Area2D

# 小丑大 Boss (The Joker Boss)
# 10 点独立血量、头顶动态血条、扑克牌弹幕抛射、二阶段狂暴与击败爆裂动画

const JokerCard = preload("res://JokerCard.gd")

const MAX_HP = 10
var hp = 10
var invincible_timer = 0.0
var shoot_timer = 0.0
var anim_timer = 0.0

var start_x = 0.0
var patrol_range = 280.0
var direction = -1.0
var alive = true

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
	
	body_entered.connect(_on_body_entered)
	queue_redraw()

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
		
	var flip = 1.0 if direction > 0 else -1.0
	var is_enraged = hp <= 5
	
	# 狂暴气场紫粉光晕
	var aura_color = Color(0.9, 0.1, 0.8, 0.25) if is_enraged else Color(0.4, 0.1, 0.5, 0.15)
	draw_circle(Vector2.ZERO, 22.0, aura_color)
	
	# 1. 小丑紫色修身战服 (Purple Tuxedo Coat)
	draw_rect(Rect2(-10, -8, 20, 24), Color(0.38, 0.1, 0.48))
	draw_rect(Rect2(-8, -6, 16, 20), Color(0.48, 0.15, 0.58))
	
	# 黄色领结
	draw_polygon(PackedVector2Array([
		Vector2(-4, -6), Vector2(4, -6), Vector2(0, -3)
	]), PackedColorArray([Color(1.0, 0.85, 0.1)]))
	
	# 2. 苍白小丑面容 (Pale Face) & 翠绿头发 (Green Hair)
	draw_circle(Vector2(0, -16), 10.0, Color(0.95, 0.95, 0.92)) # 苍白脸庞
	
	# 绿发
	var hair_color = Color(0.1, 0.85, 0.25)
	draw_circle(Vector2(-4, -22), 5.0, hair_color)
	draw_circle(Vector2(0, -24), 6.0, hair_color)
	draw_circle(Vector2(4, -22), 5.0, hair_color)
	
	# 3. 巨幅狂笑鲜红嘴唇与黄色尖牙 (Joker Smile)
	var mouth_color = Color(0.9, 0.05, 0.1)
	draw_circle(Vector2(0, -12), 4.5, mouth_color)
	draw_line(Vector2(-6 * flip, -13), Vector2(6 * flip, -13), Color(1.0, 0.9, 0.2), 2.0)
	
	# 4. 阴森发光眼睛 (Glowing Eyes)
	var eye_col = Color(1.0, 0.1, 0.1) if is_enraged else Color(0.1, 0.9, 0.9)
	draw_circle(Vector2(-3.5 * flip, -18), 2.0, eye_col)
	draw_circle(Vector2(3.5 * flip, -18), 2.0, eye_col)
	
	# 5. 头顶动态 HP 血条 (Floating HP Bar)
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
	
	var game = get_tree().current_scene
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
	tween.chain().tween_callback(func(): hide(); queue_free())
