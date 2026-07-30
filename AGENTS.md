# AI Agent — 横板冒险开发指南

> **项目**: Godot 4.7.1 横板过关小游戏
> **路径**: `D:\godot-test-project`
> **目标**: 供 AI Agent 持续优化开发的知识基准

---

## 0. 核心编码与工作流规则 (Core Guidelines)

> [!IMPORTANT]
> 1. **全中文沟通与注释**：回答问题一律使用中文，所有 GDScript 代码中的注释必须全部使用中文。
> 2. **修改后自动试玩**：每次修改代码后，必须通过自动化测试脚手架 (`TestRunner.gd`) 进行实际游玩测试与逐帧渲染快照检查。
> 3. **⚠️ [MUST] 确认无误后打包 — 禁止跳过！** 自动化测试通过后，**立即**（在同一会话内）执行 `--export-release` 打包生成 `.exe`。如果 commit 被 pre-commit hook 拦住，请先打包再提交。
> 4. **保持纯 GDScript 代码架构**：所有节点继续使用 GDScript 动态创建，不打破纯代码设计理念。

---

## 1. 项目概要


纯 GDScript 的 Godot 4 平台跳跃游戏。所有节点用代码动态创建（无 .tscn 场景编辑）。
玩家控制角色收集金币、踩敌人、到达终点通关。

### 关键文件

| 文件 | 类 | 类型 | 职责 |
|------|-----|------|------|
| `Game.gd` | — | `Node2D` | 状态机、关卡构建、Camera(自定义lerp)、HUD(StyleBoxFlat)、暂停、最高分、飘字特效、碰撞响应 |
| `Player.gd` | — | `CharacterBody2D` | 输入处理(WASD/Space/左键/右键/H)、物理、朝向翻转_draw、近战斩击/弹反、受伤/无敌/死亡、智能重绘(needs_redraw) |
| `Boss.gd` | — | `Area2D` | 小丑大 Boss AI (10 HP、头顶动态血条、狂暴二阶段、狂笑扑克弹幕、击败爆裂动画) |
| `JokerCard.gd` | — | `Area2D` | 小丑狂笑扑克牌弹幕、自旋动画、击中玩家伤害检测 |
| `Batarang.gd` | — | `Area2D` | 蝙蝠侠飞镖、高速飞行自旋双翼矢量绘制、击中敌/Boss 爆裂消灭 |
| `Enemy.gd` | — | `Area2D` | 地面巡逻 AI、像素蘑菇怪(14x12)、踩头判定、压扁动画 |
| `FlyEnemy.gd` | — | `Area2D` | 飞行蝙蝠怪物 AI、像素无人机(16x16)+螺旋桨动画 |
| `FlyEnemyBullet.gd` | — | `Area2D` | 飞行敌人能量子弹（支持近战弹反 `deflect()`） |
| `Coin.gd` | — | `Area2D` | 浮动动画(bobbing)、8帧像素旋转动画、双保险碰撞检测、收集飞走动画 |
| `Hazard.gd` | — | `Area2D` | 地刺陷阱、玩家触碰伤害判定 |
| `MovingPlatform.gd` | — | `AnimatableBody2D` | 动态升降/左右移动单向平台 |
| `TestRunner.gd` | — | `SceneTree` | 800 帧全自动游玩压测、帧率监控、白闪诊断与渲染快照脚手架 |
| `Game.tscn` | — | — | 项目入口，引用 Game.gd |
| `export_presets.cfg` | — | — | Windows 导出配置 |

---

## 2. 碰撞系统（最容易出错的地方）

### 图层分配

| 节点 | `collision_layer` | `collision_mask` | 说明 |
|------|--------------------|-------------------|------|
| Player (CharacterBody2D) | 1 (默认) | **3** (1+2) | 必须=3才能撞到地面(层1)+平台(层2) |
| Ground (StaticBody2D) | **1** (默认) | — | 实心地面的物理层 |
| Platform (StaticBody2D) | **2** (显式传参) | — | 单向平台（只能从上面站住） |
| Coin (Area2D) | 1 | 1 | 检测玩家进入 |
| Enemy (Area2D) | 1 | 1 | 检测玩家进入（踩头用位置判定） |
| Finish (Area2D) | 1 | 1 | 检测玩家到达 |

### 玩家碰撞关键配置

```gdscript
# Player.gd _ready()
collision_mask = 3          # 图层1(地面) + 图层2(平台)，缺一不可
platform_floor_layers = 2    # 图层2的StaticBody2D当作单向平台
```

**⚠️ 已知坑**:
- `collision_mask` 设为 `1`（只含图层1）→ 玩家会穿过平台落到地上
- `collision_mask` 设为 `3`（1+2）→ 玩家正常站上平台，从下方穿过
- `platform_floor_layers` 只对 `CharacterBody2D` 的 `move_and_slide()` 生效
- Area2D 的 `collision_mask` 默认为 `0`（啥都不检测），必须显式赋值

### 单向平台实现

```gdscript
# Game.gd _add_static_rect
body.collision_layer = collision_layer  # ground传1，platform传2

# Player.gd _ready()
platform_floor_layers = 2  # 告诉move_and_slide: 图层2的StaticBody2D是单向地板
```

**物理机制**: `move_and_slide()` 检查 `platform_floor_layers`，只把对应图层的 StaticBody2D 当作"单向地板"——从上方落上站住，从下方穿过无碰撞。不需要修改 CollisionShape2D 本身的参数。

---

## 2.5 节点组 (Group) 约定表

所有节点通过 `add_to_group()` 加入以下组，用于批量查找和攻击检测：

| 组名 | 节点 | 用途 |
|------|------|------|
| `"player"` | Player (CharacterBody2D) | 玩家角色标识 |
| `"enemies"` | Enemy, FlyEnemy, Boss | 所有敌方单位（含 Boss） |
| `"bosses"` | Boss | 仅 Boss，用于单独检测 |
| `"enemy_projectiles"` | JokerCard, FlyEnemyBullet | 敌方弹幕，用于近战弹反 / 飞镖摧毁 |
| `"batarangs"` | Batarang | 蝙蝠飞镖自检（防重复击中同目标） |
| `"coins"` | Coin | 金币收集检测 |
| `"hazards"` | Hazard | 地刺陷阱伤害检测 |
| `"drifting_clouds"` | 背景云朵 Sprite2D | 云层飘动控制 |

**规范**: 新增任何可交互节点都必须加入对应的组，否则批量攻击/弹反/收集检测会失效。

---

## 3. 游戏状态机

```
MENU ──(Space)──► PLAYING
                     │
                     ├──► 通关 ──► WON ──(Space)──► MENU
                     │
                     └──► 命数=0 ──► GAME_OVER ──(Space)──► MENU
```

在 `_process(delta)` 中每帧检查:

```gdscript
match state:
    GameState.MENU:
        _blink_step(delta)        # "按空格"闪烁
        if Input...: _start_game()
    GameState.PLAYING:
        camera.position = player  # 镜头跟随
        if player.y > GROUND_Y+100: _on_player_hit(player)  # 掉落死亡
    GameState.WON, GameState.GAME_OVER:
        _blink_step(delta)        # 提示闪烁
        if Input...: _go_back_menu()
```

### 状态切换时的关键操作

| 切换 | 清理 | 创建 |
|------|------|------|
| MENU → PLAYING | queue_free 菜单UI | world + player + HUD |
| PLAYING → WON | — | input_disabled=true, 弹出 overlay |
| PLAYING → GAME_OVER | — | input_disabled=true, 弹出 overlay |
| WON/GAME_OVER → MENU | queue_free 所有子节点 | _create_menu() |

---

## 4. Bug 修复历史（防止回归）

### 4.1 ❌ 无限 Tween 导致程序未响应

**症状**: 游戏启动几秒后窗口灰掉 → "未响应"
**根因**: `create_tween().set_loops().tween_property(...)` — 无限循环 Tween 在节点被 `queue_free` 后仍引用已释放的对象，Tween 系统内部崩溃
**修复**: 删除所有 `set_loops()` 调用。闪烁改用 `_process` + 计时器:

```gdscript
# Game.gd _blink_step(delta)
blink_timer += delta
if blink_timer > 0.6:
    blink_timer = 0.0
    blink_visible = not blink_visible
    overlay_hint.modulate.a = 0.9 if blink_visible else 0.3
```

### 4.2 ❌ 镜头不跟随（玩家画面外出生）

**症状**: 游戏开始后玩家在画面外（镜头在原点 0,0）
**根因**: Camera2D 的 `position_smoothing_enabled = true`，从 (0,0) 缓慢平滑到玩家位置
**修复**: 创建玩家后立即关闭平滑 → 瞬移 → 重新开启:

```gdscript
camera.position_smoothing_enabled = false
camera.position = player_node.position
camera.position_smoothing_enabled = true
```

同时每帧 `_process` PLAYING 态强制 `camera.position = player_node.position`。

### 4.3 ❌ 平台无物理（玩家穿过）

**症状**: 玩家直接穿过浮空平台
**根因**: Player 的 `collision_mask = 1`，只包含图层1（地面），Platform 在图层2
**修复**: `collision_mask = 3`（含图层1和图层2）+ `platform_floor_layers = 2`

### 4.4 ❌ 踩敌人自己受伤

**症状**: 快速下落踩敌人时判定为受伤
**根因**: 踩头容差只有 8px，快速下落有可能一帧内位移超过此值
**修复**: 双条件判定:

```gdscript
var stomp_from_fall = body.velocity.y >= 0 and player_bottom <= enemy_top + 16
var stomp_from_above = prev_player_bottom <= enemy_top + 4
if stomp_from_fall or stomp_from_above:
    # 踩头成功
```

- `stomp_from_fall`: 正下落 + 身体在敌人顶部 16px 以内
- `stomp_from_above`: 上一帧身体在敌人顶部 4px 以内（补捉极速下落漏判）
- 需要 Player 记录 `prev_position_y`

### 4.5 ❌ 窗口失焦后方向卡死

**症状**: 切窗再切回来，角色一直往右走
**根因**: `Input.get_axis("ui_left", "ui_right")` 读取的是按键状态，焦点丢失后 KEY_UP/KEY_DOWN 事件丢失，但 KeyDown 状态仍为 true
**修复**: 监听窗口失焦通知，清空缓冲区:

```gdscript
func _notification(what):
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        Input.flush_buffered_events()
```

### 4.6 ❌ 开局自动起跳

**症状**: 按 Space 开始游戏 → 角色立即自动跳起
**根因**: 菜单按 Space 触发 `_start_game` → 创建 Player → 同一个 Space 按键事件仍被 `_unhandled_input` 收到 → 触发跳跃
**修复**: `just_spawned` 标志位，首帧 `_physics_process` 清除前阻止所有输入:

```gdscript
# Player.gd
var just_spawned = true

func _physics_process(delta):
    if is_dead or input_disabled: return
    just_spawned = false           # 本帧执行完后允许输入
    ...

func _unhandled_input(event):
    if is_dead or input_disabled or just_spawned:  # 阻止
        return
```

### 4.7 ❌ 通关/结束界面时角色仍可移动

**症状**: 弹出"通关"/"游戏结束"画面后，角色仍能左右移动
**根因**: HUD 层只是显示文字，没有禁用玩家输入
**修复**: 设置 `input_disabled = true`:

