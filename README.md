# 🦇 哥谭大冒险：蝙蝠侠出击 — 开发总结

> **作者**: 钟志恒（AI技术部）
> **引擎**: Godot 4.7.1.stable
> **平台**: Windows x86_64
> **路径**: `D:\godot-test-project`
> **主题**: 蝙蝠侠哥谭市平台跳跃（原通用横板过关游戏已全面主题化改造）

---

## 目录

1. [环境安装](#1-环境安装)
2. [项目结构](#2-项目结构)
3. [代码架构](#3-代码架构)
4. [核心实现](#4-核心实现)
5. [碰撞系统详解](#5-碰撞系统详解)
6. [Bug 修复记录](#6-bug-修复记录)
7. [构建打包](#7-构建打包)
8. [开发心得](#8-开发心得)
9. [附录](#附录)

---

## 1. 环境安装

### 1.1 下载 Godot 引擎

从 [Godot 官网](https://godotengine.org/download/windows/) 下载 **Godot Engine — .NET 版**（或标准版），
当前使用版本为 `v4.7.1.stable`。

下载后得到一个 `Godot_v4.7.1-stable_win64.exe` 文件，将其放入合适目录（如 `%LOCALAPPDATA%\Godot\`）。

### 1.2 安装导出模板

导出成独立 exe 需要 Export Templates，两种安装方式：

**方式 A — 通过 Godot 编辑器**：
打开 Godot → Editor → Manage Export Templates → Download

**方式 B — 手动下载**：
从 [GitHub Releases](https://github.com/godotengine/godot/releases) 下载对应版本的
`Godot_v4.7.1-stable_export_templates.tpz`，解压到：

```
%APPDATA%\Godot\export_templates\4.7.1.stable\
```

目录结构为：
```
4.7.1.stable/
├── windows_debug_x86_64.exe
├── windows_release_x86_64.exe
├── templates/
│   ├── android_debug.apk
│   ├── android_release.apk
│   └── android_source.zip
```

### 1.3 验证安装

```powershell
& "$env:LOCALAPPDATA\Godot\godot_console.exe" --version
# 输出: 4.7.1.stable.official.a13da4feb
```

---

## 2. 项目结构

```
D:\godot-test-project\                       # 项目根目录
├── build\                                   # 导出输出目录
│   └── game.exe                             #   最终可执行文件 (~104 MB)
├── screenshots\                             # 自动截图输出
├── AGENTS.md                                # AI 开发指南与知识基准
├── Coin.gd                                  # 金币脚本
├── Enemy.gd                                 # 敌人脚本
├── Game.gd                                  # 主游戏场景脚本（哥谭夜景、HUD、逻辑）
├── Game.tscn                                # 主场景入口
├── Player.gd                                # 蝙蝠侠玩家脚本
├── TestRunner.gd                            # headless 自动截图工具
├── monitor.ps1                              # 文件变更监控脚本
├── check_changes.ps1                        # 监控日志查看脚本
├── project.godot                            # 项目配置文件
└── export_presets.cfg                       # 导出预设（Windows Desktop）
```

### 文件职责

| 文件 | 职责 | 关键类 |
|------|------|--------|
| `Game.gd` | 哥谭夜景(云层/月亮/蝙蝠探照灯)、Camera、HUD、状态机、碰撞响应、粒子爆裂、暂停增强 | `Node2D` |
| `Player.gd` | 蝙蝠侠动态动画(3态披风/腿摆动/呼吸)、Coyote Time、Jump Buffer、30FPS动画优化 | `CharacterBody2D` |
| `Coin.gd` | 金币碰撞检测、浮动动画、旋转绘制 | `Area2D` |
| `Enemy.gd` | 蘑菇怪巡逻 AI、踩头判定、压扁消失 | `Area2D` |
| `TestRunner.gd` | 500帧自动化性能测试+截图报告框架 | `SceneTree` |
| `Game.tscn` | 资源场景入口，引用 Game.gd | — |
| `AGENTS.md` | AI 上下文知识文档 | — |
| `export_presets.cfg` | Windows 导出参数 | — |

---

## 3. 代码架构

### 3.1 项目全景图

本游戏由 **5 个 GDScript 文件**（共约 1510 行代码）构成，所有节点在运行时用代码动态创建，没有预制的 .tscn 场景（Game.tscn 仅为入口空壳）。
**主题**: 🦇 哥谭大冒险：蝙蝠侠出击（蝙蝠侠哥谭市平台跳跃）

```
┌─────────────────────────────────────────────────────────────┐
│                        Game.gd (Node2D)                      │
│  状态机 | 关卡构建 | Camera | HUD | 暂停 | 最高分 | 碰撞响应   │
│  632 行 — 游戏的中枢神经系统                                  │
├─────────────────────────────────────────────────────────────┤
│                          子节点                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐  │
│  │WorldSkyBG│ │Camera2D  │ │Player    │ │Enemy x3        │  │
│  │(夜景天空)│ │(lerp跟随)│ │(蝙蝠侠)  │ │Area2D          │  │
│  │          │ │          │ │Character │ │(巡逻AI)        │  │
│  │Moon+     │ │          │ │Body2D    │ │                │  │
│  │BatSignal │ │          │ │Coyote    │ │Coin x10        │  │
│  │          │ │          │ │Time+     │ │Area2D          │  │
│  │Buildings │ │          │ │Jump      │ │(浮动+旋转)     │  │
│  │x11(窗户) │ │          │ │Buffer    │ │                │  │
│  ├──────────┤ ├──────────┤ ├──────────┤ ├────────────────┤  │
│  │Ground    │ │Platform  │ │Finish    │ │HUD (CanvasLyr) │  │
│  │Static    │ │x8 Static │ │Area2D    │ │ ├💰 ScoreLabel  │  │
│  │Body2D    │ │Body2D    │ │(通关)    │ │ ├❤️ LivesLabel  │  │
│  │(层1)     │ │(层2 单向)│ │          │ │ └👑HighScoreLbl│  │
│  └──────────┘ └──────────┘ └──────────┘ └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 每个文件内部函数结构

#### Game.gd — 游戏中枢 (735 行, 哥谭夜景调优)

| 函数区域 | 函数 | 职责 |
|---------|------|------|
| **入口** | `_ready()` | 设置背景色、加载最高分、进入菜单状态 |
| **主循环** | `_process(delta)` | 状态机分发(MENU/PLAYING/WON/GAME_OVER)、镜头lerp、掉落检测 |
| | `_unhandled_input(event)` | 仅 PLAYING 态处理 ESC 暂停 |
| **辅助** | `_blink_step(delta)` | 安全的闪烁动画（替代 infinite tween） |
| **最高分** | `_load_high_score()` | 从 `user://high_score.cfg` 加载 |
| | `_save_high_score()` | 保存最高分到本地文件 |
| **菜单** | `_create_menu()` | 创建星光背景 + 圆角卡片 + 最高分 + 操作说明 + 开始提示 |
| **状态切换** | `_start_game()` | MENU→PLAYING：清理菜单、构建世界、创建玩家、初始化镜头 |
| | `_go_back_menu()` | WON/GAME_OVER→MENU：完全重建 |
| **世界** | `_create_world()` | 哥谭夜空(调亮背景色)+明月+浮云×5+蝙蝠探照灯+摩天大楼×11(每栋2扇固定窗户)+Camera2D+地面+草地+8平台+10金币+3敌人+终点 |
| | `_add_static_rect()` | 通用 StaticBody2D 创建（参数化图层） |
| | `_create_finish()` | 终点旗帜 + 碰撞体 + 信号绑定 |
| | `_create_player()` | 实例化 Player 放到起点 |
| **HUD** | `_create_hud()` | StyleBoxFlat 圆角面板 + 🪙金币/❤️生命/👑最高分 |
| | `_update_lives_hud()` | 根据剩余生命更新 ❤️/🖤 |
| **特效** | `_spawn_floating_text()` | 飘字动画 "+1"/"+2"/"-1❤️" |
| | `_spawn_particle_burst()` | 粒子爆裂特效（8个 ColorRect + Tween 扩散淡出） |
| **暂停** | `_toggle_pause()` | 切换 `get_tree().paused`，创建/销毁暂停 overlay，支持 R/M 快捷键 |
| **事件** | `_on_coin_collected()` | 加分 + 飘字 |
| | `_on_enemy_stomped()` | 加分 + 飘字 |
| | `_player_hurt()` | 扣命 + 飘字 → Game Over |
| | `_on_player_hit()` | 状态守卫 → `_player_hurt()` |
| | `_on_finish_entered()` | 通关 |
| **弹出** | `_show_overlay()` | 通用通关/结束遮罩（含最高分比较） |
| | `_win_game()` | WON 状态 + overlay |
| | `_game_over()` | GAME_OVER 状态 + overlay |

#### Player.gd — 蝙蝠侠角色 (217 行)

| 函数区域 | 函数 | 职责 |
|---------|------|------|
| **配置** | `_ready()` | 放大1.25倍、碰撞层(mask=3)、单向平台(layers=2)、碰撞体形状 |
| **绘制(动态)** | `_draw()` | 蝙蝠侠9层+3态动画：待机(呼吸1px+微摆)/奔跑(腿摆动5px+斗篷后飘)/空中(披风张开+固定腿) |
| **输入** | `_unhandled_input()` | Jump Buffer(0.12s预输入)、Variable Jump Height(短按×0.45/长按)、守卫链 |
| | `_notification()` | 窗口失焦时 `Input.flush_buffered_events()` |
| **物理** | `_physics_process(delta)` | `anim_time`累加、Coyote Time(0.12s)、Jump Buffer执行、无敌闪烁、重力、水平移动、`move_and_slide()`、边界clamp |
| **动画优化** | 重绘策略 | 30FPS隔帧刷新(`Engine.get_physics_frames() % 2 == 0`)，减少50% `_draw()` 调用 |
| **状态** | `hit()` | 受伤：无敌1.5s + 击退，返回是否实际受伤 |
| | `die()` | 禁用碰撞 + 弹起飞出 + 变红tween 0.4s + 隐藏 |

#### Enemy.gd — 敌人 (115 行)

| 函数区域 | 函数 | 职责 |
|---------|------|------|
| **配置** | `_ready()` | 碰撞体设置、信号连接 |
| **绘制** | `_draw()` | 蘑菇怪：阴影、红头菇身体、刺角、大白眼、瞳孔（随方向）、愤怒眉毛 |
| | `draw_ellipse_custom()` | 自定义椭圆绘制（12段多边形） |
| **物理** | `_physics_process(delta)` | 巡逻左右移动，边界转向时重绘 |
| **碰撞** | `_on_body_entered()` | 踩头双条件判定(stomp_from_fall/stomp_from_above) |
| **状态** | `stomp()` | 禁用碰撞 + 压扁动画(scale 1.4→0.15) + 消失 |

#### Coin.gd — 金币 (101 行)

| 函数区域 | 函数 | 职责 |
|---------|------|------|
| **配置** | `_ready()` | 碰撞体(radius 16)、随机初始相位、信号连接 |
| **物理** | `_physics_process(delta)` | 浮动动画(sin*3.5)、双保险碰撞检测(`get_overlapping_bodies()`) |
| **绘制** | `_draw()` | 金币旋转效果：多层椭圆(暗边→金色→内槽→高光) |
| | `_draw_ellipse()` | 16段多边形椭圆（防负半径白闪） |
| **碰撞** | `_on_body_entered()` | 玩家进入 → `_collect()` |
| | `_collect()` | `set_deferred("disabled")` 安全禁用碰撞 + 飞走动画 + `queue_free()` |

### 3.3 完整事件与数据流

```
┌─ 启动 ─────────────────────────────────────┐
│ _ready() → 加载最高分 → _create_menu()      │
│   → MENU 状态，等待 Space 输入                │
└────────────────────────────────────────────┘
                      │ Space 键
                      ▼
┌─ _start_game() ────────────────────────────┐
│ queue_free 菜单 → _create_world()           │
│   → Camera2D + 地面 + 平台 + 金币 + 敌人   │
│   → Player + HUD + 镜头初始化               │
│ → PLAYING 状态                              │
└────────────────────────────────────────────┘
                      │ 每帧 _process
                      ▼
┌─ PLAYING 每帧 ─────────────────────────────┐
│ camera.position.lerp(player)   ← 自定义跟随 │
│ if player.y > 650 → _on_player_hit()        │
│ ESC → _toggle_pause()                       │
└────────────────────────────────────────────┘
                      │ move_and_slide() 触发
                      ▼
┌─ 碰撞信号 ─────────────────────────────────┐
│                                            │
│  Coin.body_entered(player)                  │
│   → _on_coin_collected → score++             │
│     → "+1"飘字 + 金色粒子爆裂               │
│                                            │
│  Enemy.body_entered(player)                 │
│   ├─ 踩头(下落+位置判定)                     │
│   │  → stomp() + player.vy=-380              │
│   │    → "+2"飘字 + 红色粒子爆裂            │
│   └─ 受伤                                   │
│      → _on_player_hit → hit() → 无敌+击退   │
│        → lives-- ("-1❤️"飘字+红色粒子)       │
│        → if ≤0 → die() → 0.4s延迟→GameOver  │
│                                            │
│  Finish.body_entered(player)                 │
│   → _on_finish_entered → _win_game()        │
│     → 比较最高分 → 保存 → 弹出 overlay       │
└────────────────────────────────────────────┘
```

### 3.4 游戏状态机

```
                        Space 键
              ┌──────────────────────────┐
              │                          │
              ▼                          │
 ┌──────┐  Space  ┌─────────┐            │
 │ MENU ├────────►│ PLAYING │            │
 └──────┘         └────┬────┘            │
                       │                 │
              ┌────────┼────────┐        │
              ▼        ▼        ▼       │
          lives=0   通关    ESC         │
              │        │        │       │
              ▼        ▼        ▼       │
         ┌─────────┐ ┌──────┐ ┌──────┐ │
         │GAME_OVER│ │ WON  │ │PAUSED│ │
         └────┬────┘ └──┬───┘ └──────┘ │
              │         │    │  ESC     │
              │         │    └──────────┘
              └────┬────┘
                   │  Space
                   ▼
               ┌──────┐
               │ MENU │
               └──────┘
```

| 状态 | 触发 | 行为 |
|------|------|------|
| `MENU` | 启动 / Game Over / 通关按 Space | 显示菜单、闪烁提示、等待输入 |
| `PLAYING` | 按 Space | 游戏运行、输入响应、物理模拟、碰撞检测 |
| `PAUSED` | 游戏中按 ESC | `get_tree().paused=true`，物理冻结，显示暂停面板 |
| `WON` | 到达终点 | `input_disabled=true`，显示通关面板+最高分 |
| `GAME_OVER` | 命数=0 | `input_disabled=true`，显示结束面板+最高分 |

### 3.5 文件间信号关联图

```
Game.gd                              Player.gd
  ├─ _on_coin_collected(coin) ←──┐     ├─ _unhandled_input → 跳跃
  ├─ _on_enemy_stomped(enemy) ←──┤     ├─ _physics_process → 物理
  ├─ _on_player_hit(body) ←──────┤     ├─ hit() ← 受伤
  ├─ _on_finish_entered(body) ←──┤     └─ die()
  │                              │
  │   Coin.gd                    │   Enemy.gd
  │    ├─ body_entered ──────→───┘     ├─ body_entered ──────→───┐
  │    ├─ _physics_process             ├─ _physics_process       │
  │    │  → get_overlapping_bodies()   │  → 巡逻移动             │
  │    └─ _collect → queue_free()      └─ stomp() → queue_free() │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
    所有 Area2D 通过 body_entered 信号 → Game.gd 的事件处理方法
    Game.gd 是中心枢纽，所有游戏逻辑汇聚于此
```

### 3.6 关键参数一览

| 参数 | 值 | 说明 |
|------|----|------|
| `SPEED` | 300.0 | 玩家水平移动速度 |
| `JUMP_VELOCITY` | -530.0 | 起跳初速度（向上为负） |
| `GRAVITY` | 1100.0 | 重力加速度 |
| `invincible_timer` | 1.5s | 受伤后无敌时间 |
| `patrol_range` | 100-250 | 敌人左右巡逻范围 |
| `GROUND_Y` | 550 | 地面 Y 坐标 |
| `LEVEL_WIDTH` | 1632 | 关卡总宽度 |
| 跳跃高度 | ≈128px | `530²/(2×1100)` |
| 踩头弹跳 | -380 | 踩到敌人后弹起速度 |
| 受伤击退 | -250 + 反向200 | 受伤后弹开 |

---

## 4. 核心实现

### 4.0 新增功能概览

| 功能 | 位置 | 说明 |
|------|------|------|
| 暂停系统 | `Game.gd _unhandled_input` / `_toggle_pause()` | ESC 暂停/恢复，`get_tree().paused` 冻结物理，圆角面板 overlay |
| 最高分持久化 | `Game.gd _load_high_score()` / `_save_high_score()` | `ConfigFile` 读写 `user://high_score.cfg` |
| 自定义 Camera lerp | `Game.gd _process` | `camera.position.lerp(player, 12*delta)` 替代内置 Smoothing |
| 飘字得分特效 | `Game.gd _spawn_floating_text()` | Tween 驱动 "+1"/"+2"/"-1❤️" 上下飘 + 淡出 |
| HUD 样式升级 | `Game.gd _create_hud()` | StyleBoxFlat 圆角面板 + Emoji 图标 (❤️🖤🪙👑) |
| 菜单重做 | `Game.gd _create_menu()` | 星光背景、圆角卡片面板、最高分展示 |
| 场景深色背景 | `Game.gd _create_world()` | `RenderingServer.set_default_clear_color` + WorldSkyBG 防白闪 |

### 4.0.1 玩家新增特性

| 特性 | 位置 | 说明 |
|------|------|------|
| 朝向翻转 | `Player.gd` `facing_right` + `flip` 系数 | `_draw` 中所有 x 坐标乘以 `flip` 实现左右镜像 |
| 红色围巾 | `Player.gd _draw` 领口 | `draw_rect(Rect2(-6, 2, 12, 3), Color(0.95, 0.25, 0.25))` |
| 智能重绘 | `Player.gd _physics_process` | `needs_redraw` 标志，仅 alpha/朝向变化时才 `queue_redraw()` |

### 4.0.2 金币重做

| 特性 | 位置 | 说明 |
|------|------|------|
| 浮动动画 | `Coin.gd _physics_process` | `sin(anim_time) * 3.5` 上下浮动，碰撞体同步移动 |
| 椭圆绘制 | `Coin.gd _draw_ellipse()` | 16 段多边形绘制椭圆，防负半径白闪 |
| 旋转拉伸 | `Coin.gd _draw` | `abs(cos(anim_time * 0.75))` 模拟金币旋转 |
| 双保险碰撞 | `Coin.gd _physics_process` | `body_entered` 信号 + `get_overlapping_bodies()` 主动检测 |
| 安全禁用 | `Coin.gd _collect()` | `set_deferred("disabled", true)` 线程安全关闭碰撞 |
| 收集动画 | `Coin.gd _collect()` | 向上飞 30px + 放大 + 淡出 |

### 4.0.3 敌人重绘

| 特性 | 说明 |
|------|------|
| 蘑菇外观 | `draw_circle` 头部 + `draw_rect` 身体组成红头菇轮廓 |
| 阴影 | `draw_ellipse_custom()` 绘制脚底椭圆阴影 |
| 大白眼 + 瞳孔 | 白色大眼眶 + 黑色瞳孔随移动方向偏移 |
| 愤怒眉毛 | `draw_line` 画出愤怒表情 |

### 4.1 玩家绘制（`Player._draw`）

使用 Godot 的 `_draw()` 方法通过基本图形绘制造型，支持朝向翻转：

```
         ╭────╮              ← 头盔（半圆）
        ╱  ●●  ╲             ← 头部 + 眼睛（随朝向偏移）
        │  ◡   │             ← 嘴巴
        │█ ████│             ← 身体 + 红色围巾
       ┌┴──────┴┐            ← 手臂
       │  ██    │            ← 腿
       └────────┘            ← 鞋子（随朝向微调）
```

**朝向翻转**: `facing_right` 变量控制 `flip = ±1`，所有 x 坐标乘以 flip 实现左右镜像。
**按需重绘**: `needs_redraw` 标志——只有 alpha 变（无敌闪烁）或朝向变时才 `queue_redraw()`，
不再每帧无脑重绘。

所有绘制基于局部坐标，与碰撞体对齐。

### 4.2 跳跃判定

```gdscript
# Player.gd _unhandled_input
if event.is_action_pressed("ui_accept") or
   (event is InputEventKey and event.pressed and not event.echo and
    (event.keycode == KEY_W or event.keycode == KEY_UP)):
    if is_on_floor():
        velocity.y = JUMP_VELOCITY
```

使用 `_unhandled_input` 而非 `_physics_process` 来检测跳跃，避免物理帧率不稳定导致
跳跃输入丢失的问题。

### 4.3 输入守卫链

Player 的 `_unhandled_input` 和 `_physics_process` 有统一的守卫逻辑：

```
_unhandled_input:  is_dead → input_disabled → just_spawned → is_on_floor() → 跳
_physics_process:  is_dead → input_disabled → (just_spawned 在本帧清除) → 移动
```

- `is_dead`: 玩家死亡后不响应任何输入
- `input_disabled`: WON/GAME_OVER 状态时禁用（由 Game.gd 设置）
- `just_spawned`: 开局第一帧阻止输入，防止开始菜单的 Space 键带到游戏中

### 4.4 无敌帧实现

受伤后 1.5 秒无敌，通过闪烁（半透明 / 不透明交替）反馈：

```gdscript
modulate.a = 0.5 if int(invincible_timer * 10) % 2 == 0 else 1.0
```

闪烁频率约为 5Hz（100ms 切换一次）。

### 4.5 窗口失焦保护

```gdscript
func _notification(what):
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        Input.flush_buffered_events()
```

防止窗口失焦后 KeyDown 状态残留导致角色"卡方向"。

### 4.6 安全的闪烁效果

不用 `create_tween().set_loops()`（会导致引用已释放节点时程序未响应），改用 `_process` 驱动：

```gdscript
func _blink_step(delta):
    if not overlay_hint: return
    blink_timer += delta
    if blink_timer > 0.6:
        blink_timer = 0.0
        blink_visible = not blink_visible
        overlay_hint.modulate.a = 0.9 if blink_visible else 0.3
```

---

## 5. 碰撞系统详解

### 5.1 图层分配表

| 节点 | `collision_layer` | `collision_mask` | 说明 |
|------|--------------------|-------------------|------|
| Player (CharacterBody2D) | 1 (默认) | **3** (1+2) | 必须含图层1和2才能撞到地面+平台 |
| Ground (StaticBody2D) | **1** | — | 实地 |
| Platform (StaticBody2D) | **2** (显式传参) | — | 单向平台（只能从上方站住） |
| Coin (Area2D) | 1 | **1** | 检测玩家进入 |
| Enemy (Area2D) | 1 | **1** | 检测玩家进入；踩头用位置判定 |
| Finish (Area2D) | 1 | **1** | 检测玩家到达终点 |

### 5.2 单向平台机制

Godot 4 中，`CharacterBody2D.move_and_slide()` 支持 `platform_floor_layers` 属性：

```gdscript
# Player.gd _ready()
collision_mask = 3          # 图层1(地面) + 图层2(平台)
platform_floor_layers = 2    # 图层2的 StaticBody2D 作为单向地板
```

**效果**：
- 玩家从上方落到平台上 → 站住
- 玩家从下方穿过平台 → 无碰撞
- 地面 (图层1) 始终是实心

**创建平台时**（Game.gd）：

```gdscript
# 地面（实心）
_add_static_rect(x, y, w, h, color, 1)

# 平台（单向地板）
_add_static_rect(x, y, w, h, color, 2)
```

### 5.3 踩头判定

```
踩头条件 = (下落中 + 玩家底部 ≤ 敌人顶部 + 16px) 或 (上一帧玩家底部 ≤ 敌人顶部 + 4px)
```

```gdscript
# Enemy.gd _on_body_entered
var player_bottom = body.position.y + 18        # 玩家碰撞体底部
var prev_player_bottom = body.prev_position_y + 18  # 上一帧底部
var enemy_top = position.y - 12                 # 敌人碰撞体顶部

var stomp_from_fall = body.velocity.y >= 0 and player_bottom <= enemy_top + 16
var stomp_from_above = prev_player_bottom <= enemy_top + 4

if stomp_from_fall or stomp_from_above:
    # 踩头成功 → 敌人消失 + 玩家弹跳
else:
    # 玩家受伤
```

- `stomp_from_fall`: 玩家在下落且底部在敌人顶部 16px 以内（≈960px/s 下落速度都能捕获）
- `stomp_from_above`: 玩家上一帧在敌人顶部 4px 以内（捕获极速下落漏判，需要 Player 记录 `prev_position_y`）

---

## 6. Bug 修复记录

### 6.1 ❌ 程序未响应（Freeze）

| 项目 | 内容 |
|------|------|
| **症状** | 游戏启动几秒后窗口灰掉，任务管理器显示"未响应" |
| **根因** | `create_tween().set_loops()` 无限循环 Tween 引用已 `queue_free` 的节点 |
| **修复** | 删除所有 `set_loops()`，改用 `_process` + `blink_timer` 驱动闪烁 |
| **涉及文件** | `Game.gd` |

### 6.2 ❌ 镜头不跟随

| 项目 | 内容 |
|------|------|
| **症状** | 游戏开始后玩家不在画面内（镜头在原点） |
| **根因** | Camera2D `position_smoothing_enabled=true`，从 (0,0) 平滑到玩家耗时过长 |
| **修复** | 创建玩家后关平滑→瞬移→开平滑；每帧强制 `camera.position = player.position` |
| **涉及文件** | `Game.gd` |

### 6.3 ❌ 平台无物理

| 项目 | 内容 |
|------|------|
| **症状** | 玩家直接穿过浮空平台 |
| **根因** | Player 的 `collision_mask = 1`（只含地面图层1），平台在图层2 |
| **修复** | `collision_mask = 3`（图层1+2）+ `platform_floor_layers = 2` |
| **涉及文件** | `Player.gd` |

### 6.4 ❌ 踩敌人自己受伤

| 项目 | 内容 |
|------|------|
| **症状** | 快速下落踩敌人时判定为玩家受伤 |
| **根因** | 踩头容差仅 8px，极速下落一帧内位移超过此值 |
| **修复** | 增强为双条件判定：16px 位置容差 + 上一帧位置追踪 |
| **涉及文件** | `Enemy.gd`, `Player.gd` |

### 6.5 ❌ 开局自动起跳

| 项目 | 内容 |
|------|------|
| **症状** | 按空格开始游戏后角色立即跳起 |
| **根因** | 菜单按 Space → `_start_game` → 创建 Player → 同一事件仍被 `_unhandled_input` 收到 |
| **修复** | 添加 `just_spawned` 标志位，首帧 `_physics_process` 清除前阻止所有输入 |
| **涉及文件** | `Player.gd` |

### 6.6 ❌ 窗口失焦后方向卡死

| 项目 | 内容 |
|------|------|
| **症状** | 切窗再切回游戏，角色一直往右走 |
| **根因** | `Input.get_axis` 读取按键状态，焦点丢失后 KeyUp 事件丢失，KeyDown 状态残留 |
| **修复** | 监听 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` → `Input.flush_buffered_events()` |
| **涉及文件** | `Player.gd` |

### 6.7 ❌ 通关/结束界面角色仍可移动

| 项目 | 内容 |
|------|------|
| **症状** | 弹出"通关"/"游戏结束"画面后角色仍可左右移动 |
| **根因** | HUD 只是显示文字，未禁用玩家输入 |
| **修复** | `player_node.input_disabled = true` |
| **涉及文件** | `Player.gd`, `Game.gd` |

---

## 7. 构建打包

### 7.1 导出预设配置

`export_presets.cfg` 必须满足以下格式要求（Godot 4）：

- `platform` 字段值必须是 `"Windows Desktop"`（与预设名一致）
- 所有空字符串值必须写 `""` 而非空（否则解析器报错）
- 布尔值写 `true`/`false`，无需引号
- `[preset.N]` 和 `[preset.N.options]` 两个 section 缺一不可

关键选项：

```cfg
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
export_filter="all_resources"
export_path="build/game.exe"

[preset.0.options]
binary_format/embed_pck=true          # 将 PCK 嵌入 exe
texture_format/s3tc=true
texture_format/bptc=true
```

### 7.2 命令行导出

```powershell
# Release 模式（推荐）
& godot_console.exe --headless --path "D:\godot-test-project" --export-release "Windows Desktop"

# Debug 模式（含调试符号，文件更大）
& godot_console.exe --headless --path "D:\godot-test-project" --export-debug "Windows Desktop"
```

导出产物：
- `build/game.exe` — 单文件独立可执行（≈ 104 MB）

### 7.3 语法检查

```powershell
& "$env:LOCALAPPDATA\Godot\godot_console.exe" --headless `
    --path "D:\godot-test-project" --script "Player.gd" --check-only
```

### 7.4 冒烟测试流程

1. 启动游戏 → 按空格开始
2. 左右移动 → 跳跃 → 踩浮空平台（验证从下方穿过）
3. 踩敌人 → 验证踩头判定
4. 被敌人撞 → 验证受伤击退 + 无敌闪烁
5. 收集金币 → 验证 HUD 加分
6. 3 条命耗尽 → 验证 Game Over
7. 到达终点 → 验证通关
8. 按空格返回菜单 → 循环正常
9. **切窗再切回** → 验证方向不卡死

---

## 8. 开发心得

### 8.1 Godot 4 的头文件/引用机制

Godot 4 的 GDScript 用 `preload()` 来引用其他脚本作为类型：

```gdscript
const Coin = preload("res://Coin.gd")
const Enemy = preload("res://Enemy.gd")
const Player = preload("res://Player.gd")
```

这些 `const` 声明必须放在顶层（全局作用域），不能在函数内部。
`preload` 的结果可以直接调用 `.new()` 创建实例。

### 8.2 Area2D vs CharacterBody2D 碰撞

- **CharacterBody2D** 通过 `move_and_slide()` 进行物理移动，`is_on_floor()` 检测接地。
- **Area2D** 用于触发区域，通过 `body_entered` 信号检测其他 PhysicsBody 进入。
- 两者要能互相检测，**必须设置 `collision_mask` / `collision_layer`**。
  新手容易踩的坑：Area2D 的 `collision_mask` 默认为 0，什么都不检测。

### 8.3 CharacterBody2D 的 `platform_floor_layers`

Godot 4 新增属性，指定哪些图层的 StaticBody2D 作为"单向地板"：

- 默认值 `0` = 没有单向地板，所有 StaticBody2D 都是实心碰撞
- 设为 `2` = 图层 2 的 StaticBody2D 只从上方站住，下方穿过
- 与 `collision_mask` 配合使用：`collision_mask` 决定能撞到哪些层，
  `platform_floor_layers` 决定哪些层是单向的

**常见错误**：
- `collision_mask = 1` + `platform_floor_layers = 2` → 检测不到图层2，无法站上平台
- 正确: `collision_mask = 3` + `platform_floor_layers = 2`

### 8.4 输入处理的选择

| 方法 | 适用场景 | 注意 |
|------|---------|------|
| `_input(event)` | 所有输入事件，UI 之前 | 可能被 UI 截断 |
| `_unhandled_input(event)` | 未被 UI 消费的输入 | ✅ 适合游戏操作 |
| `Input.is_action_just_pressed()` | 在 `_process` 中轮询 | 可能在物理帧中跳帧 |
| `Input.get_axis()` | 连续输入（方向） | ✅ 适合左右移动 |

本项目中：
- **跳跃**用 `_unhandled_input`（一次触发，精确响应）
- **左右移动**用 `Input.get_axis()` + `_physics_process`（连续状态）

### 8.5 Tween 安全使用

**不要**在会 `queue_free` 的节点上创建 `set_loops()` 的 Tween。
Tween 会持有对被动画属性的引用，节点释放后 Tween 系统内部写出错。

安全做法：
- 一次性动画（收集金币放大、受伤闪红）：用 `create_tween()`，不设循环
- 循环闪烁：用 `_process` + 计时器变量

### 8.6 导出配置的坑

Godot 4 的 `export_presets.cfg` 格式是 INI 风格，但比标准 INI 严格：

| 错误写法 | 正确写法 |
|---------|---------|
| `platform="windows"` | `platform="Windows Desktop"` |
| `patch_list=` | `patch_list=""` |
| `application/timestamp=tools` | `application/timestamp="0"` |

使用 Godot 编辑器的"导出"对话框生成配置是最稳妥的方式，
如果必须手动写，用 `--export-release` 验证。

### 8.7 碰撞体与视觉对齐

- Player 的 `_draw()` 和 CollisionShape2D 都以节点原点 (0,0) 为中心
- 地面 StaticBody2D 用子节点 ColorRect 作为视觉，偏移计算：`position = (-w/2, -h/2)`
- 每次修改 `_draw()` 后调用 `queue_redraw()` 触发重绘

### 8.8 菜单系统

游戏启动进入菜单状态 (`GameState.MENU`)，使用纯代码创建 UI：

1. **菜单画面**：深蓝背景 + 星光装饰 + 圆角卡片面板 + 最高分展示 + 操作说明子面板 + 闪烁的"按空格键开始"
2. **游戏中**：左上角 HUD（圆角半透明 StyleBoxFlat 面板），🪙金币/❤️❤️❤️生命分/👑最高分，按空格/W/↑跳跃，←→移动，ESC 暂停
3. **通关/结束**：弹出圆角面板 + 得分 vs 最高分对比 + 刷新纪录提示 + 闪烁的返回提示
4. **按空格**：回到菜单，循环

所有 UI 元素在状态切换时通过 `queue_free()` 清理，避免内存泄漏。

### 8.10 Camera 平滑的两种方式对比

| 方式 | 代码 | 问题 | 适用 |
|------|------|------|------|
| 内置 `position_smoothing_enabled` | `cam.position_smoothing_enabled = true` | 与每帧强制赋值竞争，画面抖动 | 纯配置场景 |
| 自定义 `lerp` ✅ | `camera.position = camera.position.lerp(player.position, 12 * delta)` | — | 每帧强制追赶玩家的场景 |

本项目当前使用自定义 lerp（用户优化），移除了内置 smoothing 和相关 hack。

### 8.11 纯代码绘制进阶技巧

- **组合绘图**: `draw_circle` + `draw_rect` + `draw_line` 组合复杂形状
- **椭圆绘制**: `draw_polygon` + 16 段角度采样，注意 `rx/ry` 不能为负（OpenGL 白闪）
- **阴影**: 半透明椭圆 `draw_ellipse_custom` 增加立体感
- **表情**: `draw_line` 画眉毛表达情绪
- **Emoji**: Godot 原生渲染 ❤️🖤🪙👑，零资源视觉提升

### 8.9 关卡布局

地面连续平坦，贯穿全景。8 个浮空平台形成阶梯式上升路线：

| 平台 | 中心坐标 | 间距 | 能否跳到 |
|------|---------|------|---------|
| A | (300, 488) | 地面→A ≈62px | ✓ |
| 1 | (400, 428) | 地面→1 ≈112px | ✓ (≤128) |
| B | (750, 458) | 中间辅助 | — |
| 2 | (650, 383) | 1→2 ≈35px | ✓ |
| C | (1100, 408) | 中间辅助 | — |
| 3 | (900, 338) | 2→3 ≈45px | ✓ |
| 4 | (1150, 293) | 3→4 ≈45px | ✓ |
| 5 | (1400, 248) | 4→5 ≈45px | ✓ |

跳跃高度 ≈ 128px，所有平台间距均在此范围内。

---

## 附录

### 完整文件清单

```
D:\godot-test-project\
├── build\game.exe           (104 MB, 独立可执行文件)
├── AGENTS.md                (AI 开发上下文文档)
├── Game.gd                  (406 lines, 主游戏逻辑)
├── Game.tscn                (0.2 KB, 场景入口)
├── Player.gd                (121 lines, 玩家控制)
├── Coin.gd                  (40 lines, 金币)
├── Enemy.gd                 (90 lines, 敌人)
├── project.godot            (0.1 KB, 项目配置)
├── export_presets.cfg       (1.5 KB, 导出预设)
└── README.md                (本文件)
```

### Changelog

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-29 | **用户大规模优化** — 暂停+最高分+飘字+菜单重做(星光/卡片/StyleBoxFlat)+HUD升级(Emoji+面板)+Camera自定义lerp+金币重做(浮动动画+椭圆绘制+双保险碰撞)+玩家朝向翻转+智能重绘+蘑菇怪重绘+场景深色背景防白闪 |
| v0.6 | 2026-07-29 | 修复：碰撞_mask + 踩头容差 + 焦点失锁 + 掉落死亡安全网 |
| v0.5 | 2026-07-29 | 修复：平台物理、踩头判定、窗口失焦卡方向、开局自动跳 |
| v0.4 | 2026-07-29 | 修复：infinite tween 未响应、镜头不跟随 |
| v0.3 | 2026-07-29 | 添加：浮空平台（单向地板）、菜单/通关/结束 UI |
| v0.2 | 2026-07-29 | 添加：金币、敌人、踩头判定、生命系统 |
| v0.1 | 2026-07-29 | 初始 Demo：玩家移动、跳跃、绘制 |
