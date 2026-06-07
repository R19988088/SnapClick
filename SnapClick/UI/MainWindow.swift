import SwiftUI
import AppKit

// MARK: - 设计 Token

enum DT {
    // 颜色
    static let sidebarBg        = Color(red: 240/255, green: 243/255, blue: 247/255)
    static let sidebarSelected  = Color(red: 59/255,  green: 130/255, blue: 246/255)
    static let accent           = Color(red: 59/255,  green: 130/255, blue: 246/255)
    static let contentBg        = Color.white
    static let cardBg           = Color(red: 249/255, green: 250/255, blue: 251/255)
    static let cardBorder       = Color(red: 226/255, green: 232/255, blue: 240/255)
    static let groupLabel       = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let successGreen     = Color(red: 34/255,  green: 197/255, blue: 94/255)
    static let warningOrange    = Color(red: 249/255, green: 115/255, blue: 22/255)

    // 间距
    static let contentPadding: CGFloat = 24
    static let cardRadius: CGFloat     = 10
    static let rowPadH: CGFloat        = 16
    static let rowPadV: CGFloat        = 11
}

// MARK: - 侧边栏导航项

enum SettingsDestination: String, CaseIterable, Identifiable, Hashable {
    case general     = "general"
    case screenshot  = "screenshot"
    case pinAndColor = "pinAndColor"
    case contextMenu = "contextMenu"
    case about       = "about"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .general:     return "通用".localized
        case .screenshot:  return "截图与标注".localized
        case .pinAndColor: return "贴图 & 取色".localized
        case .contextMenu: return "Finder 右键".localized
        case .about:       return "关于".localized
        }
    }

    var symbolName: String {
        switch self {
        case .general:     return "gearshape"
        case .screenshot:  return "camera.viewfinder"
        case .pinAndColor: return "pin.circle"
        case .contextMenu: return "folder.badge.gearshape"
        case .about:       return "info.circle"
        }
    }
}

// MARK: - 侧边栏导航项组件

private struct SidebarNavItem: View {
    let dest: SettingsDestination
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: dest.symbolName)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color(red: 71/255, green: 85/255, blue: 105/255))
                    .frame(width: 18)

                Text(dest.localizedTitle)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color(red: 30/255, green: 41/255, blue: 59/255))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected
                          ? DT.sidebarSelected
                          : (isHovered ? Color.black.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .accessibilityLabel(dest.localizedTitle)
    }
}

// MARK: - 内容区顶部 Header

struct SettingsPageHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
    }
}

// MARK: - 设计卡片容器

struct DesignCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(DT.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous)
                .stroke(DT.cardBorder, lineWidth: 0.75)
        )
    }
}

// 保持旧名兼容
typealias WhiteCard = DesignCard

// MARK: - 设计卡片行分隔线

struct CardDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, DT.rowPadH)
    }
}

// MARK: - 段落标题

struct SectionLabel: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 30/255, green: 41/255, blue: 59/255))
        }
    }
}

// MARK: - MainWindow

struct MainWindow: View {
    @State private var selectedDestination: SettingsDestination? = .general
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 0) {
            // ── 自定义侧边栏 ────────────────────────────────────────
            SidebarView(selectedDestination: $selectedDestination)

            Divider()
                .opacity(0.5)

            // ── 内容工作区 ──────────────────────────────────────────
            DetailView(selectedDestination: $selectedDestination)
        }
        .frame(minWidth: 820, idealWidth: 880, minHeight: 540, idealHeight: 600)
        .background(DT.contentBg)
        .preferredColorScheme(settings.appAppearance == "light" ? .light : (settings.appAppearance == "dark" ? .dark : nil))
    }
}

// MARK: - 侧边栏

private struct SidebarView: View {
    @Binding var selectedDestination: SettingsDestination?
    @ObservedObject private var permMgr = PermissionManager.shared
    @AppStorage("isFinderEnabled") private var isFinderEnabled: Bool = false

