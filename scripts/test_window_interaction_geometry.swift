import CoreGraphics
import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

@main
private enum WindowInteractionGeometryTests {
    static func main() {
        let horizontalIcon = CGRect(x: 100, y: 20, width: 100, height: 80)
        expect(!dockTargetCoreContains(CGPoint(x: 114.9, y: 60), bounds: horizontalIcon, axis: .horizontal), "left 15% must not switch")
        expect(dockTargetCoreContains(CGPoint(x: 115, y: 60), bounds: horizontalIcon, axis: .horizontal), "middle 70% must switch")
        expect(dockTargetCoreContains(CGPoint(x: 185, y: 60), bounds: horizontalIcon, axis: .horizontal), "right boundary of middle 70% must switch")
        expect(!dockTargetCoreContains(CGPoint(x: 185.1, y: 60), bounds: horizontalIcon, axis: .horizontal), "right 15% must not switch")
        expect(dockRetentionContains(CGPoint(x: 80, y: 60), bounds: horizontalIcon, axis: .horizontal), "20% side extension must retain")
        expect(!dockRetentionContains(CGPoint(x: 79.9, y: 60), bounds: horizontalIcon, axis: .horizontal), "outside 20% extension must hide")
        expect(!dockRetentionContains(CGPoint(x: 100, y: 101), bounds: horizontalIcon, axis: .horizontal), "leaving the Dock perpendicular axis must hide")

        let verticalIcon = CGRect(x: 20, y: 100, width: 80, height: 100)
        expect(!dockTargetCoreContains(CGPoint(x: 60, y: 114.9), bounds: verticalIcon, axis: .vertical), "top 15% must not switch")
        expect(dockTargetCoreContains(CGPoint(x: 60, y: 115), bounds: verticalIcon, axis: .vertical), "vertical middle 70% must switch")
        expect(dockRetentionContains(CGPoint(x: 60, y: 220), bounds: verticalIcon, axis: .vertical), "vertical 20% extension must retain")
        expect(!dockRetentionContains(CGPoint(x: 60, y: 220.1), bounds: verticalIcon, axis: .vertical), "outside vertical extension must hide")
        expect(!dockRetentionContains(CGPoint(x: 101, y: 150), bounds: verticalIcon, axis: .vertical), "leaving a side Dock horizontally must hide")

        var shake = WindowShakeRecognizer()
        shake.begin(at: CGPoint(x: 0, y: 0), timestamp: 0)
        expect(!shake.update(to: CGPoint(x: 60, y: 2), timestamp: 0.12), "first leg must not trigger")
        expect(!shake.update(to: CGPoint(x: 0, y: -2), timestamp: 0.24), "second leg must not trigger")
        expect(!shake.update(to: CGPoint(x: 60, y: 1), timestamp: 0.36), "third leg must not trigger")
        expect(shake.update(to: CGPoint(x: 0, y: 0), timestamp: 0.48), "two back-and-forth cycles must trigger")
        expect(!shake.update(to: CGPoint(x: 60, y: 0), timestamp: 0.60), "one gesture must trigger only once")

        var jitter = WindowShakeRecognizer()
        jitter.begin(at: .zero, timestamp: 0)
        for index in 1...12 {
            let x: CGFloat = index.isMultiple(of: 2) ? 20 : -20
            expect(!jitter.update(to: CGPoint(x: x, y: 0), timestamp: Double(index) * 0.05), "short jitter must not trigger")
        }

        var vertical = WindowShakeRecognizer()
        vertical.begin(at: .zero, timestamp: 0)
        expect(!vertical.update(to: CGPoint(x: 60, y: 71), timestamp: 0.1), "vertical drag must reject")
        expect(!vertical.update(to: CGPoint(x: 0, y: 0), timestamp: 0.2), "rejected gesture must stay rejected")

        var slow = WindowShakeRecognizer()
        slow.begin(at: .zero, timestamp: 0)
        expect(!slow.update(to: CGPoint(x: 60, y: 0), timestamp: 1.01), "slow gesture must reject")

        print("Window interaction geometry tests passed")
    }
}
