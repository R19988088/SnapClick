# 外接显示器软件音量实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 SnapClick 状态栏菜单加入一条总音量滑条，通过自有虚拟音频设备控制固定音量的 HDMI、DisplayPort 和 USB 输出。

**架构：** 当前签名环境没有 DriverKit provisioning profile，因此执行已批准设计中的 HAL 回退路径。最小 `AudioServerPlugIn` 使用固定版本、MIT 许可的 libASPL 源码处理 HAL ABI，SnapClick 只实现双声道虚拟输出、回读环形缓冲和 App 内转发；菜单行只绑定控制器状态。

**技术栈：** Swift 5.9、AppKit、CoreAudio、AudioToolbox、C++17、AudioServerPlugIn、管理员安装、Xcode 15+

---

## 文件结构

- `SnapClick/Core/SoftwareVolumePolicy.swift`：音量钳制、设备选择和恢复决策。
- `SnapClick/Core/SystemAudioDevice.swift`：CoreAudio 设备枚举、属性读写和监听。
- `SnapClick/Core/SoftwareVolumeController.swift`：安装、默认设备切换、转发和恢复。
- `SnapClick/UI/VolumeMenuItemView.swift`：状态菜单的一条横向音量控件。
- `SnapClickAudioDriver/Driver.cpp`、`Info.plist`：双声道虚拟输出和回读 HAL 插件。
- `ThirdParty/libASPL`：固定到上游 `633e0f70203edd87d320fc5a3cae901e1363aac5` 的 MIT 许可 HAL ABI 源码；静态编入驱动，无运行时依赖。
- `scripts/test_*volume*`、`scripts/test_audio_driver_contract.sh`：可执行策略及源契约测试。
- `SnapClick.xcodeproj/project.pbxproj`、`.github/workflows/build.yml`：驱动 target、内嵌、签名和验证。

### 任务 1：纯策略与持久化音量

**文件：** 创建 `scripts/test_software_volume_policy.swift`、`SnapClick/Core/SoftwareVolumePolicy.swift`；修改 `SnapClick/Core/AppSettings.swift`、`SnapClick.xcodeproj/project.pbxproj`。

- [ ] **步骤 1：编写失败测试**，断言负数钳制为 0、大于 1 钳制为 1、虚拟设备不会成为物理目的地、保存设备存在时优先恢复。

```swift
expect(clampVolume(-0.2) == 0, "negative volume clamps to zero")
expect(clampVolume(1.2) == 1, "volume above one clamps to one")
expect(selectPhysicalOutput(saved: 7, currentDefault: 99, available: [99, 8], virtual: 99) == 8,
       "virtual output is never its own destination")
expect(restoredOutput(saved: 7, available: [7, 8], virtual: 99) == 7,
       "saved physical output is restored")
```

- [ ] **步骤 2：验证红灯**：运行 `xcrun swift scripts/test_software_volume_policy.swift SnapClick/Core/SoftwareVolumePolicy.swift`，预期缺文件或符号失败。
- [ ] **步骤 3：最小实现**：提供 `clampVolume(_:)`、`selectPhysicalOutput(saved:currentDefault:available:virtual:)`、`restoredOutput(saved:available:virtual:)`；`AppSettings.softwareOutputVolume` 默认 1.0 且写入时钳制。
- [ ] **步骤 4：验证绿灯**：重跑 Swift 测试并运行 `xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Debug CODE_SIGNING_ALLOWED=NO build`，预期测试通过及 `BUILD SUCCEEDED`。
- [ ] **步骤 5：提交**：`git commit -m "feat: add software volume policy"`，只包含上述四个文件。

### 任务 2：CoreAudio 设备访问层

**文件：** 创建 `SnapClick/Core/SystemAudioDevice.swift`、`scripts/test_system_audio_device_contract.sh`；修改工程文件。