```gdscript
# Game.gd _win_game() / _game_over()
player_node.input_disabled = true
```

---

## 5. 用户新增功能详解（学习重点）

以下记录用户（钟志恒）对游戏的优化修改，作为 AI 后续学习的核心参考。

### 5.1 暂停系统

```gdscript
# Game.gd _unhandled_input — 用 _unhandled_input 而非 _process 避免一帧内多次触发
func _unhandled_input(event):
    if state == GameState.PLAYING and event.is_action_pressed("ui_cancel"):
        _toggle_pause()

func _toggle_pause():
    is_paused = not is_paused
    get_tree().paused = is_paused   # 暂停物理引擎，所有 _process/_physics 停摆
    
    if is_paused:
        # 用 CanvasLayer + Panel(StyleBoxFlat) 创建暂停UI
        pause_overlay = CanvasLayer.new()
        var bg = ColorRect.new()
        bg.color = Color(0, 0, 0, 0.55)
        var panel = Panel.new()
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.12, 0.16, 0.28, 0.95)
        style.corner_radius_* = 16  # 圆角面板
        ...
    else:
        if pause_overlay and is_instance_valid(pause_overlay):
            pause_overlay.queue_free()
```

**学习要点**:
- `get_tree().paused = true` 会冻结所有 `_process`/`_physics_process` 和 Tween，但 `_unhandled_input` 仍然工作
- 暂停时保留玩家引用但不操作（因为物理被冻结）
- `is_instance_valid()` 检查防止操作已释放节点

### 5.2 最高分持久化

```gdscript
# 使用 ConfigFile 读写本地文件，不需要外部数据库/服务器
func _load_high_score():
    var config = ConfigFile.new()
    if config.load("user://high_score.cfg") == OK:
        high_score = config.get_value("game", "high_score", 0)

func _save_high_score():
    var config = ConfigFile.new()
    config.set_value("game", "high_score", high_score)
    config.save("user://high_score.cfg")
```

**学习要点**:
- `user://` 路径自动映射到系统用户数据目录（Windows: `%APPDATA%/Godot/app_userdata/<project>`）
- `ConfigFile` 是 Godot 内置的简单键值存储，适合少量配置
- 在 `_ready()` 中加载，在通关/结束时保存

### 5.3 自定义 Camera lerp（替代内置 Smoothing）

```gdscript
# 将 Camera2D 的 position_smoothing_enabled 设为 false
# 在 _process 中手动插值
camera.position = camera.position.lerp(player_node.position, 12.0 * delta)
```

**为什么这么做**: Godot 内置的 `position_smoothing_enabled` 与每帧强制 `camera.position = player.position` 会互相竞争（内置平滑想慢慢走，代码想瞬间拉过去），导致画面抖动卡顿。自定义 lerp 统一了控制权。

**学习要点**:
- `lerp(a, b, t)` 每帧逼近目标，`t=12*delta` 在 60fps 下约 0.2/帧，接近但永不等于目标
- 关了内置平滑就不用再搞 `position_smoothing_enabled = false → snap → true` 那套了
- 枪毙了原来关平滑→瞬移→开平滑的 hack

### 5.4 飘字得分特效

```gdscript
func _spawn_floating_text(world_pos: Vector2, text: String, color: Color):
    var label = Label.new()
    label.text = text
    # ... 样式设置 ...
    label.position = world_pos + Vector2(-15, -25)
    add_child(label)
    
    var tween = create_tween().set_parallel(true)
    tween.tween_property(label, "position:y", label.position.y - 35.0, 0.6)
    tween.tween_property(label, "modulate:a", 0.0, 0.6)
    tween.chain().tween_callback(func(): label.queue_free())
```

**调用点**: `_on_coin_collected` → "+1"金色, `_on_enemy_stomped` → "+2"绿色, `_player_hurt` → "-1 ❤️"红色

**学习要点**: `set_parallel(true)` 让上下飘 + 淡出同时发生，`chain().tween_callback()` 结束后自动清理。使用 `set_parallel` + `chain` 的组合是 Tween 的常用模式。

### 5.5 Coin 浮动动画与双保险碰撞

```gdscript
# Coin.gd _physics_process — 用物理帧驱动浮动，使碰撞体随金币同步移动
func _physics_process(delta):
    if collected: return
    anim_time += delta * 4.0
    position.y = base_y + sin(anim_time) * 3.5  # 上下浮动 3.5px
    
    # 双保险：body_entered 信号 + 物理帧主动检测重叠
    var bodies = get_overlapping_bodies()
    for b in bodies:
        if b.is_in_group("player"):
            _collect(b)
            return
```

**为什么用 `_physics_process` 而非 `_process`**: 物理帧驱动的 `position.y` 变化才能被 Physics Server 感知，碰撞体才能同步移动。如果用 `_process`（渲染帧），高速移动可能穿模。

**碰撞体安全禁用**:
```gdscript
# 使用 set_deferred 避免在物理回调中直接修改碰撞体
col_shape.set_deferred("disabled", true)
```

**椭圆绘制防白闪**:
```gdscript
# Coin.gd _draw_ellipse — 严格确保 rx/ry 为正，防止 OpenGL 多边形缠绕异常
rx = max(abs(rx), 1.0)
ry = max(abs(ry), 1.0)
```

**学习要点**: 用户特别加了注释说明——`draw_polygon` 如果传入负的半径会导致顶点顺序反转（winding order flip），某些 GL 驱动会画成白屏。这是图形编程的深坑。

### 5.6 玩家朝向翻转与智能重绘

```gdscript
# Player.gd — facing_right 控制左右镜像
var facing_right = true
var flip = 1.0 if facing_right else -1.0

# 只在实际需要时才 queue_redraw()
var needs_redraw = false
# 只有 alpha 变了才需要重绘
if modulate.a != alpha:  
    modulate.a = alpha
    needs_redraw = true
# 只有朝向变了才需要重绘
if new_facing != facing_right:
    facing_right = new_facing
    needs_redraw = true

if needs_redraw:
    queue_redraw()
```

**学习要点**: 原来每帧无脑 `queue_redraw()`。用户优化为按需重绘——只有无敌闪烁（alpha变）或转向时才触发。减少 CPU 开销。

### 5.7 敌人视觉重绘（蘑菇怪）

```gdscript
# Enemy.gd — 从简单矩形红块变成蘑菇形状
# 身体（圆角红头菇）
draw_rect(Rect2(-14, -10, 28, 20), Color(0.9, 0.2, 0.15))
draw_circle(Vector2(0, -10), 14, Color(0.9, 0.2, 0.15))  # 蘑菇盖

# 阴影
draw_ellipse_custom(Vector2(0, 10), 14, 4, Color(0, 0, 0, 0.25))

# 愤怒小眉毛
draw_line(Vector2(-9, -10), Vector2(-2, -7), Color(0.3, 0.05, 0.0), 2.0)
```

**学习要点**: 纯代码绘制复杂形状——用 `draw_circle` + `draw_rect` 组合出蘑菇轮廓，`draw_ellipse_custom` 画阴影增加立体感，`draw_line` 画眉毛表达情绪。所有视觉元素不需要外部素材。

### 5.8 HUD 样式升级

原来只是纯文字 Label，用户升级为：

```gdscript
# Game.gd _create_hud()
# 用 Panel + StyleBoxFlat 做毛玻璃风格背景容器
var panel = Panel.new()
var style = StyleBoxFlat.new()
style.bg_color = Color(0.1, 0.14, 0.24, 0.75)    # 半透明底色
style.corner_radius_* = 12                        # 圆角
style.shadow_size = 4                             # 阴影
panel.add_theme_stylebox_override("panel", style)

# 用 Emoji 替代纯文字（更直观）
lives_label.text = "❤️ ❤️ ❤️"                   # 生命用红心
# 扣血后更新
for i in range(3):
    heart_str += "❤️ " if i < lives else "🖤 "    # 空心/实心
```

**学习要点**: Godot 原生支持 Emoji 渲染，`StyleBoxFlat` 可以零资源实现圆角/阴影/透明效果。

## 6. 输入处理模式

| 操作 | 方法 | 原因 |
|------|------|------|
| 跳跃 | `_input` + `is_action_pressed` | `_input` 优先于 GUI 传递，避免 HUD Panel `mouse_filter` 拦截 |
| 左右移动 | `_physics_process` + `Input.get_axis()` | 连续状态读取，平滑 |
| 飞镖/近战 | `_input` + `InputEventMouseButton` | 鼠标左键/右键必须在 GUI 层面之前被捕获 |
| 暂停 | `_unhandled_input` + `ui_cancel` | 暂停不应被 HUD 拦截 |
| 菜单确认 | `_process` + `Input.is_action_just_pressed` | 简单轮询 |
| 窗口失焦 | `_notification` + `NOTIFICATION_WM_WINDOW_FOCUS_OUT` | 系统级通知 |

**为什么用 `_input` 而非 `_unhandled_input`**：HUD 的 `Panel` 节点默认 `mouse_filter = MOUSE_FILTER_STOP`，会吞噬鼠标事件。`_input` 在 GUI 处理之前被调用，确保左键飞镖和右键近战不会被 HUD 层拦截。

**防抖/守卫链** (Player._input):
```
is_dead → input_disabled → just_spawned → is_on_floor()
```

**窗口失焦防护**:
```gdscript
func _notification(what):
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        Input.flush_buffered_events()
```

---

## 7. 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `SPEED` | 300.0 | 玩家水平速度 |
| `JUMP_VELOCITY` | -530.0 | 起跳速度 |
| `GRAVITY` | 1100.0 | 重力 |
| 跳跃高度 | ≈128px | `530²/(2×1100)` |
| `invincible_timer` | 1.5s | 受伤无敌时间 |
| `GROUND_Y` | 550 | 地面Y坐标 |
| `level_width` | 动态(每关不同) | 关卡宽度（由 Game.gd 创建 Player 时赋值 `player_node.level_width = level_cfg["width"]`） |
| `blink_timer` | 0.6s | 闪烁周期 |
| 踩头弹跳 | -380 | 踩到敌人后弹起速度 |
| 受伤击退 | -250 + 反向200 | 受伤后弹开 |

---

## 8. 导出与测试

### 语法检查
```powershell
& "$env:LOCALAPPDATA\Godot\godot_console.exe" --headless `
    --path "D:\godot-test-project" --script "Player.gd" --check-only
```

### 打包
```powershell
& "$env:LOCALAPPDATA\Godot\godot_console.exe" --headless `
    --path "D:\godot-test-project" --export-release "Windows Desktop"
```

### 冒烟测试流程
1. 启动游戏 → 按空格开始
2. 左右移动 → 跳跃 → 踩浮空平台（从下方穿过验证）
3. 踩敌人 → 验证踩头判定（+380弹跳）
4. 被敌人撞 → 验证受伤击退 + 闪烁无敌
5. 收集金币 → 验证HUD加分
6. 3条命耗尽 → 验证 Game Over
7. 到达终点 → 验证通关
8. 按空格返回菜单 → 循环
9. **切窗再切回** → 验证方向不卡死

---

## 9. 哥谭大冒险主题改造与持续优化

### 9.1 主题升级概述

