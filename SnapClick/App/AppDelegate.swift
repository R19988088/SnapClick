import AppKit
import ApplicationServices
import AudioToolbox
import CoreAudio
import IOKit.hidsystem
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private let dockScrollVolumeController = DockScrollVolumeController()
    private let finderKeyActionController = FinderKeyActionController()

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFinderKeyActions),
            name: .finderKeyActionsDidChange,
            object: nil
        )
        updateDockScrollVolume()
        updateFinderKeyActions()

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

    @objc private func updateFinderKeyActions() {
        finderKeyActionController.setEnabled(
            AppSettings.shared.finderDeleteToTrashEnabled || AppSettings.shared.finderDoubleShiftCopyNamesEnabled
        )
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
    private var globalMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var lastChange = Date.distantPast

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard globalMonitor == nil && eventTap == nil else { return }
        guard PermissionManager.shared.checkAccessibilityPermission() else {
            PermissionManager.shared.requestAccessibilityPermission()
            startRetryingAfterPermissionGrant()
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            DispatchQueue.main.async {
                let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.scrollingDeltaX
                guard delta != 0 else { return }
                self?.handleScroll(deltaY: Int64(delta < 0 ? -1 : 1))
            }
        }

        if !InputMonitoringPermission.isGranted {
            InputMonitoringPermission.request()
            startRetryingAfterPermissionGrant()
        } else {
            stopRetrying()
        }

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
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
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
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        globalMonitor = nil
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
            if PermissionManager.shared.checkAccessibilityPermission(), InputMonitoringPermission.isGranted {
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
              isPointerInDockEdgeRegion() else { return }

        lastChange = Date()
        SystemOutputVolumeController.changeVolume(byPercent: deltaY > 0 ? 5 : -5)
    }

    private func isPointerInDockEdgeRegion() -> Bool {
        let mouse = NSEvent.mouseLocation
        if currentDockRects().contains(where: { $0.contains(mouse) }) {
            return true
        }
        return fallbackDockRects().contains { $0.contains(mouse) }
    }

    private func currentDockRects() -> [CGRect] {
        guard PermissionManager.shared.checkAccessibilityPermission(),
              let pid = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" })?.processIdentifier else {
            return []
        }

        let dock = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dock, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return []
        }

        let maxY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        return windows.flatMap { window -> [CGRect] in
            var posValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
                  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
                  let posAX = posValue,
                  let sizeAX = sizeValue,
                  CFGetTypeID(posAX) == AXValueGetTypeID(),
                  CFGetTypeID(sizeAX) == AXValueGetTypeID() else {
                return []
            }

            var point = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(posAX as! AXValue, .cgPoint, &point)
            AXValueGetValue(sizeAX as! AXValue, .cgSize, &size)
            let raw = CGRect(origin: point, size: size)
            let converted = CGRect(x: raw.minX, y: maxY - raw.maxY, width: raw.width, height: raw.height)
            return [raw, converted].filter { !$0.isEmpty }
        }
    }

    private func fallbackDockRects() -> [CGRect] {
        let orientation = CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String ?? "bottom"
        let tileSize = (CFPreferencesCopyAppValue("tilesize" as CFString, "com.apple.dock" as CFString) as? NSNumber)?.doubleValue ?? 64
        let edge = CGFloat(max(96, tileSize + 56))

        return NSScreen.screens.map { screen in
            let frame = screen.frame
            switch orientation {
            case "left":
                return CGRect(x: frame.minX, y: frame.minY, width: edge, height: frame.height)
            case "right":
                return CGRect(x: frame.maxX - edge, y: frame.minY, width: edge, height: frame.height)
            default:
                return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: edge)
            }
        }
    }
}

private enum SystemOutputVolumeController {
    static func changeVolume(byPercent delta: Float32) {
        guard let deviceID = defaultOutputDeviceID(),
              let current = readVolume(deviceID: deviceID) else { return }
        let next = min(1, max(0, current + delta / 100))
        unmute(deviceID: deviceID)
        _ = setVolume(deviceID: deviceID, value: next)
    }

