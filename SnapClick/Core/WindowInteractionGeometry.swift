import CoreGraphics
import Foundation

enum DockLayoutAxis {
    case horizontal
    case vertical
}

func dockTargetCoreContains(_ point: CGPoint, bounds: CGRect, axis: DockLayoutAxis) -> Bool {
    let insetFraction: CGFloat = 0.15
    switch axis {
    case .horizontal:
        return point.x >= bounds.minX + bounds.width * insetFraction
            && point.x <= bounds.maxX - bounds.width * insetFraction
    case .vertical:
        return point.y >= bounds.minY + bounds.height * insetFraction
            && point.y <= bounds.maxY - bounds.height * insetFraction
    }
}

func dockRetentionContains(_ point: CGPoint, bounds: CGRect, axis: DockLayoutAxis) -> Bool {
    let extensionFraction: CGFloat = 0.20
    switch axis {
    case .horizontal:
        return point.x >= bounds.minX - bounds.width * extensionFraction
            && point.x <= bounds.maxX + bounds.width * extensionFraction
            && point.y >= bounds.minY
            && point.y <= bounds.maxY
    case .vertical:
        return point.y >= bounds.minY - bounds.height * extensionFraction
            && point.y <= bounds.maxY + bounds.height * extensionFraction
            && point.x >= bounds.minX
            && point.x <= bounds.maxX
    }
}

struct WindowShakeRecognizer {
    private static let minimumLegDistance: CGFloat = 50
    private static let maximumDuration: TimeInterval = 1.0
    private static let maximumVerticalDrift: CGFloat = 70
    private static let requiredLegCount = 4

    private var startPoint = CGPoint.zero
    private var turningPoint = CGPoint.zero
    private var startedAt: TimeInterval = 0
    private var direction = 0
    private var legCount = 0
    private var isActive = false
    private var didTrigger = false

    mutating func begin(at point: CGPoint, timestamp: TimeInterval) {
        startPoint = point
        turningPoint = point
        startedAt = timestamp
        direction = 0
        legCount = 0
        isActive = true
        didTrigger = false
    }

    mutating func update(to point: CGPoint, timestamp: TimeInterval) -> Bool {
        guard isActive, !didTrigger else { return false }
        guard timestamp - startedAt <= Self.maximumDuration,
              abs(point.y - startPoint.y) <= Self.maximumVerticalDrift else {
            isActive = false
            return false
        }

        let delta = point.x - turningPoint.x
        if direction == 0 {
            guard abs(delta) >= Self.minimumLegDistance else { return false }
            direction = delta > 0 ? 1 : -1
            turningPoint = point
            legCount = 1
            return false
        }

        if CGFloat(direction) * delta > 0 {
            turningPoint = point
            return false
        }

        guard abs(delta) >= Self.minimumLegDistance else { return false }
        direction *= -1
        turningPoint = point
        legCount += 1
        if legCount >= Self.requiredLegCount {
            didTrigger = true
            return true
        }
        return false
    }
}
