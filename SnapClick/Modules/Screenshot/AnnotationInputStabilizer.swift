import CoreGraphics
import Foundation

struct AnnotationInputSample {
    var point: CGPoint
    var pressure: CGFloat
    var timestamp: TimeInterval

    func withPressure(_ pressure: CGFloat) -> AnnotationInputSample {
        AnnotationInputSample(point: point, pressure: pressure, timestamp: timestamp)
    }
}

enum AnnotationPressureCurve: Equatable {
    case identity
    case standard

    func map(_ value: UInt16) -> UInt16 {
        guard self == .standard, value > 0, value < 65535 else { return value }
        let x = Double(value) / 65535
        let rise = pow(x, 0.92)
        let fall = 4.24 * pow(1 - x, 1.19)
        return UInt16((rise / (rise + fall) * 65535).rounded())
    }
}

struct AnnotationStabilizerConfiguration: Equatable {
    var coordinateWindow: Int
    var pressureWindow: Int
    var maximumPressure: CGFloat
    var deadZone: CGFloat
    var pressureCurve: AnnotationPressureCurve

    init(
        coordinateWindow: Int = 10,
        pressureWindow: Int = 5,
        maximumPressure: CGFloat,
        deadZone: CGFloat,
        pressureCurve: AnnotationPressureCurve = .standard
    ) {
        self.coordinateWindow = coordinateWindow
        self.pressureWindow = pressureWindow
        self.maximumPressure = maximumPressure
        self.deadZone = deadZone
        self.pressureCurve = pressureCurve
    }

    var clamped: AnnotationStabilizerConfiguration {
        var value = self
        value.coordinateWindow = max(1, min(coordinateWindow, 16))
        value.pressureWindow = max(1, min(pressureWindow, 16))
        value.maximumPressure = max(0.001, min(maximumPressure, 1))
        value.deadZone = max(0, min(deadZone, max(0, value.maximumPressure - 1 / 65535)))
        return value
    }
}

struct AnnotationInputSamples {
    private var storage: (
        AnnotationInputSample?, AnnotationInputSample?, AnnotationInputSample?, AnnotationInputSample?,
        AnnotationInputSample?, AnnotationInputSample?, AnnotationInputSample?, AnnotationInputSample?
    ) = (nil, nil, nil, nil, nil, nil, nil, nil)
    private(set) var count = 0

    subscript(index: Int) -> AnnotationInputSample {
        precondition(index >= 0 && index < count)
        switch index {
        case 0: return storage.0!
        case 1: return storage.1!
        case 2: return storage.2!
        case 3: return storage.3!
        case 4: return storage.4!
        case 5: return storage.5!
        case 6: return storage.6!
        default: return storage.7!
        }
    }

    mutating func append(_ sample: AnnotationInputSample) {
        precondition(count < 8)
        switch count {
        case 0: storage.0 = sample
        case 1: storage.1 = sample
        case 2: storage.2 = sample
        case 3: storage.3 = sample
        case 4: storage.4 = sample
        case 5: storage.5 = sample
        case 6: storage.6 = sample
        default: storage.7 = sample
        }
        count += 1
    }

    mutating func append(contentsOf other: AnnotationInputSamples) {
        for index in 0..<other.count { append(other[index]) }
    }
}

private struct AnnotationFilter16 {
    private var history = Array(repeating: 0, count: 16)
    private var index = 0
    private var count = 0

    mutating func clear() {
        index = 0
        count = 0
    }

    mutating func apply(_ input: Int, window: Int) -> Int {
        var sum = input
        var used = 1
        let previousCount = min(max(1, min(window, 16)) - 1, count)
        for offset in 0..<previousCount {
            sum += history[(index - offset - 1 + 16) & 15]
            used += 1
        }
        let output = (sum + used - 1) / used
        history[index] = input
        index = (index + 1) & 15
        count = min(count + 1, 16)
        return output
    }
}

private struct AnnotationCurveNode {
    var x: Int
    var y: Int
    var pressure: Int
    var sample: AnnotationInputSample
}

private struct AnnotationCurvePoint {
    var x: Int
    var y: Int
}