用户将原有通用平台跳跃游戏全面改造为 **"🦇 哥谭大冒险：蝙蝠侠出击"**（Gotham Adventure: Batman Strikes）：
- 角色从简单矢量小人 → 蝙蝠侠（披风、蝙蝠头盔、护臂刺刺、战术腰带、蝙蝠胸章）
- 场景从纯色背景 → 哥谭夜景（蝙蝠探照灯、摩天大楼天际线、暖色窗户灯光、明月）
- 菜单 → 蝙蝠侠主题操作说明 + 星光圆角卡片

### 9.2 Coyote Time（土狼时间）

```gdscript
# Player.gd — 允许玩家离开地面后 0.12s 内仍能跳跃
if is_on_floor():
    coyote_timer = 0.12
else:
    coyote_timer -= delta
```

**效果**: 玩家走/跑出平台边缘后，有约 2 帧的缓冲期仍能起跳。消除"明明站在边缘却跳不了"的挫败感。

**踩坑**: `coyote_timer > 0` 和 `jump_buffer_timer > 0` 必须**同时**满足才触发跳跃，否则误跳。

### 9.3 Jump Buffer（跳跃预输入）

```gdscript
# Player.gd — 提前按跳跃键 0.12s 内落地自动起跳
if event.is_action_pressed("ui_accept"):
    jump_buffer_timer = 0.12
    # ...
if jump_buffer_timer > 0 and coyote_timer > 0:
    velocity.y = JUMP_VELOCITY
    coyote_timer = 0.0
    jump_buffer_timer = 0.0
```

**效果**: 在空中提前按跳跃键，落地后自动执行跳跃。消除"感觉按了却没跳"的操作延迟。

**最佳实践**: 两个 timer 在触发跳跃后**立即归零**，防止重复触发。

### 9.4 Variable Jump Height（可变跳跃高度）

```gdscript
# Player.gd — 提前松开跳跃键 → 削减上升速度
if event.is_action_released("ui_accept"):
    if velocity.y < -150.0:
        velocity.y *= 0.45
```

**效果**: 轻按跳跃键跳得矮（短按过小坑），长按跳得高。这是顶级平台跳跃游戏（Super Mario、Celeste）标配手感。

**系数 0.45 的含义**: 短按时速度削减到 45%，跳跃高度降低约 80%（跳跃高度 ∝ v²）。

### 9.5 蝙蝠侠角色矢量绘制

```gdscript
# Player.gd _draw() — 完整蝙蝠侠角色，全部纯代码绘制
# 9 层绘制顺序（从下到上）:
# 1. 飘逸斗篷 (draw_polygon 暗色多边形)
# 2. 腿部 + 暗影战靴
# 3. 躯干战衣 (双层渐变)
# 4. 黄色蝙蝠图标胸章 (圆+剪影多边形)
# 5. 金黄色战术腰带
# 6. 手臂 + 护臂刺刺 (三角突起)
# 7. 蝙蝠头盔 + 尖角耳 (左耳/右耳 三角形)
# 8. 露脸下巴 (矩形 + 嘴唇线条)
# 9. 发光白眼 (多边形，无敌时变红)
```

**绘制技巧**: 所有坐标用 `flip` 系数控制：`left_ear`, `right_ear` 硬编码但用 `flip` 镜像。眼睛位置用 `eye_offset_x = 2.0 * flip`。

### 9.6 粒子爆裂特效

```gdscript
# Game.gd _spawn_particle_burst() — 零资源粒子系统
func _spawn_particle_burst(world_pos: Vector2, color: Color):
    var count = 8
    for i in range(count):
        var p = ColorRect.new()
        p.color = color
        p.size = Vector2(randf_range(3.0, 6.0), randf_range(3.0, 6.0))
        var angle = i * 2.0 * PI / count + randf_range(-0.3, 0.3)
        var speed = randf_range(80.0, 160.0)
        var vel = Vector2(cos(angle), sin(angle)) * speed
        node.add_child(p)
        particles.append([p, vel])
    
    var tween = create_tween().set_parallel(true)
    for item in particles:
        tween.tween_property(p, "position", vel * 0.35, 0.35)
        tween.tween_property(p, "modulate:a", 0.0, 0.35)
    tween.chain().tween_callback(func(): node.queue_free())
```

**调用点**: 吃金币(金色)、踩敌人(红色)、受伤(红色)。

**学习要点**: 用 `PI * 2 / count` 均匀分布在圆周上，再加 `randf_range(-0.3, 0.3)` 小随机偏移获得自然爆炸效果。

### 9.7 暂停菜单增强

暂停菜单添加两个快捷键：
- **R 键**: 重新开始（取消暂停+`_start_game()`）
- **M 键**: 返回主菜单

```gdscript
# Game.gd _unhandled_input
if event.keycode == KEY_R:
    _toggle_pause()
    _start_game()
elif event.keycode == KEY_M:
    _toggle_pause()
    _go_back_menu()
```

### 9.8 TestRunner 截图工具

```gdscript
# TestRunner.gd — 自动化画面截取脚本
extends SceneTree

func _initialize():
    game_instance = Game.new()
    root.add_child(game_instance)
    process_frame.connect(_on_process_frame)

func _on_process_frame():
    if frame_count == 5:
        _capture("screenshot_01_menu.png")    # 第5帧：菜单
        game_instance._start_game()
    elif frame_count == 60:
        _capture("screenshot_02_gameplay.png") # 第60帧：游戏画面
    elif frame_count == 80:
        _capture("screenshot_03_jumping.png")  # 第80帧：跳跃
```

**使用方法**: `godot_console.exe --path . --script scripts/tools/TestRunner.gd`

**注意**: TestRunner 继承 `SceneTree` 而非 `Node2D`，这是一个独立的 headless runner，不能混入主场景。

### 9.9 蝙蝠侠角色动态动画系统（2026-07-29 第二次迭代）

用户将蝙蝠侠从静态角色升级为**全动态动画角色**：

```gdscript
# Player.gd — 动作相位计算
var leg_swing = sin(anim_time * 16.0) * 5.0 if (is_moving and not is_airborne) else 0.0
var breath_y = sin(anim_time * 3.5) * 1.0 if (not is_moving and not is_airborne) else 0.0
var cape_wave = sin(anim_time * 12.0) * 4.0 if is_moving else sin(anim_time * 2.5) * 1.5
```

**三层动作状态**:
| 状态 | 腿摆动 | 呼吸起伏 | 斗篷 |
|------|--------|---------|------|
| **待机** | 无 | `sin*1.0` 微微起伏 | `sin*1.5` 顺垂微动 |
| **奔跑** | `sin*5.0` 快速摆动 | 无 | `sin*4.0` 向后剧烈摆动 |
| **空中** | 固定张开 | 无 | 蝙蝠滑翔翼式张开（最宽）|

**踩坑**: `anim_time` 在 `_physics_process` 中累加，确保动画速度与物理帧同步。如果用 `_process`（渲染帧）会导致物理和动画不同步。

**人物放大**: `scale = Vector2(1.25, 1.25)` 使角色更突出。碰撞体不变（24x36），缩放不影响碰撞。

**坐标调整**: 全部绘制坐标加 `torso_y`/`leg_y`/`head_y` 偏移，鞋底精确压在 `Y = +18` 碰撞底线上，解决嵌入地面问题。

### 9.10 30FPS 动画帧率优化

```gdscript
# Player.gd — 关键优化：按需刷新 + 隔帧刷新
if needs_redraw or ((abs(velocity.x) > 10.0 or not is_on_floor()) and Engine.get_physics_frames() % 2 == 0):
    queue_redraw()
```

**原理**: 物理帧 60FPS，动画每 2 帧重绘一次 → 实际动画 30FPS。减少 50% 的 `_draw()` 调用量。
**效果**: 动画肉眼仍然流畅（30FPS 对 2D 矢量动画已足够），大幅降低 Process CPU 开销。

### 9.11 蝙蝠侠物理反馈动画（Stretch/Squash + 落地烟尘）

```gdscript
# Player.gd _physics_process — 起跳拉伸/落地挤压 + 烟尘颗粒
# 落地挤压（横向拉伸，纵向压扁）
if currently_on_floor and not was_on_floor:
    scale = Vector2(1.42, 1.08)
    _spawn_landing_dust()
    game.add_camera_shake(2.0, 0.08)

# 起跳纵向拉伸
if jump_buffer_timer > 0 and coyote_timer > 0:
    scale = Vector2(1.08, 1.45)

# 每帧平滑回弹到标准体型 1.25x
scale = scale.lerp(Vector2(1.25, 1.25), 14.0 * delta)

func _spawn_landing_dust():
    # 在脚底生成 4-6 个金色小方块，向外扩散 + 淡出
    for i in range(randi_range(4, 6)):
        var p = ColorRect.new()
        p.size = Vector2(3, 3)
        p.color = Color(0.9, 0.75, 0.3, 0.7)
        p.position = position + Vector2(randf_range(-8, 8), 18)
        get_parent().add_child(p)
        # Tween：扩散 20px + 淡出 0.3s → queue_free
```

**效果**: 起跳时 `scale = Vector2(1.08, 1.45)` 纵向拉伸；落地挤压 `Vector2(1.42, 1.08)` 反弹。配合 `lerp` 平滑回位，提供类 Celeste 的物理反馈感。

**落地烟尘粒子**: 使用临时 `ColorRect`（零依赖外部粒子系统），Tween 驱动扩散 + 淡出后自动清理。

### 9.12 Game.gd 视觉调优

| 改动 | 作用 |
|------|------|
| 天空底色 `0.04,0.06,0.12` → `0.12,0.16,0.28` | 调亮背景，让深色蝙蝠侠轮廓更突出 |
| 月亮暖色化 80x80 → 65x65 | 更精致柔和 |
| 新增 5 朵柔和浮云 | 增加天空层次感 |
| 摩天大楼透明度增加 + 窗口固定化 | 降低节点膨胀，避免随机种子不一致 |
| 蝙蝠探照灯透明度 0.12 → 0.08 | 更低调柔和 |

### 9.13 TestRunner 自动化性能测试框架

```gdscript
# TestRunner.gd — 从简单截图工具升级为完整性能测试框架
# 500帧全自动化游玩测试，模拟：
#   - 每 45 帧切换左右移动方向
#   - 每 50 帧触发跳跃（测试平台碰撞）
#   - 自动收集金币、踩怪
```

**性能采样区间**: 80-500 帧（避开加载阶段）

**输出报告**:
```
📊 自动化游玩试玩测试与性能监控分析报告
==========================================
平均帧率 (Avg FPS)
最低帧率 (Min FPS)
卡顿掉帧次数 (Spikes < 50FPS)
平均 Physics 耗时
活跃 SceneTree 节点数
孤立节点泄漏数 (Orphans)
每帧 Draw Calls 次数
```

**重点检测**: 如果 `proc_time > 20ms` 且 `FPS < 50` → 记录 Spikes 卡顿。

**JSON 快照**: 测试完成后保存 `res://screenshots/` 下截图 + `.monitor_snapshot.json` 性能数据。

### 9.14 TestRunner 性能优化 — 延迟截图落盘

