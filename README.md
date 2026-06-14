<div align="center">

# SnapClick

### macOS 效率增强工具 — 右键增强 · 截图标注 · 屏幕录制 · 屏幕贴图 · 智能取色

[![Version](https://img.shields.io/github/v/release/Tyeerth/SnapClick?color=blue&label=version)](https://github.com/Tyeerth/SnapClick/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com/Tyeerth/SnapClick/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/Tyeerth/SnapClick/total)](https://github.com/Tyeerth/SnapClick/releases/latest)

一款专为 macOS 打造的高级效率增强工具，将 Finder 菜单增强、高级截图标注、高性能录屏、屏幕贴图、智能取色等常用效率功能一体化汇总，以纯原生 Swift 架构呈现，为您提供丝滑般尊贵的使用体验。

[功能特性](#-功能特性) · [下载安装](#-下载安装) · [技术栈](#%EF%B8%8F-技术栈) · [编译构建](#-编译构建) · [项目结构](#-项目结构) · [联系作者](#-联系作者)

[English](README_EN.md)

<br>

<img src="website/assets/hero_screenshot.png" alt="SnapClick 主设置界面" width="800" style="border-radius: 12px; box-shadow: 0 8px 30px rgba(0,0,0,0.3);">

</div>

---

## ✨ 功能特性

### 🔧 Finder 右键菜单增强

- **新建常用文件** — 右键一键新建 `.txt`、`.md`、`.docx`、`.xlsx`、`.pptx`、`.html`、`.css`、`.js`、`.py`、`.sh` 等多种格式文件，支持自定义模板，新建后自动进入重命名状态。
- **文件剪切与粘贴** — 比原生更简单的高效剪切粘贴流，支持跨目录快速移动。
- **快速移动/复制到** — 支持添加常用目录，一键归档。
- **路径高级拷贝** — 支持拷贝完整路径、仅文件名或 POSIX 规范路径。
- **常用终端/编辑器快捷打开** — 右键在当前目录拉起 Terminal、iTerm2、VS Code、Warp 或 Xcode。
- **文件哈希校验** — 快速计算 MD5、SHA1、SHA256 校验码。
- **快捷隔空投送** — 一键对选中文件发起 AirDrop 投送。

<br>
<img src="website/assets/right_click_screenshot.png" alt="Finder 右键增强菜单" width="600" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

### 📸 高级截图与标注

- **区域截图 & 智能窗口识别** — 拖拽自由选区、自动贴合悬停窗口，支持快捷键 ⌥⇧A 一键调起。
- **智能长截图捕获** — 支持滚动网页或超长文档，智能进行连续的长截图无缝捕捉。
- **高级标注编辑器** — 丰富的标注工具栏，支持矩形、椭圆、直线、箭头、文字、画笔、高亮蒙层、步骤序号以及像素级马赛克。
- **截图美化包装** — 优雅的毛玻璃大阴影、0-32px 自定义窗口圆角。

<br>
<div align="center">
  <img src="website/assets/screenshot_editor_screenshot.png" alt="屏幕截图与实时标注" width="480" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25); margin-right: 16px;">
  <img src="website/assets/long_screenshot_preview.png" alt="智能长截图捕获" width="300" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
</div>
<br>

---

### 🎥 高性能屏幕录制

- **底层SCK架构** — 基于 macOS 底层官方高性能 ScreenCaptureKit 架构，超低系统资源占用。
- **多维度选区录屏** — 支持自定义录屏区域、全屏录制、特定应用窗口录制。
- **极速高帧率录制** — 支持 30/60/120 FPS 极速高帧率与先进的 HEVC/H.264 编解码。
- **多声道混合** — 支持同时捕获系统声音（麦克风输入与系统音频流混合）。
- **HUD悬浮控制条** — 独立的浮动 HUD 控制面板，可快速进行录屏暂停、停止及时间、音频波形监视。

<br>
<img src="website/assets/recording_overlay.png" alt="屏幕录屏 HUD 与选区控制" width="700" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

### 📌 便捷屏幕贴图 (Pin Window)

- **多视窗屏幕贴图** — 将截图或任意图像一键固定在屏幕最上层展示，快捷键为 ⌥⇧P。
- **悬浮多视窗管理** — 支持跨 Space 空间跟随，多贴图并存。
- **自由交互调节** — 支持滚轮无级调节贴图透明度，双击缩放大小，支持 Pin 状态快捷栏管理。

<br>
<img src="website/assets/pin_window_overlay.png" alt="屏幕贴图置顶展示" width="600" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

### 🔍 精准取色放大镜

- **16x精准放大镜** — 支持可视化 16 倍像素级放大镜，支持快捷键 ⌥⇧C 快速调起。
- **多格式一键转换** — 完美支持 HEX、RGB、HSL、Swift (NSColor) 与 CSS 等多种颜色代码一键复制。
- **取色历史** — 智能记录并展示最近取的 20 条颜色历史记录。

<br>
<img src="website/assets/color_picker_overlay.png" alt="1:1 像素精准取色放大镜" width="450" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

## 🛠️ 技术栈

| 技术 | 说明 |
|------|------|
| Swift 5.9+ | 开发语言 |
| SwiftUI + AppKit | 混合架构，遵循 macOS Modern Design 规范 |
| ScreenCaptureKit | Apple 官方高性能屏幕捕获与录像框架 |
| FinderSync | 原生 Finder 进程菜单增强插件 |
| CGEventTap | 全局系统快捷键高精度拦截与响应监听 |
| AVFoundation & CryptoKit | 多媒体编码处理与文件加密哈希计算 |

---

## 📥 下载安装

### 方式一：直接下载安装包（推荐）

前往 [Releases 页面](https://github.com/Tyeerth/SnapClick/releases/latest) 下载最新的 `.dmg` 或 `.zip` 安装包，解压后拖拽到「应用程序」文件夹即可运行。

<a href="https://github.com/Tyeerth/SnapClick/releases/latest">
  <img src="https://img.shields.io/badge/Download-Latest%20Release-blue?style=for-the-badge&logo=github" alt="Download Latest Release">
</a>

### 方式二：从源码编译

请参阅下方 [编译构建](#-编译构建) 章节。

### ⚠️ 首次运行授权说明

首次启动时，为了功能正常运行，App 会引导您授予以下系统权限：

1. **屏幕录制权限** — 用于高性能截图、长截图、屏幕录制与放大镜取色。
2. **辅助功能权限** — 用于捕获并拦截全局快捷键。
3. **Finder 扩展启用** — 请前往「系统设置 → 通用 → 登录项与扩展 → Finder 扩展」中勾选启用 `FinderExtension`。

---

## 🏗️ 编译构建

### 前置要求

- macOS 13.0 (Ventura) 及以上
- Xcode 15.0 及以上
- Apple Developer Account（用于代码签名）

### 构建步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/Tyeerth/SnapClick.git
   cd SnapClick
   ```

2. **打开项目**
   ```bash
   open SnapClick.xcodeproj
   ```

3. **配置开发者签名** — 在 Xcode 的 `Signing & Capabilities` 中为以下两个 Target 配置您的开发团队 (Team)：
   - `SnapClick`（主 App，Bundle ID: `com.snapclick.app`，非沙盒特权模式）
   - `FinderExtension`（右键扩展插件，Bundle ID: `com.snapclick.app.FinderExtension`，沙盒模式，绑定 App Group: `group.com.snapclick.shared`）

4. **构建运行** — 选择 Scheme `SnapClick` → 构建目标 `My Mac` → 运行 (⌘R)

---

## 📂 项目结构

```
SnapClick/
├── Shared/                          # 主 App 与 FinderExtension 共享模块
│   ├── AppGroup.swift               # App Group 共享 UserDefaults 桥接
│   └── FileOperations.swift         # 文件操作核心（剪切/粘贴/新建/哈希/显示）
│
├── FinderExtension/                 # Finder 右键插件
│   ├── FinderSync.swift             # FIFinderSync 生命周期控制器
│   ├── MenuBuilder.swift            # 动态右键菜单构造引擎
│   ├── FinderExtension.entitlements
│   └── Info.plist
│
└── SnapClick/                       # 主 App
    ├── App/
    │   ├── SnapClickApp.swift       # SwiftUI 生命周期入口
    │   └── AppDelegate.swift        # AppKit 周期管理、命令分发
    ├── Core/
    │   ├── AppSettings.swift         # 全局 @AppStorage 配置项
    │   ├── PermissionManager.swift   # 系统权限检测与引导
    │   └── HotkeyManager.swift       # CGEventTap 全局快捷键
    ├── UI/
    │   ├── MainWindow.swift          # SwiftUI 多栏设置中心
    │   ├── WelcomeView.swift         # 首次启动授权引导页
    │   └── StatusBarController.swift # 菜单栏图标与下拉菜单
    └── Modules/
        ├── Screenshot/               # 截图与标注模块
        ├── PinColor/                 # 贴图与取色模块
        └── RightClick/               # 右键菜单设置模块
```

---

## ⚠️ 开发注意事项

1. **非沙盒特权** — 主 App 禁用 Sandbox，这是实现全局键盘监听 (CGEventTap) 及原生拉起外部终端与编辑器的必要前提。
2. **Finder 扩展沙盒** — `FinderExtension` 作为系统扩展插件，必须处于沙盒环境，并通过 App Group 与主 App 共享数据。
3. **IPC 通信** — FinderExtension 通过命名剪贴板 (NSPasteboard) 与主 App 进行指令状态通信，避免触发多余的 TCC 权限弹窗。
4. **文件定位显示** — 使用 `/usr/bin/open -R` 替代 `NSWorkspace` 的原生接口，避免触发 Apple Event 授权弹窗。

---

## 🤝 参与贡献

欢迎贡献代码或提出建议！请遵循以下流程：

1. Fork 本仓库。
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)。
3. 提交您的修改 (`git commit -m 'Add amazing feature'`)。
4. 推送分支 (`git push origin feature/amazing-feature`)。
5. 创建 Pull Request 待管理员审核。

---

## 📮 联系作者

如果您在使用中遇到问题、有功能建议，或者想参与讨论，欢迎通过以下方式联系：

- **联系邮箱**：[tyeerth@163.com](mailto:tyeerth@163.com)
- **微信联系**：
  <br>
  <img src="website/assets/wechat_qr.png" width="220" alt="作者微信二维码" style="border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.2);">

---

## 📄 开源协议

本项目基于 [Apache License 2.0](LICENSE) 开源协议。
