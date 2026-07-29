# AI Agent — 横板冒险开发指南

> **项目**: Godot 4.7.1 横板过关小游戏
> **路径**: `D:\godot-test-project`
> **目标**: 供 AI Agent 持续优化开发的知识基准

---

## 0. 核心编码与工作流规则 (Core Guidelines)

> [!IMPORTANT]
> 1. **全中文沟通与注释**：回答问题一律使用中文，所有 GDScript 代码中的注释必须全部使用中文。
> 2. **修改后自动试玩**：每次修改代码后，必须通过自动化测试脚手架 (`TestRunner.gd`) 进行实际游玩测试与逐帧渲染快照检查。
> 3. **确认无误后打包**：只有在自动化游玩测试通过、确认画面与帧率没有任何 Bug / 白闪 / 报错后，才执行 `--export-release` 打包生成 `.exe`。
> 4. **保持纯 GDScript 代码架构**：所有节点继续使用 GDScript 动态创建，不打破纯代码设计理念。

---

## 1. 项目概要


纯 GDScript 的 Godot 4 平台跳跃游戏。所有节点用代码动态创建（无 .tscn 场景编辑）。
玩家控制角色收集金币、踩敌人、到达终点通关。

### 关键文件

| 文件 | 类 | 类型 | 职责 |
|------|-----|------|------|
| `Game.gd` | — | `Node2D` | 状态机、关卡构建、Camera(自定义lerp)、HUD(StyleBoxFlat)、暂停、最高分、飘字特效、碰撞响应 |
| `Player.gd` | — | `CharacterBody2D` | 输入处理(WASD/Space/左键)、物理、朝向翻转_draw、受伤/无敌/死亡、智能重绘(needs_redraw) |
| `Boss.gd` | — | `Area2D` | 小丑大 Boss AI (10 HP、头顶动态血条、狂暴二阶段、狂笑扑克弹幕、击败爆裂动画) |
| `JokerCard.gd` | — | `Area2D` | 小丑狂笑扑克牌弹幕、自旋动画、击中玩家伤害检测 |
| `Batarang.gd` | — | `Area2D` | 蝙蝠侠飞镖、高速飞行自旋双翼矢量绘制、击中敌/Boss 爆裂消灭 |
| `Enemy.gd` | — | `Area2D` | 地面巡逻 AI、蘑菇怪矢量绘制(阴影/眉毛/大眼)、踩头判定、压扁动画 |
| `FlyEnemy.gd` | — | `Area2D` | 飞行蝙蝠怪物 AI、正弦波浮动巡逻绘制 |
| `Coin.gd` | — | `Area2D` | 浮动动画(bobbing)、椭圆多边形绘制、双保险碰撞检测、收集飞走动画 |
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
| 跳跃 | `_unhandled_input` + `is_action_pressed` | 一次触发，精确响应，不丢帧 |
| 左右移动 | `_physics_process` + `Input.get_axis()` | 连续状态读取，平滑 |
| 菜单确认 | `_process` + `Input.is_action_just_pressed` | 简单轮询 |
| 窗口失焦 | `_notification` + `NOTIFICATION_WM_WINDOW_FOCUS_OUT` | 系统级通知 |

