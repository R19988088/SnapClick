import AppKit

@main
struct TestPrintScreenCapture {
    static func main() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

        assert(PrintScreenCapture.displayFrame(containing: CGPoint(x: 100, y: 100), from: [primary, secondary]) == primary)
        assert(PrintScreenCapture.displayFrame(containing: CGPoint(x: 1500, y: 100), from: [primary, secondary]) == secondary)
        assert(PrintScreenCapture.displayFrame(containing: CGPoint(x: -10, y: -10), from: [primary, secondary]) == primary)
    }
}
