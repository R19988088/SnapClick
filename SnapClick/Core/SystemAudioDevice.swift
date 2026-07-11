import CoreAudio
import Foundation

enum SystemAudioDeviceError: Error, LocalizedError {
    case coreAudio(operation: String, status: OSStatus)
    case missingProperty(String)
    case invalidPropertyData(String)
    case propertyNotSettable(String)

    var errorDescription: String? {
        switch self {
        case let .coreAudio(operation, status):
            return "\(operation) failed with CoreAudio status \(status)"
        case let .missingProperty(property):
            return "CoreAudio property is unavailable: \(property)"
        case let .invalidPropertyData(property):
            return "CoreAudio property returned invalid data: \(property)"
        case let .propertyNotSettable(property):
            return "CoreAudio property is not settable: \(property)"
        }
    }
}

final class AudioPropertyListenerToken {
    private let objectID: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private let queue: DispatchQueue
    private let block: AudioObjectPropertyListenerBlock

    init(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        queue: DispatchQueue,
        block: @escaping AudioObjectPropertyListenerBlock
    ) {
        self.objectID = objectID
        self.address = address
        self.queue = queue
        self.block = block
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(objectID, &address, queue, block)
    }
}

enum SystemAudioDevice {
    static let controlDeviceUID = "com.snapclick.audio.control"
    static let virtualDeviceUID = controlDeviceUID
    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func defaultOutputID() throws -> AudioDeviceID {
        try defaultDeviceID(
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            name: "default output device"
        )
    }

    static func defaultInputID() throws -> AudioDeviceID {
        try defaultDeviceID(
            selector: kAudioHardwarePropertyDefaultInputDevice,
            name: "default input device"
        )
    }

