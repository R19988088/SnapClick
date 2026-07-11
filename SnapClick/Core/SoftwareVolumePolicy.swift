import CoreAudio

func clampVolume(_ value: Float) -> Float {
    min(1, max(0, value))
}

func selectPhysicalOutput(
    saved: AudioDeviceID?,
    currentDefault: AudioDeviceID?,
    available: [AudioDeviceID],
    virtual: AudioDeviceID?
) -> AudioDeviceID? {
    let physical = available.filter { $0 != virtual }
    if let saved, physical.contains(saved) {
        return saved
    }
    if let currentDefault, physical.contains(currentDefault) {
        return currentDefault
    }
    return physical.first
}

func restoredOutput(
    saved: AudioDeviceID?,
    available: [AudioDeviceID],
    virtual: AudioDeviceID?
) -> AudioDeviceID? {
    let physical = available.filter { $0 != virtual }
    if let saved, physical.contains(saved) {
        return saved
    }
    return physical.first
}