**防抖/守卫链** (Player._unhandled_input):
```
is_dead → input_disabled → just_spawned → is_on_floor()
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
| `LEVEL_WIDTH` | 1632 | 关卡宽度 |
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

**使用方法**: `godot_console.exe --path . --script TestRunner.gd`

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

### 9.11 Game.gd 视觉调优

| 改动 | 作用 |
|------|------|
| 天空底色 `0.04,0.06,0.12` → `0.12,0.16,0.28` | 调亮背景，让深色蝙蝠侠轮廓更突出 |
| 月亮暖色化 80x80 → 65x65 | 更精致柔和 |
| 新增 5 朵柔和浮云 | 增加天空层次感 |
| 摩天大楼透明度增加 + 窗口固定化 | 降低节点膨胀，避免随机种子不一致 |
| 蝙蝠探照灯透明度 0.12 → 0.08 | 更低调柔和 |

### 9.12 TestRunner 自动化性能测试框架

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

### 9.13 TestRunner 性能优化 — 延迟截图落盘

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

## 10. 已知局限 & 可优化方向

- **Enemy 是 Area2D**：用 `position.x += SPEED * direction * delta` 而非 `move_and_slide()`，这意味着敌人不受重力/碰撞影响。目前敌人固定在地面Y巡逻，但如果要放在平台上，需要重构为 CharacterBody2D
- **掉落死亡**：防物理Bug的保守方案（`y > GROUND_Y+100` 触发 `_on_player_hit`），没有专门的"掉坑"关卡设计
- **纯代码构建**：所有节点动态创建，没有 .tscn 场景，便于 AI 修改但缺少可视化编辑
- **`die()` 方法未使用**：Player 有 `die()` 方法但当前逻辑不触发死亡动画（命数耗尽直接弹出 Game Over 界面）
- **无音效/粒子**：纯视觉反馈

---

## 11. 踩坑与最佳实践汇总

本项目的所有踩坑记录分类汇总，方便快速查找原因和最佳方案。

### 10.1 碰撞系统

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| 玩家穿过单向平台 | 从上方站不住 | `collision_mask` 没设 `3`（缺层2） | `collision_mask = 3; platform_floor_layers = 2` |
| 碰撞体在物理回调中禁用报错 | `set_disabled` 运行时改 PhysicsServer 状态 | 物理回调中直接操作碰撞体 | 改用 `set_deferred("disabled", true)` |
| 浮动金币碰撞体不同步 | 金币浮动穿模，玩家碰不到 | 用 `_process`（渲染帧）驱动位置，PhysicsServer 没跟上 | 用 `_physics_process` 驱动，物理帧同步 |
| 踩头判定不准 | 有时踩到却受伤 | 只用 `body_entered` 信号不够细 | 双条件：`stomp_from_fall`（下落中）+ `stomp_from_above`（玩家 Y < 敌人 Y） |

### 10.2 Camera 镜头

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| Camera 内置平滑 snap | 瞬移/抖动 | 开了 `position_smoothing_enabled` 又手动 `position =` | 关掉内置平滑，用 `lerp()` 手动实现 |
| 关平滑→瞬移→开平滑 | 画面卡顿 | 多余的三步 hack | 仅用 `lerp(a, b, 12*delta)` 自然逼近 |
| 镜头不限制边界 | 看到关卡外黑色区域 | 没设 `limit_*` | `limit_left/right/top/bottom` 限制镜头范围 |

### 10.3 绘制

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| `draw_polygon` 渲染白屏 | 金币/形状显示白色方块 | 传入负的半径 → winding order flip | `rx = max(abs(rx), 1.0); ry = max(abs(ry), 1.0)` — 始终确保正半径 |
| 绘制闪烁 | `_draw()` 内容一闪一闪 | `queue_redraw()` 调用太频繁 | 设置 `needs_redraw` 标志：只有 alpha（无敌）/ 朝向变了才重绘 |
| 朝向翻转不对 | 绘制内容镜像反了 | 仅翻转 `scale.x` 导致绘制坐标也跟着反 | 绘制代码用 `facing_right` 控制坐标符号：`if !facing_right: draw_circle(Vector2(-x,y))` |

### 10.4 Tween 动画

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| Tween 无限循环泄漏 | 内存泄漏 / 卡顿 | 用 `infinite` + `set_loops()` 做闪烁 | 用 `_process` 手动 `blink_timer` 累加取整模2 |
| 飘字残留在场景中 | Label 越来越多 | Tween 回调未清理节点 | `chain().tween_callback(func(): label.queue_free())` 自动清理 |
| 动画结束后抖动 | 飘字淡出后仍然有残留 | `set_parallel(true)` 的 Tween 被提前释放 | `create_tween()` 而非 `Tween.new()`，让 Tween 自管理生命周期 |

### 10.5 输入处理

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| 窗口失焦后方向卡死 | 切窗再切回，角色自动持续移动 | 失去焦点时键盘事件丢失，但 Input 状态未复位 | `_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)`: `Input.flush_buffered_events()` |
| 跳跃触发两次 | 按一次跳两下 | `_input` + `_unhandled_input` 同时接到事件 | 守卫链：`is_dead → input_disabled → just_spawned → is_on_floor()` |
| 暂停后跳跃残留 | 取消暂停立刻跳起 | 暂停期间 Space 被缓存 | 暂停/恢复时 `Input.flush_buffered_events()` |

### 10.6 状态管理

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| 菜单重建后事件泄漏 | 旧节点信号仍触发 | `queue_free()` 后旧节点上的 signal connect 残留 | 重建前 `queue_free()` 完全清理，用 is_inside_tree() 守卫 |
| 状态守卫混乱 | 同时触发胜利和 Game Over | 没有排他状态判断 | 在 `_process` 开头用 `match state:` 分支，每个状态互斥 |
| pause 后 tween 也停了 | 暂停时飘字/闪烁也卡住 | `get_tree().paused` 默认暂停所有 `SceneTreeTimer` 和 Tween | Tween 设置 `set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` 或暂停仅冻结物理 |

### 10.7 持久化

| 问题 | 现象 | 原因 | 最佳方案 |
|------|------|------|---------|
| `ConfigFile` 路径写死 | 用户电脑没有该路径 → 读文件失败 | 用了绝对路径 | 用 `user://` 前缀自动映射到平台特定目录 |
| 最高分在不同机器上不共享 | 换电脑分数丢了 | 这不是 Bug，是设计预期 | `user://high_score.cfg` 存本地即可，无需云同步 |

