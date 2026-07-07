import AppKit
#if !TESTING
import ScreenCaptureKit
#endif

enum PrintScreenCapture {
    static func displayFrame(containing point: CGPoint, from frames: [CGRect]) -> CGRect {
        frames.first(where: { $0.contains(point) }) ?? frames.first ?? .zero
    }

#if !TESTING
    @MainActor
    @discardableResult
    static func captureMouseScreenToDesktop() async throws -> URL {
        let mouse = NSEvent.mouseLocation
        let targetFrame = displayFrame(containing: mouse, from: NSScreen.screens.map(\.frame))
        let screen = NSScreen.screens.first { $0.frame == targetFrame } ?? NSScreen.main

        guard let screen else { throw ScreenCaptureError.noScreenAvailable }
        let image = try await capture(screen: screen)
        let url = desktopURL().appendingPathComponent(fileName())
        let data = try ScreenCaptureEngine.shared.pngData(for: image)
        try data.write(to: url, options: .atomic)
        return url
    }

    @MainActor
    private static func capture(screen: NSScreen) async throws -> NSImage {
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID)
            ?? CGMainDisplayID()
        let scale = screen.backingScaleFactor

        if #available(macOS 14.0, *) {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                if let display = content.displays.first(where: { $0.displayID == displayID }) {
                    let config = SCStreamConfiguration()
                    config.width = Int(CGFloat(display.width) * scale)
                    config.height = Int(CGFloat(display.height) * scale)
                    config.showsCursor = false
                    config.capturesAudio = false
                    let cg = try await SCScreenshotManager.captureImage(
                        contentFilter: SCContentFilter(display: display, excludingWindows: []),
                        configuration: config
                    )
                    return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / scale, height: CGFloat(cg.height) / scale))
                }
            } catch {
                // fall back to CGDisplayCreateImage below
            }
        }

        guard let cg = await Task.detached(priority: .userInitiated, operation: {
            CGDisplayCreateImage(displayID)
        }).value else {
            throw ScreenCaptureError.imageConversionFailed
        }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / scale, height: CGFloat(cg.height) / scale))
    }

    private static func desktopURL() -> URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
    }

    private static func fileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        return "SnapClick_全屏_\(formatter.string(from: Date())).png"
    }
#endif
}