    private var allGranted: Bool {
        permMgr.hasScreenRecordingPermission && permMgr.hasAccessibilityPermission && isFinderEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            // App 头部
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 59/255, green: 130/255, blue: 246/255),
                                         Color(red: 99/255, green: 102/255, blue: 241/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: DT.accent.opacity(0.4), radius: 4, x: 0, y: 2)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text("SnapClick".localized)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                    Text("v1.0.2".localized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DT.groupLabel)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 24)

            VStack(spacing: 2) {
                ForEach(SettingsDestination.allCases) { dest in
                    SidebarNavItem(dest: dest, isSelected: selectedDestination == dest) {
                        selectedDestination = dest
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // 底部系统状态
            HStack(spacing: 6) {
                Circle()
                    .fill(allGranted ? DT.successGreen : DT.warningOrange)
                    .frame(width: 6, height: 6)
                Text(allGranted ? "全部已授权".localized : "存在未授权项".localized)
                    .font(.system(size: 10.5))
                    .foregroundStyle(allGranted ? DT.successGreen : DT.warningOrange)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .frame(width: 190)
        .background(DT.sidebarBg)
    }
}

// MARK: - 内容详情区

private struct DetailView: View {
    @Binding var selectedDestination: SettingsDestination?

    var body: some View {
        VStack(spacing: 0) {
            if let dest = selectedDestination {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        SettingsPageHeader(title: dest.localizedTitle)

                        switch dest {
                        case .general:
                            GeneralSettingsView(selectedDestination: $selectedDestination)
                        case .screenshot:
                            ScreenshotSettingsView()
                        case .pinAndColor:
                            PinColorSettingsView()
                        case .contextMenu:
                            RightClickSettingsView()
                        case .about:
                            AboutView()
                        }
                    }
                    .padding(DT.contentPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(DT.contentBg)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("请从左侧选择设置项".localized)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DT.contentBg)
            }
        }
    }
}

// MARK: - 通用设置页

private struct GeneralSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var permMgr = PermissionManager.shared
    @Binding var selectedDestination: SettingsDestination?
    @AppStorage("isFinderEnabled") private var isFinderEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {

            // ── 权限状态 ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "权限状态".localized, icon: "lock.shield", color: .blue)

                DesignCard {
                    PermissionRow(
                        icon: "video.badge.checkmark",
                        iconColor: .blue,
                        title: "屏幕录制".localized,
                        description: "区域截图及取色所需".localized,
                        isGranted: permMgr.hasScreenRecordingPermission,
                        onAction: { permMgr.requestScreenRecordingPermission() }
                    )

                    CardDivider()

                    PermissionRow(
                        icon: "accessibility",
                        iconColor: .purple,
                        title: "辅助功能".localized,
                        description: "全局快捷键拦截所需".localized,
                        isGranted: permMgr.hasAccessibilityPermission,
                        onAction: { permMgr.requestAccessibilityPermission() }
                    )

                    CardDivider()

                    PermissionRow(
                        icon: "folder.badge.gearshape",
                        iconColor: Color(red: 20/255, green: 184/255, blue: 166/255),
                        title: "Finder 扩展".localized,
                        description: "右键菜单与图标覆盖所需".localized,
                        isGranted: isFinderEnabled,
                        actionLabel: "去启用".localized,
                        onAction: {
                            isFinderEnabled = true
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.extensions?FinderSync") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
            }

            // ── 启动与可见性 ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "启动与可见性".localized, icon: "power.circle", color: .green)

                DesignCard {
                    ToggleRow(
                        title: "开机自启动".localized,
                        description: "登录时自动启动 SnapClick".localized,
                        isOn: $settings.launchAtLogin
                    )
                    CardDivider()
                    ToggleRow(
                        title: "在菜单栏显示图标".localized,
                        description: "在右上角菜单栏显示快捷入口".localized,
                        isOn: $settings.showInMenuBar
                    )
                }
            }

            // ── 语言与外观 ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "语言与外观".localized, icon: "globe", color: .orange)

                DesignCard {
                    HStack(spacing: 16) {
                        // 系统语言
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("系统语言".localized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                                Text("界面及菜单呈现语言".localized)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Picker("", selection: $settings.appLanguage) {
                                Text("简体中文").tag("zh-CN")
                                Text("English (US)").tag("en")
                                Text("日本語").tag("ja")
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(red: 241/255, green: 245/255, blue: 249/255))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(DT.cardBorder, lineWidth: 0.5)
                                    )
                            )
                        }
                        .frame(maxWidth: .infinity)

                        // 外观模式
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("外观模式".localized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                                Text("界面颜色主题偏好".localized)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 0) {
                                AppearanceModeButton(
                                    label: "Light",
                                    icon: "sun.max",
                                    isSelected: settings.appAppearance == "light"
                                ) { settings.appAppearance = "light" }

                                AppearanceModeButton(
                                    label: "Dark",
                                    icon: "moon",
                                    isSelected: settings.appAppearance == "dark"
                                ) { settings.appAppearance = "dark" }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(red: 241/255, green: 245/255, blue: 249/255))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(DT.cardBorder, lineWidth: 0.5)
                                    )
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(DT.rowPadH)
                }
            }

            // ── 云同步横幅 ──────────────────────────────────────────
            CloudSyncBanner()
        }
    }
}