    private static func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != AudioDeviceID(kAudioObjectUnknown) else {
            return nil
        }
        return deviceID
    }

    private static func readVolume(deviceID: AudioDeviceID) -> Float32? {
        if let volume = getScalar(deviceID: deviceID, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, element: kAudioObjectPropertyElementMain) {
            return volume
        }
        if let volume = getScalar(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: kAudioObjectPropertyElementMain) {
            return volume
        }

        let channels = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
            .compactMap { getScalar(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: $0) }
        guard !channels.isEmpty else { return nil }
        return channels.reduce(0, +) / Float32(channels.count)
    }

    @discardableResult
    private static func setVolume(deviceID: AudioDeviceID, value: Float32) -> Bool {
        if setScalar(deviceID: deviceID, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, element: kAudioObjectPropertyElementMain, value: value) {
            return true
        }
        if setScalar(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: kAudioObjectPropertyElementMain, value: value) {
            return true
        }

        let left = setScalar(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: 1, value: value)
        let right = setScalar(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: 2, value: value)
        return left || right
    }

    private static func getScalar(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> Float32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func setScalar(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement, value: Float32) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr, settable.boolValue else { return false }
        var newValue = value
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newValue) == noErr
    }

    private static func unmute(deviceID: AudioDeviceID) {
        for element in [kAudioObjectPropertyElementMain, AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)] {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var settable = DarwinBoolean(false)
            guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr, settable.boolValue else { continue }
            var muted = UInt32(0)
            _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muted)
        }
    }
}

private final class FinderKeyActionController {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var lastShiftDown = Date.distantPast

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
        guard InputMonitoringPermission.isGranted else {
            InputMonitoringPermission.request()
            startRetryingAfterPermissionGrant()
            return
        }
        stopRetrying()

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<FinderKeyActionController>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            if controller.handle(type: type, event: event) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
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
            let settings = AppSettings.shared
            guard settings.finderDeleteToTrashEnabled || settings.finderDoubleShiftCopyNamesEnabled else {
                self.stop()
                return
            }
            if PermissionManager.shared.checkAccessibilityPermission(), InputMonitoringPermission.isGranted {
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

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return false }

        let settings = AppSettings.shared
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown,
           settings.finderDeleteToTrashEnabled,
           (keyCode == 51 || keyCode == 117),
           event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty {
            DispatchQueue.main.async {
                self.trashFinderSelection()
            }
            return true
        }

        if type == .flagsChanged,
           settings.finderDoubleShiftCopyNamesEnabled,
           (keyCode == 56 || keyCode == 60),
           event.flags.contains(.maskShift) {
            let now = Date()
            defer { lastShiftDown = now }
            if now.timeIntervalSince(lastShiftDown) < 0.35 {
                DispatchQueue.main.async {
                    self.copySelectedFinderNames()
                }
            }
        }

        return false
    }

    private func trashFinderSelection() {
        var moved = false
        for url in selectedFinderURLs() {
            if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil {
                moved = true
            }
        }
        if moved {
            playTrashSound()
        }
    }

    private func copySelectedFinderNames() {
        let urls = selectedFinderURLs()
        guard urls.count > 1 else { return }
        let names = urls.map(\.lastPathComponent).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(names.joined(separator: "\n"), forType: .string)
    }

    private func selectedFinderURLs() -> [URL] {
        let script = """
        tell application "Finder"
            if frontmost is false then return ""
            set output to ""
            repeat with itemRef in (selection as list)
                set output to output & POSIX path of (itemRef as alias) & linefeed
            end repeat
            return output
        end tell
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue ?? ""
        return result
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
    }

    private func playTrashSound() {
        let path = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag to trash.aif"
        NSSound(contentsOfFile: path, byReference: true)?.play()
    }
}

private enum InputMonitoringPermission {
    static var isGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static func request() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        let urlString: String
        if #available(macOS 13.0, *) {
            urlString = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
