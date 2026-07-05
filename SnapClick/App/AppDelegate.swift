import AppKit
import ApplicationServices
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private let dockScrollVolumeController = DockScrollVolumeController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = NSImage(named: "AppIcon")

        statusBarController = StatusBarController(appDelegate: self)
        _ = PermissionManager.shared
        HotkeyManager.shared.registerAll()
        setupFinderCommandObserver()
        handleFinderCommand()

        // 启动时立即同步已安装的终端/开发工具到 SharedStore，
        // 并预热常用目录 / 文件类型的图标 Data，
        // 确保 FinderExtension 的 MenuBuilder 每次右键都直接命中缓存，
        // 不再触发 NSWorkspace.urlForApplication / icon(forFile:) 等
        // 会触发 TCC 弹窗的同步 I/O 调用。
        preheatFinderMenuAssets()

        // 监听收藏目录 / 文件模板变更，刷新图标缓存
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFinderMenuAssetsChanged),
            name: .finderMenuAssetsDidChange,
            object: nil
        )

        // 初始化并监听程序坞图标状态
        updateActivationPolicy()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateActivationPolicy),
            name: .showInDockDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDockScrollVolume),
            name: .dockScrollVolumeDidChange,
            object: nil
        )
        updateDockScrollVolume()

        // 监听毛玻璃透明效果变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGlassEffectChanged),
            name: .enableGlassEffectDidChange,
            object: nil
        )

        let settings = AppSettings.shared
        if settings.isFirstLaunch {
            showWelcomeWindow()
        }
    }

    /// 将系统中已安装的终端 / 编辑器信息、常用目录 / 文件类型图标
    /// 全部预加载并写入 SharedStore，供沙盒内的 FinderExtension 直接读取。
    /// FinderExtension 之后不再调用任何会触发 TCC 的 NSWorkspace API。
    private func preheatFinderMenuAssets() {
        let terminalCandidates: [(name: String, bundleID: String)] = [
            ("Terminal",  "com.apple.Terminal"),
            ("iTerm2",    "com.googlecode.iterm2"),
        ]
        let editorCandidates: [(name: String, bundleID: String)] = [
            ("VS Code",      "com.microsoft.VSCode"),
            ("Xcode",        "com.apple.dt.Xcode"),
            ("Sublime Text", "com.sublimetext.4"),
            ("TextEdit",     "com.apple.TextEdit"),
        ]
        let devTools = terminalCandidates + editorCandidates

        let dirPaths = FavoriteDirectoriesManager.shared.favorites.map { $0.path }
        let exts = NewFileTemplateManager.shared.enabledTemplates.map { $0.ext.lowercased() }

        // 同步预热：启动时一次性完成，所有 I/O 都在主进程进行，
        // 不会在 FinderExtension 沙盒内触发 TCC 弹窗
        IconCache.preheat(
            devTools: devTools,
            favoriteDirectoryPaths: dirPaths,
            fileTemplateExts: exts
        )
    }

    @objc private func handleFinderMenuAssetsChanged() {
        preheatFinderMenuAssets()
    }

    @objc private func updateActivationPolicy() {
        let showInDock = AppSettings.shared.showInDock
        if showInDock {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func updateDockScrollVolume() {
        dockScrollVolumeController.setEnabled(AppSettings.shared.dockScrollVolumeEnabled)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func openSettings() {
        print("[诊断] AppDelegate.openSettings 调用, settingsWindow == nil ? \(settingsWindow == nil)")
        if settingsWindow == nil {
            let hostingView = NSHostingView(rootView: MainWindow()
                .environmentObject(ColorPickerEngine.shared)
                .environmentObject(PinWindowManager.shared))
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "SnapClick 设置"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            // 不再透明，让标题栏区域由侧边栏的 VisualEffectView 自然延伸覆盖
            window.contentView = hostingView
            applyAppearance(to: window)
            applyGlassEffect(to: window)
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        applyAppearance(to: settingsWindow)
        applyGlassEffect(to: settingsWindow)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("[诊断] settingsWindow.frame = \(String(describing: settingsWindow?.frame)), isVisible = \(String(describing: settingsWindow?.isVisible)), screen = \(String(describing: settingsWindow?.screen))")
    }

    func closeSettings() {
        settingsWindow?.orderOut(nil)
    }

    private func applyAppearance(to window: NSWindow?) {
        guard let window else { return }
        switch AppSettings.shared.appAppearance {
        case "light": window.appearance = NSAppearance(named: .aqua)
        case "dark":  window.appearance = NSAppearance(named: .darkAqua)
        default:      window.appearance = nil
        }
    }

    private func applyGlassEffect(to window: NSWindow?) {
        guard let window else { return }
        if AppSettings.shared.enableGlassEffect {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
        print("[诊断玻璃] enableGlassEffect=\(AppSettings.shared.enableGlassEffect) isOpaque=\(window.isOpaque) bg=\(String(describing: window.backgroundColor)) contentView=\(String(describing: type(of: window.contentView)))")
    }

    @objc private func handleGlassEffectChanged() {
        applyGlassEffect(to: settingsWindow)
        applyGlassEffect(to: welcomeWindow)
    }

    private func setupFinderCommandObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            center,
            observer,
            { (_, observer, name, _, _) in
                guard let observer = observer else { return }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                delegate.handleFinderCommand()
            },
            "com.snapclick.app.findercommand" as CFString,
            nil,
            .deliverImmediately
        )
    }

    @objc private func handleFinderCommand() {
        // 从命名剪贴板读取命令（与 FinderSync.sendCommand 配套）
        let pb = NSPasteboard(name: NSPasteboard.Name("com.snapclick.app.ipc"))
        guard let jsonStr = pb.string(forType: .string),
              let data = jsonStr.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        // 读取后清空，避免重复处理
        pb.clearContents()

        processFinderPayload(payload)
    }

    private func processFinderPayload(_ payload: [String: Any]) {
        guard let command = payload["cmd"] as? String else { return }

        let selectedPaths    = payload["items"] as? [String] ?? []
        let targetDirStr     = payload["dir"] as? String ?? ""
        let representedDict  = payload["dict"] as? [String: String]
        let representedString = payload["str"] as? String

        let selectedURLs = selectedPaths.map { URL(fileURLWithPath: $0) }
        let targetURL: URL? = targetDirStr.isEmpty ? nil : URL(fileURLWithPath: targetDirStr)

        DispatchQueue.main.async {
            switch command {
            case "createNewFile":
                guard let dest = targetURL, let dict = representedDict else { return }
                if let createdURL = FileOperations.shared.createNewFile(dict: dict, in: dest) {
                    FileOperations.revealAndRenameInFinder(createdURL)
                }

            case "cutFiles":
                FileOperations.shared.cutFiles(items: selectedURLs)

            case "copyFiles":
                FileOperations.shared.copyFiles(items: selectedURLs)

            case "pasteFiles":
                guard let dest = targetURL else { return }
                FileOperations.shared.pasteFiles(to: dest)

            case "moveToDirectory":
                let destPath = representedString ?? "__choose__"
                FileOperations.shared.moveOrCopy(items: selectedURLs, destPath: destPath, isCopy: false)

            case "copyToDirectory":
                let destPath = representedString ?? "__choose__"
                FileOperations.shared.moveOrCopy(items: selectedURLs, destPath: destPath, isCopy: true)

            case "copyPath":
                let kind = representedString ?? "full"
                FileOperations.shared.copyPath(items: selectedURLs, kind: kind)

            case "computeHash":
                let algo = representedString ?? "sha256"
                FileOperations.shared.computeHash(items: selectedURLs, algo: algo)

            case "openWithDevTool":
                guard let bundleID = representedString else { return }
                FileOperations.shared.openWithDevTool(items: selectedURLs, bundleID: bundleID)

            case "openInTerminal":
                guard let dest = targetURL else { return }
                let terminalBundleID = representedString ?? "com.apple.Terminal"
                FileOperations.shared.openInTerminal(directory: dest, terminalBundleID: terminalBundleID)

            case "openDirectory":
                guard let path = representedString, !path.isEmpty else { return }
                NSWorkspace.shared.open(URL(fileURLWithPath: path))

            case "airDrop":
                FileOperations.shared.airDrop(items: selectedURLs)

            default:
                break
            }
        }
    }

    private func showWelcomeWindow() {
        let hostingView = NSHostingView(rootView: WelcomeView {
            AppSettings.shared.isFirstLaunch = false
            self.welcomeWindow?.close()
            self.welcomeWindow = nil
        })
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 SnapClick".localized
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        applyGlassEffect(to: window)
        window.center()
        window.isReleasedWhenClosed = false
        welcomeWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class DockScrollVolumeController {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var lastChange = Date.distantPast

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard eventTap == nil else { return }
        guard PermissionManager.shared.checkAccessibilityPermission() else {
            PermissionManager.shared.requestAccessibilityPermission()
            startRetryingAfterPermissionGrant()
            return
        }
        stopRetrying()

        let eventMask = (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<DockScrollVolumeController>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
            let lineDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let pixelDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            let delta = lineDelta != 0 ? lineDelta : pixelDelta
            DispatchQueue.main.async {
                controller.handleScroll(deltaY: delta)
            }
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            PermissionManager.shared.requestAccessibilityPermission()
            startRetryingAfterPermissionGrant()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    private func stop() {
        stopRetrying()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func startRetryingAfterPermissionGrant() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard AppSettings.shared.dockScrollVolumeEnabled else {
                self.stop()
                return
            }
            if PermissionManager.shared.checkAccessibilityPermission() {
                timer.invalidate()
                self.retryTimer = nil
                self.start()
            }
        }
    }

    private func stopRetrying() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func handleScroll(deltaY: Int64) {
        guard deltaY != 0,
              Date().timeIntervalSince(lastChange) > 0.08,
              isPointerOverAppDockIcon() else { return }

        lastChange = Date()
        changeOutputVolume(by: deltaY > 0 ? 5 : -5)
    }

    private func isPointerOverAppDockIcon() -> Bool {
        let mouse = NSEvent.mouseLocation
        let desktop = NSScreen.screens.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let point = CGPoint(x: mouse.x, y: desktop.maxY - mouse.y)
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?

        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success,
              let element else { return false }

        return titleMatchesApp(in: element)
    }

    private func titleMatchesApp(in element: AXUIElement) -> Bool {
        let names = [
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            ProcessInfo.processInfo.processName,
            "SnapClick"
        ].compactMap { $0 }
        var current: AXUIElement? = element

        for _ in 0..<4 {
            guard let item = current else { return false }
            let values = [
                axString(item, kAXTitleAttribute as String),
                axString(item, kAXDescriptionAttribute as String),
                axString(item, kAXHelpAttribute as String)
            ].compactMap { $0 }
            if values.contains(where: { value in names.contains { value.localizedCaseInsensitiveContains($0) } }) {
                return true
            }

            var parent: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXParentAttribute as CFString, &parent)
            current = parent.map { $0 as! AXUIElement }
        }

        return false
    }

    private func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func changeOutputVolume(by delta: Int) {
        let script = """
        set currentVolume to output volume of (get volume settings)
        set volume output volume (max(0, min(100, currentVolume + \(delta))))
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }
}