### 10.8 通用 Godot 实践

| 最佳实践 | 说明 |
|---------|------|
| `@onready` 缓存节点引用 | `@onready var player = $Player` 避免每帧 `get_node()` |
| `set_deferred` 修改碰撞体 | 物理回调期间用延迟设置避免状态冲突 |
| `is_inside_tree()` 守卫 | 信号回调第一行检查，防止节点已释放后意外执行 |
| `create_tween()` 而非 `Tween.new()` | 自动管理生命周期，被创建节点的父节点释放时自动清理 |
| `Input.flush_buffered_events()` | 窗口失焦、暂停恢复、状态切换时调用，防止残留输入 |
| `_physics_process` 驱动物理相关位置 | 非渲染帧驱动的 `position` 变化才能被 PhysicsServer 感知 |
| 状态机用 `enum + match` | 比字符串比较更类型安全，性能更好 |

### 10.9 TestRunner.gd 与自动化游玩压测踩坑汇总

| 问题 / 踩坑点 | 现象 | 原因 | 最佳解决方案 |
|------|------|------|---------|
| CLI 快照截图全黑/返回 null | `root.get_texture().get_image()` 截取为黑屏 | 命令行加了 `--headless` 参数使用 dummy 渲染器，不输出视口纹理 | 移除 `--headless`，改用 `--rendering-driver opengl3` 命令行驱动跑测试 |
| `get_process_step()` 语法解析报错 | `Static function "get_process_step()" not found` | 误写成 `Engine.get_process_step()` | `get_process_step()` 是 `SceneTree` 的成员方法，直接调用 `get_process_step()` |
| VSYNC 垂直同步干扰掉帧采样 | 帧率 60FPS 但 `TIME_PROCESS` 报 28ms-34ms Spike | `Performance.TIME_PROCESS` 包含了 GPU 垂直同步等待时间 | 结合 `Engine.get_frames_per_second() < 50` 以及 `Performance.TIME_PHYSICS_PROCESS` 综合判定卡顿 |
| 游玩模拟被守卫拦截 | 按空格没响应，无法开始游戏 | Player 刚生成时有 `just_spawned` 标志或处于 `input_disabled` 状态 | 试玩脚手架在 Frame 5 显式调用 `game_instance._start_game()`，并重置模拟坐标 |
| `_draw()` 堆内存大量分配推高 Process 耗时 | Process 耗时升至 22ms+ 导致卡顿 | 每帧 `_draw()` 中实例化多个 `PackedVector2Array` 数组 | 使用 `static func _static_init()` 静态预分配单位圆数组；按 `Engine.get_physics_frames() % 2 == 0` 间隔刷新 |
| 背景 ColorRect 节点膨胀推高 SceneTree 开销 | 节点数从 65 暴涨至 150+ | 在 `_create_world()` 中用循环大量生成小 Window `ColorRect` 节点 | 限制窗口灯光节点数量，或采用单个 Node2D `_draw()` 统一绘制背景 |
| EXE 打包提示 `game.tmp` 无法重命名失败 | `--export-release` 导出提示失败 | `build/game.exe` 已经在后台运行中，文件被 Windows 系统锁住 | 在打包前执行 `Stop-Process -Name "game" -Force -ErrorAction SilentlyContinue` 杀死残留进程 |

### 10.10 偶发白闪防范与 2D 多边形绘制规范

| 风险点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| `draw_polygon` 镜像翻转 (`flip = -1`) | 随机/偶发 1 帧屏幕白闪或暗屏 | `flip = -1` 使多边形顶点 Winding Order 变成 Clockwise 顺时针，在某些 GPU 驱动 (如 RTX 2080S 566.36) 上可能抛出退化三角形/白像素 | 在 `flip = -1` 时对顶点数组调用 `.reverse()` 显式保持 Counter-Clockwise (逆时针)，确保多边形有符号面积 > 0 |
| `queue_free()` 前的幽灵帧绘制 | 节点被销毁的前 1 帧突然闪现 | 节点 `queue_free()` 是延迟到帧末清理，在动画结束该帧可能比 Render Pipeline 先/后生效导致以 1.0 Alpha 重绘 | 在所有 Tween 的 `tween_callback` 中，统一采用 `func(): hide(); queue_free()` 先隐藏节点再销毁 |
| Camera `lerp` 镜头步幅突变 | 画面边缘瞬间白闪 (露底) | 帧率掉帧导致 `delta` 突大，`12.0 * delta` 溢出导致 Camera 坐标跳变，背景 `ColorRect` 与视口脱节露出默认 Clear Color | 在 Camera 移动插值中使用 `clamp(12.0 * delta, 0.0, 1.0)` 限制单帧最大跟随步幅 |
| 护臂刺刺/局部多边形坐标算错 | 转向时刺刺穿透身体拉成大狭长线段 | 护臂刺刺误用了 `Vector2(-15 * flip)` 导致 left_arm (x=-12) 刺向右边 (+15)，跨越全身 | 左右两侧手臂分别独立计算固定绘制坐标，不直接对局部 X 坐标做盲目乘 `flip` 运算 |

