# 系统音量键与音频驱动管理实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 使用 macOS 原生音量键控制 SnapClick 虚拟输出，并在“设置 → 其他”管理音频驱动安装状态。

**架构：** libASPL 在虚拟输出流上提供标准主音量和静音控制并直接处理样本；App 的 HAL 转发器保持单位增益，将处理后的音频转发到内建扬声器或外接显示器。`SoftwareVolumeController` 作为安装状态与生命周期唯一真相源，设置页观察其状态。

**技术栈：** Swift 5.9、SwiftUI、CoreAudio、AudioToolbox、C++17、libASPL、AudioServerPlugIn

---

## 文件结构

- `SnapClickAudioDriver/Driver.cpp`：为虚拟输出流添加标准音量和静音控制。
- `SnapClick/Core/SoftwareVolumeController.swift`：公开安装状态、安装/卸载动作并维持物理输出转发。
- `SnapClick/UI/MainWindow.swift`：在“其他”设置中显示驱动状态和安装/卸载按钮。
- `SnapClick/UI/StatusBarController.swift`：删除状态栏音量菜单项。
- `SnapClick/Core/AppSettings.swift`：增加设置行本地化文本。
- `scripts/test_audio_driver_contract.sh`、`scripts/test_software_volume_controller_contract.sh`、`scripts/test_volume_menu_contract.sh`：覆盖新行为。

### 任务 1：驱动原生音量与静音控制

**文件：** 修改 `scripts/test_audio_driver_contract.sh`、`SnapClickAudioDriver/Driver.cpp`

- [ ] **步骤 1：编写失败测试**：要求输出流调用 `AddStreamWithControlsAsync(outputParameters)`，输入回读流继续使用 `AddStreamAsync(inputParameters)`。
- [ ] **步骤 2：运行红灯**：`bash scripts/test_audio_driver_contract.sh`，预期因缺少 `AddStreamWithControlsAsync` 失败。
- [ ] **步骤 3：最小实现**：把输出流创建改为 `device->AddStreamWithControlsAsync(outputParameters)`；不在 App 转发回调中增加第二套增益。
- [ ] **步骤 4：运行绿灯**：重跑驱动契约，并执行 `scripts/build_audio_driver.sh`，预期契约通过且生成双架构驱动。
- [ ] **步骤 5：提交**：`git commit -m "feat: expose native audio volume controls"`。

### 任务 2：安装状态与安全卸载

**文件：** 修改 `scripts/test_software_volume_controller_contract.sh`、`SnapClick/Core/SoftwareVolumeController.swift`

- [ ] **步骤 1：编写失败测试**：要求公开 `isDriverInstalled`、`install()`、`uninstall()`；卸载顺序包含 `restoreAndStop()`、管理员删除系统驱动、`killall coreaudiod`、重新检测状态。
- [ ] **步骤 2：运行红灯**：`bash scripts/test_software_volume_controller_contract.sh`，预期缺少卸载 API。
- [ ] **步骤 3：最小实现**：状态机保留现有安装/启动状态；新增卸载中状态；安装和卸载结束均以磁盘路径刷新状态；卸载前恢复物理默认输出，授权取消进入失败状态。
- [ ] **步骤 4：运行绿灯**：重跑控制器契约和 `xcrun swift scripts/test_software_volume_policy.swift SnapClick/Core/SoftwareVolumePolicy.swift`。
- [ ] **步骤 5：提交**：`git commit -m "feat: manage audio driver lifecycle"`。

### 任务 3：设置行与状态栏清理

**文件：** 修改 `scripts/test_volume_menu_contract.sh`、`SnapClick/UI/StatusBarController.swift`、`SnapClick/UI/MainWindow.swift`、`SnapClick/Core/AppSettings.swift`；删除 `SnapClick/UI/VolumeMenuItemView.swift`

- [ ] **步骤 1：编写失败测试**：断言状态栏无音量自定义 view；“其他”设置包含“音频驱动”、已安装/未安装状态和安装/卸载按钮，并绑定控制器。
- [ ] **步骤 2：运行红灯**：`bash scripts/test_volume_menu_contract.sh`，预期旧菜单项仍存在。
- [ ] **步骤 3：最小实现**：删除菜单项和 view；`OtherSettingsView` 观察控制器并添加一行，状态标签来自实际安装状态，按钮根据状态调用安装或卸载，处理中禁用。
- [ ] **步骤 4：本地化**：增加中文、英文和日文对应文案，错误通过 SwiftUI alert 显示。
- [ ] **步骤 5：运行绿灯**：运行全部音频契约脚本与 Debug unsigned build。
- [ ] **步骤 6：提交**：`git commit -m "feat: add audio driver settings control"`。

### 任务 4：签名产物与真实设备验收

**文件：** 生成 `build/DerivedData/Build/Products/Release/SnapClick.app`、`dist/SnapClick.dmg`

- [ ] **步骤 1：签名 Release 构建**：运行项目 `AGENTS.md` 中带 `DEVELOPMENT_TEAM=HQ6YY6QF8H` 的 Release 命令，预期 `BUILD SUCCEEDED`。
- [ ] **步骤 2：验证签名和架构**：对 App、Finder 扩展、音频驱动运行 `codesign --verify --deep --strict`，并用 `lipo -archs` 确认 `x86_64 arm64`。
- [ ] **步骤 3：打包并验证 DMG**：运行 `scripts/build_dmg.sh`、`hdiutil verify`、`shasum -a 256`。
- [ ] **步骤 4：人工验收**：分别选择内建扬声器与外接显示器，验证音量加减、静音、热插拔、App 重启、驱动卸载和默认输出恢复。
- [ ] **步骤 5：在人工验收前不推送**。
