# 混合系统音量控制实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 用仅输出虚拟设备恢复 macOS 控制中心音量拖拽点，同时继续用 Process Tap 将音频可靠送往真实设备，并在状态栏菜单提供同步音量滑条。

**架构：** `SnapClick Control Output` 只发布双声道输出、主音量和静音控制，不发布输入流；控制器保存真实输出后启动 Tap/AUHAL，再把默认输出切到控制设备。系统控制、键盘和菜单滑条统一写入控制设备并同步到原子软件增益，所有停止和错误路径先恢复真实输出。

**技术栈：** Swift、AppKit、CoreAudio Process Tap、AudioServerPlugIn/libASPL、C11 atomics、SwiftUI、shell contract tests

---

### 任务 1：恢复仅输出控制驱动

**文件：**
- 恢复：`ThirdParty/libASPL/**`
- 创建：`SnapClickAudioDriver/Driver.cpp`
- 创建：`SnapClickAudioDriver/Info.plist`
- 创建：`scripts/build_audio_driver.sh`
- 修改：`scripts/test_audio_driver_contract.sh`

- [ ] **步骤 1：编写失败合约**，要求设备 UID `com.snapclick.audio.control`、`AddStreamWithControlsAsync`、Volume/Mute controls，并禁止 `Direction::Input`、`AddStreamAsync(input` 和虚拟输入 UID。
- [ ] **步骤 2：运行 `bash scripts/test_audio_driver_contract.sh`**，确认因驱动缺失失败。
- [ ] **步骤 3：从提交 `5cc02a2^` 恢复 libASPL 和构建脚本骨架**；将驱动缩减为一个 `Direction::Output` 流，不注册 IO 回读处理器或输入流。
- [ ] **步骤 4：运行 `ARCHS="arm64 x86_64" scripts/build_audio_driver.sh`**，用 `lipo -archs` 验证双架构，用 `nm` 验证 `SnapClickAudioEntryPoint`。
- [ ] **步骤 5：运行驱动合约并提交**：`git commit -m "feat: add output-only volume control driver"`。

### 任务 2：驱动内嵌、签名和安装生命周期

**文件：**
- 修改：`SnapClick.xcodeproj/project.pbxproj`
- 修改：`SnapClick/Core/SoftwareVolumeController.swift`
- 修改：`.github/workflows/build.yml`
- 修改：`AGENTS.md`
- 修改：`scripts/test_audio_driver_contract.sh`

- [ ] **步骤 1：扩展失败合约**，要求 Xcode Release App 内嵌 `SnapClickAudio.driver`，安装器验证 bundle id/signature，安装路径固定为 `/Library/Audio/Plug-Ins/HAL/SnapClickAudio.driver`。
- [ ] **步骤 2：运行合约确认失败**。
- [ ] **步骤 3：恢复 Xcode 驱动构建 phase；Release 使用 App 相同签名身份，Debug compile-only 允许 ad-hoc/unsigned。**
- [ ] **步骤 4：实现安装/卸载**：管理员授权复制或删除驱动、设置权限、重启 `coreaudiod`、等待控制设备出现；任何步骤都不读取或写入默认输入。
- [ ] **步骤 5：更新 CI 与项目发行规则**，验证 App、Finder 扩展和驱动的 Identifier/TeamIdentifier。
- [ ] **步骤 6：运行驱动合约和 Debug 构建并提交**：`git commit -m "feat: manage signed volume control driver"`。

### 任务 3：混合输出状态机

**文件：**
- 修改：`SnapClick/Core/SystemAudioDevice.swift`
- 修改：`SnapClick/Core/SoftwareVolumeController.swift`
- 修改：`scripts/test_system_audio_device_contract.sh`
- 修改：`scripts/test_software_volume_controller_contract.sh`

- [ ] **步骤 1：编写失败合约**，覆盖 `controlOutputID`、保存真实输出 UID、启动 Tap 后切默认输出、停止前恢复真实输出、忽略自身默认输出通知、禁止默认输入 API。
- [ ] **步骤 2：运行两个合约确认失败**。
- [ ] **步骤 3：在 `SystemAudioDevice` 添加控制设备查找、主音量/静音读写及属性监听；所有 API 明确使用 output scope。**
- [ ] **步骤 4：控制器启动顺序固定为：真实输出 → Tap/AUHAL → 音量监听 → 控制设备默认输出；停止顺序反向且恢复真实输出在销毁 Tap 之前。**
- [ ] **步骤 5：加入 `isChangingDefaultOutput` 和串行重启门控；控制设备通知只同步增益，真实设备通知才更新物理目标。**
- [ ] **步骤 6：运行合约、C 环形缓冲测试和 Debug 构建并提交**：`git commit -m "feat: route system volume through control output"`。

### 任务 4：系统音量、键盘和菜单滑条同步

**文件：**
- 修改：`SnapClick/Core/HotkeyManager.swift`
- 修改：`SnapClick/Core/SoftwareVolumeController.swift`
- 修改：`SnapClick/UI/StatusBarController.swift`
- 创建：`SnapClick/UI/VolumeMenuItemView.swift`
- 修改：`SnapClick.xcodeproj/project.pbxproj`
- 修改：`scripts/test_software_volume_hotkeys_contract.sh`
- 修改：`scripts/test_volume_menu_contract.sh`

- [ ] **步骤 1：编写失败 UI 合约**，要求状态栏下拉菜单存在一条横向 `Slider(value:in:)`、扬声器图标、百分比和控制器绑定。
- [ ] **步骤 2：编写失败同步合约**，要求菜单写控制设备、驱动属性监听回写 `gain`，控制设备就绪时 HID Tap 不重复吞音量键。
- [ ] **步骤 3：运行两个合约确认失败**。
- [ ] **步骤 4：创建 `VolumeMenuItemView`，固定高度和宽度，Slider 在 active 时可用；驱动监听失败时直接调用 `setGain` 作为后备。**
- [ ] **步骤 5：把自定义 view 插入现有状态栏菜单并保持截图/录屏菜单结构不变。**
- [ ] **步骤 6：调整媒体键策略**：控制设备为默认输出时放行系统标准控制；控制设备不可用但 Tap active 时由 HID Tap 调整软件增益。
- [ ] **步骤 7：运行 UI/按键合约和 Debug 构建并提交**：`git commit -m "feat: add synchronized menu volume slider"`。

### 任务 5：恢复、真实硬件和发行验证

**文件：**
- 修改：`scripts/test_startup_preheat_contract.sh`
- 修改：`docs/superpowers/specs/2026-07-11-hybrid-system-volume-design.md`（只记录验证所得的固定行为）

- [ ] **步骤 1：增加崩溃恢复合约**，默认输出残留为控制设备时先恢复保存的真实输出，默认输入保持原 UID。
- [ ] **步骤 2：运行全部 `scripts/test_*.sh` 和 clean Debug build。**
- [ ] **步骤 3：构建签名 Release，验证 App、Finder 扩展、驱动签名和双架构。**
- [ ] **步骤 4：安装后验证 MacBook 扬声器、BenQ DisplayPort、控制中心拖拽点、实体音量键、菜单 Slider、输出切换、退出恢复和麦克风/输入法语音。**
- [ ] **步骤 5：构建并验证 `dist/SnapClick.dmg`，记录 SHA-256；用户硬件确认前不推送。**
