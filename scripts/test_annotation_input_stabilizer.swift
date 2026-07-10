import CoreGraphics
import Foundation

@main
enum AnnotationInputStabilizerTest {
    static func main() {
        var stabilizer = AnnotationInputStabilizer()

        let first = stabilizer.filter(
            point: CGPoint(x: 10, y: 20),
            pressure: 0.2,
            timestamp: 1
        )
        expect(first.point == CGPoint(x: 10, y: 20), "first point must emit immediately")
        expect(close(first.pressure, 0.2), "first pressure must emit immediately")

        _ = stabilizer.filter(point: CGPoint(x: 11, y: 20), pressure: 0.4, timestamp: 1.01)
        _ = stabilizer.filter(point: CGPoint(x: 12, y: 20), pressure: 0.6, timestamp: 1.02)
        let fourth = stabilizer.filter(point: CGPoint(x: 13, y: 20), pressure: 0.8, timestamp: 1.03)
        expect(close(fourth.pressure, 0.5), "pressure must average the latest four samples")

        stabilizer.reset()
        let reset = stabilizer.filter(point: .zero, pressure: 1, timestamp: 2)
        expect(close(reset.pressure, 1), "reset must clear pressure history")

        let slow = stabilizer.filter(point: CGPoint(x: 0.2, y: 0), pressure: 1, timestamp: 2.01)
        expect(slow.point.x > 0 && slow.point.x < 0.2, "slow jitter must be smoothed")

        stabilizer.reset()
        _ = stabilizer.filter(point: .zero, pressure: 1, timestamp: 3)
        let fast = stabilizer.filter(point: CGPoint(x: 100, y: 0), pressure: 1, timestamp: 3.01)
        expect(fast.point.x > 95, "fast motion must stay close to raw input")

        print("AnnotationInputStabilizer tests passed")
    }

    private static func close(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.0001
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
