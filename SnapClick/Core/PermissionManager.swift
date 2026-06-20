import AppKit
import AVFoundation
import ApplicationServices
import FinderSync

final class PermissionManager: ObservableObject {

    static let shared = PermissionManager()
    private init() {
        hasAccessibilityPermission    = checkAccessibilityPermission()
        hasScreenRecordingPermission  = checkScreenRecordingPermission()
        // pluginkit 检测放后台，不阻塞启动
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let finder = self.checkFinderExtensionPermission()
            DispatchQueue.main.async { self.hasFinderExtensionPermission = finder }
        }
    }

    @Published var hasScreenRecordingPermission: Bool = false
    @Published var hasAccessibilityPermission: Bool = false
    @Published var hasFinderExtensionPermission: Bool = false
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

            DispatchQueue.main.async {
                self.hasScreenRecordingPermission = screen
                self.hasAccessibilityPermission   = accessibility
                self.hasFinderExtensionPermission = finder
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
        openLoginItemsPreferences()
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

        // 弹出系统提示（有时无效，因此同时打开设置页面）
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }

        // 直接打开登录项与扩展设置页面，确保用户能找到开关
        openLoginItemsPreferences()

        if !trusted {
            startPolling()
        }
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

    private func openLoginItemsPreferences() {
        let urlString: String
        if #available(macOS 15.0, *) {
            urlString = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        } else if #available(macOS 13.0, *) {
            urlString = "x-apple.systempreferences:com.apple.settings.LoginItems"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.loginitems"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
