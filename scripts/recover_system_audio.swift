import CoreAudio
import Foundation

@main
struct RecoverSystemAudio {
    static func main() throws {
        let outputs = try SystemAudioDevice.physicalOutputDeviceIDs()
        guard let output = try outputs.first(where: SystemAudioDevice.isBuiltInOutput) ?? outputs.first else {
            throw NSError(domain: "SnapClickRecovery", code: 1)
        }
        let inputs = try SystemAudioDevice.inputDeviceIDs()
        guard let input = try inputs.first(where: SystemAudioDevice.isBuiltInInput) ?? inputs.first else {
            throw NSError(domain: "SnapClickRecovery", code: 2)
        }
        try SystemAudioDevice.setDefaultInput(input)
        try SystemAudioDevice.setDefaultOutput(output)
        print("input: \(try SystemAudioDevice.name(for: input))")
        print("output: \(try SystemAudioDevice.name(for: output))")
    }
}
