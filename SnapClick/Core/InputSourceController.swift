import AppKit
import Carbon
import Combine

enum InputSourcePolicyAction: Equatable {
    case ignore
    case select(String)
    case adopt(String)
}

enum InputSourcePolicy {
    static func activationAction(
        preferredID: String,
        currentID: String,
        isException: Bool
    ) -> InputSourcePolicyAction {
        guard !isException, !preferredID.isEmpty, currentID != preferredID else {
            return .ignore
        }
        return .select(preferredID)
    }

    static func sourceChangeAction(
        preferredID: String,
        currentID: String,
        isException: Bool,
        retainUserSelection: Bool,
        hasManualSwitchIntent: Bool,
        isProgrammatic: Bool
    ) -> InputSourcePolicyAction {
        guard !isProgrammatic, !isException else { return .ignore }
        guard currentID != preferredID else { return .ignore }
        if preferredID.isEmpty || (retainUserSelection && hasManualSwitchIntent) {
            return .adopt(currentID)
        }
        return .select(preferredID)
    }

    static func replacementPreferredID(
        preferredID: String,
        availableIDs: [String],
        isException: Bool
    ) -> String? {
        guard !isException, !availableIDs.contains(preferredID) else { return nil }
        return availableIDs.first ?? ""
    }
}

struct InputSourceHotkey: Equatable {
    let keyCode: UInt16
    let modifiers: UInt
}

enum InputSourceIntentDetector {
    private static let directInputSourceKeyCodes: Set<UInt16> = [63, 102, 104]
    private static let relevantModifiers: NSEvent.ModifierFlags = [
        .shift,
        .control,
        .option,
        .command,
        .function
    ]

    static func matchesKeyboardSwitch(
        event: NSEvent,
        configuredHotkeys: [InputSourceHotkey]
    ) -> Bool {
        guard event.type == .keyDown || event.type == .flagsChanged else { return false }
        return matchesKeyboardSwitch(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags.rawValue,
            configuredHotkeys: configuredHotkeys
        )
    }

    static func matchesKeyboardSwitch(
        keyCode: UInt16,
        modifiers: UInt,
        configuredHotkeys: [InputSourceHotkey]
    ) -> Bool {
        if directInputSourceKeyCodes.contains(keyCode) {
            return true
        }
        let normalizedModifiers = modifiers & relevantModifiers.rawValue
        return configuredHotkeys.contains {
            $0.keyCode == keyCode && $0.modifiers == normalizedModifiers
        }
    }
}

struct InputSourceOption: Identifiable, Hashable {
    let id: String
    let name: String
}

struct InputSourceException: Identifiable {
    let bundleID: String
    let name: String
    let applicationURL: URL?

    var id: String { bundleID }
}

final class InputSourceController: ObservableObject {
    static let shared = InputSourceController()

    @Published private(set) var availableSources: [InputSourceOption]
    @Published var preferredInputSourceID: String {
        didSet {
            guard preferredInputSourceID != oldValue else { return }
            defaults.set(preferredInputSourceID, forKey: Self.preferredSourceKey)
            applyPreferredToFrontmostApplication()
        }
    }
    @Published var retainUserSelection: Bool {
        didSet {
            defaults.set(retainUserSelection, forKey: Self.retainSelectionKey)
        }
    }
    @Published private(set) var exceptions: [InputSourceException]

    private static let preferredSourceKey = "preferredInputSourceID"
    private static let retainSelectionKey = "retainUserInputSourceSelection"
    private static let exceptionBundleIDsKey = "inputSourceExceptionBundleIDs"

    private let defaults: UserDefaults
    private var exceptionBundleIDs: Set<String>
    private var activationObserver: NSObjectProtocol?
    private var globalUserInputMonitor: Any?
    private var localUserInputMonitor: Any?
    private var pendingProgrammaticSourceID: String?
    private var configuredInputSourceHotkeys: [InputSourceHotkey] = []
    private var manualSwitchIntentExpiresAt = Date.distantPast
    private var isStarted = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let sources = Self.enabledInputSources()
        availableSources = sources

        let savedPreferredID = defaults.string(forKey: Self.preferredSourceKey) ?? ""
        let currentID = Self.currentInputSourceID() ?? ""
        if sources.contains(where: { $0.id == savedPreferredID }) {
            preferredInputSourceID = savedPreferredID
        } else if savedPreferredID.isEmpty,
                  sources.contains(where: { $0.id == currentID }) {
            preferredInputSourceID = currentID
        } else {
            preferredInputSourceID = sources.first?.id ?? ""
        }

        if defaults.object(forKey: Self.retainSelectionKey) == nil {
            retainUserSelection = true
        } else {
            retainUserSelection = defaults.bool(forKey: Self.retainSelectionKey)
        }