- [ ] **步骤 1：编写失败契约测试**，要求公开 `defaultOutputID()`、`outputDeviceIDs()`、`uid(for:)`、`setDefaultOutput(_:)`、`addDefaultOutputListener(_:)`，并在写属性前调用 `AudioObjectIsPropertySettable`。
- [ ] **步骤 2：验证红灯**：运行 `bash scripts/test_system_audio_device_contract.sh`，预期报告源文件不存在。
- [ ] **步骤 3：实现封装**：用 `kAudioHardwarePropertyDefaultOutputDevice` 和 `kAudioHardwarePropertyDefaultSystemOutputDevice` 同步输出；用 `kAudioHardwarePropertyDevices` 枚举；用 `kAudioDevicePropertyDeviceUID` 识别 `com.snapclick.audio.virtual`；OSStatus 错误包含操作名和状态码。
- [ ] **步骤 4：验证绿灯**：运行契约测试及 Debug unsigned build，预期全部通过。
- [ ] **步骤 5：提交**：`git commit -m "feat: add CoreAudio device access"`。

### 任务 3：最小虚拟 HAL 驱动

**文件：** 创建 `SnapClickAudioDriver/Driver.cpp`、`SnapClickAudioDriver/Info.plist`、`scripts/test_audio_driver_contract.sh`；修改工程文件。

- [ ] **步骤 1：编写失败契约测试**，验证 bundle id `com.snapclick.audio.driver`、设备 UID `com.snapclick.audio.virtual`、工厂入口、48 kHz 双声道 Float32、IO 操作、固定容量环形缓冲和 underrun 零填充。
- [ ] **步骤 2：验证红灯**：运行 `bash scripts/test_audio_driver_contract.sh`，预期缺文件失败。
- [ ] **步骤 3：实现插件对象**：一个插件、一个设备、一个输出流和一个回读输入流。输出 IO 写预分配 SPSC 环形缓冲，输入 IO 读相同时间序列；underrun 补零，overrun 丢最旧帧。只支持 48 kHz、双声道、交错 Float32。
- [ ] **步骤 4：约束实时路径**：仅原子索引与 `memcpy`/`memset`，不分配、不加锁、不打印、不调用 Objective-C。
- [ ] **步骤 5：构建验证**：运行 `xcodebuild -project SnapClick.xcodeproj -target SnapClickAudioDriver -configuration Debug CODE_SIGNING_ALLOWED=NO build` 及驱动契约，预期成功并找到工厂符号。
- [ ] **步骤 6：提交**：`git commit -m "feat: add SnapClick virtual audio driver"`。

### 任务 4：驱动安装与音频转发控制器

**文件：** 创建 `SnapClick/Core/SoftwareVolumeController.swift`、`scripts/test_software_volume_controller_contract.sh`；修改 `SnapClick/App/AppDelegate.swift` 和工程文件。

- [ ] **步骤 1：编写失败契约测试**，要求状态包含 `notInstalled/installing/disabled/starting/active/recovering/failed`；启动顺序为“打开物理输出、启动转发、切默认设备”；失败/退出顺序为“恢复默认设备、停止转发”。
- [ ] **步骤 2：验证红灯**：运行 `bash scripts/test_software_volume_controller_contract.sh`，预期控制器不存在。
- [ ] **步骤 3：实现安装器**：只接受 App 内 `Contents/Resources/SnapClickAudio.driver` 且校验 bundle id；管理员授权后原子替换 `/Library/Audio/Plug-Ins/HAL/SnapClickAudio.driver`，设置 `root:wheel`、目录 755、可执行文件 755、其他文件 644，再重启 `coreaudiod`。
- [ ] **步骤 4：实现控制器生命周期**：`SoftwareVolumeController.shared` 在主 actor 发布 `state`、`volume`、`outputName`。仅当物理输出和转发均已就绪才把虚拟设备设为默认；监听设备列表和默认设备变化，过滤自身并在物理输出移除时选择其他非虚拟输出。
- [ ] **步骤 5：实现 HAL AudioUnit 转发器**：输入单元绑定虚拟设备，输出单元绑定物理设备；回调拉取交错 Float32 到预分配缓冲，逐样本乘原子增益后输出。设备切换在非实时串行队列执行。
- [ ] **步骤 6：验证绿灯**：运行控制器契约、策略测试和 Debug unsigned build，预期全部通过。
- [ ] **步骤 7：提交**：`git commit -m "feat: route system audio through SnapClick"`。