```gdscript
# 优化前：每帧截图时直接 save_png → 磁盘 I/O 阻塞主线程
# 优化后：内存缓存 + 统一落盘
var pending_captures = {}  # filename → Image

func _queue_capture(filename: String):
    var img = root.get_texture().get_image()
    pending_captures[filename] = img  # 仅内存操作

func _save_all_pending_captures():
    for filename in pending_captures:
        pending_captures[filename].save_png("res://screenshots/" + filename)
```

**效果**: 避免游戏运行中 save_png 磁盘 I/O 阻塞导致帧率采样偏差，确保性能数据准确。
**采样窗口**: 80→120 帧开始（等 FPS 滑动窗口清空初始化残留平均值）。

---

### 9.15 蝙蝠飞镖系统 (Batarang)

```gdscript
# Batarang.gd — 蝙蝠飞镖纯代码子弹
extends Area2D

const SPEED = 650.0
const MAX_RANGE = 550.0

func _ready():
    add_to_group("batarangs")      # 自检组，防重复击中
    collision_mask = 1             # 检测 Layer 1 敌人/地面
    monitoring = true
    monitorable = false            # 不被别的物体检测到
```

**行为逻辑**:
- 朝鼠标方向发射，通过 `facing_right` 和鼠标位置比对决定方向
- `_physics_process` 中每帧位移 `SPEED * delta`，累计 `distance_traveled`
- 超过 `MAX_RANGE` 自动销毁（`_destroy_with_effect(false)`）
- `area_entered` → 检测 `enemies` 组 → 调用 `hit_by_batarang()`
- `body_entered` → 检测 `StaticBody2D` 墙壁 → `_destroy_with_effect(true)`

**销毁流程** (`_destroy_with_effect(hit_something)`):
```gdscript
func _destroy_with_effect(hit_something: bool):
    set_physics_process(false)
    monitoring = false          # 立即停止碰撞检测
    if hit_something:
        game._spawn_particle_burst(position, Color(1.0, 0.85, 0.2))
    # Tween 缩放淡出 → queue_free
```

**碰撞体**: `RectangleShape2D(20×12)`，自旋时视觉旋转不影响碰撞体。

### 9.16 视差滚屏背景系统 (Parallax)

`Game.gd._create_world()` 中构建 4 层背景：

| 层 | 内容 | 视差比 | 元素 |
|----|------|--------|------|
| Layer 0 | 深空底色 + 月亮 | 固定 | 65px 暖色像素月亮，天空底色 `0.12,0.16,0.28` |
| Layer 1 | 远景摩天大楼 | `(0.08, 0.02)` | 1600px 循环复用的像素大楼纹理，带固定窗光 |
| Layer 2 | 中景大楼 + 浮云 | `(0.22, 0.05)` | 像素大楼 + 5 朵柔和半透云层加入 `drifting_clouds` 组 |
| Layer 3 | 近景管道护栏 | `(0.55, 0.10)` | 像素管道纹理，1600px 循环复用 |

**探照灯 (BatSignal)**: 在 Layer 0 上方绘制，`_process` 中 `sweep_angle = sin(time * 0.8)` 摇摆，光束顶部与蝙蝠黑影投影重合。

**实现细节**:
- 使用 `ParallaxBackground` + `ParallaxLayer` 节点
- 每个 `ParallaxLayer` 内的 `Sprite2D` 设置 `texture_repeat = true`
- 云朵通过 `drifting_clouds` 组在 `_process` 中缓慢右移

### 9.17 关卡配置系统 (LEVEL_CONFIGS)

`Game.gd` 定义 `LEVEL_CONFIGS` 字典，每个关卡配置包含：

```gdscript
var LEVEL_CONFIGS = {
    1: { "width": 1632, "coins": [...], "ground_enemies": [...], 
        "fly_enemies": [...], "platforms": [...], "moving_platforms": [...],
        "hazards": [...], "boss": false },
    5: { "width": 5000, "coins": [...], "ground_enemies": [...], 
        "fly_enemies": [...], "platforms": [...], "moving_platforms": [...],
        "hazards": [...], "boss": true },  # 第五关有 Boss
}
```

**构建流程** (`_create_world()`):
1. 读取 `level_cfg = LEVEL_CONFIGS[current_level]`
2. 赋值 `player_node.level_width = level_cfg["width"]`
3. 按顺序生成：地面 → 背景(parallax) → 平台(StaticBody2D) → 移动平台(AnimatableBody2D) → 地刺 → 金币 → 地面敌人 → 飞行敌人 → 终点传送门
4. 如果 `boss = true`，在关卡末尾生成 Boss

---

## 10. 已知局限 & 可优化方向

- **Enemy 是 Area2D**：用 `position.x += SPEED * direction * delta` 而非 `move_and_slide()`，这意味着敌人不受重力/碰撞影响。目前敌人固定在地面Y巡逻，但如果要放在平台上，需要重构为 CharacterBody2D
- **掉落死亡**：防物理Bug的保守方案（`y > GROUND_Y+100` 触发 `_on_player_hit`），没有专门的"掉坑"关卡设计
- **纯代码构建**：所有节点动态创建，没有 .tscn 场景，便于 AI 修改但缺少可视化编辑
- **`die()` 方法未使用**：Player 有 `die()` 方法但当前逻辑不触发死亡动画（命数耗尽直接弹出 Game Over 界面）
- **无音效**：纯视觉反馈（无背景音乐/SFX），但有粒子爆裂特效和落地烟尘颗粒

---

## 11. 纯代码像素风改造记录

### 11.1 改造策略

采用**混合策略 C→B 渐进式**：从背景开始逐步替换，不改变碰撞体。

| Phase | 内容 | 状态 |
|-------|------|------|
| 0 | `pixel_config.gd` + `pixel_lib.gd` 基础设施 | ✅ 完成 |
| 1 | 背景像素化（月亮/大楼/云/管道/草地） | ✅ 完成 |
| 2 | 道具+UI（Coin/Hazard/HUD 图标） | ✅ 完成 |
| 3 | 角色像素化（Player） | ❌ 待做 |
| 4 | 敌人像素化（Enemy/FlyEnemy/Boss） | ✅ 完成 (Boss) / ❌ 待做 (Enemy/FlyEnemy) |
| 5 | 特效+菜单抛光 | ❌ 待做 |

### 11.2 关键文件

| 文件 | 职责 |
|------|------|
| `pixel_config.gd` | 全局视口 NEAREST 滤波配置 |
| `pixel_lib.gd` | 像素图工具库（`create_texture` / `create_anim_textures` / `setup_animated_sprite` / `fill_circle` / `fill_rect`）|
| `pixel_background.gd` | 像素背景元素生成器（月亮/大楼/云/草地/管道）|
| `BossPixel.gd` | Boss 像素渲染器（80×60 canvas、center-relative、帧缓存、调色板常量、各状态专属表情）|
| `bg_single.gd` | 单张 bg.jpg 视差背景（替换4层程序化生成）|

### 11.3 PixelConfig API 注意事项

```gdscript
# ✅ 正确：直接在 Viewport 上设（Godot 4.7）
viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

# ❌ 错误：Texture2D 资源上没有 texture_filter 属性
# tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 运行时报错
```

`texture_filter` 是 `CanvasItem`（节点）的属性，不是 `Texture2D`（资源）的属性。全局配置由 `PixelConfig.apply(viewport)` 在 `Game.gd._ready()` 中一次性设置。

### 11.4 PixelLib 使用模式

```gdscript
# 创建单帧纹理
var tex = PixelLib.create_texture(16, 16, pixels_data, palette_dict)

# 批量生成动画帧
var texs = PixelLib.create_anim_textures(frames_data, palette, 12, 18)

# 填充 AnimatedSprite2D
PixelLib.setup_animated_sprite(sprite_node, animations_dict, palette)
```

`palette` 字典格式：`{"R": Color(1,0,0), ".": Color.TRANSPARENT, ...}`
像素数据格式：每字符串一行，字符映射调色板 key。

### 11.5 PixelBackground 生成器

所有背景纹理用 `Image.create()` + 逐像素 `set_pixel()` 或 `PixelLib.fill_rect()` 生成：

- `create_pixel_moon(size)`: 块状像素月亮 + 陨石坑
- `create_building_texture(w, h, base_color, window_color, seed)`: 像素大楼（窗格+天线）
- `create_cloud_texture(w, h)`: 半透像素云朵（多圆叠合）
- `create_grass_texture(w, h)`: 像素草地渐变
- `create_pipe_texture()`: 像素管道护栏

### 11.6 背景替换留下的死代码

`Game.gd._process()` 中 `flicker_windows` 组循环已清理（窗光现已嵌入大楼纹理）。

### 11.7 Phase 2 — 道具+UI 像素化

#### Coin.gd 改造

| 改前 | 改后 |
|------|------|
| `_draw()` 4层椭圆叠加 | `Sprite2D` 子节点，`PixelLib.create_texture(8, 8, ...)` |
| 预计算 `UNIT_CIRCLE` + `STEPS` | 8 帧像素旋转动画数组 |
| 每帧 `queue_redraw()` | `sprite.texture = coin_textures[int(anim_time*2) % 8]` |
| `scale` 无 | `sprite.scale = Vector2(4, 4)`（8→32px 匹配碰撞体 r=16）|

**保留**: 碰撞(CircleShape2D r=16)、浮动(bobbing)、双重检测(body_entered + get_overlapping_bodies)、收集动画(tween + scale 1.5)。

#### Hazard.gd 改造

| 改前 | 改后 |
|------|------|
| `_draw()` 3个三角尖刺 | `Sprite2D` 子节点，20×10 像素纹理 |
| `draw_polygon` ×3 + `draw_line` | `PixelLib.create_texture(20, 10, ...)` |
| 无缩放 | `sprite.scale = Vector2(2, 2)`（20×10→40×20 对齐碰撞体 40×16）|
| 每帧 queue_redraw | 一次性生成，无需重绘 |

**保留**: 碰撞体(RectangleShape2D 40×16, 偏移 -8)、body_entered 伤害逻辑。

#### HUD 图标改造

新增 `_create_pixel_icon()` 静态函数（替代 `_create_vector_icon`），返回 `TextureRect`：

- 6 种图标全部用 12×12 像素数据 + `PixelLib.create_texture()` 生成
- `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED` 自动缩放
- `texture_filter = TEXTURE_FILTER_NEAREST` 保持像素风
- 调用处全部替换：菜单蝙蝠(42x42)、最高分皇冠(36x36)、HUD金币(24x24)、生命心形(24x24)

#### Phase 2 踩坑

- ❌ `TextureRect.EXPAND_KEEP_ASPECT_CENTERED` 在 Godot 4.7 中不存在 → 改为 `stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED`
- ❌ `tex.texture_filter` 不能设置在 Texture2D 资源上 → 改在 Sprite2D/TextureRect 节点上设置