private struct AnnotationCurveState {
    private var a: AnnotationCurveNode
    private var b: AnnotationCurveNode
    private var c: AnnotationCurveNode
    private var outgoingControl: AnnotationCurvePoint

    init(first: AnnotationCurveNode) {
        a = first
        b = first
        c = first
        outgoingControl = AnnotationCurvePoint(x: first.x, y: first.y)
    }

    mutating func append(_ next: AnnotationCurveNode) -> AnnotationInputSamples {
        let firstControl = outgoingControl
        a = b
        b = c
        c = next
        let handles = Self.handles(previous: a, center: b, next: c)
        outgoingControl = handles.outgoing
        var result = AnnotationInputSamples()
        for step in 1...4 {
            let x = Self.cubic(a.x, firstControl.x, handles.incoming.x, b.x, step: step)
            let y = Self.cubic(a.y, firstControl.y, handles.incoming.y, b.y, step: step)
            let pressure = a.pressure + (b.pressure - a.pressure) * step / 4
            let t = Double(step) * 0.25
            result.append(AnnotationInputSample(
                point: CGPoint(x: CGFloat(x) / 256, y: CGFloat(y) / 256),
                pressure: CGFloat(pressure) / 65535,
                timestamp: a.sample.timestamp + (b.sample.timestamp - a.sample.timestamp) * t
            ))
        }
        return result
    }

    private static func cubic(_ p0: Int, _ p1: Int, _ p2: Int, _ p3: Int, step: Int) -> Int {
        let t = Double(step) * 0.25
        let inverse = 1 - t
        return Int(
            Double(p0) * inverse * inverse * inverse
                + 3 * Double(p1) * t * inverse * inverse
                + 3 * Double(p2) * t * t * inverse
                + Double(p3) * t * t * t
        )
    }

    private static func handles(
        previous: AnnotationCurveNode,
        center: AnnotationCurveNode,
        next: AnnotationCurveNode
    ) -> (incoming: AnnotationCurvePoint, outgoing: AnnotationCurvePoint) {
        let previousLength = hypot(Double(previous.x - center.x), Double(previous.y - center.y))
        let nextLength = hypot(Double(next.x - center.x), Double(next.y - center.y))
        let centerPoint = AnnotationCurvePoint(x: center.x, y: center.y)
        guard previousLength > 0, nextLength > 0 else { return (centerPoint, centerPoint) }

        let tangentX: Double
        let tangentY: Double
        let incomingScale: Double
        let outgoingScale: Double
        if previousLength <= nextLength {
            let matchedX = Double(center.x) + Double(next.x - center.x) * previousLength / nextLength
            let matchedY = Double(center.y) + Double(next.y - center.y) * previousLength / nextLength
            tangentX = matchedX - Double(previous.x)
            tangentY = matchedY - Double(previous.y)
            incomingScale = 0.2
            outgoingScale = 0.2 * nextLength / previousLength
        } else {
            let matchedX = Double(center.x) + Double(previous.x - center.x) * nextLength / previousLength
            let matchedY = Double(center.y) + Double(previous.y - center.y) * nextLength / previousLength
            tangentX = Double(next.x) - matchedX
            tangentY = Double(next.y) - matchedY
            incomingScale = 0.2 * previousLength / nextLength
            outgoingScale = 0.2
        }
        return (
            AnnotationCurvePoint(
                x: Int(Double(center.x) - tangentX * incomingScale),
                y: Int(Double(center.y) - tangentY * incomingScale)
            ),
            AnnotationCurvePoint(
                x: Int(Double(center.x) + tangentX * outgoingScale),
                y: Int(Double(center.y) + tangentY * outgoingScale)
            )
        )
    }
}

struct AnnotationInputStabilizer {
    private var configuration: AnnotationStabilizerConfiguration?
    private var xFilter = AnnotationFilter16()
    private var yFilter = AnnotationFilter16()
    private var pressureFilter = AnnotationFilter16()
    private var curveState: AnnotationCurveState?
    private var lastRawSample: AnnotationInputSample?
    private var lastEmittedNode: AnnotationCurveNode?

