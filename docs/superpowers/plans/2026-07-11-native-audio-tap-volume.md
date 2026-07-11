# 原生 Audio Tap 软件音量实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框语法跟踪进度。

**目标：** 使用 macOS 14.2+ Core Audio Process Tap 实现 SoundSource 类似的软件音量控制，不安装虚拟声卡且不影响麦克风。

**架构：** 全局立体声 Tap 排除 SnapClick 自身并在读取时静音原始输出；私有 Aggregate Device 的 IOProc 把 Tap 音频写入现有无锁环形缓冲区；物理 AUHAL 输出读取缓冲区并应用原子软件增益。系统音量键由 SnapClick 监听并更新软件增益。

**技术栈：** Swift、CoreAudio Process Tap、AudioUnit、C11 atomics、AppKit CGEventTap

---

### 任务 1：替换虚拟驱动生命周期

**文件：**
- 修改：`SnapClick/Core/SoftwareVolumeController.swift`
- 修改：`SnapClick/Core/AudioRingBuffer.h`
- 修改：`SnapClick/Core/AudioRingBuffer.c`
- 修改：`scripts/test_software_volume_controller_contract.sh`
- 修改：`scripts/test_audio_ring_buffer.c`
- 删除：`SnapClickAudioDriver/Driver.cpp`
- 删除：`SnapClickAudioDriver/Info.plist`
- 删除：`scripts/build_audio_driver.sh`

- [ ] 先修改合约，要求 `AudioHardwareCreateProcessTap`、`CATapDescription`、Aggregate Tap、`AudioDeviceCreateIOProcIDWithBlock` 和原子增益，并禁止旧驱动安装路径。
- [ ] 运行合约确认失败。
- [ ] 实现 `NativeAudioTapForwarder`：创建 Tap、Aggregate Device、捕获 IOProc、环形缓冲区和物理 AUHAL；停止时按逆序销毁。
- [ ] 在 C 环形缓冲区中加入原子增益读写，并扩展 C 测试验证 0、0.5、1 三个值。
- [ ] 运行合约、C 测试和 Debug 构建并提交。

### 任务 2：软件音量键

**文件：**
- 修改：`SnapClick/Core/SoftwareVolumeController.swift`
- 修改：`SnapClick/Core/HotkeyManager.swift`
- 创建：`scripts/test_software_volume_hotkeys_contract.sh`

- [ ] 编写失败合约，覆盖音量加、音量减、静音键和按键释放过滤。
- [ ] 在现有全局事件监听中转发 `NX_KEYTYPE_SOUND_UP`、`NX_KEYTYPE_SOUND_DOWN`、`NX_KEYTYPE_MUTE`，仅在软件音量启用时吞掉事件。
- [ ] 控制器以固定步长更新 0...1 增益并保存到 UserDefaults；静音恢复到此前非零值。
- [ ] 运行合约和 Debug 构建并提交。

### 任务 3：设置页与低版本状态

**文件：**
- 修改：`SnapClick/UI/MainWindow.swift`
- 修改：`SnapClick/Core/AppSettings.swift`
- 修改：`scripts/test_audio_driver_contract.sh`

- [ ] 编写失败合约，要求 macOS 14.2 可用性判断、启用/停用按钮，以及低版本灰色 12.5px 说明。
- [ ] 把“音频驱动”改为“软件音量”，移除安装状态，支持系统显示当前启用状态。
- [ ] 低于 macOS 14.2 时禁用按钮并显示灰色 `需要 macOS 14.2 或更高版本` 文案。
- [ ] 运行 UI 合约和 Debug 构建并提交。

### 任务 4：真实硬件与发行验证

- [ ] 验证默认麦克风和 WeType 语音输入不受影响。
- [ ] 验证内建扬声器、BenQ DisplayPort、系统音量加减和静音。
- [ ] 运行全部合约和 Debug 构建。
- [ ] 按 `AGENTS.md` 构建签名 Release，验证 App 和 Finder 扩展签名、双架构、DMG 和 SHA-256。
- [ ] 用户硬件确认前不推送。