### 10.17 八脚血盆大口蜘蛛小丑大 Boss (Spider-Joker Monster) 重构规范

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| 小丑 Boss 原滑行移动平淡乏味 | Boss 像冰块一样在平地上滑动，缺乏威慑感 | 仅仅对 `position.x` 进行线性平移，没有肢体爬行与攻击姿态变幻 | 重构为 **Spider-Joker 恐怖蜘蛛怪**：程序化绘制 8 条双关节蛛腿 (大腿+小腿+毒爪)，实现真实的 8 脚交替爬行步态 (`SKITTER`)。 |
| 沙漏标记 `draw_polygon` 三角剖分报错 | 控制台报 `ERROR: Invalid polygon data, triangulation failed` | 将沙漏 shape 定义为 `[-6,2, 6,2, 0,10, -6,18, 6,18, 0,10]` 的自交叉多边形 | 拆分为两个独立的凸三角形顶点数组 (`top_tri` + `bot_tri`) 独立调用 `draw_polygon` 绘制，彻底杜绝自交报错！ |
| Boss 攻击模式单一 | 玩家容易避开单一扑克弹幕 | 缺乏空间压制与动效威慑 | 引入 3 状态 combat AI：`SKITTER` (8脚急速扒行追击) → `CEILING_HANG` (天花板蛛丝倒挂，向下扇形发射 3 连扑克弹与蛛网) → `POUNCE` (张开血盆大口与锯齿獠牙，抛物线弧线飞扑咬杀)！ |

### 11.8 Phase 4 — 敌人像素化

| 文件 | 像素尺寸 | Scale | 说明 |
|------|---------|-------|------|
| Enemy.gd | 14×12 蘑菇怪 | 2.0 | 像素颜料 + Sprite2D，去掉 `_draw()` |
| FlyEnemy.gd | 16×16 小丑无人机 | 1.0 | 4帧螺旋桨旋转动画，去掉 `_draw()` |
| Boss.gd | 16×20 小丑 Joker | 2.2 | 像素 Sprite2D，保留矢量 `_draw()` 血条+气场 |

**测试结果**: 800 帧全自动游玩测试通过，0 SCRIPT ERROR，平均 FPS 58.7，最低 FPS 52。

**踩坑记录**:
- ❌ `PixelLib.create_texture` 参数 `pixels: Array[String]` 类型签名 → 调用方传入非泛型数组时报 `Invalid type`
  - 修复：改为 `pixels: Array`（去掉泛型约束），GDScript 运行时类型系统对泛型数组约束过严
- ❌ `Array[Texture2D]` 类型数组在跨帧调用中偶发越界 → 改为普通数组 `= []`
- ❌ Tween callback 中 `hide()` 在节点已释放时报 `Nonexistent function 'hide' in base 'Nil'`
  - 根因：场景重启后旧节点 Tween 回调执行时节点已被 `queue_free`
  - 修复：所有 `tween_callback` 统一加 `if is_instance_valid(self):` 守卫

### 11.8 Phase 4 — Boss 像素化 (BossPixel.gd)

#### 文件结构

| 文件 | 说明 |
|------|------|
| `scripts/enemies/BossPixel.gd` | Boss 像素渲染器 (80×60 canvas, 帧缓存, 调色板常量) |
| `scripts/enemies/Boss.gd` | Boss 主控 (整合 pixel_mode 切换、Sprite2D 子节点、预生成首帧) |
| `scripts/lib/pixel_lib.gd` | 像素图工具库 (`fill_circle` / `fill_rect`) |

#### BossPixel 架构

- **Canvas**: 80×60 像素, center-relative 坐标系 (CX=40, CY=30)
- **帧缓存**: 最多 80 帧, key=`{state}_{jaw_q}_{t_q}{E}{S}`, 相位 16 档
- **调色板**: 16 个具名颜色常量 (`C_ABDO`, `C_FACE`, `C_EYE` 等)
- **状态视觉**:
  | 状态 | 眼睛 | 嘴 | 腿 | 特效 |
  |------|------|-----|-----|------|
  | DORMANT | 闭合灰线 | 闭合小口 | 蜷缩 | 蛛丝 |
  | SKITTER | 正常圆眼+瞳孔 | 张嘴+牙 | 急速扒行 | 暗紫光环 |
  | POUNCE/INITIAL/SKY | 正常圆眼+瞳孔 | 张嘴+牙+獠牙 | 收缩后蹬 | 暗紫光环 |
  | CEILING_HANG | 正常圆眼+瞳孔 | 张嘴+牙 | 朝天伸展 | 蛛丝 |
  | SKY_DROP_CRASH | 正常圆眼+瞳孔 | 张嘴+牙 | 收缩后蹬 | 红色瞄准圈 |
  | STUNNED | X 眼 (黄色) | 张嘴+口水 | 瘫软散开 | 金星旋转 |
  | COUNTER_SWIPE | 正常圆眼+瞳孔 | 张嘴+牙 | 前伸 | 红色闪电 |
  | enraged | 红色 (C_EYE_E) | 正常+獠牙 | C_LEG_E 颜色 | 粉色光环 |

#### 绘制流水线

```
_render()→
  _shadow()      地面投影
  _abdo_border() 腹部边框
  _abdo()        腹部填充+菱形鳞纹+高光
  _hourglass()   红色沙漏+高光条纹
  _legs()        ×8腿 (hip→knee→claw)
  _aura()        发光光环
  _face()        脸基色→腮红→眼睛(3种模式)→斑点→嘴→轮廓→绿发
  _stars/_bolt/_reticle 状态特效
```

#### Boss.gd pixel_mode 集成

- `pixel_mode = true` 默认开启
- F1 键切换 `pixel_mode`，HUD 文字提示
- `_ready()` 预生成休眠帧 → Sprite2D.texture
- `_physics_process()` 每帧组装 `state_info` 字典 → `_boss_pixel.generate(state_info)`
- `_draw()` 中 `if pixel_mode: return` 跳过矢量绘制
- Sprite 缩放 1.5x (80×60 → ~120×90 显示尺寸)
- `centered=false`, position=(-BPW/2, -BPH/2) 对准节点原点

### 11.9 单张 bg.jpg 视差背景 (替换4层程序化)

#### 背景

原先使用 `GothamBgLayers` 4 层程序化生成纹理 (夜空/远景/中景/近景) + ParallaxBackground。
现改为 `bg_single.gd` 加载 `assets/bg.jpg`（1168×784 AI 生成哥谭夜景）作为单张视差背景。

#### 变更

- 新建 `scripts/lib/bg_single.gd` — 单层 ParallaxBackground, motion_scale (0.03, 0.01)
- `Game.gd` `_create_world()`: 4层 ParallaxBackground → `BgSingle.create(vp.x, vp.y)`
- `assets/bg.jpg` 复制自 `D:/0708ribao/images/bg.jpg`
- 等比缩放填满 1152×648 视口 (crop 顶部/底部)

### 11.10 视觉验收流程 — Gemini 3.5 Flash Lite 截图分析

#### 目的
每次像素化/视觉相关修改后，不能只依赖代码走查。必须截取游戏实际渲染画面，交给 Gemini 3.5 Flash Lite 模型分析，确认视觉效果符合预期，才能标记完成。

#### 流程

```
修改代码 → TestRunner 自动试玩(800帧) → 截取关键画面
  → 调用 Gemini 3.5 Flash Lite 分析: 
     - Boss 各状态表情/姿势是否正确
     - 背景渲染完整性
     - 色彩/像素风格一致性
     - 动画流畅度
  → Gemini 给出 pass/fail + 具体问题
  → 若 fail → 根据反馈修改 → 重新截图验收
  → 若 pass → 标记完成
```

#### 关键检查点

| 检查项 | 说明 |
|--------|------|
| Boss DORMANT | 闭合眼、蜷缩腿、蛛丝、无光环 |
| Boss STUNNED | X 眼、张嘴口水、瘫腿、金星、黄光环 |
| Boss enraged | 红眼、红腿、粉光环、腹部变红 |
| Boss SKITTER | 正常眼、8腿扒行动画、紫光环 |
| Boss COUNTER_SWIPE | 红色闪电特效 |
| bg.jpg 背景 | 完整显示、无拉伸变形、视差滚动正常 |
| 像素风格一致性 | 全部元素用 NEAREST 滤波、无模糊纹理 |

#### 调用方式

Gemini 3.5 Flash Lite 通过 `task()` 调用 (category=`multimodal-looker` 或直接 Gemini API)：

```
发送图片 + 文本 prompt: 
  "分析这张游戏截图：1) Boss 的表情和姿势是否符合[当前状态]？ 
   2) 背景 bg.jpg 是否完整显示？3) 整体的像素风格是否一致？
   列出所有视觉问题和改进建议。"
```

#### 触发时机

- 每次 BossPixel.gd 或 bg_single.gd 等视觉相关文件被修改后
- TestRunner 试玩通过后、标记 Task 完成前
- 不得跳过此步骤直接标记完成

---

## 12. 踩坑与最佳实践汇总

本项目的所有踩坑记录分类汇总，方便快速查找原因和最佳方案。

### 12.1 碰撞系统

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| 玩家穿过单向平台 | 从上方站不住 | `collision_mask` 没设 `3`（缺层2） | `collision_mask = 3; platform_floor_layers = 2` |
| 碰撞体在物理回调中禁用报错 | `set_disabled` 运行时改 PhysicsServer 状态 | 物理回调中直接操作碰撞体 | 改用 `set_deferred("disabled", true)` |
| 浮动金币碰撞体不同步 | 金币浮动穿模，玩家碰不到 | 用 `_process`（渲染帧）驱动位置，PhysicsServer 没跟上 | 用 `_physics_process` 驱动，物理帧同步 |
| 踩头判定不准 | 有时踩到却受伤 | 只用 `body_entered` 信号不够细 | 双条件：`stomp_from_fall`（下落中）+ `stomp_from_above`（玩家 Y < 敌人 Y） |

### 12.2 Camera 镜头

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| Camera 内置平滑 snap | 瞬移/抖动 | 开了 `position_smoothing_enabled` 又手动 `position =` | 关掉内置平滑，用 `lerp()` 手动实现 |
| 关平滑→瞬移→开平滑 | 画面卡顿 | 多余的三步 hack | 仅用 `lerp(a, b, 12*delta)` 自然逼近 |
| 镜头不限制边界 | 看到关卡外黑色区域 | 没设 `limit_*` | `limit_left/right/top/bottom` 限制镜头范围 |

### 12.3 绘制

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| `draw_polygon` 渲染白屏 | 金币/形状显示白色方块 | 传入负的半径 → winding order flip | `rx = max(abs(rx), 1.0); ry = max(abs(ry), 1.0)` — 始终确保正半径 |
| 绘制闪烁 | `_draw()` 内容一闪一闪 | `queue_redraw()` 调用太频繁 | 设置 `needs_redraw` 标志：只有 alpha（无敌）/ 朝向变了才重绘 |
| 朝向翻转不对 | 绘制内容镜像反了 | 仅翻转 `scale.x` 导致绘制坐标也跟着反 | 绘制代码用 `facing_right` 控制坐标符号：`if !facing_right: draw_circle(Vector2(-x,y))` |

### 12.4 Tween 动画

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| Tween 无限循环泄漏 | 内存泄漏 / 卡顿 | 用 `infinite` + `set_loops()` 做闪烁 | 用 `_process` 手动 `blink_timer` 累加取整模2 |
| 飘字残留在场景中 | Label 越来越多 | Tween 回调未清理节点 | `chain().tween_callback(func(): label.queue_free())` 自动清理 |
| 动画结束后抖动 | 飘字淡出后仍然有残留 | `set_parallel(true)` 的 Tween 被提前释放 | `create_tween()` 而非 `Tween.new()`，让 Tween 自管理生命周期 |

