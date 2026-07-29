---
description: 打包 EXE（先杀残留进程，再导出 Release）
---

停止残留游戏进程，然后执行 `--export-release` 打包 `build/game.exe`。

## 步骤

1. **杀残留进程**：
   ```powershell
   Stop-Process -Name "game" -Force -ErrorAction SilentlyContinue
   ```

2. **打包**：
   ```powershell
   & "$env:LOCALAPPDATA\Godot\godot_console.exe" --headless `
       --path "D:\godot-test-project" `
       --export-release "Windows Desktop" "build/game.exe"
   ```

3. **验证**：
   ```powershell
   Get-Item "build/game.exe" | Select-Object Length, LastWriteTime
   ```