// MARK: - 权限状态行

private struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    var actionLabel: String? = nil
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DT.successGreen)
                    Text("已授权".localized)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DT.successGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(DT.successGreen.opacity(0.1))
                        .overlay(Capsule().stroke(DT.successGreen.opacity(0.2), lineWidth: 0.75))
                )
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DT.warningOrange)
                    Text("未授权".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(DT.warningOrange)
                }

                Button(actionLabel ?? "去授权".localized) { onAction() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(DT.accent)
            }
        }
        .padding(.horizontal, DT.rowPadH)
        .padding(.vertical, DT.rowPadV)
    }
}

// MARK: - Toggle 行

struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, DT.rowPadH)
        .padding(.vertical, DT.rowPadV)
    }
}

// MARK: - 外观模式按钮

private struct AppearanceModeButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : Color(red: 71/255, green: 85/255, blue: 105/255))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? DT.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 云同步横幅

private struct CloudSyncBanner: View {
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("同步设置到云端".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                Text("通过 iCloud 在所有 macOS 设备间同步 SnapClick 配置。".localized)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(red: 71/255, green: 85/255, blue: 105/255))
                    .lineSpacing(2)

                Button("启用 iCloud 同步".localized) {
                    // 未来功能
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(DT.accent)
                .padding(.top, 4)
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 186/255, green: 230/255, blue: 253/255),
                                Color(red: 199/255, green: 210/255, blue: 254/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "cloud.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 59/255, green: 130/255, blue: 246/255),
                                     Color(red: 99/255, green: 102/255, blue: 241/255)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 239/255, green: 246/255, blue: 255/255),
                            Color(red: 238/255, green: 242/255, blue: 255/255)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous)
                        .stroke(Color(red: 191/255, green: 219/255, blue: 254/255), lineWidth: 0.75)
                )
        )
    }
}

// MARK: - 截图与标注设置页

private struct ScreenshotSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {

            // ── 实时预览区 ──────────────────────────────────────────
            LivePreviewCard(
                hasRoundCorner: settings.screenshotAddRoundCorner,
                cornerRadius: settings.screenshotCornerRadius,
                hasShadow: settings.screenshotAddShadow
            )

            // ── 两列设置区 ──────────────────────────────────────────
            HStack(alignment: .top, spacing: 16) {
                // 左列：外观美化
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(title: "截图外观".localized, icon: "paintbrush.pointed", color: .purple)

                    DesignCard {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("圆角半径".localized)
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Corner Radius")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(settings.screenshotCornerRadius)) px")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(DT.accent)
                                    .frame(width: 46, alignment: .trailing)
                            }
                            .padding(.horizontal, DT.rowPadH)
                            .padding(.top, DT.rowPadV)

                            Slider(value: $settings.screenshotCornerRadius, in: 0...32, step: 1)
                                .padding(.horizontal, DT.rowPadH)
                                .padding(.bottom, DT.rowPadV)
                                .tint(DT.accent)

                            CardDivider()

                            ToggleRow(
                                title: "添加阴影".localized,
                                description: "为截图添加投影效果".localized,
                                isOn: $settings.screenshotAddShadow
                            )

                            CardDivider()

