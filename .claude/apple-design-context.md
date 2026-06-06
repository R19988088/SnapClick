# Apple Design Context

## Product
- **Name**: SnapClick
- **Description**: macOS 效率整合工具，包含截图标注、屏幕取色、贴图、Finder 右键增强
- **Category**: Productivity / Utility
- **Stage**: Development (v0.1.1-beta)

## Platforms
| Platform | Supported | Min OS  | Notes |
|----------|-----------|---------|-------|
| iOS      | No        |         |       |
| iPadOS   | No        |         |       |
| macOS    | Yes       | 13.0    | 主 App + FinderSync Extension |
| tvOS     | No        |         |       |
| watchOS  | No        |         |       |
| visionOS | No        |         |       |

## Technology
- **UI Framework**: SwiftUI + AppKit (混合)
- **Architecture**: 菜单栏应用 + 设置主窗口 + FinderSync Extension
- **Apple Technologies**: ScreenCaptureKit, FinderSync, NSStatusItem, NSWindow

## Design System
- **Base**: 自定义设计（部分基于系统默认）
- **Brand Colors**: 蓝色渐变 (Color(red: 0.14, 0.62, 1.0) → Color(red: 0.0, 0.36, 0.88))
- **Typography**: 系统字体 (.system) 使用大量自定义 size/weight，未使用语义化字体
- **Dark Mode**: 部分支持（使用 .primary/.secondary 但有硬编码颜色如 Color.black/Color.white.opacity）
- **Dynamic Type**: 不支持（全部使用固定 size）

## Accessibility
- **Target Level**: Baseline (未做专项处理)
- **Key Considerations**: 未发现 .accessibilityLabel/.accessibilityHint 等修饰符

## Users
- **Primary Persona**: macOS 重度使用者，开发者/设计师
- **Key Use Cases**: 快速截图标注、屏幕取色、剪贴板贴图、Finder 增强操作
- **Known Challenges**: 多权限申请流程、菜单栏 + 主窗口的导航关系
