# 🦇 哥谭大冒险：蝙蝠侠出击 (Gotham Adventure: Batman Strikes)

![Godot 4.7](https://img.shields.io/badge/Godot-4.7.1.stable-blue?logo=godotengine&logoColor=white)
![Language](https://img.shields.io/badge/Language-GDScript-green)
![Platform](https://img.shields.io/badge/Platform-Windows_Desktop-lightgrey)

一款基于 **Godot 4** 的纯 GDScript 矢量动作平台跳跃游戏！玩家化身哥谭守护者**蝙蝠侠 (Batman)**，穿梭在哥谭夜景摩天大楼天际线上，运用飞镖战术摧毁反派企图，最终决战**小丑大 Boss (Joker Boss)**！

---

## 🎮 游戏核心特色

- 🦸‍♂️ **纯代码矢量蝙蝠侠形象**：零外部图片资源！包含动态动作相位（待机呼吸、奔跑迎风摆动斗篷、空中滑翔翼张开、护臂刺刺与红白发光双瞳）。
- 🦇 **蝙蝠飞镖攻击系统 (Batarang)**：支持鼠标“指哪打哪”精准瞄准、自旋双翼矢量绘制、击中敌/Boss 产生爆裂特效与浮动得分。
- 🃏 <b>小丑大 Boss (Joker Boss) 决战</b>：第 5 关末尾终极决战！10 点独立 HP、头顶动态血条、狂笑扑克牌弹幕、HP $\le$ 5 紫光狂暴二阶段。
- 🚩 **5 递进关卡与新手教学**：
  - **Level 1**：新手试炼关（实况标牌指导移动、跳跃、飞镖投掷与通关）。
  - **Level 2 ~ 4**：横向伸展的高空哥谭天际线关卡，难度与敌人密度陡增。
  - **Level 5**：5000px 终极关卡，决战小丑 Boss！
- 🕹️ **顶级平台手感**：内置 Coyote Time（土狼时间 0.12s）、Jump Buffer（跳跃预输入 0.12s）、Variable Jump Height（可变跳跃高度微调）。
- 👑 **毛玻璃 HUD & 本地最高分**：使用 `ConfigFile` 自动持久化本地最高分，支持 `ESC` 暂停菜单（一键重新开始 / 返回主菜单）。

---

## 🕹️ 操纵指南 (Controls Handbook)

| 操作项目 | 按键 / 输入 | 说明 |
|---------|------------|------|
| **左右移动** | `A` / `D` 或 `←` / `→` | 水平移动（自动触发奔跑腿部与斗篷动画） |
| **跳跃 / 攀爬** | `Space` 空格 / `W` / `↑` | 轻按小跳，长按大跳；离台 0.12s 内仍可起跳 |
| **发射蝙蝠飞镖** | `鼠标左键` 或 `J` / `K` | 朝鼠标点击方位或角色朝向发射蝙蝠飞镖 |
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
├── Player.gd           # 蝙蝠侠角色物理、矢量绘制与手感控制
├── Boss.gd             # 小丑大 Boss AI (10 HP、血条、二阶段与击败爆裂)
├── JokerCard.gd        # 小丑狂笑扑克牌弹幕节点
├── Batarang.gd         # 蝙蝠飞镖 Area2D 子弹节点
├── Enemy.gd            # 蘑菇怪敌人巡逻 AI 与矢量绘制
├── FlyEnemy.gd         # 蝙蝠飞行敌人 AI
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

## 🛠️ 面向 AI Agent / 开发者后续维护

若您是 AI 助手或项目新维护者，在编写与扩充代码前，请必须阅读 **[AGENTS.md](file:///d:/godot-test-project/AGENTS.md)**：
- 里面详细记载了**碰撞图层矩阵 (Collision Layers)**、**GUI `mouse_filter` 拦截规范**、**偶发白闪与幽灵帧防御法则**、以及**全自动测试标准 (`TestRunner.gd`)**。