### 10.11 单向平台与多关卡边界陷阱

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| 单向平台水平侧面卡死 | 玩家跃至平台同高度时在水平方向被平台左/右侧边缘阻挡卡住 | `platform_floor_layers = 2` 仅影响竖直下落 Floor 判定。因玩家 `collision_mask = 3`，在水平方向 `move_and_slide()` 仍与图层2产生硬碰撞 | 图层 2 的单向平台（StaticBody2D）的 `CollisionShape2D` 必须显式设置 `col.one_way_collision = true`，使侧面与下方均可流畅穿透 |
| 跨关长地图横向坐标卡死 | 进入 Level 2 (2400px) 或 Level 5 (5000px) 后，玩家在 x=1620.0 处被隐形墙锁死无法前进 | `Player.gd` 中硬编码了 `const LEVEL_WIDTH = 1632`，并在 `_physics_process` 中使用了 `clamp(position.x, 12, LEVEL_WIDTH - 12)` | 将 `LEVEL_WIDTH` 重构为动态变量 `var level_width`，并在 `Game.gd` 创建玩家时实时赋值 `player_node.level_width = level_cfg["width"]` |
| 地面陷阱区域死胡同 | 玩家不小心掉落到地面后，无论怎么按跳跃都无法跳回高处平台 | 蝙蝠侠极限起跳高度为 `127.7px` (`v=-530, g=1100`)。若地面上方主平台 `y <= 400`（距地面 140px+），落入地面的玩家将陷入物理不可逆的死胡同 | 地面所有地刺/陷阱空隙旁均需布置 `y = 465`（距地面仅 85px）的登高梯低平台，保障掉落后 100% 可跳跃攀爬复活 |

### 10.12 关卡难度扩展与敌人密度平衡规范

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| 关卡拉长后怪物密度下降 (密度稀释) | 越往后关卡越空旷，感觉难度不升反降 | 扩展地图长度 (如 1632px $\rightarrow$ 5000px) 时，怪物生成数量未按比例同步增加，导致密度从 3.75个/1000px 降至 3.20个/1000px | 制定**每千像素密度递增指标**：Level 1~2 控制在 3.0~3.8 个/1000px，Level 3~5 依次提升至 5.0、5.0、4.8 个/1000px |
| 关卡末段无怪空白盲区 | 接近终点线数百像素内怪物完全消失 | 手动配置敌人生成点数组时，最大 `x` 坐标止步于 `4250px`，距离 `5000px` 终点残留了 750px 的空旷地带 | 敌人生成 `x` 坐标必须覆盖至 `LEVEL_WIDTH - 350px` 的关卡前沿区域，禁止留下 >300px 的无怪空白区 |

### 10.13 鼠标点击事件拦截与输入管道规范

| 风险点 / 踩坑点 | 现象 / 隐患 | 底层根因 | 规范解决方案 |
|------|------|------|---------|
| GUI Panel 吸收鼠标左键导致飞镖无法发射 | 在游戏画面中点击鼠标左键无任何响应，飞镖无法发射 | 视口上方顶层 HUD 的 `Panel` 或 `Control` 节点默认 `mouse_filter = MOUSE_FILTER_STOP`，吞噬了所有鼠标点击事件，导致 `Player._unhandled_input()` 永远无法收到左键事件 | 1. 在 HUD `Panel` 上显式设置 `panel.mouse_filter = Control.MOUSE_FILTER_IGNORE`；<br>2. 玩家节点攻击响应统一改用 `_input(event)`（优先于 GUI 传递层级处理）。 |
| 鼠标左键发射方向与朝向脱节 | 点击左侧画面时飞镖依然朝右射出 | 发射飞镖时仅读取了 `facing_right` 变量，未根据鼠标在全局场景中的 `get_global_mouse_position()` 坐标实时判定 | 在 `shoot_batarang()` 中比对 `mouse_pos.x` 与 `global_position.x`，自动将 `facing_right` 转向鼠标所在方位，实现指哪打哪。 |