        exceptionBundleIDs = Set(defaults.stringArray(forKey: Self.exceptionBundleIDsKey) ?? [])
        exceptions = Self.makeExceptions(from: exceptionBundleIDs)
        defaults.set(preferredInputSourceID, forKey: Self.preferredSourceKey)
        defaults.set(retainUserSelection, forKey: Self.retainSelectionKey)
    }

    deinit {
        stop()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        configuredInputSourceHotkeys = Self.loadConfiguredInputSourceHotkeys()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            self?.handleApplicationActivated(application)
        }

        let userInputEvents: NSEvent.EventTypeMask = [
            .keyDown,
            .flagsChanged,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]
        globalUserInputMonitor = NSEvent.addGlobalMonitorForEvents(matching: userInputEvents) {
            [weak self] event in
            self?.recordManualSwitchIntentIfNeeded(event: event)
        }
        localUserInputMonitor = NSEvent.addLocalMonitorForEvents(matching: userInputEvents) {
            [weak self] event in
            self?.recordManualSwitchIntentIfNeeded(event: event)
            return event
        }

        let callback: CFNotificationCallback = { _, observer, name, _, _ in
            guard let observer else { return }
            let controller = Unmanaged<InputSourceController>
                .fromOpaque(observer)
                .takeUnretainedValue()
            let notificationName = name?.rawValue as String?
            DispatchQueue.main.async {
                controller.handleInputSourceNotification(named: notificationName)
            }
        }
        let center = CFNotificationCenterGetDistributedCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            callback,
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            observer,
            callback,
            kTISNotifyEnabledKeyboardInputSourcesChanged,
            nil,
            .deliverImmediately
        )

        applyPreferredToFrontmostApplication()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let globalUserInputMonitor {
            NSEvent.removeMonitor(globalUserInputMonitor)
            self.globalUserInputMonitor = nil
        }
        if let localUserInputMonitor {
            NSEvent.removeMonitor(localUserInputMonitor)
            self.localUserInputMonitor = nil
        }
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        pendingProgrammaticSourceID = nil
        manualSwitchIntentExpiresAt = .distantPast
    }

    func addException(applicationURL: URL) {
        guard let bundleID = Bundle(url: applicationURL)?.bundleIdentifier,
              !bundleID.isEmpty,
              exceptionBundleIDs.insert(bundleID).inserted else {
            return
        }
        persistExceptions()
    }

    func removeException(bundleID: String) {
        guard exceptionBundleIDs.remove(bundleID) != nil else { return }
        persistExceptions()
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
            applyPreferredToFrontmostApplication()
        }
    }

    func icon(for exception: InputSourceException) -> NSImage {
        guard let url = exception.applicationURL else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func persistExceptions() {
        defaults.set(exceptionBundleIDs.sorted(), forKey: Self.exceptionBundleIDsKey)
        exceptions = Self.makeExceptions(from: exceptionBundleIDs)
    }

    private func handleApplicationActivated(_ application: NSRunningApplication?) {
        let bundleID = application?.bundleIdentifier
        configuredInputSourceHotkeys = Self.loadConfiguredInputSourceHotkeys()
        manualSwitchIntentExpiresAt = .distantPast
        repairUnavailablePreferredSource(currentBundleID: bundleID)
        applyPreferred(currentBundleID: bundleID)
    }

    private func recordManualSwitchIntentIfNeeded(event: NSEvent? = nil) {
        guard let event else { return }
        let eventType = event.type
        let mouseLocation = NSEvent.mouseLocation

        let update = { [weak self] in
            guard let self else { return }
            switch eventType {
            case .keyDown, .flagsChanged:
                guard InputSourceIntentDetector.matchesKeyboardSwitch(
                    event: event,
                    configuredHotkeys: self.configuredInputSourceHotkeys
                ) else { return }
                self.manualSwitchIntentExpiresAt = Date().addingTimeInterval(1)
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                guard Self.isInputSourceMenuBarPoint(mouseLocation) else { return }
                self.manualSwitchIntentExpiresAt = Date().addingTimeInterval(5)
            default:
                break
            }
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func handleInputSourceNotification(named name: String?) {
        if name == (kTISNotifyEnabledKeyboardInputSourcesChanged as String) {
            refreshAvailableSources()
            return
        }

        guard let currentID = Self.currentInputSourceID() else { return }
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isProgrammatic = pendingProgrammaticSourceID == currentID
        pendingProgrammaticSourceID = nil
        let hasManualSwitchIntent = Date() <= manualSwitchIntentExpiresAt
        manualSwitchIntentExpiresAt = .distantPast
        execute(
            InputSourcePolicy.sourceChangeAction(
                preferredID: preferredInputSourceID,
                currentID: currentID,
                isException: isException(bundleID),
                retainUserSelection: retainUserSelection,
                hasManualSwitchIntent: hasManualSwitchIntent,
                isProgrammatic: isProgrammatic
            )
        )
    }

    private func refreshAvailableSources() {
        availableSources = Self.enabledInputSources()
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        repairUnavailablePreferredSource(currentBundleID: bundleID)
    }

    private func repairUnavailablePreferredSource(currentBundleID: String?) {
        guard let replacementID = InputSourcePolicy.replacementPreferredID(
            preferredID: preferredInputSourceID,
            availableIDs: availableSources.map(\.id),
            isException: isException(currentBundleID)
        ) else { return }
        preferredInputSourceID = replacementID
    }

    private func applyPreferredToFrontmostApplication() {
        guard isStarted else { return }
        applyPreferred(currentBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    private func applyPreferred(currentBundleID: String?) {
        guard let currentID = Self.currentInputSourceID() else { return }
        execute(
            InputSourcePolicy.activationAction(
                preferredID: preferredInputSourceID,
                currentID: currentID,
                isException: isException(currentBundleID)
            )
        )
    }

    private func execute(_ action: InputSourcePolicyAction) {
        switch action {
        case .ignore:
            break
        case .adopt(let inputSourceID):
            preferredInputSourceID = inputSourceID
        case .select(let inputSourceID):
            selectInputSource(id: inputSourceID)
        }
    }

    private func isException(_ bundleID: String?) -> Bool {
        bundleID.map(exceptionBundleIDs.contains) ?? false
    }

    private func selectInputSource(id: String) {
        guard !id.isEmpty, Self.currentInputSourceID() != id,
              let inputSource = Self.inputSource(id: id) else {
            return
        }
        pendingProgrammaticSourceID = id
        if TISSelectInputSource(inputSource) != noErr {
            pendingProgrammaticSourceID = nil
        }
    }

    private static func enabledInputSources() -> [InputSourceOption] {
        let filter = [
            kTISPropertyInputSourceCategory!: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsEnabled!: kCFBooleanTrue!
        ] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false).takeRetainedValue()
            as! [TISInputSource]

        return sources.compactMap { source in
            guard property(source, key: kTISPropertyInputSourceIsSelectCapable, as: CFBoolean.self)
                    .map(CFBooleanGetValue) == true,
                  let id = property(source, key: kTISPropertyInputSourceID, as: CFString.self)
                    as String?,
                  let name = property(source, key: kTISPropertyLocalizedName, as: CFString.self)
                    as String? else {
                return nil
            }
            return InputSourceOption(id: id, name: name)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func currentInputSourceID() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return property(source, key: kTISPropertyInputSourceID, as: CFString.self) as String?
    }

    private static func inputSource(id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID!: id as CFString] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false).takeRetainedValue()
            as! [TISInputSource]
        return sources.first { source in
            property(source, key: kTISPropertyInputSourceIsEnabled, as: CFBoolean.self)
                .map(CFBooleanGetValue) == true &&
            property(source, key: kTISPropertyInputSourceIsSelectCapable, as: CFBoolean.self)
                .map(CFBooleanGetValue) == true
        }
    }

    private static func property<T>(
        _ source: TISInputSource,
        key: CFString,
        as type: T.Type
    ) -> T? {
        guard let rawValue = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(rawValue).takeUnretainedValue() as? T
    }

    private static func loadConfiguredInputSourceHotkeys() -> [InputSourceHotkey] {
        let domain = UserDefaults.standard.persistentDomain(
            forName: "com.apple.symbolichotkeys"
        )
        let hotkeys = domain?["AppleSymbolicHotKeys"] as? [String: Any]

        var configuredHotkeys: [InputSourceHotkey] = ["60", "61"].compactMap { identifier in
            guard let entry = hotkeys?[identifier] as? [String: Any],
                  (entry["enabled"] as? NSNumber)?.boolValue == true,
                  let value = entry["value"] as? [String: Any],
                  let parameters = value["parameters"] as? [NSNumber],
                  parameters.count >= 3 else {
                return nil
            }
            return InputSourceHotkey(
                keyCode: parameters[1].uint16Value,
                modifiers: parameters[2].uintValue
            )
        }
        if UserDefaults.standard.bool(forKey: "TISRomanSwitchState") {
            configuredHotkeys.append(InputSourceHotkey(keyCode: 57, modifiers: 0))
        }
        return configuredHotkeys
    }

    private static func isInputSourceMenuBarPoint(_ point: CGPoint) -> Bool {
        guard let agentPID = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.TextInputMenuAgent"
        })?.processIdentifier else {
            return false
        }

        let maxScreenY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(point.x),
            Float(maxScreenY - point.y),
            &element
        ) == .success,
        let element else {
            return false
        }

        var elementPID: pid_t = 0
        return AXUIElementGetPid(element, &elementPID) == .success && elementPID == agentPID
    }

    private static func makeExceptions(from bundleIDs: Set<String>) -> [InputSourceException] {
        bundleIDs.map { bundleID in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            let name = url?.deletingPathExtension().lastPathComponent ?? bundleID
            return InputSourceException(bundleID: bundleID, name: name, applicationURL: url)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