### 12.5 输入处理

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| 窗口失焦后方向卡死 | 切窗再切回，角色自动持续移动 | 失去焦点时键盘事件丢失，但 Input 状态未复位 | `_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)`: `Input.flush_buffered_events()` |
| 跳跃触发两次 | 按一次跳两下 | `_input` + `_unhandled_input` 同时接到事件 | 守卫链：`is_dead → input_disabled → just_spawned → is_on_floor()` |
| 暂停后跳跃残留 | 取消暂停立刻跳起 | 暂停期间 Space 被缓存 | 暂停/恢复时 `Input.flush_buffered_events()` |

### 12.6 状态管理

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| 菜单重建后事件泄漏 | 旧节点信号仍触发 | `queue_free()` 后旧节点上的 signal connect 残留 | 重建前 `queue_free()` 完全清理，用 is_inside_tree() 守卫 |
| 状态守卫混乱 | 同时触发胜利和 Game Over | 没有排他状态判断 | 在 `_process` 开头用 `match state:` 分支，每个状态互斥 |
| pause 后 tween 也停了 | 暂停时飘字/闪烁也卡住 | `get_tree().paused` 默认暂停所有 `SceneTreeTimer` 和 Tween | Tween 设置 `set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` 或暂停仅冻结物理 |

### 12.7 持久化

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| `ConfigFile` 路径写死 | 用户电脑没有该路径 → 读文件失败 | 用了绝对路径 | 用 `user://` 前缀自动映射到平台特定目录 |
| 最高分在不同机器上不共享 | 换电脑分数丢了 | 这不是 Bug，是设计预期 | `user://high_score.cfg` 存本地即可，无需云同步 |

### 12.8 通用 Godot 实践

| 最佳实践 | 说明 |
|---------|------|
| `@onready` 缓存节点引用 | `@onready var player = $Player` 避免每帧 `get_node()` |
| `set_deferred` 修改碰撞体 | 物理回调期间用延迟设置避免状态冲突 |
| `is_inside_tree()` 守卫 | 信号回调第一行检查，防止节点已释放后意外执行 |
| `create_tween()` 而非 `Tween.new()` | 自动管理生命周期，被创建节点的父节点释放时自动清理 |
| `Input.flush_buffered_events()` | 窗口失焦、暂停恢复、状态切换时调用，防止残留输入 |
| `_physics_process` 驱动物理相关位置 | 非渲染帧驱动的 `position` 变化才能被 PhysicsServer 感知 |
| 状态机用 `enum + match` | 比字符串比较更类型安全，性能更好 |

### 12.9 TestRunner.gd 与自动化游玩压测踩坑汇总

TestRunner 包含 **5 个白闪/幽灵帧诊断模块**，在帧循环中并行检测：

| 模块 | 检测内容 | 触发条件 |
|------|---------|----------|
| 1. Delta Spike | Process 耗时 > 20ms & FPS < 50 | 帧率卡顿 |
| 2. Camera 镜头跳变 | Camera 位置 delta > 2.0  | 背景撕裂风险 |
| 3. 幽灵帧 (Ghost Frame) | 活跃节点数骤减 > 15 （`queue_free` 前残留绘制） | Tween 回调中节点已释放 |
| 4. 多边形退化 (Winding Order) | 记录每帧 `draw_polygon` 调用次数 | 频繁重绘消耗 CPU |
| 5. 像素采样白闪检测 | 中心+四角 5 点像素采样，亮度 > 0.95 触发白闪事件记录 | GPU 渲染异常 |

**已知踩坑**:
| 问题 / 踩坑点 | 现象 | 原因 | 最佳解决方案 |
|------|------|------|---------|
| CLI 快照截图全黑/返回 null | `root.get_texture().get_image()` 截取为黑屏 | 命令行加了 `--headless` 参数使用 dummy 渲染器，不输出视口纹理 | 移除 `--headless`，改用 `--rendering-driver opengl3` 命令行驱动跑测试 |
| `get_process_step()` 语法解析报错 | `Static function "get_process_step()" not found` | 误写成 `Engine.get_process_step()` | `get_process_step()` 是 `SceneTree` 的成员方法，直接调用 `get_process_step()` |
| VSYNC 垂直同步干扰掉帧采样 | 帧率 60FPS 但 `TIME_PROCESS` 报 28ms-34ms Spike | `Performance.TIME_PROCESS` 包含了 GPU 垂直同步等待时间 | 结合 `Engine.get_frames_per_second() < 50` 以及 `Performance.TIME_PHYSICS_PROCESS` 综合判定卡顿 |
| 游玩模拟被守卫拦截 | 按空格没响应，无法开始游戏 | Player 刚生成时有 `just_spawned` 标志或处于 `input_disabled` 状态 | 试玩脚手架在 Frame 5 显式调用 `game_instance._start_game()`，并重置模拟坐标 |
| `_draw()` 堆内存大量分配推高 Process 耗时 | Process 耗时升至 22ms+ 导致卡顿 | 每帧 `_draw()` 中实例化多个 `PackedVector2Array` 数组 | 使用 `static func _static_init()` 静态预分配单位圆数组；按 `Engine.get_physics_frames() % 2 == 0` 间隔刷新 |
| 背景 ColorRect 节点膨胀推高 SceneTree 开销 | 节点数从 65 暴涨至 150+ | 在 `_create_world()` 中用循环大量生成小 Window `ColorRect` 节点 | 限制窗口灯光节点数量，或采用单个 Node2D `_draw()` 统一绘制背景 |
| EXE 打包提示 `game.tmp` 无法重命名失败 | `--export-release` 导出提示失败 | `build/game.exe` 已经在后台运行中，文件被 Windows 系统锁住 | 在打包前执行 `Stop-Process -Name "game" -Force -ErrorAction SilentlyContinue` 杀死残留进程 |

### 12.10 偶发白闪防范与 2D 多边形绘制规范

| 风险点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| `draw_polygon` 镜像翻转 (`flip = -1`) | 随机/偶发 1 帧屏幕白闪或暗屏 | `flip = -1` 使多边形顶点 Winding Order 变成 Clockwise 顺时针，在某些 GPU 驱动 (如 RTX 2080S 566.36) 上可能抛出退化三角形/白像素 | 在 `flip = -1` 时对顶点数组调用 `.reverse()` 显式保持 Counter-Clockwise (逆时针)，确保多边形有符号面积 > 0 |
| `queue_free()` 前的幽灵帧绘制 | 节点被销毁的前 1 帧突然闪现 | 节点 `queue_free()` 是延迟到帧末清理，在动画结束该帧可能比 Render Pipeline 先/后生效导致以 1.0 Alpha 重绘 | 在所有 Tween 的 `tween_callback` 中，统一采用 `func(): if is_instance_valid(self): hide(); queue_free()` 先验证再隐藏销毁 |
| Camera `lerp` 镜头步幅突变 | 画面边缘瞬间白闪 (露底) | 帧率掉帧导致 `delta` 突大，`12.0 * delta` 溢出导致 Camera 坐标跳变，背景 `ColorRect` 与视口脱节露出默认 Clear Color | 在 Camera 移动插值中使用 `clamp(12.0 * delta, 0.0, 1.0)` 限制单帧最大跟随步幅 |
| 护臂刺刺/局部多边形坐标算错 | 转向时刺刺穿透身体拉成大狭长线段 | 护臂刺刺误用了 `Vector2(-15 * flip)` 导致 left_arm (x=-12) 刺向右边 (+15)，跨越全身 | 左右两侧手臂分别独立计算固定绘制坐标，不直接对局部 X 坐标做盲目乘 `flip` 运算 |

### 12.11 单向平台与多关卡边界陷阱

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| 单向平台水平侧面卡死 | 玩家跃至平台同高度时在水平方向被平台左/右侧边缘阻挡卡住 | `platform_floor_layers = 2` 仅影响竖直下落 Floor 判定。因玩家 `collision_mask = 3`，在水平方向 `move_and_slide()` 仍与图层2产生硬碰撞 | 图层 2 的单向平台（StaticBody2D）的 `CollisionShape2D` 必须显式设置 `col.one_way_collision = true`，使侧面与下方均可流畅穿透 |
| 跨关长地图横向坐标卡死 | 进入 Level 2 (2400px) 或 Level 5 (5000px) 后，玩家在 x=1620.0 处被隐形墙锁死无法前进 | `Player.gd` 中硬编码了 `const LEVEL_WIDTH = 1632`，并在 `_physics_process` 中使用了 `clamp(position.x, 12, LEVEL_WIDTH - 12)` | 将 `LEVEL_WIDTH` 重构为动态变量 `var level_width`，并在 `Game.gd` 创建玩家时实时赋值 `player_node.level_width = level_cfg["width"]` |
| 地面陷阱区域死胡同 | 玩家不小心掉落到地面后，无论怎么按跳跃都无法跳回高处平台 | 蝙蝠侠极限起跳高度为 `127.7px` (`v=-530, g=1100`)。若地面上方主平台 `y <= 400`（距地面 140px+），落入地面的玩家将陷入物理不可逆的死胡同 | 地面所有地刺/陷阱空隙旁均需布置 `y = 465`（距地面仅 85px）的登高梯低平台，保障掉落后 100% 可跳跃攀爬复活 |

### 12.12 关卡难度扩展与敌人密度平衡规范

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| 关卡拉长后怪物密度下降 (密度稀释) | 越往后关卡越空旷，感觉难度不升反降 | 扩展地图长度 (如 1632px $\rightarrow$ 5000px) 时，怪物生成数量未按比例同步增加，导致密度从 3.75个/1000px 降至 3.20个/1000px | 制定**每千像素密度递增指标**：Level 1~2 控制在 3.0~3.8 个/1000px，Level 3~5 依次提升至 5.0、5.0、4.8 个/1000px |
| 关卡末段无怪空白盲区 | 接近终点线数百像素内怪物完全消失 | 手动配置敌人生成点数组时，最大 `x` 坐标止步于 `4250px`，距离 `5000px` 终点残留了 750px 的空旷地带 | 敌人生成 `x` 坐标必须覆盖至 `LEVEL_WIDTH - 350px` 的关卡前沿区域，禁止留下 >300px 的无怪空白区 |

### 12.13 鼠标点击事件拦截与输入管道规范

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| GUI Panel 吸收鼠标左键导致飞镖无法发射 | 在游戏画面中点击鼠标左键无任何响应，飞镖无法发射 | 视口上方顶层 HUD 的 `Panel` 或 `Control` 节点默认 `mouse_filter = MOUSE_FILTER_STOP`，吞噬了所有鼠标点击事件，导致 `Player._unhandled_input()` 永远无法收到左键事件 | 1. 在 HUD `Panel` 上显式设置 `panel.mouse_filter = Control.MOUSE_FILTER_IGNORE`；<br>2. 玩家节点攻击响应统一改用 `_input(event)`（优先于 GUI 传递层级处理）。 |
| 鼠标左键发射方向与朝向脱节 | 点击左侧画面时飞镖依然朝右射出 | 发射飞镖时仅读取了 `facing_right` 变量，未根据鼠标在全局场景中的 `get_global_mouse_position()` 坐标实时判定 | 在 `shoot_batarang()` 中比对 `mouse_pos.x` 与 `global_position.x`，自动将 `facing_right` 转向鼠标所在方位，实现指哪打哪。 |

