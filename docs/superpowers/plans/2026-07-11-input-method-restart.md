# 当前输入法重启实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在“设置 → 其他”自动显示当前第三方输入法，并提供可靠的“重启输入法”按钮。

**架构：** 复用 `InputSourceController` 的 TIS 监听和输入源属性读取能力，在控制器中公开当前可重启输入法状态与重启命令。SwiftUI 只负责状态展示和触发操作。

**技术栈：** Swift、SwiftUI、Carbon Text Input Sources、AppKit `NSWorkspace`、shell 合约测试

---

### 任务 1：第三方输入法识别与重启

**文件：**
- 修改：`SnapClick/Core/InputSourceController.swift`
- 创建：`scripts/test_input_method_restart_contract.sh`

- [ ] **步骤 1：编写失败的合约测试**

验证控制器读取 `kTISPropertyBundleID`、限制 Input Methods 目录、终止 Bundle ID 对应进程、重启 `imklaunchagent` 并重新打开输入法 App。

- [ ] **步骤 2：运行测试验证失败**

运行：`bash scripts/test_input_method_restart_contract.sh`
预期：FAIL，因为控制器尚未包含当前第三方输入法状态和重启方法。

- [ ] **步骤 3：实现最小控制器逻辑**

增加 `RestartableInputMethod`、`currentRestartableInputMethod`、`isRestartingInputMethod`、`inputMethodRestartError` 和 `restartCurrentInputMethod()`。输入源变化监听复用现有通知回调刷新状态；重启只匹配输入法 Bundle ID，不终止普通应用或 Finder 扩展。

- [ ] **步骤 4：运行测试验证通过**

运行：`bash scripts/test_input_method_restart_contract.sh`
预期：输出 `input method restart contract passed`。

- [ ] **步骤 5：提交控制器变更**

```bash
git add SnapClick/Core/InputSourceController.swift scripts/test_input_method_restart_contract.sh
git commit -m "feat: restart current third-party input method"
```

### 任务 2：其他设置页按钮

**文件：**
- 修改：`SnapClick/UI/MainWindow.swift`
- 修改：`SnapClick/Core/AppSettings.swift`
- 创建：`scripts/test_input_method_restart_ui_contract.sh`

- [ ] **步骤 1：编写失败的 UI 合约测试**

验证 `OtherSettingsView` 观察 `InputSourceController.shared`，显示当前输入法名称和“重启输入法”按钮，并在处理中禁用按钮。

- [ ] **步骤 2：运行测试验证失败**

运行：`bash scripts/test_input_method_restart_ui_contract.sh`
预期：FAIL，因为“其他”卡片尚无输入法行。

- [ ] **步骤 3：添加输入法设置行和本地化**

在音频驱动行之后加入 `InputMethodRestartRow`。没有第三方输入法时整行隐藏；错误使用现有 Alert 风格显示。补充中、英、日文案键。

- [ ] **步骤 4：运行合约和 Debug 构建**

运行：

```bash
bash scripts/test_input_method_restart_contract.sh
bash scripts/test_input_method_restart_ui_contract.sh
xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

预期：两个合约通过，构建输出 `BUILD SUCCEEDED`。

- [ ] **步骤 5：本机运行验证 WeType**

记录 WeType 和 `imklaunchagent` PID，点击按钮，确认两者 PID 更新、微信主程序 PID 不变，并确认微信输入法语音界面恢复。

- [ ] **步骤 6：提交 UI 变更**

```bash
git add SnapClick/UI/MainWindow.swift SnapClick/Core/AppSettings.swift scripts/test_input_method_restart_ui_contract.sh
git commit -m "feat: expose input method restart in settings"
```
