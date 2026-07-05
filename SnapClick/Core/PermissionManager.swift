import AppKit
import AVFoundation
import ApplicationServices
import FinderSync

final class PermissionManager: ObservableObject {

    static let shared = PermissionManager()
    private init() {
        hasAccessibilityPermission    = checkAccessibilityPermission()
        hasScreenRecordingPermission  = checkScreenRecordingPermission()
        // pluginkit 及完全磁盘访问检测放后台，不阻塞启动
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let finder   = self.checkFinderExtensionPermission()
            let fullDisk = self.checkFullDiskAccessPermission()
            DispatchQueue.main.async {
                self.hasFinderExtensionPermission = finder
                self.hasFullDiskAccessPermission  = fullDisk
            }
        }
    }

    @Published var hasScreenRecordingPermission: Bool = false
    @Published var hasAccessibilityPermission: Bool = false
    @Published var hasFinderExtensionPermission: Bool = false
    /// 完全磁盘访问权限（可选，用于外接磁盘场景）
    @Published var hasFullDiskAccessPermission: Bool = false
    @Published var isRefreshing: Bool = false

    private var pollingTimer: Timer?

    func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllPermissions()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func refreshAllPermissions() {
        guard !isRefreshing else { return }
        isRefreshing = true
        // pluginkit 会阻塞线程，必须放后台执行，结果回主线程更新 UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let screen        = self.checkScreenRecordingPermission()
            let accessibility = self.checkAccessibilityPermission()
            let finder        = self.checkFinderExtensionPermission()
            let fullDisk      = self.checkFullDiskAccessPermission()

            DispatchQueue.main.async {
                self.hasScreenRecordingPermission = screen
                self.hasAccessibilityPermission   = accessibility
                self.hasFinderExtensionPermission = finder
                self.hasFullDiskAccessPermission  = fullDisk
                self.isRefreshing = false

                if screen && accessibility {
                    self.stopPolling()
                }
            }
        }
    }

    func checkScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecordingPermission() {
        guard !checkScreenRecordingPermission() else {
            refreshAllPermissions()
            return
        }

        _ = CGRequestScreenCaptureAccess()
        openScreenRecordingPreferences()
        startPolling()
    }

    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        guard !AXIsProcessTrusted() else {
            refreshAllPermissions()
            return
        }

        // 直接打开对应的设置页面让用户手动开启辅助功能
        // 不使用 kAXTrustedCheckOptionPrompt，避免弹出系统提示框
        openAccessibilityPreferences()
        startPolling()
    }

    func checkFinderExtensionPermission() -> Bool {
        // FIFinderSyncController 的查询 API 仅限扩展进程内使用
        // 主 App 只能通过 pluginkit 命令行工具检测扩展是否已启用
        // pluginkit 输出格式：已启用前缀为 "+"，禁用为 "!" 或 "-"
        let bundleID = "com.snapclick.app.FinderExtension"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        task.arguments = ["-m", "-A", "-i", bundleID]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            // 输出示例（已启用）："    + com.snapclick.app.FinderExtension(1.0)\n"
            return output.contains("+")
        } catch {
            return false
        }
    }

    func requestFinderExtensionPermission() {
        // 使用官方 API 直接打开到 SnapClick 自己的 Finder 扩展管理界面
        // 比通用 systempreferences URL 精确，可直接定位到本 App 的扩展启用开关
        FIFinderSyncController.showExtensionManagementInterface()
        startPolling()
    }

    private func openScreenRecordingPreferences() {
        let urlString: String
        if #available(macOS 13.0, *) {
            urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilityPreferences() {
        let urlString: String
        if #available(macOS 13.0, *) {
            urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    // MARK: - 完全磁盘访问权限（可选）

    func checkFullDiskAccessPermission() -> Bool {
        // 尝试读取仅完全磁盘访问权限才能访问的受保护目录来判断是否已授权
        let protectedPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        return FileManager.default.isReadableFile(atPath: protectedPath)
    }

    func requestFullDiskAccessPermission() {
        openFullDiskAccessPreferences()
    }

    private func openFullDiskAccessPreferences() {
        let urlString: String
        if #available(macOS 13.0, *) {
            urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
