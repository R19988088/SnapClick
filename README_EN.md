<div align="center">

# SnapClick

### macOS Productivity Enhancer — Right-Click · Screenshot · Pin · Color Picker

[![Version](https://img.shields.io/github/v/release/Tyeerth/SnapClick?color=blue&label=version)](https://github.com/Tyeerth/SnapClick/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://github.com/Tyeerth/SnapClick/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/Tyeerth/SnapClick/total)](https://github.com/Tyeerth/SnapClick/releases/latest)

A premium productivity tool built exclusively for macOS, integrating Finder menu enhancement, advanced screenshot annotation, screen pinning, and smart color picking — all delivered in pure native Swift for a silky-smooth experience.

[Features](#-features) · [Installation](#-installation) · [Build from Source](#-build-from-source) · [Contributing](#-contributing)

[中文文档](README.md)

</div>

---

## ✨ Features

### 🔧 Finder Right-Click Menu Enhancement

- **Create Common Files** — Right-click to create `.txt`, `.md`, `.docx`, `.xlsx`, `.pptx`, `.html`, `.css`, `.js`, `.py`, `.sh` and more. Supports custom templates with auto-rename on creation.
- **Cut & Paste Files** — A simpler cut-paste workflow than native macOS, supporting cross-directory moves.
- **Quick Move/Copy To** — Add favorite directories for one-click file archiving.
- **Advanced Path Copy** — Copy full path, filename only, or POSIX-compliant path.
- **Quick Open in Terminal/Editor** — Right-click to launch Terminal, iTerm2, VS Code, Sublime Text, or Xcode in the current directory.
- **File Hash Verification** — Quickly compute MD5, SHA1, SHA256 checksums.
- **Quick AirDrop** — One-click AirDrop for selected files.

### 📸 Advanced Screenshot & Annotation

- **Area Screenshot & Smart Window Detection** — Drag to select freely or auto-snap to hovered windows.
- **Delayed Full-Screen Screenshot** — Custom countdown to capture dropdown menus and transition states.
- **Advanced Annotation Editor** — Rectangles, ellipses, lines, freehand drawing, highlight overlays, pixel-level mosaic, and smart step numbers.
- **Screenshot Beautification** — Frosted glass shadow, custom rounded corners.

### 📌 Screen Pin & Smart Color Picker

- **Multi-Window Screen Pin** — Transparent borderless floating pins, always-on-top, cross-Space following, opacity adjustment.
- **16x Precision Magnifier Color Picker** — One-click copy of Hex, RGB, HSL, Swift (NSColor), or CSS color codes.

---

## 📥 Installation

### Option 1: Download Installer (Recommended)

Visit the [Releases page](https://github.com/Tyeerth/SnapClick/releases/latest) to download the latest `.dmg` installer. Double-click and drag to your Applications folder.

<a href="https://github.com/Tyeerth/SnapClick/releases/latest">
  <img src="https://img.shields.io/badge/Download-Latest%20Release-blue?style=for-the-badge&logo=github" alt="Download Latest Release">
</a>

### Option 2: Build from Source

See [Build from Source](#-build-from-source) below.

### ⚠️ First-Run Permissions

On first launch, the app will guide you through granting these permissions:

1. **Screen Recording** — Required for screenshots and magnifier color picker
2. **Accessibility** — Required for global hotkey capture
3. **Finder Extension** — Enable in System Settings → General → Login Items & Extensions → Finder Extensions, check `FinderExtension`

---

## 🛠️ Tech Stack

| Technology | Description |
|------------|-------------|
| Swift 5.9+ | Development language |
| SwiftUI + AppKit | Hybrid architecture following macOS Modern Design |
| ScreenCaptureKit | High-performance screen capture |
| FinderSync | Native Finder process plugin |
| CGEventTap | Global hotkey precision interception |
| AVFoundation & CryptoKit | Multimedia processing and cryptographic hashing |

---

## 🔨 Build from Source

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

3. **Configure signing** — In Xcode's `Signing & Capabilities`, configure the development team for both targets:
   - `SnapClick` (Main App, Bundle ID: `com.snapclick.app`, non-sandboxed)
   - `FinderExtension` (Right-click plugin, Bundle ID: `com.snapclick.app.FinderExtension`, sandboxed, bound to App Group: `group.com.snapclick.shared`)

4. **Build & Run** — Select Scheme `SnapClick` → Build target `My Mac` → Run (⌘R)

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
    └── Modules/
        ├── Screenshot/               # Screenshot & annotation module
        ├── PinColor/                 # Pin & color picker module
        └── RightClick/               # Right-click menu settings module
```

---

## ⚠️ Development Notes

1. **Non-Sandbox Privileges** — The main App disables Sandbox, which is required for global keyboard listening (CGEventTap) and native external app launching.
2. **Finder Extension Sandbox** — `FinderExtension` must run in a sandboxed environment, communicating with the main App via App Group shared data.
3. **IPC Communication** — FinderExtension communicates with the main App via named pasteboards (NSPasteboard) to avoid triggering TCC permission dialogs.
4. **File Reveal** — Uses `/usr/bin/open -R` instead of `NSWorkspace.activateFileViewerSelecting` to avoid Apple Event permission dialogs.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

---

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).