                            ToggleRow(
                                title: "窗口透明".localized,
                                description: "保留截图原始透明度".localized,
                                isOn: $settings.screenshotAddRoundCorner
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // 右列：保存路径与格式
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(title: "储存设置".localized, icon: "internaldrive", color: .teal)

                    DesignCard {
                        VStack(spacing: 0) {
                            // 保存路径
                            VStack(alignment: .leading, spacing: 8) {
                                Text("保存位置".localized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DT.accent)
                                        Text(URL(fileURLWithPath: settings.screenshotSavePath).lastPathComponent)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color(red: 241/255, green: 245/255, blue: 249/255))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .stroke(DT.cardBorder, lineWidth: 0.5)
                                            )
                                    )

                                    Button("更改…".localized) {
                                        let panel = NSOpenPanel()
                                        panel.canChooseFiles = false
                                        panel.canChooseDirectories = true
                                        panel.allowsMultipleSelection = false
                                        if panel.runModal() == .OK, let url = panel.url {
                                            settings.screenshotSavePath = url.path
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.horizontal, DT.rowPadH)
                            .padding(.top, DT.rowPadV)
                            .padding(.bottom, 10)

                            CardDivider()

                            // 格式选择
                            VStack(alignment: .leading, spacing: 8) {
                                Text("默认格式".localized)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    ForEach(["PNG", "JPG", "PDF", "HEIF"], id: \.self) { fmt in
                                        FormatBadge(format: fmt, isSelected: settings.screenshotFormat == fmt) {
                                            settings.screenshotFormat = fmt
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, DT.rowPadH)
                            .padding(.vertical, DT.rowPadV)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // ── 快捷键设置 ───────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "快捷键".localized, icon: "keyboard", color: .indigo)

                HStack(spacing: 12) {
                    ShortcutCard(
                        icon: "crop",
                        iconColor: .blue,
                        title: "区域截图".localized,
                        subtitle: "选取矩形区域".localized,
                        hotkey: $settings.hotkeyAreaScreenshot
                    )

                    ShortcutCard(
                        icon: "arrow.up.and.down",
                        iconColor: .purple,
                        title: "长截图".localized,
                        subtitle: "滚动截取全屏".localized,
                        hotkey: $settings.hotkeyLongScreenshot
                    )

                    ShortcutCard(
                        icon: "wand.and.stars",
                        iconColor: .orange,
                        title: "快速编辑".localized,
                        subtitle: "打开标注编辑".localized,
                        hotkey: .constant("")
                    )
                }
            }
        }
    }
}

// MARK: - 截图实时预览卡

private struct LivePreviewCard: View {
    let hasRoundCorner: Bool
    let cornerRadius: Double
    let hasShadow: Bool

    var body: some View {
        ZStack {
            // 背景渐变
            RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 224/255, green: 231/255, blue: 255/255),
                            Color(red: 219/255, green: 234/255, blue: 254/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DT.cardRadius, style: .continuous)
                        .stroke(Color(red: 196/255, green: 214/255, blue: 254/255), lineWidth: 0.75)
                )

            // 标签
            VStack(alignment: .leading) {
                HStack {
                    Text("实时预览".localized)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color(red: 99/255, green: 102/255, blue: 241/255))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 238/255, green: 242/255, blue: 255/255))
                                .overlay(Capsule().stroke(Color(red: 199/255, green: 210/255, blue: 254/255), lineWidth: 0.5))
                        )
                    Spacer()
                    Image(systemName: "eye")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // 模拟截图
                HStack {
                    Spacer()
                    MockScreenshotView(
                        cornerRadius: hasRoundCorner ? cornerRadius : 0,
                        hasShadow: hasShadow
                    )
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
        .frame(height: 160)
    }
}

private struct MockScreenshotView: View {
    let cornerRadius: Double
    let hasShadow: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack(spacing: 6) {
                Circle().fill(Color(red: 255/255, green: 95/255, blue: 87/255)).frame(width: 10, height: 10)
                Circle().fill(Color(red: 255/255, green: 189/255, blue: 46/255)).frame(width: 10, height: 10)
                Circle().fill(Color(red: 40/255, green: 200/255, blue: 64/255)).frame(width: 10, height: 10)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 240/255, green: 240/255, blue: 240/255))

            // 内容
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2)).frame(height: 8).frame(maxWidth: 160)
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15)).frame(height: 6).frame(maxWidth: 120)
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.gray.opacity(0.2))
                    .padding(.top, 4)
            }
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
        .frame(width: 200)
        .clipShape(RoundedRectangle(cornerRadius: max(cornerRadius, 4), style: .continuous))
        .shadow(
            color: hasShadow ? Color.black.opacity(0.18) : Color.clear,
            radius: hasShadow ? 12 : 0,
            x: 0,
            y: hasShadow ? 6 : 0
        )
    }
}

// MARK: - 格式 Badge

private struct FormatBadge: View {
    let format: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(format)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color(red: 71/255, green: 85/255, blue: 105/255))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? DT.accent : Color(red: 241/255, green: 245/255, blue: 249/255))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isSelected ? DT.accent : DT.cardBorder, lineWidth: 0.75)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 快捷键卡片