    private static func defaultDeviceID(
        selector: AudioObjectPropertySelector,
        name: String
    ) throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(
            AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceID),
            "read \(name)"
        )
        guard deviceID != kAudioObjectUnknown else {
            throw SystemAudioDeviceError.invalidPropertyData(name)
        }
        return deviceID
    }

    static func outputDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size),
            "read audio device list size"
        )
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        try check(
            AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &devices),
            "read audio device list"
        )
        return try devices.filter { try outputChannelCount(for: $0) > 0 }
    }

    static func physicalOutputDeviceIDs() throws -> [AudioDeviceID] {
        try outputDeviceIDs().filter {
            try transportType(for: $0) != kAudioDeviceTransportTypeVirtual
        }
    }

    static func inputDeviceIDs() throws -> [AudioDeviceID] {
        try allDeviceIDs().filter {
            try channelCount(for: $0, scope: kAudioDevicePropertyScopeInput) > 0
        }
    }

    static func inputDeviceID(uid: String) throws -> AudioDeviceID? {
        try inputDeviceIDs().first { try self.uid(for: $0) == uid }
    }

    static func isBuiltInOutput(_ deviceID: AudioDeviceID) throws -> Bool {
        try transportType(for: deviceID) == kAudioDeviceTransportTypeBuiltIn
    }

    static func isBuiltInInput(_ deviceID: AudioDeviceID) throws -> Bool {
        try transportType(for: deviceID) == kAudioDeviceTransportTypeBuiltIn
    }

    static func uid(for deviceID: AudioDeviceID) throws -> String {
        try stringProperty(
            selector: kAudioDevicePropertyDeviceUID,
            scope: kAudioObjectPropertyScopeGlobal,
            deviceID: deviceID,
            name: "device UID"
        )
    }

    static func deviceID(uid: String) throws -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid = uid as CFString
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            systemObject,
            &address,
            UInt32(MemoryLayout<CFString>.size),
            &uid,
            &size,
            &deviceID
        )
        try check(status, "translate audio device UID")
        return deviceID == kAudioObjectUnknown ? nil : deviceID
    }

    static func name(for deviceID: AudioDeviceID) throws -> String {
        try stringProperty(
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal,
            deviceID: deviceID,
            name: "device name"
        )
    }

    static func virtualOutputID() throws -> AudioDeviceID? {
        try deviceID(uid: virtualDeviceUID)
    }

    static func controlOutputID() throws -> AudioDeviceID? {
        try deviceID(uid: controlDeviceUID)
    }

    static func outputVolume(for deviceID: AudioDeviceID) throws -> Float32 {
        try scalarProperty(
            selector: kAudioDevicePropertyVolumeScalar,
            deviceID: deviceID,
            name: "output volume"
        )
    }

    static func setOutputVolume(_ volume: Float32, for deviceID: AudioDeviceID) throws {
        var value = min(max(volume, 0), 1)
        try setOutputProperty(
            selector: kAudioDevicePropertyVolumeScalar,
            deviceID: deviceID,
            value: &value,
            name: "output volume"
        )
    }

    static func outputMuted(for deviceID: AudioDeviceID) throws -> Bool {
        let value: UInt32 = try scalarProperty(
            selector: kAudioDevicePropertyMute,
            deviceID: deviceID,
            name: "output mute"
        )
        return value != 0
    }

    static func setOutputMuted(_ muted: Bool, for deviceID: AudioDeviceID) throws {
        var value: UInt32 = muted ? 1 : 0
        try setOutputProperty(
            selector: kAudioDevicePropertyMute,
            deviceID: deviceID,
            value: &value,
            name: "output mute"
        )
    }

    static func addOutputControlListener(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        _ handler: @escaping () -> Void
    ) throws -> AudioPropertyListenerToken {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let queue = DispatchQueue.main
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        try check(
            AudioObjectAddPropertyListenerBlock(deviceID, &address, queue, block),
            "add output control listener"
        )
        return AudioPropertyListenerToken(
            objectID: deviceID,
            address: address,
            queue: queue,
            block: block
        )
    }

    static func setDefaultOutput(_ deviceID: AudioDeviceID) throws {
        try setDeviceProperty(kAudioHardwarePropertyDefaultOutputDevice, deviceID: deviceID)
        try setDeviceProperty(kAudioHardwarePropertyDefaultSystemOutputDevice, deviceID: deviceID)
    }

    static func setDefaultInput(_ deviceID: AudioDeviceID) throws {
        try setDeviceProperty(kAudioHardwarePropertyDefaultInputDevice, deviceID: deviceID)
    }

    static func addDefaultOutputListener(
        _ handler: @escaping () -> Void
    ) throws -> AudioPropertyListenerToken {
        try addSystemListener(selector: kAudioHardwarePropertyDefaultOutputDevice, handler: handler)
    }

    static func addDeviceListListener(
        _ handler: @escaping () -> Void
    ) throws -> AudioPropertyListenerToken {
        try addSystemListener(selector: kAudioHardwarePropertyDevices, handler: handler)
    }

    private static func outputChannelCount(for deviceID: AudioDeviceID) throws -> Int {
        try channelCount(for: deviceID, scope: kAudioDevicePropertyScopeOutput)
    }

    private static func allDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size),
            "read audio device list size"
        )
        var devices = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        try check(
            AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &devices),
            "read audio device list"
        )
        return devices
    }

    private static func channelCount(
        for deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) throws -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return 0 }
        var size: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size),
            "read stream configuration size"
        )
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        try check(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, list),
            "read stream configuration"
        )
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { total, buffer in
            total + Int(buffer.mNumberChannels)
        }
    }

    private static func transportType(for deviceID: AudioDeviceID) throws -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return 0 }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value),
            "read audio device transport type"
        )
        return value
    }

    private static func stringProperty(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        deviceID: AudioDeviceID,
        name: String
    ) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else {
            throw SystemAudioDeviceError.missingProperty(name)
        }
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value),
            "read \(name)"
        )
        guard let value else {
            throw SystemAudioDeviceError.invalidPropertyData(name)
        }
        return value.takeUnretainedValue() as String
    }

    private static func scalarProperty<T>(
        selector: AudioObjectPropertySelector,
        deviceID: AudioDeviceID,
        name: String
    ) throws -> T {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else {
            throw SystemAudioDeviceError.missingProperty(name)
        }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<T>.size,
            alignment: MemoryLayout<T>.alignment
        )
        defer { raw.deallocate() }
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: MemoryLayout<T>.size)
        var size = UInt32(MemoryLayout<T>.size)
        try check(
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, raw),
            "read \(name)"
        )
        return raw.load(as: T.self)
    }

    private static func setOutputProperty<T>(
        selector: AudioObjectPropertySelector,
        deviceID: AudioDeviceID,
        value: inout T,
        name: String
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var settable = DarwinBoolean(false)
        try check(AudioObjectIsPropertySettable(deviceID, &address, &settable), "check \(name) mutability")
        guard settable.boolValue else { throw SystemAudioDeviceError.propertyNotSettable(name) }
        try check(
            AudioObjectSetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<T>.size),
                &value
            ),
            "set \(name)"
        )
    }

    private static func setDeviceProperty(
        _ selector: AudioObjectPropertySelector,
        deviceID: AudioDeviceID
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var settable = DarwinBoolean(false)
        try check(
            AudioObjectIsPropertySettable(systemObject, &address, &settable),
            "check default output mutability"
        )
        guard settable.boolValue else {
            throw SystemAudioDeviceError.propertyNotSettable("default output")
        }
        var value = deviceID
        try check(
            AudioObjectSetPropertyData(
                systemObject,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<AudioDeviceID>.size),
                &value
            ),
            "set default output device"
        )
    }

    private static func addSystemListener(
        selector: AudioObjectPropertySelector,
        handler: @escaping () -> Void
    ) throws -> AudioPropertyListenerToken {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let queue = DispatchQueue.main
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        try check(
            AudioObjectAddPropertyListenerBlock(systemObject, &address, queue, block),
            "add CoreAudio property listener"
        )
        return AudioPropertyListenerToken(
            objectID: systemObject,
            address: address,
            queue: queue,
            block: block
        )
    }

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw SystemAudioDeviceError.coreAudio(operation: operation, status: status)
        }
    }
}