### 12.14 AAA 主菜单解耦与 Bat-Signal 探照灯背景踩坑汇总

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| 主菜单面板堆叠大段文本导致拥挤 | 菜单画面像说明书而非游戏主界面 | 将操作说明框直接放进了 `MenuPanel` 中，占据了 40% 的界面空间 | 彻底解耦主菜单与说明文字：主面板仅保留垂直一字排开的 5 大功能按键；操作指南改由点击 `⚙️ 操作指南` 按钮后调用 `_show_controls_dialog()` 弹出干净独立弹窗。 |
| 探照灯摇摆光束与云层徽标不同步 | 光束往左摇，但云层上的蝙蝠黑影在右边 | 探照灯光束与云层 Bat Silhouette 顶点独立计算了不同的 `sweep_angle` 偏移量 | 在 `BatSignalBeam` 的 `_draw()` 回调中统一使用相同的 `top_center = Vector2(base_x + sin(sweep_angle) * range, top_y)` 坐标基准，确保光束顶端与云层 Projection Emblem 100% 紧密重合。 |
| `--export-release` 导出 `game.tmp` 无法重命名失败 | 执行导出命令提示 Error Code 1 失败 | 导出的目标可执行文件 `build/game.exe` 正在 Windows 系统后台中运行，句柄被系统进程占用锁住 | 导出前必须执行 `Stop-Process -Name "game" -Force -ErrorAction SilentlyContinue` 杀死残留游戏进程后再执行导出命令。 |

### 12.15 本次修复的三个 Bug

| 问题 | 现象 | 根因 | 解决方案 |
|------|------|------|---------|
| 飞行敌人太小 | FlyEnemy 16×16 像素显示太小 | 像素化后未设置 `sprite.scale` | 加 `sprite.scale = Vector2(2.0, 2.0)` |
| 飞行敌人子弹无伤害 | 击中玩家无反应 | `FlyEnemyBullet.gd` 缺少 `CollisionShape2D`，Area2D 无法检测 body_entered 信号 | 添加 `CircleShape2D(radius=6)` 碰撞体 |
| 移动平台跳上去掉下来 | 水平移动的平台玩家无法站在上面 | `col.one_way_collision = true` 与 Player 的 `platform_floor_layers = 2` 双重复盖，`AnimatableBody2D` 动态运动中互相冲突 | 去掉 MovingPlatform 的 `one_way_collision`，只依赖 Player 侧的 `platform_floor_layers = 2`（CharacterBody2D 专属单向平台机制） |

### 12.16 移动平台 AnimatableBody2D 物理同步与飞行怪远程子弹规范

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| `StaticBody2D` 移动平台导致玩家穿模坠落或无法跟随 | 左右平移平台玩家无法跟随；上下升降平台踏上去瞬间穿透单向面坠落 | `StaticBody2D` 仅用于固定建筑，不计算平台运动速度 (`get_platform_velocity`)，无法与 `CharacterBody2D` 物理同步 | 移动平台必须继承 **`extends AnimatableBody2D`**，并在 `_ready()` 中显式开启 **`sync_to_physics = true`**！`CharacterBody2D` 会自动读取平移速度并平滑跟随。 |
| 单向平台水平侧面卡死 | 玩家跃至平台同高度时在水平方向被平台左/右侧边缘阻挡卡住 | `col.one_way_collision = true` 仅阻止从下方穿过，水平方向仍然硬碰撞 | 必须设置 `col.one_way_collision_margin = 4.0` 给 4px 容差，且使用增量位移而非直接赋值 position 让 AnimatableBody2D 正确计算速度矢量 |
| 平台高速移动时玩家甩落 | 平台快速往返时玩家跟不上被抛下 | `one_way_collision_margin` 容差不够 | 设置 `col.one_way_collision_margin = 4.0`（MovingPlatform.gd:25） |
| 飞行怪子弹与 Coin 旋转索引越界 | 报错 `Out of bounds get index '3'` | GDScript 中负数浮点转 int 求模 (`-1 % 8`) 会返回负数索引 | 在获取数组纹理索引时，统一使用 **`posmod(int_val, array.size())`**，安全防范负数与越界风险！ |

---

### 12.17 近战斩击动效非线性优化 (2026-07-29)

**背景**: 原来的近战斩击动画采用线性进度 (`slash_progress = 1.0 - timer/duration`)，挥砍轨迹匀速匀速缺乏力道感。

**优化内容**:

| 方面 | 改前 | 改后 |
|------|------|------|
| **动画曲线** | 线性 `0→1` | **Ease-out cubic** `1.0 - pow(1.0 - raw_t, 2.8)` — 先快后慢，模拟真实蓄力释放 |
| **残影** | 单层月牙 | **三重残影拖尾** (ghost_layer 0/1/2)，每层 0.05s 延时叠加，产生速度加成的动感 |
| **月牙多边形** | 14 段 + 简单圆弧 | 16 段 + 增宽内外差 (`inner_r + t * 18.0`)，外层电光 + 核心亮白 + **金色刃辉勾勒** |
| **淡出** | 线性淡出 | 尾部缓出淡出 `1.0 - pow(raw_t, 1.6) * 1.2` |
| **扫角范围** | `-0.75π → 0.45π` | `-0.85π → 0.55π` 更大扫角覆盖，增强打击感 |

**性能注意**: 三重残影只在攻击帧计算，每层 steps=8 降低顶点数（比主月牙 16 步更轻量），总开销可控。

**核心代码** (`Player.gd _draw` 第 175-230 行):
```gdscript
var raw_t = 1.0 - (melee_anim_timer / MELEE_ANIM_DURATION)
var slash_progress = 1.0 - pow(1.0 - raw_t, 2.8)  # ease-out cubic

# 三重残影
for ghost_layer in [0, 1, 2]:
    var ghost_offset = 0.05 * float(ghost_layer + 1)
    var ghost_t = max(raw_t - ghost_offset, 0.0)
    ...
```

### 12.18 子弹弹反系统 (Bullet Deflect)

**功能**: 近战斩击时（`melee_attack()`），不仅能摧毁敌方弹幕，还能**反向弹回**，化为友方攻击。

**实现要点**:

| 维度 | 规范 |
|------|------|
| **检测范围** | 130px（比飞镖 110px 更宽容） |
| **触发方式** | 近战斩击时遍历 `enemy_projectiles` 组，有 `deflect()` 方法则调用 |
| **弹反效果** | `direction *= -1.0` 反弹回敌人；`collision_mask = 0` 不再伤害玩家 |
| **视觉反馈** | 双倍粒子爆裂 (`_spawn_particle_burst` 青色+金色)；弹幕变色为青蓝色 |
| **弹幕类型** | `FlyEnemyBullet.gd` + `JokerCard.gd` 均支持 |

**`deflect()` 协议**:
```gdscript
# 每个敌方弹幕必须实现的弹反方法
func deflect():
    direction *= -1.0     # 反转方向
    collision_mask = 0    # 不再伤害玩家
    deflected = true      # 变色标记
    queue_redraw()        # 刷新为友方颜色
```

**判定宽容原则**: 检测范围 130px > 飞镖 110px，配合 ease-out 弧线的"先快"阶段，让弹幕在刀光初段就被击飞，大幅降低弹反门槛，手感从容。

### 12.19 伤害协议 API (Damage Protocol)

所有可受伤对象实现以下方法，攻击系统通过 `has_method()` 检测后调用：

| 方法 | 实现者 | 效果 |
|------|--------|------|
| `hit_by_batarang()` | Enemy, FlyEnemy, FlyEnemyBullet | 被飞镖击中：爆裂粒子 + queue_free |
| `hit_by_batarang(damage: int = 1)` | Boss | Boss 扣 1 HP（默认），HP ≤ 5 进入狂暴 |
| `hit_by_melee(damage: int = 2)` | Boss | Boss 被近战斩击扣 2 HP（重创） |
| `deflect()` | FlyEnemyBullet, JokerCard | 被近战弹反：反向飞回，变色为青蓝色友方弹幕 |

**Boss 血量规则**:
- 总 HP = 10
- `hit_by_batarang(1)` → 扣 1 HP（飞镖伤害）
- `hit_by_melee(2)` → 扣 2 HP（近战重创）
- HP ≤ 5 → BOSS 进入**狂暴二阶段**：紫色气场（`Color(0.9, 0.1, 0.8, 0.25)`），移动速度 105→170，射击间隔 1.9→1.1 秒
- `alive` 标志位控制 Boss 是否存活；死亡触发 `die()`：爆裂粒子+动画→queue_free

**JokerCard 弹幕参数**:
- 抛射速度 ~320px/s，bobbing 偏移 40px
- 自旋动画 6.0 rad/s，击中玩家扣血
- 进入 `enemy_projectiles` 组，支持 `deflect()` 弹反

**弹幕 `deflect()` 协议**:
```gdscript
func deflect():
    direction *= -1.0     # 反转方向
    collision_mask = 0    # 不再伤害玩家
    deflected = true      # 变色标记
    queue_redraw()        # 刷新为青蓝色友方外观
```

### 12.20 Camera Shake 镜头震动与 Hit Stop 卡肉系统

Game.gd 提供两个打击感辅助函数，供攻击代码调用：

```gdscript
# 镜头震动 — 随 intensity 衰减
func add_camera_shake(intensity: float, duration: float = 0.15):
    camera_shake_intensity = intensity
    shake_timer = duration

# 卡肉停顿 — 短暂冻结游戏 tick 模拟打击重量感
func trigger_hit_stop(duration: float = 0.05):
    hit_stop_timer = duration
    get_tree().paused = true
```

**调用时机**:
| 事件 | Camera Shake | Hit Stop |
|------|-------------|----------|
| 近战击中敌人/Boss | `add_camera_shake(6.0~10.0, 0.1~0.15)` | `trigger_hit_stop(0.04)` |
| 落地 | `add_camera_shake(2.0, 0.08)` | — |
| 受伤 | `add_camera_shake(5.0, 0.12)` | — |

### 12.21 Boss 关键帧动画 (Keyframe Animation) 与 remove.bg 扣图工作流

> **架构升级**: 从旧的纯代码/矢量 `_draw()` 与 `BossPixel.gd` 升级为 Godot 4 最主流、推荐的 **`AnimatedSprite2D` + `SpriteFrames`** 关键帧动画系统。

#### 1. 工作流与 remove.bg API 扣图

- **动作序列图生成**：为小丑蜘蛛 Boss 绘制生成包含 `idle` (待机), `attack` (扑击咬杀), `stunned` (砸地破防), `enraged` (狂暴二阶段) 4 大核心姿势的动作序列图。
- **remove.bg API 自动化抠图**：
  - 脚本：`scripts/tools/process_boss_keyframes.py`
  - API Key: `1acZABw6JLjCPhk9qY6RFSee`
  - 自动调用 API 并执行 **Alpha 边缘精细化净化算法 (Clean Alpha Edges)**：
    - `Alpha < 100` 的微弱半透明噪点强行清零 (`Alpha = 0`)
    - 边缘浅白边/浅灰噪点进行剔除，`Alpha >= 160` 实施二值化边缘强化，保证 100% 像素风干净边缘。