private struct ShortcutCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var hotkey: String

    var body: some View {
        DesignCard {
            VStack(spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(iconColor)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HotkeyRecorderView(hotkey: $hotkey)
                    .frame(maxWidth: .infinity)
            }
            .padding(12)
        }
    }
}

// MARK: - 快捷键录制组件

struct HotkeyRecorderView: View {
    @Binding var hotkey: String
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: {
            if isRecording { stopRecording() } else { startRecording() }
        }) {
            HStack(spacing: 4) {
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("按下组合键…".localized)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DT.accent)
                } else if hotkey.isEmpty {
                    Text("点击录制".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    // 显示键盘按键样式
                    ForEach(hotkey.split(separator: "+").map(String.init), id: \.self) { key in
                        KeyBadge(key: key.uppercased())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isRecording ? DT.accent.opacity(0.08) : Color(red: 241/255, green: 245/255, blue: 249/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isRecording ? DT.accent.opacity(0.4) : DT.cardBorder, lineWidth: 0.75)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("录制快捷键"))
        .accessibilityValue(Text(hotkey.isEmpty ? "未设置" : hotkey))
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags
            var keys: [String] = []

            if modifiers.contains(.control) { keys.append("ctrl") }
            if modifiers.contains(.option)  { keys.append("option") }
            if modifiers.contains(.shift)   { keys.append("shift") }
            if modifiers.contains(.command) { keys.append("cmd") }

            let isModifierOnly = [54, 55, 56, 58, 59, 60, 61, 62].contains(Int(keyCode))
            if !isModifierOnly {
                let specialKeys: [UInt16: String] = [
                    49: "space", 36: "enter", 48: "tab",
                    126: "up", 125: "down", 123: "left", 124: "right", 53: "esc"
                ]
                let keyStr: String
                if let special = specialKeys[keyCode] {
                    keyStr = special
                } else if let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty {
                    keyStr = chars
                } else {
                    keyStr = ""
                }
                if !keyStr.isEmpty {
                    keys.append(keyStr)
                    self.hotkey = keys.joined(separator: "+")
                    self.stopRecording()
                    return nil
                }
            }
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

// MARK: - 键盘按键样式

struct KeyBadge: View {
    let key: String

    private var displayKey: String {
        switch key.lowercased() {
        case "cmd", "command": return "⌘"
        case "shift":          return "⇧"
        case "option", "opt":  return "⌥"
        case "ctrl", "control":return "⌃"
        case "enter":          return "↵"
        case "space":          return "Space"
        case "tab":            return "⇥"
        case "esc":            return "Esc"
        default:               return key
        }
    }

    var body: some View {
        Text(displayKey)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 30/255, green: 41/255, blue: 59/255))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color(red: 203/255, green: 213/255, blue: 225/255), lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 0, x: 0, y: 1)
            )
    }
}

// MARK: - 关于页

private struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {

            // App 图标 + 名称
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 59/255, green: 130/255, blue: 246/255),
                                         Color(red: 99/255, green: 102/255, blue: 241/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: DT.accent.opacity(0.3), radius: 10, x: 0, y: 5)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SnapClick")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                    Text("版本 1.0.2".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("官方网站".localized) {
                            // 打开网站
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("检查更新".localized) {
                            // 检查更新
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(DT.accent)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }

            // 功能卡片 2×2
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCard(
                    icon: "contextualmenu.and.cursorarrow",
                    iconColor: .blue,
                    title: "右键增强".localized,
                    description: "强化右键菜单，支持可编程快捷操作与快速新建。".localized
                )
                FeatureCard(
                    icon: "camera.viewfinder",
                    iconColor: .indigo,
                    title: "截图标注".localized,
                    description: "像素级区域截图，内置即时标注与 OCR 提取。".localized
                )
                FeatureCard(
                    icon: "record.circle",
                    iconColor: .red,
                    title: "屏幕录制".localized,
                    description: "高性能屏幕录制，支持音频路由与 GIF 导出。".localized
                )
                FeatureCard(
                    icon: "eyedropper.halffull",
                    iconColor: Color(red: 20/255, green: 184/255, blue: 166/255),
                    title: "取色器".localized,
                    description: "从屏幕任意位置拾取颜色，支持多格式输出。".localized
                )
            }

            // 版权信息
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("© 2026 SnapClick Team. All rights reserved.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text("专为 macOS 打造的原生效率工具集".localized)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - 功能特性卡片

private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    @State private var isHovered = false

    var body: some View {
        DesignCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 15/255, green: 23/255, blue: 42/255))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        }
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