    mutating func begin(
        _ sample: AnnotationInputSample,
        configuration: AnnotationStabilizerConfiguration
    ) -> AnnotationInputSamples {
        cancel()
        self.configuration = configuration.clamped
        lastRawSample = sample
        let node = filteredNode(sample)
        lastEmittedNode = node
        if self.configuration!.coordinateWindow > 1 {
            curveState = AnnotationCurveState(first: node)
        }
        var result = AnnotationInputSamples()
        result.append(node.sample)
        return result
    }

    mutating func append(_ sample: AnnotationInputSample) -> AnnotationInputSamples {
        guard let configuration else { return AnnotationInputSamples() }
        lastRawSample = sample
        let node = filteredNode(sample)
        guard configuration.coordinateWindow > 1 else {
            lastEmittedNode = node
            var result = AnnotationInputSamples()
            result.append(node.sample)
            return result
        }
        guard var curveState else { return AnnotationInputSamples() }
        let candidates = curveState.append(node)
        self.curveState = curveState
        var result = AnnotationInputSamples()
        for index in 0..<candidates.count {
            let candidate = candidates[index]
            let candidateNode = AnnotationCurveNode(
                x: Int((candidate.point.x * 256).rounded()),
                y: Int((candidate.point.y * 256).rounded()),
                pressure: Int((candidate.pressure * 65535).rounded()),
                sample: candidate
            )
            if let lastEmittedNode,
               candidateNode.x == lastEmittedNode.x,
               candidateNode.y == lastEmittedNode.y,
               candidateNode.pressure == lastEmittedNode.pressure {
                continue
            }
            result.append(candidate)
            lastEmittedNode = candidateNode
        }
        return result
    }

    mutating func finish(at sample: AnnotationInputSample?) -> AnnotationInputSamples {
        guard configuration != nil else { return AnnotationInputSamples() }
        var result = AnnotationInputSamples()
        if let sample, !isSameRawSample(sample, lastRawSample) {
            result.append(contentsOf: append(sample))
        }
        if let lastRawSample, configuration!.coordinateWindow > 1, result.count <= 4 {
            result.append(contentsOf: append(lastRawSample.withPressure(0)))
        }
        cancel()
        return result
    }

    mutating func cancel() {
        configuration = nil
        xFilter.clear()
        yFilter.clear()
        pressureFilter.clear()
        curveState = nil
        lastRawSample = nil
        lastEmittedNode = nil
    }

    private mutating func filteredNode(_ sample: AnnotationInputSample) -> AnnotationCurveNode {
        let configuration = configuration!
        let maximum16 = max(1, Int((configuration.maximumPressure * 65535).rounded()))
        let deadZone16 = min(maximum16 - 1, Int((configuration.deadZone * 65535).rounded()))
        let raw16 = min(maximum16, max(0, Int((sample.pressure * 65535).rounded())))
        let mapped16 = raw16 <= deadZone16
            ? 0
            : min(65535, (raw16 - deadZone16) * 65535 / max(1, maximum16 - deadZone16))
        let curved16 = Int(configuration.pressureCurve.map(UInt16(mapped16)))
        let pressure16 = pressureFilter.apply(curved16, window: configuration.pressureWindow)
        let x = xFilter.apply(Int((sample.point.x * 256).rounded()), window: configuration.coordinateWindow)
        let y = yFilter.apply(Int((sample.point.y * 256).rounded()), window: configuration.coordinateWindow)
        var filtered = sample
        filtered.point = CGPoint(x: CGFloat(x) / 256, y: CGFloat(y) / 256)
        filtered.pressure = CGFloat(pressure16) / 65535
        return AnnotationCurveNode(x: x, y: y, pressure: pressure16, sample: filtered)
    }

    private func isSameRawSample(_ lhs: AnnotationInputSample, _ rhs: AnnotationInputSample?) -> Bool {
        guard let rhs else { return false }
        return lhs.point == rhs.point
            && lhs.pressure == rhs.pressure
            && lhs.timestamp == rhs.timestamp
    }
}
