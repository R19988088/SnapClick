import AppKit
import ApplicationServices
import IOKit.hidsystem
import ScreenCaptureKit
import SwiftUI

@_silgen_name("_AXUIElementGetWindow") @discardableResult
private func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSOrderWindow")
@discardableResult
private func CGSOrderWindow(_ cid: UInt32, _ windowID: UInt32, _ place: Int32, _ relativeTo: UInt32) -> Int32

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private let finderDockPreviewController = FinderDockPreviewController()
    private let finderKeyActionController = FinderKeyActionController()
    private let screenCornerOverlayController = ScreenCornerOverlayController()

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
            selector: #selector(updateFinderKeyActions),
            name: .finderKeyActionsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDockWindowControl),
            name: .dockWindowControlDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateScreenCorners),
            name: .screenCornerDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateScreenCorners),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        updateDockWindowControl()
        updateFinderKeyActions()
        updateScreenCorners()

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

    @objc private func updateDockWindowControl() {
        finderDockPreviewController.setEnabled(AppSettings.shared.dockWindowControlEnabled)
    }

    @objc private func updateFinderKeyActions() {
        finderKeyActionController.setEnabled(
            AppSettings.shared.finderDeleteToTrashEnabled || AppSettings.shared.finderDoubleShiftCopyNamesEnabled
        )
    }

    @objc private func updateScreenCorners() {
        screenCornerOverlayController.setEnabled(AppSettings.shared.screenCornerEnabled)
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

private func dockPreviewPointerPath(in bounds: CGRect, orientation: String) -> CGPath {
    let path = CGMutablePath()
    switch orientation {
    case "left":
        path.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
    case "right":
        path.move(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
    default:
        path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
    }
    path.closeSubpath()
    return path
}

private final class FinderDockPreviewController {
    private enum PreviewMetrics {
        static let tileWidth: CGFloat = 179
        static let tileHeight: CGFloat = 161
        static let imageInset: CGFloat = 7
        static let imageHeight: CGFloat = 147
        static let spacing: CGFloat = 6
        static let panelHeight: CGFloat = 177
        static let tileCornerRadius: CGFloat = 16
        static let imageCornerRadius: CGFloat = 14
        static let panelCornerRadius: CGFloat = 22
        static let pointerSize: CGFloat = 12
    }

    private static let previewPointerIdentifier = NSUserInterfaceItemIdentifier("SnapClick.DockPreviewPointer")

    private final class PreviewPointerView: NSVisualEffectView {
        let orientation: String

        init(frame: NSRect, orientation: String) {
            self.orientation = orientation
            super.init(frame: frame)
            identifier = FinderDockPreviewController.previewPointerIdentifier
            material = .hudWindow
            blendingMode = .behindWindow
            state = .active
            wantsLayer = true
            updateMask()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            updateMask()
        }

        private func updateMask() {
            let mask = CAShapeLayer()
            mask.frame = bounds
            mask.path = dockPreviewPointerPath(in: bounds, orientation: orientation)
            layer?.mask = mask
        }
    }

    private final class PreviewTile: NSControl {
        private final class CloseButton: NSButton {
            override func draw(_ dirtyRect: NSRect) {
                let oval = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
                shadow.shadowBlurRadius = 4
                shadow.shadowOffset = NSSize(width: 0, height: -1)
                NSGraphicsContext.saveGraphicsState()
                shadow.set()
                NSColor.white.setFill()
                oval.fill()
                NSGraphicsContext.restoreGraphicsState()

                NSColor.white.setFill()
                oval.fill()

                NSColor.black.withAlphaComponent(0.24).setStroke()
                oval.lineWidth = 1
                oval.stroke()

                NSColor.darkGray.setStroke()
                let path = NSBezierPath()
                path.lineWidth = 2
                let inset: CGFloat = 6
                path.move(to: NSPoint(x: inset, y: inset))
                path.line(to: NSPoint(x: bounds.maxX - inset, y: bounds.maxY - inset))
                path.move(to: NSPoint(x: bounds.maxX - inset, y: inset))
                path.line(to: NSPoint(x: inset, y: bounds.maxY - inset))
                path.stroke()
            }
        }

        private final class ThumbnailView: NSView {
            var image: NSImage? {
                didSet { needsDisplay = true }
            }

            override func draw(_ dirtyRect: NSRect) {
                guard let image else { return }

                let imageRect = aspectFitRect(imageSize: image.size, in: bounds)
                guard imageRect.width > 1, imageRect.height > 1 else { return }

                let radius = PreviewMetrics.imageCornerRadius
                let shape = NSBezierPath(roundedRect: imageRect, xRadius: radius, yRadius: radius)
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
                shadow.shadowBlurRadius = 8
                shadow.shadowOffset = NSSize(width: 0, height: -3)

                NSGraphicsContext.saveGraphicsState()
                shadow.set()
                NSColor.white.setFill()
                shape.fill()
                NSGraphicsContext.restoreGraphicsState()

                NSGraphicsContext.saveGraphicsState()
                shape.addClip()
                image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
                NSGraphicsContext.restoreGraphicsState()

                let border = NSBezierPath(roundedRect: imageRect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
                border.lineWidth = 1
                NSColor.black.withAlphaComponent(0.3).setStroke()
                border.stroke()
            }

            private func aspectFitRect(imageSize: NSSize, in rect: NSRect) -> NSRect {
                guard imageSize.width > 0, imageSize.height > 0, rect.width > 0, rect.height > 0 else {
                    return .zero
                }
                let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
                let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
                return NSRect(
                    x: rect.midX - size.width / 2,
                    y: rect.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                )
            }
        }

        private let accentView = NSView()
        private let imageView = ThumbnailView()
        private let closeButton = CloseButton()
        private var trackingArea: NSTrackingArea?
        private var widthConstraint: NSLayoutConstraint?
        var actionHandler: (() -> Void)?
        var closeHandler: (() -> Void)?

        init(preview: DockWindowPreview) {
            super.init(frame: NSRect(x: 0, y: 0, width: PreviewMetrics.tileWidth, height: PreviewMetrics.tileHeight))
            translatesAutoresizingMaskIntoConstraints = false
            wantsLayer = true
            layer?.cornerRadius = PreviewMetrics.tileCornerRadius
            layer?.cornerCurve = .continuous
            layer?.masksToBounds = false
            layer?.backgroundColor = NSColor.clear.cgColor
            widthConstraint = widthAnchor.constraint(equalToConstant: PreviewMetrics.tileWidth)
            widthConstraint?.isActive = true
            heightAnchor.constraint(equalToConstant: PreviewMetrics.tileHeight).isActive = true

            let contentView = NSView(frame: bounds)
            contentView.autoresizingMask = [.width, .height]

            accentView.frame = bounds
            accentView.autoresizingMask = [.width, .height]
            accentView.wantsLayer = true
            accentView.layer?.cornerRadius = PreviewMetrics.tileCornerRadius
            accentView.layer?.cornerCurve = .continuous
            accentView.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            accentView.alphaValue = 0
            contentView.addSubview(accentView)

            imageView.image = preview.image
            imageView.frame = NSRect(
                x: PreviewMetrics.imageInset,
                y: PreviewMetrics.imageInset,
                width: PreviewMetrics.tileWidth - PreviewMetrics.imageInset * 2,
                height: PreviewMetrics.imageHeight
            )
            imageView.wantsLayer = true
            imageView.layer?.masksToBounds = false
            contentView.addSubview(imageView)

            closeButton.frame = NSRect(x: 11, y: PreviewMetrics.tileHeight - 29, width: 18, height: 18)
            closeButton.bezelStyle = .regularSquare
            closeButton.isBordered = false
            closeButton.wantsLayer = true
            closeButton.target = self
            closeButton.action = #selector(closeClicked)
            closeButton.alphaValue = 0
            contentView.addSubview(closeButton)

            addSubview(contentView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override var intrinsicContentSize: NSSize {
            NSSize(width: PreviewMetrics.tileWidth, height: PreviewMetrics.tileHeight)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            super.mouseEntered(with: event)
            accentView.alphaValue = 0.9
            closeButton.alphaValue = 1
        }

        override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            accentView.alphaValue = 0
            closeButton.alphaValue = 0
        }

        override func mouseDown(with event: NSEvent) {
            actionHandler?()
        }

        @objc private func closeClicked() {
            closeHandler?()
        }

        func updateImage(_ image: NSImage) {
            imageView.image = image
        }

        func collapse(completion: @escaping () -> Void) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                widthConstraint?.animator().constant = 0
                animator().alphaValue = 0
            } completionHandler: {
                self.removeFromSuperview()
                completion()
            }
        }
    }

    private struct DockApp {
        let app: NSRunningApplication
        let bounds: CGRect
    }

    private struct DockWindowPreview {
        let title: String
        let isMinimized: Bool
        let image: NSImage?
        let windowID: CGWindowID?
        let axWindow: AXUIElement?
        let app: NSRunningApplication
        let bounds: CGRect
    }

    private struct AXWindowInfo {
        let element: AXUIElement
        let windowID: CGWindowID
        let title: String
        let bounds: CGRect
        let isMinimized: Bool
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var previewPanel: NSPanel?
    private var previewAppPID: pid_t?
    private var previewOrientation: String?
    private var lastPreviewFingerprint: String?
    private var currentDockApp: DockApp?
    private var pendingDockClick: (app: DockApp, hadVisibleWindow: Bool)?
    private var lastRefresh = Date.distantPast
    private var thumbnailTilesByWindowID: [CGWindowID: PreviewTile] = [:]
    private var loadedThumbnailWindowIDs = Set<CGWindowID>()
    private var loadingThumbnailWindowIDs = Set<CGWindowID>()
    private var thumbnailTask: Task<Void, Never>?
    private var didRequestScreenRecordingForDockPreview = false

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

        let eventMask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<FinderDockPreviewController>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let point = event.location
            DispatchQueue.main.async {
                controller.handle(type: type, axPoint: point)
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
        pendingDockClick = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
        hidePreview()
    }

    private func startRetryingAfterPermissionGrant() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard AppSettings.shared.dockWindowControlEnabled else {
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

    private func handle(type: CGEventType, axPoint: CGPoint) {
        switch type {
        case .mouseMoved:
            handleMouseMoved(axPoint: axPoint)
        case .leftMouseDown:
            handleDockMouseDown(axPoint: axPoint)
        case .leftMouseUp:
            handleDockMouseUp(axPoint: axPoint)
        default:
            break
        }
    }

    private func handleMouseMoved(axPoint: CGPoint) {
        let appKitPoint = appKitPoint(fromAXPoint: axPoint)
        if let dockApp = dockApp(atAXPoint: axPoint) {
            if let currentDockApp,
               currentDockApp.app.processIdentifier != dockApp.app.processIdentifier {
                guard dockTargetCoreContains(axPoint, bounds: dockApp.bounds, axis: dockLayoutAxis()) else {
                    return
                }
                self.currentDockApp = dockApp
                lastRefresh = Date()
                showPreview(for: dockApp)
                return
            }

            if currentDockApp == nil {
                currentDockApp = dockApp
                lastRefresh = Date()
                showPreview(for: dockApp)
                return
            }

            if Date().timeIntervalSince(lastRefresh) > 0.12 {
                lastRefresh = Date()
                showPreview(for: currentDockApp ?? dockApp)
            }
        } else if let currentDockApp,
                  dockRetentionContains(axPoint, bounds: currentDockApp.bounds, axis: dockLayoutAxis()) {
            return
        } else if let currentDockApp, previewPanel?.frame.insetBy(dx: -10, dy: -10).contains(appKitPoint) == true {
            if Date().timeIntervalSince(lastRefresh) > 0.25 {
                lastRefresh = Date()
                showPreview(for: currentDockApp)
            }
        } else {
            hidePreview()
        }
    }

    private func handleDockMouseDown(axPoint: CGPoint) {
        guard let dockApp = dockApp(atAXPoint: axPoint) else { return }
        let previews = copyWindows(for: dockApp.app)
        guard !previews.isEmpty else { return }
        pendingDockClick = (dockApp, shouldMinimizeOnDockClick(app: dockApp.app, previews: previews))
    }

    private func handleDockMouseUp(axPoint: CGPoint) {
        guard let pendingDockClick else { return }
        self.pendingDockClick = nil
        guard dockApp(atAXPoint: axPoint)?.app.processIdentifier == pendingDockClick.app.app.processIdentifier else { return }
        let previews = copyWindows(for: pendingDockClick.app.app)
        guard !previews.isEmpty else { return }
        setWindows(previews, minimized: pendingDockClick.hadVisibleWindow)
    }

    private func showPreview(for dockApp: DockApp) {
        let previews = copyWindows(for: dockApp.app)
        guard !previews.isEmpty else {
            hidePreview()
            return
        }

        let contentWidth = CGFloat(previews.count) * PreviewMetrics.tileWidth
            + CGFloat(max(previews.count - 1, 0)) * PreviewMetrics.spacing
            + 16
        let orientation = dockOrientation()
        let sidePointerWidth = orientation == "bottom" ? 0 : PreviewMetrics.pointerSize
        let panelWidth = min(contentWidth, visibleFrame(near: dockApp.bounds).width - 24 - sidePointerWidth)
        let fingerprint = previewFingerprint(for: previews)
        let panel = previewPanel ?? makePanel()
        if previewPanel?.isVisible == true,
           previewAppPID == dockApp.app.processIdentifier,
           lastPreviewFingerprint == fingerprint,
           previewOrientation == orientation {
            panel.orderFrontRegardless()
            loadThumbnails(
                for: previews,
                maxSize: CGSize(width: PreviewMetrics.tileWidth - PreviewMetrics.imageInset * 2, height: PreviewMetrics.imageHeight),
                tilesByWindowID: thumbnailTilesByWindowID,
                appPID: dockApp.app.processIdentifier,
                fingerprint: fingerprint
            )
            return
        }

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = PreviewMetrics.spacing
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        var tilesByWindowID: [CGWindowID: PreviewTile] = [:]
        for preview in previews {
            let tile = PreviewTile(preview: preview)
            tile.actionHandler = { [weak self] in self?.activate(preview) }
            tile.closeHandler = { [weak self, weak tile] in self?.close(preview, tile: tile) }
            stack.addArrangedSubview(tile)
            if let windowID = preview.windowID {
                tilesByWindowID[windowID] = tile
            }
        }

        let panelFrame = frame(width: panelWidth, height: PreviewMetrics.panelHeight, near: dockApp.bounds)
        let pointerCenter = orientation == "bottom"
            ? dockApp.bounds.midX - panelFrame.minX
            : dockApp.bounds.midY - panelFrame.minY

        let contentFrame = panelContentFrame(
            width: panelWidth,
            height: PreviewMetrics.panelHeight,
            orientation: orientation
        )
        let scrollView = NSScrollView(frame: NSRect(origin: .zero, size: contentFrame.size))
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = contentWidth > panelWidth
        scrollView.hasVerticalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        stack.frame = NSRect(x: 0, y: 0, width: contentWidth, height: PreviewMetrics.panelHeight)
        scrollView.documentView = stack

        panel.contentView = panelGlassView(
            contentView: scrollView,
            orientation: orientation,
            pointerCenter: pointerCenter,
            panelSize: panelFrame.size,
            bodyFrame: contentFrame
        )
        panel.setFrame(panelFrame, display: true)
        previewAppPID = dockApp.app.processIdentifier
        previewOrientation = orientation
        lastPreviewFingerprint = fingerprint
        thumbnailTask?.cancel()
        thumbnailTilesByWindowID = tilesByWindowID
        loadedThumbnailWindowIDs = []
        loadingThumbnailWindowIDs = []
        panel.orderFrontRegardless()
        loadThumbnails(
            for: previews,
            maxSize: CGSize(width: PreviewMetrics.tileWidth - PreviewMetrics.imageInset * 2, height: PreviewMetrics.imageHeight),
            tilesByWindowID: tilesByWindowID,
            appPID: dockApp.app.processIdentifier,
            fingerprint: fingerprint
        )
    }

    private func hidePreview() {
        previewPanel?.orderOut(nil)
        previewAppPID = nil
        previewOrientation = nil
        lastPreviewFingerprint = nil
        currentDockApp = nil
        thumbnailTilesByWindowID = [:]
        loadedThumbnailWindowIDs = []
        loadingThumbnailWindowIDs = []
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        previewPanel = panel
        return panel
    }

    private func panelGlassView(
        contentView scrollView: NSScrollView,
        orientation: String,
        pointerCenter: CGFloat,
        panelSize: NSSize,
        bodyFrame: NSRect
    ) -> NSView {
        #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                return makeLiquidGlassContainer(
                    contentView: scrollView,
                    orientation: orientation,
                    pointerCenter: pointerCenter,
                    panelSize: panelSize,
                    bodyFrame: bodyFrame
                )
            }
        #endif

        let root = NSView(frame: NSRect(origin: .zero, size: panelSize))
        root.autoresizingMask = [.width, .height]

        let pointer = PreviewPointerView(
            frame: pointerFrame(
                orientation: orientation,
                pointerCenter: pointerCenter,
                panelSize: panelSize
            ),
            orientation: orientation
        )
        root.addSubview(pointer)

        let container = NSView(frame: bodyFrame)
        container.wantsLayer = true
        container.layer?.cornerRadius = PreviewMetrics.panelCornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        let effectView = NSVisualEffectView(frame: container.bounds)
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]
        container.addSubview(effectView)
        scrollView.frame = container.bounds
        container.addSubview(scrollView)
        root.addSubview(container)
        return root
    }

    #if compiler(>=6.2)
        @available(macOS 26.0, *)
        private func makeLiquidGlassContainer(
            contentView scrollView: NSScrollView,
            orientation: String,
            pointerCenter: CGFloat,
            panelSize: NSSize,
            bodyFrame: NSRect
        ) -> NSView {
            let container = NSGlassEffectContainerView(frame: NSRect(origin: .zero, size: panelSize))
            container.autoresizingMask = [.width, .height]
            container.spacing = 0

            let contentHost = NSView(frame: container.bounds)
            contentHost.autoresizingMask = [.width, .height]

            let pointerFrame = self.pointerFrame(
                orientation: orientation,
                pointerCenter: pointerCenter,
                panelSize: panelSize
            )
            let pointerView: NSView
            if orientation == "bottom" {
                pointerView = PreviewPointerView(frame: pointerFrame, orientation: orientation)
            } else {
                let pointerGlass = NSGlassEffectView(frame: pointerFrame)
                pointerGlass.identifier = Self.previewPointerIdentifier
                pointerGlass.style = .regular
                pointerGlass.contentView = NSView()
                applyPointerMask(to: pointerGlass, orientation: orientation)
                pointerView = pointerGlass
            }
            contentHost.addSubview(pointerView)

            let bodyGlass = NSGlassEffectView(frame: bodyFrame)
            bodyGlass.cornerRadius = PreviewMetrics.panelCornerRadius
            bodyGlass.style = .regular
            scrollView.frame = bodyGlass.bounds
            bodyGlass.contentView = scrollView
            contentHost.addSubview(bodyGlass)

            container.contentView = contentHost
            return container
        }
    #endif

    private func applyPointerMask(to view: NSView, orientation: String) {
        view.wantsLayer = true
        let mask = CAShapeLayer()
        mask.frame = view.bounds
        mask.path = dockPreviewPointerPath(in: view.bounds, orientation: orientation)
        view.layer?.mask = mask
    }

    private func previewPointerView(in root: NSView?) -> NSView? {
        guard let root else { return nil }
        if root.identifier == Self.previewPointerIdentifier { return root }
        for subview in root.subviews {
            if let match = previewPointerView(in: subview) { return match }
        }
        return nil
    }

    private func dockApp(atAXPoint point: CGPoint) -> DockApp? {
        guard let dockPID = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" })?.processIdentifier else {
            return nil
        }
        let dock = AXUIElementCreateApplication(dockPID)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(dock, Float(point.x), Float(point.y), &element) == .success,
              let element,
              let app = app(forDockElement: element),
              let bounds = elementBounds(element) else {
            return nil
        }
        return DockApp(app: app, bounds: bounds)
    }

    private func app(forDockElement element: AXUIElement) -> NSRunningApplication? {
        let texts = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap { attribute -> String? in
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
            return value as? String
        }
        let haystack = texts.joined(separator: " ")
        guard !haystack.isEmpty else { return nil }
        return NSWorkspace.shared.runningApplications.first { app in
            guard app.activationPolicy == .regular || app.bundleIdentifier == "com.apple.finder" else { return false }
            let names = [
                app.localizedName,
                app.bundleURL?.deletingPathExtension().lastPathComponent,
                app.bundleIdentifier
            ].compactMap { $0 }.map(normalized)
            let normalizedText = normalized(haystack)
            return names.contains { normalizedText == $0 || normalizedText.contains($0) }
        }
    }

    private func copyWindows(for app: NSRunningApplication) -> [DockWindowPreview] {
        let validAXWindows = validAXWindows(for: app.processIdentifier)
        let cgWindows = copyCGWindows(for: app)
        let appName = app.localizedName ?? "App"
        return cgWindows.compactMap { item in
            previewForCGWindow(item, app: app, appName: appName, cgWindows: cgWindows, validAXWindows: validAXWindows)
        }
    }

    private func previewForCGWindow(_ item: [String: Any], app: NSRunningApplication, appName: String, cgWindows: [[String: Any]], validAXWindows: [AXWindowInfo]) -> DockWindowPreview? {
        guard let windowID = windowIDValue(from: item[kCGWindowNumber as String]),
              let bounds = cgBounds(from: item) else { return nil }
        if let sharingState = item[kCGWindowSharingState as String] as? Int, sharingState == 0 { return nil }
        let title = item[kCGWindowName as String] as? String ?? ""
        let onScreen = (item[kCGWindowIsOnscreen as String] as? Bool) ?? false
        let matchedAXWindow = matchAXWindow(windowID: windowID, bounds: bounds, in: validAXWindows)
        if matchedAXWindow == nil && !isUsableCGWindowFallback(title: title, bounds: bounds, onScreen: onScreen) { return nil }
        let minimized = (matchedAXWindow?.isMinimized ?? false) || app.isHidden
        if !onScreen && !minimized && !app.isHidden && matchedAXWindow == nil && !validAXWindows.isEmpty { return nil }
        let previewTitle = matchedAXWindow?.title.isEmpty == false ? matchedAXWindow!.title : (title.isEmpty ? appName : title)
        return DockWindowPreview(title: previewTitle, isMinimized: minimized, image: nil, windowID: windowID, axWindow: matchedAXWindow?.element, app: app, bounds: bounds)
    }

    private func isUsableCGWindowFallback(title: String, bounds: CGRect, onScreen: Bool) -> Bool {
        onScreen && (!title.isEmpty || (bounds.width >= 300 && bounds.height >= 200))
    }

    private func validAXWindows(for pid: pid_t) -> [AXWindowInfo] {
        let appAX = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appAX, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.compactMap { window in
            guard let windowID = windowID(for: window),
                  let bounds = windowBounds(window),
                  isValidAXWindow(window) else { return nil }
            return AXWindowInfo(element: window, windowID: windowID, title: windowTitle(window), bounds: bounds, isMinimized: windowIsMinimized(window))
        }
    }

    private func isValidAXWindow(_ window: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleValue) == .success,
           let role = roleValue as? String,
           role != kAXWindowRole as String {
            return false
        }
        var subroleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleValue) == .success,
           let subrole = subroleValue as? String,
           subrole != kAXStandardWindowSubrole as String,
           subrole != kAXDialogSubrole as String,
           subrole != kAXFloatingWindowSubrole as String {
            return false
        }
        return hasAXAttribute(window, kAXCloseButtonAttribute) ||
            hasAXAttribute(window, kAXMinimizeButtonAttribute) ||
            !windowTitle(window).isEmpty
    }

    private func hasAXAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success && value != nil
    }

    private func matchAXWindow(windowID: CGWindowID, bounds: CGRect, in axWindows: [AXWindowInfo]) -> AXWindowInfo? {
        axWindows.first { $0.windowID == windowID }
            ?? axWindows.first { axWindow in
                abs(axWindow.bounds.minX - bounds.minX) < 2 &&
                    abs(axWindow.bounds.minY - bounds.minY) < 2 &&
                    abs(axWindow.bounds.width - bounds.width) < 2 &&
                    abs(axWindow.bounds.height - bounds.height) < 2
            }
    }

    private func previewFingerprint(for previews: [DockWindowPreview]) -> String {
        previews.map { preview in
            [
                String(preview.windowID ?? 0),
                preview.title,
                preview.isMinimized ? "m" : "v",
                "\(Int(preview.bounds.width))x\(Int(preview.bounds.height))"
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private func activate(_ preview: DockWindowPreview) {
        guard let axWindow = preview.axWindow else {
            if let windowID = preview.windowID {
                activateWindow(id: windowID, app: preview.app)
            } else {
                preview.app.activate(options: [.activateIgnoringOtherApps])
            }
            hidePreview()
            return
        }

        AXUIElementSetAttributeValue(axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        preview.app.activate(options: [.activateIgnoringOtherApps])
        let appAX = AXUIElementCreateApplication(preview.app.processIdentifier)
        AXUIElementSetAttributeValue(appAX, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        hidePreview()
    }

    private func activateWindow(id: CGWindowID, app: NSRunningApplication) {
        app.activate(options: [.activateIgnoringOtherApps])
        CGSOrderWindow(CGSMainConnectionID(), UInt32(id), 1, 0)
    }

    private func shouldMinimizeOnDockClick(app: NSRunningApplication, previews: [DockWindowPreview]) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
            && previews.contains { !$0.isMinimized }
    }

    private func setWindows(_ previews: [DockWindowPreview], minimized: Bool) {
        for preview in previews {
            if let axWindow = preview.axWindow {
                setWindow(axWindow, minimized: minimized)
            }
        }
        if !minimized {
            previews.first?.app.activate(options: [.activateIgnoringOtherApps])
        }
        hidePreview()
    }

    private func setWindow(_ window: AXUIElement, minimized: Bool) {
        if AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, minimized ? kCFBooleanTrue : kCFBooleanFalse) == .success {
            return
        }
        guard minimized else { return }
        var buttonValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &buttonValue) == .success,
           let button = buttonValue {
            AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
        }
    }

    private func close(_ preview: DockWindowPreview, tile: PreviewTile?) {
        guard let axWindow = preview.axWindow else { return }
        var buttonValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXCloseButtonAttribute as CFString, &buttonValue) == .success,
           let button = buttonValue {
            AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
        }
        if let windowID = preview.windowID {
            thumbnailTilesByWindowID.removeValue(forKey: windowID)
            loadedThumbnailWindowIDs.remove(windowID)
            loadingThumbnailWindowIDs.remove(windowID)
        }
        tile?.collapse { [weak self] in
            self?.shrinkPreviewPanelAfterTileClose()
        }
    }

    private func shrinkPreviewPanelAfterTileClose() {
        guard !thumbnailTilesByWindowID.isEmpty else {
            hidePreview()
            return
        }
        guard let currentDockApp else { return }
        showPreview(for: currentDockApp)
    }

    private func windowTitle(_ window: AXUIElement) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success else { return "" }
        return value as? String ?? ""
    }

    private func windowIsMinimized(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private func windowBounds(_ window: AXUIElement) -> CGRect? {
        axBounds(window).flatMap { $0.width > 40 && $0.height > 40 ? $0 : nil }
    }

    private func elementBounds(_ element: AXUIElement) -> CGRect? {
        axBounds(element).map(appKitRect(fromAXRect:))
    }

    private func axBounds(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionAX = positionValue,
              let sizeAX = sizeValue,
              CFGetTypeID(positionAX) == AXValueGetTypeID(),
              CFGetTypeID(sizeAX) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAX as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeAX as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    private func copyCGWindows(for app: NSRunningApplication) -> [[String: Any]] {
        guard let info = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let ownerNames = windowOwnerNames(for: app)
        return info.filter { item in
            (item[kCGWindowLayer as String] as? Int) == 0 &&
                (pidValue(from: item) == app.processIdentifier || ownerNameMatches(item: item, names: ownerNames))
        }
    }

    private func windowOwnerNames(for app: NSRunningApplication) -> [String] {
        [
            app.localizedName,
            app.bundleURL?.deletingPathExtension().lastPathComponent
        ].compactMap { $0 }.map(normalized)
    }

    private func ownerNameMatches(item: [String: Any], names: [String]) -> Bool {
        guard let owner = item[kCGWindowOwnerName as String] as? String else { return false }
        let normalizedOwner = normalized(owner)
        return names.contains { name in
            normalizedOwner == name ||
                normalizedOwner == "\(name).app" ||
                String(normalizedOwner.prefix(30)) == String(name.prefix(30))
        }
    }

    private func windowID(for window: AXUIElement) -> CGWindowID? {
        var windowID = CGWindowID(0)
        guard _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 else { return nil }
        return windowID
    }

    private func loadThumbnails(
        for previews: [DockWindowPreview],
        maxSize: CGSize,
        tilesByWindowID: [CGWindowID: PreviewTile],
        appPID: pid_t,
        fingerprint: String
    ) {
        let missing = previews.compactMap { preview -> (CGWindowID, PreviewTile)? in
            guard let windowID = preview.windowID,
                  !loadedThumbnailWindowIDs.contains(windowID),
                  !loadingThumbnailWindowIDs.contains(windowID),
                  let tile = tilesByWindowID[windowID] else { return nil }
            return (windowID, tile)
        }
        guard !missing.isEmpty else { return }
        guard PermissionManager.shared.checkScreenRecordingPermission() else {
            if !didRequestScreenRecordingForDockPreview {
                didRequestScreenRecordingForDockPreview = true
                PermissionManager.shared.requestScreenRecordingPermission()
            }
            return
        }

        loadingThumbnailWindowIDs.formUnion(missing.map(\.0))
        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            let windowIDs = missing.map(\.0)
            guard #available(macOS 14.0, *) else {
                await MainActor.run {
                    self.loadingThumbnailWindowIDs.subtract(windowIDs)
                }
                return
            }
            do {
                let content = try await SCShareableContent.current
                let captureWindowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
                for (windowID, tile) in missing {
                    guard !Task.isCancelled else { return }
                    guard let screenCaptureWindow = captureWindowsByID[windowID],
                          let image = try? await self.captureThumbnail(for: screenCaptureWindow, maxSize: maxSize) else { continue }
                    await MainActor.run {
                        guard self.previewAppPID == appPID,
                              self.lastPreviewFingerprint == fingerprint else { return }
                        self.loadedThumbnailWindowIDs.insert(windowID)
                        self.loadingThumbnailWindowIDs.remove(windowID)
                        tile.updateImage(image)
                    }
                }
            } catch {
            }
            await MainActor.run {
                guard self.previewAppPID == appPID,
                      self.lastPreviewFingerprint == fingerprint else { return }
                self.loadingThumbnailWindowIDs.subtract(windowIDs)
            }
        }
    }

    @available(macOS 14.0, *)
    private func captureThumbnail(for screenCaptureWindow: SCWindow, maxSize: CGSize) async throws -> NSImage {
        let sourceSize = screenCaptureWindow.frame.size
        let scale = min(
            maxSize.width / max(sourceSize.width, 1),
            maxSize.height / max(sourceSize.height, 1),
            1
        )
        let targetSize = CGSize(width: max(1, sourceSize.width * scale), height: max(1, sourceSize.height * scale))
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(targetSize.width * 2))
        configuration.height = max(1, Int(targetSize.height * 2))
        configuration.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: screenCaptureWindow)
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return NSImage(cgImage: image, size: targetSize)
    }

    private func cgBounds(from item: [String: Any]) -> CGRect? {
        guard let dict = item[kCGWindowBounds as String] as? [String: Any],
              let x = numberValue(in: dict, key: "X"),
              let y = numberValue(in: dict, key: "Y"),
              let w = numberValue(in: dict, key: "Width"),
              let h = numberValue(in: dict, key: "Height"),
              w > 40,
              h > 40 else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func windowIDValue(from value: Any?) -> CGWindowID? {
        if let id = value as? CGWindowID { return id }
        if let int = value as? Int { return CGWindowID(int) }
        if let number = value as? NSNumber { return CGWindowID(truncating: number) }
        return nil
    }

    private func pidValue(from item: [String: Any]) -> pid_t? {
        let value = item[kCGWindowOwnerPID as String]
        if let pid = value as? pid_t { return pid }
        if let number = value as? NSNumber { return number.int32Value }
        if let int = value as? Int { return pid_t(int) }
        return nil
    }

    private func numberValue(in dict: [String: Any], key: String) -> CGFloat? {
        let value = dict[key]
        if let cgFloat = value as? CGFloat { return cgFloat }
        if let double = value as? Double { return CGFloat(double) }
        if let int = value as? Int { return CGFloat(int) }
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        return nil
    }

    private func frame(width: CGFloat, height: CGFloat, near dockIcon: CGRect) -> CGRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(dockIcon) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let screenFrame = screen?.frame ?? visible
        let orientation = dockOrientation()
        let maximumIconSize = dockMaximumIconSize()
        let pointer = PreviewMetrics.pointerSize
        switch orientation {
        case "left":
            let stableRight = max(dockIcon.maxX, screenFrame.minX + maximumIconSize + 12)
            return CGRect(
                x: stableRight + 8 - pointer,
                y: clamp(dockIcon.midY - height / 2, visible.minY + 12, visible.maxY - height - 12),
                width: width + pointer,
                height: height
            )
        case "right":
            let stableLeft = min(dockIcon.minX, screenFrame.maxX - maximumIconSize - 12)
            return CGRect(
                x: stableLeft - width - 8,
                y: clamp(dockIcon.midY - height / 2, visible.minY + 12, visible.maxY - height - 12),
                width: width + pointer,
                height: height
            )
        default:
            let stableTop = screenFrame.minY + maximumIconSize + 12
            return CGRect(
                x: clamp(dockIcon.midX - width / 2, visible.minX + 12, visible.maxX - width - 12),
                y: stableTop + 8 - pointer,
                width: width,
                height: height + pointer
            )
        }
    }

    private func panelContentFrame(width: CGFloat, height: CGFloat, orientation: String) -> CGRect {
        switch orientation {
        case "left":
            return CGRect(x: PreviewMetrics.pointerSize, y: 0, width: width, height: height)
        default:
            return CGRect(
                x: 0,
                y: orientation == "bottom" ? PreviewMetrics.pointerSize : 0,
                width: width,
                height: height
            )
        }
    }

    private func pointerFrame(
        orientation: String,
        pointerCenter: CGFloat,
        panelSize: NSSize
    ) -> CGRect {
        let pointer = PreviewMetrics.pointerSize
        let base = pointer * 2
        switch orientation {
        case "left":
            return CGRect(
                x: 0,
                y: clamp(pointerCenter - base / 2, PreviewMetrics.panelCornerRadius, panelSize.height - PreviewMetrics.panelCornerRadius - base),
                width: pointer + 1,
                height: base
            )
        case "right":
            return CGRect(
                x: panelSize.width - pointer - 1,
                y: clamp(pointerCenter - base / 2, PreviewMetrics.panelCornerRadius, panelSize.height - PreviewMetrics.panelCornerRadius - base),
                width: pointer + 1,
                height: base
            )
        default:
            return CGRect(
                x: clamp(pointerCenter - base / 2, PreviewMetrics.panelCornerRadius, panelSize.width - PreviewMetrics.panelCornerRadius - base),
                y: 0,
                width: base,
                height: pointer + 1
            )
        }
    }

    private func dockMaximumIconSize() -> CGFloat {
        let tileSize = dockPreferenceNumber("tilesize") ?? 64
        let largeSize = dockPreferenceNumber("largesize") ?? tileSize
        let magnification = (CFPreferencesCopyAppValue(
            "magnification" as CFString,
            "com.apple.dock" as CFString
        ) as? NSNumber)?.boolValue ?? false
        return magnification ? max(tileSize, largeSize) : tileSize
    }

    private func dockPreferenceNumber(_ key: String) -> CGFloat? {
        guard let number = CFPreferencesCopyAppValue(
            key as CFString,
            "com.apple.dock" as CFString
        ) as? NSNumber else { return nil }
        return CGFloat(number.doubleValue)
    }

    private func visibleFrame(near rect: CGRect) -> CGRect {
        (NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
    }

    private func appKitPoint(fromAXPoint point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: maxScreenY() - point.y)
    }

    private func appKitRect(fromAXRect rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: maxScreenY() - rect.maxY, width: rect.width, height: rect.height)
    }

    private func maxScreenY() -> CGFloat {
        NSScreen.screens.map(\.frame.maxY).max() ?? 0
    }

    private func dockOrientation() -> String {
        CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String ?? "bottom"
    }

    private func dockLayoutAxis() -> DockLayoutAxis {
        dockOrientation() == "bottom" ? .horizontal : .vertical
    }

    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "访达", with: "Finder")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
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
           keyCode == 117,
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
            if now.timeIntervalSince(lastShiftDown) < 0.25 {
                lastShiftDown = Date.distantPast
                DispatchQueue.main.async {
                    self.copySelectedFinderNames()
                }
            } else {
                lastShiftDown = now
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
