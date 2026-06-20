<div align="center">

# SnapClick

### macOS Productivity Enhancer — Right-Click · Screenshot · Screen Recording · Pin · Color Picker

[![Version](https://img.shields.io/github/v/release/Tyeerth/SnapClick?color=blue&label=version)](https://github.com/Tyeerth/SnapClick/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com/Tyeerth/SnapClick/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/Tyeerth/SnapClick/total)](https://github.com/Tyeerth/SnapClick/releases/latest)

A premium productivity tool built exclusively for macOS, integrating Finder menu enhancement, advanced screenshot annotation, high-performance screen recording, screen pinning, and smart color picking — all delivered in pure native Swift for a silky-smooth experience.

[Features](#-features) · [Installation](#-installation) · [Tech Stack](#%EF%B8%8F-tech-stack) · [Build from Source](#-build-from-source) · [Project Structure](#-project-structure) · [Contact Author](#-contact-author)

[中文文档](README.md)

<br>

<img src="docs/assets/hero_screenshot.png" alt="SnapClick Main UI" width="800" style="border-radius: 12px; box-shadow: 0 8px 30px rgba(0,0,0,0.3);">

</div>

---

## ✨ Features

### 🔧 Finder Right-Click Menu Enhancement

- **Create Common Files** — Right-click to create `.txt`, `.md`, `.docx`, `.xlsx`, `.pptx`, `.html`, `.css`, `.js`, `.py`, `.sh` and more. Supports custom templates with auto-rename on creation.
- **Cut & Paste Files** — A simpler cut-paste workflow than native macOS, supporting cross-directory moves.
- **Quick Move/Copy To** — Add favorite directories for one-click file archiving.
- **Advanced Path Copy** — Copy full path, filename only, or POSIX-compliant path.
- **Quick Open in Terminal/Editor** — Right-click to launch Terminal, iTerm2, VS Code, Warp, or Xcode in the current directory.
- **File Hash Verification** — Quickly compute MD5, SHA1, SHA256 checksums.
- **Quick AirDrop** — One-click AirDrop for selected files.

<br>
<img src="docs/assets/right_click_screenshot.png" alt="Finder Right-Click Menu" width="600" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

### 📸 Advanced Screenshot & Annotation

- **Area Screenshot & Smart Window Detection** — Drag to select freely or auto-snap to hovered windows. Supports hotkey ⌥⇧A.
- **Scrolling Screenshot (Long Screenshot)** — Capture long webpages or document lists seamlessly into a single image.
- **Advanced Annotation Editor** — Rectangles, ellipses, lines, arrows, text, freehand drawing, highlight overlays, pixel-level mosaic, and smart step numbers.
- **Beautification & Framing** — Frosted glass shadows, custom 0-32px rounded window borders.

<br>
<div align="center">
  <img src="docs/assets/screenshot_editor_screenshot.png" alt="Screenshot Annotation" width="480" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25); margin-right: 16px;">
  <img src="docs/assets/long_screenshot_preview.png" alt="Scrolling Capture" width="300" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
</div>
<br>

---

### 🎥 High-Performance Screen Recording

- **Native SCK Architecture** — Powered by Apple's ScreenCaptureKit framework, delivering extremely low system overhead.
- **Custom Recording Area** — Capture full screens, selected areas, or specific application windows.
- **High Frame Rate & Coding** — Supports 30/60/120 FPS recording with advanced HEVC and H.264 codecs.
- **Multi-Channel Audio Mixing** — Record system audio, microphone inputs, or combine both in real time.
- **HUD Floating Controller** — A floating control panel to pause, resume, and stop recording, featuring live timers and audio waveforms.

<br>
<img src="docs/assets/recording_overlay.png" alt="Screen Recording Overlay" width="700" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

### 📌 Screen Pin (Pin Window)

- **Multi-Window Pinning** — Frame-free floating windows pinned to the top of your screen, supporting hotkey ⌥⇧P.
- **Workspace Navigation** — Persist pins across spaces and follow active workflows.
- **Flexible Interactions** — Zoom via double-clicks, adjust opacity smoothly using your scroll wheel, and manage active pins easily.

<br>
<img src="docs/assets/pin_window_overlay.png" alt="Pinned Screen Window" width="600" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

### 🔍 Precision Magnifier Color Picker

- **16x Magnifier** — Visually zoom into pixels with a target grid for exact alignment, supporting hotkey ⌥⇧C.
- **Multi-Format Codes** — Instantly copy HEX, RGB, HSL, Swift (NSColor), or CSS color codes.
- **History Tracking** — Automatically saves your 20 most recent color picks for quick recall.

<br>
<img src="docs/assets/color_picker_overlay.png" alt="Magnifier Color Picker" width="450" style="border-radius: 8px; box-shadow: 0 6px 20px rgba(0,0,0,0.25);">
<br>

---

## 🛠️ Tech Stack

| Technology | Description |
|------------|-------------|
| Swift 5.9+ | Main development language |
| SwiftUI + AppKit | Hybrid frontend following modern macOS design patterns |
| ScreenCaptureKit | High-performance screen capturing and recording |
| FinderSync | Native extension for Finder integration |
| CGEventTap | Precision interception for global system hotkeys |
| AVFoundation & CryptoKit | Multimedia processing and cryptographic file hashing |

---

## 📥 Installation

### Option 1: Direct Download (Recommended)

Go to the [Releases page](https://github.com/Tyeerth/SnapClick/releases/latest) and download the latest `.dmg` or `.zip` archive. Extract the file and drag the app into your `Applications` directory.

<a href="https://github.com/Tyeerth/SnapClick/releases/latest">
  <img src="https://img.shields.io/badge/Download-Latest%20Release-blue?style=for-the-badge&logo=github" alt="Download Latest Release">
</a>

### Option 2: Build from Source

See the [Build from Source](#-build-from-source) section below.

### ⚠️ First-Run Permissions

For features to work correctly, you will be prompted to grant these system privileges:

1. **Screen Recording** — Required for screenshot, scrolling capture, screen recording, and color pickers.
2. **Accessibility** — Required for capturing and triggering global hotkeys.
3. **Finder Extension** — Enable in System Settings → General → Login Items & Extensions → Finder Extensions, check `FinderExtension`.

---

## 🏗️ Build from Source

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Apple Developer Account (for code signing)

### Build Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/Tyeerth/SnapClick.git
   cd SnapClick
   ```

2. **Open the project**
   ```bash
   open SnapClick.xcodeproj
   ```

3. **Configure code signing** — Under Xcode's `Signing & Capabilities`, configure your Development Team for both targets:
   - `SnapClick` (Main App, Bundle ID: `com.snapclick.app`, non-sandboxed)
   - `FinderExtension` (Right-click plugin, Bundle ID: `com.snapclick.app.FinderExtension`, sandboxed, bound to App Group `group.com.snapclick.shared`)

4. **Build and Run** — Select target `SnapClick` → Destination `My Mac` → Run (⌘R)

---

## 📂 Project Structure

```
SnapClick/
├── Shared/                          # Shared modules between main App and FinderExtension
│   ├── AppGroup.swift               # App Group shared UserDefaults bridge
│   └── FileOperations.swift         # Core file operations (cut/paste/create/hash/reveal)
│
├── FinderExtension/                 # Finder right-click plugin
│   ├── FinderSync.swift             # FIFinderSync lifecycle controller
│   ├── MenuBuilder.swift            # Dynamic right-click menu construction engine
│   ├── FinderExtension.entitlements
│   └── Info.plist
│
└── SnapClick/                       # Main App
    ├── App/
    │   ├── SnapClickApp.swift       # SwiftUI lifecycle entry point
    │   └── AppDelegate.swift        # AppKit lifecycle management & command dispatch
    ├── Core/
    │   ├── AppSettings.swift         # Global @AppStorage configuration
    │   ├── PermissionManager.swift   # System permission detection & guidance
    │   └── HotkeyManager.swift       # CGEventTap global hotkeys
    ├── UI/
    │   ├── MainWindow.swift          # SwiftUI multi-column settings center
    │   ├── WelcomeView.swift         # First-launch permission onboarding
    │   └── StatusBarController.swift # Menu bar icon & dropdown menu
```

---

## ⚠️ Development Notes

1. **Non-Sandbox Privileges** — The main App disables Sandbox, which is required for global keyboard listening (CGEventTap) and native external terminal/editor launching.
2. **Finder Extension Sandbox** — `FinderExtension` must run in a sandboxed environment, communicating with the main App via App Group shared data.
3. **IPC Communication** — FinderExtension communicates with the main App via named pasteboards (NSPasteboard) to avoid triggering TCC permission dialogs.
4. **File Reveal** — Uses `/usr/bin/open -R` instead of `NSWorkspace` to avoid Apple Event permission dialogs.

---

## 🤝 Contributing

Contributions are welcome! Follow these steps to contribute:

1. Fork this repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Create a Pull Request for review.

---

## 📮 Contact Author

If you have questions, feature suggestions, or bug reports, feel free to contact:

- **Email**: [tyeerth@163.com](mailto:tyeerth@163.com)
- **WeChat**:
  <br>
  <img src="docs/assets/wechat_qr.png" width="220" alt="WeChat QR Code" style="border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.2);">

---

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).
