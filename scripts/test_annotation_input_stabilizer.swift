import CoreGraphics
import Foundation

@main
enum AnnotationInputStabilizerTest {
    static func main() {
        checkFixedDefaults()
        checkPressureCalibrationOrder()
        checkAnalyticPressureCurve()
        checkCausalPressureFilterWarmup()
        checkCoordinateCurveStreaming()
        checkFinishAndCancel()
        print("AnnotationInputStabilizer tests passed")
    }

    private static func sample(_ x: CGFloat, pressure: CGFloat, time: TimeInterval = 0) -> AnnotationInputSample {
        AnnotationInputSample(point: CGPoint(x: x, y: 0), pressure: pressure, timestamp: time)
    }

    private static func checkFixedDefaults() {
        let configuration = AnnotationStabilizerConfiguration(
            maximumPressure: 1,
            deadZone: 0.06
        )
        expect(configuration.coordinateWindow == 10, "coordinate window must use the documented value 10")
        expect(configuration.pressureWindow == 5, "pressure window must use the documented value 5")
        expect(close(configuration.deadZone, 0.06), "default dead zone must remain 6 percent")
        expect(configuration.pressureCurve == .standard, "default pressure response must use the standard analytic curve")
    }

    private static func checkPressureCalibrationOrder() {
        var stabilizer = AnnotationInputStabilizer()
        let configuration = AnnotationStabilizerConfiguration(
            coordinateWindow: 1,
            pressureWindow: 1,
            maximumPressure: 0.5,
            deadZone: 0.1,
            pressureCurve: .identity
        )
        let first = stabilizer.begin(sample(0, pressure: 0.1), configuration: configuration)
        expect(first.count == 1 && first[0].pressure == 0, "dead-zone input must map to zero")
        let middle = stabilizer.append(sample(1, pressure: 0.3))
        expect(middle.count == 1 && close(middle[0].pressure, 0.5), "maximum pressure must run before dead-zone remapping")
        let maximum = stabilizer.append(sample(2, pressure: 0.5))
        expect(maximum.count == 1 && maximum[0].pressure == 1, "amplified maximum must map to one")
        let aboveMaximum = stabilizer.append(sample(3, pressure: 1))
        expect(aboveMaximum.count == 1 && aboveMaximum[0].pressure == 1, "input above maximum must stay clamped to one")

        stabilizer.cancel()
        let clampedDeadZone = AnnotationStabilizerConfiguration(
            coordinateWindow: 1,
            pressureWindow: 1,
            maximumPressure: 0.05,
            deadZone: 0.3,
            pressureCurve: .identity
        )
        let belowClampedDeadZone = stabilizer.begin(
            sample(0, pressure: 0.049),
            configuration: clampedDeadZone
        )
        expect(belowClampedDeadZone[0].pressure == 0, "dead zone must clamp below maximum pressure")
        let clampedMaximum = stabilizer.append(sample(1, pressure: 0.05))
        expect(clampedMaximum[0].pressure == 1, "maximum must remain reachable after dead-zone clamping")
    }

    private static func checkAnalyticPressureCurve() {
        var stabilizer = AnnotationInputStabilizer()
        let configuration = AnnotationStabilizerConfiguration(
            coordinateWindow: 1,
            pressureWindow: 1,
            maximumPressure: 1,
            deadZone: 0,
            pressureCurve: .standard
        )
        let expected: [(CGFloat, CGFloat)] = [
            (0, 0),
            (0.1, 0.03114),
            (0.25, 0.08490),
            (0.5, 0.22142),
            (0.75, 0.48512),
            (0.9, 0.76827),
            (1, 1)
        ]
        var previous: CGFloat = -1
        for (index, pair) in expected.enumerated() {
            let output = index == 0
                ? stabilizer.begin(sample(CGFloat(index), pressure: pair.0), configuration: configuration)
                : stabilizer.append(sample(CGFloat(index), pressure: pair.0))
            expect(abs(output[0].pressure - pair.1) < 0.0002, "analytic pressure response must stay inside its numeric contract")
            expect(output[0].pressure >= previous, "analytic pressure response must stay monotonic")
            previous = output[0].pressure
        }
    }

    private static func checkCausalPressureFilterWarmup() {
        var stabilizer = AnnotationInputStabilizer()
        let configuration = AnnotationStabilizerConfiguration(
            coordinateWindow: 1,
            pressureWindow: 5,
            maximumPressure: 1,
            deadZone: 0,
            pressureCurve: .identity
        )
        let first = stabilizer.begin(sample(0, pressure: 0.25), configuration: configuration)
        expect(first.count == 1 && close(first[0].pressure, 0.25), "first pressure sample must emit immediately")
        let second = stabilizer.append(sample(1, pressure: 0.75))
        expect(second.count == 1 && close(second[0].pressure, 0.5), "Filter16 warmup must average only available raw samples")
    }

    private static func checkCoordinateCurveStreaming() {
        var stabilizer = AnnotationInputStabilizer()
        let configuration = AnnotationStabilizerConfiguration(
            coordinateWindow: 10,
            pressureWindow: 1,
            maximumPressure: 1,
            deadZone: 0,
            pressureCurve: .identity
        )
        let first = stabilizer.begin(sample(0, pressure: 1), configuration: configuration)
        expect(first.count == 1 && first[0].point.x == 0, "stroke start must emit immediately")
        expect(stabilizer.append(sample(4, pressure: 1)).count == 0, "curve warmup must not duplicate the start point")
        let curve = stabilizer.append(sample(8, pressure: 1))
        expect(curve.count == 4, "each ready curve segment must emit four samples")
        expect(curve[3].point.x == 2, "coordinate Filter16 must retain raw-history averaging")
    }

    private static func checkFinishAndCancel() {
        var stabilizer = AnnotationInputStabilizer()
        let configuration = AnnotationStabilizerConfiguration(maximumPressure: 1, deadZone: 0.06)
        _ = stabilizer.begin(sample(0, pressure: 0.2, time: 0), configuration: configuration)
        _ = stabilizer.append(sample(4, pressure: 0.4, time: 1))
        _ = stabilizer.append(sample(8, pressure: 0.8, time: 2))
        let tail = stabilizer.finish(at: sample(12, pressure: 1, time: 3))
        expect(tail.count > 0 && tail.count <= 8, "finish must flush the final curve samples")
        expect(stabilizer.finish(at: nil).count == 0, "finish must be idempotent")

        _ = stabilizer.begin(sample(0, pressure: 1), configuration: configuration)
        stabilizer.cancel()
        expect(stabilizer.append(sample(1, pressure: 1)).count == 0, "cancel must isolate stroke history")
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
