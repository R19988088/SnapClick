import CoreAudio
import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

@main
private enum SoftwareVolumePolicyTests {
    static func main() {
        expect(clampVolume(-0.2) == 0, "negative volume clamps to zero")
        expect(clampVolume(0.4) == 0.4, "in-range volume is unchanged")
        expect(clampVolume(1.2) == 1, "volume above one clamps to one")

        let virtual = AudioDeviceID(99)
        expect(
            selectPhysicalOutput(
                saved: AudioDeviceID(7),
                currentDefault: virtual,
                available: [virtual, AudioDeviceID(8)],
                virtual: virtual
            ) == AudioDeviceID(8),
            "virtual output is never its own destination"
        )
        expect(
            selectPhysicalOutput(
                saved: AudioDeviceID(7),
                currentDefault: AudioDeviceID(8),
                available: [AudioDeviceID(7), AudioDeviceID(8)],
                virtual: virtual
            ) == AudioDeviceID(7),
            "saved output is preferred while active"
        )
        expect(
            restoredOutput(
                saved: AudioDeviceID(7),
                available: [AudioDeviceID(7), AudioDeviceID(8)],
                virtual: virtual
            ) == AudioDeviceID(7),
            "saved physical output is restored"
        )
        expect(
            restoredOutput(
                saved: virtual,
                available: [virtual, AudioDeviceID(8)],
                virtual: virtual
            ) == AudioDeviceID(8),
            "virtual output is never restored"
        )

        print("software volume policy tests passed")
    }
}
