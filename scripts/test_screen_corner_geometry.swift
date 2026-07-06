import AppKit

final class AppSettings {
    static let shared = AppSettings()
    var screenCornerEnabled = true
    var screenCornerRadius = 24.0
}

@main
struct ScreenCornerGeometryTest {
    static func main() {
        let screen = CGRect(x: 10, y: 20, width: 300, height: 200)
        let rects = ScreenCornerOverlayController.cornerRects(screenFrame: screen, radius: 24)

        assert(rects == [
            CGRect(x: 10, y: 20, width: 24, height: 24),
            CGRect(x: 286, y: 20, width: 24, height: 24),
            CGRect(x: 10, y: 196, width: 24, height: 24),
            CGRect(x: 286, y: 196, width: 24, height: 24)
        ])
        assert(ScreenCornerOverlayController.cornerRects(screenFrame: screen, radius: 0).isEmpty)
        assert(ScreenCornerOverlayController.cornerRects(screenFrame: screen, radius: -8).isEmpty)
    }
}
