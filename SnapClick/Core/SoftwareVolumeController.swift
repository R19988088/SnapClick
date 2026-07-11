import AppKit
import AudioToolbox
import CoreAudio

@MainActor
final class SoftwareVolumeController: ObservableObject {
    enum State: Equatable {
        case notInstalled
        case installing
        case uninstalling
        case disabled
        case starting
        case active
        case recovering
        case failed(String)
    }

    static let shared = SoftwareVolumeController()

    @Published private(set) var state: State = .disabled
    @Published private(set) var outputName = ""
    @Published private(set) var gain: Float32
    @Published private(set) var usesSoftwareGain = false

    var isSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    var isDriverInstalled: Bool {
        FileManager.default.fileExists(atPath: Self.installedDriverURL.path)
    }

    var isActive: Bool { state == .active }

    var errorMessage: String? {
        guard case let .failed(message) = state else { return nil }
        return message
    }

    private var forwarder: NativeAudioTapForwarder?
    private var defaultOutputListener: AudioPropertyListenerToken?
    private var volumeListener: AudioPropertyListenerToken?
    private var muteListener: AudioPropertyListenerToken?
    private var savedPhysicalOutput: AudioDeviceID?
    private var isChangingDefaultOutput = false
    private var isSyncingControl = false
    private let defaults = UserDefaults.standard
    private let gainKey = "softwareVolumeGain"
    private let enabledKey = "softwareVolumeEnabled"
    private let physicalUIDKey = "softwareVolumePhysicalOutputUID"
    private var lastNonzeroGain: Float32
    private static let installedDriverURL = URL(
        fileURLWithPath: "/Library/Audio/Plug-Ins/HAL/SnapClickAudio.driver",
        isDirectory: true
    )

    private init() {
        let savedGain = UserDefaults.standard.object(forKey: "softwareVolumeGain") as? NSNumber
        let initialGain = min(max(savedGain?.floatValue ?? 1, 0), 1)
        gain = initialGain
        lastNonzeroGain = initialGain > 0 ? initialGain : 1
    }

    func prepareForLaunch() {
        recoverStrandedControlOutput()
        guard defaults.bool(forKey: enabledKey), isSupported, isDriverInstalled else {
            state = isDriverInstalled ? .disabled : .notInstalled
            return
        }
        Task { install() }
    }

    func installAndEnable() {
        install()
    }

