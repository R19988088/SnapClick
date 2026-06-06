import SwiftUI

// MARK: - VisualEffectView
/// 桥接 NSVisualEffectView 以在 SwiftUI 中展现系统级通透毛玻璃 (Vibrancy) 效果
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - WelcomeView

/// 首次启动权限引导页
struct WelcomeView: View {

    /// 点击「完成设置」后的回调
    let onComplete: () -> Void

    @ObservedObject private var permission = PermissionManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @AppStorage("isFinderEnabled") private var isFinderEnabled: Bool = false

    private var grantedCount: Int {
        var count = 0
        if permission.hasScreenRecordingPermission { count += 1 }
        if permission.hasAccessibilityPermission { count += 1 }
        if isFinderEnabled { count += 1 }
        return count
    }

    var body: some View {
        HStack(spacing: 0) {

            // ── 左侧：Vibrancy 毛玻璃侧边栏 ─────────────────────────────
            ZStack(alignment: .topLeading) {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)

                VStack(alignment: .leading, spacing: 0) {

                    // 品牌 Header
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.gradient)
                                .frame(width: 34, height: 34)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)

                            Image(systemName: "camera.viewfinder")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("SnapClick".localized)
                                .font(.headline)
                            Text("v1.0.2".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .tracking(1)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                    // 导航伪菜单（为视觉一致性保留）
                    VStack(alignment: .leading, spacing: 6) {
                        FakeSidebarItem(icon: "gearshape", title: "通用", isActive: true)
                        FakeSidebarItem(icon: "folder", title: "Finder 增强")
                        FakeSidebarItem(icon: "camera.viewfinder", title: "截图与标注")
                    }
                    .padding(.top, 36)
                    .padding(.horizontal, 8)

                    Spacer()

                    // 底部：Setup Progress 进度面板
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SETUP PROGRESS".localized)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .tracking(0.5)

                        ProgressView(value: Double(grantedCount), total: 3)
                            .progressViewStyle(.linear)
                            .tint(Color.accentColor)

                        Text("\(grantedCount)" + " / 3 已授权".localized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.all, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .frame(width: 220)

            Divider()

            // ── 右侧：Main Content 主面板 ───────────────────────────────
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {

                            // 欢迎头部
                            VStack(spacing: 6) {
                                Text("欢迎使用 SnapClick".localized)
                                    .font(.title2.weight(.bold))

                                Text("让您的 macOS 效率飞跃，请授予以下权限以开启全部功能".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            .padding(.top, 24)

                            // 权限卡片列表
                            VStack(spacing: 10) {
                                PermissionGlassCard(
                                    icon: "video.badge.checkmark",
                                    iconBgColor: .blue.opacity(0.12),
                                    iconColor: .blue,
                                    title: "屏幕录制 (Screen Recording)".localized,
                                    description: "用于区域/窗口截图及放大镜取色".localized,
                                    isGranted: permission.hasScreenRecordingPermission,
                                    onAuthorize: {
                                        permission.requestScreenRecordingPermission()
                                    }
                                )

                                PermissionGlassCard(
                                    icon: "accessibility",
                                    iconBgColor: .purple.opacity(0.12),
                                    iconColor: .purple,
                                    title: "辅助功能 (Accessibility)".localized,
                                    description: "用于全局快捷键拦截与极速响应".localized,
                                    isGranted: permission.hasAccessibilityPermission,
                                    onAuthorize: {
                                        permission.requestAccessibilityPermission()
                                    }
                                )

                                PermissionGlassCard(
                                    icon: "folder.badge.gearshape",
                                    iconBgColor: .teal.opacity(0.12),
                                    iconColor: .teal,
                                    title: "Finder 右键扩展 (Finder Extension)".localized,
                                    description: "直接在系统右键菜单中集成高级新建文件与复制工具".localized,
                                    isGranted: isFinderEnabled,
                                    onAuthorize: {
                                        isFinderEnabled = true
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.extensions?FinderSync") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal, 20)

                            // 底部操作区与注意事项
                            VStack(spacing: 8) {
                                Button(action: onComplete) {
                                    Text("完成设置".localized)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .keyboardShortcut(.defaultAction)
                                .padding(.horizontal, 20)

                                Text("您可以随时在系统偏好设置中撤销或调整这些权限。".localized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .frame(width: 820, height: 580)
        .onAppear {
            permission.refreshAllPermissions()
            permission.startPolling()
        }
        .onDisappear {
            permission.stopPolling()
        }
    }
}

// MARK: - PermissionGlassCard

/// 精致的毛玻璃权限选项卡
private struct PermissionGlassCard: View {
    let icon: String
    let iconBgColor: Color
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let onAuthorize: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {

            // 左侧图标
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)

            // 中间详细描述
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧按钮 / 已启用标签
            if isGranted {
                Label("已启用".localized, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isGranted)
                    .accessibilityLabel(Text("\(title) 已启用"))
            } else {
                Button(title.contains("Finder") ? "去启用".localized : "去授权".localized,
                       action: onAuthorize)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isGranted)
                    .accessibilityLabel(Text("授权 \(title)"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.95 : 0.6))
                .shadow(color: .black.opacity(isHovered ? 0.04 : 0.01),
                        radius: isHovered ? 6 : 2, x: 0, y: isHovered ? 3 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(isHovered ? 0.6 : 0.3), lineWidth: 0.5)
        )
        .onHover { hover in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hover
            }
        }
    }
}

// MARK: - FakeSidebarItem

/// 伪侧边栏项目
private struct FakeSidebarItem: View {
    let icon: String
    let title: String
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.white : Color.secondary)
                .frame(width: 16)

            Text(title.localized)
                .font(.subheadline.weight(isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.white : Color.primary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.accentColor : Color.clear)
        )
    }
}

// MARK: - 预览
#Preview {
    WelcomeView(onComplete: {})
        .preferredColorScheme(.light)
}