- **切片与 SpriteSheet**：
  - 产出目录：`assets/boss_anim/`
  - 包含切分关键帧 (`idle_0~3.png`, `attack_0~3.png`, `stunned_0~3.png`, `enraged_0~3.png`) 与合并规范合图 [boss_spritesheet.png](file:///d:/godot-test-project/assets/boss_anim/boss_spritesheet.png)。

#### 2. Godot 关键帧驱动与重叠消除

- **`AnimatedSprite2D` 驱动**：在 `Boss.gd` `_ready()` 中动态加载 `SpriteFrames`，在 `_physics_process()` 中依据 `current_state` 与 `hp` 自动切换 `_anim_sprite.play("idle" / "attack" / "stunned" / "enraged")`，并镜像 `flip_h`。
- **视觉重叠彻底消除**：
  - `_pixel_sprite` 设置 `visible = false` 禁用。
  - 重构 `Boss.gd _draw()`：删除了旧矢量 8 条蛛腿、后腹部、鬼魅面部与锯齿獠牙，只保留 **头顶动态血条**、**落地点预警锁定圈**、**眩晕金星** 与 **扫击电弧**，使 Boss 角色视觉 100% 由关键帧动画独占。

#### 3. 新想法与后续规划

1. **角色/小怪关键帧自动化管线**：可将 `remove.bg API` + Python 自动切片管线复用到 Player 或其他小怪的特殊技能动画制作中。
2. **多阶段动画丰富**：未来可在 `SpriteFrames` 中补充 `boss_pounce_up` (跃起)、`boss_die` (爆裂崩溃) 等独立关键帧，进一步提升视觉张力。

---

### 12.22 终极动作关键帧与抠图切片黄金工作流 (Golden Keyframe & Matting Workflow Standard)

> [!IMPORTANT]
> 本章节记录项目实战验证总结出的 **最成熟、最完善的 2D 动作关键帧生成、扣图切片与贴地对齐黄金工作流**。后续新增任何角色/Boss/敌人动画必须严格遵循此规范！

#### 1. 美术素材 AI 生成标准 (Asset Generation Rules)
- **纯色扣图蓝幕 (Pure Chroma Blue Screen RGB 0,0,255)**：生成动作精灵表 (Sprite Sheet) 时，背景必须强制指定为单一、平整的纯蓝色扣图蓝幕 `RGB(0,0,255)` 或纯绿幕，确保主体与背景具有最大色彩反差。
- **严禁地面阴影与浮空杂质 (NO Ground Shadows)**：
  - 必须包含否定词：`ABSOLUTELY NO ground shadows, NO floor pads, NO green/dark floor blobs, NO floating particles, NO dark smoke`。
  - 保证角色脚爪/底部完全独立干净。
- **扁平化 2D 像素风格 (Flat 2D Pixel Art Style)**：角色采用扁平化着色，具备高精度的 2D 像素轮廓。

#### 2. 切片与脚爪 Ground Baseline 贴地对齐算法 (Slicing & Ground-Snap Rules)
- **4x4 标准矩阵切片**：包含 `idle_0~3` (待机), `attack_0~3` (扑击), `stunned_0~3` (眩晕), `enraged_0~3` (狂暴) 4 行 16 帧。
- **最大语义连通域分割 (Largest Connected Component Matting)**：利用 OpenCV 连通域统计 (`cv2.connectedComponentsWithStats`)，仅保留连通的主躯干，100% 净空擦除脱离主体的黑色散点与气泡。
- ** Ground Baseline 贴地对齐**：每个切片提取 Bounding Box 后，统一按 **底部 Baseline 线对齐** (`py = target_frame_size[1] - ch - 4`)。彻底消除 2D 横板游戏中角色脚部悬空或陷地的视觉 Bug。

#### 3. GDScript 镜像与朝向计算公式 (Facing Formula)
- 当动作切片源图角色默认朝右时，在 `Boss.gd` 的 `_update_keyframe_animation()` 中设定镜像计算公式为：
  ```gdscript
  _anim_sprite.flip_h = (facing_dir < 0.0)
  ```
- **玩家在左侧 (`facing_dir < 0`)**：`flip_h = true`（水平翻转朝左，迎面迎战蝙蝠侠）。
- **玩家在右侧 (`facing_dir > 0`)**：`flip_h = false`（保持朝右，迎面迎战蝙蝠侠）。

#### 4. 自动化测试与 Release 打包规程 (Test & Release Build)
- 每次更新素材或代码后，必须通过 800 帧 `TestRunner.gd` 压测与渲染诊断。
- 确认无误后执行打包：`--export-release "Windows Desktop" "build/GothamBatman.exe"`。

---

### 12.23 高级主菜单 UI 全中文拆解与动态 Hover 缩放动画黄金基准 (Master Menu UI & Pivoted Hover Scale Standard)

> [!IMPORTANT]
> 本章节记录实战总结出的 **最成熟、最高品质的主菜单 UI 美术生成、全中文切片拆解、抽象少色块背景层与 Central Pivoted 动态 Hover 缩放动画黄金标准**。

#### 1. UI 美术生成与全中文约束 (Full Chinese UI Prompt Rules)
- **强制全中文汉字**：AI 提示词中必须显式指定 `FULL CHINESE TEXT CHARACTERS ONLY`，绝不允许混入英文单词。
- **纯蓝扣图背景 (Chroma Blue Screen RGB 0,0,255)**：背景必须为平整纯蓝幕，按钮与 Logo 主体严禁包含蓝色，以确保 100% 干净抠图。
- **抽象少色块底图 (Abstract Min-Color Background)**：底层背景必须设计为色块少、色调沉稳极简的抽象画（如 [menu_bg_abstract.png](file:///d:/godot-test-project/assets/menu_bg_abstract.png)），作为 UI 的下一层级。

#### 2. Python 自动化抠图与连通域切片拆解管线 (UI Matting & Slicing Pipeline)
- 脚本：`scripts/tools/slice_menu_ui_elements.py`
- 算法：将大图转换至 HSV 空间剔除纯蓝幕 (`lower_blue=[90,80,80]`, `upper_blue=[135,255,255]`)，利用 OpenCV `cv2.findContours` 提取连通区域外接矩形，按 Y 轴坐标垂直排序，切割导出为独立透明贴图：
  - `chinese_title_logo.png`（标题 Logo）
  - `chinese_btn_start.png`（“开始出击”按钮）
  - `chinese_btn_level.png`（“关卡战役”按钮）
  - `chinese_btn_controls.png`（“战术指南”按钮）
  - `chinese_btn_scores.png`（“荣誉榜”按钮）
  - `chinese_btn_exit.png`（“退出客户端”按钮）

#### 3. Godot 中心 Pivot 动态 Hover 缩放与页面跳转公式 (Central Pivoted Hover Scale Formula)
- **中心 Pivot 关键设定**：为防止 `scale` 缩放时控件朝右下角偏移，**必须显式设置 `pivot_offset` 为按钮正中心**：
  ```gdscript
  btn.pivot_offset = Vector2(btn_w / 2.0, btn_h / 2.0)
  ```
- **Hover 膨胀动画 (`mouse_entered`)**：
  ```gdscript
  var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15)
  ```
- **离开恢复动画 (`mouse_exited`)**：
  ```gdscript
  var tween = create_tween().set_ease(Tween.EASE_OUT)
  tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
  ```
- **按压弹跳与页面跳转 (`pressed`)**：
  ```gdscript
  var press_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
  press_tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
  press_tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.08)
  press_tween.chain().tween_callback(func(): action_func.call())
  ```

---

### 12.24 BGM 动态音轨系统与极速无敌翻滚基准 (BGM Audio System & Dodge Roll Standard)

> [!IMPORTANT]
> 本章节记录实战总结出的 **全局 BGM 动态淡入淡出音轨系统** 以及 **Player 极速无敌残影翻滚** 标准。

#### 1. 全局 BGM 动态音轨淡入淡出系统 (`Game.gd`)
- **根目录音频约定**：
  - `res://bgm.mp3`：常规关卡与主菜单通用 BGM。
  - `res://boss.mp3`：Level 5 小丑 Boss 决战热血 BGM。
- **动态平滑淡入淡出切换 (`_play_bgm`)**：
  - 音频播放器设置 `process_mode = Node.PROCESS_MODE_ALWAYS`，保证游戏暂停时音轨不中断。
  - 音轨切换时通过 Tween 实现 0.5s 平滑淡出 (-40dB) 与淡入 (-4dB) 过渡。
  - 进入 Level 5 决战竞技场 (`_lock_boss_arena()`) 时，平滑淡出常规 BGM，并激动切入 `res://boss.mp3`。
- **纯净背景与移除残影**：
  - 彻底禁弃夜空中的 Boss 半透明肖像残影 `boss_portrait`，保留哥谭纯净沉稳的夜景天际线与血色大楼投影。

#### 2. Player 极速无敌残影翻滚闪避 (Dodge Roll Standard)
- **快捷键**：支持按键盘 **`Shift` 键**、**`S` 键**、**`↓` 下方向键** 或 **`L` 键** 随时触发。
- **数值与无敌帧**：
  - 冲刺速度：`850.0` px/s 沿当前朝向极速爆发突进。
  - 持续时间：`0.25` 秒。
  - 冷却时间：`0.35` 秒。
  - 无敌状态：翻滚全过程强制维持 `invincible_timer = 0.25` 物理无敌，可无伤穿透小怪与 Boss 狂笑扑克弹幕。
- **特效**：每 0.05 秒生成暗金蝙蝠闪避残影 `_spawn_roll_ghost()`。

---

### 12.25 5 槽生命值 HUD 架构与哥谭战术浮空平台绘制规范 (5-Heart HUD & Tech Platform Standard)

> [!IMPORTANT]
> 本章节记录实战总结出的 **5 槽位生命值 HUD 渲染、半血拾取拦截** 以及 **哥谭战术科技悬浮平台绘制标准**。

#### 1. 5 槽位生命值系统与半血回复拦截 (`Game.gd`, `ItemDrop.gd`)
- **容量上限 (Max 5 Hearts)**：初始 `lives = 3.0`，最大上限 `max_lives = 5.0`。
- **回复与拦截逻辑**：
  - 击杀小怪掉落血瓶回复 `+0.5` 生命值（半颗心）。
  - 当 `lives >= 5.0` 满血时，拾取血瓶**不再增加生命**，自动转换为 `+100` 得分与金色闪耀特效。
- **5 槽位 HUD 渲染算法 (`_update_lives_hud`)**：
  - 遍历 5 个槽位：`>= i + 1.0` 渲染满心 `heart_full`；`>= i + 0.5` 渲染半心 `heart_half`；其余渲染空心 `heart_empty`。

#### 2. 哥谭战术科技悬浮平台绘制 (`MovingPlatform.gd`, `Game.gd`)
- **淘汰沉闷灰色底色**：彻底摒弃灰褐色长条。
- **亮金战术包边 + 天蓝荧光防滑面**：
  - 底色：深钢蓝战术配色 (`Color(0.14, 0.18, 0.32)`)。
  - 包边：金色战术警示边框 (`Color(1.0, 0.85, 0.2)`) 搭配 3.0px 天蓝顶线 (`Color(0.3, 0.92, 1.0)`).
  - 喷气核：动态移动平台底部左右配置双天蓝离子推进器 (`Color(0.2, 0.9, 1.0)`)。在暗夜场景中极具可识别度与视觉震撼！

---