    func install() {
        guard state != .installing, state != .starting, state != .active else { return }
        guard #available(macOS 14.2, *) else {
            state = .failed("Software volume requires macOS 14.2 or later")
            return
        }
        do {
            if !isDriverInstalled {
                state = .installing
                try Self.installDriver()
            }
            state = .starting
            try start()
            defaults.set(true, forKey: enabledKey)
            state = .active
            print("软件音量已启用: \(outputName)")
        } catch {
            restoreAndStop()
            state = .failed(error.localizedDescription)
            print("软件音量启用失败: \(error.localizedDescription)")
        }
    }

    func uninstall() {
        guard state != .installing, state != .uninstalling else { return }
        state = .uninstalling
        restoreAndStop()
        do {
            try Self.uninstallDriver()
            defaults.set(false, forKey: enabledKey)
            state = .notInstalled
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func disable() {
        restoreAndStop()
        defaults.set(false, forKey: enabledKey)
        state = .disabled
    }

    func restoreAndStop() {
        defaultOutputListener = nil
        volumeListener = nil
        muteListener = nil
        restorePhysicalOutput()
        forwarder?.stop()
        forwarder = nil
        outputName = ""
        usesSoftwareGain = false
    }

    func setGain(_ gain: Float32) {
        let clamped = min(max(gain, 0), 1)
        self.gain = clamped
        if clamped > 0 { lastNonzeroGain = clamped }
        defaults.set(clamped, forKey: gainKey)
        forwarder?.setGain(clamped)
        if !isSyncingControl,
           let control = try? SystemAudioDevice.controlOutputID() {
            isSyncingControl = true
            try? SystemAudioDevice.setOutputVolume(clamped, for: control)
            try? SystemAudioDevice.setOutputMuted(clamped == 0, for: control)
            isSyncingControl = false
        }
    }

    func handleMediaKey(_ keyType: Int32) -> Bool {
        guard state == .active, usesSoftwareGain else { return false }
        if let control = try? SystemAudioDevice.controlOutputID(),
           (try? SystemAudioDevice.defaultOutputID()) == control {
            return false
        }
        switch keyType {
        case NX_KEYTYPE_SOUND_UP:
            setGain(gain + 1.0 / 16.0)
        case NX_KEYTYPE_SOUND_DOWN:
            setGain(gain - 1.0 / 16.0)
        case NX_KEYTYPE_MUTE:
            setGain(gain > 0 ? 0 : lastNonzeroGain)
        default:
            return false
        }
        return true
    }

    @available(macOS 14.2, *)
    private func start() throws {
        guard let control = try waitForControlOutput() else {
            throw SoftwareVolumeError.controlDeviceUnavailable
        }
        let current = try SystemAudioDevice.defaultOutputID()
        let physical: AudioDeviceID
        if current == control {
            guard let restored = try savedPhysicalDevice() else {
                throw SoftwareVolumeError.noPhysicalOutput
            }
            physical = restored
        } else {
            physical = current
        }
        savedPhysicalOutput = physical
        defaults.set(try SystemAudioDevice.uid(for: physical), forKey: physicalUIDKey)
        usesSoftwareGain = true
        let forwarder = NativeAudioTapForwarder()
        try forwarder.start(physicalDevice: physical)
        forwarder.setGain(gain)
        self.forwarder = forwarder
        outputName = (try? SystemAudioDevice.name(for: physical)) ?? ""
        installListeners(control: control)
        isChangingDefaultOutput = true
        try SystemAudioDevice.setDefaultOutput(control)
        isChangingDefaultOutput = false
    }

    private func installListeners(control: AudioDeviceID) {
        defaultOutputListener = try? SystemAudioDevice.addDefaultOutputListener { [weak self] in
            self?.restartForCurrentOutput()
        }
        volumeListener = try? SystemAudioDevice.addOutputControlListener(
            deviceID: control,
            selector: kAudioDevicePropertyVolumeScalar
        ) { [weak self] in self?.syncFromControl(control) }
        muteListener = try? SystemAudioDevice.addOutputControlListener(
            deviceID: control,
            selector: kAudioDevicePropertyMute
        ) { [weak self] in self?.syncFromControl(control) }
        try? SystemAudioDevice.setOutputVolume(gain, for: control)
        try? SystemAudioDevice.setOutputMuted(gain == 0, for: control)
    }

    private func restartForCurrentOutput() {
        guard state == .active, !isChangingDefaultOutput else { return }
        guard #available(macOS 14.2, *) else { return }
        do {
            let physical = try SystemAudioDevice.defaultOutputID()
            guard physical != (try SystemAudioDevice.controlOutputID()) else { return }
            try deactivateForSelectedOutput(physical)
        } catch {
            isChangingDefaultOutput = false
            restoreAndStop()
            state = .failed(error.localizedDescription)
        }
    }

    private func deactivateForSelectedOutput(_ physical: AudioDeviceID) throws {
        defaultOutputListener = nil
        volumeListener = nil
        muteListener = nil
        forwarder?.stop()
        forwarder = nil
        savedPhysicalOutput = physical
        defaults.set(try SystemAudioDevice.uid(for: physical), forKey: physicalUIDKey)
        defaults.set(false, forKey: enabledKey)
        outputName = (try? SystemAudioDevice.name(for: physical)) ?? ""
        usesSoftwareGain = false
        state = .disabled
    }

    private func syncFromControl(_ control: AudioDeviceID) {
        guard !isSyncingControl else { return }
        let volume = (try? SystemAudioDevice.outputVolume(for: control)) ?? gain
        let muted = (try? SystemAudioDevice.outputMuted(for: control)) ?? false
        isSyncingControl = true
        setGain(muted ? 0 : volume)
        isSyncingControl = false
    }

    private func restorePhysicalOutput() {
        guard let physical = savedPhysicalOutput ?? (try? savedPhysicalDevice()) else { return }
        if (try? SystemAudioDevice.defaultOutputID()) != physical {
            isChangingDefaultOutput = true
            try? SystemAudioDevice.setDefaultOutput(physical)
            isChangingDefaultOutput = false
        }
        savedPhysicalOutput = nil
    }

    private func savedPhysicalDevice() throws -> AudioDeviceID? {
        if let uid = defaults.string(forKey: physicalUIDKey),
           let device = try SystemAudioDevice.deviceID(uid: uid) {
            return device
        }
        return try SystemAudioDevice.physicalOutputDeviceIDs().first
    }

    private func recoverStrandedControlOutput() {
        guard let control = try? SystemAudioDevice.controlOutputID(),
              (try? SystemAudioDevice.defaultOutputID()) == control,
              let physical = try? savedPhysicalDevice() else { return }
        try? SystemAudioDevice.setDefaultOutput(physical)
    }

    private func waitForControlOutput() throws -> AudioDeviceID? {
        for _ in 0..<40 {
            if let device = try SystemAudioDevice.controlOutputID() { return device }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    private static func installDriver() throws {
        guard let source = Bundle.main.resourceURL?.appendingPathComponent("SnapClickAudio.driver", isDirectory: true),
              FileManager.default.fileExists(atPath: source.path) else {
            throw SoftwareVolumeError.embeddedDriverMissing
        }
        try verifyDriver(at: source)
        let staging = installedDriverURL.deletingLastPathComponent()
            .appendingPathComponent(".SnapClickAudio.driver.installing")
        try runPrivileged([
            "/bin/rm -rf \(shellQuote(staging.path))",
            "/usr/bin/ditto \(shellQuote(source.path)) \(shellQuote(staging.path))",
            "/usr/sbin/chown -R root:wheel \(shellQuote(staging.path))",
            "/bin/chmod -R u=rwX,go=rX \(shellQuote(staging.path))",
            "/bin/rm -rf \(shellQuote(installedDriverURL.path))",
            "/bin/mv \(shellQuote(staging.path)) \(shellQuote(installedDriverURL.path))",
            "/usr/bin/killall coreaudiod || true",
        ], operation: "installation")
    }

    private static func uninstallDriver() throws {
        try runPrivileged([
            "/bin/rm -rf \(shellQuote(installedDriverURL.path))",
            "/usr/bin/killall coreaudiod || true",
        ], operation: "uninstallation")
    }

    private static func verifyDriver(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", url.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw SoftwareVolumeError.invalidDriverSignature }
        guard Bundle(url: url)?.bundleIdentifier == "com.snapclick.audio.driver" else {
            throw SoftwareVolumeError.invalidDriverIdentifier
        }
    }

    private static func runPrivileged(_ commands: [String], operation: String) throws {
        let command = commands.joined(separator: " && ")
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        var errorInfo: NSDictionary?
        let result = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?
            .executeAndReturnError(&errorInfo)
        guard result != nil, errorInfo == nil else {
            throw SoftwareVolumeError.driverOperationFailed(operation, errorInfo?.description ?? "Unknown error")
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

private enum SoftwareVolumeError: Error, LocalizedError {
    case embeddedDriverMissing
    case invalidDriverSignature
    case invalidDriverIdentifier
    case driverOperationFailed(String, String)
    case controlDeviceUnavailable
    case noPhysicalOutput
    case coreAudio(String, OSStatus)
    case ownProcessUnavailable
    case aggregateFormatUnavailable

    var errorDescription: String? {
        switch self {
        case .embeddedDriverMissing: return "The bundled SnapClick audio driver is missing"
        case .invalidDriverSignature: return "The bundled SnapClick audio driver signature is invalid"
        case .invalidDriverIdentifier: return "The bundled SnapClick audio driver identifier is invalid"
        case let .driverOperationFailed(operation, message): return "Audio driver \(operation) failed: \(message)"
        case .controlDeviceUnavailable: return "SnapClick Control Output did not become available"
        case .noPhysicalOutput: return "No physical audio output is available"
        case let .coreAudio(operation, status):
            return "\(operation) failed with CoreAudio status \(status)"
        case .ownProcessUnavailable:
            return "SnapClick could not exclude its own audio from the system tap"
        case .aggregateFormatUnavailable:
            return "The system audio tap did not provide a playback format"
        }
    }
}

private final class NativeAudioTapForwarder {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var captureIOProcID: AudioDeviceIOProcID?
    private var outputUnit: AudioUnit?
    private let captureQueue = DispatchQueue(
        label: "com.snapclick.audio.tap",
        qos: .userInteractive
    )
    private let ring: OpaquePointer
    private static let maximumFramesPerSlice: UInt32 = 4096

    init() {
        guard let ring = SCAudioRingBufferCreate(1 << 20) else {
            fatalError("Unable to allocate audio ring buffer")
        }
        self.ring = ring
    }

    deinit {
        stop()
        SCAudioRingBufferDestroy(ring)
    }

    @available(macOS 14.2, *)
    func start(physicalDevice: AudioDeviceID) throws {
        stop()
        SCAudioRingBufferReset(ring)
        guard let processID = try Self.audioProcessObjectID(pid: getpid()) else {
            throw SoftwareVolumeError.ownProcessUnavailable
        }

        let description = CATapDescription(
            stereoGlobalTapButExcludeProcesses: [processID]
        )
        description.name = "SnapClick Software Volume"
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = CATapMuteBehavior(rawValue: 2)!

        try Self.check(
            AudioHardwareCreateProcessTap(description, &tapID),
            "create system audio tap"
        )

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SnapClick Audio Tap",
            kAudioAggregateDeviceUIDKey: "com.snapclick.audio.tap.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString
            ]]
        ]
        do {
            try Self.check(
                AudioHardwareCreateAggregateDevice(
                    aggregateDescription as CFDictionary,
                    &aggregateDeviceID
                ),
                "create private tap device"
            )
            let format = try Self.inputStreamFormat(deviceID: aggregateDeviceID)
            try startCapture()
            try startOutput(physicalDevice: physicalDevice, format: format)
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let outputUnit {
            AudioOutputUnitStop(outputUnit)
            AudioUnitUninitialize(outputUnit)
            AudioComponentInstanceDispose(outputUnit)
        }
        outputUnit = nil

        if aggregateDeviceID != kAudioObjectUnknown, let captureIOProcID {
            AudioDeviceStop(aggregateDeviceID, captureIOProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, captureIOProcID)
        }
        captureIOProcID = nil

        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            if #available(macOS 14.2, *) {
                AudioHardwareDestroyProcessTap(tapID)
            }
            tapID = kAudioObjectUnknown
        }
        SCAudioRingBufferReset(ring)
    }

    func setGain(_ gain: Float32) {
        SCAudioRingBufferSetGain(ring, min(max(gain, 0), 1))
    }

    private func startCapture() throws {
        var ioProcID: AudioDeviceIOProcID?
        try Self.check(
            AudioDeviceCreateIOProcIDWithBlock(
                &ioProcID,
                aggregateDeviceID,
                captureQueue
            ) { [weak self] _, inputData, _, _, _ in
                self?.capture(inputData)
            },
            "create tap capture callback"
        )
        guard let ioProcID else {
            throw SoftwareVolumeError.coreAudio("create tap capture callback", kAudio_ParamError)
        }
        captureIOProcID = ioProcID
        try Self.check(
            AudioDeviceStart(aggregateDeviceID, ioProcID),
            "start tap capture"
        )
    }

    private func capture(_ buffers: UnsafePointer<AudioBufferList>) {
        let mutable = UnsafeMutablePointer(mutating: buffers)
        for buffer in UnsafeMutableAudioBufferListPointer(mutable) {
            guard let data = buffer.mData else { continue }
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.size
            SCAudioRingBufferWrite(
                ring,
                data.assumingMemoryBound(to: Float32.self),
                count
            )
        }
    }

    private func startOutput(
        physicalDevice: AudioDeviceID,
        format: AudioStreamBasicDescription
    ) throws {
        let output = try Self.makeHALUnit()
        do {
            var device = physicalDevice
            try Self.set(
                output,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &device,
                "select physical output"
            )
            var clientFormat = format
            try Self.set(
                output,
                kAudioUnitProperty_StreamFormat,
                kAudioUnitScope_Input,
                0,
                &clientFormat,
                "set physical client format"
            )
            var maximumFrames = Self.maximumFramesPerSlice
            try Self.set(
                output,
                kAudioUnitProperty_MaximumFramesPerSlice,
                kAudioUnitScope_Global,
                0,
                &maximumFrames,
                "set physical output maximum frames"
            )
            var callback = AURenderCallbackStruct(
                inputProc: Self.renderCallback,
                inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
            )
            try Self.set(
                output,
                kAudioUnitProperty_SetRenderCallback,
                kAudioUnitScope_Input,
                0,
                &callback,
                "set physical render callback"
            )
            try Self.check(AudioUnitInitialize(output), "initialize physical output")
            outputUnit = output
            try Self.check(AudioOutputUnitStart(output), "start physical output")
        } catch {
            AudioComponentInstanceDispose(output)
            throw error
        }
    }

    private func render(
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        buffers: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        let gain = SCAudioRingBufferGetGain(ring)
        var readCount = 0
        for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
            guard let data = buffer.mData else { continue }
            let samples = data.assumingMemoryBound(to: Float32.self)
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.size
            readCount += SCAudioRingBufferRead(ring, samples, count)
            if gain != 1 {
                for index in 0..<count {
                    samples[index] *= gain
                }
            }
        }
        if readCount > 0 {
            flags.pointee.remove(.unitRenderAction_OutputIsSilence)
        }
        return noErr
    }

    private static let renderCallback: AURenderCallback = {
        refCon, flags, _, _, _, buffers in
        guard let buffers else { return kAudio_ParamError }
        return Unmanaged<NativeAudioTapForwarder>.fromOpaque(refCon)
            .takeUnretainedValue()
            .render(flags: flags, buffers: buffers)
    }

    private static func audioProcessObjectID(pid: pid_t) throws -> AudioObjectID? {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var processID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var qualifier = pid
        let qualifierSize = UInt32(MemoryLayout<pid_t>.size)
        try check(
            AudioObjectGetPropertyData(
                system,
                &address,
                qualifierSize,
                &qualifier,
                &size,
                &processID
            ),
            "resolve SnapClick audio process"
        )
        return processID == kAudioObjectUnknown ? nil : processID
    }

    private static func inputStreamFormat(
        deviceID: AudioDeviceID
    ) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &format),
            "read tap stream format"
        )
        guard format.mChannelsPerFrame > 0, format.mSampleRate > 0 else {
            throw SoftwareVolumeError.aggregateFormatUnavailable
        }
        return format
    }

    private static func makeHALUnit() throws -> AudioUnit {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let component = AudioComponentFindNext(nil, &description) else {
            throw SoftwareVolumeError.coreAudio("find HAL output unit", kAudio_ParamError)
        }
        var unit: AudioUnit?
        try check(AudioComponentInstanceNew(component, &unit), "create HAL output unit")
        guard let unit else {
            throw SoftwareVolumeError.coreAudio("create HAL output unit", kAudio_ParamError)
        }
        return unit
    }

    private static func set<T>(
        _ unit: AudioUnit,
        _ property: AudioUnitPropertyID,
        _ scope: AudioUnitScope,
        _ element: AudioUnitElement,
        _ value: inout T,
        _ operation: String
    ) throws {
        let status = withUnsafeBytes(of: &value) { bytes in
            AudioUnitSetProperty(
                unit,
                property,
                scope,
                element,
                bytes.baseAddress,
                UInt32(bytes.count)
            )
        }
        try check(status, operation)
    }

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw SoftwareVolumeError.coreAudio(operation, status)
        }
    }
}
