import AppKit

final class ScreenCornerOverlayController {
    private var windows: [NSWindow] = []

    func setEnabled(_ enabled: Bool) {
        enabled ? refresh() : hide()
    }

    func refresh() {
        guard AppSettings.shared.screenCornerEnabled else {
            hide()
            return
        }

        hide()
        let radius = CGFloat(AppSettings.shared.screenCornerRadius)
        guard radius > 0 else { return }

        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.sharingType = .none
            window.contentView = ScreenCornerOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size), radius: radius)
            window.orderFrontRegardless()
            return window
        }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    static func cornerRects(screenFrame: CGRect, radius: CGFloat) -> [CGRect] {
        guard radius > 0 else { return [] }
        return [
            CGRect(x: screenFrame.minX, y: screenFrame.minY, width: radius, height: radius),
            CGRect(x: screenFrame.maxX - radius, y: screenFrame.minY, width: radius, height: radius),
            CGRect(x: screenFrame.minX, y: screenFrame.maxY - radius, width: radius, height: radius),
            CGRect(x: screenFrame.maxX - radius, y: screenFrame.maxY - radius, width: radius, height: radius)
        ]
    }
}

private final class ScreenCornerOverlayView: NSView {
    private let radius: CGFloat

    init(frame: NSRect, radius: CGFloat) {
        self.radius = radius
        super.init(frame: frame)
        wantsLayer = true
        layer = makeLayer()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var frame: NSRect {
        didSet {
            layer = makeLayer()
        }
    }

    private func makeLayer() -> CALayer {
        let shape = CAShapeLayer()
        shape.frame = bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRoundedRect(in: bounds, cornerWidth: radius, cornerHeight: radius)
        shape.path = path
        shape.fillRule = .evenOdd
        shape.fillColor = NSColor.black.cgColor
        return shape
    }
}
