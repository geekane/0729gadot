# 🦇 哥谭大冒险：蝙蝠侠出击 (Gotham Adventure: Batman Strikes)

![Godot 4.7](https://img.shields.io/badge/Godot-4.7.1.stable-blue?logo=godotengine&logoColor=white)
![Language](https://img.shields.io/badge/Language-GDScript-green)
![Platform](https://img.shields.io/badge/Platform-Windows_Desktop-lightgrey)

一款基于 **Godot 4** 的纯 GDScript 矢量动作平台跳跃游戏！玩家化身哥谭守护者**蝙蝠侠 (Batman)**，穿梭在哥谭夜景摩天大楼天际线上，运用飞镖战术与近战斩击摧毁反派企图，最终决战**小丑大 Boss (Joker Boss)**！

---

## 🎮 游戏核心特色

- 🌌 **2.5D 视差纵深夜景 (ParallaxBackground)**：4 层不同视差速率的深邃哥谭夜景（月亮探照灯、远景摩天大楼窗光、中景天际线水塔与浮云、近景管道护栏），带来震撼的镜头平移纵深感！
- 🎨 **纯像素图标 (Pixel Icon) + 零 Emoji 系统**：彻底淘汰全系统 Unicode Emojis，所有 HUD 图标、按钮装饰、飘字图标、粒子特效纹理全部采用 `PixelLib.create_texture()` 生成的像素图，消除 OS 系统字体渲染差异与乱码风险！
- 🏛️ **完整高级主菜单系统**：包含开始出击、**自由关卡选择 (Level 1 ~ 5 弹窗)**、操作指南弹窗、荣誉纪录与退出游戏功能。
- 🦸‍♂️ **纯代码矢量蝙蝠侠形象**：零外部图片资源！包含动态动作相位（待机呼吸、奔跑迎风摆动斗篷、空中滑翔翼张开、起跳拉伸/落地挤压变形）。
- 🦇 **蝙蝠飞镖攻击系统 (Batarang)**：支持鼠标"指哪打哪"精准瞄准、自旋双翼矢量绘制、击中敌/Boss 产生爆裂特效与浮动得分。
- ⚔️ **近战斩击系统 (Melee Slash)**：右键触发大弧度月牙刀光，三重残影拖尾 + 金色刃辉，配备**子弹弹反 (Bullet Deflect)** 可将敌方弹幕反弹回敌人方向。
- 🃏 <b>小丑大 Boss (Joker Boss) 决战</b>：第 5 关末尾终极决战！10 点独立 HP、头顶动态血条、狂笑扑克牌弹幕、HP ≤ 5 紫光狂暴二阶段。
- 🎬 **顶级"Game Feel"打击视觉**：包含衰减式镜头震动 (Camera Shake)、清脆打击感卡肉停顿 (Hit Stop)、受击 Flash 闪白与落地烟尘颗粒。

---

## 🕹️ 操纵指南 (Controls Handbook)

| 操作项目 | 按键 / 输入 | 说明 |
|---------|------------|------|
| **左右移动** | `A` / `D` 或 `←` / `→` | 水平移动（自动触发奔跑腿部与斗篷动画） |
| **跳跃 / 攀爬** | `Space` 空格 / `W` / `↑` | 轻按小跳，长按大跳；离台 0.12s 内仍可起跳 |
| **发射蝙蝠飞镖** | `鼠标左键` 或 `J` / `K` | 朝鼠标点击方位或角色朝向发射蝙蝠飞镖 |
| **近战斩击 / 弹反** | `鼠标右键` 或 `H` | 大弧度斜向斩击，可弹反敌方弹幕 |
| **暂停 / 菜单** | `ESC` 键 | 打开/关闭暂停菜单（`R` 键重试，`M` 键主菜单） |

---

## 🚀 快速开始与游玩

### 1. 直接游玩已打包的 EXE 程序
双击运行根目录下的可执行文件：
```text
build/game.exe
```

### 2. 通过 Godot 编辑器或命令行运行项目
如果本地安装了 Godot 4.7+ 环境：

```powershell
# 命令行启动运行游戏
& "$env:LOCALAPPDATA\Godot\godot_console.exe" --path "D:\godot-test-project"
```

### 3. 构建发布打包程序 (--export-release)
执行下述命令可自动重新生成 `build/game.exe`：

```powershell
& "$env:LOCALAPPDATA\Godot\godot_console.exe" --headless --path "D:\godot-test-project" --export-release "Windows Desktop" "build/game.exe"
```

---

## 📂 项目结构指南

```text
d:\godot-test-project\
├── Game.gd             # 主游戏逻辑、关卡构建、哥谭夜景、HUD 与状态机
├── Player.gd           # 蝙蝠侠角色物理、矢量绘制、近战斩击与手感控制
├── Boss.gd             # 小丑大 Boss AI (10 HP、血条、二阶段与击败爆裂)
├── JokerCard.gd        # 小丑狂笑扑克牌弹幕节点
├── Batarang.gd         # 蝙蝠飞镖 Area2D 子弹节点
├── Enemy.gd            # 蘑菇怪敌人巡逻 AI 与矢量绘制
├── FlyEnemy.gd         # 蝙蝠飞行敌人 AI
├── FlyEnemyBullet.gd   # 飞行敌人能量子弹（支持近战弹反）
├── Coin.gd             # 浮动金币节点
├── Hazard.gd           # 地刺陷阱节点
├── MovingPlatform.gd   # 升降/巡逻移动平台节点
├── TestRunner.gd       # 800 帧全自动游玩压测与渲染快照脚手架
├── Game.tscn           # 引擎项目场景入口
├── export_presets.cfg  # Windows 打包导出预设
├── AGENTS.md           # 🤖 AI Agent 研发指南与架构踩坑知识库
└── README.md           # 📖 本用户与项目说明文档
```

---

## 🎯 关卡系统

游戏包含 **5 个关卡**，难度递增：

| 关卡 | 宽度 | 敌人 | 金币 | 特色 |
|------|------|------|------|------|
| Level 1 | 1632px | 3 | 7 | 新手入门关卡 |
| Level 2 | 2400px | 9 | 15 | 引入飞行敌人 + 移动平台 |
| Level 3 | 3200px | 16 | 20 | 密度升级，复杂平台布局 |
| Level 4 | 4000px | 20 | 25 | 高密度混合敌人 |
| Level 5 | 5000px | 25 | 30 | 终极关卡，末尾 Boss 决战 |

---

## 🔬 自动化测试

项目内置 **TestRunner.gd**（800 帧全自动游玩压测）：

```powershell
& "$env:LOCALAPPDATA\Godot\godot_console.exe" --path "D:\godot-test-project" --script "TestRunner.gd" --rendering-driver opengl3
```

- 自动收集性能数据（FPS、Physics 耗时、Draw Calls）
- 白闪检测（像素采样）、Camera 跳变检测、幽灵帧检测
- 截图快照保存至 `res://screenshots/`
- 性能报告输出至 `.monitor_snapshot.json`

---

## 🎨 像素风系统

项目使用纯代码像素绘制（`pixel_config.gd` / `pixel_lib.gd` / `pixel_background.gd`）：

- 背景（月亮、大楼、云、管道、草地）→ 像素化 ✅
- 道具（Coin、Hazard、HUD 图标）→ 像素化 ✅
- 敌人像素化（Enemy/FlyEnemy/Boss）→ 像素化 ✅
- 特效+菜单抛光（粒子像素纹理 + 全系统零 Emoji）→ 已完成 ✅
- 角色像素化（Player）：❌ 待做（当前使用程序化矢量绘制）
- 全局 NEAREST 滤波（`viewport.canvas_item_default_texture_filter`）

---

## 🛠️ 面向 AI Agent / 开发者后续维护

若您是 AI 助手或项目新维护者，在编写与扩充代码前，请必须阅读 **[AGENTS.md](file:///d:/godot-test-project/AGENTS.md)**：
- 里面详细记载了**碰撞图层矩阵 (Collision Layers)**、**节点组 (Group) 约定表**、**GUI `mouse_filter` 拦截规范**、**偶发白闪与幽灵帧防御法则**、**伤害协议 API**、以及**全自动测试标准 (`TestRunner.gd`)**。

---

## ❓ 常见问题 (Troubleshooting)

| 问题 | 可能原因 | 解决方案 |
|------|---------|----------|
| 角色穿过平台掉落 | `collision_mask` 未设 `3` | Player 必须 `collision_mask = 3`（含图层 1+2） |
| 窗口失焦后方向卡住 | 键盘事件丢失但状态残留 | 已在 Player 中监听 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 自动清理 |
| 打包 `game.tmp` 无法重命名 | `game.exe` 正在运行 | 先关闭游戏进程再打包 |
| 右键近战不生效 | HUD Panel 拦截鼠标事件 | HUD Panel 必须设 `mouse_filter = IGNORE`；Player 用 `_input()` |
| 打包 EXE 报错 | 路径或预设问题 | 确保 `export_presets.cfg` 配置正确，且输出目录存在 |
