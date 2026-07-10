import CoreGraphics
import Foundation

struct AnnotationInputSample {
    let point: CGPoint
    let pressure: CGFloat
}

struct AnnotationInputStabilizer {
    private static let pressureCapacity = 4
    private static let minimumPositionWeight: CGFloat = 0.28
    private static let fullSpeed: CGFloat = 1_400

    private var pressureSamples = [CGFloat](repeating: 0, count: pressureCapacity)
    private var pressureCount = 0
    private var pressureIndex = 0
    private var lastRawPoint: CGPoint?
    private var lastFilteredPoint: CGPoint?
    private var lastTimestamp: TimeInterval?

    mutating func reset() {
        pressureCount = 0
        pressureIndex = 0
        lastRawPoint = nil
        lastFilteredPoint = nil
        lastTimestamp = nil
    }

    mutating func filter(
        point: CGPoint,
        pressure: CGFloat,
        timestamp: TimeInterval
    ) -> AnnotationInputSample {
        let filteredPressure = appendPressure(pressure)
        guard let lastRawPoint, let lastFilteredPoint, let lastTimestamp else {
            self.lastRawPoint = point
            self.lastFilteredPoint = point
            self.lastTimestamp = timestamp
            return AnnotationInputSample(point: point, pressure: filteredPressure)
        }

        let distance = hypot(point.x - lastRawPoint.x, point.y - lastRawPoint.y)
        let elapsed = max(timestamp - lastTimestamp, 1.0 / 240.0)
        let speed = distance / elapsed
        let weight = min(
            1,
            Self.minimumPositionWeight
                + (1 - Self.minimumPositionWeight) * speed / Self.fullSpeed
        )
        let filteredPoint = CGPoint(
            x: lastFilteredPoint.x + (point.x - lastFilteredPoint.x) * weight,
            y: lastFilteredPoint.y + (point.y - lastFilteredPoint.y) * weight
        )

        self.lastRawPoint = point
        self.lastFilteredPoint = filteredPoint
        self.lastTimestamp = timestamp
        return AnnotationInputSample(point: filteredPoint, pressure: filteredPressure)
    }

    private mutating func appendPressure(_ pressure: CGFloat) -> CGFloat {
        pressureSamples[pressureIndex] = min(max(pressure, 0), 1)
        pressureIndex = (pressureIndex + 1) % Self.pressureCapacity
        pressureCount = min(pressureCount + 1, Self.pressureCapacity)

        var total: CGFloat = 0
        for index in 0..<pressureCount {
            total += pressureSamples[index]
        }
        return total / CGFloat(pressureCount)
    }
}