### 任务 5：状态栏单滑条 UI

**文件：** 创建 `SnapClick/UI/VolumeMenuItemView.swift`、`scripts/test_volume_menu_contract.sh`；修改 `SnapClick/UI/StatusBarController.swift` 和工程文件。

- [ ] **步骤 1：编写失败契约测试**，要求录制组后、取色组前加入 `NSMenuItem.view`；活动状态仅 speaker icon、`NSSlider`、百分比；未安装状态仅“启用音量控制”；禁止设备选择、DDC、Boost 和多应用控件。
- [ ] **步骤 2：验证红灯**：运行 `bash scripts/test_volume_menu_contract.sh`，预期 view 文件不存在。
- [ ] **步骤 3：实现控件**：固定宽 350、高 38，图标宽 18、滑条弹性宽、百分比宽 42；slider 范围 0...1、连续更新，动作写入控制器 volume；安装/失败态显示普通菜单动作。
- [ ] **步骤 4：接入菜单**：`StatusBarController` 持有并在 `setupMenu()` 重建时复用 volume view；拖动不关闭菜单，菜单打开时刷新状态。
- [ ] **步骤 5：验证绿灯**：运行菜单契约和 Debug unsigned build，预期通过。
- [ ] **步骤 6：提交**：`git commit -m "feat: add status menu volume slider"`。

### 任务 6：签名、打包与 CI

**文件：** 修改 `scripts/build_dmg.sh`、`.github/workflows/build.yml`、`AGENTS.md` 和驱动契约脚本。

- [ ] **步骤 1：扩展失败契约**，要求 Release App 内存在 `Contents/Resources/SnapClickAudio.driver`，identifier 为 `com.snapclick.audio.driver`，TeamIdentifier 为 `HQ6YY6QF8H`，且通过严格 codesign 验证。
- [ ] **步骤 2：更新工程和 CI**：驱动 target 使用相同团队与 identity；DMG 前显式验证 App、Finder extension、驱动三者；CI artifact 上传前做同样检查并打印驱动签名详情。
- [ ] **步骤 3：更新项目规则**：在 `AGENTS.md` 增加驱动签名、首次安装与固定音量设备实测要求。
- [ ] **步骤 4：运行全部自动验证**：四个契约脚本、Swift 策略测试和 Debug unsigned build，预期全部通过。
- [ ] **步骤 5：提交**：`git commit -m "build: sign and verify audio driver"`。

### 任务 7：签名 DMG 与真实设备验收

**文件：** 生成 `build/DerivedData/Build/Products/Release/SnapClick.app` 和 `dist/SnapClick.dmg`。

- [ ] **步骤 1：签名 Release 构建**：

```bash
xcodebuild -project SnapClick.xcodeproj -scheme SnapClick -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData DEVELOPMENT_TEAM=HQ6YY6QF8H CODE_SIGN_IDENTITY="Apple Development: esc_g@hotmail.com (72LZ3ELC38)" CODE_SIGN_STYLE=Manual build
```

预期 `BUILD SUCCEEDED`。

- [ ] **步骤 2：验证签名**：对 App、FinderExtension.appex、`Contents/Resources/SnapClickAudio.driver` 分别运行 `codesign --verify --deep --strict`，并确认驱动 `TeamIdentifier=HQ6YY6QF8H`。
- [ ] **步骤 3：构建并验证 DMG**：运行 `scripts/build_dmg.sh build/DerivedData/Build/Products/Release/SnapClick.app`、`hdiutil verify dist/SnapClick.dmg`、`shasum -a 256 dist/SnapClick.dmg`，记录校验值。
- [ ] **步骤 4：真实设备验收**：安装签名 App，授权驱动安装；连接固定音量 HDMI/DisplayPort 输出，验证连续音频、0/25/50/100%、拔插、切输出、退出、重启，无爆音、反馈、静音卡死且默认输出恢复。
- [ ] **步骤 5：验收通过后推送**：运行 `git push origin main`，再执行 `run_id=$(gh run list --workflow Build --branch main --limit 1 --json databaseId --jq '.[0].databaseId') && gh run watch "$run_id" --exit-status`；预期 Build 成功。
