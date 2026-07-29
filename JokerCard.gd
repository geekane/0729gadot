extends Area2D

# 小丑狂笑扑克牌弹幕 (Joker Card Projectile)
# 由 Boss 发射的自旋狂笑扑克牌，击中玩家造成伤害

const SPEED = 450.0
const MAX_RANGE = 750.0

var direction = -1.0  # -1.0 = 向左, 1.0 = 向右
var distance_traveled = 0.0
var rotation_angle = 0.0

func _ready():
	add_to_group("enemy_projectiles")
	collision_layer = 1
	collision_mask = 1  # 检测玩家 Layer 1
	monitoring = true
	monitorable = true
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(18, 24)
	var col = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta):
	var move_amount = SPEED * delta
	position.x += direction * move_amount
	distance_traveled += move_amount
	
	rotation_angle += 20.0 * delta * direction
	queue_redraw()
	
	if distance_traveled >= MAX_RANGE:
		_destroy()

func _draw():
	draw_set_transform(Vector2.ZERO, rotation_angle, Vector2(1.0, 1.0))
	
	# 扑克牌白色边框与紫色背景 (Joker Card Frame)
	draw_rect(Rect2(-9, -12, 18, 24), Color(0.95, 0.95, 0.95))
	draw_rect(Rect2(-7, -10, 14, 20), Color(0.4, 0.1, 0.5))
	
	# 狂笑红唇 (Joker Smile)
	draw_circle(Vector2(0, 2), 3.5, Color(0.9, 0.1, 0.1))
	draw_line(Vector2(-4, -1), Vector2(4, -1), Color(1.0, 0.9, 0.2), 1.5)

func _on_body_entered(body):
	if body.is_in_group("player"):
		var game = get_tree().current_scene
		if game and game.has_method("_on_player_hit"):
			game._on_player_hit(body)
		_destroy()
	elif body is StaticBody2D:
		_destroy()

func _destroy():
	set_physics_process(false)
	monitoring = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(func():
		if is_instance_valid(self):
			hide(); queue_free()
	)
